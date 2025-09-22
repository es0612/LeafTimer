import SwiftUI

struct SessionStatsView: View {
    let todayCount: Int
    let weeklyAverage: Double

    private var formattedAverage: String {
        String(format: "%.1f", weeklyAverage)
    }

    var body: some View {
        HStack(spacing: 30) {
            // Today's Count
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green.opacity(0.7))

                    Text("\(todayCount)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                }

                Text("Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .accessibilityLabel("Today's sessions: \(todayCount)")

            // Weekly Average
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16))
                        .foregroundColor(.blue.opacity(0.7))

                    Text(formattedAverage)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                }

                Text("Weekly Avg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .accessibilityLabel("Weekly average: \(formattedAverage) sessions")
        }
        .padding(.top, 20)
    }
}

struct SessionStatsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SessionStatsView(todayCount: 6, weeklyAverage: 4.5)
            SessionStatsView(todayCount: 0, weeklyAverage: 0.0)
            SessionStatsView(todayCount: 12, weeklyAverage: 8.7)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}