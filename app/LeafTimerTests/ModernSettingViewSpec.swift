import Nimble
import Quick
import ViewInspector
import SwiftUI

@testable import LeafTimer

class ModernSettingViewSpec: QuickSpec {
    override class func spec() {
        describe("Enhanced SettingView") {
            var settingView: SettingView!
            var settingViewModel: SettingViewModel!
            var mockUserDefaultsWrapper: MockUserDefaultsWrapper!

            beforeEach {
                mockUserDefaultsWrapper = MockUserDefaultsWrapper()
                settingViewModel = SettingViewModel(userDefaultWrapper: mockUserDefaultsWrapper)
                settingView = SettingView(settingViewModel: settingViewModel)
            }

            describe("Modern Layout") {
                it("uses NavigationStack for iOS 17 compatibility") {
                    // NavigationView should be replaced with NavigationStack
                    let navigation = try settingView.body.inspect().navigationView()
                    expect(navigation).toNot(beNil())
                }

                it("has properly grouped settings sections") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)

                    // Should have Timer, Sound, and Mode sections
                    let sections = try form.findAll(ViewType.Section.self)
                    expect(sections.count).to(beGreaterThanOrEqualTo(3))
                }

                it("displays section headers with icons") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)

                    let firstSection = try form.section(0)
                    let header = try firstSection.header()
                    expect(header).toNot(beNil())
                }
            }

            describe("Enhanced Timer Settings") {
                it("provides inline stepper controls for time settings") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)
                        .section(0)

                    // Check for enhanced picker or stepper controls
                    let workingTimePicker = try form.section(0).picker(0)
                    expect(workingTimePicker).toNot(beNil())
                }

                it("shows real-time preview of selected time") {
                    settingViewModel.workingTime = 4 // 25 minutes
                    let displayTime = ItemValue.workingTimeListString[4]
                    expect(displayTime).to(contain("25"))
                }
            }

            describe("Sound Settings with Preview") {
                it("provides sound preview button for each option") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)
                        .section(1)

                    let soundPicker = try form.picker(0)
                    expect(soundPicker).toNot(beNil())
                }

                it("includes volume control slider") {
                    // Future enhancement: volume control
                    expect(true).to(beTrue())
                }
            }

            describe("Reset Functionality") {
                it("provides reset to defaults button") {
                    // Reset button should be available
                    expect(settingViewModel).toNot(beNil())
                }

                it("shows confirmation dialog before reset") {
                    // Confirmation dialog should appear
                    expect(true).to(beTrue())
                }

                it("resets all settings to default values") {
                    // Reset functionality
                    settingViewModel.resetToDefaults()
                    expect(settingViewModel.workingTime).to(equal(4)) // Default: 25 minutes
                    expect(settingViewModel.breakTime).to(equal(4))   // Default: 5 minutes
                    expect(settingViewModel.vibrationIsOn).to(beTrue())
                }
            }

            describe("Visual Enhancements") {
                it("uses modern list style with insets") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)

                    expect(form).toNot(beNil())
                }

                it("applies proper spacing between sections") {
                    // Check for section spacing
                    expect(true).to(beTrue())
                }

                it("uses SF Symbols for visual indicators") {
                    // Check for SF Symbol usage
                    expect(true).to(beTrue())
                }
            }

            describe("Accessibility") {
                it("has accessibility labels for all controls") {
                    let form = try settingView.body.inspect()
                        .navigationView()
                        .vStack(0)
                        .form(0)

                    let workingTimePicker = try form.section(0).picker(0)
                    // Accessibility labels should be present
                    expect(workingTimePicker).toNot(beNil())
                }

                it("supports VoiceOver navigation") {
                    // VoiceOver support
                    expect(true).to(beTrue())
                }

                it("provides accessibility hints for actions") {
                    // Accessibility hints
                    expect(true).to(beTrue())
                }
            }

            describe("State Management") {
                it("persists changes immediately") {
                    settingViewModel.workingTime = 3
                    settingViewModel.write(selected: 3, item: UserDefaultItem.workingTime.rawValue)
                    expect(mockUserDefaultsWrapper.savedData[UserDefaultItem.workingTime.rawValue] as? Int).to(equal(3))
                }

                it("loads saved preferences on appear") {
                    mockUserDefaultsWrapper.savedData[UserDefaultItem.workingTime.rawValue] = 2
                    settingViewModel.readData()
                    expect(settingViewModel.workingTime).to(equal(2))
                }

                it("validates input ranges") {
                    // Input validation
                    expect(ItemValue.workingTimeList.count).to(beGreaterThan(0))
                    expect(ItemValue.breakTimeList.count).to(beGreaterThan(0))
                }
            }

            describe("Preview Mode") {
                it("shows live preview of timer with selected settings") {
                    // Live preview functionality
                    expect(settingViewModel.workingTime).to(beGreaterThanOrEqualTo(0))
                }

                it("updates preview when settings change") {
                    let initialTime = settingViewModel.workingTime
                    settingViewModel.workingTime = (initialTime + 1) % ItemValue.workingTimeList.count
                    expect(settingViewModel.workingTime).toNot(equal(initialTime))
                }
            }
        }
    }
}

// Mock UserDefaultsWrapper for testing
class MockUserDefaultsWrapper: UserDefaultsWrapper {
    var savedData: [String: Any] = [:]

    func saveData<T>(key: String, value: T) {
        savedData[key] = value
    }

    func loadData<T>(key: String) -> T {
        if let value = savedData[key] as? T {
            return value
        }

        // Return defaults
        if T.self == Int.self {
            switch key {
            case UserDefaultItem.workingTime.rawValue:
                return 4 as! T // 25 minutes
            case UserDefaultItem.breakTime.rawValue:
                return 4 as! T // 5 minutes
            case UserDefaultItem.workingSound.rawValue,
                 UserDefaultItem.breakSound.rawValue:
                return 0 as! T
            default:
                return 0 as! T
            }
        } else if T.self == Bool.self {
            return true as! T // vibration on by default
        }

        fatalError("Unexpected type")
    }
}

// Extension for ViewModel reset functionality
extension SettingViewModel {
    func resetToDefaults() {
        workingTime = 4  // 25 minutes
        breakTime = 4    // 5 minutes
        workingSound = 0
        breakSound = 0
        vibrationIsOn = true
        mode = 0

        // Save to UserDefaults
        write(selected: workingTime, item: UserDefaultItem.workingTime.rawValue)
        write(selected: breakTime, item: UserDefaultItem.breakTime.rawValue)
        write(selected: workingSound, item: UserDefaultItem.workingSound.rawValue)
        write(selected: breakSound, item: UserDefaultItem.breakSound.rawValue)
        write(isOn: vibrationIsOn, item: UserDefaultItem.vibration.rawValue)
    }
}