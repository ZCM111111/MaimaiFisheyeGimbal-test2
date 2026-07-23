import SwiftUI

struct StatusOverlayView: View {
    @EnvironmentObject var settings: StabilizationSettings

    var body: some View {
        HStack {
            Text(settings.resolution.rawValue)
                .font(.caption.monospaced())
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(4)

            if case .recording(let duration) = settings.recordingState {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(formatDuration(duration))
                        .font(.caption.monospaced())
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
            }

            Spacer()
        }
        .padding(8)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
