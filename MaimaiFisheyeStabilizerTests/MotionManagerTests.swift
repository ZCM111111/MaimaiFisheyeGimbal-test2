import XCTest
@testable import MaimaiFisheyeStabilizer

final class MotionManagerTests: XCTestCase {

    func testSnapshotReturnsDefaultsInitially() {
        let mm = MotionManager()
        let snap = mm.snapshot()
        XCTAssertEqual(snap.roll, 0.0)
        XCTAssertEqual(snap.pitch, 0.0)
        XCTAssertEqual(snap.yaw, 0.0)
    }

    func testRecenterDoesNotCrash() {
        let mm = MotionManager()
        mm.recenter()
        let snap = mm.snapshot()
        // After recenter, all values should be close to 0
        XCTAssertEqual(snap.roll, 0.0, accuracy: 0.1)
        XCTAssertEqual(snap.pitch, 0.0, accuracy: 0.1)
        XCTAssertEqual(snap.yaw, 0.0, accuracy: 0.1)
    }
}
