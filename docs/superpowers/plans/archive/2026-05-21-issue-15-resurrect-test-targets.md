# Issue #15 — LeafTimerTests pbxproj 未登録 Spec の復活 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `app/LeafTimerTests/` に物理的には存在するが Xcode test target に attach されておらず `make tests` で実行されない 4 つのテストファイルを整理し、現役のテストとして復活させる。あわせて `ModernTimerViewSpec.swift` の `xdescribe` による全 skip を可視化し、別 Issue に切り出す。

**Architecture:** XCTest 系（`DataPersistenceTests`, `AudioSystemVerificationTests`）は現コードの API と整合しているので **そのまま target 追加**。Quick/Nimble 系（`TimerCoreLogicSpec`）は古い API を参照しているため **現 API（`fullTimeSecond` / `switchBreakState` / `finishCallCount` 等）に書き直してから target 追加**。重複している `SimpleDataPersistenceTest.swift` は **削除**。pbxproj 編集は既存の `bin/add-to-target.rb`（Issue #3 で導入）で機械的に行い、replace-all による広域変更を避ける。`ModernTimerViewSpec.swift` の `xdescribe` 起因の skip は今回スコープ外、調査と Issue 化のみ実施する。

**Tech Stack:** Swift 5, XCTest, Quick/Nimble, ViewInspector, Xcodeproj (Ruby gem), CocoaPods

**Issue:** https://github.com/es0612/LeafTimer/issues/15

---

## 背景と問題の再確認

PR #14（Issue #3 App Store レビュー誘導）実装中に発覚した状況:

| ファイル | pbxproj 登録 | 現状 | 復活コスト |
|---|---|---|---|
| `TimerCoreLogicSpec.swift` | ✗ 未登録 | 古い API 参照 (`workingTime`, `switchToBreakMode`, `playBreakSoundWasCalled`) | **大** API 書き直し必要 |
| `DataPersistenceTests.swift` | ✗ 未登録 | XCTest、API は現コードと整合 | **小** target 追加のみ |
| `AudioSystemVerificationTests.swift` | ✗ 未登録 | XCTest、API は現コードと整合 | **小** target 追加のみ |
| `SimpleDataPersistenceTest.swift` | ✗ 未登録 | `DataPersistenceTests` の極小サブセット | **0** 削除 |
| `ModernTimerViewSpec.swift` | ✓ 登録済 | **`xdescribe` で全 skip**（"26 tests skipped" の正体） | 別 Issue 化 |

`make tests` の `Executed N tests, 26 tests skipped, 0 failures` 表示は見かけクリーンだが、`ModernTimerViewSpec` の `xdescribe` 起因。`TimerViewModel` のロジック spec が事実上ゼロという深刻な状態。

---

## ファイル構成

### 編集

| パス | 変更点 |
|---|---|
| `app/LeafTimerTests/TimerCoreLogicSpec.swift` | 古い API 参照を現 API に書き直す（`workingTime` → `fullTimeSecond` ほか） |
| `app/LeafTimer.xcodeproj/project.pbxproj` | `DataPersistenceTests` / `AudioSystemVerificationTests` / `TimerCoreLogicSpec` を `LeafTimerTests` target に attach。`SimpleDataPersistenceTest` の登録は無し（既に未登録）。手で書かず `bin/add-to-target.rb` を使う |

### 削除

| パス | 理由 |
|---|---|
| `app/LeafTimerTests/SimpleDataPersistenceTest.swift` | `DataPersistenceTests` の `testSaveAndLoadIntegerValues` で網羅される極小スモークテスト。残しても価値なし |

### 新規 Issue (今回スコープ外、最終タスクで作成)

| 内容 | 理由 |
|---|---|
| `ModernTimerViewSpec.xdescribe による全 skip を解消` | `xdescribe` の経緯不明 (ViewInspector の動作不安定が理由か、退避目的か)。調査と判断は別セッションで |

---

## 現 API 早見表（書き直しの根拠）

`TimerCoreLogicSpec` を書き直すときに参照する、現コードのシグネチャ。

### TimerViewModel (`app/LeafTimer/ViewModel/TimerViewModel.swift`)

```swift
class TimerViewModel: ObservableObject {
    // プロパティ
    var fullTimeSecond: Int           // 旧 workingTime に相当
    var fullBreakTimeSecond: Int      // 旧 breakTime に相当
    var currentTimeSecond: Int
    var executeState: Bool
    var breakState: Bool
    var todaysCount: Int

    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper,
        reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    )

    func onPressedTimerButton()
    func reset()                       // breakState によって currentTimeSecond を fullTimeSecond/fullBreakTimeSecond に戻す
    @objc func updateTime()            // 0 になると switchBreakState + reset
    func switchBreakState()            // 旧 switchToBreakMode に相当
}
```

### SpyAudioManager (`app/LeafTimerTests/SpyAudioManager.swift`)

```swift
class SpyAudioManager: AudioManager {
    private(set) var setUpCallCount: Int
    private(set) var startCallCount: Int
    private(set) var stopCallCount: Int
    private(set) var finishCallCount: Int        // work → break で呼ばれる (旧 playBreakSoundWasCalled に相当)
    private(set) var finishBreakCallCount: Int   // break → work で呼ばれる
    private(set) var vibrationCallCount: Int
    private(set) var lastWorkingSound: String?
    func reset()
}
```

### switchBreakState() の振る舞い (重要)

```swift
// breakState false → true: audioManager.finish() + countWork()
// breakState true → false: audioManager.finishBreak() + audioManager.start()
```

つまり「Work から Break に切り替わるとき」のサウンドは **`audioManager.finish()`** であって `playBreakSound` ではない。テストでは `spyAudioManager.finishCallCount > 0` でアサートする。

### init() の副作用 (注意点)

```swift
init(...) {
    // ...
    loadCount()                                                 // userDefaultWrapper.loadData を呼ぶ
    if userDefaultWrapper.loadData(key: "hasLaunchedBefore") == 0 {
        userDefaultWrapper.saveData(...)                        // saveData が 3 回呼ばれる
        userDefaultWrapper.saveData(...)
        userDefaultWrapper.saveData(...)
    }
}
```

`MockUserDefaultWrapper` は初期状態で全 key に対し `0` を返すので、**init 時点で必ず "hasLaunchedBefore" の分岐に入って saveData が 3 回呼ばれる**。`testDataPersistence` のように「saveData 呼び出し回数」を検査するテストでは、`mockUserDefaultWrapper.reset()` を **TimerViewModel を作った後** に呼んでから本番アクションを実行する必要がある。

### bin/add-to-target.rb の使い方

```text
Usage: ruby bin/add-to-target.rb <project_path> <file_path> <target_name> <group_path>
  project_path : LeafTimer.xcodeproj
  file_path    : LeafTimerTests/Foo.swift   (project-relative)
  target_name  : LeafTimerTests
  group_path   : LeafTimerTests             (Xcode 上のグループ)
冪等。再実行は no-op。
```

---

### Task 1: ベースライン確認

**Files:**
- 編集なし（baseline 取得のみ）

- [ ] **Step 1: 現状の test 実行結果を記録**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/leaftimer-baseline.log | tail -30
```

Expected:
- `make` の exit code が 0（`set -o pipefail` でパイプ越しでも `${PIPESTATUS[0]}` でなく `$?` で判定可能）
- ログ末尾に `Executed NN tests, with 26 tests skipped and 0 failures` のような行
- skip 数 26 と pass 数を覚えておく（後の比較用）

もし fail するなら、まず Issue #10（xcode-precheck）相当でシミュレータ destination を整え、本タスクは始めない。

- [ ] **Step 2: pbxproj 未登録ファイルを列挙**

Run:
```bash
cd app && for f in LeafTimerTests/*.swift; do
  basename=$(basename "$f")
  if grep -q "$basename in Sources" LeafTimer.xcodeproj/project.pbxproj; then
    echo "✓ $basename"
  else
    echo "✗ $basename"
  fi
done
```

Expected: `✗ AudioSystemVerificationTests.swift`, `✗ DataPersistenceTests.swift`, `✗ SimpleDataPersistenceTest.swift`, `✗ TimerCoreLogicSpec.swift` の 4 件、他は `✓`。

- [ ] **Step 3: 作業ブランチを切る**

```bash
git checkout -b feature/issue-15-resurrect-test-targets
```

コミットはしない。

---

### Task 2: SimpleDataPersistenceTest.swift を削除

**Files:**
- Delete: `app/LeafTimerTests/SimpleDataPersistenceTest.swift`

- [ ] **Step 1: 内容を最終確認（テストが他に被ってないか）**

Run:
```bash
cd app && cat LeafTimerTests/SimpleDataPersistenceTest.swift
```

Expected: 1 メソッド `testBasicUserDefaultsWrapper`、内容は `LocalUserDefaultsWrapper().saveData(key:"testKey", value:42)` → `loadData(key:"testKey") == 42` の確認のみ。これは Task 3 で復活する `DataPersistenceTests.testSaveAndLoadIntegerValues` で完全に同じことをテストしている（むしろより厳密）。

- [ ] **Step 2: ファイルを削除**

Run:
```bash
cd app && rm LeafTimerTests/SimpleDataPersistenceTest.swift
```

- [ ] **Step 3: pbxproj に登録がないことを再確認**

Run:
```bash
cd app && grep -c SimpleDataPersistenceTest LeafTimer.xcodeproj/project.pbxproj
```

Expected: `0`（一切登録されていない）。万一 `> 0` の場合は pbxproj から手動削除が必要なので止まる。

- [ ] **Step 4: ビルド・テスト確認**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tail -20
```

Expected: Task 1 と同じテスト数で PASS。削除したファイルは元々 target 外なので件数に影響なし。

- [ ] **Step 5: Commit**

```bash
cd app && git add LeafTimerTests/SimpleDataPersistenceTest.swift
git commit -m "Issue #15: 重複していた SimpleDataPersistenceTest.swift を削除

DataPersistenceTests.testSaveAndLoadIntegerValues で同等以上の検証が
ある（こちらは復活予定）。
"
```

---

### Task 3: DataPersistenceTests.swift を test target に attach

**Files:**
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (via `bin/add-to-target.rb`)

- [ ] **Step 1: 対象ファイルの中身が現コードの API と整合することを確認**

Run:
```bash
cd app && grep -nE "userDefaultsWrapper\.(saveData|loadData)" LeafTimerTests/DataPersistenceTests.swift | head -5
```

Expected: `userDefaultsWrapper.saveData(key:, value:)` / `userDefaultsWrapper.loadData(key:)` の呼び出し。`LocalUserDefaultsWrapper` の現プロトコル (`UserDefaultsWrapper`) と一致しているはず。

- [ ] **Step 2: target attach（add-to-target.rb 実行）**

Run:
```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/DataPersistenceTests.swift LeafTimerTests LeafTimerTests
```

Expected: `added: LeafTimerTests/DataPersistenceTests.swift -> LeafTimerTests`

- [ ] **Step 3: pbxproj に正しく登録されたか確認**

Run:
```bash
cd app && grep -c "DataPersistenceTests.swift" LeafTimer.xcodeproj/project.pbxproj
```

Expected: `3` 以上（`PBXBuildFile` + `PBXFileReference` + Sources phase の 3 行が最低）。

- [ ] **Step 4: テスト実行**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/leaftimer-after-task3.log | tail -10
```

Expected:
- exit code 0
- pass 数が baseline より **20 件以上**増えている（`DataPersistenceTests` は 23 メソッド）
- `Executed NN tests, with M failures` の `M` が 0

もし fail があれば fail メッセージを読んで原因特定する（API mismatch なら本タスクの想定外）。

- [ ] **Step 5: Commit**

```bash
cd app && git add LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #15: DataPersistenceTests.swift を test target に attach

物理ファイルは存在していたが pbxproj 未登録のため make tests で
実行されていなかった。LocalUserDefaultsWrapper の現 API と整合している
ため target 追加のみで復活。
"
```

---

### Task 4: AudioSystemVerificationTests.swift を test target に attach

**Files:**
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (via `bin/add-to-target.rb`)

- [ ] **Step 1: 対象ファイルの中身が現コードの API と整合することを確認**

Run:
```bash
cd app && grep -nE "audioManager\.(setUp|start|stop|finish|finishBreak|vibration)" LeafTimerTests/AudioSystemVerificationTests.swift | head -5
```

Expected: 全て `DefaultAudioManager` の現メソッドシグネチャと一致。

- [ ] **Step 2: target attach**

Run:
```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/AudioSystemVerificationTests.swift LeafTimerTests LeafTimerTests
```

Expected: `added: LeafTimerTests/AudioSystemVerificationTests.swift -> LeafTimerTests`

- [ ] **Step 3: pbxproj 確認**

Run:
```bash
cd app && grep -c "AudioSystemVerificationTests.swift" LeafTimer.xcodeproj/project.pbxproj
```

Expected: `3` 以上。

- [ ] **Step 4: テスト実行**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/leaftimer-after-task4.log | tail -10
```

Expected:
- exit code 0
- pass 数が Task 3 後より **15 件以上**増えている（`AudioSystemVerificationTests` は 18 メソッド）
- failures 0

⚠ `testAudioFileResourcesExist` は Bundle の `warning1.mp3` / `rain1.mp3` / `river1.mp3` の存在チェック。プロジェクトに該当ファイルが入っていない場合 fail する。fail した場合は Bundle resources を確認し、必要なら期待 mp3 リストを実際に同梱されているものに合わせる（範囲は本タスク内で OK）。

- [ ] **Step 5: Commit**

```bash
cd app && git add LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #15: AudioSystemVerificationTests.swift を test target に attach

DefaultAudioManager の現 API と整合しているため target 追加のみで復活。
"
```

---

### Task 5: TimerCoreLogicSpec.swift を現 API に書き直し

これがメインタスク。9 個の `it` を現 API に翻訳し、不整合な期待をしているテストは内容修正する。書き直しはファイル全体置換が現実的なので、最終形のコードを Step 内に全部載せる。

**Files:**
- Modify (full rewrite): `app/LeafTimerTests/TimerCoreLogicSpec.swift`

- [ ] **Step 1: 旧 API 参照箇所を列挙して把握**

Run:
```bash
cd app && grep -nE "(workingTime|breakTime|switchToBreakMode|playBreakSoundWasCalled)" LeafTimerTests/TimerCoreLogicSpec.swift
```

Expected (現状):
- Line 104, 179, 207, 259, 267: `workingTime`
- Line 180: `breakTime`
- Line 183, 236: `switchToBreakMode`
- Line 239: `playBreakSoundWasCalled`

これらが書き直し対象。

- [ ] **Step 2: ファイル全体を新しい内容に置き換える**

`app/LeafTimerTests/TimerCoreLogicSpec.swift` の中身を以下で置き換える:

```swift
import Quick
import Nimble
import ViewInspector
import SwiftUI

@testable import LeafTimer

// TimerViewModel の中核ロジックを Spy/Mock を使って検証する spec。
// PR #14 (Issue #3) 時点で pbxproj 未登録のまま放置されていたものを、
// Issue #15 で現 API (fullTimeSecond / switchBreakState / finishCallCount)
// に書き直して復活させた。
class TimerCoreLogicSpec: QuickSpec {
    override class func spec() {
        describe("Timer Core Logic") {

            // MARK: - Helper

            // init() で hasLaunchedBefore 分岐により saveData が 3 回呼ばれるため、
            // 「saveData 呼び出し回数」を検査するテストは生成直後に reset する。
            func makeViewModel() -> (
                vm: TimerViewModel,
                spyTimer: SpyTimerManager,
                spyAudio: SpyAudioManager,
                mockDefaults: MockUserDefaultWrapper
            ) {
                let spyTimer = SpyTimerManager()
                let spyAudio = SpyAudioManager()
                let mockDefaults = MockUserDefaultWrapper()
                let vm = TimerViewModel(
                    timerManager: spyTimer,
                    audioManager: spyAudio,
                    userDefaultWrapper: mockDefaults
                )
                return (vm, spyTimer, spyAudio, mockDefaults)
            }

            // MARK: - TimerManager basic functionality

            context("TimerManager basic functionality") {
                it("stopped 状態から timer button を押すと start が呼ばれる") {
                    let (vm, spyTimer, _, _) = makeViewModel()

                    expect(vm.executeState) == false
                    expect(spyTimer.startWasCalled) == false

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == true
                    expect(spyTimer.startWasCalled) == true
                }

                it("running 状態から timer button を押すと stop が呼ばれる") {
                    let (vm, spyTimer, _, _) = makeViewModel()
                    vm.executeState = true

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == false
                    expect(spyTimer.stopWasCalled) == true
                }

                it("reset() は work mode で currentTimeSecond を fullTimeSecond に戻す") {
                    let (vm, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 100
                    vm.fullTimeSecond = 300
                    vm.breakState = false

                    vm.reset()

                    expect(vm.currentTimeSecond) == 300
                }

                it("reset() は break mode で currentTimeSecond を fullBreakTimeSecond に戻す") {
                    let (vm, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 10
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = true

                    vm.reset()

                    expect(vm.currentTimeSecond) == 60
                }
            }

            // MARK: - Countdown functionality

            context("Countdown functionality") {
                it("updateTime() は currentTimeSecond を 1 減らす") {
                    let (vm, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 300

                    vm.updateTime()

                    expect(vm.currentTimeSecond) == 299
                }

                it("currentTimeSecond が 0 のとき updateTime() で switchBreakState + reset が走る") {
                    let (vm, _, _, _) = makeViewModel()
                    vm.fullBreakTimeSecond = 60
                    vm.currentTimeSecond = 0
                    vm.breakState = false

                    vm.updateTime()

                    // work → break に切り替わる
                    expect(vm.breakState) == true
                    // reset() で currentTimeSecond は fullBreakTimeSecond に戻る
                    expect(vm.currentTimeSecond) == 60
                }
            }

            // MARK: - Work/Break mode switching

            context("Work/Break mode switching") {
                it("work から break への switch で audio.finish() と countWork() が走る") {
                    let (vm, _, spyAudio, mockDefaults) = makeViewModel()
                    vm.breakState = false
                    let countBefore = vm.todaysCount
                    mockDefaults.reset()

                    vm.switchBreakState()

                    expect(vm.breakState) == true
                    expect(spyAudio.finishCallCount) == 1
                    expect(vm.todaysCount) == countBefore + 1
                }

                it("break から work への switch で audio.finishBreak() と audio.start() が走る") {
                    let (vm, _, spyAudio, _) = makeViewModel()
                    vm.breakState = true

                    vm.switchBreakState()

                    expect(vm.breakState) == false
                    expect(spyAudio.finishBreakCallCount) == 1
                    expect(spyAudio.startCallCount) == 1
                }
            }

            // MARK: - Data persistence

            context("Data persistence") {
                it("countWork() で todaysCount が永続化される") {
                    let (vm, _, _, mockDefaults) = makeViewModel()
                    // init で発生する saveData をクリアしてから本番アクションを評価
                    mockDefaults.reset()

                    vm.countWork()

                    expect(mockDefaults.saveDataIntCallCount) >= 1
                }
            }

            // MARK: - Audio integration

            context("Audio integration") {
                it("work → break に切り替わると audioManager.finish() が呼ばれる") {
                    let (vm, _, spyAudio, _) = makeViewModel()
                    vm.breakState = false

                    vm.switchBreakState()

                    expect(spyAudio.finishCallCount) == 1
                }
            }

            // MARK: - State management

            context("State management") {
                it("onPressedTimerButton() の前後で fullTimeSecond は変化しない") {
                    let (vm, _, _, _) = makeViewModel()
                    let initialFullTimeSecond = vm.fullTimeSecond
                    vm.executeState = false

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == true
                    expect(vm.fullTimeSecond) == initialFullTimeSecond
                }
            }

            // MARK: - Memory management

            context("Memory management") {
                it("TimerViewModel は deallocate される") {
                    weak var weakVM: TimerViewModel?

                    autoreleasepool {
                        let spyTimer = SpyTimerManager()
                        let spyAudio = SpyAudioManager()
                        let mockDefaults = MockUserDefaultWrapper()
                        let localVM = TimerViewModel(
                            timerManager: spyTimer,
                            audioManager: spyAudio,
                            userDefaultWrapper: mockDefaults
                        )
                        weakVM = localVM
                        localVM.onPressedTimerButton()
                    }

                    expect(weakVM).to(beNil())
                }
            }
        }
    }
}
```

書き直しのポイント:
- 旧 `workingTime` → `fullTimeSecond`、旧 `breakTime` → `fullBreakTimeSecond`
- 旧 `switchToBreakMode()` → `switchBreakState()`
- 旧 `playBreakSoundWasCalled` → `finishCallCount` (work→break) / `finishBreakCallCount` (break→work)
- `makeViewModel()` ヘルパで boilerplate を集約
- 「Data persistence」の it は `mockDefaults.reset()` を挟んで init 副作用を取り除く
- 「Countdown: time 0 になったとき executeState == false」という旧テストは現実装と合わない（実装は switchBreakState + reset を呼ぶだけで executeState は触らない）ため、`breakState` と `currentTimeSecond` の遷移を検証する形に修正
- 旧テスト 9 件 → 新テスト 11 件（reset の break/work 分岐、switchBreakState の双方向、を追加）

- [ ] **Step 3: target attach**

Run:
```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/TimerCoreLogicSpec.swift LeafTimerTests LeafTimerTests
```

Expected: `added: LeafTimerTests/TimerCoreLogicSpec.swift -> LeafTimerTests`

- [ ] **Step 4: テスト実行**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/leaftimer-after-task5.log | tail -20
```

Expected:
- exit code 0
- pass 数が Task 4 後より **11 件**増えている
- failures 0

もし fail があれば失敗メッセージを読み、`fullTimeSecond` / `fullBreakTimeSecond` のデフォルト値（`25*60` / `5*60`）と各 it の前提条件のズレを疑う。

- [ ] **Step 5: SwiftLint チェック**

Run:
```bash
cd app && make lint 2>&1 | tail -10
```

Expected: 新規 warning なし。`function_body_length` などで引っかかる場合は spec を context 単位に分割するか、`// swiftlint:disable function_body_length` の追加で対応する。

- [ ] **Step 6: Commit**

```bash
cd app && git add LeafTimerTests/TimerCoreLogicSpec.swift LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #15: TimerCoreLogicSpec を現 API に書き直して target attach

旧 workingTime / switchToBreakMode / playBreakSoundWasCalled 等の
古いシンボル参照を fullTimeSecond / switchBreakState / finishCallCount に
置換し、init() の saveData 副作用を考慮した検証に修正した上で
LeafTimerTests target に attach。
"
```

---

### Task 6: ModernTimerViewSpec.xdescribe を可視化、Issue 化

`xdescribe` は本プランの直接スコープ外（経緯不明、ViewInspector のバージョン依存の可能性）。今回は **触らず**、別 Issue に切り出すことで「未対応である」事実を可視化する。

**Files:**
- 触らない

- [ ] **Step 1: `xdescribe` がここだけか確認**

Run:
```bash
cd app && grep -rn "xdescribe\|xit\|xcontext" LeafTimerTests/
```

Expected: `LeafTimerTests/ModernTimerViewSpec.swift:11: xdescribe("Modernized TimerView")` のみ。

- [ ] **Step 2: GitHub Issue を新規作成**

Run:
```bash
cd app && gh issue create --title "ModernTimerViewSpec が xdescribe で全 skip されている" --body "$(cat <<'EOF'
## 背景

Issue #15 (test target 未登録 Spec の復活) 対応中に発覚。

`app/LeafTimerTests/ModernTimerViewSpec.swift:11` が `xdescribe("Modernized TimerView")` になっており、配下の 26 ケースが Quick によって全 skip されている。これが `make tests` の `26 tests skipped` の正体。

## 問題

- `TimerView` (NavigationStack / タイマー表示 / セッション統計 / GIF / レイアウト) を ViewInspector で検証する大規模 spec だが、現状一切走っていない
- なぜ `xdescribe` 化されたのか経緯不明 (ViewInspector のバージョン依存で落ちていたのを退避した可能性が高い)
- `26 skipped` を 0 にしたい (skip 件数が常時非ゼロだと、新規 skip の出現に気付けない)

## 対応案

- **A. 復活**: ViewInspector の現バージョンで pass するように修正し `describe` に戻す
- **B. 廃棄**: View 層は SwiftUI Preview / Snapshot Test の方が筋が良いと判断して全削除
- **C. 一部復活**: `NavigationStack` や `formatted time string` など外形のみ確認するケースだけ復活し、内部実装に深く触れていたケースは削除

## 関連

- Issue #15 (PR で扱った 4 ファイル復活の対象外として明示的に切り出し)
- xdescribe 化のコミット履歴を見ると判断材料になる: \`git log --all -p -- app/LeafTimerTests/ModernTimerViewSpec.swift\`
EOF
)"
```

Expected: 新規 Issue の URL が標準出力される。URL を控えておく。

- [ ] **Step 3: README ないし Issue #15 にコメント追加（任意）**

(コミット不要、Step 4 以降にまとめてプッシュ時に GitHub 側 Issue にコメントする想定で良い)

---

### Task 7: 最終確認 + PR 作成

**Files:**
- 触らない（PR メタ操作のみ）

- [ ] **Step 1: 全テスト・lint を最終確認**

Run:
```bash
cd app && set -o pipefail && make tests 2>&1 | tail -10 && echo "---" && make lint 2>&1 | tail -10
```

Expected:
- tests: failures 0、skipped が baseline の 26 のままで増えていない（`ModernTimerViewSpec` の 26 件は触ってないのでそのまま）、pass 数が baseline +46 程度（DataPersistence 23 + AudioSystem 18 + TimerCoreLogic 11 = 52、ただし Bundle 不足等で多少前後する可能性あり）
- lint: warning 0

- [ ] **Step 2: コミットログを確認**

Run:
```bash
git log --oneline master..HEAD
```

Expected:
```
<sha> Issue #15: TimerCoreLogicSpec を現 API に書き直して target attach
<sha> Issue #15: AudioSystemVerificationTests.swift を test target に attach
<sha> Issue #15: DataPersistenceTests.swift を test target に attach
<sha> Issue #15: 重複していた SimpleDataPersistenceTest.swift を削除
```

4 コミット、それぞれが独立して revert 可能な粒度であること。

- [ ] **Step 3: ブランチを push して PR 作成**

Run:
```bash
git push -u origin feature/issue-15-resurrect-test-targets
```

```bash
gh pr create --title "Issue #15: LeafTimerTests pbxproj 未登録 Spec の復活" --body "$(cat <<'EOF'
## Summary

- `DataPersistenceTests.swift` (XCTest, 23 メソッド) と `AudioSystemVerificationTests.swift` (XCTest, 18 メソッド) を test target に attach
- `TimerCoreLogicSpec.swift` (Quick/Nimble) を現 API (`fullTimeSecond` / `switchBreakState` / `finishCallCount` 等) に書き直して target に attach
- 重複していた `SimpleDataPersistenceTest.swift` を削除
- `ModernTimerViewSpec.swift` の `xdescribe` 起因 skip は別 Issue に切り出し (#NN)

`make tests` の pass 数が baseline +約 50 件、TimerViewModel の中核ロジック spec が事実上ゼロだった状態を解消。

Closes #15

## Test plan

- [ ] `make tests` で failures 0
- [ ] `make lint` で warning 0
- [ ] 新規 pass 数が約 50 件増えていることを確認
- [ ] `26 tests skipped` の skip 数が変動していない (ModernTimerViewSpec の xdescribe はそのまま)
- [ ] Xcode で開いて project navigator に 3 ファイルが正しく見えること
EOF
)"
```

Expected: PR URL が標準出力される。

- [ ] **Step 4: 結果サマリーを Issue #15 にコメント**

Run:
```bash
gh issue comment 15 --body "$(cat <<'EOF'
PR #NN で対応。方針 A (全復活) を採用。

- DataPersistenceTests / AudioSystemVerificationTests → target 追加で復活
- TimerCoreLogicSpec → 現 API に書き直して復活
- SimpleDataPersistenceTest → 削除 (DataPersistenceTests に統合)
- ModernTimerViewSpec の xdescribe は別 Issue #MM に切り出し
EOF
)"
```

(`#NN` / `#MM` は実際の番号に置換。)

---

## Self-Review チェック

- ✅ **Spec coverage**: Issue body の 3 対応案 (A 復活 / B 削除 / C 退避) を A メインで実施、SimpleDataPersistenceTest のみ B を採用、ModernTimerViewSpec を別 Issue に切り出して延命
- ✅ **No placeholders**: 全 Step に具体コマンド or 完全なコード
- ✅ **Type consistency**: `fullTimeSecond` / `fullBreakTimeSecond` / `switchBreakState` / `finishCallCount` / `finishBreakCallCount` を全タスクで一貫使用
- ✅ **TDD / 検証**: 既存実装に対して spec を後付けで書く性質上、Red→Green の TDD リズムは適用しにくいが、各 Task の Step 4 で `make tests` を回して pass 数を baseline と差分比較することで「テストが本当に実行されている」ことを保証
- ✅ **Commit 粒度**: 4 タスク = 4 コミット、各々 revert 可能
- ⚠ **Bundle resources 依存リスク**: Task 4 の `testAudioFileResourcesExist` が `warning1.mp3` / `rain1.mp3` / `river1.mp3` の Bundle 同梱を仮定。fail した場合は本タスク内で期待リストを実環境に合わせる旨を Step 4 ⚠ 注釈に明示
- ⚠ **pbxproj sort**: `make sort` で並び順整形が必要な可能性。`bin/add-to-target.rb` は末尾追加なので、過去 PR のレビューで sort 指摘があった場合は Task 7 Step 1 の前に `make sort` を 1 度走らせる
