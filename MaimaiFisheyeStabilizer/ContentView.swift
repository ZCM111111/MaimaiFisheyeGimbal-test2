import SwiftUI
import MetalKit
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var metalPipeline = MetalPipeline()
    @StateObject private var motionManager = MotionManager()
    @StateObject private var recorder = Recorder()

    @State private var lensProfile = LensProfile.load()
    @State private var stabilization = StabilizationParams.load()
    @State private var showSettings = false
    @State private var outputResolution: OutputResolution = .p1080

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

            // Recording controls overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        StatusOverlay(
                            resolution: outputResolution.label,
                            isRecording: recorder.isRecording,
                            duration: recorder.recordingDuration
                        )
                        RecordButton(isRecording: recorder.isRecording) {
                            toggleRecording()
                        }
                        if let error = recorder.recordingError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 32)
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
            setupFrameForwarding()
        }
        .onDisappear {
            cameraManager.stopSession()
            motionManager.stop()
        }
    }

    private func setupFrameForwarding() {
        cameraManager.onFrameCaptured = { [weak recorder] pixelBuffer, presentationTime in
            if let recorder = recorder, recorder.isRecording {
                recorder.writeFrame(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
            } else {
                CVPixelBufferRelease(pixelBuffer)
            }
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording {
                // Recording stopped
            }
        } else {
            let outputURL = generateOutputURL()
            let size = outputResolution.size
            recorder.startRecording(outputURL: outputURL, size: size)
        }
    }

    private func generateOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "Maimai_\(formatter.string(from: Date())).mov"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(filename)
    }
}

#Preview {
    ContentView()
}

enum OutputResolution: String, CaseIterable {
    case p1080 = "1080p"
    case p4K = "4K"

    var label: String {
        switch self {
        case .p1080: return "1080p"
        case .p4K: return "4K"
        }
    }

    var size: CGSize {
        switch self {
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p4K: return CGSize(width: 3840, height: 2160)
        }
    }
}
