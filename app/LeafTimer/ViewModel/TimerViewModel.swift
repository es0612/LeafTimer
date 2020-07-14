import Foundation
import AVFoundation

class TimerViewModel: ObservableObject {

    var stopAudioPlayer: AVAudioPlayer?
    var workingAudioPlayer: AVAudioPlayer?

    // MARK: - Dependency Injection
    var timerManager: TimerManager

    // MARK: - Observed Parameter
    @Published var fullTimeSecond: Int
    @Published var currentTimeSecond: Int
    @Published var executeState: Bool

    // MARK: - Initialization
    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        self.fullTimeSecond = 1*60
        self.currentTimeSecond = 1*60
        self.executeState = false

        setUpPlayer()
    }

    // MARK: - methods
    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            timerManager.start(target: self)

            workingAudioPlayer?.play()
            stopAudioPlayer?.stop()

        case true:
            executeState = false
            timerManager.stop()

            workingAudioPlayer?.stop()
            stopAudioPlayer?.stop()
        }
    }

    @objc func updateTime() {
        if currentTimeSecond == 0 {
            timerManager.stop()

            workingAudioPlayer?.stop()

            let systemSoundID = SystemSoundID(kSystemSoundID_Vibrate)
            AudioServicesPlaySystemSound(systemSoundID)

            stopAudioPlayer?.play()

            return
        }

        currentTimeSecond -= 1
    }

    func getDisplayedTime() -> String {
        let minString
            = String(format: "%02d", Int(currentTimeSecond/60))
        let secondString
            = String(format: "%02d", Int(currentTimeSecond%60))

        return minString + ":" + secondString
    }

    func getButtonState() -> String {
        switch executeState {
        case true:
            return "STOP"

        case false:
            return "START"
        }
    }

    func setUpPlayer() {
      guard let path = Bundle.main.path(
        forResource: "warning1", ofType: "mp3")
        else {
            return
        }

        do {
            stopAudioPlayer = try AVAudioPlayer(
                contentsOf: URL(fileURLWithPath: path))

            stopAudioPlayer?.numberOfLoops = -1
            stopAudioPlayer?.prepareToPlay()
            stopAudioPlayer?.volume = 0.5
        } catch { }

        guard let workingPath = Bundle.main.path(
          forResource: "rain1", ofType: "mp3")
          else {
              return
          }

          do {
              workingAudioPlayer = try AVAudioPlayer(
                  contentsOf: URL(fileURLWithPath: workingPath))

            workingAudioPlayer?.numberOfLoops = -1
            workingAudioPlayer?.prepareToPlay()
            workingAudioPlayer?.volume = 0.3

          } catch { }
    }
}

