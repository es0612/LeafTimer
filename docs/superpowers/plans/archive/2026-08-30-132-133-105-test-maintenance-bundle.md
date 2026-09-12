# Issue #133 / #132 / #105 Test-Maintenance Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PR #134 の final / task review で後送になったテスト保守 3 件 (#133 Accessibility xit 2 件の復活 + 誤診断コメント訂正 / #132 toolbar テスト 3 件の中身検証化 + 残り時間テストの期待値独立化 / #105 `localized(_:locale:)` helper の 3 重複を 1 箇所へ集約) を 1 ブランチ 1 PR で完済する。

**Architecture:** 全てテストターゲット (`LeafTimerTests`) のみの変更で、本番コードは 1 行も触らない。#133/#132 は同じ 2 ファイル (`ModernTimerViewSpec.swift` / `TimerViewSpec.swift`) を編集するので Task 1 に束ねる。#105 は新規 Swift ファイル 2 つ (helper 本体 + helper 自身の RED 実証テスト) を test target に `make add-file` で配線する Task 2。Task 1 と Task 2 はファイルが重ならず独立 — ルール 20 に従い **1 subagent に両 Task を束ねて dispatch** し、レビューは最後に 2 段階 (spec compliance → code quality) でまとめて行う。

**Tech Stack:** Swift 5.9 / Quick + Nimble + ViewInspector 0.10.2 (CocoaPods) / XCTest / make (`make add-file` = `app/bin/add-to-target.rb` ラッパー、#130 で整備)

**Spec:** 本 plan が spec を兼ねる。要求の原文は GitHub Issue #133 / #132 / #105 本文 (`gh issue view <N>`)。

## Global Constraints

- ビルド/テストは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests` 形式 (cd を同一コマンドに前置)。成否は exit code でなく `** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` / `Error 6x` の不在で判定する (CLAUDE.md ルール 1)。`Mach error -308` / `Lost connection to testmanagerd` は Simulator 偽 FAIL — `xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライ。
- `make unit-tests` / `xcodebuild ... test` を含む Bash 呼び出しは timeout 600000 (10 分) を指定する (ルール 16)。
- **本番コード (`app/LeafTimer/`) は変更禁止。** 変更は `app/LeafTimerTests/` と `app/LeafTimer.xcodeproj/project.pbxproj` (Task 2 の配線差分) のみ。
- 新規 Swift ファイルの配線は手編集せず `make add-file FILE=<project相対パス> TARGET=test` を使い、**pbxproj 差分をそのファイルを追加する commit に同梱**する (ルール 28)。TARGET は必ず `test`。
- SwiftLint: 新規コードは `.isEmpty` を使う (ルール 35)。`make tests` の lint が通ること。
- 各 Task 完了ごとに commit。メッセージは `test(#133/#132): ...` / `test(#105): ...` 形式。
- PR merge は plan のスコープ外 (ルール 22)。Task 3 の PR 作成で終了し、merge はレビュー通過後にコントローラがルール 24 のチェーンで行う。
- Subagent は最終報告の全文を SendMessage で main へ送ってから idle になる (ルール 15)。
- 「到達不能」と判断する前に、必ず **失敗した実際のエラーメッセージ** (`InspectionError` の文言) を報告に残す (ルール 9)。推測で諦めない。

---

### Task 0: ブランチ作成 + plan commit (コントローラが実施)

**Files:**
- Create: `docs/superpowers/plans/2026-08-30-132-133-105-test-maintenance-bundle.md` (本ファイル)

- [ ] **Step 1: ブランチ作成と plan の first commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git checkout -b feature/132-133-105-test-maintenance-bundle && git add docs/superpowers/plans/2026-08-30-132-133-105-test-maintenance-bundle.md && git commit -m "docs(#132/#133/#105): テスト保守バンドルの実装 plan を追加"
```

---

### Task 1: #133 + #132 — ModernTimerViewSpec / TimerViewSpec の ViewInspector テスト強化

**Files:**
- Modify: `app/LeafTimerTests/ModernTimerViewSpec.swift` (toolbar 2 テスト: 90-110 行付近 / Accessibility 節の xit 2 件: 178-200 行付近)
- Modify: `app/LeafTimerTests/TimerViewSpec.swift` (残り時間テスト: 29-37 行付近 / toolbar テスト: 45-52 行付近)
- Read only: `app/LeafTimer/View/TimerView.swift` (現構造の確認用。変更禁止)

**Interfaces:**
- Consumes: なし
- Produces: PR 本文に載せる **disposition 表 (6 行)** — 各テストについて「強化後の形 / 到達不能なら実エラー文言と代替案」

**前提知識 (implementer は最初に `app/LeafTimer/View/TimerView.swift` を Read すること):**

現在の `TimerView.timerContent` の構造:

```text
NavigationStack
└ GeometryReader
  └ ZStack
    ├ [0] 背景 Color
    ├ [1] leafLayer (GIFView)
    └ [2] VStack                       ← .navigationTitle / .toolbar / .onAppear はここに付く
        ├ Text(getDisplayedTime())     ← .accessibilityLabel("timer.a11y.remaining_time") / .accessibilityValue(...)
        ├ Button { CircleButton }      ← .accessibilityLabel(getAccessibilityLabel())
        └ statChipLayout { StatChip ×2 }
    .toolbar {
        ToolbarItem(.navigationBarLeading)  [0] Button { Image("arrow.counterclockwise") }
        ToolbarItem(.navigationBarTrailing) [1] NavigationLink(HistoryView) { Image("chart.bar.fill") }
        ToolbarItem(.navigationBarTrailing) [2] NavigationLink(EnhancedSettingView) { Image("gearshape.fill") }
    }
```

ViewInspector 0.10.2 で使える API (GitHub の 0.10.2 タグ `Sources/ViewInspector/SwiftUI/Toolbar.swift` / `Image.swift` / `Modifiers/AccessibilityModifiers.swift` で確認済み):

- `.toolbar()` → `InspectableView<ViewType.Toolbar>`; `.item(i)` → `InspectableView<ViewType.Toolbar.Item>` (`SingleViewContent` なので `.button()` / `.navigationLink()` / `.find(...)` が使える); `ViewType.Toolbar` は `SupplementaryChildren` なので `find()` は toolbar item の中まで降りる。
- `Image` → `.actualImage().name()` で `Image(systemName:)` の名前文字列が取れる。
- 任意の view → `.accessibilityLabel()` / `.accessibilityValue()` が `InspectableView<ViewType.Text>` を返す (`.string()` で比較)。

**判定ルール:** 以下の Step に書いた「第 1 案」で GREEN になればそれを採用。第 1 案が `InspectionError` で落ちたら、エラー文言を控えて「第 2 案」を試す。第 2 案も落ちたら、テストは現状維持 (`expect(toolbar) != nil` 等) のまま、**両案の実エラー文言を disposition 表に記録**して報告する。xit のまま残す・silent に消すは禁止。

- [ ] **Step 1: TimerView.swift を Read して上の構造図と一致することを確認する**

toolbar の ToolbarItem 順序 (leading reset → trailing history → trailing settings) と systemName 3 つを確認する。ずれていたら本 plan の構造図でなく実コードを正とする。

- [ ] **Step 2: (#133) Accessibility 節の xit 2 件を find() + accessibilityLabel 検証で復活し、コメントを訂正する**

`ModernTimerViewSpec.swift` の `describe("Accessibility")` ブロック全体を以下に置き換える:

```swift
            describe("Accessibility") {
                // Issue #133: 旧コメントの「vStack(1).text(0) の位置に GIFView が存在するためパス不一致」は
                // #129 の調査で反証済み。実際の原因は (a) navigationStack 直下の GeometryReader を
                // パスに含めていなかったこと、(b) ZStack の子が [背景, leafLayer, VStack] の順で
                // 主要 VStack が index 2 (旧パスは 1) だったこと。index パスをやめ find() で復活する。
                it("has accessibility labels for timer display") {
                    let timeText = try timerView.body.inspect()
                        .find(text: timerViewModel.getDisplayedTime())

                    let label = try timeText.accessibilityLabel().string()
                    expect(label) == NSLocalizedString("timer.a11y.remaining_time", comment: "")
                }

                // Issue #133: 同上 (旧コメントの vStack(1).view(CircleButton, 1) 不一致も同じ原因)
                it("has accessibility labels for controls") {
                    let button = try timerView.body.inspect().find(ViewType.Button.self, where: { candidate in
                        (try? candidate.find(CircleButton.self)) != nil
                    })

                    let label = try button.accessibilityLabel().string()
                    expect(label) == timerViewModel.getAccessibilityLabel()
                }
            }
```

**第 2 案** (`.accessibilityLabel()` が `InspectionError` で落ちる場合のみ): `accessibilityLabel()` の 2 行を外し `expect(timeText) != nil` / `expect(button) != nil` にする。ただしその場合、既存の "displays timer with modern typography" / "start/stop control is a real Button wrapping CircleButton" と実質重複するので、**第 2 案を採る時はこの 2 テストを削除し disposition 表に「重複のため削除 + 実エラー文言」を書く**。

- [ ] **Step 3: (#132 M-1) ModernTimerViewSpec の toolbar 2 テストを中身検証に書き換える**

`describe("Modern Controls")` 内の `it("has reset button in toolbar")` と `it("has settings navigation link in toolbar")` を以下に置き換える:

```swift
                // Issue #132: expect(toolbar) != nil は ToolbarItem を全部消しても pass する。
                // item(0) の中の SF Symbol 名まで検証する。
                it("has reset button in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    let resetIcon = try toolbar.item(0).find(ViewType.Image.self).actualImage().name()
                    expect(resetIcon) == "arrow.counterclockwise"
                }

                // Issue #132: 同上。settings は 3 番目の ToolbarItem (index 2)
                it("has settings navigation link in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    let settingsItem = try toolbar.item(2)
                    expect(try settingsItem.navigationLink()) != nil
                    let settingsIcon = try settingsItem.find(ViewType.Image.self).actualImage().name()
                    expect(settingsIcon) == "gearshape.fill"
                }
```

**第 2 案** (`toolbar.item(i)` が `viewNotFound` で落ちる場合): root からの `find` で toolbar 内を探索する:

```swift
                it("has reset button in toolbar") {
                    let resetIcon = try timerView.body.inspect().find(ViewType.Image.self, where: { image in
                        (try? image.actualImage().name()) == "arrow.counterclockwise"
                    })
                    expect(resetIcon) != nil
                }

                it("has settings navigation link in toolbar") {
                    let settingsIcon = try timerView.body.inspect().find(ViewType.Image.self, where: { image in
                        (try? image.actualImage().name()) == "gearshape.fill"
                    })
                    expect(settingsIcon) != nil
                }
```

- [ ] **Step 4: (#132 M-1) TimerViewSpec の toolbar テストを 3 item の存在検証に書き換える**

`TimerViewSpec.swift` の `it("displayed navigation bar button item")` を以下に置き換える:

```swift
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
```

第 2 案は Step 3 と同じ root `find(ViewType.Image.self, where:)` 形式 (3 アイコンそれぞれ)。

- [ ] **Step 5: (#132 M-2) TimerViewSpec の残り時間テストを独立した期待値にする**

`TimerViewSpec.swift` の `it("displayed remaining time.")` とその直前のコメント 2 行を以下に置き換える:

```swift
            // Issue #132: find(text: getDisplayedTime()) を getDisplayedTime() と比較するのは同語反復だった。
            // currentTimeSecond を固定して UserDefaults 非依存の定数 "20:00" を期待値にする。
            it("displayed remaining time.") {
                timerViewModel.currentTimeSecond = 1200

                let textViewString = try timerView.body
                    .inspect().find(text: "20:00").string()

                expect(textViewString) == "20:00"
            }
```

- [ ] **Step 6: 対象 2 spec だけを実行して GREEN を確認する (第 1 案 → 落ちたら第 2 案)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test -only-testing:LeafTimerTests/ModernTimerViewSpec -only-testing:LeafTimerTests/TimerViewSpec 2>&1 | grep -E "Test Case .* (passed|failed)|error:|InspectionError|\*\* TEST (SUCCEEDED|FAILED) \*\*" | head -60
```

(Bash timeout 600000)。Expected: 対象テストが全て `passed` かつ `** TEST SUCCEEDED **`。`failed` があれば出力の `error:` 行 (ViewInspector の文言) を控えて該当 Step の第 2 案に切り替え、再実行する。

- [ ] **Step 7: 検証が「本物」であることを RED で実証する (commit しない一時変更)**

ルール 8: 強化したテストが本当に中身を見ているか、意図的に壊して確認する。`ModernTimerViewSpec.swift` の Step 3 で書いた `expect(resetIcon) == "arrow.counterclockwise"` を一時的に `== "xmark"` に変え、Step 6 のコマンドを再実行して **その 1 件だけ `failed`** になることを確認したら、元に戻す。同様に Step 5 の `find(text: "20:00")` を `"21:00"` に変えて failed を確認し、元に戻す。報告に「壊した内容 → failed になったテスト名」を 2 件とも書く。

- [ ] **Step 8: disposition 表を完成させる (6 行、空欄なし)**

| ファイル | テスト | 採用案 | 備考 (第 2 案なら第 1 案の実エラー文言) |
| --- | --- | --- | --- |
| ModernTimerViewSpec | has accessibility labels for timer display | | |
| ModernTimerViewSpec | has accessibility labels for controls | | |
| ModernTimerViewSpec | has reset button in toolbar | | |
| ModernTimerViewSpec | has settings navigation link in toolbar | | |
| TimerViewSpec | displayed navigation bar button item | | |
| TimerViewSpec | displayed remaining time. | | |

- [ ] **Step 9: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimerTests/ModernTimerViewSpec.swift app/LeafTimerTests/TimerViewSpec.swift && git commit -m "test(#133/#132): Accessibility xit 2 件を find() で復活し toolbar / 残り時間テストを中身検証化

- #133: xit の誤診断コメント (GIFView 起因) を GeometryReader 欠落 + vStack index 違いに訂正
- #132 M-1: toolbar 3 テストを ToolbarItem の SF Symbol 名検証へ
- #132 M-2: 残り時間テストを currentTimeSecond=1200 → \"20:00\" の独立期待値へ"
```

---

### Task 2: #105 — `localized(_:locale:)` helper を LocalizationTestSupport に集約

**Files:**
- Create: `app/LeafTimerTests/LocalizationTestSupport.swift` (XCTestCase extension)
- Create: `app/LeafTimerTests/LocalizationTestSupportTests.swift` (helper 自身の sentinel 動作テスト)
- Modify: `app/LeafTimerTests/SettingsLocalizationTests.swift:38-47` (private helper 削除)
- Modify: `app/LeafTimerTests/StatLocalizationTests.swift:7-16` (同上)
- Modify: `app/LeafTimerTests/OnboardingLocalizationTests.swift:6-15` (同上)
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (`make add-file` による自動配線。手編集禁止)

**Interfaces:**
- Produces: `extension XCTestCase { func localized(_ key: String, locale: String) -> String }` — 3 つの Localization テストはこの extension メソッドを **そのままの呼び出し形** (`localized("...", locale: "ja")`) で使う。挙動は既存 private helper とバイト単位で同一 (lproj 欠落時 `XCTFail` + `"<<missing>>"`、キー欠落時 `"<<missing>>"`)。

- [ ] **Step 1: helper の sentinel 動作テストを先に書く (RED)**

`app/LeafTimerTests/LocalizationTestSupportTests.swift` を作成:

```swift
// app/LeafTimerTests/LocalizationTestSupportTests.swift
import XCTest
@testable import LeafTimer

/// Issue #105: 3 ファイルに重複していた localized(_:locale:) を LocalizationTestSupport に集約した。
/// PR #96 で片方だけ直して他が取り残された drift の再発防止として、helper 自身の sentinel 挙動を固定する。
final class LocalizationTestSupportTests: XCTestCase {

    func testExistingKeyResolvesInBothLocales() {
        XCTAssertNotEqual(localized("timer.title", locale: "ja"), "<<missing>>")
        XCTAssertNotEqual(localized("timer.title", locale: "en"), "<<missing>>")
    }

    func testMissingKeyReturnsSentinel() {
        XCTAssertEqual(localized("definitely.not.a.real.key", locale: "ja"), "<<missing>>")
        XCTAssertEqual(localized("definitely.not.a.real.key", locale: "en"), "<<missing>>")
    }

    func testMissingLocaleReturnsSentinelAndFails() {
        // lproj が丸ごと無い場合は XCTFail + "<<missing>>" (PR #96 で塞いだ抜け穴の固定)
        XCTExpectFailure("zz.lproj は存在しないので XCTFail が記録される")
        XCTAssertEqual(localized("timer.title", locale: "zz"), "<<missing>>")
    }
}
```

`timer.title` は `TimerView.swift` の `navigationTitle` で使われている実在キー (ja/en 両方の `Localizable.strings` にある)。

- [ ] **Step 2: 2 つの新規ファイルを test target に配線する**

先に helper 本体を作成 (`app/LeafTimerTests/LocalizationTestSupport.swift`):

```swift
// app/LeafTimerTests/LocalizationTestSupport.swift
import XCTest
@testable import LeafTimer

/// Issue #105: Settings / Stat / Onboarding の Localization テストで重複していた helper の集約先。
extension XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    /// - lproj が見つからない: XCTFail を記録し "<<missing>>" を返す (PR #96 の抜け穴修正を維持)
    /// - key が無い: "<<missing>>" を返す
    func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            XCTFail("\(locale).lproj が見つからない")
            return "<<missing>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }
}
```

次に配線 (ルール 28。sort + precheck まで自動実行される):

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make add-file FILE=LeafTimerTests/LocalizationTestSupport.swift TARGET=test && make add-file FILE=LeafTimerTests/LocalizationTestSupportTests.swift TARGET=test && git -C /Users/shinya/workspace/claude/LeafTimer status --short
```

Expected: `project.pbxproj` が modified、2 つの新規 .swift が untracked。precheck が orphan を報告しない。

- [ ] **Step 3: この時点でビルドが「重複定義」で RED になることを確認する**

3 ファイルの private helper がまだ残っているので、`private func localized` と extension の `localized` が同名で存在する。Swift ではクラス内 private メソッドが extension メソッドを shadow するためコンパイルは通る可能性が高い — **この Step は「通るか落ちるか」の観測のみ** で、どちらでも次に進む:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test -only-testing:LeafTimerTests/LocalizationTestSupportTests 2>&1 | grep -E "Test Case .* (passed|failed)|error:|\*\* TEST (SUCCEEDED|FAILED) \*\*" | head -20
```

(Bash timeout 600000)。Expected: `LocalizationTestSupportTests` の 3 テストが `passed`。`testMissingLocaleReturnsSentinelAndFails` は `XCTExpectFailure` で包んでいるので passed 扱いになる。もし failed なら、XCTFail の記録が extension 経由でも self に載ることを前提にしているので、失敗出力を控えて報告する (その場合の代替: `XCTExpectFailure` を外し、テスト名を `testMissingLocaleReturnsSentinel` にして `XCTAssertEqual` のみ残す — XCTFail が出て failed になるならそれ自体が「lproj 欠落を検出できる」証拠なので、そのテストは削除して報告に理由を書く)。

- [ ] **Step 4: 3 ファイルから private helper を削除する**

`SettingsLocalizationTests.swift` / `StatLocalizationTests.swift` / `OnboardingLocalizationTests.swift` それぞれから、以下のブロック (doc コメント 1 行 + `private func localized` 9 行 + 直後の空行) を削除する。**呼び出し側は 1 文字も変えない** (extension の同名メソッドに解決される):

```swift
    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            XCTFail("\(locale).lproj が見つからない")
            return "<<missing>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

```

`SettingsLocalizationTests.swift` の class doc コメント「パターンは StatLocalizationTests を踏襲」は「helper は LocalizationTestSupport を参照」に書き換える。

削除後の確認:

```bash
grep -rn "func localized" /Users/shinya/workspace/claude/LeafTimer/app/LeafTimerTests/
```

Expected: `LocalizationTestSupport.swift` の 1 件のみ。

- [ ] **Step 5: 4 つの Localization テストを実行して GREEN を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test -only-testing:LeafTimerTests/SettingsLocalizationTests -only-testing:LeafTimerTests/StatLocalizationTests -only-testing:LeafTimerTests/OnboardingLocalizationTests -only-testing:LeafTimerTests/LocalizationTestSupportTests 2>&1 | grep -E "Test Case .* (passed|failed)|error:|\*\* TEST (SUCCEEDED|FAILED) \*\*" | head -40
```

(Bash timeout 600000)。Expected: 全て `passed` + `** TEST SUCCEEDED **`。

- [ ] **Step 6: 集約 helper が drift を検出できることを RED で実証する (commit しない一時変更)**

ルール 8: `LocalizationTestSupport.swift` の `value: "<<missing>>"` を一時的に `value: "<<gone>>"` に変えて Step 5 を再実行し、`testMissingKeyReturnsSentinel` と `SettingsLocalizationTests` / `OnboardingLocalizationTests` の各 `XCTAssertNotEqual` 系が **同時に** failed になる (= 1 箇所の変更が全ファイルへ波及する、PR #96 の「片方だけ直る」が起きない) ことを確認して元に戻す。報告に failed になったテスト名を列挙する。

- [ ] **Step 7: フル suite + precheck + lint を通す**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | grep -E "\*\* TEST (SUCCEEDED|FAILED) \*\*|Error 6|No rule to make target|orphan|warning:.*swiftlint|error:" | head -20
```

(Bash timeout 600000)。Expected: `** TEST SUCCEEDED **` が出て、`** TEST FAILED **` / `Error 6` / `No rule to make target` / orphan 報告が無い。

- [ ] **Step 8: Commit (pbxproj 差分を同梱)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimerTests/LocalizationTestSupport.swift app/LeafTimerTests/LocalizationTestSupportTests.swift app/LeafTimerTests/SettingsLocalizationTests.swift app/LeafTimerTests/StatLocalizationTests.swift app/LeafTimerTests/OnboardingLocalizationTests.swift app/LeafTimer.xcodeproj/project.pbxproj && git commit -m "test(#105): localized(_:locale:) helper を LocalizationTestSupport に集約

3 つの Localization テストに private func としてコピーされていた helper を
XCTestCase extension 1 箇所へ集約し、helper 自身の sentinel 挙動テストを追加。
PR #96 で起きた「片方だけ直して他が取り残される」drift の再発防止。"
```

---

### Task 3: PR 作成 (merge はしない)

**Files:** なし (git / gh 操作のみ)

- [ ] **Step 1: 既存 PR の有無を確認してから push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/132-133-105-test-maintenance-bundle && git push -u origin feature/132-133-105-test-maintenance-bundle
```

Expected: `gh pr list` が空 (既存 PR なし)。

- [ ] **Step 2: PR 作成**

本文には Task 1 Step 8 の disposition 表と、Task 1 Step 7 / Task 2 Step 6 の RED 実証結果 (壊した内容 → failed テスト名) を必ず載せる。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create --title "test: #133/#132/#105 テスト保守バンドル (Accessibility xit 復活 / toolbar 中身検証 / localized helper 集約)" --body "$(cat <<'EOF'
## 概要
PR #134 の後送 3 件をテストターゲットのみの変更で完済。本番コード変更なし。

- #133: ModernTimerViewSpec Accessibility 節の xit 2 件を find() + accessibilityLabel 検証で復活。旧 xit コメントの誤診断 (GIFView 起因) を GeometryReader 欠落 + vStack index 違いに訂正。
- #132 M-1: toolbar 3 テストを ToolbarItem の SF Symbol 名検証へ (ToolbarItem を消すと fail する)。
- #132 M-2: 残り時間テストを currentTimeSecond=1200 → "20:00" の独立期待値へ。
- #105: `localized(_:locale:)` を `LocalizationTestSupport.swift` (XCTestCase extension) に集約し、sentinel 挙動テストを追加。`make add-file TARGET=test` で配線。

## disposition 表 (#133/#132)
(Task 1 Step 8 の表をここに貼る)

## RED 実証
(Task 1 Step 7 / Task 2 Step 6 の結果をここに貼る)

## 検証
- `make tests`: `** TEST SUCCEEDED **` / precheck orphan なし / lint 通過

Closes #133
Closes #132
Closes #105

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: PR URL と disposition 表を最終報告に含めて SendMessage で main へ送る**

---

## Self-Review 済み事項

- **Spec coverage:** #133 (xit 2 件復活 + コメント訂正) → Task 1 Step 2。#132 M-1 (3 toolbar テスト) → Task 1 Step 3-4。#132 M-2 (残り時間) → Task 1 Step 5。#105 (集約 + 新規ファイル配線) → Task 2。#132 本文の N-1 (`make add-file` が pbxproj 全体を再シリアライズする件) は本 plan のスコープ外 — Task 2 Step 2 の `git status` で pbxproj 差分が想定外に大きければ報告のみ (修正しない)。
- **Placeholder scan:** disposition 表と RED 実証の「ここに貼る」は implementer が実測値で埋める欄 (実測前に埋められない) であり、コード・手順の placeholder ではない。
- **Type consistency:** Task 2 の `localized(_ key: String, locale: String) -> String` は 3 ファイルの既存呼び出し形と同一シグネチャ。Task 1 の `getAccessibilityLabel()` / `getDisplayedTime()` / `currentTimeSecond` は `TimerView.swift` で使われている実在 API。
- **ルール 7 (実在確認):** `make add-file` は `app/Makefile:37`、ViewInspector API は GitHub 0.10.2 タグの source、`timer.title` / 3 つの systemName は `TimerView.swift` で確認済み。
