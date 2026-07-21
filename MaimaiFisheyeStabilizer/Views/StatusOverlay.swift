import SwiftUI

struct StatusOverlay: View {
    var resolution: String
    var isRecording: Bool
    var duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(resolution)
                .font(.caption)
                .foregroundColor(.white)
            if isRecording {
                Text("REC \(formatDuration(duration))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
