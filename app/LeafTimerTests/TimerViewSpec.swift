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

            // Issue #132: find(text: getDisplayedTime()) を getDisplayedTime() と比較するのは同語反復だった。
            // currentTimeSecond を固定して UserDefaults 非依存の定数 "20:00" を期待値にする。
            it("displayed remaining time.") {
                timerViewModel.currentTimeSecond = 1200

                let textViewString = try timerView.body
                    .inspect().find(text: "20:00").string()

                expect(textViewString) == "20:00"
            }

            it("displayed navigation bar") {
                let navStack = try timerView.body.inspect().navigationStack()

                expect(navStack) != nil
            }

            // Issue #132: toolbar の存在だけでなく 3 つの ToolbarItem (reset / history / settings) の
            // アイコンまで検証する。item(3) が無いことも確認して増減を検出する。
            it("displayed navigation bar button item") {
                let toolbar = try timerView.body.inspect().navigationStack()
                    .geometryReader().zStack().vStack(2).toolbar()

                let icons = try (0..<3).map { index in
                    try toolbar.item(index).find(ViewType.Image.self).actualImage().name()
                }
                expect(icons) == ["arrow.counterclockwise", "chart.bar.fill", "gearshape.fill"]
                expect { try toolbar.item(3) }.to(throwError())
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
