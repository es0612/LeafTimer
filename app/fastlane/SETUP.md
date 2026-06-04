# Fastlane設定ガイド

## TestFlightへのアップロード設定

### 1. App-Specific Passwordの生成

TestFlightへアップロードするには、Apple IDのApp-Specific Password（アプリ専用パスワード）が必要です。

#### 手順:

1. [Apple ID アカウントページ](https://appleid.apple.com)にアクセス
2. 「サインインとセキュリティ」セクションへ移動
3. 「App用パスワード」を選択
4. 「パスワードを生成」をクリック
5. ラベル（例: "Fastlane"）を入力
6. 生成された16文字のパスワード（xxxx-xxxx-xxxx-xxxx形式）をコピー

### 2. 環境変数の設定

#### 方法A: .env.defaultファイル（推奨）

```bash
# fastlaneディレクトリで実行
cd /path/to/LeafTimer/app/fastlane
cp .env.default.template .env.default
```

`.env.default`ファイルを編集:

```bash
FASTLANE_USER=your-apple-id@example.com
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

#### 方法B: 環境変数として設定

```bash
export FASTLANE_USER="your-apple-id@example.com"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

`.zshrc`または`.bash_profile`に追加すると永続化できます。

### 3. TestFlightへのアップロード

```bash
cd /path/to/LeafTimer/app
make beta
```

または

```bash
cd /path/to/LeafTimer/app
fastlane beta
```

## 利用可能なレーン

### `fastlane beta`

1. ユニットテストを実行
2. ビルド番号を自動インクリメント
3. バージョン変更をコミット
4. Gitにプッシュ
5. アプリをビルド
6. TestFlightへアップロード

### `fastlane unittests`

ユニットテストのみを実行します。

## ASC メタデータ投入 (`upload_metadata`)

バイナリは **Xcode Cloud が所有**したまま、App Store Connect の**メタデータだけ**を投入するレーン。横断の know-how はグローバルスキル `asc-metadata-delivery`（`~/.claude/skills/`）に集約し、このリポジトリ固有の content は `fastlane/metadata/` に置く。

> ⚠️ **重要**: `upload_metadata` は **本番 ASC に metadata を書き込む**（`submit_for_review:false` は「審査に submit しない」だけで「書き込まない」ではない）。**必ず人間が認証情報付きで手実行**し、CI / 自動では走らせない。

### 手順 (download → edit → ローカル検証 → upload → 人間 submit)

1. 認証情報を `.env` に設定（上記「環境変数の設定」と同じ。`FASTLANE_USER` + App-Specific Password、または ASC API Key）。
2. **live を取得**してから編集（placeholder を上書き投入して live を壊さないため）:
   ```bash
   cd app && fastlane deliver download_metadata
   ```
3. `fastlane/metadata/<locale>/*.txt` を編集（`ja` / `en-US`）。
   - `en-US` の `description.txt` / `release_notes.txt` に **絵文字を入れない**（ASC が silent fail）。`ja` は絵文字 OK。詳細は `release-version-bump-check` スキル。
   - `name` / `subtitle` は 30 文字以内、`keywords` はカンマ区切り 100 文字以内。
4. **ローカル検証**（upload 前に潰せるもの）: en-emoji・`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` の bump・Age Rating を `release-version-bump-check` スキルで確認。
5. **投入**（stage → precheck。審査提出は ASC UI で人間が別途）:
   ```bash
   cd app && fastlane upload_metadata
   ```
   lane は `upload_to_app_store`（`skip_binary_upload:true` で stage）→ `precheck`（stage 済み ASC コピーを検証）の順に走る。

### Xcode Cloud との共存

- バイナリの upload/処理は **Xcode Cloud Workflow** が担う（Issue #13 で移行済み・不変）。
- `upload_metadata` は `skip_binary_upload: true` で **metadata だけ** push する。両者は所有境界が分かれており衝突しない。
- 特定ビルドにメタデータを紐付けたい場合のみ `upload_to_app_store(..., build_number: "<n>")` を足す。

### `fastlane/metadata/review_information/`

審査用 demo 認証情報など機微情報を含むため **gitignore 済み**（`.gitkeep` のみ commit）。各自ローカルで埋めてから投入する。

## トラブルシューティング

### エラー: "Auth context delegate failed to get headers"

**原因:** App-Specific Passwordが設定されていない、または間違っている

**解決:**
1. App-Specific Passwordを再生成
2. `.env.default`ファイルを確認
3. パスワードに余分なスペースがないか確認

### エラー: "Could not download/upload from App Store Connect"

**原因:**
- Apple Developer Programの期限切れ
- App Store Connectのアクセス権限不足
- ネットワーク接続の問題

**解決:**
1. [App Store Connect](https://appstoreconnect.apple.com)にアクセス可能か確認
2. Apple Developer Programが有効か確認
3. アカウントにTestFlightへのアップロード権限があるか確認

### エラー: "Failed to determine the appleID from bundleID"

**原因:** Bundle IDが App Store Connect に登録されていない

**解決:**
1. App Store Connectでアプリが作成されているか確認
2. Bundle ID `jp.ema.LeafTimer` が正しいか確認

## セキュリティ

- `.env.default`ファイルは`.gitignore`に含まれており、リポジトリにコミットされません
- パスワードを直接コードにハードコードしないでください
- CI/CDを使用する場合は、シークレット管理機能を使用してください

## 参考リンク

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Apple Developer](https://developer.apple.com/)
- [App Store Connect](https://appstoreconnect.apple.com/)
