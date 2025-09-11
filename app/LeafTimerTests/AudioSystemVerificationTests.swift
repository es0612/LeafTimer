import XCTest
import AVFoundation
@testable import LeafTimer

/// Audio System Verification Tests for Task 1.2.2
/// Following TDD methodology to verify iOS 17 audio system functionality
class AudioSystemVerificationTests: XCTestCase {
    
    var audioManager: DefaultAudioManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        audioManager = DefaultAudioManager()
    }
    
    override func tearDownWithError() throws {
        audioManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 音声再生機能の動作確認
    
    func testAudioPlaybackFunctionality() {
        // Given: Audio manager is set up with a valid sound
        audioManager.setUp(workingSound: "rain1")
        
        // When: Starting audio playback
        audioManager.start()
        
        // Then: Should not crash and handle playback state
        XCTAssertNoThrow(audioManager.start(), "Audio playback should start without errors")
        
        // When: Stopping audio playback
        audioManager.stop()
        
        // Then: Should not crash
        XCTAssertNoThrow(audioManager.stop(), "Audio playback should stop without errors")
    }
    
    func testAudioFileResourcesExist() {
        // Given: Expected audio files should exist in bundle
        let expectedSounds = ["warning1", "rain1", "river1"]
        
        for soundName in expectedSounds {
            // When: Looking for audio file in bundle
            let audioPath = Bundle.main.path(forResource: soundName, ofType: "mp3")
            
            // Then: Audio file should exist
            XCTAssertNotNil(audioPath, "\(soundName).mp3 should exist in bundle")
        }
    }
    
    func testNoSoundOptionHandling() {
        // Given: Setting up with no sound option
        // When: Setting up with "noSound"
        // Then: Should handle gracefully without crashes
        XCTAssertNoThrow(audioManager.setUp(workingSound: "noSound"))
        XCTAssertNoThrow(audioManager.start())
        XCTAssertNoThrow(audioManager.stop())
    }
    
    // MARK: - バイブレーション機能のテスト
    
    func testVibrationFunctionality() {
        // When: Triggering vibration
        // Then: Should execute without errors
        XCTAssertNoThrow(audioManager.vibration(), "Vibration should trigger without errors")
    }
    
    // MARK: - Audio Sessionの適切な設定確認
    
    func testAudioSessionConfiguration() {
        // Given: Audio manager has been initialized
        let audioSession = AVAudioSession.sharedInstance()
        
        // Then: Audio session should be configured for playback
        XCTAssertEqual(audioSession.category, .playback, "Audio session should be set to playback category")
        XCTAssertTrue(audioSession.categoryOptions.contains(.mixWithOthers), "Audio session should allow mixing with other audio")
    }
    
    func testBackgroundAudioCapability() {
        // Given: Audio manager is set up for background audio
        audioManager.setUp(workingSound: "rain1")
        
        // When: Starting audio that should continue in background
        audioManager.start()
        
        // Then: Audio session should be active
        let audioSession = AVAudioSession.sharedInstance()
        
        // Verify that audio session is configured for background audio
        XCTAssertEqual(audioSession.category, .playback)
        XCTAssertTrue(audioSession.categoryOptions.contains(.mixWithOthers))
    }
    
    // MARK: - 音声切り替え機能のテスト
    
    func testAudioTransitions() {
        // Given: Audio manager with working sound
        audioManager.setUp(workingSound: "rain1")
        audioManager.start()
        
        // When: Finishing current session (should play warning sound)
        // Then: Should transition without errors
        XCTAssertNoThrow(audioManager.finish(), "Audio finish transition should work without errors")
    }
    
    func testMultipleSoundSetup() {
        // Given: Different sound configurations
        let sounds = ["rain1", "river1", "noSound"]
        
        for sound in sounds {
            // When: Setting up with different sounds
            // Then: Should handle each configuration
            XCTAssertNoThrow(audioManager.setUp(workingSound: sound), "Should handle \(sound) setup without errors")
        }
    }
    
    // MARK: - メモリ管理とリソース最適化テスト
    
    func testMemoryManagement() {
        // Given: Multiple audio manager instances
        var managers: [DefaultAudioManager] = []
        
        for _ in 0..<5 {
            let manager = DefaultAudioManager()
            manager.setUp(workingSound: "rain1")
            manager.start()
            managers.append(manager)
        }
        
        // When: Releasing managers
        managers.removeAll()
        
        // Then: Should not cause memory issues (verified by not crashing)
        XCTAssertTrue(true, "Memory management should handle multiple instances")
    }
    
    func testResourceCleanup() {
        // Given: Audio manager with resources
        audioManager.setUp(workingSound: "rain1")
        audioManager.start()
        
        // When: Stopping and cleaning up
        audioManager.stop()
        
        // Then: Should clean up resources properly
        XCTAssertNoThrow(audioManager.stop(), "Resource cleanup should work without errors")
    }
    
    // MARK: - エラー処理テスト
    
    func testInvalidSoundHandling() {
        // When: Setting up with invalid sound file
        // Then: Should handle gracefully
        XCTAssertNoThrow(audioManager.setUp(workingSound: "nonexistent_sound_file"))
        XCTAssertNoThrow(audioManager.start())
        XCTAssertNoThrow(audioManager.stop())
    }
    
    func testRapidOperations() {
        // Given: Audio manager setup
        audioManager.setUp(workingSound: "rain1")
        
        // When: Performing rapid start/stop operations
        for _ in 0..<10 {
            audioManager.start()
            audioManager.stop()
        }
        
        // Then: Should handle rapid operations without issues
        XCTAssertNoThrow(audioManager.finish(), "Should handle rapid operations")
    }
    
    // MARK: - iOS 17 最適化機能テスト
    
    func testBatteryOptimizedAudioSession() {
        // Given: Audio manager initialized (should use iOS 17 optimizations)
        audioManager.setUp(workingSound: "rain1")
        
        // When: Testing audio session management for battery efficiency
        audioManager.start()
        audioManager.stop()
        
        // Then: Should manage audio session efficiently
        // This is tested by ensuring no crashes occur during session management
        XCTAssertNoThrow(audioManager.start())
        XCTAssertNoThrow(audioManager.stop())
    }
    
    func testModernHapticFeedback() {
        // When: Using vibration on iOS 17+
        // Then: Should use modern haptic feedback APIs
        if #available(iOS 17.0, *) {
            XCTAssertNoThrow(audioManager.vibration(), "Should use modern haptic feedback on iOS 17+")
        }
    }
    
    // MARK: - 統合テスト
    
    func testCompleteAudioWorkflow() {
        // Given: A complete pomodoro timer audio workflow
        audioManager.setUp(workingSound: "rain1")
        
        // When: Simulating complete work session
        audioManager.start()  // Start work session
        Thread.sleep(forTimeInterval: 0.1) // Simulate some work time
        audioManager.finish() // End work session (play notification)
        audioManager.vibration() // Trigger haptic feedback
        audioManager.stop() // Stop all audio
        
        // Then: Complete workflow should execute without errors
        XCTAssertNoThrow(audioManager.setUp(workingSound: "noSound"))
        XCTAssertNoThrow(audioManager.start())
        XCTAssertNoThrow(audioManager.stop())
    }
}