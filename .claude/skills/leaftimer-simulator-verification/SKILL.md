---
name: leaftimer-simulator-verification
description: Use when verifying LeafTimer screens in the iOS Simulator — finding which screen shows a View, getting the built .app path, checking the 4 background states (work/break × light/dark), Dynamic Type sizes, onboarding/ATT bypass, tapping with cliclick, notification banner timing, animation still/playing checks, and comparing screenshots with the old store screenshots.
---

# LeafTimer Simulator 検証

CLAUDE.md ルール 12 / 30 / 31 / 32 / 42 の実体。汎用手順は global skill `ios-simulator-app-verification` / `ios-simulator-locale-testing`、ここは LeafTimer 固有の値と罠だけを書く。各項目の事故経緯は `docs/claude-lessons-archive.md` の「#171 で CLAUDE.md から退避したルール全文」節にある。

## 観測する前に (ルール 12)

- UI 要素の有無を観測する前に、その View の live 参照元を grep して「どの画面に遷移すれば見えるか」を確定させる。

## ビルド成果物のパス (ルール 30)

- `.app` を `find app/build` で探さない (古い残骸を掴み silent に誤検証する)。実パスは次で取る:

  `xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'`

- 同名 Simulator が複数世代ある機種 (iPhone SE 等) では `name=...,OS=latest` が曖昧マッチで exit 70 になる。`xcrun simctl list devices available` で UDID を引き、`-destination "platform=iOS Simulator,id=<UDID>"` で指定する。

## 背景 4 状態と overlay (ルール 31)

- トップ画面 (`TimerView`) の背景は work/break × light/dark の 4 状態 (`TimerViewModel+extensions.swift` の `getBackgroundColor`)。
- overlay UI はハードコード色でなく `.ultraThinMaterial` + semantic color を使う。
- 4 状態 (× ロケール) を目視検証する: `xcrun simctl ui <SIM> appearance light|dark` + 起動引数 `-AppleLanguages`。

## 画面の準備 (ルール 32)

- **起動済みの Simulator は使わない。** 別のリポの session が同じ Simulator で UI テストやストアスクショを撮っていることがある。2026-10-25 #188 では、OtetsudaiCoin の `xcodebuild test` が使っていた iPhone 17 Pro に、こちらが appearance・content_size・Reduce Motion を書き込み、相手の撮影を汚した。撮影や検証には `xcrun simctl create leaftimer-<issue>-<機種> "<機種>"` で専用の Simulator を作り、UDID を指定して使う。`booted` は複数台が起動していると曖昧になるので、`simctl ui` / `spawn` でも UDID を書く。始める前に `pgrep -fl 'xcodebuild test'` で、他の session のテストの destination を確かめる。`make unit-tests` の既定 (`iPhone 17`) を使うことは問題ない
- Dynamic Type: `xcrun simctl ui <UDID> content_size <値>`。標準域 `extra-small`〜`extra-extra-extra-large`、拡張域 `accessibility-medium`〜`accessibility-extra-extra-extra-large` (= AX5)。
- onboarding: install 直後の初回起動は onboarding の fullScreenCover が最前面に出る。他画面を撮る時は、起動引数 `-hasSeenOnboarding YES` を `simctl launch` に渡すのが確実 (引数ドメインが最優先。永続しないので、次に引数なしで起動すると onboarding が戻る)。onboarding 自体は引数なしの fresh install で撮る。
- `xcrun simctl spawn <UDID> defaults write jp.ema.LeafTimer <key> …` が書くのはアプリのコンテナではなく、device 側の `data/Library/Preferences/jp.ema.LeafTimer.plist`。アプリからは **コンテナに同じキーが無い時だけ** 読める。コンテナに値があればそちらが勝つので、一度アプリが書いたキーは spawn で上書きできない (2026-10-24 #168 で実測: 書く前の初回起動では効き、seed 後の false 書き込みは効かない)。コンテナの plist の直書きは cfprefsd に戻される。
- 画面を直接開く: 起動引数 `-InitialScreen=settings` / `history` / `timePreview` (`TimerView.swift` の DEBUG フック)。葉パターンは `-LeafPattern=small|mid|big` で強制できる。 break 状態の背景は `-BreakState` で開ける (#63)。
- ATT: fresh Simulator では初回起動時に ATT ダイアログが最前面に出て、simctl では tap も TCC.db 直書きもできない。起動前に `applesimutils --byId <UDID> --bundle jp.ema.LeafTimer --setPermissions "userTracking=YES" --restartSB` で付与する (brew 導入済み。再導入時は `brew trust wix/brew` が必要)。
- 設定画面下部はスクロール手段が無く未検証 (#109)。

## tap の自動化 (ルール 32)

- simctl に tap は無い。cliclick (brew 導入済み) で Simulator ウィンドウ座標を直接クリックする (osascript の System Events click は -25204 で不可)。2026-10-25 #188 では `cliclick c:<x>,<y>` が届かず、`cliclick dd:<x>,<y> w:150 du:<x>,<y>` (押してから 150ms 後に離す) で届いた。押しても変化しない時は、まずボタンの中央を押す対照実験で「クリックが届いているか」を確かめる
- クリックの前に、Simulator を最前面のアプリにし (`tell application "Simulator" to activate`)、自分の機種のウィンドウを `perform action "AXRaise" of (first window whose name starts with "<機種名>")` で前に出す。`get name of window 1` で自分のウィンドウが先頭かを確かめる。複数の Simulator のウィンドウや別アプリ (ターミナル) が重なっていると、クリックが別の Simulator や別アプリに当たる
- 座標は `osascript -e 'tell application "System Events" to tell process "Simulator" to get {name, position, size} of every window'` からデバイス座標比で換算する。`screencapture -x -R<x>,<y>,<w>,<h>` でウィンドウを撮って、狙う位置を目で確かめる。cliclick drag によるスクロールは未検証
- Mac の画面がロック中だと、`screencapture` は真っ黒になり、Simulator のウィンドウ数は 0 と返る。そのときクリックは確かめられないので、ロックの解除をオーナーに頼む

## 撮影のタイミングと判定 (ルール 32)

- 通知バナーは配送後約 10 秒で消える。fire 時刻 +2 秒に照準した background sleep → screenshot で撮る。
- アプリ復帰直後のスクショは遷移アニメ中の旧フレームを掴む。数秒後の 2 枚目で確定判定する。
- 見た目不変をピクセル差分で確かめる時は、起動前に `xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` で葉の GIF を止める。同一ビルド 2 回撮影で全画面 DIFF 0 になる (2026-10-18 #63、off では葉の領域だけ DIFF が出る)。
- 色・スタイルの集約など見た目不変のリファクタは、変更前後で同じ操作のスクショを全テーマ状態 (work/break/履歴 × light/dark) で撮り、全画面 DIFF 0 で受け入れる。差分が出たら、まず旧コードの色空間 (Generic RGB と sRGB) を疑い、次に換算後の小数の丸め桁を疑う (#63 では 4 桁で 1 階調ずれ、6 桁にして DIFF 0)。比較コマンドが効いているかは、設定を戻して DIFF が出ることで逆方向も確かめる。
- 起動画面 (LaunchScreen) は `simctl uninstall` してもキャッシュが残り旧画像が出る。アセット変更後の起動画面は未使用の新規 Simulator (`simctl create`) で撮る (2026-10-18 #93)。
- アニメの静止/再生判定は 1〜2 秒間隔のスクショ複数枚の md5 比較で行い、「静止 = 全一致」と「再生 = 不一致」の両方向を必ず実証する (片方向だけでは検出手法自体の故障と区別できない)。
- スクショの目視は縮小した一覧画像で済ませず、1 枚ずつ原寸で下端まで見る (設定画面下端の AdMob テスト広告を見落とした実績がある)。

## 既存デザインか回帰か (ルール 42)

- レイアウト変更後のスクショで迷ったら、`docs/ver1_2/screen/` の旧ストア掲載スクショ (6.7 インチ / iPad 別) と突き合わせて判定する。ユーザー確認を挟まず即断できる。
