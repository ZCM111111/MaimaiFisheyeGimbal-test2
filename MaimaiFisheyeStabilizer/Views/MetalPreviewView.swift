import SwiftUI
import MetalKit
import CoreMedia

struct MetalPreviewView: UIViewRepresentable {
    var pipeline: MetalPipeline
    var camera: CameraManager
    var motion: MotionManager
    var settings: StabilizationSettings
    var recorder: Recorder?

    func makeCoordinator() -> Coordinator {
        Coordinator(pipeline: pipeline, camera: camera, motion: motion,
                    settings: settings, recorder: recorder)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = pipeline.device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.recorder = recorder
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        let pipeline: MetalPipeline
        let camera: CameraManager
        let motion: MotionManager
        let settings: StabilizationSettings
        var recorder: Recorder?

        /// Latest camera frame — written from background queue, read from display link.
        private var latestBuffer: CVPixelBuffer?
        private let bufferLock = NSLock()

        init(pipeline: MetalPipeline, camera: CameraManager, motion: MotionManager,
             settings: StabilizationSettings, recorder: Recorder?) {
            self.pipeline = pipeline
            self.camera = camera
            self.motion = motion
            self.settings = settings
            self.recorder = recorder
            super.init()

            // Wire camera → store latest buffer
            camera.frameCallback = { [weak self] buffer, timestamp in
                self?.bufferLock.lock()
                self?.latestBuffer = buffer
                self?.bufferLock.unlock()
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            bufferLock.lock()
            guard let buffer = latestBuffer else {
                bufferLock.unlock()
                return
            }
            latestBuffer = nil  // consume
            bufferLock.unlock()

            guard let drawable = view.currentDrawable else { return }

            let snap = motion.snapshot()
            pipeline.render(
                pixelBuffer: buffer,
                drawable: drawable,
                lens: settings.lensProfile,
                stabilization: snap,
                settings: settings
            )

            // Append to recorder if recording
            if settings.recordingState.isRecording {
                recorder?.append(pixelBuffer: buffer, timestamp: CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600))
            }
        }
    }
}
