//
//  HorizonRectangleView.swift
//  Stable Action
//
//  A fixed 3:4 viewport centred on screen. The camera preview layer inside
//  counter-rotates + scales against the phone roll so the image is always
//  horizon-locked. Everything outside the rectangle is clipped away.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Motion Manager

final class MotionManager: ObservableObject {

    // ── Published for SwiftUI (HorizonRectangleView overlay) ──────────
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var offsetX: Double = 0.0
    @Published var offsetY: Double = 0.0

    // ── Thread-safe snapshot for CameraManager (read from data-output queue) ──
    private let snapshotLock = NSLock()
    private var _snapRoll:    Double = 0.0
    private var _snapPitch:   Double = 0.0
    private var _snapOffsetX: Double = 0.0
    private var _snapOffsetY: Double = 0.0

    /// Atomic read of the latest motion state — safe to call from any thread.
    func snapshot() -> (roll: Double, offsetX: Double, offsetY: Double, pitch: Double) {
        snapshotLock.lock()
        let r = _snapRoll; let x = _snapOffsetX; let y = _snapOffsetY; let p = _snapPitch
        snapshotLock.unlock()
        return (r, x, y, p)
    }

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()

    // Velocity accumulators (accessed only on motionQueue).
    private var velX: Double = 0.0
    private var velY: Double = 0.0
    // Continuous roll tracking — unwraps atan2 jumps at ±180°
    private var previousRawRoll: Double = 0.0
    private var rollUnwrapped:   Double = 0.0

    // Continuous pitch tracking — unwraps atan2 jumps at ±180°
    private var previousRawPitch: Double = 0.0
    private var pitchUnwrapped:   Double = 0.0

    // ── Tuning constants ──────────────────────────────────────────────
    private let dt: Double = 1.0 / 120.0

    // Velocity decay: controls how fast lateral momentum bleeds off.
    private let velocityDecay: Double = 0.82

    // Position decay: how quickly the crop drifts back to centre when still.
    private let positionDecay: Double = 0.992

    // Sensitivity: maps acceleration (m/s²) to normalised crop offset.
    private let sensitivity: Double = 0.035

    // Acceleration dead-zone: ignore tiny vibrations below this threshold (m/s²).
    private let accelDeadZone: Double = 0.02

    // Pitch tuning
    private let maxPitchRange: Double = .pi / 6    // 30 degrees
    private let pitchDeadZone: Double = 0.005      // ~0.3 degrees

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionQueue.name = "com.stableaction.motion"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive

        motionManager.deviceMotionUpdateInterval = dt
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] data, _ in
            guard let self, let data else { return }

            // ── Roll (continuous 360°, no flip at ±180°) ─────────────────
            let rawRoll = atan2(data.gravity.x, -data.gravity.y)
            var delta = rawRoll - self.previousRawRoll
            if delta >  Double.pi { delta -= 2 * Double.pi }
            if delta < -Double.pi { delta += 2 * Double.pi }
            self.previousRawRoll  = rawRoll
            self.rollUnwrapped   += delta
            let newRoll = self.rollUnwrapped

            // ── Pitch (continuous, no flip at ±180°) ────────────────────
            let rawPitch = atan2(data.gravity.y, -data.gravity.z)
            var pitchDelta = rawPitch - self.previousRawPitch
            if pitchDelta >  Double.pi { pitchDelta -= 2 * Double.pi }
            if pitchDelta < -Double.pi { pitchDelta += 2 * Double.pi }
            self.previousRawPitch  = rawPitch
            self.pitchUnwrapped   += pitchDelta

            var newPitch = self.pitchUnwrapped
            // Dead-zone: hold previous value when wobble is sub-threshold
            if abs(pitchDelta) < self.pitchDeadZone {
                newPitch = self._snapPitch
            }

            // ── Translation (X/Y shift) ───────────────────────────────
            var ax = data.userAcceleration.x
            var ay = data.userAcceleration.y

            // Dead-zone: kill micro-vibrations that cause jitter
            if abs(ax) < self.accelDeadZone { ax = 0 }
            if abs(ay) < self.accelDeadZone { ay = 0 }

            // Integrate acceleration → velocity, then decay
            self.velX = (self.velX + ax * self.dt) * self.velocityDecay
            self.velY = (self.velY + ay * self.dt) * self.velocityDecay

            // Integrate velocity → offset, then decay toward centre
            // Negate: if phone jerks right we shift crop left to compensate
            var newOffX = (self._snapOffsetX - self.velX * self.sensitivity) * self.positionDecay
            var newOffY = (self._snapOffsetY - self.velY * self.sensitivity) * self.positionDecay

            // Clamp to ±1
            newOffX = max(-1.0, min(1.0, newOffX))
            newOffY = max(-1.0, min(1.0, newOffY))

            // Write to thread-safe snapshot (for CameraManager)
            self.snapshotLock.lock()
            self._snapRoll    = newRoll
            self._snapPitch   = newPitch
            self._snapOffsetX = newOffX
            self._snapOffsetY = newOffY
            self.snapshotLock.unlock()

            // Publish to main thread for SwiftUI overlay
            DispatchQueue.main.async {
                self.roll    = newRoll
                self.pitch   = newPitch
                self.offsetX = newOffX
                self.offsetY = newOffY
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        snapshotLock.lock()
        _snapRoll = 0; _snapPitch = 0; _snapOffsetX = 0; _snapOffsetY = 0
        snapshotLock.unlock()
        velX = 0; velY = 0
        previousRawRoll = 0; rollUnwrapped = 0
        previousRawPitch = 0; pitchUnwrapped = 0
        DispatchQueue.main.async { [weak self] in
            self?.roll = 0; self?.pitch = 0; self?.offsetX = 0; self?.offsetY = 0
        }
    }
}

// MARK: - Horizon Rectangle View

struct HorizonRectangleView: View {

    @ObservedObject var motion: MotionManager

    var body: some View {
        GeometryReader { geo in
            let cW = geo.size.width
            let cH = geo.size.height

            let rectW = min(cW, cH) * (3.0 / 5.0) * 0.90
            let rectH = rectW * (4.0 / 3.0)

            // Counter-rotate so the rectangle stays upright
            let angle = -motion.roll

            // Shift to match the crop translation offset.
            // Available margin on each side = (containerDim - rectDim) / 2
            let marginX = (cW - rectW) / 2
            let marginY = (cH - rectH) / 2
            let shiftX  = CGFloat(motion.offsetX) * marginX * 0.9
            let shiftY  = CGFloat(motion.offsetY) * marginY * 0.9

            // Pitch-based vertical shift
            let maxPitch = CGFloat(Double.pi / 6)
            let pitchNorm = max(-1.0, min(1.0, CGFloat(motion.pitch) / maxPitch))
            let pitchShiftY = pitchNorm * marginY

            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                ViewfinderCorners()
                    .stroke(
                        Color.yellow,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
            }
            .frame(width: rectW, height: rectH)
            .rotationEffect(.radians(angle))
            .position(x: cW / 2 + shiftX, y: cH / 2 - shiftY + pitchShiftY)
        }
    }
}

// MARK: - Corner brackets

private struct ViewfinderCorners: Shape {
    private let arm: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let a = arm
        let r = rect.insetBy(dx: 1, dy: 1)

        // Top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + a))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + a, y: r.minY))

        // Top-right
        p.move(to: CGPoint(x: r.maxX - a, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + a))

        // Bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - a))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - a, y: r.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: r.minX + a, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - a))
        return p
    }
}
