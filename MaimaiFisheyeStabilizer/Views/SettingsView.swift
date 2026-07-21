import SwiftUI

struct SettingsView: View {
    @Binding var lensProfile: LensProfile
    @Binding var stabilization: StabilizationParams
    var onReCenter: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Lens Profile") {
                    VStack(alignment: .leading) {
                        Text("Focal Length: \(Int(lensProfile.focalLength))")
                        Slider(value: $lensProfile.focalLength, in: 100...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Center X: \(Int(lensProfile.principalPointX))")
                        Slider(value: $lensProfile.principalPointX, in: 0...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Center Y: \(Int(lensProfile.principalPointY))")
                        Slider(value: $lensProfile.principalPointY, in: 0...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("K1: \(String(format: "%.4f", lensProfile.k1))")
                        Slider(value: $lensProfile.k1, in: -1.0...1.0, step: 0.001)
                    }
                    VStack(alignment: .leading) {
                        Text("K2: \(String(format: "%.4f", lensProfile.k2))")
                        Slider(value: $lensProfile.k2, in: -1.0...1.0, step: 0.001)
                    }
                    VStack(alignment: .leading) {
                        Text("K3: \(String(format: "%.4f", lensProfile.k3))")
                        Slider(value: $lensProfile.k3, in: -1.0...1.0, step: 0.001)
                    }
                    VStack(alignment: .leading) {
                        Text("K4: \(String(format: "%.4f", lensProfile.k4))")
                        Slider(value: $lensProfile.k4, in: -1.0...1.0, step: 0.001)
                    }
                }

                Section("Stabilization") {
                    VStack(alignment: .leading) {
                        Text("Strength: \(String(format: "%.2f", stabilization.strength))")
                        Slider(value: $stabilization.strength, in: 0...2.0, step: 0.05)
                    }
                    VStack(alignment: .leading) {
                        Text("Smoothing: \(String(format: "%.2f", stabilization.smoothing))")
                        Slider(value: $stabilization.smoothing, in: 0.01...1.0, step: 0.01)
                    }
                    VStack(alignment: .leading) {
                        Text("Output FOV: \(Int(stabilization.outputFov))°")
                        Slider(value: $stabilization.outputFov, in: 30...180, step: 1)
                    }
                }

                Section {
                    Button(action: onReCenter) {
                        HStack {
                            Spacer()
                            Text("Re-Center")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
