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
