import Foundation
import AVFoundation

/// Observable settings shared across the app.
final class StabilizationSettings: ObservableObject {
    // MARK: - Resolution

    enum Resolution: String, CaseIterable, Identifiable {
        case hd1080p60 = "1080p60"
        case uhd4k60   = "4K60"

        var id: String { rawValue }

        var preset: AVCaptureSession.Preset {
            switch self {
            case .hd1080p60: return .hd1920x1080
            case .uhd4k60:   return .hd4K3840x2160
            }
        }

        var size: CGSize {
            switch self {
            case .hd1080p60: return CGSize(width: 1920, height: 1080)
            case .uhd4k60:   return CGSize(width: 3840, height: 2160)
            }
        }
    }

    @Published var resolution: Resolution = .hd1080p60

    // MARK: - Stabilization strength

    /// 0.0 = off, 1.0 = full compensation
    @Published var strength: Double = 1.0

    /// Exponential smoothing factor (0.0 = raw, 1.0 = heavy smoothing)
    @Published var smoothing: Double = 0.85

    // MARK: - Max compensation per axis (degrees)

    @Published var maxRollDeg: Double = 45.0
    @Published var maxPitchDeg: Double = 45.0
    @Published var maxYawDeg: Double = 45.0

    // MARK: - Output field of view

    @Published var outputFovDeg: Double = 100.0

    // MARK: - Lens

    @Published var lensProfile: LensProfile = .default

    // MARK: - Recording

    @Published var recordingState: RecordingState = .idle
}

// MARK: - Recording State

enum RecordingState {
    case idle
    case recording(duration: TimeInterval)
    case error(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}
