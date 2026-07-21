import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var metalPipeline: MetalPipeline?

    var body: some View {
        Group {
            if let pipeline = metalPipeline, let frame = camera.frame {
                CameraPreviewView(pixelBuffer: frame, metalPipeline: pipeline)
                    .ignoresSafeArea()
            } else {
                Text("Initializing...")
                    .font(.largeTitle)
            }
        }
        .onAppear {
            metalPipeline = MetalPipeline()
            camera.startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
    }
}
