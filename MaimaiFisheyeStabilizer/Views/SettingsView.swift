import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: StabilizationSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // ── Resolution ───────────────────────────
                Section("Resolution") {
                    Picker("Mode", selection: $settings.resolution) {
                        ForEach(StabilizationSettings.Resolution.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ── Stabilization ────────────────────────
                Section("Stabilization") {
                    VStack(alignment: .leading) {
                        Text("Strength: \(Int(settings.strength * 100))%")
                        Slider(value: $settings.strength, in: 0...1, step: 0.05)
                    }
                    VStack(alignment: .leading) {
                        Text("Smoothing: \(Int(settings.smoothing * 100))%")
                        Slider(value: $settings.smoothing, in: 0...1, step: 0.05)
                    }
                }

                // ── Angle limits ─────────────────────────
                Section("Max Compensation (deg)") {
                    HStack {
                        Text("R")
                        Slider(value: $settings.maxRollDeg, in: 5...90, step: 1)
                            .tint(.red)
                        Text("\(Int(settings.maxRollDeg))°")
                            .frame(width: 36)
                    }
                    HStack {
                        Text("P")
                        Slider(value: $settings.maxPitchDeg, in: 5...90, step: 1)
                            .tint(.green)
                        Text("\(Int(settings.maxPitchDeg))°")
                            .frame(width: 36)
                    }
                    HStack {
                        Text("Y")
                        Slider(value: $settings.maxYawDeg, in: 5...90, step: 1)
                            .tint(.blue)
                        Text("\(Int(settings.maxYawDeg))°")
                            .frame(width: 36)
                    }
                }

                // ── Output FOV ───────────────────────────
                Section("Output Horizontal FOV") {
                    VStack(alignment: .leading) {
                        Text("\(Int(settings.outputFovDeg))°")
                        Slider(value: $settings.outputFovDeg, in: 40...180, step: 1)
                    }
                }

                // ── Lens profile ─────────────────────────
                Section("Lens (238° Fish-Eye)") {
                    VStack(alignment: .leading) {
                        Text("Focal length: \(Int(settings.lensProfile.focalLength))")
                        Slider(value: lensBinding(\.focalLength), in: 200...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Center X: \(settings.lensProfile.centerX, specifier: "%.3f")")
                        Slider(value: lensBinding(\.centerX), in: 0.3...0.7, step: 0.001)
                    }
                    VStack(alignment: .leading) {
                        Text("Center Y: \(settings.lensProfile.centerY, specifier: "%.3f")")
                        Slider(value: lensBinding(\.centerY), in: 0.3...0.7, step: 0.001)
                    }
                    VStack(alignment: .leading) {
                        Text("K1: \(settings.lensProfile.k1, specifier: "%.4f")")
                        Slider(value: lensBinding(\.k1), in: -0.5...0.5, step: 0.0005)
                    }
                    VStack(alignment: .leading) {
                        Text("K2: \(settings.lensProfile.k2, specifier: "%.4f")")
                        Slider(value: lensBinding(\.k2), in: -0.5...0.5, step: 0.0005)
                    }
                    VStack(alignment: .leading) {
                        Text("Output scale: \(settings.lensProfile.outputScale, specifier: "%.2f")")
                        Slider(value: lensBinding(\.outputScale), in: 0.25...4.0, step: 0.05)
                    }
                }

                // ── Info ─────────────────────────────────
                Section("Info") {
                    Text("Lens: 238° super fish-eye")
                    Text("Model: Equidistant (f·θ)")
                    Text("Shader: Single-pass Metal")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Create a Binding to a nested LensProfile property.
    private func lensBinding(_ keyPath: WritableKeyPath<LensProfile, Double>) -> Binding<Double> {
        Binding(
            get: { settings.lensProfile[keyPath: keyPath] },
            set: { settings.lensProfile[keyPath: keyPath] = $0 }
        )
    }
}
