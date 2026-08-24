# Issue #120: kill 後の stale 通知チェーン掃除 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** タイマー稼働中にアプリを kill → 再起動した後、旧プロセスが予約した通知チェーン (最大 6 本中の残り) が届き続ける問題を、起動時の `cancelAll()` 配線で解消する。

**Architecture:** (1) `TimerViewModel.init` で無条件に `notificationScheduler.cancelAll()` を呼ぶ (稼働状態の復元は spec スコープ外のため init 時点では常に非稼働 = pending は常に stale)。(2) `DefaultNotificationScheduler.cancelAll()` に `lastEntries = []` (許可ダイアログ応答と Stop の sub-second レースによるチェーン復活防止) と `removeDeliveredNotifications` (停止後に通知センターへ残る配送済みバナーの掃除、issue 本文 M-1) を同梱する。

**Tech Stack:** Swift / XCTest (spy ベース)。`DefaultNotificationScheduler` は既存方針どおり unit test 対象外 (thin wrapper、Simulator 実地確認で代替 — ファイル先頭コメント参照)。

**Spec:** Issue #120 本文 + コメント (https://github.com/es0612/LeafTimer/issues/120) が仕様。別途 spec doc は無し。

## Global Constraints

- ビルド/テストは `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests`。成功判定は `** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` の不在 (exit code ではない)。Bash timeout は 600000ms。
- 新規 Swift ファイルは作らない (既存ファイルの修正のみ) → `make sort` 不要。
- default branch は **master**。作業ブランチは `feature/120-stale-notification-cleanup`。
- **スコープ宣言 (PR 本文にも記載):** 本修正が直すのは「kill 後に**再起動した**場合」のみ。kill 後一度も開かなければ通知 2〜5 本目は依然届く — これは spec (#54) が「kill 後も通知が届く」をバックグラウンド進行の利点として受容した設計どおりで、本 issue のスコープ外。

---

### Task 1: TimerViewModel.init で cold start 時に cancelAll を配線

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift` (init 末尾、88 行目付近の NotificationCenter.addObserver の直前)
- Test: `app/LeafTimerTests/TimerNotificationIntegrationTests.swift`

**Interfaces:**
- Consumes: `NotificationScheduler.cancelAll()` (既存 protocol メソッド)
- Produces: 「init 直後は `cancelAllCallCount == 1`」という新しい観測可能仕様。既存テスト `testStopCancelsChain` はこの分を含む前提に改修される。

**設計メモ (実装者向け):**
- init での呼び出しは**無条件**でよい。稼働状態の復元機能は存在せず (spec スコープ外)、init 時点で `executeState` は常に `false`。つまり旧プロセスの pending 通知は常に stale。
- 本番の live な `TimerViewModel` 生成箇所は `AppDelegate.didFinishLaunching` の 1 箇所のみ (確認済み)。`CircleButton.swift` / `TimerView.swift` 内の生成は PreviewProvider 用で本番パスに影響しない。

- [ ] **Step 1: 失敗するテストを書く**

`TimerNotificationIntegrationTests.swift` に新テストを追加し、既存 `testStopCancelsChain` を「差分アサート」に改修する (init 分の +1 に依存しない書き方にして将来の init 変更にも耐える):

```swift
    // Issue #120: cold start では旧プロセスの予約チェーンが残りうるため、
    // init (稼働状態を復元しない) 時点で cancelAll して stale 通知を掃除する
    func testInitCancelsStaleNotificationChain() {
        let clock = FakeClock()
        let (_, spy, _, _) = makeViewModel(clock: clock)

        XCTAssertEqual(spy.cancelAllCallCount, 1)
    }
```

既存 `testStopCancelsChain` (47〜55 行目) を以下に置換:

```swift
    // 停止 → cancelAll (init 時の cold start 掃除分とは別に +1)
    func testStopCancelsChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        let countAfterStart = spy.cancelAllCallCount

        vm.onPressedTimerButton()

        XCTAssertEqual(spy.cancelAllCallCount, countAfterStart + 1)
    }
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests` (timeout 600000)
Expected: `testInitCancelsStaleNotificationChain` が FAIL (`XCTAssertEqual failed: ("0") is not equal to ("1")`)。`** TEST FAILED **` マーカーが出る。予測失敗値 (0 ≠ 1) と実際の失敗値が一致することを確認してから次へ。

注: `onPressedTimerButton` の start 分岐は `scheduleChain` 経由でしか cancel しない (spy では別カウント) ため、改修後の `testStopCancelsChain` は実装前でも PASS する (countAfterStart = 0 → stop で 1)。RED になるのは新テストのみ、で正しい。

- [ ] **Step 3: 最小実装**

`TimerViewModel.swift` の init 内、`// Issue #54: suspend 中に跨いだフェーズを...` コメント (88 行目) の直前に挿入:

```swift
        // Issue #120: 稼働状態は復元しない (spec スコープ外) ため、cold start 時点で
        // 旧プロセスが予約した通知チェーンは常に stale。起動時に掃除する。
        notificationScheduler.cancelAll()
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests` (timeout 600000)
Expected: `** TEST SUCCEEDED **` あり / `** TEST FAILED **` なし。

- [ ] **Step 5: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/ViewModel/TimerViewModel.swift app/LeafTimerTests/TimerNotificationIntegrationTests.swift && git commit -m "fix(#120): 起動時に cancelAll して kill 前の stale 通知チェーンを掃除"
```

---

### Task 2: DefaultNotificationScheduler.cancelAll に lastEntries クリアと配送済み削除を同梱

**Files:**
- Modify: `app/LeafTimer/Components/DefaultNotificationScheduler.swift:59-63` (`cancelAll()`)

**Interfaces:**
- Consumes: Task 1 と独立 (protocol 変更なし)。
- Produces: `cancelAll()` の強化版セマンティクス — pending 削除 + `lastEntries` クリア + delivered 削除。

**設計メモ (実装者向け):**
- このクラスは**意図的に unit test 対象外** (ファイル先頭コメント: thin wrapper、Simulator 実地確認で代替)。injectability のためのリファクタは**しない**こと。本 Task はテスト無しのコード変更 + レビューで担保する。TDD ギャップは既存方針どおりで許容 (レビュー時に指摘不要)。
- `lastEntries = []` の目的 (issue コメント): 初回許可ダイアログ応答と Stop タップが交錯する sub-second レースで、`requestAuthorizationIfNeeded` の completion が停止済みチェーンを `addRequests(for: lastEntries)` で復活させるのを防ぐ。cancelAll 済みなら completion は空配列で no-op になる。
- 呼び出し順の注意: `scheduleChain` は `cancelAll()` → `lastEntries = entries` の順 (27〜28 行目)。この順序のおかげで cancelAll 内のクリアが直後の代入で上書きされ、既存の再予約フローは壊れない。**順序を入れ替えないこと。**
- `removeDeliveredNotifications` の副作用: `scheduleChain` → `cancelAll` 経由なので、停止時だけでなく再予約時 (foreground 復帰 / 設定変更 / フェーズ切替) にも配送済みバナーが通知センターから消える。これは**意図した挙動** — ユーザーがアプリに戻った時点で stale な「終了しました」バナーに価値は無い (issue 本文 M-1 の解決)。

- [ ] **Step 1: 実装**

`cancelAll()` (59〜63 行目) を以下に置換:

```swift
    func cancelAll() {
        // Issue #120: 許可ダイアログ応答と Stop の交錯レースで completion が
        // 停止済みチェーンを復活させないよう、保持中 entries も同時に破棄する
        lastEntries = []
        let identifiers = (0..<(NotificationChainBuilder.cycles * 2))
            .map { Self.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        // Issue #120 (M-1): 配送済みバナーも通知センターから掃除する。
        // scheduleChain 経由でも呼ばれるため、再予約時に stale バナーが消えるのは意図した挙動
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
```

- [ ] **Step 2: 回帰が無いことを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests` (timeout 600000)
Expected: `** TEST SUCCEEDED **` あり / `** TEST FAILED **` なし (このクラスは unit test 対象外だが、ビルドと既存テストの回帰確認は必須)。

- [ ] **Step 3: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/Components/DefaultNotificationScheduler.swift && git commit -m "fix(#120): cancelAll で lastEntries クリアと配送済み通知削除を同梱"
```

---

### Task 3: precheck + PR 作成

**Files:**
- なし (検証と PR のみ)

- [ ] **Step 1: precheck**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make precheck`
Expected: エラーなし (新規ファイル無しなので orphan は出ないはず)。

- [ ] **Step 2: 既存 PR 確認 + push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/120-stale-notification-cleanup
```

既存 PR が無いことを確認してから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git push -u origin feature/120-stale-notification-cleanup
```

- [ ] **Step 3: PR 作成**

PR 本文には以下を必ず含める:
- Closes #120
- 修正 3 点の要約 (init cancelAll / lastEntries クリア / removeDeliveredNotifications)
- **スコープ宣言**: 「本修正が直すのは kill 後に再起動した場合のみ。kill 後一度も開かなければ通知は届き続けるが、これは #54 spec が受容した設計 (バックグラウンド進行の利点) でありスコープ外」
- 再予約時にも配送済みバナーが消える副作用が意図であることの一言

- [ ] **Step 4: CI 待ち → merge**

`gh pr checks <PR>` の URL 末尾から run ID を取り、**フォアグラウンドの `gh run watch <run-id> --interval 30`** で待つ (ポーリング sleep・バックグラウンド通知は使わない)。merge は必ず `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで実行する。
