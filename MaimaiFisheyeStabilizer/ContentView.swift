import SwiftUI
import MetalKit

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()
    @State private var pipeline: MetalPipeline?
    @State private var showSettings = false
    @State private var recorder: Recorder?
    @State private var isReady = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let pipeline, isReady {
                MetalPreviewView(
                    pipeline: pipeline,
                    camera: camera,
                    motion: motion,
                    settings: settings,
                    recorder: recorder
                )
                .ignoresSafeArea()
            }

            // Error overlay
            if let errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }

            VStack {
                StatusOverlayView()
                Spacer()

                HStack(spacing: 40) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Button { toggleRecording() } label: {
                        Circle()
                            .fill(settings.recordingState.isRecording ? .red : .white)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 4))
                    }

                    Button { motion.recenter() } label: {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            setupPipeline()
        }
        .onDisappear {
            camera.stop()
            motion.stop()
        }
        .onChange(of: settings.resolution) { _ in
            camera.stop()
            camera.configure(resolution: settings.resolution)
            camera.start()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }

    private func setupPipeline() {
        // Initialize Metal
        guard let pipe = MetalPipeline() else {
            errorMessage = "Metal not supported on this device"
            return
        }
        pipeline = pipe

        // Configure camera
        camera.configure(resolution: settings.resolution)

        // Start services
        camera.start()
        motion.start()

        // Mark ready after a brief delay to let camera warm up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isReady = true
        }
    }

    private func toggleRecording() {
        if settings.recordingState.isRecording {
            recorder?.stop()
            recorder = nil
            settings.recordingState = .idle
        } else {
            recorder = Recorder(resolution: settings.resolution.size)
            recorder?.start()
            settings.recordingState = .recording(duration: 0)
        }
    }
}
