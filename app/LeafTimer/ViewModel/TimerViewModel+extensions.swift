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

    // Issue #59: 開始/停止ボタンの VoiceOver ラベル。View 側での状態分岐重複を避けるため ViewModel に集約する。
    func getAccessibilityLabel() -> String {
        switch executeState {
        case true:
            NSLocalizedString("timer.a11y.stop", comment: "Stop timer button")

        case false:
            NSLocalizedString("timer.a11y.start", comment: "Start timer button")
        }
    }

    // Issue #97: 残り時間の VoiceOver 読み上げ値。"25:00" の数字列読みを避け、
    // DateComponentsFormatter に単数複数・ロケール処理ごと委譲する。
    // 毎秒呼ばれるが formatter は軽量で、locale 注入 (テスト決定性) と両立させるため都度生成のままにする。
    func getAccessibilityTimeValue(locale: Locale = .current) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        if currentTimeSecond < 60 {
            // 0 を「0秒」と読ませるため zero を drop しない
            formatter.allowedUnits = [.second]
        } else {
            formatter.allowedUnits = [.minute, .second]
            formatter.zeroFormattingBehavior = .dropTrailing
        }
        return formatter.string(from: TimeInterval(currentTimeSecond)) ?? getDisplayedTime()
    }

    // Issue #63: 色の値は App/Assets.xcassets の named color (light/dark の対) に持たせる。
    // named color が環境の colorScheme で解決されるため、ここでは work/break だけで分岐する。
    func getBackgroundColor() -> LinearGradient {
        let colors: [Color] = if breakState {
            [AppColor.breakGradientTop.color, AppColor.breakGradientBottom.color]
        } else {
            [AppColor.workGradientTop.color, AppColor.workGradientBottom.color]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
    }

    func getColor1() -> Color {
        breakState ? AppColor.breakRing1.color : AppColor.workRing1.color
    }

    func getColor2() -> Color {
        breakState ? AppColor.breakRing2.color : AppColor.workRing2.color
    }

    func getColor3() -> Color {
        breakState ? AppColor.breakRing3.color : AppColor.workRing3.color
    }

    func getColor4() -> Color {
        breakState ? AppColor.breakRing4.color : AppColor.workRing4.color
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
