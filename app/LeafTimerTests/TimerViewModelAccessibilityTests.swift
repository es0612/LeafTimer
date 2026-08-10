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

    // MARK: - Issue #97: 残り時間の読み上げ値 (M6)

    // 期待値は RED 実行の actual 出力でピン留めする (ICU の空白/区切りは OS 依存のため推測禁止)。
    private let ja = Locale(identifier: "ja_JP")
    private let en = Locale(identifier: "en_US")

    func testAccessibilityTimeValueMinutesOnlyJapanese() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 25 * 60

        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: ja), "25分")
    }

    func testAccessibilityTimeValueMinutesAndSecondsJapanese() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 25 * 60 + 30

        // ICU 出力実測値: 分秒の間に半角スペースが入る (2026-08-11, iOS 18 simulator で観測)
        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: ja), "25分 30秒")
    }

    func testAccessibilityTimeValueMinutesAndSecondsEnglish() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 25 * 60 + 30

        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: en), "25 minutes, 30 seconds")
    }

    func testAccessibilityTimeValueSingularMinuteEnglish() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 60

        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: en), "1 minute")
    }

    func testAccessibilityTimeValueSecondsOnlyJapanese() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 59

        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: ja), "59秒")
    }

    func testAccessibilityTimeValueZeroJapanese() {
        let viewModel = makeViewModel()
        viewModel.currentTimeSecond = 0

        XCTAssertEqual(viewModel.getAccessibilityTimeValue(locale: ja), "0秒")
    }
}
