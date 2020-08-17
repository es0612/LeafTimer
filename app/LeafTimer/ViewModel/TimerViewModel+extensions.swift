import SwiftUI

extension TimerViewModel {
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

    func getBackgroundColor() -> LinearGradient{
        if breakState {
            return LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color(.displayP3, red: 0.77, green: 0.80, blue: 0.88),
                        Color(.displayP3, red: 0.94, green: 0.96, blue: 0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color(.displayP3, red: 0.95, green: 0.98, blue: 0.95),
                        Color(.displayP3, red: 0.89, green: 0.93, blue: 0.88)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    func getColor1() -> Color {
        if breakState {
            return Color(.init(red: 0.35, green: 0.38, blue: 0.46, alpha: 1))
        } else {
            return Color(.init(red: 0.35, green: 0.47, blue: 0.35, alpha: 1))
        }

    }

    func getColor2() -> Color {
        if breakState {
            return Color(.init(red: 0.52, green: 0.66, blue: 0.73, alpha: 1))
        } else {
            return Color(.init(red: 0.57, green: 0.73, blue: 0.52, alpha: 1))
        }
    }

    func getColor3() -> Color {
        if breakState {
            return Color(.init(red: 0.41, green: 0.57, blue: 0.71, alpha: 1))
        } else {
            return Color(.init(red: 0.49, green: 0.71, blue: 0.41, alpha: 1))
        }
    }

    func getColor4() -> Color {
        if breakState {
            return Color(.init(red: 0.29, green: 0.45, blue: 0.67, alpha: 1))
        } else {
            return Color(.init(red: 0.35, green: 0.68, blue: 0.29, alpha: 1))
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

enum LeafPattern{
    case small
    case mid
    case big
}

