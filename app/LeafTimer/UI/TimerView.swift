import SwiftUI

struct TimerView: View {
    var body: some View {
        VStack {
            Text("25:00")

            Button(action: {
                print("stop")
            }) {
                Text("STOP")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach (["iPhone 8","iPhone 11"], id: \.self) { deviceName in
            TimerView()
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
