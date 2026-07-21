import CoreMotion
import Combine

class MotionManager: ObservableObject {
    // MARK: - Published Properties
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0

    // MARK: - Configuration
    var smoothingAlpha: Double = 0.15

    // MARK: - Private State
    private let motionManager = CMMotionManager()

    // Raw angles (for unwrapping)
    private var previousRawRoll: Double = 0.0
    private var previousRawPitch: Double = 0.0
    private var previousRawYaw: Double = 0.0

    // Unwrapped angles (continuous, no ±180° jumps)
    private var unwrappedRoll: Double = 0.0
    private var unwrappedPitch: Double = 0.0
    private var unwrappedYaw: Double = 0.0

    // Smoothed angles
    private var smoothedRoll: Double = 0.0
    private var smoothedPitch: Double = 0.0
    private var smoothedYaw: Double = 0.0

    // Reference (center) angles for resetCenter()
    private var referenceRoll: Double = 0.0
    private var referencePitch: Double = 0.0
    private var referenceYaw: Double = 0.0

    // Track if we have received at least one update
    private var hasFirstReading: Bool = false

    // MARK: - Public Methods

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available on this device.")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0 // 120 Hz

        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.handleMotion(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    func resetCenter() {
        referenceRoll = smoothedRoll
        referencePitch = smoothedPitch
        referenceYaw = smoothedYaw
    }

    // MARK: - Private Methods

    private func handleMotion(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude

        let rawRoll = attitude.roll
        let rawPitch = attitude.pitch
        let rawYaw = attitude.yaw

        if !hasFirstReading {
            // Initialize all state with first reading
            previousRawRoll = rawRoll
            previousRawPitch = rawPitch
            previousRawYaw = rawYaw

            unwrappedRoll = rawRoll
            unwrappedPitch = rawPitch
            unwrappedYaw = rawYaw

            smoothedRoll = rawRoll
            smoothedPitch = rawPitch
            smoothedYaw = rawYaw

            referenceRoll = rawRoll
            referencePitch = rawPitch
            referenceYaw = rawYaw

            hasFirstReading = true

            updatePublishedValues()
            return
        }

        // Angle unwrapping: handle ±180° boundary crossings
        unwrappedRoll = unwrapAngle(new: rawRoll, previous: previousRawRoll, accumulated: unwrappedRoll)
        unwrappedPitch = unwrapAngle(new: rawPitch, previous: previousRawPitch, accumulated: unwrappedPitch)
        unwrappedYaw = unwrapAngle(new: rawYaw, previous: previousRawYaw, accumulated: unwrappedYaw)

        // Update previous raw values
        previousRawRoll = rawRoll
        previousRawPitch = rawPitch
        previousRawYaw = rawYaw

        // Exponential moving average smoothing
        smoothedRoll = smoothingAlpha * unwrappedRoll + (1.0 - smoothingAlpha) * smoothedRoll
        smoothedPitch = smoothingAlpha * unwrappedPitch + (1.0 - smoothingAlpha) * smoothedPitch
        smoothedYaw = smoothingAlpha * unwrappedYaw + (1.0 - smoothingAlpha) * smoothedYaw

        updatePublishedValues()
    }

    /// Unwraps an angle to maintain continuity across ±π boundaries.
    /// When the raw angle jumps by more than π, we add/subtract 2π to maintain continuity.
    private func unwrapAngle(new: Double, previous: Double, accumulated: Double) -> Double {
        let delta = new - previous

        if delta > .pi {
            // Jumped backward across the boundary (e.g., 179° to -179°)
            return accumulated + delta - 2.0 * .pi
        } else if delta < -.pi {
            // Jumped forward across the boundary (e.g., -179° to 179°)
            return accumulated + delta + 2.0 * .pi
        } else {
            // Normal small change
            return accumulated + delta
        }
    }

    private func updatePublishedValues() {
        // Subtract reference (center) to get relative angles
        roll = smoothedRoll - referenceRoll
        pitch = smoothedPitch - referencePitch
        yaw = smoothedYaw - referenceYaw
    }
}
