import CoreMotion
import Combine

class MotionManager: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0

    private let motionManager = CMMotionManager()
    private var referenceAttitude: CMAttitude?

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            self?.handleMotion(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    func reCenter() {
        guard let motion = motionManager.deviceMotion else { return }
        referenceAttitude = motion.attitude.copy() as? CMAttitude
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude

        if let ref = referenceAttitude {
            attitude.multiply(byInverseOf: ref)
        }

        roll = attitude.roll
        pitch = attitude.pitch
        yaw = attitude.yaw
    }
}
