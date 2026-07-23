import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @State private var status = "Step 0: View created"
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(status)
                .foregroundColor(.white)
                .font(.title2)
        }
        .onAppear {
            status = "Step 1: onAppear OK"

            // Skip motion, go straight to camera
            camera.requestPermission { granted in
                if granted {
                    status = "Step 2: permission granted"
                    camera.configure(resolution: settings.resolution)
                    status = "Step 3: camera configured"
                    camera.start()
                    status = "Step 4: camera started - ALL DONE"
                } else {
                    status = "Step 2: permission DENIED"
                }
            }
        }
        .onDisappear {
            camera.stop()
        }
    }
}
