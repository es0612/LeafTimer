import SwiftUI

struct TimerDisplayView: View {
    let currentTime: Int
    let isRunning: Bool
    let mode: TimerMode.Mode

    private var timeString: String {
        let minutes = currentTime / 60
        let seconds = currentTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var modeColor: Color {
        switch mode {
        case .work:
            return Color(red: 0.4, green: 0.65, blue: 0.45)
        case .break:
            return Color(red: 0.45, green: 0.55, blue: 0.7)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(timeString)
                .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            modeColor.opacity(0.8),
                            modeColor.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                .scaleEffect(isRunning ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isRunning)

            Text(mode == .work ? "Work Session" : "Break Time")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(modeColor.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.vertical, 20)
        .accessibilityLabel("Timer showing \(timeString)")
        .accessibilityHint(mode == .work ? "Work session in progress" : "Break time in progress")
    }
}

struct TimerDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TimerDisplayView(
                currentTime: 1500,
                isRunning: false,
                mode: .work
            )
            TimerDisplayView(
                currentTime: 300,
                isRunning: true,
                mode: .break
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}