# ヘルプ導入（初回オンボーディング）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新規ユーザーの初回起動時にだけ、2画面の軽量オンボーディングを表示し、設定からも再表示できるようにする（#4）。

**Architecture:** 再利用可能な状態レス `OnboardingView` を作り、`.fullScreenCover` で ①`TimerView`（初回ゲート）②`EnhancedSettingView`（もう一度見る）の2箇所から提示する。初回判定は `SettingViewModel` に置き、既存の `UserDefaultsWrapper` 抽象に乗せてテスト可能にする。既存ユーザーは `totalPomodoroCount > 0` を代理指標にフラグをシードして抑制する。

**Tech Stack:** SwiftUI（`TabView` page style / `.fullScreenCover`）、UserDefaults（`UserDefaultsWrapper` プロトコル）、XCTest + ViewInspector、クラシック `.strings` ローカライズ。

**前提コマンド:** 全コマンドは `app/` ディレクトリで実行する。テスト実行は `make unit-tests`（scheme "LeafTimer" / iPhone 17 simulator）。Bash の `timeout` は `600000`（10分）を設定すること（simulator boot + build + test で2〜5分かかるため）。

---

## ファイル構成

| ファイル | 責務 | 操作 |
| --- | --- | --- |
| `LeafTimer/View/OnboardingView.swift` | 2画面の状態レス UI。完了/スキップで `onFinish()` を呼ぶだけ | 新規 |
| `LeafTimer/Components/UserDefaultItem.swift` | 永続化キーの enum | 修正（`hasSeenOnboarding` 追加） |
| `LeafTimer/ViewModel/SettingViewModel.swift` | 初回ゲート判定 + 既読記録 | 修正（2メソッド追加） |
| `LeafTimer/View/TimerView.swift` | 初回ゲート（onAppear で判定し cover 提示） | 修正 |
| `LeafTimer/View/EnhancedSettingView.swift` | 「もう一度見る」導線 | 修正 |
| `LeafTimer/App/ja.lproj/Localizable.strings` | 日本語文言 | 修正 |
| `LeafTimer/App/en.lproj/Localizable.strings` | 英語文言 | 修正 |
| `LeafTimerTests/OnboardingGateTests.swift` | ゲートロジックの単体テスト | 新規 |
| `LeafTimerTests/OnboardingLocalizationTests.swift` | ja/en キー存在テスト | 新規 |
| `LeafTimerTests/OnboardingViewSpec.swift` | skip ボタン → onFinish 発火テスト | 新規 |

**新規ファイルは必ず Xcode target に attach する**（`app/bin/add-to-target.rb`）。未 attach だと `make precheck` が orphan として fail し、ビルド/テストにも含まれない。

---

## Task 1: 初回ゲートのロジック（SettingViewModel + UserDefaultItem）

**Files:**
- Create: `app/LeafTimerTests/OnboardingGateTests.swift`
- Modify: `app/LeafTimer/Components/UserDefaultItem.swift`
- Modify: `app/LeafTimer/ViewModel/SettingViewModel.swift:68`（末尾の空 `extension SettingViewModel {}` を置換）

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/OnboardingGateTests.swift` を新規作成：

```swift
import XCTest
@testable import LeafTimer

final class OnboardingGateTests: XCTestCase {
    private var mock: MockUserDefaultWrapper!
    private var viewModel: SettingViewModel!

    override func setUp() {
        super.setUp()
        mock = MockUserDefaultWrapper()
        viewModel = SettingViewModel(userDefaultWrapper: mock)
    }

    func testNewUserSeesOnboarding() {
        // フラグ未設定(=false) かつ totalPomodoroCount=0 の真の新規ユーザー
        XCTAssertTrue(viewModel.shouldShowOnboarding())
    }

    func testExistingUserDoesNotSeeOnboardingAndFlagIsSeeded() {
        // 既存ユーザー: ポモドーロ完了経験あり
        mock.setValue(for: UserDefaultItem.totalPomodoroCount.rawValue, value: 1)

        XCTAssertFalse(viewModel.shouldShowOnboarding())

        // 二度と出さないようフラグが true にシードされている
        let seeded: Bool = mock.loadData(key: UserDefaultItem.hasSeenOnboarding.rawValue)
        XCTAssertTrue(seeded)
    }

    func testAfterMarkingSeenOnboardingIsNotShown() {
        viewModel.markOnboardingSeen()
        XCTAssertFalse(viewModel.shouldShowOnboarding())
    }
}
```

- [ ] **Step 2: テストファイルを target に attach**

Run:
```bash
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/OnboardingGateTests.swift LeafTimerTests LeafTimerTests
```
Expected: `added: LeafTimerTests/OnboardingGateTests.swift -> LeafTimerTests`

- [ ] **Step 3: テストを実行して失敗を確認**

Run: `make unit-tests`
Expected: コンパイルエラー（`shouldShowOnboarding` / `markOnboardingSeen` / `UserDefaultItem.hasSeenOnboarding` が未定義）で FAIL。

- [ ] **Step 4: enum にキーを追加**

`app/LeafTimer/Components/UserDefaultItem.swift` の enum 末尾（`lastReviewRequestedCount` の後）に追加：

```swift
    case totalPomodoroCount
    case lastReviewRequestedCount

    case hasSeenOnboarding
}
```

- [ ] **Step 5: SettingViewModel にゲートメソッドを実装**

`app/LeafTimer/ViewModel/SettingViewModel.swift:68` の `extension SettingViewModel {}` を以下で置換：

```swift
extension SettingViewModel {
    /// 初回オンボーディングを表示すべきか判定する。
    /// - 既に見た（フラグ true）→ false
    /// - 既存ユーザー（totalPomodoroCount > 0）→ フラグを true にシードして false
    /// - それ以外（真の新規）→ true
    func shouldShowOnboarding() -> Bool {
        if readBool(item: UserDefaultItem.hasSeenOnboarding.rawValue) {
            return false
        }
        if readInt(item: UserDefaultItem.totalPomodoroCount.rawValue) > 0 {
            markOnboardingSeen()
            return false
        }
        return true
    }

    /// オンボーディングを見たことを記録する（以後は表示しない）。
    func markOnboardingSeen() {
        write(isOn: true, item: UserDefaultItem.hasSeenOnboarding.rawValue)
    }
}
```

- [ ] **Step 6: テストを実行して成功を確認**

Run: `make unit-tests`
Expected: `** TEST SUCCEEDED **`（`OnboardingGateTests` の3件が PASS）。
> 注: zsh では `${PIPESTATUS[0]}` は空を返す。成功判定は出力中の `** TEST SUCCEEDED **` / `** TEST FAILED **` マーカーで行う。

- [ ] **Step 7: コミット**

```bash
make sort
git add LeafTimer.xcodeproj/project.pbxproj LeafTimer/Components/UserDefaultItem.swift LeafTimer/ViewModel/SettingViewModel.swift LeafTimerTests/OnboardingGateTests.swift
git commit -m "feat(onboarding): #4 add first-launch gate logic in SettingViewModel"
```

---

## Task 2: ローカライズ文言（ja / en）

**Files:**
- Create: `app/LeafTimerTests/OnboardingLocalizationTests.swift`
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings`
- Modify: `app/LeafTimer/App/en.lproj/Localizable.strings`

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/OnboardingLocalizationTests.swift` を新規作成（`StatLocalizationTests` の lproj 直読みパターンに倣う）：

```swift
import XCTest
@testable import LeafTimer

final class OnboardingLocalizationTests: XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return "<<missing \(locale).lproj>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

    private let keys = [
        "onboarding.welcome.title",
        "onboarding.welcome.body",
        "onboarding.usage.title",
        "onboarding.usage.body",
        "onboarding.skip",
        "onboarding.start_button",
        "settings.help_section",
        "settings.replay_onboarding",
    ]

    func testOnboardingKeysExistInJapanese() {
        for key in keys {
            XCTAssertNotEqual(localized(key, locale: "ja"), "<<missing>>", "ja missing: \(key)")
        }
    }

    func testOnboardingKeysExistInEnglish() {
        for key in keys {
            XCTAssertNotEqual(localized(key, locale: "en"), "<<missing>>", "en missing: \(key)")
        }
    }
}
```

- [ ] **Step 2: テストファイルを target に attach**

Run:
```bash
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/OnboardingLocalizationTests.swift LeafTimerTests LeafTimerTests
```
Expected: `added: ... -> LeafTimerTests`

- [ ] **Step 3: テストを実行して失敗を確認**

Run: `make unit-tests`
Expected: `** TEST FAILED **`（キー未定義のため `<<missing>>` が返り XCTAssertNotEqual が失敗）。

- [ ] **Step 4: 日本語文言を追加**

`app/LeafTimer/App/ja.lproj/Localizable.strings` の末尾（`history.last_7_days` の後）に追加：

```
// MARK: - Onboarding (Issue #4)
"onboarding.welcome.title" = "LeafTimer へようこそ 🍃";
"onboarding.welcome.body" = "集中した時間を、葉っぱを育てて記録しよう。";
"onboarding.usage.title" = "使い方はかんたん";
"onboarding.usage.body" = "ボタンを押すとタイマー開始。集中するほど葉っぱが育ち、今日の回数と連続日数も記録されます。";
"onboarding.skip" = "スキップ";
"onboarding.start_button" = "はじめる";
"settings.help_section" = "ヘルプ";
"settings.replay_onboarding" = "使い方をもう一度見る";
```

- [ ] **Step 5: 英語文言を追加**

`app/LeafTimer/App/en.lproj/Localizable.strings` の末尾（`history.last_7_days` の後）に追加：

```
// MARK: - Onboarding (Issue #4)
"onboarding.welcome.title" = "Welcome to LeafTimer 🍃";
"onboarding.welcome.body" = "Grow a leaf as you focus and watch your effort take root.";
"onboarding.usage.title" = "How it works";
"onboarding.usage.body" = "Tap to start the timer. Your leaf grows as you focus, and your daily count and streak are tracked.";
"onboarding.skip" = "Skip";
"onboarding.start_button" = "Get Started";
"settings.help_section" = "Help";
"settings.replay_onboarding" = "View the intro again";
```

- [ ] **Step 6: テストを実行して成功を確認**

Run: `make unit-tests`
Expected: `** TEST SUCCEEDED **`（ja/en の2件が PASS）。

- [ ] **Step 7: コミット**

```bash
make sort
git add LeafTimer.xcodeproj/project.pbxproj LeafTimer/App/ja.lproj/Localizable.strings LeafTimer/App/en.lproj/Localizable.strings LeafTimerTests/OnboardingLocalizationTests.swift
git commit -m "feat(onboarding): #4 add ja/en onboarding strings"
```

---

## Task 3: OnboardingView（2画面 UI）

**Files:**
- Create: `app/LeafTimer/View/OnboardingView.swift`
- Create: `app/LeafTimerTests/OnboardingViewSpec.swift`

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/OnboardingViewSpec.swift` を新規作成。skip ボタン（page 0 で常時表示・`TabView` の外）を `find(ViewType.Button.self)` で取得しタップ → `onFinish` 発火を検証：

```swift
import XCTest
import ViewInspector
import SwiftUI
@testable import LeafTimer

final class OnboardingViewSpec: XCTestCase {
    func testSkipButtonInvokesOnFinish() throws {
        var finished = false
        let sut = OnboardingView(onFinish: { finished = true })

        // 最初に見つかる Button は TabView の上にある skip ボタン
        // （既存スペックに倣い .body.inspect() でルートから traversal）
        let button = try sut.body.inspect().find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(finished)
    }
}
```

- [ ] **Step 2: テストファイルを target に attach**

Run:
```bash
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/OnboardingViewSpec.swift LeafTimerTests LeafTimerTests
```
Expected: `added: ... -> LeafTimerTests`

- [ ] **Step 3: テストを実行して失敗を確認**

Run: `make unit-tests`
Expected: コンパイルエラー（`OnboardingView` 未定義）で FAIL。

- [ ] **Step 4: OnboardingView を実装**

`app/LeafTimer/View/OnboardingView.swift` を新規作成。背景は `Color(.systemBackground)`（light/dark adaptive な不透明背景。full-screen cover では下に何も透けないため `.ultraThinMaterial` ではなくこれが正しい）、テキストは `.primary` / `.secondary` の semantic color：

```swift
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selection = 0

    private struct Page {
        let emoji: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(
                emoji: "🍃",
                title: NSLocalizedString("onboarding.welcome.title", comment: "Onboarding welcome title"),
                body: NSLocalizedString("onboarding.welcome.body", comment: "Onboarding welcome body")
            ),
            Page(
                emoji: "▶️",
                title: NSLocalizedString("onboarding.usage.title", comment: "Onboarding usage title"),
                body: NSLocalizedString("onboarding.usage.body", comment: "Onboarding usage body")
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if selection < pages.count - 1 {
                        Button(NSLocalizedString("onboarding.skip", comment: "Skip onboarding")) {
                            onFinish()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Text(page.emoji)
                                .font(.system(size: 72))
                            Text(page.title)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            Text(page.body)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                if selection == pages.count - 1 {
                    Button(action: onFinish) {
                        Text(NSLocalizedString("onboarding.start_button", comment: "Get started button"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {})
    }
}
```

- [ ] **Step 5: OnboardingView.swift を app target に attach**

Run:
```bash
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/View/OnboardingView.swift LeafTimer LeafTimer/View
```
Expected: `added: LeafTimer/View/OnboardingView.swift -> LeafTimer`

- [ ] **Step 6: テストを実行して成功を確認**

Run: `make unit-tests`
Expected: `** TEST SUCCEEDED **`（`testSkipButtonInvokesOnFinish` が PASS）。
> ViewInspector の `find(ViewType.Button.self)` が万一 traversal で不安定な場合でも、skip ボタンは `TabView` の外（上位 HStack）にあるため最初にヒットする。どうしても不安定なら `find(button:)`（ラベル一致）にフォールバックしてよい。

- [ ] **Step 7: コミット**

```bash
make sort
git add LeafTimer.xcodeproj/project.pbxproj LeafTimer/View/OnboardingView.swift LeafTimerTests/OnboardingViewSpec.swift
git commit -m "feat(onboarding): #4 add 2-page OnboardingView"
```

---

## Task 4: TimerView へ初回ゲートを配線

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift`（`@State` 追加 / `.onAppear` 拡張 / `.fullScreenCover` 追加）

- [ ] **Step 1: `@State` プロパティを追加**

`app/LeafTimer/View/TimerView.swift` の State セクション（`@Environment(\.colorScheme) var colorScheme` の直後、line 10 付近）に追加：

```swift
    @Environment(\.colorScheme) var colorScheme
    @State private var showOnboarding = false
```

- [ ] **Step 2: onAppear にゲート判定を追加 + fullScreenCover を付与**

`TimerView.swift` の `.onAppear { ... }`（line 110-113）を以下で置換し、直後に `.fullScreenCover` を追加：

```swift
                .onAppear {
                    timerViewModel.readData()
                    timerViewModel.openScreen()
                    if settingViewModel.shouldShowOnboarding() {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView {
                        settingViewModel.markOnboardingSeen()
                        showOnboarding = false
                    }
                }
```

- [ ] **Step 3: ビルド & テストを実行**

Run: `make unit-tests`
Expected: `** TEST SUCCEEDED **`（ビルドが通り、既存テストも全て PASS。`TimerViewSpec` / `ModernTimerViewSpec` が壊れていないこと）。

- [ ] **Step 4: コミット**

```bash
git add LeafTimer/View/TimerView.swift
git commit -m "feat(onboarding): #4 show onboarding on first launch from TimerView"
```

---

## Task 5: EnhancedSettingView へ「もう一度見る」を配線

**Files:**
- Modify: `app/LeafTimer/View/EnhancedSettingView.swift`（`@State` 追加 / Help Section 追加 / `.fullScreenCover` 追加）

- [ ] **Step 1: `@State` プロパティを追加**

`app/LeafTimer/View/EnhancedSettingView.swift` の `@Environment(\.dismiss) private var dismiss`（line 5）の直後に追加：

```swift
    @Environment(\.dismiss) private var dismiss
    @State private var showOnboarding = false
```

- [ ] **Step 2: Help Section を Form に追加**

`EnhancedSettingView.swift` の Mode Section（line 17-45）と About Section（line 48）の間に、新しい Help Section を追加：

```swift
                // Help Section (Issue #4)
                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label(
                            NSLocalizedString("settings.replay_onboarding", comment: "Replay onboarding"),
                            systemImage: "questionmark.circle"
                        )
                        .font(.system(size: 15, weight: .medium))
                    }
                } header: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("settings.help_section", comment: "Help section header"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                }

                // About Section
```

- [ ] **Step 3: fullScreenCover を付与（再表示はフラグを書かない）**

`EnhancedSettingView.swift` の `Form { ... }` 閉じ括弧の直後（`.navigationTitle(...)` がある行の前）に `.fullScreenCover` を追加。再表示なので `markOnboardingSeen()` は**呼ばない**：

```swift
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: "Settings navigation title"))
```

- [ ] **Step 4: ビルド & テストを実行**

Run: `make unit-tests`
Expected: `** TEST SUCCEEDED **`（ビルド通過・全テスト PASS。`ModernSettingViewSpec` のセクション数 expectation `>= 3` は Help 追加後も満たす）。

- [ ] **Step 5: コミット**

```bash
git add LeafTimer/View/EnhancedSettingView.swift
git commit -m "feat(onboarding): #4 add 'view intro again' entry in settings"
```

---

## Task 6: フル検証（precheck / sort / lint / unit-tests + 実機目視）

**Files:** なし（検証のみ。差分が出たら commit）

- [ ] **Step 1: フルテストスイートを実行**

Run: `make tests`
Expected: `precheck`（orphan 無し）→ `sort`（差分無し）→ `lint`（違反無し）→ `unit-tests` `** TEST SUCCEEDED **` が全て通る。
> もし `make sort` がここで pbxproj を変更したら、新規ファイル追加後の未ソートが残っていたサイン。`git add LeafTimer.xcodeproj/project.pbxproj && git commit -m "chore: #4 sort pbxproj"` で追従する（Issue #8 の「PR後に1 uncommitted change」事故を防ぐ）。

- [ ] **Step 2: Simulator で4状態を目視検証（新規ユーザー）**

クリーンな状態（`hasSeenOnboarding` 未設定・`totalPomodoroCount` 0）で、light/dark × ja/en の **4状態**を目視し、オンボーディングの文字・背景の可読性を確認する（Issue #39 の「ハードコード白は light で不可視」教訓）。`ios-simulator-app-verification` / `ios-simulator-locale-testing` スキルを使い、`xcrun simctl ui <SIM> appearance light|dark` と `-AppleLanguages` で切替える。

確認項目:
- 2画面がスワイプでき、ページドットが見える
- 1画面目に「スキップ」、2画面目に「はじめる」が表示される
- 「はじめる」/「スキップ」で閉じ、再起動しても二度と出ない

- [ ] **Step 3: 既存ユーザーで出ないことを確認**

`totalPomodoroCount > 0` をシードした状態（または1回ポモドーロを完了させた状態）でアプリを起動し、**オンボーディングが出ないこと**を確認する。

- [ ] **Step 4: 設定からの再表示を確認**

設定 →「ヘルプ」→「使い方をもう一度見る」で再生でき、再生後もフラグが初回状態に戻らない（再起動で初回オンボが復活しない）ことを確認する。

- [ ] **Step 5: 最終コミット & PR 準備**

差分が残っていれば commit。`git status` がクリーンなことを確認してから PR 作成に進む（PR 作成前に `git fetch && gh pr list --state all --head feature/4-help-onboarding` で既存 PR を確認）。スクリーンショット（4状態）は `SendUserFile` でユーザーに渡し、PR 本文には「スクリーンショット」枠だけ用意してユーザーがドラッグ&ドロップ添付する（ローカルパス画像は GitHub に埋め込めないため）。

---

## スコープ外（YAGNI）

- 3画面以上・コーチマーク・動画・FAQ・設定内の常設ヘルプページ。
- 休憩 / 履歴 / 設定の詳細解説（ミニマル方針）。
- `SettingView.swift`（dead code 疑い）の整理 — 本 issue とは無関係なので触らない。
