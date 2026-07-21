import Foundation

struct StabilizationParams: Codable {
    var strength: Float
    var smoothing: Float
    var maxOffset: Float
    var outputFov: Float

    static let `default` = StabilizationParams(
        strength: 1.0,
        smoothing: 0.15,
        maxOffset: 0.5,
        outputFov: 100.0
    )

    // MARK: - Persistence

    private static let storageKey = "StabilizationParams"

    /// Save these parameters to UserDefaults as JSON.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: StabilizationParams.storageKey)
        } catch {
            os_log("Failed to save StabilizationParams: %{public}@", type: .error, error.localizedDescription)
        }
    }

    /// Load saved parameters from UserDefaults, or return the default.
    static func load() -> StabilizationParams {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let params = try? JSONDecoder().decode(StabilizationParams.self, from: data) else {
            return StabilizationParams.default
        }
        return params
    }

    /// Reset to the default parameters and clear saved data.
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
