import AVFoundation
import CoreVideo
import Combine
import os.log

/// Thread-safe video recorder using AVAssetWriter.
/// Captures raw camera frames to a .mov file with H.264 encoding.
class Recorder: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0

    // MARK: - Private State
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var lastPresentationTime: CMTime?

    private let recordingQueue = DispatchQueue(label: "com.maimaiFisheyeStabilizer.recorder")
    private var durationTimer: Timer?

    // MARK: - Public Methods

    /// Starts recording to the given output URL with the specified size.
    /// - Parameters:
    ///   - outputURL: The file URL where the video will be saved.
    ///   - size: The output video size (e.g., 1920x1080 or 3840x2160).
    func startRecording(outputURL: URL, size: CGSize) {
        recordingQueue.async { [weak self] in
            guard let self = self else { return }

            // Prevent starting if already recording
            guard !self.isRecording else { return }

            // Remove any existing file at the output URL
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputURL.path) {
                do {
                    try fileManager.removeItem(at: outputURL)
                } catch {
                    os_log("Failed to remove existing file: %{public}@", type: .error, error.localizedDescription)
                    return
                }
            }

            // Create asset writer
            guard let writer = try? AVAssetWriter(url: outputURL, fileType: .mov) else {
                os_log("Failed to create AVAssetWriter", type: .error)
                return
            }

            // Configure video output settings
            let outputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            input.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            guard writer.canAdd(input) else {
                os_log("Cannot add video input to asset writer", type: .error)
                return
            }

            writer.add(input)

            guard writer.startWriting() else {
                os_log("Failed to start writing: %{public}@", type: .error, writer.error?.localizedDescription ?? "unknown")
                return
            }

            writer.startSession(atSourceTime: .zero)

            DispatchQueue.main.async {
                self.assetWriter = writer
                self.videoInput = input
                self.pixelBufferAdaptor = adaptor
                self.isRecording = true
                self.recordingDuration = 0.0
                self.recordingStartTime = nil
                self.lastPresentationTime = nil
                self.startDurationTimer()
            }
        }
    }

    /// Writes a single frame to the video file.
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer containing the frame data.
    ///   - presentationTime: The presentation time for this frame.
    func writeFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        recordingQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isRecording else { return }
            guard let adaptor = self.pixelBufferAdaptor else { return }
            guard let input = self.videoInput else { return }

            // Set the start time on first frame
            if self.recordingStartTime == nil {
                self.recordingStartTime = presentationTime
            }

            // Calculate relative presentation time
            let relativeTime = CMTimeSubtract(presentationTime, self.recordingStartTime ?? .zero)
            self.lastPresentationTime = relativeTime

            // Wait until the input is ready for more media data
            guard input.isReadyForMoreMediaData else { return }

            // Append the pixel buffer
            if !adaptor.append(pixelBuffer, withPresentationTime: relativeTime) {
                os_log("Failed to append pixel buffer", type: .error)
            }
        }
    }

    /// Stops recording and finalizes the video file.
    /// - Parameter completion: Called when the recording has finished writing.
    func stopRecording(completion: @escaping () -> Void) {
        recordingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion() }
                return
            }

            guard self.isRecording else {
                DispatchQueue.main.async { completion() }
                return
            }

            // Mark input as finished
            self.videoInput?.markAsFinished()

            // Finish writing
            self.assetWriter?.finishWriting { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async { completion() }
                    return
                }

                if let error = self.assetWriter?.error {
                    os_log("Asset writer finished with error: %{public}@", type: .error, error.localizedDescription)
                }

                DispatchQueue.main.async {
                    self.stopDurationTimer()
                    self.isRecording = false
                    self.recordingDuration = 0.0
                    self.assetWriter = nil
                    self.videoInput = nil
                    self.pixelBufferAdaptor = nil
                    self.recordingStartTime = nil
                    self.lastPresentationTime = nil
                    completion()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let startTime = self.recordingStartTime, let lastTime = self.lastPresentationTime {
                let duration = CMTimeGetSeconds(CMTimeSubtract(lastTime, startTime))
                self.recordingDuration = max(0, duration)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
