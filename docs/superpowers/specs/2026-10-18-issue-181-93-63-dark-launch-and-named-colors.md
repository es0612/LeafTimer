# v1.6: dark の起動画面文言 (#93) と直書き色の集約 (#63) — 設計

- Issue: #181 (v1.6 リリース) / #93 / #63
- 日付: 2026-10-18
- 状態: 実装済み (PR 作成時に archive)

## 意図

v1.5 (2026-09-27 公開) 以降、ユーザー向けのコード変更が 0 件。1.6 を出す価値として次の 2 点を入れる。

- **#93**: dark モードの起動画面で「Leaf Timer」の文言が濃緑背景に埋もれて読めない。dark の人にだけ見える不具合を直す (ユーザーに見える改善)。
- **#63**: 色が `Color(.displayP3, …)` などの直書きで 3 ファイルに散っており、過去の色可読性事故 (#26 / #39) の温床。名前付きの色に集約して、light/dark の対を 1 か所で管理できるようにする (保守性の改善、見た目は変えない)。

1.6 の配信そのものが #169 (JP ストアの旧スクショ) の解消にもなる。

## ゴール

1. dark モードの起動画面で文言が読める。light は変化なし。
2. 下表の直書き色 18 値が、ビルド対象のアセットカタログの named color 経由で描画される。
3. 1 と 2 の前後で、アプリ内画面の見た目が変わらない (ピクセル差分で確認)。
4. ビルド対象外の死んだ色定義 (14 colorset とその生成スクリプト) が repo から消え、「どれが本物の色か」で迷わない。

## 非ゴール

- 配色の刷新。未登録の 14 colorset (`WorkMode` = オレンジ等) の色は**採用しない** (ユーザー判断 2026-10-18)。
- `.blue` / `.green` / `.red` / `.gray` / `.orange` などの SwiftUI 標準色の置き換え。OS が light/dark に追従済みで、置き換えても見た目は同じため対象外。
- LaunchScreen のレイアウト変更、`splashIcon` の葉の色の変更。

## アンチゴール (技術的に動いても失敗)

- named color が実行時に解決できず、黒・透明・既定色にフォールバックする (#67 で未登録カタログに置くと黒画面になった前例)。
- light か dark のどちらかで見た目が変わる。
- 起動画面の検証で、iOS がキャッシュした旧画像を見て「直った」と判断する。

## 対象 (2026-10-18 master `66c579f` で実測)

| 場所 | 値の数 | 色空間 | light/dark |
|---|---|---|---|
| `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift` `getBackgroundColor(colorScheme:)` | 8 (work/break × light/dark × 上/下) | display P3 (`Color(.displayP3, …)`) | `colorScheme` 引数で分岐 |
| 同 `getColor1()`〜`getColor4()` (参照元: `View/Elements/CircleButton.swift:41-53`) | 8 (work/break × 4 輪) | sRGB (`Color(UIColor(red:…))`) | 分岐なし (dark も同じ値) |
| `app/LeafTimer/View/HistoryView.swift:100-103` `barColor(for:)` の count > 0 | 2 (light/dark) | sRGB (`Color(red:…)`) | `colorScheme` で分岐 |

`count == 0` の `Color.gray.opacity(…)` は標準色なので対象外。

## 決まっていること

### #93 (ユーザー判断)

- `app/LeafTimer/App/Assets.xcassets/splashIcon.imageset/` に dark appearance (`"appearances": [{"appearance": "luminosity", "value": "dark"}]`) の 2 枚目の PDF を追加する。既存 PDF は light / any 用としてそのまま残す。
- dark 用 PDF は既存 PDF の文言色だけを差し替えて作る。既存 PDF (Adobe XD 出力) のコンテンツストリームの色指定は 2 種類だけ (調査 2026-10-18):
  - 葉: `.3569 .4667 .3529` (rg/RG) → **変えない**
  - 文言: `.2353 .2353 .2627` (rg/RG) → **`0.95 0.98 0.95`** (ユーザー判断。light 背景グラデ上端と同じ淡い緑白)

### #63 (ユーザー判断)

- 見た目は変えずに集約する。named color は**ビルド対象の** `app/LeafTimer/App/Assets.xcassets` に置く (#67 の `LaunchBackground` と同じ場所)。
- ビルド対象外の `app/LeafTimer/Assets.xcassets` (14 colorset) は**この PR で削除する**。生成元の `app/bin/create_color_assets.sh` も同時に削除する (他からの参照 0 件、`/usr/bin/grep` で確認済み)。削除はルール 14 に従い、ユーザーが `! git rm -r app/LeafTimer/Assets.xcassets app/bin/create_color_assets.sh` を実行する。

### 物差し

1. **値の一致 (ユニットテスト、XCTest)**: 新しい named color ごとに、light と dark の trait で解決した値が、旧来の直書き値と同じ色空間で許容誤差 0.002 以内で一致する。名前が解決できない (nil) 場合は fail する。
2. **見た目の不変 (Simulator)**: トップ画面の 4 状態 (work/break × light/dark)、履歴画面 (light/dark) の計 6 枚を、変更前 (master) と変更後のビルドで同条件で撮り、ピクセル差分で比較する。合格基準 (私の判断): ステータスバーと GIF の矩形だけを事前に決めた座標でマスクし、**それ以外の差分画素数が 0**。0 でなければ止めて報告する。マスク領域は計画に座標で書く。
3. **#93 (Simulator)**: アプリを uninstall → install してから、dark と light で起動画面を撮る。dark で文言が読め、light は従来と同じであること。

## 実装者に任せること (私の判断を含む)

- **色名** (私の案): `WorkGradientTop` / `WorkGradientBottom` / `BreakGradientTop` / `BreakGradientBottom` / `WorkRing1`〜`WorkRing4` / `BreakRing1`〜`BreakRing4` / `HistoryBar`。カタログ直下に置くか `Colors/` フォルダにまとめるかは任せる。
- **colorset の色空間**: 元の値と同じ色空間 (グラデは display-p3、輪と履歴バーは srgb) で書く。輪は dark の値を持たない (any のみ) のが今の挙動。
- **`getBackgroundColor(colorScheme:)` の引数**: named color は環境の colorScheme で解決されるため引数は不要になる。外すか残すかは任せる。外す場合は `TimerView.swift:77` と `LeafTimerTests/ModernTimerViewSpec.swift:151,157` を合わせて直す (Quick/Nimble の既存テストは据え置き、ルール 43)。
- **Swift からの参照方法**: `Color("Name")` か、Xcode が生成するアセットシンボル (`Color(.name)`) か。生成が有効かはビルド設定を実測して決める。
- **dark 用 PDF の作り方**: 色の置換、ストリームの再圧縮、`/Length` と xref の整合をとるスクリプトは scratchpad に置き、repo には生成物の PDF だけを入れる。
- **break 状態の撮影**: break 状態に入る起動引数が無い (現在あるのは `-InitialScreen` / `-LeafPattern` / `-AutoStart` / `-SeedSampleStats` / `-HideAds`)。既存の `Debug*` 起動引数と同じ `#if DEBUG` の形で追加してよい。
- 撮影手順の詳細は skill `leaftimer-simulator-verification` に従う (ステータスバーの固定、GIF の静止、オンボーディング/ATT の回避)。

## PR の範囲 (私の判断)

- 同じ PR に `docs/RELEASE_v1.6.md` (What's New ja/en、絵文字なし、v1.5 と同じ見出し構成) を含める。
- PR の外 (merge 後にコントローラが行う): Xcode Cloud のビルド確認、ASC の 1.6 にビルドと What's New を設定 (`asc-submission-prep`、提出は人)、#179。
- 14 colorset の削除は人の操作 (`! git rm -r …`) が前提。計画では PR 作成前の人の判断点として置き、削除されていなければ PR を出さない。

## 制約

- Swift ファイルの追加は `make add-file` (ルール 28)。
- 新規テストは XCTest (ルール 43)。
- 起動画面のキャッシュ: 検証は毎回 uninstall から行う。

## 実装時の変更 (2026-10-18、実装後に追記)

- **輪 8 色の色空間**: 旧 `getColor1()`〜`getColor4()` の `Color(.init(red:…))` は `CGColor(red:…)` = Generic RGB に解決されていた。「srgb で元の値」では輪が暗くなる (初回比較でボタン 450×450 が DIFF 153308) ため、colorset には Generic RGB の元の値を sRGB に換算した値 (小数 6 桁) を書き、テストは Generic RGB 空間で元の直書き値と比べる。上の表の「srgb / 元の値」は輪については当てはまらない。値を「元の値」に戻すと `AppColorAssetTests` が落ちる。
- **見た目不変の判定**: GIF 矩形のマスクではなく、Reduce Motion (`com.apple.Accessibility ReduceMotionEnabled`) で葉の GIF を止め、6 枚とも**全画面で DIFF 0** を合格条件にした (on: DIFF 0 / off: DIFF 11274 で両方向を実証)。
- **起動画面の確認**: `simctl uninstall` では Simulator の起動画面キャッシュが消えなかったため、未使用の新規 Simulator で確認した。
