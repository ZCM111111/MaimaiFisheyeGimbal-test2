import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @State private var status = "Step 0: View created"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(status)
                .foregroundColor(.white)
                .font(.title2)
        }
        .onAppear {
            status = "Step 1: onAppear fired"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                status = "Step 2: MotionManager init..."
                let _ = MotionManager()
                status = "Step 3: MotionManager created OK"

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    status = "Step 4: CameraManager init..."
                    let _ = CameraManager()
                    status = "Step 5: CameraManager created OK"
                }
            }
        }
    }
}
