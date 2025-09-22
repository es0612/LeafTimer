import SwiftUI

struct TimerControlsView: View {
    let onPlayPause: () -> Void
    let onReset: () -> Void
    let state: TimerControlState.State

    private var buttonText: String {
        switch state {
        case .idle:
            return "START"
        case .running:
            return "PAUSE"
        case .paused:
            return "RESUME"
        }
    }

    private var buttonColor: Color {
        switch state {
        case .idle:
            return Color(red: 0.3, green: 0.65, blue: 0.4)
        case .running:
            return Color(red: 0.85, green: 0.45, blue: 0.35)
        case .paused:
            return Color(red: 0.95, green: 0.7, blue: 0.3)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Main Control Button
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    buttonColor,
                                    buttonColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)

                    Text(buttonText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .shadow(color: buttonColor.opacity(0.3), radius: 8, x: 0, y: 4)
            .accessibilityLabel(buttonText)
            .accessibilityHint("Tap to \(buttonText.lowercased()) the timer")

            // Reset Button
            if state != .idle {
                Button(action: onReset) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color.gray.opacity(0.8))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3), value: state)
                .accessibilityLabel("Reset")
                .accessibilityHint("Tap to reset the timer")
            }
        }
        .padding()
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct TimerControlsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            TimerControlsView(
                onPlayPause: {},
                onReset: {},
                state: .idle
            )
            TimerControlsView(
                onPlayPause: {},
                onReset: {},
                state: .running
            )
            TimerControlsView(
                onPlayPause: {},
                onReset: {},
                state: .paused
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}