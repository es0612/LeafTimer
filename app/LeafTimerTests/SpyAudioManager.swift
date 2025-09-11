@testable import LeafTimer

class SpyAudioManager: AudioManager {
    
    // MARK: - Call Tracking
    private(set) var setUpCallCount = 0
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var finishCallCount = 0
    private(set) var vibrationCallCount = 0
    
    private(set) var lastWorkingSound: String?
    
    // MARK: - AudioManager Implementation
    func setUp(workingSound: String) {
        setUpCallCount += 1
        lastWorkingSound = workingSound
    }

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func finish() {
        finishCallCount += 1
    }

    func vibration() {
        vibrationCallCount += 1
    }
    
    // MARK: - Helper Methods for Testing
    func reset() {
        setUpCallCount = 0
        startCallCount = 0
        stopCallCount = 0
        finishCallCount = 0
        vibrationCallCount = 0
        lastWorkingSound = nil
    }
}
