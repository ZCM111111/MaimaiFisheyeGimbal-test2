import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()
    @State private var metalPipeline: MetalPipeline?
    @State private var lensProfile = LensProfile.default
    @State private var stabilization = StabilizationParams.default
    @State private var isRecording = false
    @State private var showSettings = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingStartTime: Date?
    @State private var recorder = Recorder()
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Camera preview with stabilization
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
                Color.black.ignoresSafeArea()
                ProgressView("Initializing...")
                    .foregroundColor(.white)
            }

            // Status overlay (top-left)
            VStack {
                HStack {
                    StatusOverlay(
                        resolution: "1080p60",
                        isRecording: isRecording,
                        duration: recordingDuration
                    )
                    Spacer()
                }
                .padding()
                Spacer()
            }

            // Controls (bottom)
            VStack {
                Spacer()
                HStack {
                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                    }

                    Spacer()

                    // Record button
                    RecordButton(isRecording: isRecording) {
                        toggleRecording()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                lensProfile: $lensProfile,
                stabilization: $stabilization,
                onReCenter: {
                    motion.reCenter()
                }
            )
        }
        .onAppear {
            metalPipeline = MetalPipeline()
            camera.startSession()
            motion.start()
        }
        .onDisappear {
            camera.stopSession()
            motion.stop()
            if isRecording {
                recorder.stopRecording { _ in }
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            recorder.stopRecording { url in
                isRecording = false
                recordingStartTime = nil
                timer?.invalidate()
                timer = nil
                if let url = url {
                    print("Saved: \(url)")
                }
            }
        } else {
            let timestamp = Int(Date().timeIntervalSince1970)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("maimai_\(timestamp).mov")
            let size = CGSize(width: 1920, height: 1080)
            recorder.startRecording(outputURL: url, size: size)
            isRecording = true
            recordingStartTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let start = recordingStartTime {
                    recordingDuration = Date().timeIntervalSince(start)
                }
            }
        }
    }
}
