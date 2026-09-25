import AVFoundation
import Foundation
import Observation
import UIKit

// MARK: - Scanning lifecycle

enum CardScanPhase: Equatable {
    case idle
    case requestingPermission
    case scanning
    case recognizing
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
    private var resolver: CardScanResolving
    private let store: AppDataStoring

    internal private(set) var lastScanned: ScannedCard?
    internal private(set) var recognitionTask: Task<Void, Never>?

    init(
        camera: CameraSessionController = CameraSessionController(),
        resolver: CardScanResolving = StubCardScanResolver(),
        store: AppDataStoring = BackendDataStore(),
        userId: String = BackendDataStore.demoUserId
    ) {
        self.camera = camera
        self.resolver = resolver
        self.store = store
        self.userId = userId
    }

    /// Convenience for production: backend OCR + cheapest printing.
    convenience init(appStore: AppStore) {
        self.init(
            resolver: BackendCardScanResolver(
                client: appStore.client,
                accessToken: appStore.accessToken,
                userId: appStore.userId
            ),
            store: appStore.store,
            userId: appStore.userId
        )
    }

    var isScanning: Bool {
        switch phase {
        case .scanning, .requestingPermission: return true
        default: return false
        }
    }

    /// Session used exclusively by `CameraPreview` to render the live camera feed.
    var previewSession: AVCaptureSession { camera.session }

    // MARK: - Lifecycle

    /// Requests camera access and starts streaming frames (for the live preview).
    func start() {
        guard !isScanning, phase != .adding, phase != .recognizing else { return }
        phase = .requestingPermission

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
        recognitionTask?.cancel()
        recognitionTask = nil
        camera.stop()
        switch phase {
        case .scanning, .requestingPermission, .recognizing, .error, .permissionDenied:
            phase = .idle
        default:
            break
        }
    }

    /// Returns from a detected card (or a transient error) to the live scanner.
    func resumeScanning() {
        switch phase {
        case .detected, .error:
            quantity = 1
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

    // MARK: - Capture → backend OCR

    /// Captures the current camera frame and resolves it via the general API.
    func captureAndScan() {
        guard case .scanning = phase else { return }
        do {
            let jpeg = try camera.captureJPEG()
            scan(imageJPEG: jpeg)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Test / alternate seam: resolve a JPEG without touching the camera.
    func scan(imageJPEG: Data) {
        guard phase == .scanning || phase == .idle else { return }
        phase = .recognizing
        recognitionTask?.cancel()
        recognitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let match = try await self.resolver.resolve(imageJPEG: imageJPEG)
                guard !Task.isCancelled else { return }
                let scanned = ScannedCard(match: match)
                self.lastScanned = scanned
                self.phase = .detected(scanned)
                self.quantity = 1
            } catch {
                guard !Task.isCancelled else { return }
                self.phase = .error(error.localizedDescription)
            }
        }
    }

    /// Test seam: enters the `.scanning` phase without touching the camera.
    internal func enterScanningForTesting() {
        phase = .scanning
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
                cardScryfallId: scanned.id,
                cardName: scanned.name,
                quantity: quantity,
                setCode: scanned.setCode,
                collectorNumber: scanned.collectorNumber,
                manaCost: scanned.manaCost,
                typeLine: scanned.typeLine,
                imageUri: scanned.imageUri
            )

            if var merged = byKey[collectionKey(for: newCard)] {
                merged.quantity += quantity
                byKey[collectionKey(for: newCard)] = merged
            } else {
                byKey[collectionKey(for: newCard)] = newCard
            }

            try await store.saveCollection(Array(byKey.values))

            phase = .scanning
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func collectionKey(for card: CollectionCard) -> String {
        "\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"
    }
}
