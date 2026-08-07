import SwiftUI

struct ResetSettingsSection: View {
    @ObservedObject var viewModel: SettingViewModel
    @State private var showingResetAlert = false
    @State private var showingResetConfirmation = false

    var body: some View {
        Section {
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)

                    Text(NSLocalizedString("settings.reset.button", comment: "Reset settings button"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)

                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .alert(NSLocalizedString("settings.reset.alert_title", comment: "Reset alert title"), isPresented: $showingResetAlert) {
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
                Button(NSLocalizedString("settings.reset.confirm", comment: "Reset confirm"), role: .destructive) {
                    resetToDefaults()
                }
            } message: {
                Text(NSLocalizedString("settings.reset.alert_message", comment: "Reset alert message"))
            }
            .confirmationDialog(NSLocalizedString("settings.reset.done_title", comment: "Reset done title"), isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button(NSLocalizedString("common.ok", comment: "OK")) { }
            } message: {
                Text(NSLocalizedString("settings.reset.done_message", comment: "Reset done message"))
            }

        } header: {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                Text(NSLocalizedString("settings.system_section", comment: "System section header"))
            }
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("settings.footer.app_name", comment: "Footer app name"))
                    .font(.system(size: 11, weight: .medium))
                Text(NSLocalizedString("settings.footer.copyright", comment: "Footer copyright"))
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
    }

    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.resetToDefaults()
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Show confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingResetConfirmation = true
        }
    }
}

// Extension for ViewModel reset functionality
extension SettingViewModel {
    func resetToDefaults() {
        workingTime = 4  // 25 minutes (index 4)
        breakTime = 4    // 5 minutes (index 4)
        workingSound = 0 // No sound
        breakSound = 0   // No sound
        vibrationIsOn = true
        mode = 0

        // Save all to UserDefaults
        write(selected: workingTime, item: UserDefaultItem.workingTime.rawValue)
        write(selected: breakTime, item: UserDefaultItem.breakTime.rawValue)
        write(selected: workingSound, item: UserDefaultItem.workingSound.rawValue)
        write(selected: breakSound, item: UserDefaultItem.breakSound.rawValue)
        write(isOn: vibrationIsOn, item: UserDefaultItem.vibration.rawValue)
    }
}