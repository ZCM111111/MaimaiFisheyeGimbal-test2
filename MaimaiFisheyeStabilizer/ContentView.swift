import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @State private var status = "Starting..."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Maimai Fisheye Gimbal")
                    .font(.title)
                    .foregroundColor(.white)

                Text(status)
                    .font(.body)
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .onAppear {
            status = "App launched OK"

            // Step 1: Test Motion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let motion = MotionManager()
                motion.start()
                status = "Motion OK"

                // Step 2: Test Camera
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let camera = CameraManager()
                    camera.configure(resolution: settings.resolution)
                    camera.start()
                    status = "Camera OK"

                    // Step 3: Test Metal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let _ = MetalPipeline() {
                            status = "All OK - Ready to go!"
                        } else {
                            status = "⚠️ Metal init failed"
                        }
                    }
                }
            }
        }
    }
}
