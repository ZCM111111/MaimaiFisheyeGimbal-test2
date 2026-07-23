import Foundation
import CoreMotion

final class MotionManager: ObservableObject {
    private let mm = CMMotionManager()

    // Published for display; shader reads via snapshot()
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0

    // Reference orientation set on recenter
    private var refRoll: Double = 0.0
    private var refPitch: Double = 0.0
    private var refYaw: Double = 0.0

    // Unwrap accumulators
    private var rollUnwrapped: Double = 0.0
    private var pitchUnwrapped: Double = 0.0
    private var yawUnwrapped: Double = 0.0
    private var prevRoll: Double = 0.0
    private var prevPitch: Double = 0.0
    private var prevYaw: Double = 0.0

    // Smoothing state
    private var smoothedRoll: Double = 0.0
    private var smoothedPitch: Double = 0.0
    private var smoothedYaw: Double = 0.0

    private let updateInterval: TimeInterval = 1.0 / 120.0

    init() {
        guard mm.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available")
            return
        }
        mm.deviceMotionUpdateInterval = updateInterval
    }

    func start() {
        guard mm.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available, skipping start")
            return
        }
        mm.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, error in
            guard let self, let data = data else { return }
            let attitude = data.attitude

            // Unwrap angles to avoid ±π jumps
            let rawRoll  = attitude.roll
            let rawPitch = attitude.pitch
            let rawYaw   = attitude.yaw

            self.rollUnwrapped  += Self.angleDelta(self.prevRoll, rawRoll)
            self.pitchUnwrapped += Self.angleDelta(self.prevPitch, rawPitch)
            self.yawUnwrapped   += Self.angleDelta(self.prevYaw, rawYaw)

            self.prevRoll  = rawRoll
            self.prevPitch = rawPitch
            self.prevYaw   = rawYaw

            // Subtract reference
            let r = self.rollUnwrapped  - self.refRoll
            let p = self.pitchUnwrapped - self.refPitch
            let y = self.yawUnwrapped   - self.refYaw

            // Smooth (EMA)
            let alpha = 0.85
            self.smoothedRoll  += alpha * (r - self.smoothedRoll)
            self.smoothedPitch += alpha * (p - self.smoothedPitch)
            self.smoothedYaw   += alpha * (y - self.smoothedYaw)

            self.roll  = self.smoothedRoll
            self.pitch = self.smoothedPitch
            self.yaw   = self.smoothedYaw
        }
    }

    func stop() {
        mm.stopDeviceMotionUpdates()
    }

    /// Reset reference orientation to current pose (re-center).
    func recenter() {
        refRoll  = rollUnwrapped
        refPitch = pitchUnwrapped
        refYaw   = yawUnwrapped
    }

    /// Non-mutating snapshot for the render loop — avoids races.
    func snapshot() -> (roll: Double, pitch: Double, yaw: Double) {
        return (roll, pitch, yaw)
    }

    // MARK: - Angle delta for unwrapping

    private static func angleDelta(_ prev: Double, _ curr: Double) -> Double {
        var d = curr - prev
        while d >  .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }
}
