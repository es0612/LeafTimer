import SwiftUI

struct TimerView: View {
    // MARK: - State

    @ObservedObject
    var timerViewModel: TimerViewModel
    @ObservedObject
    var settingViewModel: SettingViewModel

    // MARK: - View

    var body: some View {
        NavigationStack {
            ZStack {
                timerViewModel.getBackgroundColor()
                    .ignoresSafeArea(.all)

                VStack {
                    if timerViewModel.breakState {
                        GIFView(gifName: "leaf3")
                            .frame(width: 350, height: 350, alignment: .center)
                            .padding(.bottom, 300)

                    } else {
                        if timerViewModel.getLeafPattern() == LeafPattern.small {
                            GIFView(gifName: "leaf1")
                                .frame(width: 90, height: 90, alignment: .center)
                                .padding(.trailing, 22)
                                .padding(.bottom, 105)
                        }

                        if timerViewModel.getLeafPattern() == LeafPattern.mid {
                            GIFView(gifName: "leaf2")
                                .frame(width: 200, height: 200, alignment: .center)
                                .padding(.leading, 11)
                                .padding(.bottom, 150)
                        }

                        if timerViewModel.getLeafPattern() == LeafPattern.big {
                            GIFView(gifName: "leaf3")
                                .frame(width: 350, height: 350, alignment: .center)
                                .padding(.bottom, 300)
                        }
                    }
                }

                VStack {
                    Text(timerViewModel.getDisplayedTime())
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced
                        )
                        )
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65, opacity: 0.9))
                        .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        .padding(.bottom, 50)

                    CircleButton(viewModel: timerViewModel)
                        .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        .onTapGesture {
                            didTapTimerButton()
                        }

                    Text(NSLocalizedString("timer.todays_count", comment: "Today's pomodoro count label") + String(timerViewModel.todaysCount))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9))
                        .padding()
                        .padding(.top, 20)
                }
                .navigationTitle(NSLocalizedString("timer.title", comment: "Timer navigation title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: didTapResetButton) {
                            Image("reloadIcon").foregroundColor(.primary)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingView(settingViewModel: settingViewModel)) {
                            Image("settingIcon").foregroundColor(.primary)
                        }
                    }
                }
                .onAppear {
                    timerViewModel.readData()
                    timerViewModel.openScreen()
                }
            }
        }
    }

    // MARK: - Private methods

    private func didTapTimerButton() {
        timerViewModel.onPressedTimerButton()
    }

    private func didTapResetButton() {
        timerViewModel.reset()
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 16"], id: \.self) { deviceName in
            TimerView(
                timerViewModel: TimerViewModel(
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
