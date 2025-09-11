# LeafTimer コードベースレビュー（2025-09-10）

- 対象: iOS/SwiftUI アプリ（ポモドーロ・タイマー）。主要依存は Firebase、Google Mobile Ads、CocoaPods、Fastlane。
- 調査範囲: リポジトリ全体（`app/` 配下のソース、テスト、ビルド設定、CI 用スクリプト、各種設定ファイル）。

---

## リポジトリ構成（要点）
- アプリ本体: `app/LeafTimer`（`App/` `View/` `ViewModel/` `Components/` `Sound/`）。
- テスト: `app/LeafTimerTests`（Quick/Nimble/ViewInspector）、`app/LeafTimerUITests`（テンプレートのみ）。
- 依存管理: CocoaPods（`app/Podfile`、`app/Podfile.lock`、`app/Pods/` もコミット済み）。
- 配信/自動化: Fastlane（`app/fastlane/`）。
- 機密/設定: `app/GoogleService-Info.plist`、`app/Keys.plist`（広告ユニットID）。
- その他: Xcode プロジェクト/ワークスペース、アセット、サウンド、Makefile。

---

## アーキテクチャ概観
- パターン: MVVM 準拠（`TimerViewModel`、`SettingViewModel`）。
- DI: `TimerManager`・`AudioManager`・`UserDefaultsWrapper` のプロトコル注入でテスト容易性を確保。
- UI: SwiftUI（`TimerView`/`SettingView`/各種要素）。`AppDelegate` から `UIHostingController` で起動。

---

## 良い点
- 依存性注入が整理され、`Spy` 実装も用意されている（テスト拡張しやすい）。
- UI とロジックの責務分離（ViewModel で状態管理）。
- Fastlane/Makefile により基本的な自動化下地がある。
- 資産（アセット/音源）が Xcode 管理に揃っている。

---

## 主な課題とリスク

### 設計/コード品質
- タイマーのリセット未実装: `DefaultTimerManager.reset()` が空実装。期待動作が曖昧（`app/LeafTimer/Components/DefaultTimerManager.swift:1`）。
- 強参照/ライフサイクル懸念: `Timer.scheduledTimer(target:selector:)` は target を強参照。停止漏れやライフサイクル次第でリークの恐れ（`DefaultTimerManager.start`）。
- バックグラウンド挙動が不明瞭: `beginBackgroundTask` は呼ぶがバックグラウンド継続実行の要件（Background Modes: Audio 等）設定/設計が見えない（`app/LeafTimer/App/AppDelegate.swift:1`）。
- 例外握りつぶし: `do-catch { }` の空 `catch` が複数箇所（`DefaultAudioManager.setUp`）。障害時に調査困難（`app/LeafTimer/Components/DefaultAudioManager.swift:1`）。
- 強制アンラップ/型不一致: 広告 ID 取得で `! as? String`。`nil` でクラッシュし得るし、`as?` 後が Optional になるため式として不明確（`app/LeafTimer/View/AdsView.swift:1`）。
- 日付処理のロケール/タイムゾーン未指定: `DateFormatter` で `locale/timeZone` 未設定。端末設定に依存し不安定（`app/LeafTimer/Components/DateManager.swift:1`）。
- 命名の一貫性: ファイル名 `LocalUserDefaultWrapper.swift` と型名 `LocalUserDefaultsWrapper` が不一致（`app/LeafTimer/Components/LocalUserDefaultWrapper.swift:1`）。
- マジックナンバー/ハードコード: 色値、時間、文言が散在。再利用/翻訳困難（`TimerViewModel+extensions.swift:1`, `SettingView.swift:1` など）。
- ログの `print` 混入: 本番ビルドで不要ログが出る恐れ（`AdsView.swift:1`）。

### 機密情報/セキュリティ
- Firebase/AdMob の設定ファイルをリポジトリに同梱（`app/GoogleService-Info.plist:1`, `app/Keys.plist:1`）。運用上は権限/レート制限が前提だが、原則として漏洩面の最小化が望ましい。

### ビルド/依存/CI
- Pods をリポジトリに同梱（`app/Pods/`）。差分肥大化・競合・再現性低下の一因。
- `.gitignore` が最小限で Xcode 生成物や DerivedData、xcuserdata 等が対象外（ルート `.gitignore:1`）。
- CI 設定が見当たらない（GitHub Actions 等）。Fastlane はあるが CI 連携が未整備。

### テスト
- 単体テストの多くが `xit` で無効化（`app/LeafTimerTests/TimerViewSpec.swift:1`）。
- UI テストはテンプレートのみで実質未整備（`app/LeafTimerUITests/LeafTimerUITests.swift:1`）。
- 主要ユースケース（開始/停止/ブレーク遷移/今日の回数加算/設定反映）の網羅不足。

### UX/アクセシビリティ
- 動的タイプ/コントラスト対応・VoiceOver ラベル等が未考慮。
- 文言がハードコードで多言語化が困難（`SettingView.swift:1`, `TimerView.swift:1`）。

### パフォーマンス/安定性
- GIF 再生を独自実装（全フレーム decode＋配列保持）。メモリ/CPU 負荷が高くなりやすい（`app/LeafTimer/View/Elements/GIFPlayerView.swift:1`）。
- `UserDefaults.synchronize()` の多用は不要/非推奨（`LocalUserDefaultsWrapper`）。

---

## 改善提案（優先度つき）

### P0（直近対応推奨）
- 例外/クラッシュ対策:
  - `AdsView` の `adUnitID` 取得は安全にアンラップし、`testDeviceIdentifiers` 等の設定を分岐。Nil 時は広告を非表示にフェイルセーフ。
  - `DefaultAudioManager` の `catch` にエラー記録（os_log など）。
- タイマーの責務整理:
  - `DefaultTimerManager.reset()` の定義見直し or インターフェースから削除。リセットは `TimerViewModel` 側に集約。
  - `Timer` のライフサイクルを厳密化（`deinit`/`onDisappear` で invalidate、または `DispatchSourceTimer` 検討）。
- 日付/フォーマットの安定化:
  - `DateFormatter` に `locale = en_US_POSIX`、`timeZone = .current` を明示。
- ログ/計測:
  - 本番ビルドでの `print` を抑止。`Logger`（OSLog）に統一。

### P1（数スプリント）
- App エントリを SwiftUI App に移行（`@main` + `UIApplicationDelegateAdaptor`）。
- 機密情報の外部化:
  - `GoogleService-Info.plist` と `Keys.plist` は環境別テンプレート化（`*.template.plist`）し、実体は CI で注入。
  - Bundle ID/AdMob/Firebase 鍵は環境別設定（Debug/Staging/Release）。
- リポジトリ衛生:
  - 標準 `.gitignore`（Xcode）を適用。`Pods/` は原則 ignore（CocoaPods を継続する場合）。
  - 代わりに `Podfile.lock` をコミットし再現性確保。
- CI/CD:
  - GitHub Actions などでビルド/テスト/`fastlane beta` の自動化。
- テスト強化:
  - `xit` を有効化し、`TimerViewModel` のコア遷移（開始/停止/ブレーク切替/カウント保存/設定反映）を網羅。

### P2（中期）
- 国際化/アクセシビリティ:
  - `Localizable.strings` へ文言移行、日本語/英語最低対応。VoiceOver/コントラスト/動的タイプ対応。
- アニメーション最適化:
  - GIF 再生は `UIImage.animatedImage` の大量フレーム保持を避け、アセットの APNG/動画、Lottie 等を検討。
- 設定/状態の整備:
  - デフォルト値を `UserDefaults.register(defaults:)` で集中管理。

### P3（将来）
- 設計リファクタ:
  - 色/スタイルを `ColorSet` や `Theme` へ集約。マジックナンバー排除。
  - `KeyManager` → 型安全な設定層（`struct`/`enum`）に置換。
- 監視/分析:
  - クラッシュレポート（Crashlytics）とイベント計測の導入（プライバシー配慮/同意管理前提）。

---

## 指摘の根拠（該当ファイル）
- アプリ起動/バックグラウンド: `app/LeafTimer/App/AppDelegate.swift:1`
- タイマー管理: `app/LeafTimer/Components/DefaultTimerManager.swift:1`
- 音声管理/例外処理: `app/LeafTimer/Components/DefaultAudioManager.swift:1`
- 日付ユーティリティ: `app/LeafTimer/Components/DateManager.swift:1`
- 設定保持: `app/LeafTimer/Components/LocalUserDefaultWrapper.swift:1`
- キー管理: `app/LeafTimer/Components/KeyManager.swift:1`
- 画面/UI: `app/LeafTimer/View/TimerView.swift:1`, `app/LeafTimer/View/SettingView.swift:1`, `app/LeafTimer/View/AdsView.swift:1`
- GIF 再生: `app/LeafTimer/View/Elements/GIFPlayerView.swift:1`, `app/LeafTimer/View/Elements/GIFView.swift:1`
- ViewModel: `app/LeafTimer/ViewModel/TimerViewModel.swift:1`, `app/LeafTimer/ViewModel/SettingViewModel.swift:1`, `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift:1`
- テスト: `app/LeafTimerTests/TimerViewSpec.swift:1`, `app/LeafTimerUITests/LeafTimerUITests.swift:1`
- 依存/自動化: `app/Podfile:1`, `app/Podfile.lock:1`, `app/fastlane/Fastfile:1`, `app/Makefile:1`
- 機密ファイル: `app/GoogleService-Info.plist:1`, `app/Keys.plist:1`
- ignore 設定: `.gitignore:1`

---

## 追加で推奨する運用/整備
- コーディング規約の明文化（命名/コメント/ログ方針/エラーハンドリング）。
- 依存バージョンの定期更新と Renovate/Bazel などの導入検討（任意）。
- リリースノート/変更履歴（`CHANGELOG.md`）整備。
- 開発用 README 強化（セットアップ手順、シミュレータ指定、環境変数、`pod install`/`fastlane` の実行例）。

---

## 差し当たりの具体的アクション（チェックリスト）
- [.gitignore 拡充] Xcode/DerivedData/ビルド生成物/`Pods/` を対象へ。
- [秘密情報] `GoogleService-Info.plist`/`Keys.plist` のテンプレ化と CI 注入。
- [タイマー] `reset` の整理、`Timer` の管理強化、テスト追加。
- [日時処理] `DateFormatter` のロケール/タイムゾーン指定、ユニットテスト。
- [テスト] `xit` 解除、主要ロジックの網羅テスト、CI での自動実行。
- [UI/UX] 文言の `Localizable.strings` 化、A11y 対応。
- [ログ] `print` 排除と `Logger` への置換。

---

以上です。実装は行っていないため、必要に応じて優先タスクから着手できるよう提案を粒度化しました。必要なら個別課題のチケット化（タイトル/背景/受け入れ条件/影響範囲）もお手伝いします。

