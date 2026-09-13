import AVFoundation
import CoreGraphics
import Foundation
import Observation

// MARK: - Scanning lifecycle

enum CardScanPhase: Equatable {
    case idle
    case requestingPermission
    case scanning
    case detected(ScannedCard)
    case adding
    case permissionDenied
    case error(String)
}

// MARK: - View model

@Observable
@MainActor
final class CardScannerViewModel {
    private(set) var phase: CardScanPhase = .idle
    /// Copies of the recognized card to insert into the collection.
    var quantity = 1
    /// User scope for the cards created by `addToCollection`.
    var userId: String = BackendDataStore.demoUserId

    private let camera: CameraSessionController
    private var scanner: CardScanning
    private let store: AppDataStoring

    // Stability / debounce state (internal so tests can verify the pipeline).
    internal private(set) var stableName: String?
    internal private(set) var stableFrames = 0
    internal private(set) var resolutionTask: Task<Void, Never>?
    internal private(set) var lastScanned: ScannedCard?
    private var lastScan: Date = .distantPast

    private let minimumStableFrames: Int
    private let scanThrottle: TimeInterval

    init(
        camera: CameraSessionController = CameraSessionController(),
        scanner: CardScanning = VisionCardScanService(),
        store: AppDataStoring = BackendDataStore(),
        userId: String = BackendDataStore.demoUserId,
        minimumStableFrames: Int = 3,
        scanThrottle: TimeInterval = 0.35
    ) {
        self.camera = camera
        self.scanner = scanner
        self.store = store
        self.userId = userId
        self.minimumStableFrames = minimumStableFrames
        self.scanThrottle = scanThrottle
    }

    var isScanning: Bool {
        switch phase {
        case .scanning, .requestingPermission: return true
        default: return false
        }
    }

    /// Session used exclusively by `CameraPreview` to render the live camera feed.
    /// The view never needs access to the controller or to its frame callback.
    var previewSession: AVCaptureSession { camera.session }

    // MARK: - Lifecycle

    /// Requests camera access and starts streaming frames.
    func start() {
        guard !isScanning, phase != .adding else { return }
        phase = .requestingPermission

        camera.onFrame = { [weak self] image in
            Task { @MainActor [weak self] in
                self?.processFrame(image)
            }
        }

        Task { @MainActor in
            do {
                try await camera.start()
                if case .requestingPermission = phase {
                    phase = .scanning
                }
            } catch {
                phase = isPermissionDenied(error) ? .permissionDenied : .error(error.localizedDescription)
            }
        }
    }

    /// Stops streaming. Keeps a `detected` card so the user can still save it.
    func stop() {
        camera.onFrame = nil
        resolutionTask?.cancel()
        resolutionTask = nil
        camera.stop()
        switch phase {
        case .scanning, .requestingPermission, .error, .permissionDenied:
            phase = .idle
        default:
            break
        }
    }

    /// Returns from a detected card (or a transient error) to the live scanner
    /// without exposing the view model's state machine to direct mutation.
    func resumeScanning() {
        switch phase {
        case .detected, .error:
            quantity = 1
            lastScan = .distantPast
            resetStability()
            phase = .scanning
        default:
            break
        }
    }

    /// Recovers from a failed state. When a card was already recognized but its save
    /// failed, retries the save; otherwise restarts the camera.
    func retry() {
        guard case .error = phase else { return }
        if let lastScanned {
            phase = .detected(lastScanned)
            Task { await addToCollection() }
        } else {
            start()
        }
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        guard let cameraError = error as? CameraSessionController.CameraError else { return false }
        return cameraError == .unauthorized
    }

    // MARK: - Frame pipeline

    /// Feeds a camera frame through OCR + stability/voting. Only a name seen
    /// consistently across `minimumStableFrames` frames is resolved against Scryfall.
    internal func processFrame(_ image: CGImage) {
        guard case .scanning = phase else { return }

        let now = Date()
        guard now.timeIntervalSince(lastScan) >= scanThrottle else { return }
        lastScan = now

        let candidates = scanner.recognizeCard(in: image)
        guard let best = stableBest(from: candidates) else { return }

        resolutionTask?.cancel()
        resolutionTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let card = try await self.scanner.resolve(best) else { return }
                guard !Task.isCancelled, case .scanning = self.phase else { return }
                let scanned = ScannedCard(card: card)
                self.lastScanned = scanned
                self.phase = .detected(scanned)
                self.quantity = 1
            } catch {
                // Transient resolution errors (e.g. network) keep the scanner live.
            }
        }
    }

    /// Applies the stability vote: the highest-confidence candidate, requiring the same
    /// name on consecutive frames. Extracted as a pure function for unit testing.
    internal func stableBest(from candidates: [CardScanCandidate]) -> CardScanCandidate? {
        guard let best = candidates.first else {
            resetStability()
            return nil
        }
        let name = best.normalizedName
        if name == stableName {
            stableFrames += 1
            return stableFrames >= minimumStableFrames ? best : nil
        } else {
            stableName = name
            stableFrames = 1
            return nil
        }
    }

    private func resetStability() {
        stableName = nil
        stableFrames = 0
    }

    /// Test seam: enters the `.scanning` phase without touching the camera.
    internal func enterScanningForTesting() {
        phase = .scanning
        lastScan = .distantPast
        resetStability()
    }

    // MARK: - Persistence

    /// Merges the recognized card into the collection (by normalized name + set) and
    /// persists via the shared store, mirroring `CollectionViewModel.addCards`.
    func addToCollection() async {
        guard case .detected(let scanned) = phase, quantity >= 1 else { return }
        lastScanned = scanned
        phase = .adding
        defer {
            if case .adding = phase {
                phase = .error("No se pudo guardar la carta en la colección.")
            }
        }

        do {
            var byKey: [String: CollectionCard] = [:]
            let existing = try await store.allCollection()
            for card in existing {
                byKey[collectionKey(for: card)] = card
            }

            let newCard = CollectionCard(
                userId: userId,
                cardScryfallId: scanned.card.id,
                cardName: scanned.card.name,
                quantity: quantity,
                setCode: scanned.card.set,
                collectorNumber: scanned.card.collectorNumber,
                manaCost: scanned.card.displayManaCost,
                typeLine: scanned.card.displayTypeLine,
                imageUri: scanned.card.displayImageUri
            )

            if var merged = byKey[collectionKey(for: newCard)] {
                merged.quantity += quantity
                byKey[collectionKey(for: newCard)] = merged
            } else {
                byKey[collectionKey(for: newCard)] = newCard
            }

            try await store.saveCollection(Array(byKey.values))

            phase = .scanning
            lastScan = .distantPast
            resetStability()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func collectionKey(for card: CollectionCard) -> String {
        "\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"
    }
}