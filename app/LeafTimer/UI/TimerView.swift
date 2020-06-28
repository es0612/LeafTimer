import SwiftUI

struct TimerView: View {
    // MARK: - State
    @State var buttonText = "START"

    // MARK: - View
    var body: some View {
        NavigationView {
            VStack {
                Text("25:00")
                Button(buttonText, action: didTapStartButton)
            }.navigationBarTitle("ポモドーロ", displayMode: .inline)
        }
    }

    // MARK: - Private methods
    private func didTapStartButton() {
        buttonText = "STOP"
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach (["iPhone 11"], id: \.self) { deviceName in
            TimerView()
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
