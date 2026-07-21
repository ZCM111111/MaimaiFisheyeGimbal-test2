import Foundation

struct LensProfile: Codable, Equatable {
    var name: String
    var focalLength: Float
    var principalPointX: Float
    var principalPointY: Float
    var k1: Float
    var k2: Float

    static let `default` = LensProfile(
        name: "238° Fisheye",
        focalLength: 500.0,
        principalPointX: 960.0,
        principalPointY: 540.0,
        k1: 0.0,
        k2: 0.0
    )
}
