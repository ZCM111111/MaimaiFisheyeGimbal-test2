import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()

    var body: some View {
        Text("Camera running: \(camera.frame != nil ? "YES" : "NO")")
            .font(.largeTitle)
            .onAppear {
                camera.startSession()
            }
            .onDisappear {
                camera.stopSession()
            }
    }
}
