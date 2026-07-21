import AVFoundation
import Metal
import CoreVideo
import Combine

/// Callback for each captured frame, providing both the pixel buffer and presentation time.
typealias FrameCallback = (CVPixelBuffer, CMTime) -> Void

class CameraManager: NSObject, ObservableObject {
    @Published var currentPixelBuffer: CVPixelBuffer?

    /// Called on the camera session queue for every captured frame.
    var onFrameCaptured: FrameCallback?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.maimaiFisheyeStabilizer.cameraSession")
    private var videoOutput: AVCaptureVideoDataOutput?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to find back wide-angle camera")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Failed to create video input: \(error)")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Retain the pixel buffer before dispatching to main queue
        let retainedBuffer = pixelBuffer
        CVPixelBufferRetain(retainedBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.currentPixelBuffer = retainedBuffer
            // Release previous buffer if any
            if let previous = self?.currentPixelBuffer, previous !== retainedBuffer {
                CVPixelBufferRelease(previous)
            }
        }

        // Forward frame to the callback on the session queue (synchronous, no retain needed)
        onFrameCaptured?(pixelBuffer, presentationTime)
    }
}
