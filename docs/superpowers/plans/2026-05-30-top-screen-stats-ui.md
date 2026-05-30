# トップ画面ステータス表示の刷新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** トップ画面下部の「Today / Streak」表示を、🔥emoji 入りベタテキストから SF Symbol アイコン付きの `.ultraThinMaterial` ピル2つ（`StatChip`）に刷新する。

**Architecture:** 純表示の再利用コンポーネント `StatChip` を新設し、`TimerView` の単一 `Text` を2つの `StatChip` を並べた `HStack` に置換。ViewModel・Repository は変更しない（既存 `todaysCount`/`currentStreak` を読むだけ）。ローカライズは 🔥emoji 入りの旧キーを削除し、アイコン前提の短い2キーに置換。

**Tech Stack:** SwiftUI (iOS 16+), MVVM, CocoaPods (`LeafTimer.xcworkspace`), Quick/Nimble + XCTest, SwiftLint, `xcodeproj` gem (`bin/add-to-target.rb`)。

**Design doc:** `docs/superpowers/specs/2026-05-30-top-screen-stats-ui-design.md`

---

## Preconditions（着手前に確認）

- 作業ブランチ `feature/39-top-screen-stats-ui` 上にいること（`git branch --show-current`）。
- 依存解決済みであること。`app/Pods/` が無ければ `cd app && make install`（`pod install`）。
- テスト用 Simulator が利用可能なこと。`xcrun simctl list devices available | grep -i "iPhone 17"` でヒットすること（Makefile は `iPhone 17, OS=latest` を hardcode）。無ければ利用可能な機種名に読み替える。
- `ruby bin/add-to-target.rb` が `cannot load such file -- xcodeproj` で失敗する場合は `gem install xcodeproj` を実行。
- すべての `xcodebuild`/`make unit-tests` 実行は Bash の `timeout` を `600000`（10分）に設定する（simulator boot + build + test に数分かかるため）。

---

## File Structure

- **Create** `app/LeafTimer/View/Elements/StatChip.swift` — 再利用可能な角丸ピル表示コンポーネント（純表示・状態なし）。`CircleButton`/`GIFView` と同階層の live components 置き場。
- **Create** `app/LeafTimerTests/StatLocalizationTests.swift` — 新ローカライズキーの ja/en 整形を検証する XCTest。
- **Modify** `app/LeafTimer/App/ja.lproj/Localizable.strings` — 旧キー削除 + 新キュー2つ追加。
- **Modify** `app/LeafTimer/App/en.lproj/Localizable.strings` — 同上。
- **Modify** `app/LeafTimer/View/TimerView.swift`（65–74行）— `Text` を `HStack { StatChip; StatChip }` に置換。
- **Modify** `app/LeafTimer.xcodeproj/project.pbxproj` — 新規2ファイルの target 追加 + `make sort` で正規化（add-to-target.rb が自動更新）。

---

## Task 1: ローカライズキー追加 + localization テスト (TDD)

**Files:**
- Create: `app/LeafTimerTests/StatLocalizationTests.swift`
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings`, `app/LeafTimer/App/en.lproj/Localizable.strings`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj`（add-to-target + sort）

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/StatLocalizationTests.swift` を新規作成:

```swift
// app/LeafTimerTests/StatLocalizationTests.swift
import XCTest
@testable import LeafTimer

final class StatLocalizationTests: XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return "<<missing \(locale).lproj>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

    func testTodayChipJapanese() {
        XCTAssertEqual(String(format: localized("timer.stat.today", locale: "ja"), 3), "今日 3")
    }

    func testTodayChipEnglish() {
        XCTAssertEqual(String(format: localized("timer.stat.today", locale: "en"), 3), "Today 3")
    }

    func testStreakChipJapanese() {
        XCTAssertEqual(String(format: localized("timer.stat.streak", locale: "ja"), 5), "連続 5")
    }

    func testStreakChipEnglish() {
        XCTAssertEqual(String(format: localized("timer.stat.streak", locale: "en"), 5), "Streak 5")
    }

    func testNoFireEmojiInTopScreenStrings() {
        XCTAssertFalse(localized("timer.stat.today", locale: "ja").contains("🔥"))
        XCTAssertFalse(localized("timer.stat.streak", locale: "ja").contains("🔥"))
        XCTAssertFalse(localized("timer.stat.streak", locale: "en").contains("🔥"))
    }
}
```

- [ ] **Step 2: テストファイルを LeafTimerTests target に追加し pbxproj を正規化**

Run:
```bash
cd app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/StatLocalizationTests.swift LeafTimerTests LeafTimerTests
make sort
```
Expected: エラーなく完了（add-to-target は冪等）。`git status` に `project.pbxproj` と新規テストが出る。

- [ ] **Step 3: テストを実行して失敗を確認**

Run（timeout 600000）:
```bash
cd app && make unit-tests 2>&1 | tee /tmp/t1.log; echo "exit=${PIPESTATUS[0]}"
```
Expected: `StatLocalizationTests` の4ケースが FAIL（キー未定義のため `localized(...)` が `<<missing>>` を返し、整形結果が期待値と不一致）。`exit` が 0 以外。
（注: `${PIPESTATUS[0]}` で `make` の真の exit code を確認すること。`| tee` の 0 に隠さない — CLAUDE.md の教訓 Issue #9）

- [ ] **Step 4: ja/en に新キーを追加**

`app/LeafTimer/App/ja.lproj/Localizable.strings` の `"timer.todays_count" = "今日のポモドーロ数：";` の直後に追記:
```
"timer.stat.today" = "今日 %d";
"timer.stat.streak" = "連続 %d";
```

`app/LeafTimer/App/en.lproj/Localizable.strings` の `"timer.todays_count" = "Today's Pomodoros: ";` の直後に追記:
```
"timer.stat.today" = "Today %d";
"timer.stat.streak" = "Streak %d";
```

（この時点では旧キー `timer.todays_count_with_streak` は残す。TimerView がまだ使用中で、アプリは現状動作を維持する。）

- [ ] **Step 5: テストを実行して成功を確認**

Run（timeout 600000）:
```bash
cd app && make unit-tests 2>&1 | tee /tmp/t1b.log; echo "exit=${PIPESTATUS[0]}"
```
Expected: 全テスト PASS、`exit=0`。

- [ ] **Step 6: コミット**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimerTests/StatLocalizationTests.swift \
        app/LeafTimer/App/ja.lproj/Localizable.strings \
        app/LeafTimer/App/en.lproj/Localizable.strings \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "test(timer): トップ画面ステータス用ローカライズキーを追加 (#39)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: StatChip コンポーネント新設

**Files:**
- Create: `app/LeafTimer/View/Elements/StatChip.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj`（add-to-target + sort）

- [ ] **Step 1: StatChip.swift を作成**

`app/LeafTimer/View/Elements/StatChip.swift`:

```swift
import SwiftUI

/// トップ画面の「今日 / 連続」などを表示する角丸ピル。
/// 背景は `.ultraThinMaterial` で work/break × light/dark の全状態に自動適応する。
/// 純表示コンポーネント（内部状態を持たない）。
struct StatChip: View {
    let systemImage: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct StatChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 10) {
            StatChip(systemImage: "leaf.fill", tint: .green, text: "今日 3")
            StatChip(systemImage: "flame.fill", tint: .orange, text: "連続 5")
        }
        .padding(40)
        .background(
            LinearGradient(
                colors: [.green.opacity(0.35), .green.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
```

- [ ] **Step 2: StatChip を LeafTimer target に追加し pbxproj を正規化**

Run:
```bash
cd app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/View/Elements/StatChip.swift LeafTimer LeafTimer/View/Elements
make sort
```
Expected: エラーなく完了。

- [ ] **Step 3: ビルドが通ることを確認**

Run（timeout 600000）:
```bash
cd app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tee /tmp/t2.log; echo "exit=${PIPESTATUS[0]}"
```
Expected: `BUILD SUCCEEDED`、`exit=0`。

- [ ] **Step 4: コミット**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer/View/Elements/StatChip.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "feat(timer): StatChip ピルコンポーネントを追加 (#39)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: TimerView 置換 + 旧キー削除 + 検証

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift`（65–74行）
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings`, `app/LeafTimer/App/en.lproj/Localizable.strings`（旧キー削除）

- [ ] **Step 1: TimerView の streak Text を StatChip 2つに置換**

`app/LeafTimer/View/TimerView.swift` の以下のブロック（65–74行）:

```swift
                    Text(
                        String(
                            format: NSLocalizedString("timer.todays_count_with_streak", comment: "Today count and streak"),
                            timerViewModel.todaysCount,
                            timerViewModel.currentStreak
                        )
                    )
                        .foregroundColor(.secondary.opacity(0.9))
                        .padding()
                        .padding(.top, 20)
```

を、次に置換:

```swift
                    HStack(spacing: 10) {
                        StatChip(
                            systemImage: "leaf.fill",
                            tint: .green,
                            text: String(
                                format: NSLocalizedString("timer.stat.today", comment: "Today's pomodoro count"),
                                timerViewModel.todaysCount
                            )
                        )
                        StatChip(
                            systemImage: "flame.fill",
                            tint: .orange,
                            text: String(
                                format: NSLocalizedString("timer.stat.streak", comment: "Current streak"),
                                timerViewModel.currentStreak
                            )
                        )
                    }
                    .padding()
                    .padding(.top, 20)
```

- [ ] **Step 2: 旧キー `timer.todays_count_with_streak` を削除**

`app/LeafTimer/App/ja.lproj/Localizable.strings` から次の行を削除:
```
"timer.todays_count_with_streak" = "今日 %d 回 ・ 🔥 Streak %d";
```
`app/LeafTimer/App/en.lproj/Localizable.strings` から次の行を削除:
```
"timer.todays_count_with_streak" = "Today %d · 🔥 Streak %d";
```

- [ ] **Step 3: ビルド + 全ユニットテスト実行**

Run（timeout 600000）:
```bash
cd app && make unit-tests 2>&1 | tee /tmp/t3.log; echo "exit=${PIPESTATUS[0]}"
```
Expected: 全テスト PASS（`StatLocalizationTests` 含む）、`exit=0`。`grep -i "error\|FAILED\|Error 6" /tmp/t3.log` で見落としチェック。

- [ ] **Step 4: SwiftLint 確認**

Run:
```bash
cd app && make lint 2>&1 | tail -20; echo "exit=${PIPESTATUS[0]}"
```
Expected: 新規ファイルに violation なし（`empty_count` 等の組み込みルールに注意 — CLAUDE.md 教訓）。

- [ ] **Step 5: Simulator で目視検証（4状態 × ja/en）**

`ios-simulator-app-verification` / `ios-simulator-locale-testing` skill を用い、トップ画面を以下の組み合わせでスクリーンショット取得し、チップが可読か確認:
- work × light / work × dark / break × light / break × dark（break は休憩遷移 or UserDefaults で誘導）
- ja ロケール / en ロケール

取得した画像は PR 説明に添付する。

- [ ] **Step 6: コミット**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer/View/TimerView.swift \
        app/LeafTimer/App/ja.lproj/Localizable.strings \
        app/LeafTimer/App/en.lproj/Localizable.strings
git commit -m "feat(timer): トップ画面ステータスを StatChip ピル表示に刷新 (#39)

🔥emoji を flame.fill/leaf.fill の SF Symbol に置換し、
Today/Streak を .ultraThinMaterial ピルで表示。旧 emoji 文言を削除。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## After all tasks

- [ ] `make sort && git status` で pbxproj 差分が残っていないこと（残っていれば追いコミット — CLAUDE.md 教訓 Issue #8）。
- [ ] `superpowers:finishing-a-development-branch` で PR を作成（Simulator スクショを本文に添付、`Closes #39`）。
- [ ] PR 作成前に `git fetch && gh pr list --state all --head feature/39-top-screen-stats-ui` で既存 PR / merge 状況を確認（CLAUDE.md 教訓）。

---

## Self-Review メモ

- **Spec coverage**: アイコン統一(flame.fill)=Task2/3、ピル UI=Task2/3、4状態適応(.ultraThinMaterial)=Task2 + Task3 Step5 検証、ローカライズ2キー=Task1、旧 emoji キュー削除=Task3、テスト=Task1（localization）+ Task3 Step5（manual）。spec の全要求に対応タスクあり。
- **Placeholder scan**: 全コードブロックは実コードを記載。TBD/TODO なし。
- **Type consistency**: `StatChip(systemImage:tint:text:)` のシグネチャは Task2 定義と Task3 呼び出しで一致。キー名 `timer.stat.today`/`timer.stat.streak` は Task1（定義）・Task3（参照）・テストで一致。
