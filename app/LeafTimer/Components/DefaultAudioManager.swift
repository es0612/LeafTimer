import AVFoundation
import Foundation
import UIKit

protocol AudioManager {
    func start()
    func stop()
    func finish()
    func vibration()
    func setUp(workingSound: String)
}

/// Modern iOS 17 optimized audio manager with improved session management and energy efficiency
class DefaultAudioManager: AudioManager {
    private var stopAudioPlayer: AVAudioPlayer?
    private var workingAudioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()

    init() {
        setupAudioSession()
    }

    // iOS 17: Optimize audio session for background timer app
    private func setupAudioSession() {
        do {
            // Configure for background audio with minimal interruption
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: [])
        } catch {
            // Graceful fallback for audio session setup failure
            print("Failed to setup audio session: \(error)")
        }
    }

    func start() {
        // iOS 17: Ensure audio session is active before playback
        activateAudioSessionIfNeeded()
        workingAudioPlayer?.play()
        stopAudioPlayer?.stop()
    }

    func stop() {
        workingAudioPlayer?.stop()
        stopAudioPlayer?.stop()

        // iOS 17: Deactivate session when not needed to save battery
        deactivateAudioSessionIfNeeded()
    }

    func finish() {
        workingAudioPlayer?.stop()

        // iOS 17: Ensure audio session is active for notification sound
        activateAudioSessionIfNeeded()
        stopAudioPlayer?.play()
    }

    func vibration() {
        // iOS 17: More efficient haptic feedback
        if #available(iOS 17.0, *) {
            // Use modern haptic feedback when available
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } else {
            // Fallback to system sound for older iOS versions
            let systemSoundID = SystemSoundID(kSystemSoundID_Vibrate)
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }

    func setUp(workingSound: String) {
        setupStopAudio()
        setupWorkingAudio(workingSound: workingSound)
    }

    // iOS 17: Improved error handling and resource management
    private func setupStopAudio() {
        guard let path = Bundle.main.path(forResource: "warning1", ofType: "mp3") else {
            print("Warning: Could not find warning1.mp3")
            return
        }

        do {
            stopAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            stopAudioPlayer?.numberOfLoops = 3
            stopAudioPlayer?.prepareToPlay()
            stopAudioPlayer?.volume = 0.5
        } catch {
            print("Failed to setup stop audio: \(error)")
        }
    }

    private func setupWorkingAudio(workingSound: String) {
        // Handle "noSound" case gracefully
        guard workingSound != "noSound",
              let workingPath = Bundle.main.path(forResource: workingSound, ofType: "mp3")
        else {
            workingAudioPlayer = nil // Clear existing player for "noSound"
            return
        }

        do {
            workingAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: workingPath))
            workingAudioPlayer?.numberOfLoops = -1
            workingAudioPlayer?.prepareToPlay()
            workingAudioPlayer?.volume = 0.3
        } catch {
            print("Failed to setup working audio: \(error)")
        }
    }

    // iOS 17: Smart audio session management for battery optimization
    private func activateAudioSessionIfNeeded() {
        do {
            try audioSession.setActive(true, options: [])
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        // Only deactivate if no audio is playing
        guard workingAudioPlayer?.isPlaying != true, stopAudioPlayer?.isPlaying != true else {
            return
        }

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    // iOS 17: Proper cleanup for memory management
    deinit {
        stop()
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate audio session in deinit: \(error)")
        }
    }
}
