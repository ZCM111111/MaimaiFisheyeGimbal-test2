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
}
