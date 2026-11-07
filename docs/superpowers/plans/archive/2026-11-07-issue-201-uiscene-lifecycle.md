# UIScene ライフサイクル対応 Implementation Plan (#201)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS / iPadOS 27.2 で起動直後に落ちないよう、LeafTimer を UIScene ライフサイクルに対応させ、1.6.2 を build 52 以降で再提出できる状態にする。

**Architecture:** `Info.plist` に `UIApplicationSceneManifest` (単一 window scene) を宣言し、window・root view・`AdsBootstrapper` の起動を新しい `SceneDelegate` へ移す。background task の開始・終了は `BackgroundTaskKeeper` に切り出して `sceneWillResignActive` / `sceneDidBecomeActive` から呼ぶ。`AppDelegate` には Firebase と DEBUG のスクショ用 seed だけを残す。

**Tech Stack:** Swift / UIKit + SwiftUI (`UIHostingController`) / XCTest (test host = LeafTimer.app)

**Spec:** GitHub issue #201 本文 (bug fix のため spec doc は作らない)。根拠のクラッシュログ・Xcode の版は #201 と #197 のコメントにある。

## Global Constraints

- `MARKETING_VERSION` は 1.6.2 のまま。1.6.2 は未承認 (却下) なので train は開いている。`CURRENT_PROJECT_VERSION` も触らない (Xcode Cloud が採番する)
- Swift ファイルの追加は `make add-file FILE=… TARGET=app|test` (ルール 28)。pbxproj を手で編集しない
- 新しいテストは XCTest (ルール 43)
- manifest のキー (Apple ドキュメント JSON で確認済み、2026-11-07): `UIApplicationSceneManifest` → `UIApplicationSupportsMultipleScenes` (false) と `UISceneConfigurations` → `UIWindowSceneSessionRoleApplication` → 配列 1 件 `{ UISceneConfigurationName: "Default Configuration", UISceneDelegateClassName: "$(PRODUCT_MODULE_NAME).SceneDelegate" }`
- background task の振る舞い (#70: expiration handler で self を強参照しない / #128: 未登録なら end しない) は変えない
- PR 本文は `Refs #201` / `Refs #197` (受け入れは Xcode Cloud のビルドと再審査の後)

## Review Focus

1. 端末の回転・iPad の Split View / Stage Manager でサイズが変わる → scene は 1 つのまま、表示が崩れない (`UIApplicationSupportsMultipleScenes = false` で 2 つ目の window を作らせない)
2. タイマー動作中にホームへ戻る → これまでどおり background task が始まり、戻ると終わる (scene を使うと AppDelegate の `applicationWillResignActive` / `applicationDidBecomeActive` は呼ばれない)
3. バックグラウンドから戻る → `TimerViewModel` の `UIApplication.willEnterForegroundNotification` による補正が動く (scene 化しても UIApplication の通知は届く)
4. 初回起動 → onboarding の fullScreenCover と、その後の UMP / ATT ダイアログが出る (`AdsBootstrapper` に渡す view controller が nil にならない)
5. `-InitialScreen` などの DEBUG 起動引数と `DebugStoreScreenshot.seedIfRequested()` が、root view を作る前に効いている

1 と 3〜5 はユニットテストでは押さえられないので、Task 2 の Simulator 検証で見る。2 は Task 1 のテストで押さえる。

---

### Task 1: BackgroundTaskKeeper と SceneDelegate、manifest

**Files:**
- Create: `app/LeafTimer/App/BackgroundTaskKeeper.swift`
- Create: `app/LeafTimer/App/SceneDelegate.swift`
- Modify: `app/LeafTimer/App/AppDelegate.swift` (window・root view・Ads 起動・2 つの lifecycle メソッド・`backgroundTaskID` を削除)
- Modify: `app/LeafTimer/Info.plist` (`UIApplicationSceneManifest` を追加)
- Test: `app/LeafTimerTests/SceneLifecycleTests.swift`

**Interfaces:**
- Produces:
  - `protocol BackgroundTaskRunning: AnyObject { func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier; func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) }` と `extension UIApplication: BackgroundTaskRunning {}`
  - `final class BackgroundTaskKeeper { init(runner: BackgroundTaskRunning); private(set) var taskID: UIBackgroundTaskIdentifier; func begin(); func end() }`
  - `final class SceneDelegate: UIResponder, UIWindowSceneDelegate { var window: UIWindow?; var backgroundTaskKeeper: BackgroundTaskKeeper }` (既定値は `BackgroundTaskKeeper(runner: UIApplication.shared)`)

- [ ] **Step 1: テストを書く** (`SceneLifecycleTests.swift`。`SpyBackgroundTaskRunner` は同じファイル内に置き、begin 回数・end に渡された ID・最後の expiration handler を記録する)
  - `test_infoPlist_declaresSingleWindowSceneWithSceneDelegate`: `Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest")` が辞書、`UIApplicationSupportsMultipleScenes == false`、`UIWindowSceneSessionRoleApplication` の配列が 1 件、その `UISceneDelegateClassName` を `NSClassFromString` した結果が `SceneDelegate.self`
  - `test_keeper_begin_thenEnd_endsSameTaskAndResets`: begin → end で、runner の end に begin が返した ID が 1 回渡り、`taskID == .invalid`
  - `test_keeper_end_withoutBegin_doesNothing` (#128): end だけでは runner の end が 0 回
  - `test_keeper_expirationHandler_endsTask` (#70): begin 後に記録した handler を呼ぶと end が 1 回、`taskID == .invalid`
  - `test_sceneDelegate_resignActive_begins_and_becomeActive_ends`: `SceneDelegate()` に spy runner の keeper を入れ、`UIApplication.shared.connectedScenes.first!` を渡して `sceneWillResignActive` → `sceneDidBecomeActive` を呼ぶと、begin 1 回・end 1 回
- [ ] **Step 2: `make add-file FILE=LeafTimerTests/SceneLifecycleTests.swift TARGET=test` (app/ で実行) → `make unit-tests` が失敗することを確かめる**
  Expected: `SceneDelegate` / `BackgroundTaskKeeper` が無いのでコンパイルエラー (`cannot find 'SceneDelegate' in scope`)。
- [ ] **Step 3: 実装する**。2 つの新ファイルを作って `make add-file … TARGET=app` で配線し、上の Interfaces どおりに書く
  - `SceneDelegate.scene(_:willConnectTo:options:)`: `guard let windowScene = scene as? UIWindowScene`。`UIWindow(windowScene:)` を作り、いまの `AppDelegate` と同じ順で `LocalUserDefaultsWrapper` → `TimerView(...)` → `UIHostingController` → `makeKeyAndVisible()` を行う。その後、`DispatchQueue.main.async { [weak self] in AdsBootstrapper.shared.bootstrap(from: self?.window?.rootViewController, completion: nil) }`
  - `sceneWillResignActive` → `backgroundTaskKeeper.begin()`、`sceneDidBecomeActive` → `backgroundTaskKeeper.end()`
  - `AppDelegate`: `FirebaseApp.configure()` と `#if DEBUG DebugStoreScreenshot.seedIfRequested()` だけを残す (`didFinishLaunching` は scene の接続より前に呼ばれるので、seed の順序は変わらない)。既存のコメント (#57 / #55) は移した先に一緒に移す
  - `Info.plist`: Global Constraints の manifest を `UILaunchStoryboardName` の近くに足す
- [ ] **Step 4: `make tests` が通ることを確かめる**
  Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tee <workspace>/task1.log | tail -5`
  Expected: `** TEST SUCCEEDED **` があり、`** TEST FAILED **` が無い。新しい 5 件が通る。
- [ ] **Step 5: mutation で 1 件ずつ RED になることを確かめる (ルール 8)**。どれも確かめたら戻す。
  - manifest から `UISceneDelegateClassName` を外す → `test_infoPlist…` が落ちる
  - `sceneWillResignActive` の `begin()` を消す → `test_sceneDelegate…` が落ちる
  - keeper の end の `guard taskID != .invalid` を消す → `test_keeper_end_withoutBegin…` が落ちる
- [ ] **Step 6: commit** (path を指定して stage する。`git diff | cat -e` で行末を確かめる)

```bash
git add app/LeafTimer/App/BackgroundTaskKeeper.swift app/LeafTimer/App/SceneDelegate.swift app/LeafTimer/App/AppDelegate.swift app/LeafTimer/Info.plist app/LeafTimerTests/SceneLifecycleTests.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "fix(#201): UIScene ライフサイクルに対応し iOS 27.2 の起動クラッシュを直す"
```

### Task 2: Simulator で起動ログ・成果物・画面を確かめる

**Files:** なし (検証だけ。結果は PR 本文に書く)

- [ ] **Step 1: ビルドした `.app` の Info.plist を読む** (ルール 30 の `BUILT_PRODUCTS_DIR`)
  Run: `plutil -p "$P/LeafTimer.app/Info.plist" | grep -A8 UIApplicationSceneManifest`
  Expected: `UISceneDelegateClassName => "LeafTimer.SceneDelegate"` と `UIApplicationSupportsMultipleScenes => false`
- [ ] **Step 2: 起動ログの runtime-issue が消えたことを確かめる**。iPhone (`leaftimer-199-iphone17`, iOS 26.5) と、新しく作る `leaftimer-201-ipadair11m3` (iPad Air 11-inch (M3), iOS 26.5) の両方で行う
  Run: install → `simctl launch … -hasSeenOnboarding YES` → 8 秒後に `log show --last 1m --predicate 'process == "LeafTimer" AND eventMessage CONTAINS "lifecycle will soon be required"'`
  Expected: 0 件。修正前の build では 1 件出た (2026-11-07 実測) ので、両方向を確かめたことになる
- [ ] **Step 3: 画面を撮って原寸で見る** (iPhone / iPad。トップ画面の葉とタイマー、iPad は縦横 2 枚)。続けて Review Focus 4 のために、引数なしの fresh install で onboarding が出ることを 1 枚撮る
- [ ] **Step 4: Review Focus 2・3 の目視**。タイマーを開始 → ホームへ → 10 秒後に戻ると残り時間が進んでいる (`willEnterForeground` の補正)。ログに `beginBackgroundTask` の失敗や警告が出ていない

### Task 3: リリース手順書を直し、plan を archive へ移す

**Files:**
- Modify: `docs/RELEASE_v1.6.2.md` (build 51 の行)
- Move: この plan → `docs/superpowers/plans/archive/`

- [ ] **Step 1: `docs/RELEASE_v1.6.2.md` の build 51 の記述に注記を足す**: 「build 51 は iPadOS 27.2 の起動クラッシュで却下 (2026-11-07、#201)。再提出は #201 の merge 後に Xcode Cloud が作るビルドで、番号は TestFlight で確かめてから書く」。What's New は変えない (ユーザーに見える変化が無いので、「細かな改善」は書かない)
- [ ] **Step 2: `git mv` で plan を archive へ移し、`make tests` (plan-docs-check を含む) が通ることを確かめて commit する**
