import SwiftUI

struct TimerView: View {
    // MARK: - State
    @ObservedObject var timverViewModel: TimerViewModel

    // MARK: - View
    var body: some View {
        NavigationView {
            VStack {
                Text(timverViewModel.getDisplayedTime())
                Button(timverViewModel.getButtonState(), action: didTapStartButton)
            }.navigationBarTitle("ポモドーロ", displayMode: .inline)
        }
    }

    // MARK: - Private methods
    private func didTapStartButton() {
        timverViewModel.onPressedTimerButton()

    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach (["iPhone 11"], id: \.self) { deviceName in
            TimerView(
                timverViewModel: TimerViewModel(
                    timerManager: DefaultTimerManager()
            ))
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
