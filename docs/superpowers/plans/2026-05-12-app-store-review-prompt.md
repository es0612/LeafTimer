# App Store Review Prompt — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Store レビュー誘導を LeafTimer に導入する。累計ポモドーロ完了が 5/20/50 回を超えた瞬間（ワーク完了→ブレイク突入直後）にネイティブのレビュー要請ダイアログを出し、設定画面に手動の評価導線も追加する。

**Architecture:** プロトコル分離 + DI。閾値判定の純粋ロジック (`ReviewRequestPolicy`) と StoreKit/UIApplication 副作用ラッパ (`ReviewRequesting`) を分離。既存の `UserDefaultsWrapper`/`AudioManager`/`TimerManager` と同じパターンに乗せて Quick/Nimble でテスト可能にする。

**Tech Stack:** Swift 5, SwiftUI, UIKit (UIApplication), StoreKit (SKStoreReviewController), Quick/Nimble, CocoaPods

**Spec:** `docs/superpowers/specs/2026-05-12-app-store-review-prompt-design.md`

---

## ファイル構成

### 新規作成

| パス | 責務 |
|---|---|
| `app/LeafTimer/Components/ReviewRequestPolicy.swift` | 閾値判定の純粋関数（副作用なし、テスト容易） |
| `app/LeafTimer/Components/StoreKitReviewRequester.swift` | SKStoreReviewController と App Store URL を呼ぶラッパ |
| `app/LeafTimer/View/Settings/AboutSettingsSection.swift` | 設定画面の「アプリを評価する」セクション |
| `app/LeafTimerTests/ReviewRequestPolicySpec.swift` | 閾値判定の境界値テスト |
| `app/LeafTimerTests/MockReviewRequester.swift` | ReviewRequesting の spy 実装 |

### 編集

| パス | 変更点 |
|---|---|
| `app/LeafTimer/Components/UserDefaultItem.swift` | enum に `totalPomodoroCount`, `lastReviewRequestedCount` の2ケース追加 |
| `app/LeafTimer/ViewModel/TimerViewModel.swift` | init に 2引数追加（デフォルト引数あり）、`countWork()` 拡張、`requestReviewIfNeeded()` を新規メソッドとして追加 |
| `app/LeafTimer/View/EnhancedSettingView.swift` | `Form` の中に `AboutSettingsSection()` を `ResetSettingsSection` の直前に挿入 |
| `app/LeafTimerTests/TimerCoreLogicSpec.swift` | レビュー要請の発火/不発火を検証する context を追加 |

### Xcode プロジェクト統合

新規ファイルは `app/LeafTimer.xcodeproj/project.pbxproj` に追加する必要がある。各タスクで `make sort` を実行し、Xcode が自動的にファイルを認識した状態でビルド確認する。Xcode を開いて手動で Target に追加するのが確実。

---

### Task 1: ReviewRequestPolicy（閾値判定の純粋ロジック）

**Files:**
- Create: `app/LeafTimer/Components/ReviewRequestPolicy.swift`
- Create: `app/LeafTimerTests/ReviewRequestPolicySpec.swift`

- [ ] **Step 1: Spec ファイルを書く（失敗するテスト）**

`app/LeafTimerTests/ReviewRequestPolicySpec.swift` を新規作成:

```swift
import Quick
import Nimble

@testable import LeafTimer

class ReviewRequestPolicySpec: QuickSpec {
    override class func spec() {
        describe("ThresholdReviewRequestPolicy") {
            let policy = ThresholdReviewRequestPolicy()

            context("when total has not crossed any threshold") {
                it("returns false at total=4, last=0") {
                    expect(policy.shouldRequest(totalCount: 4, lastRequestedCount: 0)) == false
                }
            }

            context("when total just crosses the first threshold (5)") {
                it("returns true at total=5, last=0") {
                    expect(policy.shouldRequest(totalCount: 5, lastRequestedCount: 0)) == true
                }
            }

            context("when total is at the threshold but already requested") {
                it("returns false at total=5, last=5") {
                    expect(policy.shouldRequest(totalCount: 5, lastRequestedCount: 5)) == false
                }
            }

            context("when total crosses the second threshold (20)") {
                it("returns true at total=20, last=5") {
                    expect(policy.shouldRequest(totalCount: 20, lastRequestedCount: 5)) == true
                }
                it("returns false at total=20, last=20") {
                    expect(policy.shouldRequest(totalCount: 20, lastRequestedCount: 20)) == false
                }
            }

            context("when total skips multiple thresholds in one update") {
                it("returns true at total=50, last=5") {
                    expect(policy.shouldRequest(totalCount: 50, lastRequestedCount: 5)) == true
                }
            }

            context("when total exceeds the last threshold") {
                it("returns false at total=51, last=50") {
                    expect(policy.shouldRequest(totalCount: 51, lastRequestedCount: 50)) == false
                }
                it("returns false at total=1000, last=50") {
                    expect(policy.shouldRequest(totalCount: 1000, lastRequestedCount: 50)) == false
                }
            }
        }
    }
}
```

- [ ] **Step 2: Xcode で新規ファイルを LeafTimerTests Target に追加**

Xcode を開き、`app/LeafTimerTests/` グループに `ReviewRequestPolicySpec.swift` を追加（Target Membership: LeafTimerTests のみチェック）。

- [ ] **Step 3: ビルド試行 → 失敗を確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build test 2>&1 | tail -20
```

Expected: ビルドエラー `cannot find 'ThresholdReviewRequestPolicy' in scope`

- [ ] **Step 4: 実装ファイルを書く**

`app/LeafTimer/Components/ReviewRequestPolicy.swift` を新規作成:

```swift
import Foundation

protocol ReviewRequestPolicy {
    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool
}

struct ThresholdReviewRequestPolicy: ReviewRequestPolicy {
    static let thresholds = [5, 20, 50]

    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool {
        Self.thresholds.contains { threshold in
            lastRequestedCount < threshold && totalCount >= threshold
        }
    }
}
```

- [ ] **Step 5: Xcode で新規ファイルを LeafTimer Target に追加**

`app/LeafTimer/Components/` グループに `ReviewRequestPolicy.swift` を追加（Target Membership: LeafTimer のみチェック）。

- [ ] **Step 6: テスト実行 → 全件パスを確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build test 2>&1 | grep -E '(Test Case.*ThresholdReviewRequestPolicy|TEST SUCCEEDED|TEST FAILED)' | tail -20
```

Expected: 8件のテストすべて `passed`、最後に `** TEST SUCCEEDED **`

- [ ] **Step 7: pbxproj をソートしてコミット**

```bash
cd app && make sort
git add app/LeafTimer/Components/ReviewRequestPolicy.swift app/LeafTimerTests/ReviewRequestPolicySpec.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #3: ReviewRequestPolicy 閾値判定ロジックを追加"
```

---

### Task 2: UserDefaultItem に永続化ケースを追加

**Files:**
- Modify: `app/LeafTimer/Components/UserDefaultItem.swift`

- [ ] **Step 1: enum にケース2つを追加**

`UserDefaultItem` を以下に書き換え:

```swift
import Foundation

enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration

    case workingSound
    case breakSound

    case totalPomodoroCount
    case lastReviewRequestedCount
}
```

- [ ] **Step 2: ビルド確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミット**

```bash
git add app/LeafTimer/Components/UserDefaultItem.swift
git commit -m "Issue #3: UserDefaultItem にレビュー関連ケースを追加"
```

---

### Task 3: ReviewRequesting プロトコル + StoreKit 実装

**Files:**
- Create: `app/LeafTimer/Components/StoreKitReviewRequester.swift`

副作用ラッパで実機/シミュレータでしか挙動確認できないため、このタスクではユニットテストは書かない（Apple 実装を信頼）。

- [ ] **Step 1: protocol と本番実装を書く**

`app/LeafTimer/Components/StoreKitReviewRequester.swift` を新規作成:

```swift
import Foundation
import StoreKit
import UIKit

protocol ReviewRequesting {
    func requestReview()
    func openAppStoreReviewPage()
}

final class StoreKitReviewRequester: ReviewRequesting {
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
    }

    func openAppStoreReviewPage() {
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "LeafTimerAppStoreID") as? String,
              !appID.isEmpty,
              let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
```

- [ ] **Step 2: Xcode で新規ファイルを LeafTimer Target に追加**

`app/LeafTimer/Components/` グループに `StoreKitReviewRequester.swift` を追加。

- [ ] **Step 3: ビルド確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: pbxproj をソートしてコミット**

```bash
cd app && make sort
git add app/LeafTimer/Components/StoreKitReviewRequester.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #3: StoreKitReviewRequester を追加"
```

---

### Task 4: MockReviewRequester（テスト用 spy）

**Files:**
- Create: `app/LeafTimerTests/MockReviewRequester.swift`

既存の `SpyAudioManager` パターンを踏襲して、呼び出し回数を `private(set)` で公開する spy を作る。

- [ ] **Step 1: Mock 実装を書く**

`app/LeafTimerTests/MockReviewRequester.swift` を新規作成:

```swift
@testable import LeafTimer

class MockReviewRequester: ReviewRequesting {
    // MARK: - Call Tracking

    private(set) var requestReviewCallCount = 0
    private(set) var openAppStoreReviewPageCallCount = 0

    // MARK: - ReviewRequesting Implementation

    func requestReview() {
        requestReviewCallCount += 1
    }

    func openAppStoreReviewPage() {
        openAppStoreReviewPageCallCount += 1
    }

    // MARK: - Helper Methods for Testing

    func reset() {
        requestReviewCallCount = 0
        openAppStoreReviewPageCallCount = 0
    }
}
```

- [ ] **Step 2: Xcode で新規ファイルを LeafTimerTests Target に追加**

`app/LeafTimerTests/` グループに `MockReviewRequester.swift` を追加（Target Membership: LeafTimerTests のみ）。

- [ ] **Step 3: ビルド確認（テストターゲット）**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build-for-testing 2>&1 | tail -5
```

Expected: `** TEST BUILD SUCCEEDED **`

- [ ] **Step 4: pbxproj をソートしてコミット**

```bash
cd app && make sort
git add app/LeafTimerTests/MockReviewRequester.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "Issue #3: MockReviewRequester（テスト用 spy）を追加"
```

---

### Task 5: TimerViewModel にレビュー要請ロジックを統合

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift`
- Modify: `app/LeafTimerTests/TimerCoreLogicSpec.swift`

- [ ] **Step 1: TimerCoreLogicSpec に新しい context を追加（失敗するテスト）**

`app/LeafTimerTests/TimerCoreLogicSpec.swift` の `spec()` の中、`testMemoryManagement()` 呼び出しの直前に新メソッド呼び出しを追加し、ファイル末尾に新メソッドを追加。

まず `spec()` 内に呼び出し追加（35-41行目あたり）:

```swift
            TimerCoreLogicSpec.testTimerManagerBasicFunctionality()
            TimerCoreLogicSpec.testCountdownFunctionality()
            TimerCoreLogicSpec.testWorkBreakModeSwitching()
            TimerCoreLogicSpec.testDataPersistence()
            TimerCoreLogicSpec.testAudioIntegration()
            TimerCoreLogicSpec.testStateManagement()
            TimerCoreLogicSpec.testMemoryManagement()
            TimerCoreLogicSpec.testReviewRequestIntegration()   // ★ 追加
```

ファイル末尾に新メソッドを追加（`testMemoryManagement` の閉じカッコの後、クラス閉じカッコの前）:

```swift
    // MARK: - Review Request Integration

    static func testReviewRequestIntegration() {
        context("Review request integration") {
            it("does not request review when totalPomodoroCount stays under the first threshold") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 3
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (3 → 4)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 0
            }

            it("requests review when totalPomodoroCount crosses the first threshold (4 -> 5)") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 4
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 0
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (4 → 5)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 1
            }

            it("does not request review again on subsequent pomodoros within the same threshold range (5 -> 6)") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 5
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 5
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (5 → 6)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 0
            }

            it("updates lastReviewRequestedCount after requesting a review") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 4
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 0
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (4 → 5)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then: lastReviewRequestedCount が 5 に更新されている
                let saved = mockUserDefaultWrapper.loadData(
                    key: UserDefaultItem.lastReviewRequestedCount.rawValue
                )
                expect(saved) == 5
            }
        }
    }
```

- [ ] **Step 2: テスト実行 → 失敗を確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build test 2>&1 | tail -20
```

Expected: ビルドエラー `extra argument 'reviewPolicy' in call`（init 未拡張のため）

- [ ] **Step 3: TimerViewModel を拡張**

`app/LeafTimer/ViewModel/TimerViewModel.swift` を以下のように編集:

**3a. DI プロパティを追加（class 内、既存 DI の下）:**

```swift
    var timerManager: TimerManager
    var audioManager: AudioManager
    var userDefaultWrapper: UserDefaultsWrapper
    var reviewPolicy: ReviewRequestPolicy
    var reviewRequester: ReviewRequesting
```

**3b. init を以下に書き換え（既存の34-62行目）:**

```swift
    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper,
        reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    ) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper
        self.reviewPolicy = reviewPolicy
        self.reviewRequester = reviewRequester

        fullTimeSecond = 25 * 60
        currentTimeSecond = 25 * 60
        executeState = false

        fullBreakTimeSecond = 5 * 60
        breakState = false

        vibration = true

        todaysCount = 0

        loadCount()

        // Set default sound settings on first launch only
        if userDefaultWrapper.loadData(key: "hasLaunchedBefore") == 0 {
            userDefaultWrapper.saveData(key: UserDefaultItem.workingSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.breakSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: "hasLaunchedBefore", value: 1)
        }
    }
```

**3c. `countWork()` を以下に書き換え（既存の155-158行目）:**

```swift
    func countWork() {
        todaysCount += 1
        userDefaultWrapper.saveData(key: DateManager.getToday(), value: todaysCount)

        let totalCount = userDefaultWrapper.loadData(
            key: UserDefaultItem.totalPomodoroCount.rawValue
        ) + 1
        userDefaultWrapper.saveData(
            key: UserDefaultItem.totalPomodoroCount.rawValue,
            value: totalCount
        )

        requestReviewIfNeeded(totalCount: totalCount)
    }

    private func requestReviewIfNeeded(totalCount: Int) {
        let lastRequested = userDefaultWrapper.loadData(
            key: UserDefaultItem.lastReviewRequestedCount.rawValue
        )
        guard reviewPolicy.shouldRequest(
            totalCount: totalCount, lastRequestedCount: lastRequested
        ) else { return }

        reviewRequester.requestReview()
        userDefaultWrapper.saveData(
            key: UserDefaultItem.lastReviewRequestedCount.rawValue,
            value: totalCount
        )
    }
```

- [ ] **Step 4: テスト実行 → 新規4件パス & 既存テストが回帰していないことを確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build test 2>&1 | grep -E '(Test Suite.*Review|Executed.*tests|TEST SUCCEEDED|TEST FAILED)' | tail -10
```

Expected:
- 新規 `Review request integration` context の4件が `passed`
- 最終: `Executed 50 tests, with 26 tests skipped and 0 failures` 程度（既存46 + 新規4）
- `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimerTests/TimerCoreLogicSpec.swift
git commit -m "Issue #3: TimerViewModel にレビュー要請ロジックを統合"
```

---

### Task 6: AboutSettingsSection を作って設定画面に組み込む

**Files:**
- Create: `app/LeafTimer/View/Settings/AboutSettingsSection.swift`
- Modify: `app/LeafTimer/View/EnhancedSettingView.swift`

`SettingViewModel` への DI も必要。`reviewRequester` を `SettingViewModel` のプロパティとして持たせ、`AboutSettingsSection` から呼ぶ。

- [ ] **Step 1: SettingViewModel の構造を確認**

```bash
cat app/LeafTimer/ViewModel/SettingViewModel.swift | head -40
```

期待: `init(userDefaultWrapper:)` のシグネチャ。`reviewRequester` プロパティを追加する余地を確認。

- [ ] **Step 2: SettingViewModel に DI 追加**

`app/LeafTimer/ViewModel/SettingViewModel.swift` の init に `reviewRequester` を追加。クラス内に格納用プロパティ追加:

```swift
    var reviewRequester: ReviewRequesting
```

init 引数追加（既存引数の後ろ、デフォルト引数で）:

```swift
    init(
        userDefaultWrapper: UserDefaultsWrapper,
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    ) {
        self.userDefaultWrapper = userDefaultWrapper
        self.reviewRequester = reviewRequester
        // ... 既存処理はそのまま
    }
```

外向きヘルパーを追加:

```swift
    func openAppStoreReviewPage() {
        reviewRequester.openAppStoreReviewPage()
    }
```

- [ ] **Step 3: AboutSettingsSection を新規作成**

`app/LeafTimer/View/Settings/AboutSettingsSection.swift`:

```swift
import SwiftUI

struct AboutSettingsSection: View {
    @ObservedObject var viewModel: SettingViewModel

    var body: some View {
        Section {
            Button {
                viewModel.openAppStoreReviewPage()
            } label: {
                HStack {
                    Label(
                        NSLocalizedString("settings.review_app", comment: "Review this app"),
                        systemImage: "star.fill"
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        } header: {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                Text(NSLocalizedString("settings.about_section", comment: "About section header"))
            }
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
        } footer: {
            Text(NSLocalizedString(
                "settings.review_app_footer",
                comment: "Footer for review section"
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}
```

- [ ] **Step 4: ローカライズ文字列を Localizable.strings に追加**

```bash
ls app/LeafTimer/*.lproj/Localizable.strings 2>/dev/null || ls app/LeafTimer/Resources/*.lproj/ 2>/dev/null
```

該当 .strings ファイルに以下を追加（ja/en それぞれ）:

英語版:
```
"settings.review_app" = "Review this app";
"settings.about_section" = "About";
"settings.review_app_footer" = "If you enjoy LeafTimer, please leave a review on the App Store.";
```

日本語版:
```
"settings.review_app" = "このアプリを評価する";
"settings.about_section" = "アプリについて";
"settings.review_app_footer" = "LeafTimer が役に立ったら、App Store でレビューをお寄せください。";
```

該当ファイルが見つからない場合はスキップ（既存パターンに揃えてフォールバック英語表示でも可）。

- [ ] **Step 5: EnhancedSettingView に組み込み**

`app/LeafTimer/View/EnhancedSettingView.swift` の Form 内、`ResetSettingsSection(viewModel: settingViewModel)` の直前に1行追加（既存48行目あたり）:

```swift
                // About Section (新規)
                AboutSettingsSection(viewModel: settingViewModel)

                // Reset & System Section
                ResetSettingsSection(viewModel: settingViewModel)
```

- [ ] **Step 6: ビルド確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: シミュレータで設定画面を起動して目視確認**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' -configuration Debug build 2>&1 | tail -3
```

その後、Xcode でアプリを Run → 設定画面を開き、「Reset」セクションの直前に「アプリを評価する / Review this app」が表示されているか確認。タップしてもアプリがクラッシュしない（`LeafTimerAppStoreID` 未設定なので何も起きないのが正しい）ことを確認。

- [ ] **Step 8: pbxproj をソートしてコミット**

```bash
cd app && make sort
git add app/LeafTimer/View/Settings/AboutSettingsSection.swift \
        app/LeafTimer/View/EnhancedSettingView.swift \
        app/LeafTimer/ViewModel/SettingViewModel.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
# Localizable.strings を変更した場合は追加
git add app/LeafTimer/*.lproj/Localizable.strings 2>/dev/null || true
git commit -m "Issue #3: 設定画面にレビュー誘導セクションを追加"
```

---

### Task 7: 既存テスト全件が通ることを確認＆Issue クローズ準備

**Files:** なし（検証のみ）

- [ ] **Step 1: 全テスト実行**

```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build test 2>&1 | grep -E '(Test Suite.*tests|Executed.*tests|TEST SUCCEEDED|TEST FAILED)' | tail -5
```

Expected:
- `Executed 50 tests, with 26 tests skipped and 0 failures`
- `** TEST SUCCEEDED **`

- [ ] **Step 2: lint 実行**

```bash
cd app && make lint 2>&1 | tail -3
```

Expected: 既存 violation 数より増えていないこと（177以下）。新規ファイルで violation が出たら修正してから次へ。

- [ ] **Step 3: 全コミット履歴を確認**

```bash
git log --oneline master..HEAD 2>/dev/null || git log --oneline -10
```

Expected (上から順):
- Issue #3: 設定画面にレビュー誘導セクションを追加
- Issue #3: TimerViewModel にレビュー要請ロジックを統合
- Issue #3: MockReviewRequester（テスト用 spy）を追加
- Issue #3: StoreKitReviewRequester を追加
- Issue #3: UserDefaultItem にレビュー関連ケースを追加
- Issue #3: ReviewRequestPolicy 閾値判定ロジックを追加

- [ ] **Step 4: 実装計画ファイルを git 管理に加えるかユーザに確認**

注: `docs/superpowers/specs/` は spec をコミットした。`docs/superpowers/plans/` の plan もリポジトリに残すかユーザに確認。残す場合:

```bash
git add docs/superpowers/plans/2026-05-12-app-store-review-prompt.md
git commit -m "Issue #3: 実装計画を保存"
```

- [ ] **Step 5: ユーザに完了報告 + push 確認**

報告事項:
- 全テスト通過（既存46 + 新規4 = 50件、failures 0）
- 6コミット作成（push はユーザ確認後）
- 実機検証は別途実施（SKStoreReviewController は実機 / TestFlight でのみ実挙動を確認可能）
- `LeafTimerAppStoreID` は App Store ID 確定後に `Info.plist` へ追加

push と Issue #3 のクローズはユーザの明示指示後に実施。

---

## 検証手順（end-to-end）

実装完了後、以下を順に確認:

1. **ユニットテスト**: 全件 PASS（上記 Task 7 Step 1）
2. **ビルド**: Debug / Release 両方でエラーなし
3. **シミュレータ目視**: 設定画面に「アプリを評価する」表示、タップでクラッシュなし
4. **実機/TestFlight 検証**（リリース前）:
   - 累計 5 回ポモドーロ完了でレビューダイアログが表示される
   - 5 → 6 で再表示されない
   - 設定 > Apple Account > メディアと購入 でレビュー履歴をリセット後、20 / 50 回でも表示される
5. **本リリース後**: App Store ID を `Info.plist` の `LeafTimerAppStoreID` に追加し、設定画面の「アプリを評価する」が機能することを確認

---

## オープン項目（実装中に判明したら対応）

- `Localizable.strings` の場所が見つからなければ、既存パターンに従い英語文字列をハードコードでも可（Spec 上の MUST ではない）
- `SettingViewModel` の構造によっては Task 6 Step 2 の差し込みが微調整必要
- 既存テスト26件の skipped は本件のスコープ外（別 issue で対応）
