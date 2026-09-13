import AVFoundation
import CoreGraphics
import CoreImage
import SwiftUI
import UIKit

// MARK: - Camera session controller

/// Owns the `AVCaptureSession`, handles camera permission, and delivers
/// each frame as a `CGImage` to `onFrame` on a non-main queue.
/// Opts out of default MainActor isolation so frames arrive off the UI thread.
nonisolated final class CameraSessionController {
    let session = AVCaptureSession()
    /// Called on a background queue with the latest camera frame.
    var onFrame: (@Sendable (CGImage) -> Void)?

    private let outputQueue = DispatchQueue(label: "mtg.utils.camera.frame", qos: .userInitiated)
    private var isConfigured = false
    private let ciContext = CIContext()

    enum CameraError: LocalizedError {
        case unauthorized
        case noCamera
        case setupFailed

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Sin permiso de cámara. Actívalo en Ajustes > Privacidad > Cámara."
            case .noCamera:
                return "No se encontró una cámara disponible en este dispositivo."
            case .setupFailed:
                return "No se pudo configurar la cámara."
            }
        }
    }

    /// Requests camera permission. Returns `true` when granted.
    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    /// Requests permission, configures the session once, and starts streaming.
    func start() async throws {
        guard await requestAccess() else { throw CameraError.unauthorized }
        try configureIfNeeded()
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCamera
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.setupFailed
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard session.canAddInput(input) else { throw CameraError.setupFailed }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(SampleBufferDelegate(callback: { [weak self] image in
            self?.onFrame?(image)
        }), queue: outputQueue)

        guard session.canAddOutput(output) else { throw CameraError.setupFailed }
        session.addOutput(output)

        isConfigured = true
    }
}

// MARK: - Frame → CGImage conversion

/// Converts `CMSampleBuffer` frames to `CGImage` and forwards them to `onFrame`.
nonisolated final class SampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let callback: (CGImage) -> Void
    private let ciContext = CIContext()

    init(callback: @escaping (CGImage) -> Void) {
        self.callback = callback
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        callback(cgImage)
    }
}

// MARK: - SwiftUI preview

/// Live camera preview backed by `CameraSessionController.session`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

/// UIView hosting an `AVCaptureVideoPreviewLayer`.
final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}