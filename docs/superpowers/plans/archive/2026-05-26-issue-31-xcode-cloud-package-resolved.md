# Issue #31 Xcode Cloud Package.resolved 不在ビルド失敗修正 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xcode Cloud の Archive ビルドが SwiftPM `Package.resolved` 不在で失敗するのを修正し、`ci_post_clone.sh` を通過させる。

**Architecture:** `app/.gitignore:53` の `*.xcworkspace` グロブが `LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` まで巻き込んでいるのが根因。Git の whitelist パターン（親ディレクトリを `!` で順次再 include）で Package.resolved のみ tracking 対象に戻す。`pod install` が `xcshareddata/` を破壊しない（CocoaPods は `contents.xcworkspacedata` のみ更新する）ことを前提とし、ローカル検証で確認する。検証で破壊が確認されたら approach B（`app/` 直下に backup を置き `ci_post_clone.sh` でコピー）へ切り替え。

**Tech Stack:** Git gitignore whitelist patterns, CocoaPods (pod install)、Xcode 26 SwiftPM Package.resolved、Xcode Cloud workflow / `ci_post_clone.sh`

---

### Task 1: ブランチ準備と plan commit

**Files:**
- Add to git: `docs/superpowers/plans/2026-05-26-issue-31-xcode-cloud-package-resolved.md`（この plan ファイル本体）

- [ ] **Step 1: master を最新化して fix ブランチを切る**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git fetch origin
git checkout master
git pull origin master
git checkout -b fix/issue-31-xcode-cloud-package-resolved
```

Expected: `Switched to a new branch 'fix/issue-31-xcode-cloud-package-resolved'`

- [ ] **Step 2: 既存 PR が無いことを確認**（CLAUDE.md ルール：push 前に必ず確認）

```bash
gh pr list --state all --head fix/issue-31-xcode-cloud-package-resolved
```

Expected: 出力なし（新規ブランチ）

- [ ] **Step 3: plan ファイルを commit**（CLAUDE.md ルール：plan は実装の最初のコミットとして含める）

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add docs/superpowers/plans/2026-05-26-issue-31-xcode-cloud-package-resolved.md
git commit -m "$(cat <<'EOF'
docs: Issue #31 Xcode Cloud Package.resolved 修正 plan

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 1 ファイル追加の commit が成功

---

### Task 2: app/.gitignore に whitelist パターンを追加

**Files:**
- Modify: `app/.gitignore`（CocoaPods セクション、`*.xcworkspace` 行の直下）

- [ ] **Step 1: 現在の app/.gitignore 該当箇所を確認**

```bash
sed -n '50,55p' /Users/shinya/workspace/claude/LeafTimer/app/.gitignore
```

Expected:
```
# CocoaPods
Pods/
*.xcworkspace
```

- [ ] **Step 2: Edit で `*.xcworkspace` を whitelist パターンに置換**

Edit tool を以下のように使用：

- file_path: `/Users/shinya/workspace/claude/LeafTimer/app/.gitignore`
- old_string:
```
# CocoaPods
Pods/
*.xcworkspace
```
- new_string:
```
# CocoaPods
Pods/
*.xcworkspace
# Issue #31: SwiftPM Package.resolved は LeafTimer.xcworkspace 配下に存在するため
# whitelist で除外する。Xcode Cloud は automatic dependency resolution が
# disabled で Package.resolved が必須。
!LeafTimer.xcworkspace
LeafTimer.xcworkspace/*
!LeafTimer.xcworkspace/xcshareddata
LeafTimer.xcworkspace/xcshareddata/*
!LeafTimer.xcworkspace/xcshareddata/swiftpm
LeafTimer.xcworkspace/xcshareddata/swiftpm/*
!LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

- [ ] **Step 3: 正例 (ignore したい) を検証**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git check-ignore -v app/LeafTimer.xcworkspace/contents.xcworkspacedata
git check-ignore -v app/LeafTimer.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
git check-ignore -v app/LeafTimer.xcworkspace/xcshareddata/swiftpm/configuration/dummy.json
```

Expected: 3 つすべてが ignore されている（.gitignore のいずれかの行にヒットする出力）

- [ ] **Step 4: 反例 (ignore したくない) を検証**

CLAUDE.md の振り返り教訓：「新規 custom rule を入れる前に、**意図する正例と反例の両方をテキストで列挙して regex を当て**、ヒット方向が反転していないかを必ず確認する」

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git check-ignore -v app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
echo "exit=$?"
```

Expected:
- 出力なし
- `exit=1`（`git check-ignore` は ignore されていないファイルに対して exit 1 を返す）

もし出力が出たら（exit 0）、whitelist が反転している → Step 2 をやり直す。

---

### Task 3: Package.resolved を tracking に追加

**Files:**
- Add to git: `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: 対象ファイルの存在確認**

```bash
cat /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: ViewInspector の pin を含む JSON が出力される（`"identity" : "viewinspector"` を含む）

- [ ] **Step 2: git add（whitelist 後なので `-f` 不要）**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
git status
```

Expected: status に `new file: app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` が表示される。出ない場合は Task 2 Step 4 の whitelist が壊れている → Task 2 をやり直す。

---

### Task 4: pod install が xcshareddata/ を壊さないことをローカル検証

**Files:** None modified（read-only verification）

このタスクは approach A の前提（`pod install` が `xcshareddata/` を触らない）を実証するためのもの。前提が崩れたら approach B（`ci_post_clone.sh` でコピー）への切り替えが必要なので Plan を中断してユーザーに報告する。

- [ ] **Step 1: 現在の Package.resolved の checksum を記録**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
shasum LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: SHA-1 hash が出力される。**メモする**（例: `abc123...  Package.resolved`）

- [ ] **Step 2: pod install を実行**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
pod install 2>&1 | tail -20
echo "exit=${PIPESTATUS[0]}"
```

Expected:
- 末尾に `Pod installation complete!` が含まれる
- `exit=0`

CLAUDE.md の振り返り教訓に従い、`set -o pipefail` を明示的に置いて exit code が `tail` に隠されないようにする。

- [ ] **Step 3: Package.resolved が変化していないことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
shasum LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: Step 1 と同じ hash。

**もし違ったら（approach A 破綻）**:
- このタスクで Plan を中断する
- ユーザーに「approach A 不成立。`pod install` が xcshareddata/swiftpm/ を再生成した。approach B（`app/` 直下に backup を置き `ci_post_clone.sh` の `pod install` 後にコピー）へ切り替えるか確認したい」と報告
- 勝手に approach B に切り替えない

- [ ] **Step 4: 作業ツリーに予期せぬ差分が無いことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git status
```

Expected:
- staged: `app/.gitignore` (modified) と `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (new file) のみ
- unstaged: なし、または無視可能な変更のみ（`Pods/` 配下は ignore されているはず）

もし大きな副作用差分が出ていたら（例: `app/Podfile.lock` が変化、新規ファイル多数）、ユーザーに状況を見せて指示を仰ぐ。

---

### Task 5: コミットとプッシュ

**Files:**
- Modified: `app/.gitignore`
- Added: `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: staged 差分の最終確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git diff --cached --stat
git diff --cached app/.gitignore
```

Expected:
- 2 ファイル変更（.gitignore + Package.resolved）
- .gitignore の diff に whitelist 7 行 + コメント 3 行が追加されている

- [ ] **Step 2: コミット**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git commit -m "$(cat <<'EOF'
fix(ci): Issue #31 Xcode Cloud で Package.resolved 不在ビルド失敗を修正

app/.gitignore の `*.xcworkspace` グロブが
LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved まで巻き込んでいた。
ViewInspector を SPM 経由で追加した際、Xcode Cloud は automatic dependency
resolution が disabled なので Package.resolved が必須となり、不在で
ci_post_clone.sh が失敗していた (exited with code 1)。

whitelist パターン (親ディレクトリを ! で順次再 include) で Package.resolved
のみ tracking に戻し、pod install が xcshareddata/swiftpm/ を破壊しないこと
もローカル検証済み (Task 4)。

Closes #31

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit 成功

- [ ] **Step 3: push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git push -u origin fix/issue-31-xcode-cloud-package-resolved
```

Expected: `Branch 'fix/issue-31-xcode-cloud-package-resolved' set up to track 'origin/fix/issue-31-xcode-cloud-package-resolved'`

---

### Task 6: PR 作成

**Files:** None modified

- [ ] **Step 1: 既存 PR が無いことを再確認**（push 後）

```bash
gh pr list --state all --head fix/issue-31-xcode-cloud-package-resolved
```

Expected: まだ何も出ない（or なにかあったら確認して中止）

- [ ] **Step 2: PR 作成**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
gh pr create --title "fix: Issue #31 Xcode Cloud Package.resolved 不在ビルド失敗修正" --body "$(cat <<'EOF'
## Summary

- `app/.gitignore` の `*.xcworkspace` グロブが SwiftPM `Package.resolved` を巻き込んでいたのを whitelist パターンで除外
- ViewInspector の `Package.resolved` を tracking 対象に追加
- `pod install` が `xcshareddata/swiftpm/` を破壊しないことをローカル検証済み（approach A）

Closes #31

## Test plan

- [ ] PR push 後、Xcode Cloud の Archive ビルドが `ci_post_clone.sh` を通過すること
- [ ] SwiftPM 依存解決エラー（`Could not resolve package dependencies`）が消えること
- [ ] (副次的) 「scheme may only exist locally」警告が消えるか観察（残っても無害と判断済み）

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL が返ってくる

- [ ] **Step 3: PR URL をユーザーに報告**

ユーザーに PR URL を提示し、Xcode Cloud ビルド結果は manual で待つことを伝える。
ビルド結果の verify は別セッションで実施（CI 結果は async）。

---

## Self-Review

**1. Spec coverage:** Issue #31 (Xcode Cloud Package.resolved 失敗) → Task 2 で gitignore 修正 / Task 3 で Package.resolved 追加 / Task 4 で pod install 影響検証 / Task 5-6 で commit, push, PR。コア要件カバー OK。

**2. Placeholder scan:** 「TBD」「TODO」「implement later」無し。全コマンド・全 diff が具体的。

**3. Type consistency:** ファイルパスが一貫して `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved`。ブランチ名 `fix/issue-31-xcode-cloud-package-resolved` も全 Task で統一。

**4. CLAUDE.md ルール照合:**
- ✅ plan を実装最初のコミットに含める (Task 1 Step 3)
- ✅ push 前に既存 PR 確認 (Task 1 Step 2, Task 6 Step 1)
- ✅ gitignore 修正時に正例/反例両方を検証 (Task 2 Step 3-4)
- ✅ Bash で `tail` する時 `pipefail` + `PIPESTATUS` (Task 4 Step 2)
