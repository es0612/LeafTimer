# App Store レビュー誘導の導入 — 設計ドキュメント

- **対象 Issue:** [#3 レビューしてもらう動線を作る](https://github.com/es0612/LeafTimer/issues/3)
- **作成日:** 2026-05-12
- **対象アプリ:** LeafTimer (Bundle ID: `jp.ema.LeafTimer`)

## Context（背景）

LeafTimer は iOS 向けのポモドーロタイマーアプリ。現在 App Store 上での評価獲得導線がなく、`SKStoreReviewController` も `UIApplication.shared.open` ベースの手動導線も未実装である。ユーザがアプリを継続利用して達成感を得ているタイミングでレビュー依頼を出すことで、サクラのない自然なレビュー獲得を目指す。

## 決定事項サマリ

| 項目 | 決定内容 |
|---|---|
| トリガー条件 | 累計ポモドーロ完了が **5 / 20 / 50 回** を初めて超えたとき |
| 表示瞬間 | **ワーク完了→ブレイク突入** の瞬間（`countWork()` 加算直後） |
| 手動導線 | 設定画面に「アプリを評価する」リンク（App Store の review ページへ遷移） |
| アーキ | プロトコル分離 + DI（既存 `UserDefaultsWrapper`/`AudioManager`/`TimerManager` のパターンを踏襲） |
| 永続化 | `UserDefaults` (既存の `LocalUserDefaultsWrapper`、Int 型のみで対応可能) |
| 既存ユーザのマイグレーション | 不要（累計0からカウント開始、UI 表示は無いので影響なし） |

## アーキテクチャ

### 新規/編集ファイル

```
app/LeafTimer/
├── Components/
│   ├── ReviewRequestPolicy.swift          (新規) 閾値判定の純粋ロジック
│   ├── StoreKitReviewRequester.swift      (新規) SKStoreReviewController + URL ラッパ
│   └── UserDefaultItem.swift              (編集) ケース追加
├── ViewModel/
│   └── TimerViewModel.swift               (編集) countWork() に判定差し込み・DI 引数追加
└── View/Settings/
    └── AboutSettingsSection.swift         (新規) 「アプリを評価」リンクの新セクション
```

`EnhancedSettingView.swift` には `AboutSettingsSection(viewModel:)` を `ResetSettingsSection` の直前に挿入する1行を追加。

### プロトコル設計

```swift
// 純粋ロジック（副作用なし、テスト容易）
protocol ReviewRequestPolicy {
    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool
}

struct ThresholdReviewRequestPolicy: ReviewRequestPolicy {
    static let thresholds = [5, 20, 50]

    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool {
        Self.thresholds.contains { threshold in
            lastRequestedCount < threshold && totalCount >= threshold
        }
    }
}

// 副作用ラッパ（StoreKit / UIApplication 呼び出し）
protocol ReviewRequesting {
    func requestReview()
    func openAppStoreReviewPage()
}

final class StoreKitReviewRequester: ReviewRequesting {
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    func openAppStoreReviewPage() {
        // App ID は本リリース後に確定するため、Info.plist の LeafTimerAppStoreID キーから読む
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "LeafTimerAppStoreID") as? String,
              let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") else { return }
        UIApplication.shared.open(url)
    }
}
```

## データモデル

`UserDefaultItem` に2ケース追加:

```swift
enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration
    case workingSound
    case breakSound
    case totalPomodoroCount             // ★ 新規: 累計ポモドーロ完了数
    case lastReviewRequestedCount       // ★ 新規: 最後にレビュー要請した時点の totalCount
}
```

両方 `Int` 型、既存の `LocalUserDefaultsWrapper.saveData(key:value:Int)` で読み書き可能。**型拡張は不要**。

## データフロー

### 自動トリガー

```
TimerViewModel.timeBecomeZero()
  └── switchBreakState()
        └── else 分岐（ワーク→ブレイク）
              ├── breakState = true
              ├── audioManager.finish()
              └── countWork()
                    ├── todaysCount += 1                            (既存)
                    ├── userDefaultWrapper.saveData(today, …)       (既存)
                    ├── totalPomodoroCount += 1                     ★
                    ├── userDefaultWrapper.saveData(total, …)       ★
                    └── requestReviewIfNeeded()                     ★
                          ├── policy.shouldRequest(total, last)
                          │   ├─ true  → reviewRequester.requestReview()
                          │   │           lastReviewRequestedCount = total
                          │   │           userDefaultWrapper.saveData(…)
                          │   └─ false → 何もしない
```

### 手動トリガー

```
EnhancedSettingView
  └── AboutSettingsSection
        └── 「アプリを評価する」行をタップ
              └── reviewRequester.openAppStoreReviewPage()
                    └── UIApplication.shared.open(App Store URL)
```

### TimerViewModel への DI 追加

```swift
init(
    userDefaultWrapper: UserDefaultsWrapper,
    audioManager: AudioManager,
    timerManager: TimerManager,
    reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),    // ★ 新規
    reviewRequester: ReviewRequesting = StoreKitReviewRequester()          // ★ 新規
) { ... }
```

デフォルト引数で本番実装を提供することで、既存呼び出し箇所（`TimerView`, テスト等）への破壊的変更を回避する。

## エラー処理 & 制約

| ケース | 挙動 |
|---|---|
| SKStoreReviewController が Apple 側制限で表示拒否 | サイレントに無視。`lastRequestedCount` は **更新する**（再試行しないことで UX を守る） |
| App Store URL が開けない（極端ケース） | 失敗ログ出力のみ、ユーザへのエラー表示なし |
| UserDefaults 書き込み失敗 | 既存実装と同様、`synchronize()` の戻り値は無視 |
| 同一更新で複数閾値跨ぎ（例: 4 → 一気に 20） | `contains { lastRequested < th && total >= th }` で1回の呼び出しに集約。再要請しない |
| `LeafTimerAppStoreID` 未設定（開発ビルド） | `openAppStoreReviewPage()` は早期 return。クラッシュなし |

## テスト戦略

### ユニットテスト（Quick/Nimble）

**新規 spec**: `ReviewRequestPolicySpec.swift`
- `shouldRequest(4, 0)` → false
- `shouldRequest(5, 0)` → true
- `shouldRequest(5, 5)` → false（既に要請済み）
- `shouldRequest(20, 5)` → true
- `shouldRequest(20, 20)` → false
- `shouldRequest(51, 50)` → false（再要請しない）
- `shouldRequest(50, 5)` → true（複数閾値跨ぎは1回）
- `shouldRequest(1000, 50)` → false（最大閾値超過後は出ない）

**既存 spec 拡張**: `TimerCoreLogicSpec.swift`
- 新規 `MockReviewRequester` を注入し、`switchBreakState()` を以下の状況で呼び出して spy で検証:
  - 累計 4 → 5 になる遷移で `requestReview()` が1回呼ばれる
  - 累計 5 → 6 では呼ばれない
  - 設定: `totalPomodoroCount` 初期値を Mock UserDefaults で制御

### 統合テスト（手動）

- TestFlight / 実機で「自動レビュー表示が有効化」されることを確認
- iOS 「設定 > Apple Account > メディアと購入 > レビュー」もしくは シミュレータの Erase で表示制限をリセットして繰り返し検証
- 設定画面の「アプリを評価する」リンクで App Store の review ページが正しく開くか

### スコープ外

- SKStoreReviewController 自体の動作確認（Apple の実装を信頼）
- App Store URL の有効性（リリース時に確認）

## 重要ファイル一覧

| パス | 操作 |
|---|---|
| `app/LeafTimer/Components/ReviewRequestPolicy.swift` | 新規（protocol + 実装） |
| `app/LeafTimer/Components/StoreKitReviewRequester.swift` | 新規 |
| `app/LeafTimer/Components/UserDefaultItem.swift` | 編集（case 2つ追加） |
| `app/LeafTimer/ViewModel/TimerViewModel.swift` | 編集（init 引数、countWork） |
| `app/LeafTimer/View/Settings/AboutSettingsSection.swift` | 新規 |
| `app/LeafTimer/View/EnhancedSettingView.swift` | 編集（1行追加） |
| `app/LeafTimer/Info.plist` | 編集（`LeafTimerAppStoreID` キー追加。値は本リリース後に設定） |
| `app/LeafTimerTests/ReviewRequestPolicySpec.swift` | 新規 |
| `app/LeafTimerTests/MockReviewRequester.swift` | 新規 |
| `app/LeafTimerTests/TimerCoreLogicSpec.swift` | 編集（テスト追加） |

## オープン項目（実装着手前に解決）

- **App Store ID の決定**: 現在ストア未掲載または ID 未確定の場合、`Info.plist` の `LeafTimerAppStoreID` キーは追加不要（`StoreKitReviewRequester.openAppStoreReviewPage()` が早期 return するため、手動評価リンクは無効になるだけでクラッシュなし）。ID が判明した時点で `Info.plist` に追加すれば手動導線が有効化される。
  - 開発ビルド時の挙動: 設定画面の「アプリを評価する」行は **表示する** が、タップしても何も起きない（クラッシュなし、ログのみ）。本リリース後の有効化を前提とする。
