import SwiftUI

struct RecordButton: View {
    var isRecording: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner circle / stop square
                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
    }
}
