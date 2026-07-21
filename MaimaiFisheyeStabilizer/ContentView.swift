import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var metalPipeline = MetalPipeline()

    var body: some View {
        ZStack {
            if let device = metalPipeline.device {
                CameraPreviewView(
                    device: device,
                    pixelBuffer: cameraManager.currentPixelBuffer
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

#Preview {
    ContentView()
}
