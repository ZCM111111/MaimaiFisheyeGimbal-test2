import AVFoundation

final class Recorder {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let outputURL: URL
    private let outputSize: CGSize
    private var started = false
    private var lastTimestamp: CMTime = .zero

    init(resolution: CGSize) {
        outputSize = resolution
        let dir = FileManager.default.temporaryDirectory
        outputURL = dir.appendingPathComponent("maimai_stabilized_\(Int(Date().timeIntervalSince1970)).mov")
    }

    func start() {
        try? FileManager.default.removeItem(at: outputURL)
        guard let w = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            print("❌ AVAssetWriter init failed")
            return
        }
        writer = w

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: outputSize.width,
            AVVideoHeightKey: outputSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 20_000_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input!.expectsMediaDataInRealTime = true

        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: outputSize.width,
                kCVPixelBufferHeightKey as String: outputSize.height
            ]
        )

        writer!.add(input!)
        writer!.startWriting()
        writer!.startSession(atSourceTime: .zero)
        started = true
    }

    func append(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard started, let input, input.isReadyForMoreMediaData else { return }
        adaptor?.append(pixelBuffer, withPresentationTime: timestamp)
        lastTimestamp = timestamp
    }

    func stop() {
        input?.markAsFinished()
        writer?.finishWriting { [weak self] in
            print("✅ Recording saved: \(self?.outputURL.path ?? "")")
        }
        started = false
    }
}
