# Issue #16: ModernTimerViewSpec の xdescribe 解除 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `app/LeafTimerTests/ModernTimerViewSpec.swift` の `xdescribe("Modernized TimerView")` を `describe` に戻し、ViewInspector の現バージョン (0.10.2) で実際に動くケースを生かす。動かないケースだけ個別の `xit` に降ろし、その理由をコメントで明記する。`make tests` の `26 tests skipped` を最小化し、新規 skip が出現した時に気づける状態にする。

**Architecture:** 
- xdescribe (全 skip) → describe (実行) に戻す
- 試走で fail/error する個別 `it` に `xit` を付け、コメントで「ViewInspector 0.10.2 で未対応」「他の構造変更で path が変わった」等の理由を残す
- ViewInspector に依存しない ViewModel 直接呼び出し系 (約 7 件) は確実に pass する想定
- inspect() ベース (約 12 件) は ViewInspector のバージョン次第で個別判断

**Tech Stack:** Swift / Quick / Nimble / ViewInspector 0.10.2 / Xcode / xcodebuild

---

## File Structure

- **Modify**: `app/LeafTimerTests/ModernTimerViewSpec.swift` (215 行)
  - L11: `xdescribe("Modernized TimerView")` → `describe("Modernized TimerView")`
  - 個別の it のうち fail するものに `xit` を付け、直前にコメントで理由を明記
  - L9 の `// swiftlint:disable:next function_body_length` は維持 (本体サイズは変わらないため)

タスク 1 はこの plan を最初の commit に含める運用 (前回振り返りルール: `docs/superpowers/plans/<date>-<feature>.md` をブランチ作成直後に commit)。

---

### Task 1: Plan ドキュメントを最初の commit に含める

**Files:**
- Create: `docs/superpowers/plans/2026-05-23-issue-16-modern-timer-view-spec.md` (この plan)

- [ ] **Step 1: Plan ファイルが存在することを確認**

```bash
ls docs/superpowers/plans/2026-05-23-issue-16-modern-timer-view-spec.md
```

Expected: ファイルが見つかる (writing-plans skill で既に作成済み)

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-05-23-issue-16-modern-timer-view-spec.md
git commit -m "Issue #16: 計画ドキュメント追加

ModernTimerViewSpec の xdescribe 解除に向けた implementation plan を
ブランチ初回 commit として登録 (前回 #15 f2df20e の convention)。"
```

---

### Task 2: 現状の skip 件数を確認 (ベースライン記録)

**Files:**
- Read only: `app/LeafTimerTests/ModernTimerViewSpec.swift`

- [ ] **Step 1: ベースラインとして make tests を実行し、skip 数を記録**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tee /tmp/issue-16-baseline.log | tail -30
```

Expected: `make: *** Error` または `** TEST SUCCEEDED **` のどちらか。`tests skipped` または `xdescribe` 由来で 26 件相当の skip があるはず。

- [ ] **Step 2: skip 件数を確認**

```bash
grep -E "Test (Suite|Case).*skipped|26 tests skipped|tests passed.*skipped" /tmp/issue-16-baseline.log | head -20
```

Expected: `ModernTimerViewSpec` 配下の skip 件数を含む行が出る (ベースラインメモ用)。

- [ ] **Step 3: TaskList で進捗を記録 (commit 不要、メモのみ)**

baseline の skip 件数を会話に書き留める (例: 「ベースライン: 26 skipped」)。

---

### Task 3: xdescribe → describe に変更して試走

**Files:**
- Modify: `app/LeafTimerTests/ModernTimerViewSpec.swift:11`

- [ ] **Step 1: xdescribe → describe に変更**

`app/LeafTimerTests/ModernTimerViewSpec.swift` 11 行目を編集:

```swift
// Before
        xdescribe("Modernized TimerView") {

// After
        describe("Modernized TimerView") {
```

- [ ] **Step 2: 試走 (unit-tests のみ。lint は後で)**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tee /tmp/issue-16-tryout.log | tail -50
```

Expected: テスト実行が走り、`** TEST FAILED **` または `** TEST SUCCEEDED **` のどちらか。

- [ ] **Step 3: pass / fail の内訳を抽出**

```bash
grep -E "Test Case '-\[LeafTimerTests\.ModernTimerViewSpec" /tmp/issue-16-tryout.log | head -50
```

各 it が `passed` / `failed` のいずれかで終わるはず。fail のものをリストアップする。

- [ ] **Step 4: fail 内容を確認**

```bash
grep -B 2 -A 5 "ModernTimerViewSpec.*failed\|XCTAssert" /tmp/issue-16-tryout.log | head -100
```

fail の原因 (ViewInspector の限界 / path 不一致 / 期待値ズレ) を特定する。

**Note**: この時点で **commit はまだしない**。Task 4 で xit を付けてから一緒にコミットする。

---

### Task 4: fail / unsupported なケースに `xit` を付ける

**Files:**
- Modify: `app/LeafTimerTests/ModernTimerViewSpec.swift` (該当行)

- [ ] **Step 1: Task 3 の結果リストから、xit にする it を確定**

Task 3 で fail したものを「ViewInspector 限界由来 → xit」「実装変更由来 → xit + ロードマップコメント」に分類。

- [ ] **Step 2: 該当 it 行に `xit` を付与し、直前にコメントを書く**

例:
```swift
// xit: ViewInspector 0.10.2 では NavigationStack.navigationTitle() が
// SwiftUI 16+ の internal API 変更で取得できない (Issue #16)
xit("has proper navigation title") {
    let navStack = try timerView.body.inspect().navigationStack()
    let title = try navStack.navigationTitle()
    expect(title.isEmpty) == false
}
```

注意: コメントは「なぜスキップするのか」だけを書く (将来の読者が「ViewInspector が直ったら戻せる」と判断できるように)。

- [ ] **Step 3: 再試走して残った it が全て pass することを確認**

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tee /tmp/issue-16-after.log | tail -30
```

Expected: `** TEST SUCCEEDED **`、ModernTimerViewSpec 配下の fail は 0、skip 件数は Task 2 のベースラインより小さい。

- [ ] **Step 4: 残り skip 件数を確認**

```bash
grep -E "tests passed|tests failed|tests skipped|tests skipped" /tmp/issue-16-after.log | tail -10
```

会話に「ベースライン X 件 → 修正後 Y 件 (削減 X-Y 件)」を報告。

---

### Task 5: SwiftLint と sort を確認 (`make tests` を通す)

**Files:**
- Run only: `cd app && make tests`

- [ ] **Step 1: `make tests` 全体を実行 (sort + lint + unit-tests)**

```bash
cd app && set -o pipefail && make tests 2>&1 | tee /tmp/issue-16-make-tests.log | tail -30
```

Expected: `sort` `lint` `unit-tests` すべて成功。`** TEST SUCCEEDED **` で終わる。

- [ ] **Step 2: lint で警告 (特に function_body_length / 既存 xit 関連) が出ていないことを確認**

```bash
grep -i "warning\|error" /tmp/issue-16-make-tests.log | head -20
```

Expected: ModernTimerViewSpec 関連の warning が増えていない。`disable:next function_body_length` は xit を増やしても body のサイズは変わらないので維持で OK。

---

### Task 6: 変更を commit

**Files:**
- Modify: `app/LeafTimerTests/ModernTimerViewSpec.swift`

- [ ] **Step 1: 差分確認**

```bash
git diff app/LeafTimerTests/ModernTimerViewSpec.swift
```

Expected: 
- L11: `xdescribe` → `describe`
- 個別 it のうち N 件: `it` → `xit` + 直前のコメント追加

- [ ] **Step 2: Commit**

```bash
git add app/LeafTimerTests/ModernTimerViewSpec.swift
git commit -m "Issue #16: xdescribe を解除し、動かないケースのみ個別 xit に降ろす

- 26 tests skipped (xdescribe 由来) → N tests skipped (個別 xit 由来) に削減
- xit に降ろしたケースは直前のコメントでスキップ理由を明示
  (ViewInspector 0.10.2 の API 限界 / 実装変更による path 不一致 等)
- ViewModel 直接呼び出し系のケースは pass で復活

Closes #16"
```

注意: コミットメッセージの `N` は実際の数値に差し替え。

---

### Task 7: PR 作成

- [ ] **Step 1: Push**

```bash
git push -u origin feature/issue-16-modern-timer-view-spec
```

- [ ] **Step 2: PR 作成 (タイトルは「Issue #16: ModernTimerViewSpec の xdescribe を解除し個別 xit に降ろす」)**

```bash
gh pr create --title "Issue #16: ModernTimerViewSpec の xdescribe を解除し個別 xit に降ろす" --body "..."
```

PR 本文の構成:
- **Summary**: xdescribe 解除 → 個別 xit に降ろしたケース数
- **Background**: c4f4e8c での経緯と、本来 `xit` で済むはずだったが `xdescribe` で全 skip になっていた事実
- **改善内容**: ベースライン N 件 → 修正後 M 件 (削減 N-M 件)、それぞれの xit にスキップ理由コメントが付いた
- **xit に降ろしたテスト一覧** (Task 4 で確定したリスト)
- **Test plan**: `make tests` 通過 / 残り xit のスキップ理由がコメントで明示されている

`Closes #16` を本文に含める。

- [ ] **Step 3: PR の URL をユーザーに報告**

---

## 自己レビュー結果

### Spec coverage check
- Issue #16 の A 案 (復活: ViewInspector の現バージョンで pass するように修正し describe に戻す) を、現実的な範囲 (動かないものは個別 xit) で実装する Task に分解済み。
- 「26 tests skipped を 0 にしたい」目標は、xit が残る限り完全達成は困難。ただし「**個別 xit ごとにスキップ理由が明示される**」状態にすることで「新規 skip が出現した時に気づける」という Issue #16 の本質的な要望は満たせる。

### Placeholder scan
- Task 4 の Step 2 のコメント文言、Task 6 のコミットメッセージ内 `N` は試走結果に応じて差し替える「動的な値」。プランの定型的なプレースホルダではないため許容。

### Type consistency
- ファイル名は一貫して `ModernTimerViewSpec.swift`、テストフレームワークは Quick / Nimble / ViewInspector で統一。
