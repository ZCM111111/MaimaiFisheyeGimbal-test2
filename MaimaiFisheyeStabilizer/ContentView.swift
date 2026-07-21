import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var metalPipeline = MetalPipeline()
    @StateObject private var motionManager = MotionManager()

    // MARK: - Default Lens Parameters for 238° fisheye
    private let defaultStrength: Double = 1.0
    private let defaultOutputFov: Double = 100.0
    private let defaultFocalLength: Double = 500.0
    private let defaultPrincipalPointX: Double = 960.0
    private let defaultPrincipalPointY: Double = 540.0
    private let defaultK1: Double = 0.0
    private let defaultK2: Double = 0.0

    var body: some View {
        ZStack {
            if let device = metalPipeline.device {
                CameraPreviewView(
                    device: device,
                    pixelBuffer: cameraManager.currentPixelBuffer,
                    roll: motionManager.roll,
                    pitch: motionManager.pitch,
                    yaw: motionManager.yaw,
                    strength: defaultStrength,
                    outputFov: defaultOutputFov,
                    focalLength: defaultFocalLength,
                    principalPointX: defaultPrincipalPointX,
                    principalPointY: defaultPrincipalPointY,
                    k1: defaultK1,
                    k2: defaultK2
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
