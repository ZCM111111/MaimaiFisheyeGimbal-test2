import Foundation

struct LensProfile: Codable, Equatable {
    var name: String
    var focalLength: Float      // Focal length in pixels
    var principalPointX: Float  // Lens center X (pixels)
    var principalPointY: Float  // Lens center Y (pixels)
    var k1: Float               // Fisheye distortion coefficient k1
    var k2: Float               // Fisheye distortion coefficient k2
    var k3: Float               // Fisheye distortion coefficient k3
    var k4: Float               // Fisheye distortion coefficient k4

    static let `default` = LensProfile(
        name: "238° Fisheye",
        focalLength: 500.0,     // Will need calibration for your specific lens
        principalPointX: 960.0, // Half of 1920
        principalPointY: 540.0, // Half of 1080
        k1: 0.0,                // Will need calibration
        k2: 0.0,
        k3: 0.0,
        k4: 0.0
    )
}
