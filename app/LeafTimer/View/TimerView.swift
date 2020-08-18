import SwiftUI

struct TimerView: View {
    // MARK: - State
    @ObservedObject var timverViewModel: TimerViewModel
    @ObservedObject var settingViewModel: SettingViewModel

    // MARK: - View
    var body: some View {

        NavigationView {
            ZStack {
                timverViewModel.getBackgroundColor()
                    .edgesIgnoringSafeArea(.all)

                VStack{

                    if timverViewModel.breakState {
                        GIFView(gifName: "leaf3")
                            .frame(width: 350, height: 350, alignment: .center)
                            .padding(.bottom, 200)

                    } else {
                        if timverViewModel.getLeafPattern() == LeafPattern.small {
                            GIFView(gifName: "leaf1")
                                .frame(width: 100, height: 100, alignment: .center)
                                .padding(.trailing, 22)
                                .padding(.bottom, -25)
                        }

                        if timverViewModel.getLeafPattern() == LeafPattern.mid {
                            GIFView(gifName: "leaf2")
                                .frame(width: 200, height: 200, alignment: .center)
                                .padding(.leading, 11)
                                .padding(.bottom, 60)
                        }

                        if timverViewModel.getLeafPattern() == LeafPattern.big {
                            GIFView(gifName: "leaf3")
                                .frame(width: 350, height: 350, alignment: .center)
                                .padding(.bottom, 200)
                        }
                    }
                }

                VStack {
                    Text(timverViewModel.getDisplayedTime())
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced)
                    )
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6,opacity: 0.8))
                        .padding(.bottom, 100)


                    CircleButton(viewModel: timverViewModel)
                        .onTapGesture {
                            self.didTapTimerButton()
                    }
                }
                .navigationBarTitle("ポモドーロ", displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: didTapResetButton) {
                        Text("Reset")
                    },
                    trailing: NavigationLink(destination: SettingView(settingViewModel: settingViewModel)) {
                        Text("Setting")
                    }
                )
                    .onAppear() {
                        self.timverViewModel.readData()
                        self.timverViewModel.openScreen()
                }
            }
        }
    }

    // MARK: - Private methods
    private func didTapTimerButton() {
        timverViewModel.onPressedTimerButton()
    }

    private func didTapResetButton() {
        timverViewModel.reset()
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach (["iPhone 11"], id: \.self) { deviceName in
            TimerView(
                timverViewModel: TimerViewModel(
                    timerManager: DefaultTimerManager(),
                    audioManager: DefaultAudioManager(),
                    userDefaultWrapper: LocalUserDefaultsWrapper()
                ),
                settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
            )
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
