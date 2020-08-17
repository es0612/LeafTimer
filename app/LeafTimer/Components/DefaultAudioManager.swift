import Foundation
import AVFoundation

protocol AudioManager {
    func start()
    func stop()
    func finish()
    func vibration()
    func setUp(workingSound: String)

}

class DefaultAudioManager: AudioManager {
    var stopAudioPlayer: AVAudioPlayer?
    var workingAudioPlayer: AVAudioPlayer?

    func start() {
        workingAudioPlayer?.play()
        stopAudioPlayer?.stop()
    }

    func stop() {
        workingAudioPlayer?.stop()
        stopAudioPlayer?.stop()
    }

    func finish() {
        workingAudioPlayer?.stop()
        stopAudioPlayer?.play()
    }

    func vibration() {
        let systemSoundID = SystemSoundID(kSystemSoundID_Vibrate)
        AudioServicesPlaySystemSound(systemSoundID)
    }

    func setUp(workingSound: String) {
        guard let path = Bundle.main.path(
            forResource: "warning1", ofType: "mp3")
            else {
                return
        }

        do {
            stopAudioPlayer = try AVAudioPlayer(
                contentsOf: URL(fileURLWithPath: path))

            stopAudioPlayer?.numberOfLoops = 3
            stopAudioPlayer?.prepareToPlay()
            stopAudioPlayer?.volume = 0.5
        } catch { }

        guard let workingPath = Bundle.main.path(
            forResource: workingSound, ofType: "mp3")
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
