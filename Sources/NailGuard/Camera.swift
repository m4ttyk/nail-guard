import AVFoundation
import SwiftUI

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera")
    private let lock = NSLock()
    private let output = AVCaptureVideoDataOutput()
    private var latest: CVPixelBuffer?

    /// Runs the session from app launch so frames are already exposed when detection starts.
    func start() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.denied }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            throw CameraError.missing
        }
        session.beginConfiguration()
        session.addInput(try AVCaptureDeviceInput(device: device))
        // The camera's native format avoids a per-frame colour conversion.
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        session.addOutput(output)
        session.commitConfiguration()
        // 15 fps is the built-in camera's minimum; set after commit because configuration resets it.
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 15 && 15 <= $0.maxFrameRate }) {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            device.unlockForConfiguration()
        }
        queue.async { self.session.startRunning() }
    }

    /// Frames reach the app only while detecting; the preview keeps running regardless.
    func setDelivering(_ delivering: Bool) {
        if !delivering { lock.withLock { latest = nil } }
        output.setSampleBufferDelegate(delivering ? self : nil, queue: delivering ? queue : nil)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.withLock { latest = buffer }
    }

    func latestBuffer() -> CVPixelBuffer? {
        lock.withLock { latest }
    }
}

enum CameraError: LocalizedError {
    case denied, missing

    var errorDescription: String? {
        switch self {
        case .denied: "Camera access denied. Allow it in System Settings → Privacy & Security → Camera."
        case .missing: "No built-in camera found."
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
