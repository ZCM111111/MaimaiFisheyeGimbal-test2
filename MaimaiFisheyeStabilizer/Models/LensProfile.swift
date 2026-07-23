import Foundation
import CoreGraphics

/// User-tunable fisheye lens parameters for dewarp.
/// Equidistant projection model: r = focalLength * theta.
struct LensProfile: Codable, Equatable {
    /// Focal length in pixel scale (roughly sensor width / π for 180° coverage).
    var focalLength: Double = 600.0

    /// Optical center as fraction of image dimensions (0.0 – 1.0).
    var centerX: Double = 0.5
    var centerY: Double = 0.5

    /// Radial distortion coefficients K1, K2.
    /// r_distorted = r * (1 + k1*r² + k2*r⁴)
    var k1: Double = 0.0
    var k2: Double = 0.0

    /// Scale applied to dewarped output (tighter = narrower field of view).
    var outputScale: Double = 1.0

    /// Map a normalized fisheye texture coordinate to a normalized rectilinear coordinate.
    /// Returns (rx, ry) in [-1, 1] range.
    func dewarp(point: CGPoint, sourceSize: CGSize) -> CGPoint {
        let px = centerX * sourceSize.width
        let py = centerY * sourceSize.height

        let dx = point.x * sourceSize.width - px
        let dy = point.y * sourceSize.height - py
        let r = hypot(dx, dy)

        guard r > 1e-6 else { return CGPoint(x: 0, y: 0) }

        // Undistort radius
        let rNorm = r / max(sourceSize.width, sourceSize.height)
        let distortion = 1.0 + k1 * rNorm * rNorm + k2 * rNorm * rNorm * rNorm * rNorm
        let rUndistorted = r / distortion

        // Angle from equidistant model
        let thetaRaw = rUndistorted / focalLength

        // Direction from optical center
        let nx = dx / r
        let ny = dy / r

        // Rectilinear projection: x = tan(θ) * nx, y = tan(θ) * ny
        let scale = tan(thetaRaw) / max(abs(nx), abs(ny), 0.01)
        let rx = nx * scale / outputScale
        let ry = ny * scale / outputScale

        return CGPoint(x: rx, y: ry)
    }

    static let `default` = LensProfile()
}
