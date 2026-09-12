# 未配線 dead Swift 14ファイルの削除 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** どの Xcode target にも attach されていない（= ビルド/テストに含まれない）dead な Swift 14ファイルをディスクから削除し、`xcode-precheck` の orphan baseline を空にする。

**Architecture:** 14ファイルは全て 2025-09 の放棄された旧実装（iOS 17 Design System Phase 2 / TimerView Modernization Phase 2）。orphan = どの target にも未配線なので、(a) ビルドが成立している事実 と (b) grep による live 参照ゼロの裏取り の二重証拠で「全て dead」と確定済み。orphan は `project.pbxproj` に登録されていないため、削除しても pbxproj は変化せず `make sort` は不要。削除後に `--update-baseline` で baseline を再生成すると header のみの空になる。

**Tech Stack:** Ruby (`bin/xcode-precheck.rb`, `xcodeproj` gem 1.27.0), `make` (precheck / tests), git。

---

## 事前確認（実施済み・記録）

- 14ファイルは `app/bin/xcode-precheck-orphans.txt` の baseline と完全一致（grandfathered）。
- `git log -1` で全ファイルが 2025-09-21 / 2025-09-22 の commit 止まり（8ヶ月前・recent WIP ではない）。
- orphan シンボル（`TimerControlsView` / `TimerDisplayView` / `PulseAnimation` / `ComponentLibrary` 等）への参照は **orphan ファイル自身の内部（自己定義 / PreviewProvider）のみ**。live コードからの参照ゼロ。
- live `TimerView.swift` は semantic color（`.green` / `.orange`）を直接使用 → DesignSystem ツリーは完全に supersede 済み。
- test 3ファイルも test target 外なので、削除してもテストスイートに影響なし。
- `xcodeproj` gem はローカルに存在（1.27.0）→ `--update-baseline` 実行可能。

**判断結論:** 全14ファイル **delete**（wire ではない）。

---

## File Structure

**削除する 11 source ファイル（`app/` 配下）:**
- `LeafTimer/View/Components/TimerControlsView.swift`
- `LeafTimer/View/Components/TimerDisplayView.swift`
- `LeafTimer/View/DesignSystem/ColorExtensions.swift`
- `LeafTimer/View/DesignSystem/Components/Buttons.swift`
- `LeafTimer/View/DesignSystem/Components/Cards.swift`
- `LeafTimer/View/DesignSystem/Components/ComponentLibrary.swift`
- `LeafTimer/View/DesignSystem/Components/ProgressViews.swift`
- `LeafTimer/View/DesignSystem/Components/SettingsComponents.swift`
- `LeafTimer/View/DesignSystem/Components/Toast.swift`
- `LeafTimer/View/DesignSystem/FontExtensions.swift`
- `LeafTimer/View/Modifiers/PulseAnimation.swift`

**削除する 3 test ファイル（`app/` 配下）:**
- `LeafTimerTests/DesignSystem/ColorExtensionsTests.swift`
- `LeafTimerTests/DesignSystem/ComponentsTests.swift`
- `LeafTimerTests/DesignSystem/FontExtensionsTests.swift`

**更新するファイル:**
- `app/bin/xcode-precheck-orphans.txt` — `--update-baseline` により header のみへ（自動更新）

**変更しないもの:** `app/LeafTimer.xcodeproj/project.pbxproj`（orphan は非登録なので差分なし）→ `make sort` 不要。

---

## Task 1: 削除前のベースライン確認（現状が green であること）

**Files:** なし（確認のみ）

- [ ] **Step 1: 削除対象が baseline と一致し、live 参照がゼロであることを再確認**

Run:
```bash
cd app
grep -rn -E "TimerControlsView|TimerDisplayView|PulseAnimation|pulseAnimation|ComponentLibrary|GreenLeafButton|LeafCard" LeafTimer LeafTimerTests --include="*.swift"
```
Expected: hit はすべて orphan ファイル自身の内部（定義行 / `*_Previews` / `ComponentLibraryPreviews`）のみ。live ファイルからの参照が **1件もない** こと。万一 live ファイル（baseline 外のファイル）が hit したら、そのファイルは削除対象から外し、ユーザーに報告して STOP。

- [ ] **Step 2: 削除前の precheck が green であることを記録**

Run:
```bash
cd app && ruby bin/xcode-precheck.rb
```
Expected: `✅ targets: no new orphan Swift files (14 grandfathered in baseline)` を含む。`❌` が無いこと。

---

## Task 2: 14ファイルを削除

**Files:** 上記 File Structure の 14ファイルを削除

> ⚠️ **破壊的操作（`git rm`）の前に、ユーザーの literal な削除承諾を得てから実行する**（プロジェクト CLAUDE.md の destructive-op ルール）。AskUserQuestion の選択肢ラベルは承諾として扱わない。

- [ ] **Step 1: 14ファイルを git rm**

Run:
```bash
cd app
git rm \
  LeafTimer/View/Components/TimerControlsView.swift \
  LeafTimer/View/Components/TimerDisplayView.swift \
  LeafTimer/View/DesignSystem/ColorExtensions.swift \
  LeafTimer/View/DesignSystem/Components/Buttons.swift \
  LeafTimer/View/DesignSystem/Components/Cards.swift \
  LeafTimer/View/DesignSystem/Components/ComponentLibrary.swift \
  LeafTimer/View/DesignSystem/Components/ProgressViews.swift \
  LeafTimer/View/DesignSystem/Components/SettingsComponents.swift \
  LeafTimer/View/DesignSystem/Components/Toast.swift \
  LeafTimer/View/DesignSystem/FontExtensions.swift \
  LeafTimer/View/Modifiers/PulseAnimation.swift \
  LeafTimerTests/DesignSystem/ColorExtensionsTests.swift \
  LeafTimerTests/DesignSystem/ComponentsTests.swift \
  LeafTimerTests/DesignSystem/FontExtensionsTests.swift
```
Expected: `rm '...'` が 14行出力される。エラーなし。

- [ ] **Step 2: 空になったディレクトリを確認・除去**

Run:
```bash
cd app
find LeafTimer/View/DesignSystem LeafTimer/View/Modifiers LeafTimer/View/Components LeafTimerTests/DesignSystem -type d 2>/dev/null | sort -r | while read d; do rmdir "$d" 2>/dev/null && echo "removed empty dir: $d"; done
git status --short
```
Expected: `View/Components/` に live ファイルが残る場合はそのディレクトリは残る（それで正しい）。完全に空になったディレクトリ（`DesignSystem/`, `Modifiers/`, `LeafTimerTests/DesignSystem/` 等）のみ除去される。git は空ディレクトリを追跡しないので、削除済みの 14ファイルだけが `D`（deleted）として staged 表示される。

---

## Task 3: baseline を再生成して空にする

**Files:** `app/bin/xcode-precheck-orphans.txt`（自動更新）

- [ ] **Step 1: --update-baseline で baseline を再生成**

Run:
```bash
cd app && ruby bin/xcode-precheck.rb --update-baseline
```
Expected: `✅ Wrote 0 orphan(s) to bin/xcode-precheck-orphans.txt`

- [ ] **Step 2: baseline が header のみ（orphan 0件）になったことを確認**

Run:
```bash
cd app && cat bin/xcode-precheck-orphans.txt
```
Expected: 先頭3行の `#` コメント header のみ。ファイルパスの行が1つも無いこと。

---

## Task 4: precheck と tests が green であることを検証

**Files:** なし（検証のみ）

- [ ] **Step 1: precheck が new orphan 0 / grandfathered 0 で green**

Run:
```bash
cd app && make precheck
```
Expected: `✅ targets: no new orphan Swift files (0 grandfathered in baseline)` を含む。`test_xcode_precheck.rb` のテストも pass。`❌` / `Error` が無いこと。

- [ ] **Step 2: フルテストでアプリ・テストバンドルのビルドが壊れていないことを確認**

Run（subagent 実行時は Bash timeout を 600000 に設定すること）:
```bash
cd app && make tests 2>&1 | tee /tmp/issue47-make-tests.log
```
Expected: 出力に `** TEST SUCCEEDED **`（または `** BUILD SUCCEEDED **` + テスト pass）が含まれ、`** TEST FAILED **` / `Error 6x` / `** BUILD FAILED **` が無いこと。

> zsh では `${PIPESTATUS[0]}` は空を返すため、成功判定は **出力中の成功/失敗マーカー文字列**で行う（プロジェクト CLAUDE.md の zsh pipestatus ルール）。`tee` で全ログを残しているので、判定に迷ったら `/tmp/issue47-make-tests.log` を `grep -E "TEST SUCCEEDED|TEST FAILED|BUILD FAILED|Error [0-9]"` で確認する。

---

## Task 5: コミット

**Files:** 14削除ファイル + `app/bin/xcode-precheck-orphans.txt`

- [ ] **Step 1: 変更を stage して commit**

Run:
```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add -A app/
git status --short
git commit -m "$(cat <<'EOF'
chore(cleanup): #47 未配線 dead Swift 14ファイルを削除し orphan baseline を空に

2025-09 の放棄された DesignSystem / TimerView Modernization 旧実装。
どの target にも未配線で live 参照ゼロ（ビルド成立 + grep の二重証拠）。
削除後 --update-baseline で baseline を 0件に再生成。

Closes #47

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: 15ファイル（14 deleted + 1 modified baseline）の commit。

---

## Self-Review

- **Spec coverage:** Issue #47 の「各ファイルを live/dead 判定 → 削除 or 配線」「baseline を空に」を全カバー（判定結果は全 delete）。
- **Placeholder scan:** TBD/TODO なし。全ステップに具体的なコマンドと期待出力あり。
- **Type consistency:** 削除タスクのため型定義の前後整合は対象外。ファイルパスは baseline と一致確認済み。
- **破壊的操作ガード:** Task 2 に literal 承諾の前置を明記。
- **zsh pipestatus / make sort:** Task 4 に zsh 成功マーカー判定、File Structure に `make sort` 不要の根拠を明記。
