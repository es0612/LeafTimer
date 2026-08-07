// app/LeafTimerTests/TimerViewModelAccessibilityTests.swift
import XCTest
@testable import LeafTimer

/// Issue #59: 開始/停止ボタンの VoiceOver ラベルが executeState と連動することを検証する。
/// TimerView.swift の三項演算子 (getButtonState() と同じ状態分岐の重複) を
/// TimerViewModel+extensions.swift の getAccessibilityLabel() へ引き上げた結果を、
/// ViewInspector を経由せず ViewModel 単体で確認する
/// (AdsBannerView/AccessibilityImageLabel の traversal blocker を回避するため)。
final class TimerViewModelAccessibilityTests: XCTestCase {

    private func makeViewModel() -> TimerViewModel {
        TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: SpyAudioManager(),
            userDefaultWrapper: LocalUserDefaultsWrapper(),
            sessionStatsRepository: SpySessionStatsRepository()
        )
    }

    func testAccessibilityLabelWhenStopped() {
        let viewModel = makeViewModel()
        viewModel.executeState = false

        XCTAssertEqual(
            viewModel.getAccessibilityLabel(),
            NSLocalizedString("timer.a11y.start", comment: "Start timer button")
        )
    }

    func testAccessibilityLabelWhenRunning() {
        let viewModel = makeViewModel()
        viewModel.executeState = true

        XCTAssertEqual(
            viewModel.getAccessibilityLabel(),
            NSLocalizedString("timer.a11y.stop", comment: "Stop timer button")
        )
    }
}
