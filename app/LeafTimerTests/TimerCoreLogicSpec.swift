import Nimble
import Quick
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
            
            // MARK: - Timer Manager Basic Functionality
            context("TimerManager basic functionality") {
                
                it("should start timer when timer button is pressed from stopped state") {
                    // Given
                    expect(timerViewModel.executeState).to(beFalse())
                    expect(spyTimerManager.start_wasCalled).to(beFalse())
                    
                    // When
                    timerViewModel.onPressedTimerButton()
                    
                    // Then
                    expect(timerViewModel.executeState).to(beTrue())
                    expect(spyTimerManager.start_wasCalled).to(beTrue())
                }
                
                it("should stop timer when timer button is pressed from running state") {
                    // Given
                    timerViewModel.executeState = true
                    
                    // When
                    timerViewModel.onPressedTimerButton()
                    
                    // Then
                    expect(timerViewModel.executeState).to(beFalse())
                    expect(spyTimerManager.stop_wasCalled).to(beTrue())
                }
                
                it("should reset timer correctly for work mode") {
                    // Given
                    timerViewModel.breakState = false
                    timerViewModel.currentTimeSecond = 100
                    timerViewModel.fullTimeSecond = 1500
                    
                    // When
                    timerViewModel.reset()
                    
                    // Then
                    expect(timerViewModel.currentTimeSecond).to(equal(1500))
                }
                
                it("should reset timer correctly for break mode") {
                    // Given
                    timerViewModel.breakState = true
                    timerViewModel.currentTimeSecond = 50
                    timerViewModel.fullBreakTimeSecond = 300
                    
                    // When
                    timerViewModel.reset()
                    
                    // Then
                    expect(timerViewModel.currentTimeSecond).to(equal(300))
                }
            }
            
            // MARK: - Countdown Functionality
            context("Countdown functionality") {
                
                it("should decrement current time by 1 second when updateTime is called") {
                    // Given
                    let initialTime = 1500
                    timerViewModel.currentTimeSecond = initialTime
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(timerViewModel.currentTimeSecond).to(equal(initialTime - 1))
                }
                
                it("should not go below zero when updateTime is called at zero") {
                    // Given
                    timerViewModel.currentTimeSecond = 1
                    timerViewModel.breakState = false
                    let initialCount = timerViewModel.todaysCount
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then - Timer should reset and switch to break mode
                    expect(timerViewModel.breakState).to(beTrue())
                    expect(timerViewModel.todaysCount).to(equal(initialCount + 1))
                }
                
                it("should handle continuous countdown correctly") {
                    // Given
                    timerViewModel.currentTimeSecond = 5
                    
                    // When - Simulate 3 seconds of countdown
                    for _ in 0..<3 {
                        timerViewModel.updateTime()
                    }
                    
                    // Then
                    expect(timerViewModel.currentTimeSecond).to(equal(2))
                }
            }
            
            // MARK: - Work/Break Mode Switching
            context("Work/Break mode switching") {
                
                it("should start in work mode") {
                    // Given - Fresh timer view model
                    
                    // Then
                    expect(timerViewModel.breakState).to(beFalse())
                }
                
                it("should switch from work mode to break mode when timer reaches zero") {
                    // Given
                    timerViewModel.breakState = false
                    timerViewModel.currentTimeSecond = 1
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(timerViewModel.breakState).to(beTrue())
                }
                
                it("should switch from break mode to work mode when timer reaches zero") {
                    // Given
                    timerViewModel.breakState = true
                    timerViewModel.currentTimeSecond = 1
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(timerViewModel.breakState).to(beFalse())
                }
                
                it("should count work sessions when switching from work to break") {
                    // Given
                    timerViewModel.breakState = false
                    timerViewModel.currentTimeSecond = 1
                    let initialCount = timerViewModel.todaysCount
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(timerViewModel.todaysCount).to(equal(initialCount + 1))
                }
                
                it("should not count work sessions when switching from break to work") {
                    // Given
                    timerViewModel.breakState = true
                    timerViewModel.currentTimeSecond = 1
                    let initialCount = timerViewModel.todaysCount
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(timerViewModel.todaysCount).to(equal(initialCount))
                }
            }
            
            // MARK: - Data Persistence
            context("Data persistence") {
                
                it("should save today's count when work session is completed") {
                    // Given
                    timerViewModel.breakState = false
                    timerViewModel.currentTimeSecond = 1
                    timerViewModel.todaysCount = 5
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(mockUserDefaultWrapper.saveDataIntCallCount).to(beGreaterThan(0))
                    expect(mockUserDefaultWrapper.lastSavedValue).to(equal(6))
                }
                
                it("should load today's count correctly") {
                    // Given
                    mockUserDefaultWrapper.mockIntValue = 3
                    
                    // When
                    timerViewModel.loadCount()
                    
                    // Then
                    expect(timerViewModel.todaysCount).to(equal(3))
                }
                
                it("should read user preferences correctly") {
                    // Given
                    mockUserDefaultWrapper.mockIntValue = 2 // Index for 15 minutes work time
                    mockUserDefaultWrapper.mockBoolValue = false
                    
                    // When
                    timerViewModel.readData()
                    
                    // Then
                    expect(timerViewModel.fullTimeSecond).to(equal(ItemValue.workingTimeList[2]))
                    expect(timerViewModel.vibration).to(beFalse())
                }
            }
            
            // MARK: - Audio Integration
            context("Audio integration") {
                
                it("should start audio when timer starts in work mode") {
                    // Given
                    timerViewModel.breakState = false
                    timerViewModel.executeState = false
                    
                    // When
                    timerViewModel.onPressedTimerButton()
                    
                    // Then
                    expect(spyAudioManager.startCallCount).to(equal(1))
                }
                
                it("should not start audio when timer starts in break mode") {
                    // Given
                    timerViewModel.breakState = true
                    timerViewModel.executeState = false
                    
                    // When
                    timerViewModel.onPressedTimerButton()
                    
                    // Then
                    expect(spyAudioManager.startCallCount).to(equal(0))
                }
                
                it("should stop audio when timer is stopped") {
                    // Given
                    timerViewModel.executeState = true
                    
                    // When
                    timerViewModel.onPressedTimerButton()
                    
                    // Then
                    expect(spyAudioManager.stopCallCount).to(equal(1))
                }
                
                it("should trigger vibration when enabled and timer reaches zero") {
                    // Given
                    timerViewModel.vibration = true
                    timerViewModel.currentTimeSecond = 1
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(spyAudioManager.vibrationCallCount).to(equal(1))
                }
                
                it("should not trigger vibration when disabled") {
                    // Given
                    timerViewModel.vibration = false
                    timerViewModel.currentTimeSecond = 1
                    
                    // When
                    timerViewModel.updateTime()
                    
                    // Then
                    expect(spyAudioManager.vibrationCallCount).to(equal(0))
                }
            }
            
            // MARK: - State Management
            context("State management") {
                
                it("should initialize with correct default values") {
                    // Then
                    expect(timerViewModel.fullTimeSecond).to(equal(25*60))
                    expect(timerViewModel.fullBreakTimeSecond).to(equal(5*60))
                    expect(timerViewModel.currentTimeSecond).to(equal(25*60))
                    expect(timerViewModel.executeState).to(beFalse())
                    expect(timerViewModel.breakState).to(beFalse())
                    expect(timerViewModel.vibration).to(beTrue())
                    expect(timerViewModel.todaysCount).to(equal(0))
                }
                
                it("should handle screen opening correctly on first launch") {
                    // Given - Fresh timer view model
                    timerViewModel.currentTimeSecond = 100
                    
                    // When
                    timerViewModel.openScreen()
                    
                    // Then - Should reset to full time
                    expect(timerViewModel.currentTimeSecond).to(equal(25*60))
                }
                
                it("should not reset time on subsequent screen openings") {
                    // Given
                    timerViewModel.openScreen() // First call
                    timerViewModel.currentTimeSecond = 500
                    
                    // When
                    timerViewModel.openScreen() // Second call
                    
                    // Then - Should keep current time
                    expect(timerViewModel.currentTimeSecond).to(equal(500))
                }
            }
            
            // MARK: - Memory Management
            context("Memory management") {
                
                it("should not retain strong references that cause memory leaks") {
                    weak var weakTimerViewModel: TimerViewModel?
                    
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
                    expect(weakTimerViewModel).to(beNil())
                }
            }
        }
    }
}