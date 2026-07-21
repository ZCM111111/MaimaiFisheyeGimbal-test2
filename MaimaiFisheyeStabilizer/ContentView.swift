import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var metalPipeline = MetalPipeline()
    @StateObject private var motionManager = MotionManager()

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

            // Debug overlay for motion data
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "Roll:  %.3f°", motionManager.roll * 180.0 / .pi))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Text(String(format: "Pitch: %.3f°", motionManager.pitch * 180.0 / .pi))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Text(String(format: "Yaw:   %.3f°", motionManager.yaw * 180.0 / .pi))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            cameraManager.startSession()
            motionManager.start()
        }
        .onDisappear {
            cameraManager.stopSession()
            motionManager.stop()
        }
    }
}

#Preview {
    ContentView()
}
