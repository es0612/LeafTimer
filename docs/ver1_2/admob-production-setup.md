# AdMob本番環境設定ガイド

## 🚀 本番リリース前のAdMob設定

### 現在の設定確認

#### Keys.plist（テスト環境）
```xml
<key>adUnitID</key>
<string>ca-app-pub-3940256099942544/2435281174</string>
```
⚠️ **これはテスト用IDです。本番リリース前に変更が必要です。**

#### Info.plist（本番環境設定済み）
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-9706471521661305~4450977179</string>
```
✅ **本番用アプリIDが設定済みです。**

## 📋 AdMob本番設定手順

### Step 1: AdMobコンソールでの設定

1. **AdMobアカウントにログイン**
   - https://apps.admob.com/

2. **アプリの確認**
   - Bundle ID: `jp.ema.LeafTimer`
   - アプリ名: `LeafTimer`

3. **広告ユニットの作成**
   - 形式: バナー広告
   - 名前: `LeafTimer Banner`
   - 推奨サイズ: 320x50 (標準バナー)

4. **広告ユニットIDの取得**
   - フォーマット: `ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx`
   - テスト用IDから本番用IDに置き換え

### Step 2: コード内の設定変更

#### Keys.plistの更新
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>adUnitID</key>
    <string>[本番用広告ユニットID]</string>
</dict>
</plist>
```

#### 本番とテストの切り替え実装例
```swift
// KeyManager.swiftの拡張（推奨）
extension KeyManager {
    func getAdUnitID() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174" // テスト用
        #else
        return getValue(key: "adUnitID") as? String ?? "" // 本番用
        #endif
    }
}

// AdsView.swiftでの使用
struct AdsView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        
        // 本番/テストの自動切り替え
        banner.adUnitID = KeyManager().getAdUnitID()
        
        // 以下既存のコード...
    }
}
```

## 💰 収益化設定

### 支払い設定
1. **税務情報の提出**
   - 米国税務情報（W-8BEN等）
   - 日本の税務情報

2. **支払い方法の設定**
   - 銀行口座情報
   - 最低支払い額: $100

3. **広告配信地域の設定**
   - 初期: 日本、アメリカ
   - 段階的に他地域へ拡大

### 広告設定の最適化

#### 広告フォーマット
```
推奨設定:
- バナー広告: 320x50（標準）
- 配置: 画面下部
- リフレッシュ: 30-60秒
- eCPM最適化: 有効
```

#### 広告フィルタリング
```
除外カテゴリ:
- ギャンブル
- アルコール
- 成人向けコンテンツ
- 競合アプリ
```

## 🔒 プライバシー・コンプライアンス

### GDPR対応（EU向け）
```swift
// UMP（User Messaging Platform）の実装例
import UserMessagingPlatform

class ConsentManager {
    func requestConsentForm() {
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false
        
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(
            with: parameters
        ) { [weak self] error in
            if error != nil {
                // エラーハンドリング
            } else {
                self?.loadConsentForm()
            }
        }
    }
    
    private func loadConsentForm() {
        UMPConsentForm.load { [weak self] form, error in
            if let form = form {
                form.present(from: self?.viewController) { error in
                    // フォーム表示後の処理
                }
            }
        }
    }
}
```

### COPPA対応（子供向け）
```swift
// 子供向けコンテンツとしてマーク（必要に応じて）
let request = GADRequest()
let extras = GADExtras()
extras.additionalParameters = ["tag_for_child_directed_treatment": "true"]
request.register(extras)
```

## 📊 分析・測定設定

### Firebase Analytics統合
```swift
// イベント追加例
Analytics.logEvent("ad_impression", parameters: [
    "ad_unit_id": adUnitID,
    "ad_format": "banner"
])

Analytics.logEvent("timer_start", parameters: [
    "session_type": "work", // work/break
    "duration_minutes": 25
])
```

### AdMob指標の監視
```
重要指標:
- インプレッション数
- クリック率（CTR）
- 収益（eCPM）
- フィルレート
- 表示エラー率
```

## 🧪 テスト・QA

### 本番前テスト手順

1. **テスト環境での確認**
   ```
   - Debug buildでテスト広告の表示確認
   - 広告の適切な配置とサイズ確認
   - バックグラウンド/フォアグラウンド切り替え時の動作確認
   ```

2. **本番環境での確認**
   ```
   - Release buildで本番広告の表示確認
   - 広告収益の計測確認
   - プライバシー設定の動作確認
   ```

3. **TestFlightでの確認**
   ```
   - 内部テスターでの広告表示確認
   - 様々なデバイス・iOS版での動作確認
   - ユーザビリティテスト
   ```

### 本番リリース後の監視

#### 初期監視項目（最初の48時間）
- [ ] 広告の正常表示
- [ ] クラッシュ率 < 1%
- [ ] 広告収益の発生確認
- [ ] ユーザー体験の悪化なし

#### 継続監視項目（日次）
- [ ] DAU（日間アクティブユーザー）
- [ ] 広告収益の推移
- [ ] アプリレビューの監視
- [ ] 技術的な問題の発生状況

## 🚨 トラブルシューティング

### よくある問題と解決策

#### 広告が表示されない
```
原因と対処:
1. 広告在庫不足 → 配信地域の拡大
2. 広告ユニットID誤り → Keys.plistの確認
3. GADApplicationIdentifier誤り → Info.plistの確認
4. ネットワーク問題 → エラーハンドリングの改善
```

#### 収益が発生しない
```
原因と対処:
1. 支払い設定未完了 → AdMobコンソールで設定確認
2. 最低支払い額未達 → $100まで累積待ち
3. 無効トラフィック → 広告クリックの監視
4. 税務情報未提出 → 必要書類の提出
```

#### プライバシー関連の問題
```
原因と対処:
1. ATT設定不備 → Info.plistのNSUserTrackingUsageDescription確認
2. GDPR同意未取得 → UMPの実装
3. プライバシーポリシー不備 → ポリシーの更新
```

## 📅 リリース後のスケジュール

### 第1週
- [ ] 日次収益監視
- [ ] 広告表示率確認
- [ ] ユーザーフィードバック対応

### 第1ヶ月
- [ ] 収益最適化
- [ ] 広告配信設定調整
- [ ] A/Bテスト実施

### 継続的改善
- [ ] 新しい広告フォーマットの検討
- [ ] 広告配置の最適化
- [ ] 収益向上施策の実施

## 🔗 参考リンク

- [AdMob ヘルプセンター](https://support.google.com/admob/)
- [Google Mobile Ads SDK](https://developers.google.com/admob/ios)
- [User Messaging Platform](https://developers.google.com/admob/ump/ios)
- [AdMob ポリシー](https://support.google.com/admob/answer/6128543)