import Foundation

struct LensProfile: Codable, Equatable {
    var name: String
    var focalLength: Float      // Focal length in pixels
    var principalPointX: Float  // Lens center X (pixels)
    var principalPointY: Float  // Lens center Y (pixels)
    var k1: Float               // Fisheye distortion coefficient k1
    var k2: Float               // Fisheye distortion coefficient k2

    static let `default` = LensProfile(
        name: "238° Fisheye",
        focalLength: 500.0,     // Will need calibration for your specific lens
        principalPointX: 960.0, // Half of 1920
        principalPointY: 540.0, // Half of 1080
        k1: 0.0,                // Will need calibration
        k2: 0.0
    )

    // MARK: - Persistence

    private static let storageKey = "LensProfile"

    /// Save this profile to UserDefaults as JSON.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: LensProfile.storageKey)
        } catch {
            os_log("Failed to save LensProfile: %{public}@", type: .error, error.localizedDescription)
        }
    }

    /// Load the saved profile from UserDefaults, or return the default.
    static func load() -> LensProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(LensProfile.self, from: data) else {
            return LensProfile.default
        }
        return profile
    }

    /// Reset to the default profile and clear saved data.
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
