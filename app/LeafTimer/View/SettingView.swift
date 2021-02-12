import SwiftUI

struct SettingView: View {
    // MARK: - State
    @ObservedObject var settingViewModel: SettingViewModel

    var body: some View {
        NavigationView{
            VStack {
                Form{
                    Section(header: Text("タイマー")){
                        Picker("作業時間", selection: Binding(
                            get: { self.settingViewModel.workingTime },
                            set: { self.settingViewModel.workingTime = $0 }
                        ).onChange({ selected in
                            self.settingViewModel
                                .write(selected: selected, item: UserDefaultItem.workingTime.rawValue)

                        }))
                        {
                            ForEach(0..<ItemValue.workingTimeListString.count) {
                                Text(ItemValue.workingTimeListString[$0]).tag($0)
                            }
                        }

                        Picker("休憩時間", selection: Binding(
                            get: { self.settingViewModel.breakTime },
                            set: { self.settingViewModel.breakTime = $0 }
                        ).onChange({ selected in
                            self.settingViewModel
                                .write(selected: selected, item: UserDefaultItem.breakTime.rawValue)
                        })
                        ) {
                            ForEach(0..<ItemValue.breakTimeListString.count) {
                                Text(ItemValue.breakTimeListString[$0]).tag($0)
                            }
                        }
                    }

                    Section(header: Text("サウンド")){
                        Picker("作業中", selection: Binding(
                            get: { self.settingViewModel.workingSound },
                            set: { self.settingViewModel.workingSound = $0 }
                        ).onChange({ selected in
                            self.settingViewModel
                                .write(selected: selected, item: UserDefaultItem.workingSound.rawValue)

                        })
                        ) {
                            ForEach(0..<ItemValue.soundList.count) {
                                Text(ItemValue.soundList[$0]).tag($0)
                            }
                        }

                        Toggle("バイブレーション", isOn: Binding(
                            get: { self.settingViewModel.vibrationIsOn },
                            set: { self.settingViewModel.vibrationIsOn = $0 }
                        )
                        .onChange({ isOn in
                            self.settingViewModel.write(isOn: isOn, item: UserDefaultItem.vibration.rawValue)
                        })
                        )
                    }

                    Section(header: Text("モード")){
                        Text("ポモドーロ")
                    }
                }
                AdsView().frame(width: nil, height: 50, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
            }
        }
        .navigationBarTitle("設定",displayMode: .inline)
        .onAppear() {
            self.settingViewModel.readData()
        }

    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper()))
    }
}
