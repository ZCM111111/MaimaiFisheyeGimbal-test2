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
            status = "1/4 App launched OK"

            // Step 1: Motion
            let motion = MotionManager()
            motion.start()
            status = "2/4 Motion OK"

            // Step 2: Request camera permission
            let camera = CameraManager()
            camera.requestPermission { granted in
                if granted {
                    status = "3/4 Camera permission OK"

                    // Step 3: Configure and start camera
                    camera.configure(resolution: settings.resolution)
                    camera.start()
                    status = "4/4 Camera started - All OK!"
                } else {
                    status = "❌ Camera permission denied"
                }
            }
        }
    }
}
