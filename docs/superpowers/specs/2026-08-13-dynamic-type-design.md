# Dynamic Type 対応 設計 (Issue #58)

- Issue: [#58](https://github.com/es0612/LeafTimer/issues/58) Dynamic Type 対応: 固定 font size で「文字を大きく」が一切効かない
- 作成日: 2026-08-13
- ブランチ: `feature/58-dynamic-type`

## 背景

全画面で `.font(.system(size:))` の固定サイズが使われており、iOS の「文字を大きく」設定を最大にしても文字が拡大しない。弱視・高齢ユーザーが読めず、アクセシビリティ観点で影響が大きい。`@ScaledMetric` / `dynamicTypeSize` の使用は 0 件。

## 実測 (2026-08-13)

固定 font size は **40 箇所 / 9 ファイル**。

Issue 本文の「41 箇所」および証拠にある `TimerView.swift:52-54` は概ね正しい。ただし単一行の `grep` では `TimerView.swift` の折り返された `.font(.system(\n size: 78` を取りこぼし 39 件に見える。改行を潰して数えると 40 件。**この取りこぼしは後述のガードスクリプトが踏んではならない罠そのもの**である。

## 決定事項

| # | 論点 | 決定 |
| --- | --- | --- |
| 1 | 対応範囲 | 文字 + SF Symbol アイコンの **40 箇所すべて** + 再発防止ガード |
| 2 | 特大文字 (78/72/48pt) | `@ScaledMetric` で **上限付きスケール** |
| 3 | 保証する文字サイズ | **AX5 (最大) まで**レイアウトが崩れないことを保証 |
| 4 | 実装アプローチ | **案A: SwiftUI 標準 text style へ直接置換**（独自 Font レイヤは作らない） |
| 5 | 検証手段 | **DEBUG 専用の起動引数**で各画面を直接表示 |

### 決定 4 の根拠

案B「独自のセマンティック Font 拡張レイヤ (`Font+LeafTimer.swift`) を新設」を退けた理由:

- SwiftUI の text style (`.body` / `.footnote` / `.caption2` …) が**それ自体すでにセマンティック**であり、その上に自前レイヤを重ねるのは二重の抽象になる
- 新規 Swift ファイルの追加は `project.pbxproj` 登録 / `make sort` / orphan 検査のセレモニーを伴う
- Issue #63 (色の集約) のロジックは転用できない。**色には標準のセマンティック体系が無いから集約が要る**のであって、フォントには最初からある
- `design:` / `weight:` は `.font(.system(.subheadline, design: .rounded, weight: .semibold))` の形で保持できるため、「丸ゴシック・等幅を残したい」は案B の根拠にならない

一貫性は「本ドキュメントの対応表」＋「CI で落ちるガード」という別手段で担保する。

## 設計 1: サイズ → text style 対応

### 前提: 固定値は標準 text style とほぼ一致している

| 固定サイズ | 標準 text style (Large 基準) | 一致 |
| --- | --- | --- |
| 22pt | `.title2` (22) | ✅ |
| 20pt | `.title3` (20) | ✅ |
| 17pt | `.body` (17) | ✅ |
| 16pt | `.callout` (16) | ✅ |
| 15pt | `.subheadline` (15) | ✅ |
| 13pt | `.footnote` (13) | ✅ |
| 12pt | `.caption` (12) | ✅ |
| 11pt | `.caption2` (11) | ✅ |

元の実装は text style を意識した数値になっているため、**置換しても標準サイズでの見た目はほぼ変わらない**。「文字を大きく」への追従能力だけが付加される。

例外は 2 つ:

- **14pt** (5 箇所) — 標準に該当なし。隣接要素が 15pt のため `.subheadline` に寄せる (+1pt)
- **10pt** (2 箇所) — 標準の最小が 11pt のため `.caption2` に寄せる (+1pt)

### 対応表 (全 40 箇所)

行番号は 2026-08-13 時点。実装時にずれる場合は「内容」で同定する。

#### `View/TimerView.swift` (1)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 52-55 | タイマー数字 | `size: 78, .bold, .monospaced` | **@ScaledMetric 上限 110** (設計 2) |

#### `View/Elements/StatChip.swift` (1)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 16 | ピル内テキスト | `size: 15, .medium` | `.subheadline.weight(.medium)` |

#### `View/EnhancedSettingView.swift` (7)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 24 | Label 行タイトル | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 30 | Image `checkmark` | `size: 14, .semibold` | `.subheadline.weight(.semibold)` |
| 40 | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 44 | Section footer | `size: 11` | `.caption2` |
| 57 | Label 行タイトル | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 65 | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 88 | Done ボタン | `size: 16, .medium` | `.callout.weight(.medium)` |

#### `View/Settings/TimerSettingsSection.swift` (10)

`TimerSettingsSection` (7) / `TimerPreviewSheet` (1) / `PreviewTimerDisplay` (2) の 3 struct にまたがる。

| 行 | struct | 内容 | Before | After |
| --- | --- | --- | --- | --- |
| 16 | TimerSettingsSection | Label 作業時間 | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 22 | TimerSettingsSection | 設定値 | `size: 15, .semibold, .rounded` | `.system(.subheadline, design: .rounded, weight: .semibold)` |
| 52 | TimerSettingsSection | Label 休憩時間 | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 58 | TimerSettingsSection | 設定値 | `size: 15, .semibold, .rounded` | `.system(.subheadline, design: .rounded, weight: .semibold)` |
| 87 | TimerSettingsSection | Image `eye` | `size: 14` | `.subheadline` |
| 89 | TimerSettingsSection | プレビューボタン文言 | `size: 14, .medium` | `.subheadline.weight(.medium)` |
| 104 | TimerSettingsSection | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 136 | TimerPreviewSheet | Image `arrow.down` | `size: 20` | `.title3` |
| 169 | PreviewTimerDisplay | タイトル | `size: 14, .medium` | `.subheadline.weight(.medium)` |
| 173 | PreviewTimerDisplay | 時刻表示 | `size: 48, .light, .monospaced` | **@ScaledMetric 上限 72** (設計 2) |

#### `View/Settings/SoundSettingsSection.swift` (7)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 18 | Label 作業音 | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 30 | Image `checkmark.circle` | `size: 20` | `.title3` |
| 33 | サウンド名 | `size: 15` | `.subheadline` |
| 44 | Image `play.circle` | `size: 22` | `.title2` |
| 65 | Label バイブレーション | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 94 | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 98 | Section footer | `size: 11` | `.caption2` |

#### `View/Settings/ResetSettingsSection.swift` (5)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 15 | Image `arrow.counterclockwise` | `size: 20` | `.title3` |
| 19 | リセットボタン文言 | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 47 | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 52 | Footer アプリ名 | `size: 11, .medium` | `.caption2.weight(.medium)` |
| 54 | Footer 著作権表記 | `size: 10` | `.caption2` |

#### `View/Settings/AboutSettingsSection.swift` (4)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 16 | Label レビュー | `size: 15, .medium` | `.subheadline.weight(.medium)` |
| 22 | Image `chevron.right` | `size: 12, .semibold` | `.caption.weight(.semibold)` |
| 33 | Section header | `size: 13, .semibold` | `.footnote.weight(.semibold)` |
| 40 | Section footer | `size: 11` | `.caption2` |

#### `View/HistoryView.swift` (4)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 50 | 統計行テキスト | `size: 17, .medium` | `.body.weight(.medium)` |
| 59 | 「直近7日」見出し | `size: 14, .semibold` | `.subheadline.weight(.semibold)` |
| 67 | 棒グラフの件数 | `size: 11` | `.caption2` |
| 73 | 日付ラベル | `size: 10` | `.caption2` |

#### `View/OnboardingView.swift` (1)

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 50 | ページ絵文字 | `size: 72` | **@ScaledMetric 上限 100** (設計 2) |

## 設計 2: 特大 3 箇所の上限付きスケール

素直に比例拡大すると破綻する。AX5 では本文が約 3.1 倍になるため 78pt → 約 240pt となり、iPhone の画面幅 390pt に `25:00` の 5 文字は収まらない。

```swift
@ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 78

Text(timerViewModel.getDisplayedTime())
    .font(.system(size: min(timerFontSize, 110), weight: .bold, design: .monospaced))
    .lineLimit(1)
    .minimumScaleFactor(0.8)
```

| 箇所 | 基準 | 上限 (暫定) |
| --- | --- | --- |
| `TimerView.swift:52` タイマー | 78pt | 110pt |
| `OnboardingView.swift:50` 絵文字 | 72pt | 100pt |
| `TimerSettingsSection.swift:173` プレビュー時刻 | 48pt | 72pt |

**上限値は実測前の暫定値**であり、AX5 のスクリーンショットを見てから調整する。`.minimumScaleFactor(0.8)` は安全弁で、上限の見積もりがずれてもレイアウト破綻ではなく緩やかな縮小に留める。

## 設計 3: DEBUG 専用の検証フック

### 問題

`simctl` には tap が無い (Issue #90 で学んだ制約)。到達経路を調べると、40 箇所のうち**素で観測できるのは 2 箇所だけ**だった。

| 画面 | 到達方法 | タップ不要で観測 | 箇所数 |
| --- | --- | --- | --- |
| `TimerView` (トップ) | 起動直後 | ✅ | 2 |
| `OnboardingView` | `hasSeenOnboarding` が false なら自動表示 | ✅ (UserDefaults) | 1 |
| `HistoryView` | `TimerView.swift:101-102` NavigationLink | ❌ | 4 |
| `EnhancedSettingView` + Settings 4 セクション | `TimerView.swift:112` NavigationLink | ❌ | 30 |
| `TimerPreviewSheet` / `PreviewTimerDisplay` | 設定画面内の `.sheet` (2 段深い) | ❌ | 3 |

決定 3「AX5 まで保証」は、観測手段が無ければ空手形になる。

### 解決

`#if DEBUG` で囲んだ起動引数フックを追加する。既存の `-UMPDebugGeographyEEA` (`Components/AdsConsentServices.swift:20`) と同じ発想。

```swift
#if DEBUG
enum DebugInitialScreen {
    static var requested: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-InitialScreen=") }?
            .replacingOccurrences(of: "-InitialScreen=", with: "")
    }
}
#endif
```

| 引数 | 表示画面 | カバー箇所 |
| --- | --- | --- |
| `-InitialScreen=settings` | `EnhancedSettingView` | 30 |
| `-InitialScreen=history` | `HistoryView` | 4 |
| `-InitialScreen=timePreview` | `TimerPreviewSheet` | 3 |
| (引数なし) | `TimerView` | 2 |
| (UserDefaults で `hasSeenOnboarding` を消す) | `OnboardingView` | 1 |

- `#if DEBUG` により **Release ビルドには一切入らない**
- `DebugInitialScreen` は**新規ファイルを作らず `TimerView.swift` 内に `#if DEBUG` で置く**。新規 Swift ファイルを足すと、案B を退けた理由 (pbxproj 登録 / orphan 検査 / `make sort` のセレモニー) を自分で買い戻すことになる
- `TimerView` の `NavigationStack` (`TimerView.swift:16`) 構造は変更しない。DEBUG 分岐で目的の View を返す
- ただし `EnhancedSettingView` / `HistoryView` は通常 `NavigationStack` の内側で描画されるため、**DEBUG 分岐でも `NavigationStack` でラップして返す**。裸で返すとツールバーや `navigationTitle` が描画されず、baseline として不正確になる
- 今後の UI 検証 (#62 Reduce Motion / #64 SE・iPad 対応) でも再利用できる資産になる

オンボーディングは既存の UserDefaults 経路で観測できるため、`-InitialScreen=onboarding` は用意しない (YAGNI)。撮影時は **`simctl uninstall` ではなくキー削除**を使う。

```bash
xcrun simctl spawn booted defaults delete jp.ema.LeafTimer hasSeenOnboarding
```

`uninstall` は ATT の決定もリセットするため、次回起動で ATT ダイアログが出て**手動タップが 1 回必要**になる (Issue #90 のコメントに記録済み)。キー削除ならこれを避けられる。

## 設計 4: 再発防止ガード

40 箇所を直しても、新規コードで固定サイズが再び混入すれば元に戻る。`make localization-check` の前例に倣い、機械的検査をリポジトリ内スクリプトとして実装する。

### ファイル構成

`app/bin/` の既存規約 (CLI 層 = ハイフン / ロジック層 = アンダースコア / minitest) に従う。

```
app/bin/dynamic-type-check.rb        # CLI 層
app/bin/dynamic_type_check.rb        # ロジック module
app/bin/test_dynamic_type_check.rb   # minitest
```

### 検出ルール

対象は `app/LeafTimer/` 配下の `.swift` のみ (テストコードは対象外)。

1. **数値リテラルのみを違反とする** — `size:` の後が変数なら違反ではない。これを守らないと `@ScaledMetric` を使う 3 箇所 (`size: timerFontSize` 等) が引っかかり、**ガードが自分自身の PR を落とす**
2. **改行を潰してから照合する** — 行単位の照合は `TimerView.swift` の折り返し (39 件 vs 実際 40 件) と同じ盲点を持つ

### RED フィクスチャ (必須)

リポジトリの教訓「検査ツールの本体は FAIL(RED) パス。正常系が GREEN なだけの確認は vacuously green」に従い、以下 3 種を必ず含める。

| フィクスチャ | 期待 |
| --- | --- |
| 単一行の違反 `.font(.system(size: 15))` | 🔴 検出される |
| 複数行の違反 `.font(.system(\n size: 78, ...))` | 🔴 検出される |
| 変数サイズ `.font(.system(size: timerFontSize, ...))` | 🟢 検出されない |
| **上限付き変数** `.font(.system(size: min(timerFontSize, 110), ...))` | 🟢 検出されない |

4 つ目のフィクスチャは必須である。設計 2 で実際に書くコードは `size: min(timerFontSize, 110)` であり、**数値リテラル `110` を含む**。「`.font(.system(...)` 内に数字があれば違反」という素朴な実装は 3 つ目のフィクスチャを通過しながら実コードを落とすため、この 4 つ目でしか検出できない。判定は「`size:` の**直後のトークン**が数値リテラルか」で行う。

### Makefile への配線

`localization-check` の隣に `dynamic-type-check` ターゲットを追加し、`tests` チェーンに組み込む。

```make
tests: precheck localization-check dynamic-type-check sort lint unit-tests
```

## 設計 5: 検証手順

### コマンド

ビルド → install → 起動の全体手順は `ios-simulator-app-verification` スキルに従う。本設計に固有なのは以下の 2 行 (文字サイズ切替と起動引数)。

```bash
# 文字サイズを切り替える (tap 不要)
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large

# 目的の画面を直接開いてスクリーンショットを撮る
xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=settings
xcrun simctl io booted screenshot /tmp/settings-AX5.png
```

`simctl install` に渡すバンドルパスは**絶対パス**で組む (相対パスは直前の `cd app` と二重化して無言でタイムアウトする)。

`content_size` の有効値 (`xcrun simctl ui` で確認済み):

- 標準: `extra-small` / `small` / `medium` / `large` / `extra-large` / `extra-extra-large` / `extra-extra-extra-large`
- 拡張: `accessibility-medium` / `accessibility-large` / `accessibility-extra-large` / `accessibility-extra-extra-large` / `accessibility-extra-extra-extra-large`

### 実施順序の制約 (重要)

完了条件の「標準サイズのスクリーンショットが置換前と実質同一」は、**置換前に `large` の 5 枚を撮っておかなければ検証できない**。しかし設定画面・履歴・プレビューの撮影には DEBUG 起動引数が必要で、それは実装物である。したがって作業順序は次に固定する。

1. **DEBUG 起動引数フック (設計 3) を単独で先に実装・commit** — 表示内容を変えないため、この時点のスクリーンショットが正当な baseline になる
2. `large` の baseline 5 枚を撮影して保存
3. 40 箇所の置換 (設計 1・2) を実施
4. 検証マトリクス 13 枚を撮影し、`large` の 5 枚を baseline と比較

### 検証マトリクス (13 枚)

| 文字サイズ | 対象画面 | 枚数 | 目的 |
| --- | --- | --- | --- |
| `large` (標準) | 全 5 画面 | 5 | 置換前後で見た目が変わらないことの確認 |
| `extra-extra-extra-large` | timer / settings / history | 3 | 中間サイズでの崩れ確認 |
| `accessibility-extra-extra-extra-large` (AX5) | 全 5 画面 | 5 | 保証対象。崩れず読めることの確認 |

ライト/ダークは掛けない。本変更は**フォントのみで色に触らない**ため直交しており、色の可読性検証は #26 / #39 で実施済み。

### ビルド成果物の取得

`app/Makefile` の `xcodebuild` は `-derivedDataPath` を指定していないため、`app/build/` を `find` しない (古い残骸を掴む)。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && BUILT_DIR=$(xcodebuild \
  -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //')
```

`make` / `xcodebuild` 系は**毎回同一コマンド内で絶対パスの `cd` を前置する** (直前ターンの cwd に依存すると `No rule to make target` で無言失敗する)。成否はパイプの exit code ではなく `** TEST SUCCEEDED **` 等の出力マーカーで判定する。

## 設計 6: テスト戦略

| 対象 | 手段 |
| --- | --- |
| Ruby ガード | minitest で TDD (RED → GREEN)。`test_localization_check.rb` と同じ形 |
| Swift 側の回帰 | 既存の `make unit-tests` が通ること |
| font 値の正しさ | ガードスクリプトが「固定サイズが存在しないこと」を担保 |
| レイアウトの崩れ | Simulator 目視検証 13 枚が担保 |

**ViewInspector で 40 箇所の font 値を個別検証するテストは書かない。** ガードと目視で二重に担保されており、三重目は費用対効果が合わない (YAGNI)。

## スコープ外

| 項目 | 理由 | 行き先 |
| --- | --- | --- |
| 固定 `.frame(width:height:)` の SE / iPad 対応 (10 箇所) | テーマは近いが対象ファイルの重複が 2 つのみで、1 PR にすると L 規模に膨らむ | Issue #64 |
| Reduce Motion 対応 | 別の a11y 軸 | Issue #62 |
| ライト/ダークの色検証 | 本変更と直交 | #26 / #39 で実施済み |
| UI テストターゲットの復活 | DEBUG 起動引数で検証目的は達成できる | Issue #76 |

## 完了条件

- [ ] DEBUG 起動引数フックを**先に**実装し、置換前に `large` の baseline 5 枚を撮影済み
- [ ] 40 箇所すべてが text style または `@ScaledMetric` に置換されている
- [ ] `make dynamic-type-check` が green、かつ意図的に壊した入力で RED になることを実証済み
- [ ] `make tests` チェーンに組み込まれ green
- [ ] 検証マトリクス 13 枚を取得し、AX5 で全画面が崩れず読めることを確認
- [ ] 標準サイズのスクリーンショットが置換前と実質同一であることを確認
