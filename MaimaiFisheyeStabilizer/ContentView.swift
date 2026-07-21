import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()
    @State private var metalPipeline: MetalPipeline?
    @State private var lensProfile = LensProfile.default
    @State private var stabilization = StabilizationParams.default

    var body: some View {
        Group {
            if let pipeline = metalPipeline, let frame = camera.frame {
                CameraPreviewView(
                    pixelBuffer: frame,
                    metalPipeline: pipeline,
                    motion: motion,
                    lensProfile: lensProfile,
                    stabilization: stabilization
                )
                .ignoresSafeArea()
            } else {
                Text("Initializing...")
                    .font(.largeTitle)
            }
        }
        .onAppear {
            metalPipeline = MetalPipeline()
            camera.startSession()
            motion.start()
        }
        .onDisappear {
            camera.stopSession()
            motion.stop()
        }
    }
}
