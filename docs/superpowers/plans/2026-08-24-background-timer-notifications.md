# バックグラウンド動作 + 完了通知 実装プラン (Issue #54)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** サウンドなし設定でアプリが suspend されてもポモドーロが壁時計基準で自動進行し、フェーズ終了 (作業終了/休憩終了) がローカル通知で届くようにする。

**Architecture:** ローカル通知チェーン + 復帰時リコンサイル方式。タイマー開始時に先 3 往復分 (6 件) のフェーズ境界通知を `UNUserNotificationCenter` に予約し、`willEnterForeground` で純粋ロジック `PhaseReconciler` が壁時計から跨いだフェーズ数を計算して状態・統計を更新する。プロセスの延命はしない。

**Tech Stack:** Swift / SwiftUI / UserNotifications / XCTest (テスト新規分は Quick でなく XCTest。`FakeClock` は `TimerCoreLogicSpec.swift` 定義済みのものを再利用)

**Spec:** `docs/superpowers/specs/2026-08-24-background-timer-notifications-design.md`

## Global Constraints

- ビルド/テストは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests` (Bash timeout 600000)。成否は `** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` の不在で判定する。
- 新規 Swift ファイルを追加する commit には (1) `ruby bin/add-to-target.rb` での target attach、(2) `make sort` の結果 (pbxproj) を **同一 commit に含める** (CLAUDE.md ルール 28)。
- ローカライズは String Catalog ではなく従来型 `.strings` (`LeafTimer/App/ja.lproj/Localizable.strings` / `en.lproj/Localizable.strings`)。追記後 `make localization-check` が green であること。
- SwiftLint: 新規コードは `.isEmpty` を使う。`make lint` green を維持。
- default branch は `master`。作業ブランチは `feature/54-background-timer-notifications` (作成済み・spec commit 済み)。

---

### Task 1: PhaseReconciler (純粋ロジック)

**Files:**
- Create: `app/LeafTimer/Components/PhaseReconciler.swift`
- Test: `app/LeafTimerTests/PhaseReconcilerTests.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (add-to-target + make sort)

**Interfaces:**
- Consumes: なし (Foundation のみ)
- Produces: `PhaseReconciler.reconcile(endDate:breakState:workDuration:breakDuration:now:) -> PhaseReconcileResult`。`PhaseReconcileResult` は `breakState: Bool, completedWorkCount: Int, remainingSeconds: Int, newEndDate: Date` を持つ Equatable struct。Task 3 が消費する。

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/PhaseReconcilerTests.swift`:

```swift
import XCTest

@testable import LeafTimer

// Issue #54: suspend 中のフェーズ跨ぎを壁時計から一括計算する純粋ロジックの検証。
final class PhaseReconcilerTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let work = 25 * 60
    private let brk = 5 * 60

    // 跨ぎゼロ: endDate 前に復帰 → 残り秒のみ更新 (冪等性の要)
    func testNoCrossingUpdatesRemainingOnly() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: base.addingTimeInterval(100)
        )
        XCTAssertEqual(result, PhaseReconcileResult(
            breakState: false, completedWorkCount: 0,
            remainingSeconds: 500, newEndDate: end
        ))
    }

    // work 終了を 1 回跨ぐ → break 中・work 1 完了
    func testCrossingOneWorkEnd() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: end.addingTimeInterval(10)
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 1)
        XCTAssertEqual(result.remainingSeconds, brk - 10)
        XCTAssertEqual(result.newEndDate, end.addingTimeInterval(TimeInterval(brk)))
    }

    // ちょうど境界 (now == endDate) は「跨いだ」扱い
    func testExactBoundaryCountsAsCrossed() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: end
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 1)
        XCTAssertEqual(result.remainingSeconds, brk)
    }

    // 複数往復: work 終了 → break 終了 → work 終了 (work 2 完了、break 中)
    func testCrossingMultiplePhases() {
        let end = base.addingTimeInterval(600)
        // 跨ぐ量: 600 (今の work 残り) + brk + work + 30 秒
        let now = base.addingTimeInterval(TimeInterval(600 + brk + work + 30))
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: now
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 2)
        XCTAssertEqual(result.remainingSeconds, brk - 30)
    }

    // break 起点: break 終了を跨いでも work は完了しない
    func testCrossingFromBreakDoesNotCountWork() {
        let end = base.addingTimeInterval(100)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: true,
            workDuration: work, breakDuration: brk,
            now: end.addingTimeInterval(20)
        )
        XCTAssertEqual(result.breakState, false)
        XCTAssertEqual(result.completedWorkCount, 0)
        XCTAssertEqual(result.remainingSeconds, work - 20)
    }

    // duration が両方 0 (異常系) は無限ループせず現状維持で返す
    func testZeroDurationsReturnSafely() {
        let end = base
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: 0, breakDuration: 0,
            now: base.addingTimeInterval(50)
        )
        XCTAssertEqual(result.completedWorkCount, 0)
        XCTAssertEqual(result.remainingSeconds, 0)
    }
}
```

- [ ] **Step 2: target 登録して RED を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/PhaseReconcilerTests.swift LeafTimerTests LeafTimerTests && \
  make unit-tests
```
Expected: ビルドエラー `cannot find 'PhaseReconciler' in scope` (= RED)。timeout 600000。

- [ ] **Step 3: 最小実装**

`app/LeafTimer/Components/PhaseReconciler.swift`:

```swift
import Foundation

// Issue #54: suspend 中に跨いだフェーズ境界を壁時計から一括計算する。
// 副作用なしの純粋ロジック。now < endDate なら跨ぎゼロで冪等。
struct PhaseReconcileResult: Equatable {
    let breakState: Bool
    let completedWorkCount: Int
    let remainingSeconds: Int
    let newEndDate: Date
}

enum PhaseReconciler {
    static func reconcile(
        endDate: Date,
        breakState: Bool,
        workDuration: Int,
        breakDuration: Int,
        now: Date
    ) -> PhaseReconcileResult {
        guard workDuration + breakDuration > 0 else {
            return PhaseReconcileResult(
                breakState: breakState, completedWorkCount: 0,
                remainingSeconds: 0, newEndDate: endDate
            )
        }

        var end = endDate
        var isBreak = breakState
        var completedWork = 0

        while now >= end {
            if !isBreak {
                completedWork += 1
            }
            isBreak.toggle()
            let nextDuration = isBreak ? breakDuration : workDuration
            end = end.addingTimeInterval(TimeInterval(nextDuration))
        }

        let remaining = max(0, Int(end.timeIntervalSince(now).rounded()))
        return PhaseReconcileResult(
            breakState: isBreak, completedWorkCount: completedWork,
            remainingSeconds: remaining, newEndDate: end
        )
    }
}
```

注意: `workDuration > 0, breakDuration == 0` のケースでも 1 周期合計が正なのでループは停止する。

- [ ] **Step 4: target 登録 + GREEN 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/PhaseReconciler.swift LeafTimer LeafTimer/Components && \
  make unit-tests
```
Expected: `** TEST SUCCEEDED **`。timeout 600000。

- [ ] **Step 5: sort + precheck + commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make sort && make precheck && \
  git add LeafTimer/Components/PhaseReconciler.swift LeafTimerTests/PhaseReconcilerTests.swift LeafTimer.xcodeproj/project.pbxproj && \
  git commit -m "feat: #54 PhaseReconciler で suspend 中のフェーズ跨ぎを壁時計計算"
```

---

### Task 2: NotificationScheduler + チェーン構築 + ローカライズ文言

**Files:**
- Create: `app/LeafTimer/Components/NotificationScheduler.swift` (protocol + `NotificationEntry` + `NotificationChainBuilder`)
- Create: `app/LeafTimer/Components/DefaultNotificationScheduler.swift`
- Create: `app/LeafTimerTests/NotificationChainBuilderTests.swift`
- Create: `app/LeafTimerTests/SpyNotificationScheduler.swift`
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings` / `app/LeafTimer/App/en.lproj/Localizable.strings` (末尾に 4 key 追記)
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: なし
- Produces (Task 3 が消費):
  - `protocol NotificationScheduler { func requestAuthorizationIfNeeded(); func scheduleChain(entries: [NotificationEntry]); func cancelAll() }`
  - `struct NotificationEntry: Equatable { let fireDate: Date; let titleKey: String; let bodyKey: String }` (ローカライズは Default 実装が schedule 時に行う)
  - `NotificationChainBuilder.build(endDate:breakState:workDuration:breakDuration:) -> [NotificationEntry]` (3 往復 = 6 件)
  - テスト用 `SpyNotificationScheduler` (`requestAuthorizationCallCount`, `scheduledChains: [[NotificationEntry]]`, `cancelAllCallCount`)

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/NotificationChainBuilderTests.swift`:

```swift
import XCTest

@testable import LeafTimer

final class NotificationChainBuilderTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let work = 25 * 60
    private let brk = 5 * 60

    // work 中に開始 → workEnd, breakEnd, ... が交互に 6 件
    func testBuildsAlternatingChainFromWork() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: false,
            workDuration: work, breakDuration: brk
        )
        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(entries[0], NotificationEntry(
            fireDate: base,
            titleKey: "notification.workEnd.title",
            bodyKey: "notification.workEnd.body"
        ))
        XCTAssertEqual(entries[1], NotificationEntry(
            fireDate: base.addingTimeInterval(TimeInterval(brk)),
            titleKey: "notification.breakEnd.title",
            bodyKey: "notification.breakEnd.body"
        ))
        XCTAssertEqual(entries[2].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            entries[2].fireDate,
            base.addingTimeInterval(TimeInterval(brk + work))
        )
    }

    // break 中に開始 → 先頭は breakEnd
    func testBuildsChainFromBreak() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: true,
            workDuration: work, breakDuration: brk
        )
        XCTAssertEqual(entries[0].titleKey, "notification.breakEnd.title")
        XCTAssertEqual(entries[1].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            entries[1].fireDate,
            base.addingTimeInterval(TimeInterval(work))
        )
    }

    // duration 両方 0 は空チェーン
    func testZeroDurationsReturnEmpty() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: false,
            workDuration: 0, breakDuration: 0
        )
        XCTAssertTrue(entries.isEmpty)
    }
}
```

- [ ] **Step 2: target 登録して RED を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/NotificationChainBuilderTests.swift LeafTimerTests LeafTimerTests && \
  make unit-tests
```
Expected: `cannot find 'NotificationChainBuilder' in scope` (= RED)。timeout 600000。

- [ ] **Step 3: 実装 (protocol / builder / spy / default / strings)**

`app/LeafTimer/Components/NotificationScheduler.swift`:

```swift
import Foundation

// Issue #54: フェーズ境界のローカル通知予約の抽象。
// TimerManager / AudioManager と同じ protocol DI パターン。
struct NotificationEntry: Equatable {
    let fireDate: Date
    let titleKey: String
    let bodyKey: String
}

protocol NotificationScheduler {
    func requestAuthorizationIfNeeded()
    func scheduleChain(entries: [NotificationEntry])
    func cancelAll()
}

// タイマー開始時点の状態から先 3 往復分のフェーズ境界通知を組み立てる純粋ロジック。
enum NotificationChainBuilder {
    static let cycles = 3

    static func build(
        endDate: Date,
        breakState: Bool,
        workDuration: Int,
        breakDuration: Int
    ) -> [NotificationEntry] {
        guard workDuration + breakDuration > 0 else { return [] }

        var entries: [NotificationEntry] = []
        var fireDate = endDate
        var isBreak = breakState

        for _ in 0..<(cycles * 2) {
            let entry = isBreak
                ? NotificationEntry(
                    fireDate: fireDate,
                    titleKey: "notification.breakEnd.title",
                    bodyKey: "notification.breakEnd.body"
                )
                : NotificationEntry(
                    fireDate: fireDate,
                    titleKey: "notification.workEnd.title",
                    bodyKey: "notification.workEnd.body"
                )
            entries.append(entry)

            isBreak.toggle()
            let nextDuration = isBreak ? breakDuration : workDuration
            fireDate = fireDate.addingTimeInterval(TimeInterval(nextDuration))
        }

        return entries
    }
}
```

`app/LeafTimer/Components/DefaultNotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications

// Issue #54: UNUserNotificationCenter の thin wrapper。unit test 対象外
// (Simulator 実地確認で代替)。identifier は固定 prefix + index で、
// cancelAll は自分の予約分だけを削除する。
class DefaultNotificationScheduler: NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "jp.ema.LeafTimer.phase."
    private var didRequestAuthorization = false

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleChain(entries: [NotificationEntry]) {
        cancelAll()

        for (index, entry) in entries.enumerated() {
            let interval = entry.fireDate.timeIntervalSinceNow
            guard interval > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString(entry.titleKey, comment: "")
            content.body = NSLocalizedString(entry.bodyKey, comment: "")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval, repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(index),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelAll() {
        let identifiers = (0..<(NotificationChainBuilder.cycles * 2))
            .map { Self.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
```

`app/LeafTimerTests/SpyNotificationScheduler.swift`:

```swift
import Foundation

@testable import LeafTimer

class SpyNotificationScheduler: NotificationScheduler {
    private(set) var requestAuthorizationCallCount = 0
    func requestAuthorizationIfNeeded() {
        requestAuthorizationCallCount += 1
    }

    private(set) var scheduledChains: [[NotificationEntry]] = []
    func scheduleChain(entries: [NotificationEntry]) {
        scheduledChains.append(entries)
    }

    private(set) var cancelAllCallCount = 0
    func cancelAll() {
        cancelAllCallCount += 1
    }
}
```

`app/LeafTimer/App/ja.lproj/Localizable.strings` 末尾に追記:

```text

/* Issue #54: フェーズ終了通知 */
"notification.workEnd.title" = "作業おつかれさま！";
"notification.workEnd.body" = "休憩しよう🍃";
"notification.breakEnd.title" = "休憩終了！";
"notification.breakEnd.body" = "次のポモドーロを始めよう";
```

`app/LeafTimer/App/en.lproj/Localizable.strings` 末尾に追記:

```text

/* Issue #54: phase-end notifications */
"notification.workEnd.title" = "Great work!";
"notification.workEnd.body" = "Time for a break 🍃";
"notification.breakEnd.title" = "Break's over!";
"notification.breakEnd.body" = "Let's start the next Pomodoro";
```

- [ ] **Step 4: target 登録 + GREEN 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/NotificationScheduler.swift LeafTimer LeafTimer/Components && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/DefaultNotificationScheduler.swift LeafTimer LeafTimer/Components && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/SpyNotificationScheduler.swift LeafTimerTests LeafTimerTests && \
  make localization-check && make unit-tests
```
Expected: localization-check green + `** TEST SUCCEEDED **`。timeout 600000。

- [ ] **Step 5: sort + precheck + commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make sort && make precheck && \
  git add LeafTimer/Components/NotificationScheduler.swift \
          LeafTimer/Components/DefaultNotificationScheduler.swift \
          LeafTimerTests/NotificationChainBuilderTests.swift \
          LeafTimerTests/SpyNotificationScheduler.swift \
          LeafTimer/App/ja.lproj/Localizable.strings \
          LeafTimer/App/en.lproj/Localizable.strings \
          LeafTimer.xcodeproj/project.pbxproj && \
  git commit -m "feat: #54 NotificationScheduler とフェーズ境界通知チェーンを追加"
```

---

### Task 3: TimerViewModel 統合 (予約・キャンセル・リコンサイル)

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift`
- Create: `app/LeafTimerTests/TimerNotificationIntegrationTests.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 1 の `PhaseReconciler.reconcile(...)`、Task 2 の `NotificationScheduler` / `NotificationChainBuilder.build(...)` / `SpyNotificationScheduler`。既存の `FakeClock` (`TimerCoreLogicSpec.swift` 定義、同一テストターゲット内なので import 不要)。
- Produces: `TimerViewModel.handleWillEnterForeground()` (internal メソッド、テストから直接呼ぶ)。init 追加パラメータ `notificationScheduler: NotificationScheduler = DefaultNotificationScheduler()` — default 値があるため `AppDelegate.swift` / `TimerView.swift` の既存生成箇所は変更不要。

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/TimerNotificationIntegrationTests.swift`:

```swift
import XCTest

@testable import LeafTimer

// Issue #54: TimerViewModel と NotificationScheduler / PhaseReconciler の結線検証。
final class TimerNotificationIntegrationTests: XCTestCase {
    // swiftlint:disable:next large_tuple
    private func makeViewModel(clock: FakeClock) -> (
        vm: TimerViewModel,
        spyNotification: SpyNotificationScheduler,
        spyStats: SpySessionStatsRepository,
        spyAudio: SpyAudioManager
    ) {
        let spyNotification = SpyNotificationScheduler()
        let spyStats = SpySessionStatsRepository()
        let spyAudio = SpyAudioManager()
        let vm = TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: spyAudio,
            userDefaultWrapper: MockUserDefaultWrapper(),
            sessionStatsRepository: spyStats,
            reviewRequester: MockReviewRequester(),
            notificationScheduler: spyNotification,
            now: { clock.now() }
        )
        return (vm, spyNotification, spyStats, spyAudio)
    }

    // 開始 → 許可リクエスト 1 回 + 6 件チェーン予約
    func testStartRequestsAuthorizationAndSchedulesChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()

        XCTAssertEqual(spy.requestAuthorizationCallCount, 1)
        XCTAssertEqual(spy.scheduledChains.count, 1)
        XCTAssertEqual(spy.scheduledChains[0].count, 6)
        XCTAssertEqual(spy.scheduledChains[0][0].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            spy.scheduledChains[0][0].fireDate,
            clock.now().addingTimeInterval(TimeInterval(vm.fullTimeSecond))
        )
    }

    // 停止 → cancelAll
    func testStopCancelsChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        vm.onPressedTimerButton()

        XCTAssertEqual(spy.cancelAllCallCount, 1)
    }

    // 跨ぎゼロの foreground 復帰 → 統計は増えない (冪等)
    func testForegroundWithoutCrossingDoesNotRecordSession() {
        let clock = FakeClock()
        let (vm, _, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        clock.advance(by: 60)
        vm.handleWillEnterForeground()

        XCTAssertEqual(spyStats.recordSessionCallCount, 0)
        XCTAssertEqual(vm.currentTimeSecond, vm.fullTimeSecond - 60)
    }

    // work 終了を跨いで復帰 → break へ進み、work 1 回分の統計を記録し、チェーン再予約
    func testForegroundAfterWorkEndAdvancesToBreakAndRecords() {
        let clock = FakeClock()
        let (vm, spy, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        clock.advance(by: TimeInterval(vm.fullTimeSecond + 10))
        vm.handleWillEnterForeground()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spyStats.recordSessionCallCount, 1)
        XCTAssertEqual(vm.currentTimeSecond, vm.fullBreakTimeSecond - 10)
        XCTAssertEqual(spy.scheduledChains.count, 2)
    }

    // 複数往復を跨いで復帰 → work 2 回分の統計
    func testForegroundAfterMultipleCyclesRecordsEachWork() {
        let clock = FakeClock()
        let (vm, _, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        let crossed = vm.fullTimeSecond + vm.fullBreakTimeSecond + vm.fullTimeSecond + 30
        clock.advance(by: TimeInterval(crossed))
        vm.handleWillEnterForeground()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spyStats.recordSessionCallCount, 2)
    }

    // 停止中の foreground 復帰は no-op
    func testForegroundWhileStoppedIsNoOp() {
        let clock = FakeClock()
        let (vm, spy, spyStats, _) = makeViewModel(clock: clock)

        clock.advance(by: 3600)
        vm.handleWillEnterForeground()

        XCTAssertEqual(spyStats.recordSessionCallCount, 0)
        XCTAssertTrue(spy.scheduledChains.isEmpty)
    }

    // フォアグラウンド稼働中の自然なフェーズ切替 (updateTime が 0 到達) でも再予約
    func testNaturalPhaseSwitchReschedulesChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        vm.currentTimeSecond = 0
        vm.updateTime()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spy.scheduledChains.count, 2)
    }
}
```

注意: `SpySessionStatsRepository` に `recordSessionCallCount` が無い場合は
`private(set) var recordSessionCallCount = 0` を追加し `recordSession` 内で increment する
(既存 spec が壊れないよう追加のみ、既存プロパティは変更しない)。

- [ ] **Step 2: target 登録して RED を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
  ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/TimerNotificationIntegrationTests.swift LeafTimerTests LeafTimerTests && \
  make unit-tests
```
Expected: `extra argument 'notificationScheduler' in call` などのビルドエラー (= RED)。timeout 600000。

- [ ] **Step 3: TimerViewModel を実装**

`app/LeafTimer/ViewModel/TimerViewModel.swift` の変更点:

(1) DI プロパティ追加 (`var reviewRequester: ReviewRequesting` の直後):

```swift
    var notificationScheduler: NotificationScheduler
```

(2) init のシグネチャに追加 (`reviewRequester:` の後、`now:` の前) + 本文で代入:

```swift
        notificationScheduler: NotificationScheduler = DefaultNotificationScheduler(),
```

```swift
        self.notificationScheduler = notificationScheduler
```

(3) init 本文の末尾に foreground observer を追加:

```swift
        // Issue #54: suspend 中に跨いだフェーズを復帰時にリコンサイルする
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
```

(4) `onPressedTimerButton` の開始側 (`timerManager.start(target: self)` の直後) に追加:

```swift
            notificationScheduler.requestAuthorizationIfNeeded()
            rescheduleNotifications()
```

停止側 (`timerManager.stop()` の直後) に追加:

```swift
            notificationScheduler.cancelAll()
```

(5) `updateTime` の `reset()` 呼び出し直後 (return の前) に追加:

```swift
            rescheduleNotifications()
```

(6) 新規メソッドを `switchBreakState` の後に追加:

```swift
    // Issue #54: 現在の endDate / フェーズから先 3 往復分の通知チェーンを予約し直す
    private func rescheduleNotifications() {
        guard executeState, let endDate else { return }
        let entries = NotificationChainBuilder.build(
            endDate: endDate,
            breakState: breakState,
            workDuration: fullTimeSecond,
            breakDuration: fullBreakTimeSecond
        )
        notificationScheduler.scheduleChain(entries: entries)
    }

    @objc private func willEnterForeground() {
        handleWillEnterForeground()
    }

    // Issue #54: suspend 中に跨いだフェーズを壁時計から一括反映する。
    // audio 生存でバックグラウンド稼働し続けた場合は updateTime が進行済みのため
    // 跨ぎゼロ (no-op) になり二重カウントしない。
    func handleWillEnterForeground() {
        guard executeState, let endDate else { return }

        let result = PhaseReconciler.reconcile(
            endDate: endDate,
            breakState: breakState,
            workDuration: fullTimeSecond,
            breakDuration: fullBreakTimeSecond,
            now: now()
        )

        let crossed = result.completedWorkCount > 0 || result.breakState != breakState
        guard crossed else {
            currentTimeSecond = result.remainingSeconds
            return
        }

        for _ in 0..<result.completedWorkCount {
            countWork()
        }

        breakState = result.breakState
        currentTimeSecond = result.remainingSeconds
        self.endDate = result.newEndDate

        // suspend 中に audio は止まっているので新フェーズに合わせて張り直す
        if breakState {
            audioManager.stop()
        } else {
            audioManager.start()
        }

        rescheduleNotifications()
    }
```

(7) `SpySessionStatsRepository` に `recordSessionCallCount` が無ければ追加 (Step 1 の注意参照)。

- [ ] **Step 4: GREEN 確認 (全テスト)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests
```
Expected: `** TEST SUCCEEDED **`。既存の TimerCoreLogicSpec / ReviewIntegrationSpec が引き続き green であること (init に default 引数を足しただけなので既存呼び出しは影響なし)。timeout 600000。

- [ ] **Step 5: lint + sort + commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make lint && make sort && make precheck && \
  git add LeafTimer/ViewModel/TimerViewModel.swift \
          LeafTimerTests/TimerNotificationIntegrationTests.swift \
          LeafTimerTests/SpySessionStatsRepository.swift \
          LeafTimer.xcodeproj/project.pbxproj && \
  git commit -m "feat: #54 タイマー開始で通知チェーン予約、復帰時に壁時計リコンサイル"
```

---

### Task 4: 検証 + PR 作成

**Files:**
- なし (検証のみ。必要に応じて fix commit)

**Interfaces:**
- Consumes: Task 1〜3 の全成果物
- Produces: PR

- [ ] **Step 1: フルチェック**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests
```
Expected: `** TEST SUCCEEDED **` + precheck / localization-check / dynamic-type-check / lint 全て green。timeout 600000。

- [ ] **Step 2: Simulator 実地確認 (通知が実際に届くか)**

1. ビルド・install・起動 (CLAUDE.md ルール 30 の `-showBuildSettings` で .app パス取得、ルール 32 の onboarding/ATT 突破手順に従う)。
2. 起動後、タイマー開始をタップできないため、検証は「作業 5 分設定 + アプリを background に回す」で行う: 開始操作は tap 不可のため、`-InitialScreen` フックでは開始できない点に注意。**tap 不要の代替**: 通知予約の観測は `xcrun simctl spawn <UDID> notifyutil` では見えないため、開始操作だけはユーザーに 1 tap 依頼するか、`xcrun simctl launch` 後に AppleScript で Simulator ウィンドウを click する (`osascript -e 'tell application "System Events" to click at {x, y}'`)。ここは実装 session の判断で最も安い手段を選ぶ。
3. 開始後 `xcrun simctl launch <UDID> com.apple.Preferences` などで LeafTimer を background に回し、フェーズ境界時刻を過ぎたら screenshot で通知バナー/通知センターを確認。
4. 復帰後にフェーズ・残り時間・今日のカウントが壁時計基準で進んでいることを screenshot で確認。
5. 確認できたスクショは SendUserFile でユーザーに渡す (PR にはユーザーがブラウザで添付、ルール 25)。

- [ ] **Step 3: push + PR**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && \
  gh pr list --state all --head feature/54-background-timer-notifications && \
  git push -u origin feature/54-background-timer-notifications
```

既存 PR が無いことを確認してから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create \
  --title "feat: #54 バックグラウンド自動進行 + フェーズ終了のローカル通知" \
  --body "$(cat <<'EOF'
## 概要
Issue #54 対応。サウンドなし設定で suspend されてもポモドーロが壁時計基準で自動進行し、作業終了・休憩終了がローカル通知で届くようにした。

## 方式 (spec: docs/superpowers/specs/2026-08-24-background-timer-notifications-design.md)
- タイマー開始時に先 3 往復分 (6 件) のフェーズ境界通知を UNUserNotificationCenter に予約、停止時に全キャンセル
- willEnterForeground で PhaseReconciler (純粋ロジック) が跨いだフェーズ数を壁時計から計算し、状態・ポモドーロ統計を更新
- audio 生存でバックグラウンド稼働し続けた場合は跨ぎゼロで no-op (二重カウントなし)
- 通知許可は初回タイマー開始時にリクエスト。拒否されてもタイマーは動作

## テスト
- PhaseReconciler: 跨ぎゼロ / 1 跨ぎ / 複数往復 / 境界一致 / break 起点 / 異常系
- NotificationChainBuilder: 交互チェーン構築
- TimerViewModel 統合: 予約・キャンセル・リコンサイル・再予約 (Spy 検証)

Closes #54

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01P532T8LiixbcGXFU9xo2f3
EOF
)"
```

- [ ] **Step 4: CI 確認**

`gh pr checks <PR>` の URL 末尾から run ID を取り、**フォアグラウンドの `gh run watch <run-id> --interval 30`** で待つ (ルール 23)。green 後、merge はユーザー確認を経て `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで行う (ルール 24)。
