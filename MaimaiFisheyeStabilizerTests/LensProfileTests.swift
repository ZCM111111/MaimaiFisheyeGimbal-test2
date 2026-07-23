import XCTest
@testable import MaimaiFisheyeStabilizer

final class LensProfileTests: XCTestCase {

    func testDefaultCenterMapsToZeroDewarp() {
        let profile = LensProfile.default
        let center = CGPoint(x: 0.5, y: 0.5)
        let out = profile.dewarp(point: center, sourceSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(out.x, 0.0, accuracy: 0.01)
        XCTAssertEqual(out.y, 0.0, accuracy: 0.01)
    }

    func testFocalLengthAffectsScale() {
        var wide = LensProfile.default
        wide.focalLength = 400
        var narrow = LensProfile.default
        narrow.focalLength = 800

        let edge = CGPoint(x: 0.75, y: 0.5)
        let w = wide.dewarp(point: edge, sourceSize: CGSize(width: 1920, height: 1080))
        let n = narrow.dewarp(point: edge, sourceSize: CGSize(width: 1920, height: 1080))

        // Narrower lens (higher f) → smaller output angle
        XCTAssertGreaterThan(abs(w.x), abs(n.x))
    }

    func testK1Distortion() {
        var barrel = LensProfile.default
        barrel.k1 = -0.1

        let pt = CGPoint(x: 0.7, y: 0.5)
        let base = LensProfile.default.dewarp(point: pt, sourceSize: CGSize(width: 1920, height: 1080))
        let distorted = barrel.dewarp(point: pt, sourceSize: CGSize(width: 1920, height: 1080))

        // K1 != 0 should change the output
        XCTAssertNotEqual(base.x, distorted.x, accuracy: 0.001)
    }
}
