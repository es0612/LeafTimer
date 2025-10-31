import SwiftUI

struct SettingView: View {
    // MARK: - State

    @ObservedObject var settingViewModel: SettingViewModel

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text(NSLocalizedString("settings.timer_section", comment: "Timer section header"))) {
                        Picker(NSLocalizedString("settings.working_time", comment: "Working time setting"), selection: Binding(
                            get: { settingViewModel.workingTime },
                            set: { settingViewModel.workingTime = $0 }
                        ).onChange { selected in
                            settingViewModel
                                .write(selected: selected, item: UserDefaultItem.workingTime.rawValue)

                        }) {
                            ForEach(ItemValue.workingTimeListString.indices, id: \.self) {
                                Text(ItemValue.workingTimeListString[$0]).tag($0)
                            }
                        }

                        Picker(
                            NSLocalizedString("settings.break_time", comment: "Break time setting"),
                            selection: Binding(
                                get: { settingViewModel.breakTime },
                                set: { settingViewModel.breakTime = $0 }
                            ).onChange { selected in
                                settingViewModel
                                    .write(selected: selected, item: UserDefaultItem.breakTime.rawValue)
                            }
                        ) {
                            ForEach(ItemValue.breakTimeListString.indices, id: \.self) {
                                Text(ItemValue.breakTimeListString[$0]).tag($0)
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("settings.sound_section", comment: "Sound section header"))) {
                        Picker(
                            NSLocalizedString("settings.working_sound", comment: "Working sound setting"),
                            selection: Binding(
                                get: { settingViewModel.workingSound },
                                set: { settingViewModel.workingSound = $0 }
                            ).onChange { selected in
                                settingViewModel
                                    .write(selected: selected, item: UserDefaultItem.workingSound.rawValue)
                            }
                        ) {
                            ForEach(ItemValue.soundList.indices, id: \.self) {
                                Text(ItemValue.soundList[$0]).tag($0)
                            }
                        }

                        Toggle(
                            NSLocalizedString("settings.vibration", comment: "Vibration setting"),
                            isOn: Binding(
                                get: { settingViewModel.vibrationIsOn },
                                set: { settingViewModel.vibrationIsOn = $0 }
                            )
                            .onChange { isOn in
                                settingViewModel.write(isOn: isOn, item: UserDefaultItem.vibration.rawValue)
                            }
                        )
                    }

                    Section(header: Text(NSLocalizedString("settings.mode_section", comment: "Mode section header"))) {
                        Text(NSLocalizedString("settings.pomodoro_mode", comment: "Pomodoro mode"))
                    }
                }
                AdsView().frame(width: nil, height: 50, alignment: /*@START_MENU_TOKEN@*/ .center/*@END_MENU_TOKEN@*/)
            }
        }
        .navigationBarTitle(NSLocalizedString("settings.title", comment: "Settings navigation title"), displayMode: .inline)
        .onAppear {
            settingViewModel.readData()
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper()))
    }
}
