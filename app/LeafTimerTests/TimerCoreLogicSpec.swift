import Quick
import Nimble
import ViewInspector
import SwiftUI

@testable import LeafTimer

class TimerCoreLogicSpec: QuickSpec {
    override class func spec() {
        describe("Timer Core Logic Testing") {
            var spyTimerManager: SpyTimerManager!
            var spyAudioManager: SpyAudioManager!
            var mockUserDefaultWrapper: MockUserDefaultWrapper!
            var timerViewModel: TimerViewModel!

            beforeEach {
                spyTimerManager = SpyTimerManager()
                spyAudioManager = SpyAudioManager()
                mockUserDefaultWrapper = MockUserDefaultWrapper()

                timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
            }

            afterEach {
                timerViewModel = nil
                spyTimerManager = nil
                spyAudioManager = nil
                mockUserDefaultWrapper = nil
            }

            TimerCoreLogicSpec.testTimerManagerBasicFunctionality()
            TimerCoreLogicSpec.testCountdownFunctionality()
            TimerCoreLogicSpec.testWorkBreakModeSwitching()
            TimerCoreLogicSpec.testDataPersistence()
            TimerCoreLogicSpec.testAudioIntegration()
            TimerCoreLogicSpec.testStateManagement()
            TimerCoreLogicSpec.testMemoryManagement()
        }
    }

    // MARK: - Timer Manager Basic Functionality
    
    static func testTimerManagerBasicFunctionality() {
        context("TimerManager basic functionality") {
            it("should start timer when timer button is pressed from stopped state") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                expect(timerViewModel.executeState) == false
                expect(spyTimerManager.startWasCalled) == false

                // When
                timerViewModel.onPressedTimerButton()

                // Then
                expect(timerViewModel.executeState) == true
                expect(spyTimerManager.startWasCalled) == true
            }

            it("should stop timer when timer button is pressed from running state") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.executeState = true

                // When
                timerViewModel.onPressedTimerButton()

                // Then
                expect(timerViewModel.executeState) == false
                expect(spyTimerManager.stopWasCalled) == true
            }

            it("should reset timer correctly for work mode") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.currentTimeSecond = 100
                timerViewModel.workingTime = 300 // 5 minutes

                // When
                timerViewModel.reset()

                // Then
                expect(timerViewModel.currentTimeSecond) == 300
            }
        }
    }

    // MARK: - Countdown Functionality
    
    static func testCountdownFunctionality() {
        context("Countdown functionality") {
            it("should decrement current time by 1 second when updateTime is called") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.currentTimeSecond = 300

                // When
                timerViewModel.updateTime()

                // Then
                expect(timerViewModel.currentTimeSecond) == 299
            }

            it("should handle time reaching zero") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.currentTimeSecond = 1
                timerViewModel.breakState = false

                // When
                timerViewModel.updateTime()

                // Then
                expect(timerViewModel.currentTimeSecond) == 0
                expect(timerViewModel.executeState) == false
            }
        }
    }

    // MARK: - Work/Break Mode Switching
    
    static func testWorkBreakModeSwitching() {
        context("Work/Break mode switching") {
            it("should switch from work to break mode correctly") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.breakState = false
                timerViewModel.workingTime = 300
                timerViewModel.breakTime = 60

                // When
                timerViewModel.switchToBreakMode()

                // Then
                expect(timerViewModel.breakState) == true
                expect(timerViewModel.currentTimeSecond) == 60
            }
        }
    }

    // MARK: - Data Persistence
    
    static func testDataPersistence() {
        context("Data persistence") {
            it("should save working time setting correctly") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                let newWorkingTime = 1500 // 25 minutes

                // When
                timerViewModel.workingTime = newWorkingTime

                // Then
                expect(mockUserDefaultWrapper.saveDataIntCallCount) > 0
            }
        }
    }

    // MARK: - Audio Integration
    
    static func testAudioIntegration() {
        context("Audio integration") {
            it("should play break sound when switching to break mode") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                timerViewModel.breakState = false

                // When
                timerViewModel.switchToBreakMode()

                // Then
                expect(spyAudioManager.playBreakSoundWasCalled) == true
            }
        }
    }

    // MARK: - State Management
    
    static func testStateManagement() {
        context("State management") {
            it("should maintain consistent state during timer operations") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper
                )
                
                // Given
                let initialWorkingTime = timerViewModel.workingTime
                timerViewModel.executeState = false

                // When
                timerViewModel.onPressedTimerButton()

                // Then
                expect(timerViewModel.executeState) == true
                expect(timerViewModel.workingTime) == initialWorkingTime
            }
        }
    }

    // MARK: - Memory Management
    
    static func testMemoryManagement() {
        context("Memory management") {
            it("should properly deallocate TimerViewModel") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                
                // Given
                weak var weakTimerViewModel: TimerViewModel?

                // When
                autoreleasepool {
                    let localTimerViewModel = TimerViewModel(
                        timerManager: spyTimerManager,
                        audioManager: spyAudioManager,
                        userDefaultWrapper: mockUserDefaultWrapper
                    )
                    weakTimerViewModel = localTimerViewModel

                    // Use the view model
                    localTimerViewModel.onPressedTimerButton()
                }

                // Then - Should be deallocated
                expect(weakTimerViewModel) == nil
            }
        }
    }
}