import Nimble
import Quick
import ViewInspector

import SwiftUI

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override class func spec() {
        describe("test for TimerView") {
            var timerView: TimerView!
            var timerViewModel: TimerViewModel!
            var spyTimerManager: SpyTimerManager!

            beforeEach {
                spyTimerManager = SpyTimerManager()
                timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: SpyAudioManager(),
                    userDefaultWrapper: LocalUserDefaultsWrapper(),
                    sessionStatsRepository: SpySessionStatsRepository()
                )
                timerView = TimerView(
                    timerViewModel: timerViewModel,
                    settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
                )
            }

            // Issue #129: index パスでなく find(text:) で実際の表示文字列を検索する形へ移行。
            // 期待値は UserDefaults 依存のため定数でなく getDisplayedTime() から動的に取得する。
            it("displayed remaining time.") {
                let textViewString = try timerView.body
                    .inspect().find(text: timerViewModel.getDisplayedTime()).string()

                expect(textViewString) == timerViewModel.getDisplayedTime()
            }

            it("displayed navigation bar") {
                let navStack = try timerView.body.inspect().navigationStack()

                expect(navStack) != nil
            }

            // Issue #129: toolbar modifier は VStack (GeometryReader > ZStack > VStack) に
            // 付与されているため正しいパスへ移行
            it("displayed navigation bar button item") {
                let toolbarButton = try timerView.body.inspect().navigationStack()
                    .geometryReader().zStack().vStack(2).toolbar()

                expect(toolbarButton) != nil
            }

            // Issue #129: index パスでなく CircleButton を包む Button を find() で検索する形へ移行
            it("call timerManager methods when button tapped") {
                let stopButton = try timerView.body.inspect().find(ViewType.Button.self, where: { candidate in
                    (try? candidate.find(CircleButton.self)) != nil
                })

                try stopButton.tap()

                _ = try timerView.body.inspect()

                expect(spyTimerManager.startWasCalled).toEventually(beTrue())
            }
        }
    }
}
