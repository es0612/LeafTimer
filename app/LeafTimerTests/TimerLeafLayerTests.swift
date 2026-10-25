import XCTest
import ViewInspector
import SwiftUI
@testable import LeafTimer

/// Issue #188: 葉は START ボタンの background に置き、ボタンの上端に重ねる。
/// 重なった部分のタップをボタンに通し、VoiceOver でも飾りとして読ませない。
final class TimerLeafLayerTests: XCTestCase {
    private func makeTimerView() -> TimerView {
        TimerView(
            timerViewModel: TimerViewModel(
                timerManager: SpyTimerManager(),
                audioManager: SpyAudioManager(),
                userDefaultWrapper: LocalUserDefaultsWrapper(),
                sessionStatsRepository: SpySessionStatsRepository()
            ),
            settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
        )
    }

    func testLeafDoesNotReceiveTaps() throws {
        let leaf = try makeTimerView().body.inspect().find(ViewType.View<GIFView>.self)

        XCTAssertFalse(try leaf.allowsHitTesting())
    }

    func testLeafIsHiddenFromVoiceOver() throws {
        let leaf = try makeTimerView().body.inspect().find(ViewType.View<GIFView>.self)

        XCTAssertTrue(try leaf.accessibilityHidden())
    }

    // Issue #190: GIFView は gifName が変わっても GIF を読み直さない。名前を id にして、
    // 芽 → 若木 → 木 に変わるたびに作り直させる (#64 で分岐を 1 つにまとめてから効いていなかった)
    func testLeafIsRecreatedWhenGifNameChanges() throws {
        let leaf = try makeTimerView().body.inspect().find(ViewType.View<GIFView>.self)

        XCTAssertEqual(try leaf.id(), AnyHashable(try leaf.actualView().gifName))
    }
}
