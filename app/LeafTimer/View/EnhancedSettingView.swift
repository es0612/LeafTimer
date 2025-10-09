import SwiftUI

struct EnhancedSettingView: View {
    @ObservedObject var settingViewModel: SettingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Timer Settings Section
                TimerSettingsSection(viewModel: settingViewModel)

                // Sound Settings Section
                SoundSettingsSection(viewModel: settingViewModel)

                // Mode Section (Existing)
                Section {
                    HStack {
                        Label(
                            NSLocalizedString("settings.pomodoro_mode", comment: "Pomodoro mode"),
                            systemImage: "leaf.fill"
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.green)

                        Spacer()

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                } header: {
                    HStack {
                        Image(systemName: "leaf.circle.fill")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("settings.mode_section", comment: "Mode section header"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                } footer: {
                    Text("Pomodoro technique helps you stay focused with regular breaks.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Reset & System Section
                ResetSettingsSection(viewModel: settingViewModel)
                
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
            .onAppear {
                settingViewModel.readData()
            }
            AdsView().frame(width: nil, height: 50, alignment: /*@START_MENU_TOKEN@*/ .center/*@END_MENU_TOKEN@*/)
        }
        .tint(.blue)
    }
}

// Preview
struct EnhancedSettingView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSettingView(
            settingViewModel: SettingViewModel(
                userDefaultWrapper: LocalUserDefaultsWrapper()
            )
        )
    }
}
