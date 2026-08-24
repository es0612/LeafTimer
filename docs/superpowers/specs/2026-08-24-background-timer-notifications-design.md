# バックグラウンド動作 + 完了通知 設計 (Issue #54)

日付: 2026-08-24 / 対象 Issue: #54

## 問題

- `UIBackgroundModes: audio` によりサウンド ON の間だけバックグラウンドでもタイマーが生存する。サウンド「なし」設定では数十秒で suspend され、tick が止まる。
- #56 の壁時計補正 (`endDate` 差分) で復帰時の残り時間は自己補正されるが、suspend 中にフェーズ終了を跨いだ場合のフェーズ切替・ポモドーロカウント・ユーザーへの気づきの手段が存在しない。
- 通知コード (`UNUserNotificationCenter`) は現状ゼロ。

## 決定事項 (ユーザー確認済み)

1. 通知は **作業終了・休憩終了の両方** で出す。
2. バックグラウンド中のフェーズ跨ぎは **自動進行** 扱い: 壁時計基準で work→break→work を跨いだ分だけ進め、完了した work はポモドーロ統計にカウントする。
3. 通知許可は **初回タイマー開始時** にリクエストする。拒否されてもタイマー機能自体は動作する。

## アプローチ選定

**採用: 案A — ローカル通知チェーン + 復帰時リコンサイル**

プロセスをバックグラウンドで生かし続けることを目指さない。OS にローカル通知の配送を委ね、アプリ状態は復帰時に壁時計から再計算する。

- タイマー開始時に endDate から先のフェーズ境界 3 往復分 (= 6 件、UN の 64 件上限に余裕) のローカル通知を予約。
- 停止時に全キャンセル。フォアグラウンド稼働中のフェーズ切替時はチェーンを再予約。
- アプリが kill されても予約済み通知は届く。

不採用案:
- 案B (無音オーディオ常時再生で suspend 回避): App Store リジェクトリスク・電池消費・ハック的。
- 案C (BGTaskScheduler / リモート push): 実行タイミング保証なし / サーバー不要アプリにオーバーキル。

## コンポーネント設計

### NotificationScheduler (新規 protocol) + DefaultNotificationScheduler (新規)

`TimerManager` / `AudioManager` と同じ DI パターン。`UNUserNotificationCenter` の wrapper。

```swift
protocol NotificationScheduler {
    func requestAuthorizationIfNeeded()
    func scheduleChain(entries: [NotificationEntry])  // (fireDate, title, body)
    func cancelAll()
}
```

- `requestAuthorizationIfNeeded()`: `.alert, .sound` を要求。結果は保持するだけで UI 分岐なし。
- `scheduleChain`: `UNCalendarNotificationTrigger` (または timeInterval trigger) で予約。identifier は固定 prefix でこのアプリの予約分のみ `cancelAll` 対象にする。

### PhaseReconciler (新規・純粋ロジック struct)

suspend 中のフェーズ進行を復帰時に一括計算する。**副作用なし・全ケース unit test 対象。**

```swift
struct PhaseReconcileResult: Equatable {
    let breakState: Bool
    let completedWorkCount: Int   // 跨いだ work フェーズ数 (統計反映用)
    let remainingSeconds: Int
    let newEndDate: Date
}

struct PhaseReconciler {
    static func reconcile(
        endDate: Date, breakState: Bool,
        workDuration: Int, breakDuration: Int, now: Date
    ) -> PhaseReconcileResult
}
```

- `now < endDate` なら跨ぎゼロ (残り秒のみ更新) — 冪等性の要。
- `now >= endDate` なら work/break を交互に消化し、跨いだ work 数を数える。

### TimerViewModel 変更

- DI に `notificationScheduler: NotificationScheduler` を追加。
- `onPressedTimerButton` 開始時: `requestAuthorizationIfNeeded()` → `scheduleChain(...)`。
- `onPressedTimerButton` 停止時: `cancelAll()`。
- `switchBreakState` (フォアグラウンド稼働中の自然切替) 時: チェーン再予約。
- `willEnterForeground` 相当のフック (`NotificationCenter.default` の `UIApplication.willEnterForegroundNotification` を VM で observe): 稼働中 (`executeState == true`) なら `PhaseReconciler.reconcile` を呼び、
  - `completedWorkCount` 回だけ `countWork()` 相当の統計反映
  - `breakState` / `currentTimeSecond` / `endDate` を結果で更新
  - チェーン再予約
- audio 生存でバックグラウンド稼働し続けたケースでは `updateTime` が進行済み → reconcile は跨ぎゼロで no-op (二重カウント防止)。

### フォアグラウンド時の通知表示

`UNUserNotificationCenterDelegate` は実装しない (デフォルト挙動 = フォアグラウンドでは通知非表示)。フォアグラウンドでは既存のサウンド/バイブが完了を伝え、バックグラウンド (audio 生存含む) では OS が通知を表示する。

## 通知文言 (xcstrings, ja/en)

| key | ja | en |
| --- | --- | --- |
| `notification.workEnd.title` | 作業おつかれさま！ | Great work! |
| `notification.workEnd.body` | 休憩しよう🍃 | Time for a break 🍃 |
| `notification.breakEnd.title` | 休憩終了！ | Break's over! |
| `notification.breakEnd.body` | 次のポモドーロを始めよう | Let's start the next Pomodoro |

追加は xcstrings-bulk-update スキルの手順に従う。

## エラー処理

- 通知許可拒否: 予約 API は呼ぶが OS 側で表示されないだけ。タイマー・リコンサイルは通知と独立に動作。
- 予約失敗 (add error): ログのみ。致命ではない。

## テスト戦略 (TDD)

1. `PhaseReconciler`: 跨ぎゼロ / work→break 1 跨ぎ / 複数往復跨ぎ / break 起点 / ちょうど境界 (`now == endDate`) の各ケース。
2. `TimerViewModel`: mock `NotificationScheduler` で開始→schedule 呼び出し・停止→cancel 呼び出し・reconcile 後の統計/状態を検証。既存の `SpyTimerManager` 等のパターンを踏襲。
3. `DefaultNotificationScheduler`: UN API の thin wrapper のため unit test 対象外 (Simulator 実機確認で代替)。

## スコープ外 (YAGNI)

- アプリ kill 後の稼働状態復元 (予約済み通知の配送は kill 後も OS が行う)
- 通知のアクションボタン / カスタムサウンド
- リモート push・サーバー連携
- 設定画面での通知 ON/OFF トグル (OS 設定に委譲)
