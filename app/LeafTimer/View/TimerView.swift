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
                            .padding(.bottom, 300)

                    } else {
                        if timverViewModel.getLeafPattern() == LeafPattern.small {
                            GIFView(gifName: "leaf1")
                                .frame(width: 100, height: 100, alignment: .center)
                                .padding(.trailing, 22)
                                .padding(.bottom, 90)
                        }

                        if timverViewModel.getLeafPattern() == LeafPattern.mid {
                            GIFView(gifName: "leaf2")
                                .frame(width: 200, height: 200, alignment: .center)
                                .padding(.leading, 11)
                                .padding(.bottom, 150)
                        }

                        if timverViewModel.getLeafPattern() == LeafPattern.big {
                            GIFView(gifName: "leaf3")
                                .frame(width: 350, height: 350, alignment: .center)
                                .padding(.bottom, 300)
                        }
                    }
                }

                VStack {
                    Text(timverViewModel.getDisplayedTime())
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced)
                    )
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65, opacity: 0.9))
                        .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        .padding(.bottom, 50)

                    CircleButton(viewModel: timverViewModel)
                        .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        .onTapGesture {
                            self.didTapTimerButton()
                    }

                    Text("今日のポモドーロ数：" + String(timverViewModel.todaysCount))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9))
                        .padding()
                        .padding(.top, 20)
                }
                .navigationBarTitle("ポモドーロ", displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: didTapResetButton) {
                        Image("reloadIcon").foregroundColor(.primary)
                    },
                    trailing: NavigationLink(destination: SettingView(settingViewModel: settingViewModel)) {
                        Image("settingIcon").foregroundColor(.primary)
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


