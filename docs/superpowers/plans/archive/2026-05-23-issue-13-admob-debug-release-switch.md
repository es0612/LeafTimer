# Issue #13 Part A: AdMob テスト/本番 ID 自動切替 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `KeyManager` に `getAdUnitID()` を追加し、`#if DEBUG` で Google 公式テスト ID、`#else` で `Keys.plist` の本番 ID を返すよう実装する。これにより Debug ビルド (開発・テスト時) が誤って本番広告を叩く Google ポリシー違反リスクを根絶する。`AdsView.swift` を新メソッド呼び出しに差し替え、不要なコメントアウト残骸も削除する。

**Architecture:** 
- Issue #13 本文の「やること #1」に対応する独立タスク。Xcode Cloud 移行 (Plan Part B-E) の前提条件であり、単独で完結・リリース可能。
- 切替条件はコンパイル時の `#if DEBUG` (= Debug Configuration ビルド)。Release ビルドは `Keys.plist` の本番 ID。
- Google 公式テスト Banner ID: `ca-app-pub-3940256099942544/2934735716` (Issue #13 本文に明記)。
- TDD: 先に Quick spec で Debug ビルドのテスト ID 返却を検証 → 実装 → Release 側は `#if !DEBUG` で別途確認 (テスト中は Debug なので、Release 分岐の直接検証は不可。コードレビューで確保)。

**Tech Stack:** Swift / Quick / Nimble / Xcode / ファイル登録は `bin/add-to-target.rb` (Issue #15 で確立した手法)

---

## File Structure

- **Modify**: `app/LeafTimer/Components/KeyManager.swift` (現在 19 行)
  - 新規メソッド `getAdUnitID() -> String` を追加。`#if DEBUG` でテスト ID、`#else` で `getValue(key: "adUnitID") as? String ?? ""`
- **Modify**: `app/LeafTimer/View/AdsView.swift` (現在 38 行)
  - L8-9 のコメントアウト済みテスト ID を削除
  - L11 を `KeyManager().getAdUnitID()` に差し替え (force unwrap でなく String 直接代入)
- **Create**: `app/LeafTimerTests/KeyManagerSpec.swift` (新規)
  - `getAdUnitID()` が Debug ビルドで Google 公式テスト ID を返すことを検証する Quick spec
- **Modify**: `app/LeafTimer.xcodeproj/project.pbxproj`
  - `KeyManagerSpec.swift` を **LeafTimerTests** target に登録 (Issue #15 で確立した `bin/add-to-target.rb` で実施。手動編集禁止)

`print(banner.adUnitID)` (`AdsView.swift:12`) はデバッグログ残骸だが、本 Plan のスコープ外。別 Issue 候補として note に残す。

---

### Task 1: Plan ドキュメントを最初の commit に含める

**Files:**
- Create: `docs/superpowers/plans/2026-05-23-issue-13-admob-debug-release-switch.md` (この plan)

- [ ] **Step 1: Plan ファイルが存在することを確認**

```bash
ls docs/superpowers/plans/2026-05-23-issue-13-admob-debug-release-switch.md
```

Expected: ファイルが見つかる (writing-plans skill で既に作成済み)

- [ ] **Step 2: ブランチが `feature/issue-13-admob-debug-release-switch` であることを確認 / 切替**

```bash
git branch --show-current
# feature/issue-13-admob-debug-release-switch でなければ:
# git checkout -b feature/issue-13-admob-debug-release-switch master
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-05-23-issue-13-admob-debug-release-switch.md
git commit -m "$(cat <<'EOF'
Issue #13 Part A: 計画ドキュメント追加

AdMob テスト/本番 ID 自動切替 (Issue #13 やること #1) の
implementation plan をブランチ初回 commit として登録
(plan-driven PR convention)。

Plan Part B-E (Xcode Cloud 移行本体) は別 plan として後続予定。
EOF
)"
```

---

### Task 2: KeyManagerSpec を失敗テストで作成

**Files:**
- Create: `app/LeafTimerTests/KeyManagerSpec.swift`

- [ ] **Step 1: Quick spec を新規作成**

`app/LeafTimerTests/KeyManagerSpec.swift` に以下を書く:

```swift
import Nimble
import Quick

@testable import LeafTimer

final class KeyManagerSpec: QuickSpec {
    override class func spec() {
        describe("KeyManager") {
            describe("getAdUnitID()") {
                it("returns Google's official test banner ID in Debug builds") {
                    // テストターゲットは常に Debug Configuration でビルドされるため、
                    // ここでは Debug 分岐 (Google 公式テスト ID) のみを検証する。
                    // Release 分岐は #if !DEBUG で別途コードレビューで担保。
                    let adUnitID = KeyManager().getAdUnitID()
                    expect(adUnitID) == "ca-app-pub-3940256099942544/2934735716"
                }
            }
        }
    }
}
```

- [ ] **Step 2: テストファイルを LeafTimerTests target に登録**

Issue #15 で確立した手法に従い、`bin/add-to-target.rb` で登録する (pbxproj 手動編集は事故のもと)。

```bash
ls bin/add-to-target.rb && cd app && ruby ../bin/add-to-target.rb LeafTimerTests/KeyManagerSpec.swift LeafTimerTests
```

Expected: スクリプトが「LeafTimerTests target に追加しました」相当のメッセージを出す。`git diff app/LeafTimer.xcodeproj/project.pbxproj` で `KeyManagerSpec.swift` の参照が追加されていることを確認。

注: `bin/add-to-target.rb` の正確な呼び出し方法 (引数仕様 / cwd) は Issue #15 のコミット (`f2df20e` など) を参考にする:

```bash
git log --all --oneline -- bin/add-to-target.rb | head -5
git show <SHA> -- bin/add-to-target.rb | head -80   # 引数仕様確認用
```

もし `bin/add-to-target.rb` が無い、または使い方が不明な場合は STOP して controller に報告 (BLOCKED)。手動 pbxproj 編集は禁止。

- [ ] **Step 3: テストを実行し、コンパイルエラー (`getAdUnitID` 未定義) で失敗することを確認**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -40
```

Expected: ビルドエラー、または `KeyManagerSpec` がコンパイルできず `cannot find 'getAdUnitID'` 相当のエラー。 → Task 3 の実装で解消する。

---

### Task 3: KeyManager に getAdUnitID() を実装

**Files:**
- Modify: `app/LeafTimer/Components/KeyManager.swift`

- [ ] **Step 1: メソッドを追加**

`KeyManager.swift` の末尾 (`}` の直前) に以下を追加:

```swift
    /// 広告ユニット ID を環境別に返す。
    /// - Debug ビルド: Google 公式のテスト用 Banner ID (本番広告に影響しない)
    /// - Release ビルド: `Keys.plist` の `adUnitID` (本番 ID)
    func getAdUnitID() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return getValue(key: "adUnitID") as? String ?? ""
        #endif
    }
```

完成後の `KeyManager.swift` (全 28 行想定):

```swift
import Foundation

struct KeyManager {
    private let keyFilePath = Bundle.main.path(forResource: "Keys", ofType: "plist")

    func getKeys() -> NSDictionary? {
        guard let keyFilePath else {
            return nil
        }
        return NSDictionary(contentsOfFile: keyFilePath)
    }

    func getValue(key: String) -> AnyObject? {
        guard let keys = getKeys() else {
            return nil
        }
        return keys[key] as AnyObject
    }

    /// 広告ユニット ID を環境別に返す。
    /// - Debug ビルド: Google 公式のテスト用 Banner ID (本番広告に影響しない)
    /// - Release ビルド: `Keys.plist` の `adUnitID` (本番 ID)
    func getAdUnitID() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return getValue(key: "adUnitID") as? String ?? ""
        #endif
    }
}
```

- [ ] **Step 2: テストを再実行し、pass することを確認**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`、`KeyManagerSpec` 配下の 1 ケースが pass。

---

### Task 4: AdsView を新メソッドに差し替え + コメントアウト削除

**Files:**
- Modify: `app/LeafTimer/View/AdsView.swift`

- [ ] **Step 1: AdsView.swift の Lines 8-11 を編集**

現状:

```swift
        //                test id
        //                banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"

        banner.adUnitID = KeyManager().getValue(key: "adUnitID") as? String
```

変更後:

```swift
        banner.adUnitID = KeyManager().getAdUnitID()
```

これでコメントアウト 2 行 + force-cast 1 行が、シンプルな 1 行に置き換わる。

注: `print(banner.adUnitID)` (元 L12) は本 Plan のスコープ外として温存。デバッグログ残骸として別 Issue 候補。

- [ ] **Step 2: 差分確認**

```bash
git diff app/LeafTimer/View/AdsView.swift
```

Expected: コメントアウト 2 行削除 + 1 行差し替えのみ。

- [ ] **Step 3: ビルド & テスト**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`。

---

### Task 5: SwiftLint と `make tests` 通過確認

**Files:**
- Run only: `cd app && make tests`

- [ ] **Step 1: 全体テスト**

```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/issue-13a-make-tests.log | tail -30
```

Expected: `sort` → `lint` → `unit-tests` 全て成功、`** TEST SUCCEEDED **` で終わる。

- [ ] **Step 2: 新規 lint warning がないことを確認**

```bash
grep -i "warning\|error" /tmp/issue-13a-make-tests.log | grep -E "KeyManager|AdsView" | head -10
```

Expected: 0 件、または既存 warning と同等のもののみ。

---

### Task 6: Commit

**Files:**
- Modify: `app/LeafTimer/Components/KeyManager.swift`
- Modify: `app/LeafTimer/View/AdsView.swift`
- Create: `app/LeafTimerTests/KeyManagerSpec.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj`

- [ ] **Step 1: 差分全体確認**

```bash
git status
git diff --stat
```

Expected: 4 ファイル変更 (KeyManager.swift / AdsView.swift / KeyManagerSpec.swift 新規 / project.pbxproj に 1 ファイル追加分の参照)

- [ ] **Step 2: Commit**

```bash
git add \
    app/LeafTimer/Components/KeyManager.swift \
    app/LeafTimer/View/AdsView.swift \
    app/LeafTimerTests/KeyManagerSpec.swift \
    app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Issue #13 Part A: AdMob テスト/本番 ID 自動切替を実装

- KeyManager に getAdUnitID() を追加 (#if DEBUG で Google 公式テスト
  Banner ID ca-app-pub-3940256099942544/2934735716、Release で
  Keys.plist の本番 ID を返す)
- AdsView を新メソッド呼び出しに差し替え、コメントアウト済みテスト ID
  (L8-9) を削除
- KeyManagerSpec を新規作成し、Debug ビルドでのテスト ID 返却を検証
- pbxproj に LeafTimerTests target 登録は bin/add-to-target.rb で実施
  (Issue #15 で確立した手法、手動編集は禁止)

これで Debug ビルド (開発 / Xcode 起動 / xcodebuild test) が
誤って本番広告 ID を叩く Google ポリシー違反リスクを根絶する。

Refs #13 (Part A のみ。Xcode Cloud 移行本体 Part B-E は別 PR)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

注: `Closes #13` ではなく `Refs #13`。Issue #13 は Part B-E の作業が残るため自動 close しない。Part E 完了時 (最後の PR) に `Closes #13` を付ける。

---

### Task 7: PR 作成

- [ ] **Step 1: Push**

```bash
git push -u origin feature/issue-13-admob-debug-release-switch
```

- [ ] **Step 2: PR 作成**

タイトル: `Issue #13 Part A: AdMob テスト/本番 ID 自動切替`

本文の構成:
- **Summary**: 何を変えたか (KeyManager.getAdUnitID 追加、AdsView 差し替え、Spec 新規)
- **Background**: 現状 Keys.plist が本番 ID で、Debug ビルドも本番広告を叩く Google ポリシー違反リスク。Issue #13 やること #1 を切り出して独立対応
- **採用したテスト ID**: `ca-app-pub-3940256099942544/2934735716` (Google 公式 Banner テスト ID)
- **Plan Part B-E の予告**: Xcode Cloud 移行本体は別 Plan / 別 PR で対応
- **Test plan**: `make tests` 通過 / `KeyManagerSpec` で Debug 側を検証 / Release 側はレビューで担保
- **Note**: `AdsView.swift:12` の `print(banner.adUnitID)` 残骸は本 Plan スコープ外 (別 Issue 候補)

`Refs #13` を本文に含める (close はしない)。

- [ ] **Step 3: PR の URL をユーザーに報告**

---

## 自己レビュー結果

### Spec coverage check
- Issue #13「やること #1: AdMob テスト/本番切替の実装」の 3 サブタスクをすべてカバー:
  - [x] `KeyManager.getAdUnitID()` 追加 (Task 3)
  - [x] `AdsView.swift:11` を `getAdUnitID()` 呼び出しに差し替え (Task 4)
  - [x] コメントアウト済みテスト ID (`AdsView.swift:8-9`) を削除 (Task 4)
- Issue #13「やること #2-#6」(Xcode Cloud / ci_scripts / Secrets / Workflow / fastlane 整理) は意図的にスコープ外。別 plan で扱う旨を Plan header と PR description に明記。

### Placeholder scan
- "TBD" / "fill in details" 等の placeholder は無い。
- Task 2 Step 2 で「`bin/add-to-target.rb` の正確な呼び出し方法は Issue #15 のコミットを参考」と書いた箇所は、実装者が現地で検証する手順を明示 (BLOCKED escalation 条件も書いた)。これは placeholder ではなく安全装置。

### Type consistency
- `getAdUnitID() -> String` のシグネチャは Task 2 (テスト), Task 3 (実装), Task 4 (呼び出し側) で一貫。
- テスト ID 文字列 `ca-app-pub-3940256099942544/2934735716` は Task 2 / Task 3 / Task 6 commit msg / Task 7 PR で一貫。

### スコープ判断
- Plan は LeafTimer の **アプリコードのみ** を変更 (Swift 4 ファイル + pbxproj 登録)。
- インフラ (Xcode Cloud / Secrets / ci_scripts) はゼロ。これは正しい分離。
- `print(banner.adUnitID)` 削除はスコープ外として明示。別 Issue 候補。
