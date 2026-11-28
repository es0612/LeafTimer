# #223 新規インストールの初期値と停止中タイマーへの設定の反映 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新しく入れた人は 25 分・5 分・バイブ ON で始まり、止まっていて未開始のタイマーには設定の変更がすぐ効くようにする。

**Architecture:** `UserDefaultsWrapper` に `hasValue(key:)` を足す。`TimerViewModel.init` の初回起動の処理では、未保存のキーにだけ既定値を書く。`readData()` は、止まっていて残り時間が変更前の長さと同じときに、残り時間を新しい長さへ置き直す。

**Tech Stack:** Swift / SwiftUI / XCTest（新規テストは XCTest、ルール 43）

**Spec:** `docs/superpowers/specs/2026-11-28-issue-223-default-timer.md`（Task 4 で `docs/superpowers/specs/archive/` に移る）

## Global Constraints

- 既定値: 作業 = `ItemValue.workingTimeList` の添字 4（25 分）、休憩 = `ItemValue.breakTimeList` の添字 4（5 分）、バイブ = `true`、音 = 0（無音）。「設定を初期値に戻す」（`ResetSettingsSection.swift:80-84`）と同じ値にする。
- 既存ユーザー（`hasLaunchedBefore == 1`）の値は変えない。保存済みのキーは、初回起動の処理でも上書きしない。
- 稼働中（`executeState == true`）の `readData()` の動きは変えない。
- ビルド・テストは `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する。成否は `** TEST SUCCEEDED **` の存在と `** TEST FAILED **` の不在で判定する（ルール 1）。Bash timeout は 600000。
- 新規 Swift ファイルは `make add-file FILE=… TARGET=test` で配線し、同じ commit に含める（ルール 28）。
- 新規コードは `.isEmpty` を使う（ルール 35）。Edit の後、commit 前に `git diff | cat -e` で、触っていない空行のインデントが消えていないか確かめる。
- テストの件数・失敗の数はコードを読んで予測した値。違ったら止めて報告する。

## Review Focus

- v1.3 以前から直接上げた人（`hasLaunchedBefore` 未保存、時間・音・バイブは保存済み）→ 選んだ値がそのまま残る。Task 2 の `testFirstLaunchKeepsValuesSavedByOldVersion`。
- 設定を一度も触っていない既存ユーザー（`hasLaunchedBefore == 1`、ほかは未保存）→ 5 分・1 分・OFF のまま。Task 2 の `testExistingUserWithoutSavedSettingsKeepsOldDefaults`。
- 途中で一時停止した状態で設定を変える → 残り時間を保つ。Task 3 の `testPausedTimerKeepsRemainingTime`。
- 稼働中に設定を変える → 残り時間はそのまま（次のフェーズから新しい長さ）。Task 3 の `testRunningTimerKeepsRemainingTime`。
- 休憩フェーズで止まっていて未開始のときに休憩時間を変える → 新しい休憩時間になる。Task 3 の `testStoppedUnstartedBreakTakesNewBreakTime`。

---

### Task 1: `UserDefaultsWrapper.hasValue(key:)`

**Files:**
- Modify: `app/LeafTimer/Components/LocalUserDefaultWrapper.swift`（protocol と `LocalUserDefaultsWrapper`）
- Modify: `app/LeafTimerTests/MockUserDefaultWrapper.swift`
- Modify: `app/LeafTimerTests/ModernSettingViewSpec.swift:131-`（`MockUserDefaultsWrapper`）
- Test: `app/LeafTimerTests/LocalUserDefaultsWrapperTests.swift`

**Interfaces:**
- Produces: `protocol UserDefaultsWrapper` に `func hasValue(key: String) -> Bool`。実体は `userDefaults.object(forKey: key) != nil`。`MockUserDefaultWrapper` は `intStorage[key] != nil || boolStorage[key] != nil`（`mockIntValue` / `mockBoolValue` は「保存済み」に数えない）。`MockUserDefaultsWrapper` は `savedData[key] != nil`。

- [ ] **Step 1: 失敗するテストを書く** — `LocalUserDefaultsWrapperTests` に追加:

```swift
func testHasValueIsTrueOnlyAfterSave() {
    let key = "LocalUserDefaultsWrapperTests.hasValue"
    XCTAssertFalse(wrapper.hasValue(key: key))
    // 0 を保存しても「保存済み」と判定する (integer(forKey:) != 0 で代用していないことの確認)
    wrapper.saveData(key: key, value: 0)
    XCTAssertTrue(wrapper.hasValue(key: key))
}
```

- [ ] **Step 2: 失敗を確かめる** — `cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -only-testing:LeafTimerTests/LocalUserDefaultsWrapperTests test 2>&1 | /usr/bin/grep -E "error:|Test Case .*(passed|failed)|\*\* TEST"`。Expected: コンパイルエラー `value of type 'LocalUserDefaultsWrapper' has no member 'hasValue'`。
- [ ] **Step 3: 実装する** — 上の Interfaces どおり、protocol・`LocalUserDefaultsWrapper`・2 つの Mock に `hasValue(key:)` を足す。
- [ ] **Step 4: 通ることを確かめる** — Step 2 と同じコマンド。Expected: `testHasValueIsTrueOnlyAfterSave` が passed、`** TEST SUCCEEDED **`。
- [ ] **Step 5: mutation** — 実体を `userDefaults.integer(forKey: key) != 0` に変えて Step 2 のコマンドを流し、`testHasValueIsTrueOnlyAfterSave` が failed になることを見てから元に戻す。
- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/Components/LocalUserDefaultWrapper.swift app/LeafTimerTests/MockUserDefaultWrapper.swift app/LeafTimerTests/ModernSettingViewSpec.swift app/LeafTimerTests/LocalUserDefaultsWrapperTests.swift
git commit -m "feat: UserDefaultsWrapper にキーが保存済みかを返す hasValue を足す (#223)"
```

### Task 2: 初回起動の既定値を、未保存のキーだけ書く

**Files:**
- Modify: `app/LeafTimer/Components/UserDefaultItem.swift`（`ItemValue` に既定の添字）
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift:81-86`
- Modify: `app/LeafTimer/View/Settings/ResetSettingsSection.swift:80-81`（添字 4 を定数に置き換える）
- Modify: `app/LeafTimer/Components/DebugStoreScreenshot.swift:48`（コメント「アプリの初期値は 5 分」を「アプリの初期値と同じ 25 分。既存ユーザーの 5 分を上書きして撮る」に直す）
- Create: `app/LeafTimerTests/TimerDefaultSettingsTests.swift`

**Interfaces:**
- Consumes: Task 1 の `hasValue(key:)`
- Produces: `ItemValue.defaultWorkingTimeIndex = 4`、`ItemValue.defaultBreakTimeIndex = 4`（`static let`）。`TimerDefaultSettingsTests` に `makeViewModel(wrapper: MockUserDefaultWrapper) -> TimerViewModel`（`SpyTimerManager` / `SpyAudioManager` / `SpySessionStatsRepository` / `MockReviewRequester` / `SpyNotificationScheduler` を渡す。`OnboardingGateTests.swift:51-57` と同じ組み方）と、画面を開いたときと同じ `vm.readData(); vm.openScreen()` を呼ぶ `open(_ vm:)`。Task 3 も使う。

- [ ] **Step 1: 失敗するテストを書く** — `TimerDefaultSettingsTests.swift` を作り `make add-file FILE=LeafTimerTests/TimerDefaultSettingsTests.swift TARGET=test` で配線する。テスト 3 件:

```swift
// 新規インストール: 何も保存されていない
func testFirstLaunchStartsWithPomodoroDefaults() {
    let wrapper = MockUserDefaultWrapper()
    let vm = makeViewModel(wrapper: wrapper)
    open(vm)
    XCTAssertEqual(vm.fullTimeSecond, 25 * 60)
    XCTAssertEqual(vm.fullBreakTimeSecond, 5 * 60)
    XCTAssertEqual(vm.currentTimeSecond, 25 * 60)
    XCTAssertTrue(vm.vibration)
    // 設定画面も同じ値を出す
    let setting = SettingViewModel(userDefaultWrapper: wrapper, reviewRequester: MockReviewRequester())
    setting.readData()
    XCTAssertEqual(setting.workingTime, ItemValue.defaultWorkingTimeIndex)
    XCTAssertEqual(setting.breakTime, ItemValue.defaultBreakTimeIndex)
    XCTAssertTrue(setting.vibrationIsOn)
}

// v1.3 以前から直接上げた人: hasLaunchedBefore は未保存だが、選んだ値は保存済み
func testFirstLaunchKeepsValuesSavedByOldVersion() {
    let wrapper = MockUserDefaultWrapper()
    wrapper.setValue(for: UserDefaultItem.workingTime.rawValue, value: 9)
    wrapper.setValue(for: UserDefaultItem.breakTime.rawValue, value: 0)
    wrapper.setValue(for: UserDefaultItem.vibration.rawValue, value: false)
    wrapper.setValue(for: UserDefaultItem.workingSound.rawValue, value: 2)
    let vm = makeViewModel(wrapper: wrapper)
    open(vm)
    XCTAssertEqual(vm.fullTimeSecond, 50 * 60)
    XCTAssertEqual(vm.fullBreakTimeSecond, 1 * 60)
    XCTAssertFalse(vm.vibration)
    XCTAssertEqual(wrapper.loadData(key: UserDefaultItem.workingSound.rawValue) as Int, 2)
}

// 設定を一度も触っていない既存ユーザー: 5 分・1 分・OFF のまま
func testExistingUserWithoutSavedSettingsKeepsOldDefaults() {
    let wrapper = MockUserDefaultWrapper()
    wrapper.setValue(for: UserDefaultItem.hasLaunchedBefore.rawValue, value: 1)
    let vm = makeViewModel(wrapper: wrapper)
    open(vm)
    XCTAssertEqual(vm.fullTimeSecond, 5 * 60)
    XCTAssertEqual(vm.fullBreakTimeSecond, 1 * 60)
    XCTAssertFalse(vm.vibration)
}
```

- [ ] **Step 2: 失敗を確かめる** — `-only-testing:LeafTimerTests/TimerDefaultSettingsTests`（コマンドの形は Task 1 Step 2 と同じ）。Expected: `ItemValue.defaultWorkingTimeIndex` が無いためコンパイルエラー。先に 2 つの定数だけ足して再実行すると、`testFirstLaunchStartsWithPomodoroDefaults` が 7 件の assertion で failed（300≠1500、60≠300、300≠1500、vibration false、0≠4、0≠4、vibrationIsOn false）、`testFirstLaunchKeepsValuesSavedByOldVersion` が 1 件で failed（workingSound 0≠2）、`testExistingUserWithoutSavedSettingsKeepsOldDefaults` は passed（回帰の番人。Step 5 で mutation を見る）。
- [ ] **Step 3: 実装する** — `TimerViewModel.init` の `hasLaunchedBefore == 0` の中で、`workingSound = 0`・`breakSound = 0`・`workingTime = ItemValue.defaultWorkingTimeIndex`・`breakTime = ItemValue.defaultBreakTimeIndex`・`vibration = true` を、`hasValue(key:)` が false のキーにだけ保存する。最後に `hasLaunchedBefore = 1` を保存する（今と同じ）。`ResetSettingsSection.swift` の `4` 2 か所を同じ定数に置き換え、`DebugStoreScreenshot.swift:48` のコメントを直す。
- [ ] **Step 4: 通ることを確かめる** — Step 2 と同じコマンド。Expected: 3 件 passed。`-only-testing:LeafTimerTests/OnboardingGateTests` も流し、`testFirstLaunchWritesDefaultsUsingEnumKeys` が passed のままであること。
- [ ] **Step 5: mutation（テスト 1 件 : mutation 1 つ）** — 1 つずつ入れて Step 2 のコマンドを流し、failed を見てから元に戻す。
  - `testFirstLaunchStartsWithPomodoroDefaults` ← `workingTime` の保存行を消す
  - `testFirstLaunchKeepsValuesSavedByOldVersion` ← `hasValue` の判定を外して必ず保存する
  - `testExistingUserWithoutSavedSettingsKeepsOldDefaults` ← `hasLaunchedBefore == 0` の条件を外して毎回この処理を通す
- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/Components/UserDefaultItem.swift app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimer/View/Settings/ResetSettingsSection.swift app/LeafTimer/Components/DebugStoreScreenshot.swift app/LeafTimerTests/TimerDefaultSettingsTests.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "fix: 新規インストールを 25 分・5 分・バイブ ON で始め、保存済みの値は上書きしない (#223)"
```

### Task 3: 止まっていて未開始なら、設定の変更を残り時間に反映する

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift`（`readData()`、今の :268 付近）
- Test: `app/LeafTimerTests/TimerDefaultSettingsTests.swift`

**Interfaces:**
- Consumes: Task 2 の `makeViewModel(wrapper:)` と `open(_:)`
- Produces: `TimerDefaultSettingsTests` に `makeOpenedViewModel() -> (vm: TimerViewModel, wrapper: MockUserDefaultWrapper)`。`hasLaunchedBefore = 1`・`workingTime = 4`・`breakTime = 4` を保存した wrapper で `makeViewModel` → `open` した状態を返す。

- [ ] **Step 1: 失敗するテストを書く** — 4 件追加。どれも `let (vm, wrapper) = makeOpenedViewModel()` で始め（下のコードでは省略）、設定を書き換えて `vm.readData()` を呼ぶ（設定画面から戻ったときと同じ）。

```swift
func testStoppedUnstartedTimerTakesNewWorkingTime() {
    // open 後: currentTimeSecond == 25 * 60
    wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
    vm.readData()
    XCTAssertEqual(vm.currentTimeSecond, 5 * 60)
}

func testStoppedUnstartedBreakTakesNewBreakTime() {
    vm.breakState = true
    vm.reset() // currentTimeSecond == 5 * 60
    wrapper.saveData(key: UserDefaultItem.breakTime.rawValue, value: 9)
    vm.readData()
    XCTAssertEqual(vm.currentTimeSecond, 10 * 60)
}

func testPausedTimerKeepsRemainingTime() {
    vm.currentTimeSecond = 1000 // 途中で一時停止した状態 (executeState == false)
    wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
    vm.readData()
    XCTAssertEqual(vm.currentTimeSecond, 1000)
    XCTAssertEqual(vm.fullTimeSecond, 5 * 60)
}

func testRunningTimerKeepsRemainingTime() {
    vm.onPressedTimerButton() // 開始
    wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
    vm.readData()
    XCTAssertEqual(vm.currentTimeSecond, 25 * 60)
}
```

- [ ] **Step 2: 失敗を確かめる** — `-only-testing:LeafTimerTests/TimerDefaultSettingsTests`。Expected: `testStoppedUnstartedTimerTakesNewWorkingTime`（1500≠300）と `testStoppedUnstartedBreakTakesNewBreakTime`（300≠600）が failed、`testPausedTimerKeepsRemainingTime` と `testRunningTimerKeepsRemainingTime` は passed（回帰の番人）。Task 2 の 3 件は passed のまま。
- [ ] **Step 3: 実装する** — `readData()` の冒頭で、変更前の長さ（`breakState` なら `fullBreakTimeSecond`、それ以外は `fullTimeSecond`）を覚えておく。新しい長さを読み込んだ後、`!executeState && currentTimeSecond == 変更前の長さ` のときだけ、`currentTimeSecond` を今のフェーズの新しい長さにする。`openScreen()` の `isFirstOpen` 分岐は残す。
- [ ] **Step 4: 通ることを確かめる** — Step 2 と同じコマンド。Expected: 7 件 passed。`-only-testing:LeafTimerTests/TimerNotificationIntegrationTests` も流し、`testReadDataWhileRunningReschedulesChainWithNewDuration` が passed のままであること。
- [ ] **Step 5: mutation（テスト 1 件 : mutation 1 つ）** — 1 つずつ入れて failed を見てから元に戻す。
  - `testStoppedUnstartedTimerTakesNewWorkingTime` ← 置き直しの処理を丸ごと消す
  - `testStoppedUnstartedBreakTakesNewBreakTime` ← 変更前の長さを常に `fullTimeSecond` にする
  - `testPausedTimerKeepsRemainingTime` ← `currentTimeSecond == 変更前の長さ` の条件を外す
  - `testRunningTimerKeepsRemainingTime` ← `!executeState` の条件を外す
- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimerTests/TimerDefaultSettingsTests.swift
git commit -m "fix: 止まっていて未開始なら、設定で変えた時間をすぐ残り時間に反映する (#223)"
```

### Task 4: 全体の確認と PR

- [ ] **Step 1:** `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests`。Expected: `Executed 257 tests`（master の 249 + 8）、failures 0、`** TEST SUCCEEDED **`。件数が違ったら止めて報告する。
- [ ] **Step 2: Simulator** — `leaftimer-simulator-verification` に従い、アプリを消して入れ直し（`simctl uninstall` → `install` → `launch`）、オンボーディングを抜けた最初の画面が `25:00` であることをスクショで確かめる。設定で作業時間を 5 分にして戻り、`05:00` になることも確かめる（tap は cliclick）。
- [ ] **Step 3: plan と spec を archive へ移して commit する**

```bash
git mv docs/superpowers/plans/2026-11-28-issue-223-default-timer.md docs/superpowers/plans/archive/
git mv docs/superpowers/specs/2026-11-28-issue-223-default-timer.md docs/superpowers/specs/archive/
git commit -m "docs: #223 の plan と spec を archive へ移す"
```

- [ ] **Step 4: PR を作る** — `git fetch && gh pr list --state all --head fix/issue-223-default-timer` で既存 PR が無いことを確かめてから push し、`gh pr create`。本文は `Refs #223`（`Closes` にしない。配信後に新規インストールで 25:00 を確かめてから手で close する）。merge はこの plan に含めない（ルール 22）。
