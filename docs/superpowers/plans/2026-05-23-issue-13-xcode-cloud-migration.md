# Issue #13 Part B-E: Xcode Cloud TestFlight 移行 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LeafTimer の TestFlight 配信を fastlane beta lane から Xcode Cloud Workflow に一本化する。`ci_post_clone.sh` で Secrets 復元と pod install を行い、Xcode Cloud setup 手順を docs 化し、`fastlane beta` lane に deprecated コメントを付ける (削除はしない、緊急時 rollback 保険)。

**Architecture:** spec `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md` 参照。Secrets は A 案 (base64 Environment Variable、`ci_post_clone.sh` で `base64 -d` して配置)。Build Number は F-1 (Xcode Cloud auto-increment、Apple 側で管理)。fastlane は D-1 (`beta` のみ deprecated コメント、`unittests` 維持)。

**Tech Stack:** Bash (ci_post_clone.sh), CocoaPods, Xcode Cloud (Apple 側 UI 設定 = コード変更外), Ruby/fastlane (既存)

---

## File Structure

| ファイル | 種別 | 行数目安 |
|---|---|---|
| `app/ci_scripts/ci_post_clone.sh` | 新規 (Bash) | ~30 |
| `docs/ver1_2/xcode-cloud-setup.md` | 新規 (Markdown) | ~120 |
| `app/fastlane/Fastfile` | 修正 (Ruby) | +1 line (deprecated コメント) |
| `docs/superpowers/plans/2026-05-23-issue-13-xcode-cloud-migration.md` | 新規 (この plan、Task 1 で commit) | - |

**変更しないファイル**: `Info.plist`, `.gitignore`, `Podfile`, `Podfile.lock`, `KeyManager.swift`, `AdsView.swift`。

**注意**: `app/ci_scripts/` ディレクトリは現状未作成。Task 2 で `mkdir -p` する。Apple Xcode Cloud は `ci_post_clone.sh` というファイル名を **予約名** として認識する (リポジトリルートまたは `ci_scripts/` 配下、実行権限必須)。`app/` 配下に置く理由: Xcode プロジェクト (`LeafTimer.xcworkspace`) が `app/` 配下にあり、Xcode Cloud の `$CI_PRIMARY_REPOSITORY_PATH` ベースの動作が `app/` ルート前提で組まれるため。

---

### Task 1: Plan ドキュメントを最初の commit に含める

**Files:**
- Create: `docs/superpowers/plans/2026-05-23-issue-13-xcode-cloud-migration.md` (この plan)

- [ ] **Step 1: Plan ファイルが存在することを確認**

```bash
ls docs/superpowers/plans/2026-05-23-issue-13-xcode-cloud-migration.md
```

Expected: ファイルが見つかる (writing-plans skill で既に作成済み)

- [ ] **Step 2: ブランチが `feature/issue-13-part-b-e-xcode-cloud` であることを確認**

```bash
git branch --show-current
```

Expected: `feature/issue-13-part-b-e-xcode-cloud` (既存、spec の commit `35bc2a4` を含む)

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-05-23-issue-13-xcode-cloud-migration.md
git commit -m "$(cat <<'EOF'
Issue #13 Part B-E: 計画ドキュメント追加

spec docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md
に基づく implementation plan を追加。

Plan 構造 (戦略 III、1 PR / 4 commits):
- Task 1: 本 plan の commit (これ)
- Task 2: ci_post_clone.sh 新規
- Task 3: docs/ver1_2/xcode-cloud-setup.md 新規
- Task 4: fastlane Fastfile に deprecated コメント
EOF
)"
```

---

### Task 2: ci_post_clone.sh の新規作成

**Files:**
- Create: `app/ci_scripts/ci_post_clone.sh`

- [ ] **Step 1: `app/ci_scripts/` ディレクトリを作成**

```bash
ls app/ci_scripts/ 2>&1 || mkdir -p app/ci_scripts
ls -la app/ci_scripts/
```

Expected: ディレクトリが作成される (元々無いはず)。

- [ ] **Step 2: `ci_post_clone.sh` を新規作成**

`app/ci_scripts/ci_post_clone.sh` に以下を記述:

```bash
#!/usr/bin/env bash
# Apple Xcode Cloud の予約 hook: リポジトリ clone 直後に実行される。
# Secrets (Keys.plist / GoogleService-Info.plist) を base64 Env Var から復元し、
# CocoaPods 依存を取得する。
#
# 設計: docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md
# 必要な Env Var: KEYS_PLIST_BASE64, GOOGLE_SERVICE_INFO_PLIST_BASE64
# (App Store Connect の Workflow Environment Variables に Secret 区分で登録)
set -euo pipefail

echo "==> ci_post_clone.sh: start"

APP_DIR="${CI_WORKSPACE}/app"

echo "==> Restoring Keys.plist"
echo "${KEYS_PLIST_BASE64}" | base64 -d > "${APP_DIR}/Keys.plist"

echo "==> Restoring GoogleService-Info.plist"
echo "${GOOGLE_SERVICE_INFO_PLIST_BASE64}" | base64 -d > "${APP_DIR}/GoogleService-Info.plist"

echo "==> Running pod install"
cd "${APP_DIR}"
pod install

echo "==> ci_post_clone.sh: done"
```

- [ ] **Step 3: 実行権限を付与**

```bash
chmod +x app/ci_scripts/ci_post_clone.sh
ls -la app/ci_scripts/ci_post_clone.sh
```

Expected: ファイル権限が `-rwxr-xr-x` (実行可能) になる。Xcode Cloud は実行権限が無いと hook を認識しない。

- [ ] **Step 4: ローカル shellcheck (任意、なくても続行可)**

```bash
which shellcheck && shellcheck app/ci_scripts/ci_post_clone.sh || echo "shellcheck not installed, skipping"
```

Expected: shellcheck がインストールされていれば warning 0 件 (set -euo pipefail / 変数引用 / quoting は適切に書いてある)。インストールされていない場合は skip して OK。

- [ ] **Step 5: bash 構文チェック**

```bash
bash -n app/ci_scripts/ci_post_clone.sh && echo "syntax OK"
```

Expected: `syntax OK`。

- [ ] **Step 6: dry-run スモークテスト (任意、Env Var 未設定で fail することの確認)**

```bash
bash app/ci_scripts/ci_post_clone.sh 2>&1 | tail -5 || true
```

Expected: `KEYS_PLIST_BASE64: unbound variable` 相当のエラーが出て exit (set -u の効果)。これにより本番でも Env Var 未設定が即検出されることを確認できる。

- [ ] **Step 7: Commit**

```bash
git add app/ci_scripts/ci_post_clone.sh
git commit -m "$(cat <<'EOF'
Issue #13 Part B-E: ci_post_clone.sh で Secrets 復元と pod install を実装

Apple Xcode Cloud の予約 hook (ci_post_clone.sh) を新規作成。

動作:
1. KEYS_PLIST_BASE64 → base64 -d → app/Keys.plist 配置
2. GOOGLE_SERVICE_INFO_PLIST_BASE64 → base64 -d → app/GoogleService-Info.plist 配置
3. cd app && pod install で CocoaPods 取得

set -euo pipefail で Env Var 未設定 / base64 失敗 / pod install 失敗を
即検出 (LeafTimer の pipefail rule と整合)。

実行権限 -rwxr-xr-x を付与 (Xcode Cloud は実行権限必須)。

Env Var の登録は App Store Connect の Workflow UI で実施
(手順は docs/ver1_2/xcode-cloud-setup.md に記載予定)。
EOF
)"
```

---

### Task 3: docs/ver1_2/xcode-cloud-setup.md の新規作成

**Files:**
- Create: `docs/ver1_2/xcode-cloud-setup.md`

- [ ] **Step 1: ドキュメントを新規作成**

`docs/ver1_2/xcode-cloud-setup.md` に以下を記述:

````markdown
# Xcode Cloud TestFlight 配信セットアップガイド

> 関連: Issue #13 / spec `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md` / `app/ci_scripts/ci_post_clone.sh`

LeafTimer の TestFlight 配信を **Xcode Cloud** で自動化するための初回セットアップ手順。コードに含まれない Apple Developer / App Store Connect 側の UI 操作をまとめる。

## 前提

- Apple Developer Program 有効 (個人 / 法人)
- App Store Connect で `LeafTimer` (Bundle ID `jp.ema.LeafTimer`) が登録済み
- 月次 Xcode Cloud ビルド時間枠 25h 以内で運用 (LeafTimer 規模なら十分余裕)
- 本 PR (Issue #13 Part B-E) がマージ済みで `app/ci_scripts/ci_post_clone.sh` がリポジトリにある状態

## Step 1: GitHub Repository を Apple Developer に接続

1. https://appstoreconnect.apple.com → My Apps → LeafTimer → **Xcode Cloud** タブ
2. **Get Started** → ソースリポジトリとして GitHub を選択
3. Apple ID 認証 → GitHub OAuth で `es0612/LeafTimer` リポジトリへのアクセスを許可
4. Primary repository は LeafTimer リポジトリ、Branch は `master`

## Step 2: ローカルで Secrets を base64 化

```bash
# Keys.plist (本番 AdMob Unit ID を含む) を base64 化
base64 -i app/Keys.plist | pbcopy
# → 出力 (クリップボード) をメモ帳等に控える

base64 -i app/GoogleService-Info.plist | pbcopy
# → 出力 (クリップボード) をメモ帳等に控える
```

注: `pbcopy` は macOS 標準。Linux なら `xclip -selection clipboard`。出力をターミナルにそのまま出すと履歴に残るので、`pbcopy` 経由が推奨。

## Step 3: Xcode Cloud Workflow を新規作成

App Store Connect → Xcode Cloud → **Create Workflow**:

- **Name**: `TestFlight Beta` (任意)
- **Start Condition**: 
  - Branch Changes
  - Branch: `master`
  - Auto-cancel when newer build starts: ✓
- **Environment**:
  - Xcode Version: Latest Release (例: `Xcode 17.x`)
  - macOS Version: Latest Release
- **Actions**:
  - **Archive** (iOS):
    - Scheme: `LeafTimer Release` (既存 scheme、`Fastfile` の `build_app` でも使用)
    - Platform: iOS
    - Deployment Preparation: TestFlight (Internal Testing Only)
- **Post-Actions**:
  - **TestFlight Internal Testing**:
    - Group: 内部テスター (`Internal Testers` 等の既存グループ)

### Build Number 自動 increment の設定

Workflow の編集ページ → Environment 設定 → **Increment Build Number** を有効化 (`CURRENT_PROJECT_VERSION` を Xcode Cloud のビルド番号で上書き)。

`MARKETING_VERSION` (アプリのバージョン、例 1.2.0) は手動管理。リリース時に開発者が `.pbxproj` を直接編集 (release-version-bump-check の手順に従う)。

## Step 4: Environment Variables (Secrets) を登録

Workflow の編集ページ → **Environment Variables** タブ → **Add Variable**:

| Name | Value | Secret |
|---|---|---|
| `KEYS_PLIST_BASE64` | Step 2 で取得した Keys.plist の base64 文字列 | ✓ (必須) |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Step 2 で取得した GoogleService-Info.plist の base64 文字列 | ✓ (必須) |

**Secret チェック** をオンにすると、ビルドログで値が `***` でマスクされる。**必ずチェックすること** (本番広告 ID / Firebase 認証情報が露出するリスク回避)。

## Step 5: 動作確認

Workflow 作成完了後、**Start Build** で手動トリガー:

- [ ] `ci_post_clone.sh` の各 step が Apple ログで pass (echo した step 名で確認)
  - `==> ci_post_clone.sh: start`
  - `==> Restoring Keys.plist`
  - `==> Restoring GoogleService-Info.plist`
  - `==> Running pod install`
  - `==> ci_post_clone.sh: done`
- [ ] Archive 成功 (Workflow page で緑色 ✓)
- [ ] TestFlight に新 Build が表示される (App Store Connect → My Apps → LeafTimer → TestFlight タブ)
- [ ] Build を internal tester に配布 (自分の Apple ID で受信できれば OK)
- [ ] インストール → 起動 → **本番広告 ID で広告表示**:
  - Issue #13 Part A (PR #24) のおかげで Release ビルドは本番 ID、Debug ビルドはテスト ID
  - TestFlight は Release ビルドなので、AdMob 管理画面でインプレッションが計上されることを後日確認
- [ ] クラッシュ報告なし (24 時間監視、App Store Connect → Crashes タブ)

## トラブルシューティング

### `ci_post_clone.sh` が認識されない

- ファイルパスが `app/ci_scripts/ci_post_clone.sh` であることを確認
- 実行権限 `-rwxr-xr-x` (`chmod +x`) が付いていることを確認
- ファイル名が完全一致 (`.sh` 拡張子、ハイフンと underscore の混在なし)

### `KEYS_PLIST_BASE64: unbound variable` で fail

- Step 4 で Env Var が登録されていない可能性
- 名前のスペルミス (`KEYS_PLIST_BASE64` 厳密一致)
- Secret 区分ではなく Non-secret で登録した場合も同様 (Xcode Cloud では同じ環境変数空間)

### `pod install` で `Pods.xcodeproj` が見つからない等のエラー

- Podfile.lock のバージョン整合性を確認
- `cd app && pod install --repo-update` をローカルで実行して同じ状態を再現
- 必要なら Podfile.lock を commit して再 push

### Archive が失敗する (codesigning エラー)

- Xcode Cloud の **Automatic Code Signing** が有効か確認
- Apple Developer Team ID が正しいか (`DEVELOPMENT_TEAM = UUD4WPFJTD`)
- App Store Connect の **Profiles** / **Certificates** が最新か

## Rollback 手順 (緊急時)

Xcode Cloud で致命的な問題が発生し、すぐに TestFlight 送信が必要な場合:

```bash
cd app
bundle exec fastlane beta
```

`fastlane beta` lane は deprecated コメント付きで残っている (`app/fastlane/Fastfile`)。`unittests` → `increment_build_number` → `commit_version_bump` → `push_to_git_remote` → `build_app` → `upload_to_testflight` を従来通り実行できる。

注意: fastlane で送る場合、`commit_version_bump` で master に直接 commit を作るので、後で Xcode Cloud の自動 increment と build number が衝突しないようにリリース後に手動調整が必要。

## fastlane との関係 (移行後の運用)

| Lane | 状態 | 用途 |
|---|---|---|
| `fastlane unittests` | 維持 | ローカル開発でのテスト実行 (`make tests` と並存) |
| `fastlane beta` | deprecated コメント付き | 緊急時 rollback 用、通常運用では使わない |

将来的に `fastlane beta` を完全削除する場合は別 Issue / 別 PR で。Xcode Cloud で安定運用 1-2 リリース見届けてから判断する。

## 参考

- [Apple: Configuring Xcode Cloud Workflows](https://developer.apple.com/documentation/xcode/configuring-the-build-environment-of-an-xcode-cloud-workflow)
- [Apple: Custom Build Scripts in Xcode Cloud](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- spec: `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md`
- 関連 PR: #24 (Issue #13 Part A, AdMob 切替)
````

- [ ] **Step 2: 差分確認**

```bash
wc -l docs/ver1_2/xcode-cloud-setup.md
git status
```

Expected: 120 行前後 (Markdown は柔軟、目安)、untracked file として表示。

- [ ] **Step 3: Commit**

```bash
git add docs/ver1_2/xcode-cloud-setup.md
git commit -m "$(cat <<'EOF'
Issue #13 Part B-E: Xcode Cloud setup ドキュメントを追加

App Store Connect 側の UI 操作 (Workflow 作成 / Env Var 登録 /
動作確認チェックリスト / トラブルシューティング / Rollback 手順) を
docs/ver1_2/xcode-cloud-setup.md に集約。

ci_post_clone.sh 単体ではコードに含まれない設定情報を、将来の
リリース担当 / 引き継ぎ者向けに残す。

既存の docs/ver1_2/ ディレクトリ (admob-production-setup.md /
release-checklist.md 等) との並列配置。
EOF
)"
```

---

### Task 4: fastlane Fastfile の beta lane に deprecated コメント追加

**Files:**
- Modify: `app/fastlane/Fastfile:16` (`lane :beta do` 行の直前)

- [ ] **Step 1: 現状の Fastfile を確認**

```bash
cat app/fastlane/Fastfile
```

Expected: 26 行のファイル、`lane :unittests` と `lane :beta` の 2 lane が定義されている (現状 confirmed)。

- [ ] **Step 2: deprecated コメントを追加**

`app/fastlane/Fastfile` の `lane :beta do` (16 行目) の直前に 1 行コメントを挿入:

変更前 (15-16 行目):
```ruby

  lane :beta do
```

変更後 (16-17 行目):
```ruby

  # DEPRECATED: TestFlight 配信は Xcode Cloud Workflow に移行済み (Issue #13)。
  # この lane は緊急時 rollback 用に残してある。通常は git push で
  # Xcode Cloud が自動配信する。詳細: docs/ver1_2/xcode-cloud-setup.md
  lane :beta do
```

- [ ] **Step 3: 差分確認**

```bash
git diff app/fastlane/Fastfile
```

Expected: 3 行追加 (コメント 3 行)、それ以外は無変更。`lane :unittests` は無修正。

- [ ] **Step 4: fastlane の syntax チェック (ruby parse)**

```bash
ruby -c app/fastlane/Fastfile
```

Expected: `Syntax OK`。

- [ ] **Step 5: Commit**

```bash
git add app/fastlane/Fastfile
git commit -m "$(cat <<'EOF'
Issue #13 Part B-E: fastlane beta lane を deprecated コメント化

TestFlight 配信を Xcode Cloud に一本化したことに伴い、
fastlane beta lane に DEPRECATED コメントを追加。

lane 自体は削除しない (緊急時 rollback 保険として残す)。
unittests lane はローカル開発で引き続き使うため無修正。

将来 Xcode Cloud で 1-2 リリース安定運用を見届けた後、
別 Issue で完全削除を判断する。
EOF
)"
```

---

### Task 5: 全体差分の確認と PR 作成準備

**Files:** (確認のみ、変更なし)

- [ ] **Step 1: ブランチ全体の commit を確認**

```bash
git log --oneline master..HEAD
```

Expected: 5 commits (古い順):
1. `Issue #13 Part B-E: 設計ドキュメント (brainstorming spec) 追加` (35bc2a4)
2. `Issue #13 Part B-E: 計画ドキュメント追加` (Task 1)
3. `Issue #13 Part B-E: ci_post_clone.sh で Secrets 復元と pod install を実装` (Task 2)
4. `Issue #13 Part B-E: Xcode Cloud setup ドキュメントを追加` (Task 3)
5. `Issue #13 Part B-E: fastlane beta lane を deprecated コメント化` (Task 4)

- [ ] **Step 2: ファイル変更全体の確認**

```bash
git diff master --stat
```

Expected: 4 files changed:
- `app/ci_scripts/ci_post_clone.sh` (新規、~30 lines)
- `app/fastlane/Fastfile` (+3 lines コメント)
- `docs/superpowers/plans/2026-05-23-issue-13-xcode-cloud-migration.md` (新規)
- `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md` (新規)
- `docs/ver1_2/xcode-cloud-setup.md` (新規)

(spec ドキュメントは事前 commit `35bc2a4` でブランチに既にある)

- [ ] **Step 3: `make tests` で既存テストに影響がないことを確認**

```bash
cd app && set -o pipefail && make tests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`、既存テスト 109 件 / 16 skipped (Issue #16 由来) は変動なし。

注: 本 PR で Swift コードに変更はないので、テスト結果に影響しないはず。 もしビルドが失敗するなら、`Podfile` / `Podfile.lock` / fastlane に意図せず影響を与えた可能性があるので、原因究明を優先。

- [ ] **Step 4: ci_post_clone.sh の最終チェック**

```bash
bash -n app/ci_scripts/ci_post_clone.sh && echo "syntax OK"
ls -la app/ci_scripts/ci_post_clone.sh
```

Expected: `syntax OK`、`-rwxr-xr-x` (実行権限あり)。

---

### Task 6: PR 作成

**Files:** (push と PR 作成、ファイル変更なし)

- [ ] **Step 1: Push**

```bash
git push -u origin feature/issue-13-part-b-e-xcode-cloud
```

- [ ] **Step 2: PR 作成 (タイトル: `Issue #13 Part B-E: Xcode Cloud TestFlight 移行`)**

PR 本文の構成:

- **Summary**: Xcode Cloud 移行の全体像 (ci_post_clone.sh / setup docs / fastlane deprecated)
- **Background**: Issue #13 やること #2-#6 を Part A (PR #24) と分離して本 PR で完了
- **設計参照**: spec ファイルへのリンク
- **主要決定 4 件の要約** (Secrets / fastlane / Build Number / 戦略)
- **本 PR でカバーする範囲とカバーしない範囲 (Scope 注意)**
- **ユーザーが App Store Connect 側で必要な作業** (Workflow 作成 / Env Var 登録 / GitHub 接続)
- **Test plan**: 動作確認チェックリスト (docs と同じ内容)
- **Closes #13** (Part A は別 PR #24、Part B-E でクローズ)
- **Rollback 手順** (緊急時の fastlane beta 利用方法)

- [ ] **Step 3: PR の URL をユーザーに報告**

PR がマージされたら、ユーザーは `docs/ver1_2/xcode-cloud-setup.md` の Step 1-5 に従って Xcode Cloud Workflow を設定する。

---

## 自己レビュー結果

### Spec coverage check

spec `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md` の各セクション対応:

- ✅ **Architecture (移行後)**: Task 2 (ci_post_clone.sh), Task 3 (docs で Xcode Cloud Workflow 手順)
- ✅ **Components 表**:
  - `app/ci_scripts/ci_post_clone.sh` → Task 2
  - `docs/ver1_2/xcode-cloud-setup.md` → Task 3
  - `app/fastlane/Fastfile` → Task 4
  - Xcode Cloud Workflow (Apple 側) → Task 3 の docs に手順記載
- ✅ **Data Flow (Secrets 受け渡し)**: Task 2 ci_post_clone.sh で `base64 -d`、Task 3 docs で encode 手順
- ✅ **Error Handling**: Task 2 で `set -euo pipefail`、Task 3 docs にトラブルシューティング
- ✅ **Testing (動作確認)**: Task 3 docs に同チェックリスト
- ✅ **Scope 注意 (コード変更外)**: Task 3 docs の Step 1-5 で UI 操作手順
- ✅ **Commit 構造 (戦略 III、4 commits)**: Task 1-4 で計画通り (spec の 4 commits + Task 1 spec の事前 commit = 計 5 commits)
- ✅ **既知の留保事項**: Out-of-scope 項目は spec で明示済み、本 plan でも対象外

### Placeholder scan

- "TBD" / "TODO" / "Add appropriate error handling" 等の禁忌語なし
- 全 step に code block (Bash / Ruby / Markdown) または exact command を記載
- Task 3 の docs 本文は長文だが、placeholder ではなく実際の手順 (Apple Developer ID `UUD4WPFJTD` 等の固有値も spec / Issue 本文から拾って明示)

### Type consistency

- Env Var 名: `KEYS_PLIST_BASE64` / `GOOGLE_SERVICE_INFO_PLIST_BASE64` で全 task / docs 一貫
- ファイル名: `ci_post_clone.sh` (拡張子 + underscore で全箇所統一、ハイフン混在なし)
- パス: `app/ci_scripts/ci_post_clone.sh` / `app/Keys.plist` / `app/GoogleService-Info.plist` で統一
- `CI_WORKSPACE` (Xcode Cloud 標準環境変数) を ci_post_clone.sh と docs の両方で一貫使用

### スコープ判断

- 本 plan は **コード変更 4 ファイル** (`ci_post_clone.sh` 新規 / `Fastfile` +3 行 / docs 2 ファイル新規) のみ
- App Store Connect UI 操作はゼロ (docs に手順記載のみ、Task 6 で PR がマージされた後にユーザーが手動実施)
- Swift / Xcode プロジェクト構造への変更ゼロ (`make tests` への影響なし)
- 本 plan で完結、後続作業は不要 (Issue #13 全体をクローズ可能)
