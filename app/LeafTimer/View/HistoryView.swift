import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summarySection
                Divider().padding(.horizontal)
                last7DaysSection
            }
            .padding(.top, 16)
        }
        .navigationTitle(NSLocalizedString("history.title", comment: "History screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            statRow(
                icon: "flame.fill",
                color: .orange,
                text: String(format: NSLocalizedString("history.current_streak", comment: ""), viewModel.currentStreak)
            )
            statRow(
                icon: "trophy.fill",
                color: .yellow,
                text: String(format: NSLocalizedString("history.longest_streak", comment: ""), viewModel.longestStreak)
            )
            statRow(
                icon: "checkmark.circle.fill",
                color: .green,
                text: String(format: NSLocalizedString("history.total_sessions", comment: ""), viewModel.totalCount)
            )
        }
        .padding(.horizontal)
    }

    private func statRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private var last7DaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("history.last_7_days", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.last7Days, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text("\(day.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(barColor(for: day.count))
                            .frame(height: barHeight(for: day.count))
                        Text(shortLabel(date: day.date))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }

    private var maxCount: Int {
        max(viewModel.last7Days.map { $0.count }.max() ?? 0, 1)
    }

    private func barHeight(for count: Int) -> CGFloat {
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(ratio * 120, 4)
    }

    private func barColor(for count: Int) -> Color {
        count == 0
            ? Color.gray.opacity(0.3)
            : Color(red: 0.42, green: 0.56, blue: 0.42)
    }

    private func shortLabel(date: String) -> String {
        let parts = date.split(separator: "/")
        guard parts.count == 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let spy = SpyHistoryRepository()
        spy.stubRecent = [
            (date: "2026/05/22", count: 0),
            (date: "2026/05/23", count: 2),
            (date: "2026/05/24", count: 4),
            (date: "2026/05/25", count: 1),
            (date: "2026/05/26", count: 3),
            (date: "2026/05/27", count: 0),
            (date: "2026/05/28", count: 5),
        ]
        let vm = HistoryViewModel(repository: spy)
        vm.last7Days = spy.stubRecent
        vm.currentStreak = 2
        vm.longestStreak = 7
        vm.totalCount = 42
        return NavigationStack {
            HistoryView(viewModel: vm)
        }
    }
}

private class SpyHistoryRepository: SessionStatsRepository {
    var stubRecent: [(date: String, count: Int)] = []
    func load() -> SessionStats { .empty }
    func recordSession(today: String) -> SessionStats { .empty }
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] { stubRecent }
}
