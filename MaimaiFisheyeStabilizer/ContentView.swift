import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var metalPipeline = MetalPipeline()
    @StateObject private var motionManager = MotionManager()

    @State private var lensProfile = LensProfile.load()
    @State private var stabilization = StabilizationParams.load()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            if let device = metalPipeline.device {
                CameraPreviewView(
                    device: device,
                    pixelBuffer: cameraManager.currentPixelBuffer,
                    roll: motionManager.roll,
                    pitch: motionManager.pitch,
                    yaw: motionManager.yaw,
                    lensProfile: lensProfile,
                    stabilization: stabilization
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

            // Top-right settings button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                lensProfile: $lensProfile,
                stabilization: $stabilization,
                onReCenter: {
                    motionManager.resetCenter()
                },
                onSave: {
                    lensProfile.save()
                    stabilization.save()
                },
                onLoad: {
                    lensProfile = LensProfile.load()
                    stabilization = StabilizationParams.load()
                }
            )
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
