import SwiftUI
import AVFoundation

struct SoundSettingsSection: View {
    @ObservedObject var viewModel: SettingViewModel
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingSound = false
    @State private var playingSoundIndex: Int? = nil

    var body: some View {
        Section {
            // Working Sound Setting
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    NSLocalizedString("settings.working_sound", comment: "Working sound setting"),
                    systemImage: "speaker.wave.2.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)

                ForEach(0 ..< ItemValue.soundList.count, id: \.self) { index in
                    HStack {
                        Button(action: {
                            viewModel.workingSound = index
                            viewModel.write(selected: index, item: UserDefaultItem.workingSound.rawValue)
                        }) {
                            HStack {
                                Image(systemName: viewModel.workingSound == index ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(viewModel.workingSound == index ? .blue : .gray)
                                    .font(.title3)

                                Text(ItemValue.soundList[index])
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Spacer()

                                // Preview Button
                                if index > 0 {
                                    Button(action: {
                                        playSound(at: index)
                                    }) {
                                        Image(systemName: playingSoundIndex == index && isPlayingSound ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Vibration Toggle with Enhanced Visual
            HStack {
                Label(
                    NSLocalizedString("settings.vibration", comment: "Vibration setting"),
                    systemImage: "iphone.radiowaves.left.and.right"
                )
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { viewModel.vibrationIsOn },
                    set: { newValue in
                        viewModel.vibrationIsOn = newValue
                        viewModel.write(isOn: newValue, item: UserDefaultItem.vibration.rawValue)
                        if newValue {
                            // Provide haptic feedback when enabling
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                ))
                .labelsHidden()
                .tint(.blue)
                .accessibilityLabel(NSLocalizedString("settings.vibration", comment: "Vibration setting"))
            }
            .padding(.vertical, 4)

        } header: {
            HStack {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .foregroundColor(.green)
                Text(NSLocalizedString("settings.sound_section", comment: "Sound section header"))
            }
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
        } footer: {
            Text(NSLocalizedString("settings.sound_footer", comment: "Sound section footer"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func playSound(at index: Int) {
        if isPlayingSound && playingSoundIndex == index {
            // Stop current sound
            audioPlayer?.stop()
            isPlayingSound = false
            playingSoundIndex = nil
        } else {
            // Play new sound
            let soundFileName = ItemValue.soundListFileName[index]
            if let soundURL = Bundle.main.url(forResource: soundFileName, withExtension: "mp3") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    audioPlayer?.play()
                    isPlayingSound = true
                    playingSoundIndex = index

                    // Auto stop after a few seconds for preview
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.playingSoundIndex == index {
                            self.audioPlayer?.stop()
                            self.isPlayingSound = false
                            self.playingSoundIndex = nil
                        }
                    }
                } catch {
                    print("Error playing sound: \(error)")
                }
            }
        }
    }
}