# タイマー壁時計補正 (Issue #56) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** タイマーの残り時間を「Timer 発火回数のカウント」から「終了予定時刻 (endDate) − 現在時刻」の壁時計基準再計算に変更し、発火抜け (着信 / run loop ブロック / フォアグラウンド復帰) でも表示残り時間が実時間からズレないようにする。

**Architecture:** `TimerViewModel` に clock 注入 (`now: () -> Date`) と `endDate: Date?` を追加。開始・再開・リセット・phase 切替時に `endDate = now() + currentTimeSecond` を張り直し、毎 tick の `updateTime()` は `remaining = endDate − now()` を丸めて表示する。`DefaultTimerManager` (1秒 Timer) は無変更 — tick はあくまで「再計算のトリガー」になる。

**Tech Stack:** Swift / SwiftUI, Quick + Nimble (既存 `TimerCoreLogicSpec` を拡張), xcodebuild via `make`

## Global Constraints

- default branch は `master` (`main` ではない)。作業ブランチ: `feature/56-wall-clock-timer`
- **新規 Swift ファイルは作らない** (pbxproj target attach / make sort の手間を回避)。FakeClock もテストも既存 `TimerCoreLogicSpec.swift` 内に追加する
- テスト実行は `cd app && make unit-tests` (内側ループ)、最終ゲートは `cd app && make tests`。**Bash timeout は 600000 (10分) を明示**
- shell は zsh。テスト成否は exit code ではなく出力マーカー (`** TEST SUCCEEDED **` / `** TEST FAILED **`) で判定するか、`set -o pipefail` を前置する
- 既存テスト `updateTime() は currentTimeSecond を 1 減らす` (endDate 未設定で直接呼ぶ) は green を維持すること — endDate が nil の時は従来どおり 1 減算にフォールバックする
- commit メッセージは `feat(timer): #56 ...` 形式、末尾に Co-Authored-By / Claude-Session トレーラーを付ける

---

### Task 1: clock 注入と壁時計基準の updateTime

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift`
- Test: `app/LeafTimerTests/TimerCoreLogicSpec.swift`

**Interfaces:**
- Produces: `TimerViewModel.init(..., now: @escaping () -> Date = { Date() })` — 既存呼び出し元 (AppDelegate / Preview / 既存テスト) はデフォルト引数で無変更のまま通る
- Produces: `private var endDate: Date?` — 開始 (`onPressedTimerButton` の start 分岐) で `now() + currentTimeSecond` を設定、pause 分岐で `nil` クリア
- Produces: `updateTime()` — `endDate` 非 nil なら `max(0, Int(endDate.timeIntervalSince(now()).rounded()))` を `currentTimeSecond` に代入。nil なら従来の 1 減算

- [ ] **Step 1: FakeClock と失敗するテストを書く**

`app/LeafTimerTests/TimerCoreLogicSpec.swift` の `import` 群の直後 (class 宣言の前) に FakeClock を追加:

```swift
// Issue #56: 壁時計補正テスト用の可変クロック。
// テストから now() を注入し、advance() で実時間経過をシミュレートする。
final class FakeClock {
    private(set) var current: Date

    init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        current = start
    }

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}
```

`describe("Timer Core Logic")` 内 (既存の `context("Memory management")` の後) に新しい context を追加:

```swift
            // MARK: - Wall-clock correction (Issue #56)

            context("Wall-clock correction") {
                // clock 注入付きの VM を作る。既存 makeViewModel() は
                // tuple 形状を変えたくないので別 helper にする。
                func makeClockedViewModel(clock: FakeClock) -> TimerViewModel {
                    TimerViewModel(
                        timerManager: SpyTimerManager(),
                        audioManager: SpyAudioManager(),
                        userDefaultWrapper: MockUserDefaultWrapper(),
                        sessionStatsRepository: SpySessionStatsRepository(),
                        reviewRequester: MockReviewRequester(),
                        now: clock.now
                    )
                }

                it("通常の 1 秒 tick では 1 ずつ減る") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start: endDate = now + 300

                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 299

                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 298
                }

                it("tick 抜けで実時間が 5 秒進んでいたら 5 秒分補正される") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton()

                    // 5 秒経過したのに tick は 1 回しか来なかった (発火抜け)
                    clock.advance(by: 5)
                    vm.updateTime()

                    expect(vm.currentTimeSecond) == 295
                }

                it("残り時間を超えて経過したら 0 にクランプされ、次の tick で phase が切り替わる") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = false
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton()

                    // 残り 300 秒を大幅に超えて 400 秒経過 (長時間ブロック)
                    clock.advance(by: 400)
                    vm.updateTime()

                    // まず 0 にクランプ (この tick では phase は切り替わらない)
                    expect(vm.currentTimeSecond) == 0
                    expect(vm.breakState) == false

                    // 次の tick で従来どおり完了処理が走る
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.breakState) == true
                    expect(vm.currentTimeSecond) == 60
                }
            }
```

- [ ] **Step 2: テストが RED (コンパイルエラー) になることを確認**

Run (timeout 600000):
```bash
cd app && make unit-tests 2>&1 | tail -40
```
Expected: `now:` という init 引数が存在しないため **ビルド失敗** (`extra argument 'now' in call` 等)。これが RED に相当。

- [ ] **Step 3: TimerViewModel に clock 注入と endDate を実装**

`app/LeafTimer/ViewModel/TimerViewModel.swift` を変更。

(a) プロパティ追加 — `private var isFirstOpen = true` の直後:

```swift
    // Issue #56: 壁時計基準の残り時間補正。
    // tick 発火回数に頼らず、終了予定時刻との差分で残り時間を再計算する。
    private let now: () -> Date
    private var endDate: Date?
```

(b) init のシグネチャに clock を追加し、本体で保持 (既存呼び出し元はデフォルト引数で無変更):

```swift
    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper,
        sessionStatsRepository: SessionStatsRepository,
        reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),
        reviewRequester: ReviewRequesting = StoreKitReviewRequester(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper
        self.sessionStatsRepository = sessionStatsRepository
        self.reviewPolicy = reviewPolicy
        self.reviewRequester = reviewRequester
        self.now = now
```

(init 本体の残り — `fullTimeSecond = 25 * 60` 以降 — は無変更)

(c) `onPressedTimerButton()` の start 分岐で endDate を張り、pause 分岐でクリア:

```swift
    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            endDate = now().addingTimeInterval(TimeInterval(currentTimeSecond))
            timerManager.start(target: self)
            UIApplication.shared.isIdleTimerDisabled = true

            if !breakState {
                audioManager.start()
            }

        case true:
            executeState = false
            endDate = nil
            timerManager.stop()
            audioManager.stop()

            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
```

(d) `updateTime()` を壁時計基準に変更:

```swift
    @objc func updateTime() {
        if currentTimeSecond == 0 {
            if vibration {
                audioManager.vibration()
            }

            switchBreakState()
            reset()

            return
        }

        if let endDate {
            // 発火抜けがあっても endDate との差分で自己補正する (Issue #56)
            currentTimeSecond = max(0, Int(endDate.timeIntervalSince(now()).rounded()))
        } else {
            // endDate 未設定 (タイマー非稼働で直接呼ばれた場合) は従来挙動
            currentTimeSecond -= 1
        }
    }
```

- [ ] **Step 4: テストが GREEN になることを確認**

Run (timeout 600000):
```bash
cd app && make unit-tests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`、新規 3 テストを含め failures 0。
注意: この時点で Task 2 の phase 切替テストはまだ書いていないので全 green のはず。既存テスト `updateTime() は currentTimeSecond を 1 減らす` が endDate nil フォールバックで green を維持していることを確認。

- [ ] **Step 5: Commit**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimerTests/TimerCoreLogicSpec.swift
git commit -m "feat(timer): #56 clock 注入と endDate 基準の残り時間再計算を導入

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013DY63ftra9pSTqtQxALMBM"
```

---

### Task 2: pause/resume と phase 切替・手動リセットの endDate 再計算

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift` (reset() のみ)
- Test: `app/LeafTimerTests/TimerCoreLogicSpec.swift`

**Interfaces:**
- Consumes: Task 1 の `endDate` / `now` / `makeClockedViewModel(clock:)` / `FakeClock`
- Produces: `reset()` — `currentTimeSecond` を phase の full 値に戻した後、**稼働中 (`executeState == true`) なら `endDate = now() + currentTimeSecond` を再計算**する。これにより (i) tick 完了からの phase 切替 (`updateTime` → `switchBreakState` → `reset`) と (ii) 稼働中の手動リセットボタン (`TimerView.didTapResetButton`) の両方で endDate が張り直される

- [ ] **Step 1: 失敗するテストを書く**

`context("Wall-clock correction")` 内の末尾に追加:

```swift
                it("pause 中は時間が経過しても減らず、resume 後は残りから再開する") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start

                    clock.advance(by: 2)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 298

                    vm.onPressedTimerButton() // pause
                    clock.advance(by: 60)     // pause 中に 60 秒経過

                    vm.onPressedTimerButton() // resume: endDate = now + 298
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 297
                }

                it("phase 切替後は新しい endDate 基準でカウントダウンする") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = false
                    vm.currentTimeSecond = 2
                    vm.onPressedTimerButton() // start: endDate = now + 2 (これが stale になる)

                    clock.advance(by: 1)
                    vm.updateTime() // → 1
                    clock.advance(by: 1)
                    vm.updateTime() // → 0 (クランプ)
                    clock.advance(by: 1)
                    vm.updateTime() // 完了処理: switchBreakState + reset

                    expect(vm.breakState) == true
                    expect(vm.currentTimeSecond) == 60

                    // reset() が endDate を張り直していなければ、次の tick は
                    // 開始時の古い endDate (now + 2) との差分で 0 に潰れる
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 59
                }

                it("稼働中の手動リセットは full 値に戻して endDate を張り直す") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullTimeSecond = 300
                    vm.breakState = false
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start

                    clock.advance(by: 10)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 290

                    vm.reset() // TimerView の reset ボタン相当

                    expect(vm.currentTimeSecond) == 300
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 299
                }
```

- [ ] **Step 2: テストが RED になることを確認**

Run (timeout 600000):
```bash
cd app && make unit-tests 2>&1 | tail -40
```
Expected: **TEST FAILED**。
- 「phase 切替後」: `reset()` が endDate を張り直さないため、最後の expect (59) が開始時の古い endDate 基準でクランプされた 0 になり失敗
- 「手動リセット」: 最後の expect (299) が古い endDate 基準の値 (289) になり失敗
- 「pause/resume」: resume の start 分岐は Task 1 で endDate を張り直すので、これは green の可能性が高い (green でも問題ない — 回帰ガードとして残す)

- [ ] **Step 3: reset() を実装**

```swift
    func reset() {
        if breakState {
            currentTimeSecond = fullBreakTimeSecond
        } else {
            currentTimeSecond = fullTimeSecond
        }

        // 稼働中のリセット (phase 切替 / 手動リセット) では
        // 新しい残り時間で endDate を張り直す (Issue #56)
        if executeState {
            endDate = now().addingTimeInterval(TimeInterval(currentTimeSecond))
        }
    }
```

- [ ] **Step 4: テストが GREEN になることを確認**

Run (timeout 600000):
```bash
cd app && make unit-tests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`、failures 0。

- [ ] **Step 5: Commit**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimerTests/TimerCoreLogicSpec.swift
git commit -m "feat(timer): #56 phase 切替・手動リセット時に endDate を再計算

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013DY63ftra9pSTqtQxALMBM"
```

---

### Task 3: 最終検証と PR 作成

**Files:**
- なし (検証のみ)

**Interfaces:**
- Consumes: Task 1-2 の全変更

- [ ] **Step 1: フルテストゲートを通す**

Run (timeout 600000):
```bash
cd app && set -o pipefail && make tests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **` (precheck / sort / lint も同時に通る。新規ファイルなしなので orphan / sort 差分は出ないはず)。`git status` で意図しない差分が無いことも確認。

- [ ] **Step 2: 既存 PR の確認と push**

```bash
git fetch && gh pr list --state all --head feature/56-wall-clock-timer
git push -u origin feature/56-wall-clock-timer
```
Expected: 既存 PR なし → push 成功。

- [ ] **Step 3: PR 作成**

```bash
gh pr create --title "feat(timer): #56 タイマー残り時間を壁時計基準で補正" --body "(概要 / 根本原因 / 変更内容 / 検証結果を記載。Closes #56。#54 バックグラウンド継続は別スコープである旨を明記)"
```

- [ ] **Step 4: Issue #56 と #54 の関連コメント**

`#54 (バックグラウンド継続) は本 PR のスコープ外だが、壁時計補正によりフォアグラウンド復帰後 1 tick (約1秒) 以内に表示が自己補正されるようになった` 旨を PR 本文に含める (別コメント不要)。

---

## スコープ外 (明示)

- **#54 バックグラウンド継続 + プッシュ通知**: 本 plan はフォアグラウンド中の発火抜け補正のみ。バックグラウンドで phase 完了を通知する機能は #54 で別途設計する
- バックグラウンドで複数 phase をまたぐ長時間経過 (例: 40 分放置で work + break 両方完了) の多段切替: 今回は「0 クランプ → 次 tick で 1 回だけ phase 切替」の単段挙動とする (実運用ではフォアグラウンド復帰後の話であり、#54 と合わせて設計するのが妥当)
- `DefaultTimerManager` の Timer 精度改善 (tolerance 調整等): 壁時計補正により tick 精度への依存自体が下がるため不要
