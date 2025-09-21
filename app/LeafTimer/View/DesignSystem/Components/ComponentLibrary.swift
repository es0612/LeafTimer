import SwiftUI

// MARK: - Component Library Index
// This file provides a central import point for all design system components

// Re-export all components for convenience
public typealias PrimaryButton = PrimaryButton
public typealias SecondaryButton = SecondaryButton
public typealias AnimatedButton = AnimatedButton
public typealias TimerCard = TimerCard
public typealias StatCard = StatCard
public typealias ProgressRing = ProgressRing
public typealias IconBadge = IconBadge
public typealias SettingRow = SettingRow
public typealias Toast = Toast
public typealias ToastType = ToastType

// MARK: - Preview Helpers

struct ComponentLibraryPreviews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Buttons
                GroupBox("Buttons") {
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Start Timer", systemImage: "play.fill") {}
                        SecondaryButton(title: "Cancel") {}
                        AnimatedButton(title: "Loading...", isAnimating: true) {}
                    }
                }

                // Cards
                GroupBox("Cards") {
                    VStack(spacing: 12) {
                        TimerCard(title: "Work Session", time: "25:00", color: .primaryGreen)
                        StatCard(title: "Today's Sessions", value: "8", icon: "clock.fill")
                    }
                }

                // Progress
                GroupBox("Progress") {
                    HStack(spacing: 20) {
                        ProgressRing(progress: 0.75, lineWidth: 10)
                            .frame(width: 100, height: 100)
                        IconBadge(systemName: "star.fill", color: .accentGreen)
                    }
                }

                // Settings
                GroupBox("Settings") {
                    SettingRow(title: "Sound", value: "Rain", icon: "speaker.wave.2") {}
                }

                // Toast
                GroupBox("Toast") {
                    VStack(spacing: 8) {
                        Toast(message: "Timer started successfully!", type: .success)
                        Toast(message: "Failed to save settings", type: .error)
                        Toast(message: "Low battery warning", type: .warning)
                        Toast(message: "Tip: Use spacebar to pause", type: .info)
                    }
                }
            }
            .padding()
        }
    }
}