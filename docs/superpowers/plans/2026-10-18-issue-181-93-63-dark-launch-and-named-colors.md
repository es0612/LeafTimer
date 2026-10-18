# v1.6: dark 起動画面文言 (#93) と直書き色の集約 (#63) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dark モードの起動画面で文言を読めるようにし、直書き色 18 値を named color に集約する (見た目不変)。v1.6 のリリースノートを添えて PR を作るまで。

**Architecture:** 色は `App/Assets.xcassets` (ビルド対象) の colorset に置き、Swift からは `AppColor` enum の 1 か所を経由して参照する。ユニットテストが各 colorset の解決と値を固定し、Simulator のピクセル差分が見た目の不変を固定する。起動画面は `splashIcon.imageset` に dark appearance の PDF を足す。

**Tech Stack:** SwiftUI / XCTest / Xcode asset catalog / `xcrun simctl` / `xcrun assetutil`

**Spec:** `docs/superpowers/specs/2026-10-18-issue-181-93-63-dark-launch-and-named-colors.md`

## Global Constraints

- 見た目は変えない。旧 14 colorset (`WorkMode` = オレンジ等) の色は採用しない。
- `.blue` / `.green` / `.red` / `.gray` / `.orange` 等の SwiftUI 標準色は対象外 (触らない)。
- dark 用 PDF の文言色は `0.95 0.98 0.95`。葉の色 `.3569 .4667 .3529` は変えない。
- named color の置き場所は `app/LeafTimer/App/Assets.xcassets` 直下 (`LaunchBackground.colorset` と同じ階層、フォルダは作らない)。
- Swift ファイル追加は `make add-file` (ルール 28)。新規テストは XCTest (ルール 43)。
- ビルド/テストは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置し、成否は `** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` の不在で判定する (ルール 1)。Bash timeout は 600000。
- この plan は PR 作成まで。merge は含めない (ルール 22)。

## 道具 (このセッションの scratchpad に実在、2026-10-18 に動作確認済み)

`SP=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/39d9dad0-f977-404f-9992-3c8cf8882e8c/scratchpad`

- `$SP/capture.sh <out_dir> [break]` — Debug ビルド → 専用 Simulator `LeafTimer-Colors` (iPhone 17) に uninstall/install → ステータスバー 9:41 固定 → light/dark で `work-*.png` (`-SeedSampleStats -HideAds -LeafPattern=small`)・`history-*.png` (`-InitialScreen=history`) を撮る。`break` を付けると `break-*.png` (`-BreakState`) も撮る。1206×2622。
- `$SP/pixdiff <a.png> <b.png> [x,y,w,h ...]` — マスク矩形 (ピクセル、左上原点) を除いた差分画素数。`DIFF 0` で exit 0、差分ありは `DIFF n bbox=…` で exit 1。
- `$SP/make_dark_pdf.py <src.pdf> <dst.pdf>` — 文言色を置換して再圧縮し、`/Length`・xref を書き直す。置換が 2 箇所 (rg + RG) でなければ exit 1。
- `$SP/composite.swift <pdf> <png> r g b` — PDF を指定背景色の上に描く (目視用)。

**実測済みの揺らぎ (master `66c579f`、同一ビルドを 2 回撮影):** `work-light` DIFF 7914 / `work-dark` DIFF 2136、どちらも bbox は葉の GIF (`450,1222,249,78` 以内)。`history-light` / `history-dark` は DIFF 0。→ work のマスクは `430,1202,289,118` (bbox + 20px)。history はマスクなし。break のマスクは Task 2 で同じ方法で実測して決める。

## Review Focus

1. **named color の解決失敗**: colorset 名の typo や置き場所違いで `Color("…")` が実行時に解決できないと、透明/既定色にフォールバックして背景が抜ける → Task 3 の `testEveryAppColorResolvesInAppBundle` が全 case で nil でないことを固定する。
2. **輪の色に dark 値が混入する**: 現在の `getColor1()`〜`getColor4()` は dark でも同じ値。colorset に dark エントリを足すと dark でだけ色が変わる → Task 3 の値テストで、輪は dark trait でも light と同じ値であることを固定する。
3. **dark 用 PDF がアセットに入らない**: `Contents.json` の appearances 記述ミスでも build は通る → Task 4 で `xcrun assetutil --info` に `splashIcon` の `Appearance: UIAppearanceDark` エントリがあることを確かめる。
4. **起動画面のキャッシュで旧画像を見る**: install し直さずに撮ると iOS がキャッシュした旧起動画面が出る → Task 4 の撮影は uninstall → install から始める。
5. **`-BreakState` の副作用**: 起動引数で break にした状態が `openScreen()` や `readData()` に上書きされる、または Release ビルドに漏れる → Task 2 で `-BreakState` 撮影画面が break の背景 (青灰) であることを目視確認し、フックは `#if DEBUG` 内だけに置く。

---

### Task 1: 旧 14 colorset と生成スクリプトの削除 (人の操作)

**Files:**
- Delete: `app/LeafTimer/Assets.xcassets/` (ビルド対象外、14 colorset)
- Delete: `app/bin/create_color_assets.sh` (上の生成元、参照 0 件)

- [ ] **Step 1: ユーザーに削除を依頼する (ルール 14)** — 次のコマンドをそのまま貼れる形で提示し、ユーザーが自分の turn で実行するのを待つ。AskUserQuestion の選択は authorization にならない。

  `! git rm -r app/LeafTimer/Assets.xcassets app/bin/create_color_assets.sh`

- [ ] **Step 2: 削除を確認する**

  Run: `cd /Users/shinya/workspace/claude/LeafTimer && git status --short && ls app/LeafTimer/Assets.xcassets 2>&1 | head -1`
  Expected: `D ` 行が 15 件 (`git ls-files` で 2026-10-18 に実測した追跡ファイル数)、`ls` は `No such file or directory`。

- [ ] **Step 3: Commit**

  `git commit -m "chore(#63): ビルド対象外の 14 colorset と生成スクリプトを削除"` (stage はStep 1 の `git rm` 済み)

### Task 2: `-BreakState` 起動引数と変更前の基準スクショ

**Files:**
- Modify: `app/LeafTimer/Components/DebugStoreScreenshot.swift` (定数と判定関数を追加)
- Modify: `app/LeafTimer/View/TimerView.swift:162-167` (`onAppear` の `#if DEBUG` ブロック)
- Test: `app/LeafTimerTests/DebugStoreScreenshotTests.swift`

**Interfaces:**
- Produces: `DebugStoreScreenshot.breakStateArgument = "-BreakState"`、`static func isBreakStateRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool`

- [ ] **Step 1: 失敗するテストを書く** — `DebugStoreScreenshotTests` に追加:

  - `testBreakStateRequestedOnlyWithArgument`: `XCTAssertTrue(DebugStoreScreenshot.isBreakStateRequested(arguments: ["app", "-BreakState"]))` と `XCTAssertFalse(DebugStoreScreenshot.isBreakStateRequested(arguments: ["app", "-AutoStart"]))`

- [ ] **Step 2: RED を確認** — `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30`。Expected: `isBreakStateRequested` 未定義のコンパイルエラー (`** TEST FAILED **` か build failure)。

- [ ] **Step 3: 実装** — `isAutoStartRequested` と同じ形で `breakStateArgument` / `isBreakStateRequested` を追加する。`TimerView` の `onAppear` の `#if DEBUG` 内、AutoStart 判定の**前**に `if DebugStoreScreenshot.isBreakStateRequested() { timerViewModel.breakState = true }` を置く (`readData()` / `openScreen()` の後なので上書きされない)。

- [ ] **Step 4: GREEN を確認** — `make unit-tests`。Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。

- [ ] **Step 5: Commit** — `git add app/LeafTimer/Components/DebugStoreScreenshot.swift app/LeafTimer/View/TimerView.swift app/LeafTimerTests/DebugStoreScreenshotTests.swift && git commit -m "test(#63): 背景比較用に DEBUG 起動引数 -BreakState を追加"`

- [ ] **Step 6: 基準スクショを 2 回撮る** — `$SP/capture.sh $SP/before break && $SP/capture.sh $SP/before2 break`。Expected: 末尾に `✅ captured: break-dark.png break-light.png history-dark.png history-light.png work-dark.png work-light.png`。

- [ ] **Step 7: break の揺らぎを測ってマスクを決める** — `$SP/pixdiff $SP/before/break-light.png $SP/before2/break-light.png` と dark。bbox が葉の GIF (画面中央、`big` の葉) にあることを `sips -Z 600` の縮小画像で確かめ、bbox を上下左右 20px 広げた矩形を break マスクとして記録する。bbox が葉以外にあったら止めて報告する。work/history は「実測済みの揺らぎ」と同じ結果 (work は `430,1202,289,118` 内、history は DIFF 0) になることも確かめる。

- [ ] **Step 8: break 画面を目視** — `$SP/before/break-light.png` と `break-dark.png` を原寸で開き、背景が青灰のグラデ (work の緑ではない) であることを確認する。

### Task 3: named color の作成と配線 (#63)

**Files:**
- Create: `app/LeafTimer/App/Assets.xcassets/<Name>.colorset/Contents.json` × 17 (下表)
- Create: `app/LeafTimer/Components/AppColor.swift` (`make add-file FILE=LeafTimer/Components/AppColor.swift TARGET=app`)
- Modify: `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift:69-154` (`getBackgroundColor`、`getColor1`〜`getColor4`)
- Modify: `app/LeafTimer/View/HistoryView.swift:96-104` (`barColor(for:)` の count > 0 の分岐)
- Modify: `app/LeafTimer/View/TimerView.swift:77` と `app/LeafTimerTests/ModernTimerViewSpec.swift:151,157` (引数の削除に追従)
- Test: `app/LeafTimerTests/AppColorAssetTests.swift` (`make add-file FILE=LeafTimerTests/AppColorAssetTests.swift TARGET=test`)

**Interfaces:**
- Produces: `enum AppColor: String, CaseIterable` (rawValue = colorset 名)、`var color: Color { Color(rawValue) }`。case 名は rawValue の先頭小文字 (`workGradientTop` など)。
- Produces: `func getBackgroundColor() -> LinearGradient` (`colorScheme` 引数を削除。named color が環境の colorScheme で解決されるため)。

**colorset の値 (旧来の直書き値そのまま):**

| colorset | color-space | any (light) | dark |
|---|---|---|---|
| WorkGradientTop | display-p3 | 0.95, 0.98, 0.95 | 0.18, 0.22, 0.18 |
| WorkGradientBottom | display-p3 | 0.87, 0.91, 0.85 | 0.25, 0.30, 0.23 |
| BreakGradientTop | display-p3 | 0.94, 0.96, 0.98 | 0.18, 0.20, 0.24 |
| BreakGradientBottom | display-p3 | 0.77, 0.80, 0.88 | 0.25, 0.30, 0.36 |
| WorkRing1 | srgb | 0.35, 0.47, 0.35 | (なし) |
| WorkRing2 | srgb | 0.57, 0.73, 0.52 | (なし) |
| WorkRing3 | srgb | 0.49, 0.71, 0.41 | (なし) |
| WorkRing4 | srgb | 0.35, 0.68, 0.29 | (なし) |
| BreakRing1 | srgb | 0.35, 0.38, 0.46 | (なし) |
| BreakRing2 | srgb | 0.52, 0.66, 0.73 | (なし) |
| BreakRing3 | srgb | 0.41, 0.57, 0.71 | (なし) |
| BreakRing4 | srgb | 0.29, 0.45, 0.67 | (なし) |
| HistoryBar | srgb | 0.42, 0.56, 0.42 | 0.62, 0.76, 0.62 |

計 13 colorset (spec の「18 値」は gradient 8 + 輪 8 + 履歴 2 の値の数。colorset は light/dark を 1 つにまとめるので 13 になる)。Contents.json の書式は `LaunchBackground.colorset/Contents.json` に合わせる (値は小数 3 桁の文字列、alpha `"1.000"`)。

- [ ] **Step 1: 失敗するテストを書く** — `AppColorAssetTests` (XCTestCase):

  - `testEveryAppColorResolvesInAppBundle`: `for c in AppColor.allCases { XCTAssertNotNil(UIColor(named: c.rawValue, in: .main, compatibleWith: nil), c.rawValue) }` かつ `XCTAssertEqual(AppColor.allCases.count, 13)`
  - `testResolvedValuesMatchFormerLiterals`: 上表を `[(AppColor, CGColorSpace名, light: [CGFloat], dark: [CGFloat])]` の期待値表として持ち (dark なしの行は dark = light)、各 case を `UITraitCollection(userInterfaceStyle: .light/.dark)` で `resolvedColor(with:)` → `cgColor.converted(to: CGColorSpace(name: 表の色空間)!, intent: .defaultIntent, options: nil)!.components!` の先頭 3 要素が期待値と `accuracy: 0.002` で一致。色空間は gradient 行が `CGColorSpace.displayP3`、他は `CGColorSpace.sRGB`。

- [ ] **Step 2: RED を確認** — `make unit-tests`。Expected: `AppColor` 未定義のコンパイルエラー。

- [ ] **Step 3: `AppColor.swift` を作り add-file で配線** — 13 case のみ。colorset はまだ作らない状態で `make unit-tests` を回し、`testEveryAppColorResolvesInAppBundle` が 13 件の nil で FAIL することを確認する (予測 RED と実際の RED の突き合わせ、ルール 9)。値テストは `XCTUnwrap` で nil を FAIL にし、crash させない。

- [ ] **Step 4: 13 colorset を作る** — 上表どおり。

- [ ] **Step 5: GREEN を確認** — `make unit-tests`。Expected: `** TEST SUCCEEDED **`、`AppColorAssetTests` の 2 件が pass。

- [ ] **Step 6: mutation で両テストが効くことを確かめる (ルール 8)** — (a) `WorkRing1.colorset` を一時的に `WorkRing1x.colorset` にリネーム → `testEveryAppColorResolvesInAppBundle` と `testResolvedValuesMatchFormerLiterals` が FAIL。(b) `HistoryBar` の dark の red を `0.620` → `0.700` → `testResolvedValuesMatchFormerLiterals` のみ FAIL。どちらも戻して GREEN を再確認する。

- [ ] **Step 7: 配線** — `getBackgroundColor()` は `breakState` だけで分岐し `[AppColor.workGradientTop.color, AppColor.workGradientBottom.color]` (break は Break*) の `LinearGradient(top → bottom)` を返す。`getColor1()`〜`getColor4()` は `breakState ? AppColor.breakRingN.color : AppColor.workRingN.color`。`HistoryView.barColor(for:)` の count > 0 は `AppColor.historyBar.color` (count == 0 の `Color.gray.opacity(…)` は残す)。`TimerView.swift:77` と `ModernTimerViewSpec.swift:151,157` の呼び出しから `colorScheme:` を外す。`HistoryView` で `colorScheme` が count == 0 分岐でまだ使われることを確認し、未使用になった `@Environment(\.colorScheme)` があれば (TimerView 等) 削除せず使用箇所を grep して判断する。

- [ ] **Step 8: 直書きが残っていないことを確認** — `/usr/bin/grep -rn -E 'Color\(\.displayP3|Color\(\.init\(red|Color\(red:' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer --include='*.swift'`。Expected: 0 件。

- [ ] **Step 9: テスト** — `make unit-tests`。Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 10: 変更後を撮影して比較** — `$SP/capture.sh $SP/after break` の後、6 枚それぞれ:
  - `$SP/pixdiff $SP/before/work-light.png $SP/after/work-light.png 430,1202,289,118` (work-dark も同じマスク)
  - `$SP/pixdiff $SP/before/break-light.png $SP/after/break-light.png <Task 2 Step 7 の break マスク>` (break-dark も)
  - `$SP/pixdiff $SP/before/history-light.png $SP/after/history-light.png` (history-dark も、マスクなし)

  Expected: 6 枚すべて `DIFF 0`。1 枚でも差分があれば止めて、bbox と原寸画像を添えて報告する (色の丸め・色空間の違いを疑う。マスクを広げて通さない)。

- [ ] **Step 11: Commit** — `git add app/LeafTimer/App/Assets.xcassets app/LeafTimer/Components/AppColor.swift app/LeafTimerTests/AppColorAssetTests.swift app/LeafTimer/ViewModel/TimerViewModel+extensions.swift app/LeafTimer/View/HistoryView.swift app/LeafTimer/View/TimerView.swift app/LeafTimerTests/ModernTimerViewSpec.swift app/LeafTimer.xcodeproj/project.pbxproj && git commit -m "refactor(#63): 直書き色 18 値を named color (AppColor) に集約"`

### Task 4: dark 用 splashIcon (#93)

**Files:**
- Create: `app/LeafTimer/App/Assets.xcassets/splashIcon.imageset/splashIcon-dark.pdf`
- Modify: `app/LeafTimer/App/Assets.xcassets/splashIcon.imageset/Contents.json`

- [ ] **Step 1: dark 用 PDF を生成** — `python3 -I $SP/make_dark_pdf.py /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/splashIcon.imageset/splashIcon.pdf /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/splashIcon.imageset/splashIcon-dark.pdf`。Expected: `replaced=2 objects=12 size=213085`。

- [ ] **Step 2: 目視** — `swift $SP/composite.swift <splashIcon-dark.pdf> $SP/pdf/check-dark.png 0.18 0.22 0.18` を開き、文言が淡い緑白で読め、葉が元と同じ緑であること。

- [ ] **Step 3: Contents.json に dark エントリを追加** — 既存の `{"filename": "splashIcon.pdf", "idiom": "universal"}` は残し、`{"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "splashIcon-dark.pdf", "idiom": "universal"}` を足す。PDF の vector 設定 (`properties`) は既存に無いので足さない。

- [ ] **Step 4: アセットに入ったことを確認** — `$SP/capture.sh $SP/after2` でビルドした後、`xcrun assetutil --info /Users/shinya/workspace/claude/LeafTimer/app/build/colors-dd/Build/Products/Debug-iphonesimulator/LeafTimer.app/Assets.car` を `Name == "splashIcon"` で絞る。Expected: `Appearance: UIAppearanceDark` のエントリが 1 件以上ある (変更前は全エントリ `Appearance: None`、2026-10-18 実測)。

- [ ] **Step 5: 起動画面を撮る (best-effort)** — `LeafTimer-Colors` Simulator で dark にし、`simctl uninstall` → `install` → `launch` の直後に 0.2 秒間隔で `simctl io screenshot` を 10 枚撮り、起動画面が写ったコマを原寸で確認する。light でも同じ手順で撮り、従来どおりであること。起動画面のコマが撮れなかった場合は「未実測」として PR に書き、Step 4 の結果を根拠にする (撮れたフリをしない)。

- [ ] **Step 6: Commit** — `git add app/LeafTimer/App/Assets.xcassets/splashIcon.imageset && git commit -m "fix(#93): dark モードの起動画面で文言が読めるよう splashIcon に dark 用 PDF を追加"`

### Task 5: v1.6 リリースノート

**Files:**
- Create: `docs/RELEASE_v1.6.md`

- [ ] **Step 1: 書く** — `docs/RELEASE_v1.5.md` の冒頭〜`## What's New` と同じ構成 (振り返り節は配信後に足すので書かない)。対象は `MARKETING_VERSION 1.6`、入力元は v1.5 タグ (2026-09-27) 以降の merged PR のうちユーザーに見える変更 = この PR だけ。What's New は ja/en とも 1 行、**絵文字なし**:
  - ja: `・ダークモードの起動画面で、アプリ名が読みにくかった問題を修正しました`
  - en: `- Fixed the app name being hard to read on the launch screen in Dark Mode`
  - (#63 は見た目が変わらないので載せない)

- [ ] **Step 2: 絵文字が無いことを確認** — `python3 -I -c "import re,sys;t=open('/Users/shinya/workspace/claude/LeafTimer/docs/RELEASE_v1.6.md').read();print(re.findall(r'[\U0001F000-\U0001FAFF☀-➿]',t))"`。Expected: `[]`。

- [ ] **Step 3: Commit** — `git add docs/RELEASE_v1.6.md && git commit -m "docs(#181): v1.6 リリースノートを追加"`

### Task 6: 全体テストと PR 作成

- [ ] **Step 1: 全チェーン** — `cd /Users/shinya/workspace/claude/LeafTimer/app && set -o pipefail && make tests 2>&1 | tail -40`。Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6x` / `No rule to make target` なし。`make sort` が pbxproj を並べ替えた場合はその差分を `git add app/LeafTimer.xcodeproj/project.pbxproj` で別 commit にする。

- [ ] **Step 2: spec と plan を archive へ (ルール 44)** — `git mv docs/superpowers/specs/2026-10-18-issue-181-93-63-dark-launch-and-named-colors.md docs/superpowers/specs/archive/` と plan も同様。`make plan-docs-check` が通ること。Commit: `chore(#181): spec/plan を archive へ`。

- [ ] **Step 3: push 前の確認 (ルール 21)** — `git fetch && gh pr list --state all --head feature/181-dark-launch-named-colors`。Expected: 既存 PR なし。`git diff --stat master..HEAD` で無関係なファイルが混ざっていないこと。

- [ ] **Step 4: push と PR 作成** — `git push -u origin feature/181-dark-launch-named-colors` → `gh pr create --base master`。本文: 概要 (#93 / #63、Refs #181、Closes #93 #63)、物差しの結果 (6 枚の pixdiff 結果と各マスク、assetutil の結果、起動画面スクショの有無)、mutation の結果、未実測の項目。スクショは PR に埋め込まず SendUserFile でユーザーに渡す (ルール 25)。

## 実装時の変更 (2026-10-18、実装後に追記)

- **輪 8 色の色空間**: 旧 `getColor1()`〜`getColor4()` の `Color(.init(red:…))` は `CGColor(red:…)` = Generic RGB に解決されていた。「srgb で元の値」では輪が暗くなる (初回比較でボタン 450×450 が DIFF 153308) ため、colorset には Generic RGB の元の値を sRGB に換算した値 (小数 6 桁) を書き、テストは Generic RGB 空間で元の直書き値と比べる。上の表の「srgb / 元の値」は輪については当てはまらない。値を「元の値」に戻すと `AppColorAssetTests` が落ちる。
- **見た目不変の判定**: GIF 矩形のマスクではなく、Reduce Motion (`com.apple.Accessibility ReduceMotionEnabled`) で葉の GIF を止め、6 枚とも**全画面で DIFF 0** を合格条件にした (on: DIFF 0 / off: DIFF 11274 で両方向を実証)。
- **起動画面の確認**: `simctl uninstall` では Simulator の起動画面キャッシュが消えなかったため、未使用の新規 Simulator で確認した。
