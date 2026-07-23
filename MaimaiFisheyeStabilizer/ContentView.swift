import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @State private var status = "Step 0: View created"
    @StateObject private var motion = MotionManager()
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(status)
                .foregroundColor(.white)
                .font(.title2)
        }
        .onAppear {
            status = "Step 1: onAppear"

            // Step 2: Start motion
            motion.start()
            status = "Step 2: motion.start() OK"

            // Step 3: Request camera permission
            camera.requestPermission { granted in
                if granted {
                    status = "Step 3: permission granted"
                    camera.configure(resolution: settings.resolution)
                    status = "Step 4: camera configured"
                    camera.start()
                    status = "Step 5: camera started - ALL DONE"
                } else {
                    status = "Step 3: permission DENIED"
                }
            }
        }
        .onDisappear {
            motion.stop()
            camera.stop()
        }
    }
}
