import SwiftUI

// MARK: - Timer Card

struct TimerCard: View {
    let title: String
    let time: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textSecondary)

            Text(time)
                .font(.timerDisplay)
                .foregroundColor(color)
                .monospacedDigit()

            ProgressRing(progress: 0.75, lineWidth: 8, foregroundColor: color, backgroundColor: Color.gray.opacity(0.2))
                .frame(width: 120, height: 120)
        }
        .padding(24)
        .background(Color.backgroundSecondary)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            IconBadge(systemName: icon, color: .primaryGreen)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Text(value)
                    .font(.sessionCount)
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}