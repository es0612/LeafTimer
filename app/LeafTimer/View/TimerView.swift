import SwiftUI

struct TimerView: View {
    // MARK: - State
    @ObservedObject var timverViewModel: TimerViewModel

    let backGroundColor = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(.displayP3, red: 0.8, green: 1, blue: 0.84, opacity: 0.33),
                Color(.displayP3, red: 0.68, green: 0.81, blue: 0.48, opacity: 0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - View
    var body: some View {

        NavigationView {

            ZStack {
                backGroundColor.edgesIgnoringSafeArea(.all)

                VStack {
                    Text(timverViewModel.getDisplayedTime())
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced)
                    )
                        .foregroundColor(.gray)

                    CircleButton(buttonState: self.timverViewModel.getButtonState())
                        .onTapGesture {
                            self.didTapTimerButton()
                    }
                }
                .navigationBarTitle("ポモドーロ", displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: didTapResetButton) {
                        Text("Reset")
                    },
                    trailing: NavigationLink(destination: SettingView()) {
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
