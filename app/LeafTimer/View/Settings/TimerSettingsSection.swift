import SwiftUI

struct TimerSettingsSection: View {
    @ObservedObject var viewModel: SettingViewModel
    @State private var showingTimePreview = false

    var body: some View {
        Section {
            // Working Time Setting with Stepper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        NSLocalizedString("settings.working_time", comment: "Working time setting"),
                        systemImage: "timer"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Text(ItemValue.workingTimeListString[viewModel.workingTime])
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.blue)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.workingTime)
                }

                Picker("", selection: Binding(
                    get: { viewModel.workingTime },
                    set: { newValue in
                        viewModel.workingTime = newValue
                        viewModel.write(selected: newValue, item: UserDefaultItem.workingTime.rawValue)
                    }
                )) {
                    ForEach(0 ..< ItemValue.workingTimeListString.count, id: \.self) { index in
                        Text(ItemValue.workingTimeListString[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(NSLocalizedString("settings.working_time", comment: "Working time setting"))
            }
            .padding(.vertical, 4)

            // Break Time Setting with Stepper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        NSLocalizedString("settings.break_time", comment: "Break time setting"),
                        systemImage: "pause.circle"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Text(ItemValue.breakTimeListString[viewModel.breakTime])
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.green)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.breakTime)
                }

                Picker("", selection: Binding(
                    get: { viewModel.breakTime },
                    set: { newValue in
                        viewModel.breakTime = newValue
                        viewModel.write(selected: newValue, item: UserDefaultItem.breakTime.rawValue)
                    }
                )) {
                    ForEach(0 ..< ItemValue.breakTimeListString.count, id: \.self) { index in
                        Text(ItemValue.breakTimeListString[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(NSLocalizedString("settings.break_time", comment: "Break time setting"))
            }
            .padding(.vertical, 4)

            // Time Preview Button
            Button(action: {
                showingTimePreview.toggle()
            }) {
                HStack {
                    Image(systemName: "eye")
                        .font(.subheadline)
                    Text(NSLocalizedString("settings.timer.preview_button", comment: "Preview timer settings button"))
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text(NSLocalizedString("settings.timer_section", comment: "Timer section header"))
            }
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
        }
        .sheet(isPresented: $showingTimePreview) {
            TimerPreviewSheet(
                workingTime: ItemValue.workingTimeList[viewModel.workingTime],
                breakTime: ItemValue.breakTimeList[viewModel.breakTime]
            )
        }
    }
}

struct TimerPreviewSheet: View {
    let workingTime: Int
    let breakTime: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            // AX5 では見出し + 2 カードの合計高さが画面を超えるため ScrollView で包む。
            // Spacer() は固定 VStack 時代に余白を吸収する役割だったが、
            // ScrollView の内容は元々コンテンツの実サイズで上詰めされるため不要。
            ScrollView {
                VStack(spacing: 30) {
                    Text(NSLocalizedString("settings.timer.preview_title", comment: "Timer preview sheet title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 20) {
                        PreviewTimerDisplay(
                            title: NSLocalizedString("settings.timer.preview_work", comment: "Work session preview label"),
                            time: workingTime,
                            color: .blue
                        )

                        Image(systemName: "arrow.down")
                            .font(.title3)
                            .foregroundColor(.gray)

                        PreviewTimerDisplay(
                            title: NSLocalizedString("settings.timer.preview_break", comment: "Break time preview label"),
                            time: breakTime,
                            color: .green
                        )
                    }
                    .padding()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button(NSLocalizedString("settings.done", comment: "Done button")) { dismiss() })
        }
    }
}

struct PreviewTimerDisplay: View {
    let title: String
    let time: Int
    let color: Color

    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 48

    private var timeString: String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                // fixedSize(vertical: true) が無いと AX5 で高さが 1 行分に圧縮され、
                // 「作業セッション」等が語中省略される (Issue #58 Task 7 実測)。
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(timeString)
                .font(.system(size: min(timeFontSize, 72), weight: .light, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(color)

            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.2))
                .frame(height: 4)
                .frame(maxWidth: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}