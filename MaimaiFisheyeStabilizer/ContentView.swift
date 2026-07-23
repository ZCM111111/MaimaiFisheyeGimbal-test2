import SwiftUI
import MetalKit

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()
    @State private var pipeline: MetalPipeline?
    @State private var showSettings = false
    @State private var recorder: Recorder?

    var body: some View {
        ZStack {
            if let pipeline {
                MetalPreviewView(
                    pipeline: pipeline,
                    camera: camera,
                    motion: motion,
                    settings: settings,
                    recorder: recorder
                )
                .ignoresSafeArea()
            }

            VStack {
                StatusOverlayView()
                Spacer()

                HStack(spacing: 40) {
                    // Settings
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    // Record
                    Button { toggleRecording() } label: {
                        Circle()
                            .fill(settings.recordingState.isRecording ? .red : .white)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 4))
                    }

                    // Re-center
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
            pipeline = MetalPipeline()
            camera.configure(resolution: settings.resolution)
            camera.start()
            motion.start()
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
