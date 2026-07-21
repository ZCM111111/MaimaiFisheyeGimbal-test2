import AVFoundation
import CoreVideo

class Recorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private(set) var isRecording = false
    private let recordingQueue = DispatchQueue(label: "recorder.queue")

    func startRecording(outputURL: URL, size: CGSize) {
        recordingQueue.async { [weak self] in
            guard let self = self else { return }

            // Remove existing file if needed
            try? FileManager.default.removeItem(at: outputURL)

            do {
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(size.width),
                    AVVideoHeightKey: Int(size.height)
                ]

                let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                input.expectsMediaDataInRealTime = true

                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: input,
                    sourcePixelBufferAttributes: [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                        kCVPixelBufferWidthKey as String: Int(size.width),
                        kCVPixelBufferHeightKey as String: Int(size.height)
                    ]
                )

                if writer.canAdd(input) {
                    writer.add(input)
                }

                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                self.assetWriter = writer
                self.videoInput = input
                self.pixelBufferAdaptor = adaptor
                self.isRecording = true

                print("Recording started: \(outputURL.lastPathComponent)")
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }

    func writeFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        recordingQueue.async { [weak self] in
            guard let self = self,
                  self.isRecording,
                  let input = self.videoInput,
                  input.isReadyForMoreMediaData else { return }
            self.pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        recordingQueue.async { [weak self] in
            guard let self = self, let writer = self.assetWriter else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.videoInput?.markAsFinished()
            writer.finishWriting { [weak self] in
                let url = writer.outputURL
                self?.isRecording = false
                self?.assetWriter = nil
                self?.videoInput = nil
                self?.pixelBufferAdaptor = nil
                print("Recording saved: \(url.lastPathComponent)")
                DispatchQueue.main.async {
                    completion(url)
                }
            }
        }
    }
}
