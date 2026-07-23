import SwiftUI
import MetalKit

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()
    @State private var pipeline: MetalPipeline?
    @State private var showSettings = false
    @State private var recorder: Recorder?
    @State private var setupLog: [String] = []
    @State private var isReady = false

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

            // Debug log overlay (always visible)
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(setupLog.indices, id: \.self) { i in
                        Text(setupLog[i])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(setupLog[i].contains("❌") ? .red :
                                             setupLog[i].contains("✅") ? .green : .white)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .padding(.bottom, 100)
            }

            VStack {
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
            setup()
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

    private func setup() {
        log("1/5 Creating Metal pipeline...")
        guard let pipe = MetalPipeline() else {
            log("❌ Metal pipeline failed")
            return
        }
        pipeline = pipe
        log("✅ Metal pipeline OK")

        log("2/5 Configuring camera (\(settings.resolution.rawValue))...")
        camera.configure(resolution: settings.resolution)
        log("✅ Camera configured")

        log("3/5 Starting camera...")
        camera.start()
        log("✅ Camera started")

        log("4/5 Starting motion...")
        motion.start()
        log("✅ Motion started")

        log("5/5 Enabling preview...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isReady = true
            log("✅ Preview active")
        }
    }

    private func log(_ msg: String) {
        setupLog.append(msg)
        // Keep only last 8 lines
        if setupLog.count > 8 {
            setupLog.removeFirst()
        }
        print("[MaimaiStab] \(msg)")
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
