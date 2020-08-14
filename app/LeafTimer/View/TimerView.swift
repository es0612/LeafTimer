import SwiftUI

struct TimerView: View {
    // MARK: - State
    @ObservedObject var timverViewModel: TimerViewModel

    // MARK: - View
    var body: some View {

        NavigationView {
            ZStack {
                timverViewModel.getBackgroundColor()
                    .edgesIgnoringSafeArea(.all)

                VStack{
                    GIFView(gifName: "leaf2")
                        .frame(width: 100, height: 100, alignment: .center)
                        .padding(.trailing, 20)
                }

                VStack {
                    Text(timverViewModel.getDisplayedTime())
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced)
                    )
                        .foregroundColor(.gray)
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
                    trailing: NavigationLink(destination: SettingView(settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper()))) {
                        Text("Setting")
                    }
                )
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
                    audioManager: DefaultAudioManager()
            ))
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
