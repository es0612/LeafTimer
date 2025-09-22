import SwiftUI

// Import new component types for extension
struct TimerControlState {
    enum State {
        case idle
        case running
        case paused
    }
}

struct TimerMode {
    enum Mode {
        case work
        case `break`
    }
}

extension TimerViewModel {
    func getDisplayedTime() -> String {
        let minString
            = String(format: "%02d", Int(currentTimeSecond / 60))
        let secondString
            = String(format: "%02d", Int(currentTimeSecond % 60))

        return minString + ":" + secondString
    }

    func getButtonState() -> String {
        switch executeState {
        case true:
            NSLocalizedString("button.stop", comment: "Stop button")

        case false:
            NSLocalizedString("button.start", comment: "Start button")
        }
    }

    func getBackgroundColor() -> LinearGradient {
        if breakState {
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color(.displayP3, red: 0.94, green: 0.96, blue: 0.98),
                        Color(.displayP3, red: 0.77, green: 0.80, blue: 0.88),
                    ]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color(.displayP3, red: 0.95, green: 0.98, blue: 0.95),
                        Color(.displayP3, red: 0.87, green: 0.91, blue: 0.85),
                    ]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    func getColor1() -> Color {
        if breakState {
            Color(.init(red: 0.35, green: 0.38, blue: 0.46, alpha: 1))
        } else {
            Color(.init(red: 0.35, green: 0.47, blue: 0.35, alpha: 1))
        }
    }

    func getColor2() -> Color {
        if breakState {
            Color(.init(red: 0.52, green: 0.66, blue: 0.73, alpha: 1))
        } else {
            Color(.init(red: 0.57, green: 0.73, blue: 0.52, alpha: 1))
        }
    }

    func getColor3() -> Color {
        if breakState {
            Color(.init(red: 0.41, green: 0.57, blue: 0.71, alpha: 1))
        } else {
            Color(.init(red: 0.49, green: 0.71, blue: 0.41, alpha: 1))
        }
    }

    func getColor4() -> Color {
        if breakState {
            Color(.init(red: 0.29, green: 0.45, blue: 0.67, alpha: 1))
        } else {
            Color(.init(red: 0.35, green: 0.68, blue: 0.29, alpha: 1))
        }
    }

    func getLeafPattern() -> LeafPattern {
        let percent = Double(currentTimeSecond) / Double(fullTimeSecond)

        if percent > 0.7 {
            return .small
        } else if percent > 0.3 {
            return .mid
        } else {
            return .big
        }
    }
}

enum LeafPattern {
    case small
    case mid
    case big
}

// MARK: - Modern Timer Extensions
extension TimerViewModel {
    var weeklyAverage: Double {
        // Calculate weekly average from stored data
        // For now, return a mock value - will be replaced with actual calculation
        return Double(todaysCount) * 0.8
    }

    var timerState: TimerControlState.State {
        if executeState {
            return .running
        } else if currentTimeSecond < fullTimeSecond {
            return .paused
        } else {
            return .idle
        }
    }

    var currentTimerMode: TimerMode.Mode {
        return breakState ? .break : .work
    }
}
