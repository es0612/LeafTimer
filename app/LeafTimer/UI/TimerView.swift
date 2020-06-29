import SwiftUI

struct TimerView: View {
    // MARK: - State
    @ObservedObject var timerManager: DefaultTimerManager

    // MARK: - View
    var body: some View {
        NavigationView {
            VStack {
                Text(timerManager.getDisplayedTime())
                Button(timerManager.getButtonState(), action: didTapStartButton)
            }.navigationBarTitle("ポモドーロ", displayMode: .inline)
        }
    }

    // MARK: - Private methods
    private func didTapStartButton() {
        timerManager.startTimer()

    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach (["iPhone 11"], id: \.self) { deviceName in
            TimerView(timerManager: DefaultTimerManager())
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
