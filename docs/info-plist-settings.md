# Info.plist 追加設定項目

## 🔒 プライバシー設定（iOS 14+ 対応）

### App Tracking Transparency（ATT）対応

```xml
<!-- 広告トラッキング許可要求の説明文 -->
<key>NSUserTrackingUsageDescription</key>
<string>このアプリは、他社のアプリやウェブサイトをまたいであなたの情報をトラッキングし、広告の品質向上に使用します。</string>

<!-- 英語版 -->
<key>NSUserTrackingUsageDescription</key>
<string>This app would like to track your activity across other companies' apps and websites to improve ad quality.</string>
```

### バックグラウンドオーディオの用途説明

```xml
<!-- 現在設定済みだが、より具体的な説明に更新 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- 用途説明を追加（iOS 17で推奨） -->
<key>NSMicrophoneUsageDescription</key>
<string>このアプリはマイクロフォンを使用しません。</string>

<key>NSCameraUsageDescription</key>
<string>このアプリはカメラを使用しません。</string>
```

## 📱 アプリメタデータ更新

### バージョン情報の明確化

```xml
<!-- マーケティングバージョン（App Storeに表示） -->
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>

<!-- ビルドバージョン（内部管理用） -->
<key>CFBundleVersion</key>
<string>1</string>

<!-- 表示名（ホーム画面に表示） -->
<key>CFBundleDisplayName</key>
<string>LeafTimer</string>

<!-- バンドル名 -->
<key>CFBundleName</key>
<string>LeafTimer</string>
```

### 多言語対応の完全化

```xml
<!-- 開発言語の設定 -->
<key>CFBundleDevelopmentRegion</key>
<string>ja</string>

<!-- サポートする言語リスト -->
<key>CFBundleLocalizations</key>
<array>
    <string>ja</string>
    <string>en</string>
</array>
```

## 🔐 セキュリティ設定

### App Transport Security（ATS）

```xml
<!-- HTTPS接続の強制（推奨設定） -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <false/>
    <!-- AdMob用の例外設定（必要に応じて） -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>googleads.g.doubleclick.net</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 📊 Google Services設定確認

### AdMob設定の確認

```xml
<!-- 現在の設定確認 -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-9706471521661305~4450977179</string>

<key>GADIsAdManagerApp</key>
<string>true</string>

<!-- SKAdNetwork設定の拡張（iOS 14.5+） -->
<key>SKAdNetworkItems</key>
<array>
    <!-- Google AdMob -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <!-- Google -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>4fzdc2evr5.skadnetwork</string>
    </dict>
    <!-- その他主要な広告ネットワーク -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>2u9pt9hc89.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>8s468mfl3y.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>hs6bdukanm.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>prcb7njmu6.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>v72qych5uu.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>c6k4g5qg8m.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>s39g8k73mm.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>3qy4746246.skadnetwork</string>
    </dict>
</array>
```

## 🎨 UI/UX設定

### インターフェース設定の最適化

```xml
<!-- 現在の設定確認・更新 -->
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>

<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>

<!-- ステータスバーの設定 -->
<key>UIStatusBarStyle</key>
<string>UIStatusBarStyleDefault</string>

<key>UIViewControllerBasedStatusBarAppearance</key>
<true/>
```

### 起動画面の設定

```xml
<!-- Launch Screen設定 -->
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>

<!-- Legacy設定の削除確認 -->
<!-- 以下が存在する場合は削除 -->
<!-- <key>UILaunchImages</key> -->
<!-- <key>UILaunchImageFile</key> -->
```

## 🚀 パフォーマンス設定

### バックグラウンド実行の最適化

```xml
<!-- 現在設定済みのバックグラウンドモード -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- バックグラウンド更新の制御 -->
<key>UIBackgroundRefreshEnabled</key>
<true/>
```

### メモリ管理の最適化

```xml
<!-- アプリ終了時の挙動 -->
<key>UIApplicationExitsOnSuspend</key>
<false/>

<!-- メモリ警告時の挙動 -->
<key>UIFileSharingEnabled</key>
<false/>
```

## 🔍 検索・Spotlight設定

### Spotlight検索対応

```xml
<!-- Spotlight検索でのアプリ表示 -->
<key>CoreSpotlightContinuation</key>
<true/>

<!-- 検索キーワード -->
<key>NSUserActivity</key>
<dict>
    <key>NSUserActivityTypes</key>
    <array>
        <string>com.leaftimer.timer</string>
        <string>com.leaftimer.pomodoro</string>
    </array>
</dict>
```

## 🧩 拡張機能準備

### 将来のWidget対応準備

```xml
<!-- WidgetKit準備 -->
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

## ✅ 設定チェックリスト

### 必須項目
- [ ] NSUserTrackingUsageDescription追加
- [ ] CFBundleShortVersionString設定（1.0.0）
- [ ] CFBundleVersion設定（1）
- [ ] CFBundleDisplayName設定
- [ ] CFBundleLocalizations配列追加

### 推奨項目
- [ ] SKAdNetworkItems拡張
- [ ] NSAppTransportSecurity設定
- [ ] UIStatusBarStyle設定
- [ ] CoreSpotlightContinuation設定

### 確認項目
- [ ] GADApplicationIdentifier正確性
- [ ] UIBackgroundModes必要性
- [ ] UISupportedInterfaceOrientations適切性
- [ ] UILaunchStoryboardName存在確認

## 📝 注意事項

1. **本番用AdMob ID**: Keys.plistのadUnitIDをテスト用から本番用に変更
2. **プライバシー設定**: iOS 14+のATT対応は法的要件
3. **多言語対応**: CFBundleLocalizationsは実際のローカライゼーションファイルと一致させる
4. **セキュリティ**: ATS設定は最新のセキュリティ基準に準拠
5. **バージョン管理**: リリース後のアップデート計画も考慮