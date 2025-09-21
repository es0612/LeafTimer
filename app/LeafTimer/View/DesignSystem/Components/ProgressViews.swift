import SwiftUI

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var foregroundColor: Color = .primaryGreen
    var backgroundColor: Color = Color.gray.opacity(0.2)

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Progress text
            Text("\(Int(progress * 100))%")
                .font(.sessionCount)
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Icon Badge

struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(.white)
            .frame(width: size * 1.8, height: size * 1.8)
            .background(color)
            .clipShape(Circle())
    }
}