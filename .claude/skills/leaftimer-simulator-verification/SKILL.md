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

- Dynamic Type: `xcrun simctl ui booted content_size <値>`。標準域 `extra-small`〜`extra-extra-extra-large`、拡張域 `accessibility-medium`〜`accessibility-extra-extra-extra-large` (= AX5)。
- onboarding: install 直後の初回起動は onboarding の fullScreenCover が最前面に出る。他画面を撮る前に `xcrun simctl spawn booted defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true`。onboarding 自体を撮る時は `defaults delete` を使う (`simctl uninstall` は ATT までリセットされるので不可)。
- 画面を直接開く: 起動引数 `-InitialScreen=settings` / `history` / `timePreview` (`TimerView.swift` の DEBUG フック)。葉パターンは `-LeafPattern=small|mid|big` で強制できる。
- ATT: fresh Simulator では初回起動時に ATT ダイアログが最前面に出て、simctl では tap も TCC.db 直書きもできない。起動前に `applesimutils --byId <UDID> --bundle jp.ema.LeafTimer --setPermissions "userTracking=YES" --restartSB` で付与する (brew 導入済み。再導入時は `brew trust wix/brew` が必要)。
- 設定画面下部はスクロール手段が無く未検証 (#109)。

## tap の自動化 (ルール 32)

- simctl に tap は無い。`cliclick c:<x>,<y>` (brew 導入済み) で Simulator ウィンドウ座標を直接クリックする (osascript の System Events click は -25204 で不可)。
- 座標は `osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of front window'` からデバイス座標比で換算する。cliclick drag によるスクロールは未検証。

## 撮影のタイミングと判定 (ルール 32)

- 通知バナーは配送後約 10 秒で消える。fire 時刻 +2 秒に照準した background sleep → screenshot で撮る。
- アプリ復帰直後のスクショは遷移アニメ中の旧フレームを掴む。数秒後の 2 枚目で確定判定する。
- アニメの静止/再生判定は 1〜2 秒間隔のスクショ複数枚の md5 比較で行い、「静止 = 全一致」と「再生 = 不一致」の両方向を必ず実証する (片方向だけでは検出手法自体の故障と区別できない)。
- スクショの目視は縮小した一覧画像で済ませず、1 枚ずつ原寸で下端まで見る (設定画面下端の AdMob テスト広告を見落とした実績がある)。

## 既存デザインか回帰か (ルール 42)

- レイアウト変更後のスクショで迷ったら、`docs/ver1_2/screen/` の旧ストア掲載スクショ (6.7 インチ / iPad 別) と突き合わせて判定する。ユーザー確認を挟まず即断できる。
