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

                    Text("Reset to Default Settings")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)

                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .confirmationDialog("Settings Reset", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("OK") { }
            } message: {
                Text("All settings have been reset to defaults.")
            }

            // App Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("Build")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)

        } header: {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                Text("System")
            }
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("LeafTimer - Focus & Productivity")
                    .font(.system(size: 11, weight: .medium))
                Text("© 2025 LeafTimer. All rights reserved.")
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