import SwiftUI

@main
struct MaimaiFisheyeStabilizerApp: App {
    @StateObject private var settings = StabilizationSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
