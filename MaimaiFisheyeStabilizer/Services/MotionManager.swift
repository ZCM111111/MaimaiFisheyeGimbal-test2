import CoreMotion
import simd

class MotionManager: ObservableObject {
    // Current orientation as quaternion (x, y, z, w)
    @Published var orientation: Quat = .identity

    // Reference orientation (what we consider "stable")
    private var referenceOrientation: Quat = .identity

    // Raw quaternion from CMDeviceMotion
    private var rawQuat: Quat = .identity

    // Smoothing
    private var smoothedQuat: Quat = .identity
    private let smoothingAlpha: Float = 0.15 // Lower = smoother, higher = more responsive

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0 // 120 Hz
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            self?.handleMotion(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    // Re-center: set current orientation as the reference
    func reCenter() {
        referenceOrientation = smoothedQuat
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
        let q = motion.attitude.quaternion

        // Convert CMQuaternion to SIMD4<Float> (x,y,z,w)
        rawQuat = Quat(Float(q.x), Float(q.y), Float(q.z), Float(q.w))

        // Apply exponential moving average smoothing
        smoothedQuat = slerp(smoothedQuat, rawQuat, alpha: smoothingAlpha)

        // The orientation relative to reference
        // orientation = inverse(reference) * current
        // This gives us the rotation FROM reference TO current
        orientation = quatMul(quatConj(referenceOrientation), smoothedQuat)
    }

    // Quaternion SLERP for smooth interpolation
    private func slerp(_ a: Quat, _ b: Quat, alpha: Float) -> Quat {
        var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

        // If dot is negative, negate one quaternion to take the shorter path
        var b = b
        if dot < 0 {
            b = Quat(-b.x, -b.y, -b.z, -b.w)
            dot = -dot
        }

        // If quaternions are very close, use linear interpolation
        if dot > 0.9995 {
            let result = Quat(
                a.x + alpha * (b.x - a.x),
                a.y + alpha * (b.y - a.y),
                a.z + alpha * (b.z - a.z),
                a.w + alpha * (b.w - a.w)
            )
            return normalizeQuat(result)
        }

        let theta = acos(dot)
        let sinTheta = sin(theta)
        let aFactor = sin((1 - alpha) * theta) / sinTheta
        let bFactor = sin(alpha * theta) / sinTheta

        return Quat(
            a.x * aFactor + b.x * bFactor,
            a.y * aFactor + b.y * bFactor,
            a.z * aFactor + b.z * bFactor,
            a.w * aFactor + b.w * bFactor
        )
    }

    private func normalizeQuat(_ q: Quat) -> Quat {
        let len = sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
        if len < 1e-6 { return .identity }
        return Quat(q.x / len, q.y / len, q.z / len, q.w / len)
    }
}

// Quaternion math helpers
func quatMul(_ a: Quat, _ b: Quat) -> Quat {
    return Quat(
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
    )
}

func quatConj(_ q: Quat) -> Quat {
    return Quat(-q.x, -q.y, -q.z, q.w)
}
