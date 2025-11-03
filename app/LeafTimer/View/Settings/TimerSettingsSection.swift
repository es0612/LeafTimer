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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Text(ItemValue.workingTimeListString[viewModel.workingTime])
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
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
            }
            .padding(.vertical, 4)

            // Break Time Setting with Stepper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        NSLocalizedString("settings.break_time", comment: "Break time setting"),
                        systemImage: "pause.circle"
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Text(ItemValue.breakTimeListString[viewModel.breakTime])
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
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
            }
            .padding(.vertical, 4)

            // Time Preview Button
            Button(action: {
                showingTimePreview.toggle()
            }) {
                HStack {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                    Text("Preview Timer Settings")
                        .font(.system(size: 14, weight: .medium))
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
            .font(.system(size: 13, weight: .semibold))
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
            VStack(spacing: 30) {
                Text("Timer Preview")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    PreviewTimerDisplay(
                        title: "Work Session",
                        time: workingTime,
                        color: .blue
                    )

                    Image(systemName: "arrow.down")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)

                    PreviewTimerDisplay(
                        title: "Break Time",
                        time: breakTime,
                        color: .green
                    )
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct PreviewTimerDisplay: View {
    let title: String
    let time: Int
    let color: Color

    private var timeString: String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Text(timeString)
                .font(.system(size: 48, weight: .light, design: .monospaced))
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