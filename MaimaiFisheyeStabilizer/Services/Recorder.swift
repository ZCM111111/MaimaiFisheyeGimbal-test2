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
    @Published var recordingError: String?

    // MARK: - Private State
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var lastPresentationTime: CMTime?

    private let recordingQueue = DispatchQueue(label: "com.maimaiFisheyeStabilizer.recorder")
    private var durationTimer: Timer?

    // Internal recording flag, only accessed on recordingQueue
    private var _isRecording: Bool = false

    // Main-queue copies of timing state for the timer
    private var mainQueueStartTime: CMTime?
    private var mainQueueLastPresentationTime: CMTime?

    // MARK: - Public Methods

    /// Starts recording to the given output URL with the specified size.
    /// - Parameters:
    ///   - outputURL: The file URL where the video will be saved.
    ///   - size: The output video size (e.g., 1920x1080 or 3840x2160).
    func startRecording(outputURL: URL, size: CGSize) {
        recordingQueue.async { [weak self] in
            guard let self = self else { return }

            // Prevent starting if already recording
            guard !self._isRecording else { return }

            // Remove any existing file at the output URL
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputURL.path) {
                do {
                    try fileManager.removeItem(at: outputURL)
                } catch {
                    os_log("Failed to remove existing file: %{public}@", type: .error, error.localizedDescription)
                    DispatchQueue.main.async {
                        self.recordingError = "Failed to remove existing file: \(error.localizedDescription)"
                    }
                    return
                }
            }

            // Create asset writer
            do {
                let writer = try AVAssetWriter(url: outputURL, fileType: .mov)

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
                    DispatchQueue.main.async {
                        self.recordingError = "Cannot add video input to asset writer"
                    }
                    return
                }

                writer.add(input)

                guard writer.startWriting() else {
                    os_log("Failed to start writing: %{public}@", type: .error, writer.error?.localizedDescription ?? "unknown")
                    DispatchQueue.main.async {
                        self.recordingError = "Failed to start writing: \(writer.error?.localizedDescription ?? "unknown")"
                    }
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
                    self.mainQueueStartTime = nil
                    self.mainQueueLastPresentationTime = nil
                    self.startDurationTimer()
                }

                self._isRecording = true
            } catch {
                os_log("Failed to create AVAssetWriter: %{public}@", type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    self.recordingError = "Failed to create AVAssetWriter: \(error.localizedDescription)"
                }
                return
            }
        }
    }

    /// Writes a single frame to the video file.
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer containing the frame data.
    ///   - presentationTime: The presentation time for this frame.
    func writeFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        recordingQueue.async { [weak self] in
            guard let self = self else {
                CVPixelBufferRelease(pixelBuffer)
                return
            }
            guard self._isRecording else {
                CVPixelBufferRelease(pixelBuffer)
                return
            }
            guard let adaptor = self.pixelBufferAdaptor else {
                CVPixelBufferRelease(pixelBuffer)
                return
            }
            guard let input = self.videoInput else {
                CVPixelBufferRelease(pixelBuffer)
                return
            }

            // Set the start time on first frame
            if self.recordingStartTime == nil {
                self.recordingStartTime = presentationTime
            }

            // Calculate relative presentation time
            let relativeTime = CMTimeSubtract(presentationTime, self.recordingStartTime ?? .zero)
            self.lastPresentationTime = relativeTime

            // Wait until the input is ready for more media data
            guard input.isReadyForMoreMediaData else {
                CVPixelBufferRelease(pixelBuffer)
                return
            }

            // Append the pixel buffer
            if !adaptor.append(pixelBuffer, withPresentationTime: relativeTime) {
                os_log("Failed to append pixel buffer", type: .error)
            }

            // Release the buffer after writing
            CVPixelBufferRelease(pixelBuffer)

            // Update main-queue timing copies for the timer
            DispatchQueue.main.async {
                self.mainQueueStartTime = self.recordingStartTime
                self.mainQueueLastPresentationTime = self.lastPresentationTime
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

            guard self._isRecording else {
                DispatchQueue.main.async { completion() }
                return
            }

            self._isRecording = false

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
                    DispatchQueue.main.async {
                        self.recordingError = "Asset writer finished with error: \(error.localizedDescription)"
                    }
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
                    self.mainQueueStartTime = nil
                    self.mainQueueLastPresentationTime = nil
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
            if let startTime = self.mainQueueStartTime, let lastTime = self.mainQueueLastPresentationTime {
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
