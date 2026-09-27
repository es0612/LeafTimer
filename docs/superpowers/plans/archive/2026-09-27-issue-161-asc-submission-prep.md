# #161 ASC 申請準備の自動化 (Chrome 経路) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v1.5 のストア用スクショ (ja / en × iPhone 6.9" / iPad 13" × 5 画面) と What's New を repo から再生成できるようにし、PR 作成までを行う。ASC への投入は PR 作成後にコントローラが `asc-submission-prep` skill で行う (本 plan のタスク外、末尾「PR 作成後」参照)。

**画面の決定:** spec 4.B の候補のうち起動画面 (splash) は撮影タイミングが再現しないため不採用 (実測)、代わりに v1.5 の新機能のオンボーディングを入れる。

**Architecture:** DEBUG 限定の起動引数 (`-SeedSampleStats` / `-AutoStart` / `-InitialScreen=onboarding`) で撮影用の状態を作り、`bin/store-screenshots.rb` が専用 Simulator で撮影 → `bin/store-screenshot-compose.swift` (CoreGraphics) で背景 + コピーを合成 → `bin/store-screenshots-check.rb` が寸法と枚数を検証する。What's New は `docs/RELEASE_v1.5.md`。

**Tech Stack:** Swift / SwiftUI / XCTest、Ruby (minitest)、CoreGraphics + CoreText + ImageIO、xcrun simctl、applesimutils

**Spec:** `docs/superpowers/specs/2026-09-27-issue-161-asc-submission-prep.md`

## Global Constraints

- 出力寸法: iPhone **1320×2868**、iPad **2064×2752** (Apple screenshot-specifications の 6.9" / 13"。Simulator の生スクショも同寸であることを 2026-09-27 に実測済み)
- 撮影機種: `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max` / `com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB`、Simulator 名 `LeafTimer-Store-iphone` / `LeafTimer-Store-ipad` (UDID で扱う — CLAUDE.md ルール 30)
- 撮影用フックは **すべて `#if DEBUG`**。Release バイナリに入れない
- 生成物は `app/build/store-screenshots/` (`app/.gitignore` の `build/` で管理外)。repo に PNG を commit しない
- What's New は ja / en とも**絵文字禁止**
- 新規 Swift ファイルの配線は `make add-file FILE=<path> TARGET=app|test` (ルール 28)
- ビルド / テストは `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置し、成否は出力マーカーで判定 (ルール 1)
- 「審査へ提出」は押さない。ASC への書き込みは本 plan のタスクに含めない

## Review Focus

1. **en のコピーが長くて画面幅からはみ出す** → compose が最長行を幅 88% に収まるまで縮小する (実測: "your perfect focus zone" で縮小を確認済み)。Task 3 で en の全 10 枚を目視する
2. **前回実行の古い PNG が残り、削除した画面が ASC にアップロードされる** → capture 開始時に `raw/` `final/` を消し、checker が `unexpected:` を出す (Task 2 のテスト `test_unexpected_file_is_reported`)
3. **通知許可 / ATT のシステムダイアログが実行中画面に被る** → capture が applesimutils で `userTracking=YES, notifications=YES` を事前付与する。Task 3 の目視で 02-growing にダイアログが無いことを確認する
4. **Seed データが既存ユーザーの実データを上書きする** → フックは DEBUG ビルド限定かつ起動引数がある時だけ。Task 1 のテスト `testSeedIsNotAppliedWithoutArgument` で引数なしなら書き込まないことを固定する
5. **日付境界 (撮影中に日付が変わる) で過去 7 日の棒が 1 本ずれる** → seed は起動のたびに `Date()` 基準で書き直すので、次の起動で自己修復する。対策コードは足さない (YAGNI)。撮影は日中に行う

---

### Task 1: 撮影用 DEBUG フック (seed / auto start / onboarding 画面)

**Files:**
- Create: `app/LeafTimer/Components/DebugStoreScreenshot.swift`
- Create: `app/LeafTimerTests/DebugStoreScreenshotTests.swift`
- Modify: `app/LeafTimer/App/AppDelegate.swift` (VM 生成の直前に seed)
- Modify: `app/LeafTimer/View/TimerView.swift` (`onAppear` の auto start、`debugScreen` に `onboarding`)

**Interfaces:**
- Produces: 起動引数 `-SeedSampleStats` / `-AutoStart` / `-InitialScreen=onboarding` (Task 2 の `screens.json` が使う)
- Produces: `DebugStoreScreenshot.sampleStats(today: Date, calendar: Calendar) -> SessionStats`、`DebugStoreScreenshot.seedIfRequested(arguments: [String], defaults: UserDefaults, today: Date)`

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/DebugStoreScreenshotTests.swift`:

```swift
import XCTest
@testable import LeafTimer

/// Issue #161: ストア用スクショ撮影 (make store-screenshots) の DEBUG フック。
final class DebugStoreScreenshotTests: XCTestCase {

    private let suiteName = "DebugStoreScreenshotTests"
    private var testDefaults: UserDefaults!
    private let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 27
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testSeedIsReadableByLocalSessionStatsRepository() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: ["LeafTimer", DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        let stats = LocalSessionStatsRepository(userDefaults: testDefaults).load()

        XCTAssertEqual(stats, DebugStoreScreenshot.sampleStats(today: today))
        XCTAssertEqual(stats.totalCount, 128)
        XCTAssertEqual(stats.currentStreak, 12)
    }

    func testSeedFillsLastSevenDaysEndingToday() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: [DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        let days = LocalSessionStatsRepository(userDefaults: testDefaults)
            .recentDailyCounts(days: 7, endingAt: "2026/09/27")

        XCTAssertEqual(days.map(\.date).first, "2026/09/21")
        XCTAssertEqual(days.map(\.count), [3, 5, 2, 6, 4, 7, 4])
    }

    func testSeedMarksOnboardingSeen() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: [DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        XCTAssertTrue(testDefaults.bool(forKey: UserDefaultItem.hasSeenOnboarding.rawValue))
    }

    func testSeedIsNotAppliedWithoutArgument() {
        DebugStoreScreenshot.seedIfRequested(arguments: ["LeafTimer"], defaults: testDefaults, today: today)

        XCTAssertNil(testDefaults.data(forKey: "sessionStats"))
        XCTAssertFalse(testDefaults.bool(forKey: UserDefaultItem.hasSeenOnboarding.rawValue))
    }

    func testAutoStartFlagReadsLaunchArgument() {
        XCTAssertTrue(DebugStoreScreenshot.isAutoStartRequested(arguments: ["LeafTimer", "-AutoStart"]))
        XCTAssertFalse(DebugStoreScreenshot.isAutoStartRequested(arguments: ["LeafTimer"]))
    }
}
```

- [ ] **Step 2: テストファイルを test target に配線し、RED を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make add-file FILE=LeafTimerTests/DebugStoreScreenshotTests.swift TARGET=test`

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | /usr/bin/grep -E "cannot find 'DebugStoreScreenshot'|\*\* TEST (SUCCEEDED|FAILED) \*\*" | head -3`
Expected: `cannot find 'DebugStoreScreenshot' in scope` (コンパイルエラーで RED)

- [ ] **Step 3: 最小実装を書く**

`app/LeafTimer/Components/DebugStoreScreenshot.swift`:

```swift
#if DEBUG
import Foundation

/// Issue #161: ストア用スクショ撮影 (`make store-screenshots`) の起動引数フック。
/// simctl には tap も app コンテナの UserDefaults への確実な書き込み手段も無い
/// (`simctl spawn defaults write` はコンテナ外に書き、plist 直書きは cfprefsd に
/// 戻される — 2026-09-27 実測) ため、撮影用の状態はアプリ自身に作らせる。
enum DebugStoreScreenshot {
    static let seedArgument = "-SeedSampleStats"
    static let autoStartArgument = "-AutoStart"

    /// 過去 7 日 (today を含む) の件数と、見栄えのする streak / 累計の固定値。
    static func sampleStats(today: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> SessionStats {
        let counts = [3, 5, 2, 6, 4, 7, 4]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"

        var dailyCount: [String: Int] = [:]
        for (offset, count) in counts.enumerated() {
            let day = calendar.date(byAdding: .day, value: offset - (counts.count - 1), to: today)!
            dailyCount[formatter.string(from: day)] = count
        }
        return SessionStats(
            dailyCount: dailyCount,
            totalCount: 128,
            currentStreak: 12,
            longestStreak: 21,
            lastSessionDate: formatter.string(from: today)
        )
    }

    /// `-SeedSampleStats` がある時だけ、LocalSessionStatsRepository と同じキーに書き込む。
    /// オンボーディングも既読にして、タイマー画面の上に fullScreenCover が出ないようにする。
    static func seedIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        today: Date = Date()
    ) {
        guard arguments.contains(seedArgument),
              let data = try? JSONEncoder().encode(sampleStats(today: today)) else { return }
        defaults.set(data, forKey: "sessionStats")
        defaults.set(true, forKey: "statsMigrated")
        defaults.set(true, forKey: UserDefaultItem.hasSeenOnboarding.rawValue)
    }

    static func isAutoStartRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(autoStartArgument)
    }
}
#endif
```

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make add-file FILE=LeafTimer/Components/DebugStoreScreenshot.swift TARGET=app`

- [ ] **Step 4: アプリに配線する**

`app/LeafTimer/App/AppDelegate.swift` — `window = UIWindow()` の直後 (VM 生成より前) に追加:

```swift
#if DEBUG
        // Issue #161: ストア用スクショ撮影のサンプルデータ (起動引数がある時だけ)
        DebugStoreScreenshot.seedIfRequested()
#endif
```

`app/LeafTimer/View/TimerView.swift` — `timerContent` の `.onAppear` 内、`if settingViewModel.shouldShowOnboarding() { … }` の直後に追加:

```swift
#if DEBUG
                        // Issue #161: ストア用スクショの実行中画面 (simctl に tap が無いため)
                        if DebugStoreScreenshot.isAutoStartRequested(), !timerViewModel.executeState {
                            timerViewModel.onPressedTimerButton()
                        }
#endif
```

`app/LeafTimer/View/TimerView.swift` — `debugScreen(_:)` の `case "timePreview":` の前に追加:

```swift
        case "onboarding":
            OnboardingView {}
```

- [ ] **Step 5: GREEN を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | /usr/bin/grep -E "DebugStoreScreenshotTests.*(passed|failed)|Executed [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED) \*\*"`
Expected: DebugStoreScreenshotTests の 5 件が passed、`** TEST SUCCEEDED **`、総数は 199 + 5 = **204 tests** (2 skipped は既存)

- [ ] **Step 6: mutation で RED を実証する (ルール 8、テスト 5 件 : mutation 4 つ)**

各 mutation を 1 つずつ入れて `make unit-tests` を回し、期待する失敗を確認したら戻す:

| mutation (DebugStoreScreenshot.swift) | 期待する失敗 |
|---|---|
| `forKey: "sessionStats"` → `forKey: "sessionStatsX"` | `testSeedIsReadableByLocalSessionStatsRepository`, `testSeedFillsLastSevenDaysEndingToday` |
| `offset - (counts.count - 1)` → `offset - counts.count` | `testSeedIsReadableByLocalSessionStatsRepository` (lastSessionDate と dailyCount がずれる), `testSeedFillsLastSevenDaysEndingToday` |
| `defaults.set(true, forKey: UserDefaultItem.hasSeenOnboarding.rawValue)` を削除 | `testSeedMarksOnboardingSeen` |
| `guard arguments.contains(seedArgument),` → `guard true,` | `testSeedIsNotAppliedWithoutArgument` |

`testAutoStartFlagReadsLaunchArgument` は `isAutoStartRequested` を `return true` にして RED を確認する (5 件目)。

- [ ] **Step 7: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer/Components/DebugStoreScreenshot.swift app/LeafTimerTests/DebugStoreScreenshotTests.swift \
  app/LeafTimer/App/AppDelegate.swift app/LeafTimer/View/TimerView.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "feat(#161): ストア用スクショ撮影の DEBUG 起動引数フックを追加"
```

---

### Task 2: スクショ撮影・合成・検証スクリプトと make ターゲット

**Files (2026-09-27 に scratchpad で試作・実測済み。試作は既に下記パスに未 commit で置いてある):**
- Create: `app/store-screenshots/screens.json` (機種・ロケール・画面ごとの起動引数とコピー)
- Create: `app/bin/store-screenshot-compose.swift` (合成。`swiftc -O` で 1 回だけコンパイルして使う)
- Create: `app/bin/store-screenshots.rb` (撮影オーケストレーション)
- Create: `app/bin/store_screenshots_check.rb` (純粋ロジック) / `app/bin/store-screenshots-check.rb` (CLI) / `app/bin/test_store_screenshots_check.rb` (minitest) — ルール 33 の 2 層構成
- Modify: `app/Makefile` (`store-screenshots` ターゲット、`tests` チェーンに checker の unit test)

**Interfaces:**
- Consumes: Task 1 の起動引数
- Produces: `make store-screenshots` → `app/build/store-screenshots/final/<locale>/<device>/<screen id>.png` (20 枚)

- [ ] **Step 1: 試作ファイルの存在と中身を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer && git status --short app/bin app/store-screenshots`
Expected: 上記 6 ファイルが `??` で出る。無ければ停止して報告する (plan の前提が崩れている)。

- [ ] **Step 2: checker の unit test を実行する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_store_screenshots_check.rb 2>&1 | tail -1`
Expected: `7 runs, 8 assertions, 0 failures, 0 errors, 0 skips` (実測値。違ったら停止)

- [ ] **Step 3: checker の mutation を確認する (新規テスト 7 件 : mutation 6 つ、すべて実測済み)**

| mutation (`bin/store_screenshots_check.rb`) | 実測した結果 |
|---|---|
| `elsif actual != size` → `elsif false` | 1 failure (`test_off_by_one_size_is_reported`) |
| `(sizes.keys - expected.keys)…` の行を削除 | 1 failure (`test_unexpected_file_is_reported`) |
| `problems << "missing: #{path}"` → `nil` | 1 failure (`test_missing_file_is_reported`) |
| `problems << "not a PNG: #{path}"` → `nil` | 1 failure (`test_non_png_is_reported`) |
| PNG シグネチャ判定の `return nil unless …` → `nil` | 1 failure (`test_png_size_rejects_non_png`) |
| `unpack('NN')` → `unpack('nn')` | 1 failure (`test_png_size_reads_ihdr`) |
| `problems = []` → `problems = ['always']` | 5 failures (`test_complete_set_has_no_violations` を含む) |

各行を入れて `ruby bin/test_store_screenshots_check.rb | tail -1` を確認し、戻す。

- [ ] **Step 4: Makefile にターゲットを足す**

`app/Makefile` の `plan-docs-check:` ターゲットの後に追加 (レシピ行はタブ):

```make
# Issue #161: App Store 用スクショ (ja/en × iPhone 6.9" / iPad 13" × 5 画面) を
# 撮影 → 合成 → 寸法検証する。数分かかり Simulator を使うので tests チェーンには入れない。
store-screenshots:
	@ruby bin/store-screenshots.rb
	@ruby bin/store-screenshots-check.rb

# checker 自体の unit test は数十 ms なので tests チェーンで常時回す (#159 の教訓)。
store-screenshots-check-test:
	@echo "Running store-screenshots-check unit tests..."
	@ruby bin/test_store_screenshots_check.rb
```

`tests:` 行に `store-screenshots-check-test` を `gitignore-check` の後ろへ足す:

```make
tests: precheck cocoapods-lock-check localization-check dynamic-type-check plan-docs-check gitignore-check store-screenshots-check-test sort lint unit-tests
```

- [ ] **Step 5: `make store-screenshots` を通しで実行する**

所要は約 8.5 分 (試作の実測 514 秒: Debug ビルド + 2 機種 × 10 枚 × 起動待ち 6 秒)。Bash の 10 分上限に近いので `run_in_background: true` で流し、ログを `until /usr/bin/grep -qE "store-screenshots-check|❌" <log>; do sleep 15; done` で待つ。

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make store-screenshots > build/store-screenshots.log 2>&1`
Expected: ログ末尾に `✅ store-screenshots-check: 20 screenshot(s) match screens.json` (試作で実測済み)

補足: フック無しの試作では fresh install のためオンボーディングが 01-timer に被った。Task 1 の `-SeedSampleStats` が既読フラグを立てるので、ここでは被らないことを Task 3 で確認する。

- [ ] **Step 6: checker の RED を実ファイルで確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && sips -z 2867 1320 build/store-screenshots/final/ja/iphone/01-timer.png >/dev/null && ruby bin/store-screenshots-check.rb; echo "exit=$?"`
Expected: `wrong size: ja/iphone/01-timer.png is 1320x2867, expected 1320x2868` と `exit=1`。確認後に `make store-screenshots` を再実行して 20 枚を戻す。

- [ ] **Step 7: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/store-screenshots/screens.json app/bin/store-screenshot-compose.swift app/bin/store-screenshots.rb \
  app/bin/store_screenshots_check.rb app/bin/store-screenshots-check.rb app/bin/test_store_screenshots_check.rb app/Makefile
git commit -m "feat(#161): ストア用スクショの撮影・合成・寸法検証を make store-screenshots に"
```

---

### Task 3: 🛑 スクショの目視確認 (人の判断点)

**Files:** なし (必要ならコピーを `app/store-screenshots/screens.json` で修正)

- [ ] **Step 1: 4 セットの一覧画像を作ってユーザーに渡す**

ja / en × iphone / ipad の 4 セット (各 5 枚) を縮小して横に並べ、SendUserFile で送る。

- [ ] **Step 2: 目視チェック項目を自分で先に確認する**

| 画面 | 確認点 |
|---|---|
| 01-timer | 今日 4・連続 12 のバッジ、ダイアログ・オンボーディングが無い |
| 02-growing | STOP ボタン、残り時間が 05:00 未満、大きな木、通知許可ダイアログが無い |
| 03-history | 連続 12 日・最長 21 日・累計 128、過去 7 日の棒 |
| 04-settings | 広告バナーが写っていない |
| 05-onboarding | オンボーディング 1 枚目 |
| 全画面 | コピーがはみ出していない、ステータスバー 9:41、ロケールと UI 言語が一致 |

- [ ] **Step 3: AskUserQuestion で OK / コピー修正 / 画面差し替えを聞く**

修正が出たら `screens.json` を直して `make store-screenshots` → Step 1 に戻る。OK が出たら修正分を commit:

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/store-screenshots/screens.json
git commit -m "fix(#161): ストア用スクショのコピーを調整"
```
(修正なしなら commit しない)

---

### Task 4: What's New (`docs/RELEASE_v1.5.md`)

**Files:**
- Create: `docs/RELEASE_v1.5.md`

- [ ] **Step 1: 下書きを書く**

入力: 前回リリース PR #35 (2026-05-26) 以降の merged PR のうちユーザーに見える変更 (#53 #37 #41 #43 #121 #122 #123 #124 #96 #102 #107 #117 #115 #118 #87 #88 #91)。

```markdown
# LeafTimer v1.5 リリースノート

- 対象: MARKETING_VERSION 1.5 (公開中は 1.4)
- 入力元: PR #35 (2026-05-26) 以降の merged PR のうちユーザーに見える変更
- `asc-submission-prep` skill が「What's New」節を ASC の「このバージョンの最新情報」に使う

## What's New

### ja

・はじめての方向けのガイド画面を追加しました
・履歴画面で、連続日数・最長記録・過去 7 日の実績を確認できるようになりました
・アプリを閉じていてもタイマーが進み、作業と休憩の終わりを通知でお知らせします
・開始・停止ボタンに触覚フィードバックを追加しました
・VoiceOver と文字サイズの変更に対応しました
・「視差効果を減らす」がオンの時は、葉のアニメーションを止めるようにしました
・iPhone SE と iPad の画面レイアウトを改善しました
・タイマー開始時に、他のアプリで再生中の音楽が止まる問題を修正しました
・履歴の表示が 0 に戻ることがある問題を修正しました

### en

- New welcome guide for first-time users
- History screen: see your current streak, longest streak, and the last 7 days
- The timer keeps running in the background and notifies you when a work or break session ends
- Haptic feedback on the Start and Stop buttons
- VoiceOver and Dynamic Type support
- The leaf animation pauses when Reduce Motion is on
- Improved layouts on iPhone SE and iPad
- Fixed an issue where music from other apps stopped when the timer started
- Fixed an issue where the history sometimes reset to 0
```

- [ ] **Step 2: 絵文字と字数を検証する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer && ruby -e 's = File.read("docs/RELEASE_v1.5.md"); body = s[/## What.s New.*/m]; emoji = body.scan(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]/); ja = body[/### ja\n(.*?)### en/m, 1].strip; en = body[/### en\n(.*)/m, 1].strip; puts "emoji=#{emoji.size} ja=#{ja.size} en=#{en.size}"'`
Expected: `emoji=0`、ja / en とも 4000 未満

- [ ] **Step 3: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add docs/RELEASE_v1.5.md
git commit -m "docs(#161): v1.5 の What's New (ja/en) 下書き"
```

---

### Task 5: 後片付けの issue 起票と PR 作成

- [ ] **Step 1: fastlane 片付けの issue を起票する**

```bash
gh issue create --title "fastlane upload_metadata lane と fastlane/metadata を撤去する (#161 で Chrome 経路に一本化)" --label "cleanup,priority:low" --body "#161 で ASC 申請準備を Chrome 経路 (asc-submission-prep skill) に一本化した。fastlane は Apple ID + App 用パスワードでは deliver が Unauthorized になり (2.240.1 で実測)、API Key 運用もしない判断。upload_metadata lane / fastlane/metadata (中身は PLACEHOLDER) / SETUP.md の該当節 / .env.default.template の扱いを決めて撤去する。"
```

- [ ] **Step 2: `make tests` を通す**

Run (Bash timeout 600000): `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec make tests 2>&1 | /usr/bin/grep -E "\*\* TEST (SUCCEEDED|FAILED) \*\*|store-screenshots-check|Error [0-9]" `
Expected: `7 runs, 8 assertions, 0 failures` を含む checker 行と `** TEST SUCCEEDED **`、`Error` 行なし

- [ ] **Step 3: plan / spec を archive へ移す (ルール 44)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git mv docs/superpowers/plans/2026-09-27-issue-161-asc-submission-prep.md docs/superpowers/plans/archive/
git mv docs/superpowers/specs/2026-09-27-issue-161-asc-submission-prep.md docs/superpowers/specs/archive/
git commit -m "docs(#161): plan と spec を archive へ移動"
```

- [ ] **Step 4: PR を作る (merge はしない — ルール 22)**

`git fetch && gh pr list --state all --head feature/161-asc-submission-prep` で既存 PR が無いことを確認してから push → `gh pr create`。本文に「CI 受け入れはログ行 `store-screenshots-check` の unit test 行で確認」と書く (ルール 23)。

---

## PR 作成後 (コントローラが行う。本 plan のタスク外)

1. final review → CI のログ行確認 → merge (ルール 24)
2. `asc-submission-prep` skill の dry-run → 差分表 (1.5 作成 / What's New ja・en / スクショ 6.9"・13" × ja・en / ビルド) → 判断① → 書き込み → 読み戻し → 停止レポート
3. 実走で確定した不足分をグローバル skill に追記する (直前に SKILL.md の mtime を再確認)
