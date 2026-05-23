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
base64 -i app/Keys.plist | tr -d '\n' | pbcopy
# → 出力 (クリップボード) をメモ帳等に控える

base64 -i app/GoogleService-Info.plist | tr -d '\n' | pbcopy
# → 出力 (クリップボード) をメモ帳等に控える
```

注: `pbcopy` は macOS 標準。Linux なら `xclip -selection clipboard`。出力をターミナルにそのまま出すと履歴に残るので、`pbcopy` 経由が推奨。

注: `tr -d '\n'` で改行を除去して 1 行化することで、App Store Connect の Secret 入力欄で改行が誤って消えるリスクを回避している (macOS の `base64 -i` はデフォルトで 76 文字ごとに line-wrap するため)。

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
