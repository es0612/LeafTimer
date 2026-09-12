# トップ画面ステータス表示の刷新 設計

- **Issue**: [#39 トップ画面の火のアイコンがaiぽい](https://github.com/es0612/LeafTimer/issues/39)
- **日付**: 2026-05-30
- **対象**: app/LeafTimer (iOS, SwiftUI, MVVM)

## Context

Issue #8 (PR #37) で streak / 今日のカウントをトップ画面下部に表示する機能が入った。現状の表示は単一の `Text` で `今日 0 回 ・ 🔥 Streak 0`（日本語ロケール）/ `Today 0 · 🔥 Streak 0`（英語ロケール）というベタなテキスト1行。

Issue #39 のユーザー指摘は2点:

1. **火のアイコンがAIっぽい** — トップ画面の 🔥 は localized string `timer.todays_count_with_streak` に直接埋め込まれた emoji。一方、履歴画面 (`HistoryView`) は同じ streak を SF Symbol `flame.fill`（`.orange`）で描画しており、ユーザーは「履歴画面のアイコンはまだマシ」とコメント。→ トップも履歴と同じ SF Symbol 系に統一すべき。
2. **テキスト表示だけだと微妙、UI工夫したい** — 1行ベタテキストをやめ、デザインされた見せ方にしたい。

調査結果:

- トップ画面の live コードは `View/TimerView.swift`（インラインの streak `Text`、65–74行）＋ `View/Elements/CircleButton.swift`。
- `View/Components/TimerDisplayView.swift` / `View/Components/TimerControlsView.swift` は **dead code**（自ファイル以外から参照ゼロ、`grep` で確認）。本件では触らない。
- `TimerViewModel` は `todaysCount: Int` / `currentStreak: Int` を **既に公開済み**（ViewModel 変更不要）。
- アイコン慣習が既に確立: `leaf.fill` ＝ `.green`（`EnhancedSettingView`）、`flame.fill` ＝ `.orange`（`HistoryView`）。
- 背景は `TimerViewModel+extensions.swift` の `getBackgroundColor(colorScheme:)` で **work/break × light/dark の4状態**に変化する。light モードはほぼ白に近い淡色（work=淡緑 / break=淡青）、dark モードは濃色（work=深緑 / break=紺）。現状テキストは `.secondary`（semantic color）で全状態に自動適応している。
- ローカライズは legacy `.strings`（`ja.lproj/Localizable.strings` / `en.lproj/Localizable.strings`）。`.xcstrings` ではないため plural variation 機構は無関係。
- localization 専用テストは現状 **存在しない**。

## Goals

- トップ画面の 🔥 emoji を SF Symbol `flame.fill`（`.orange`）に置き換え、履歴画面とビジュアル言語を統一する。
- 「Today / Streak」を1行ベタテキストから、デザインされた**ピル（チップ）2つ**の表示に刷新する。
- work/break × light/dark の全4状態で可読性を担保する。
- 既存 MVVM パターン・アイコン慣習を踏襲し、View を疎結合・テスタブルに保つ。

## Non-Goals (このスコープでは扱わない)

- タイマー時刻表示・STOP/STARTボタン (`CircleButton`)・葉アニメ (`GIFView`)・ナビバーアイコンの変更。
- dead code（`TimerDisplayView` / `TimerControlsView`）の改修・削除。
- アプリアイコン（別 Issue）やトップ画面全体のレイアウト再構成。
- streak / count の集計ロジック変更（表示のみ）。
- アニメーション演出（チップ出現アニメ等）。

## Design

### コンポーネント: `StatChip`

新規 `View/Elements/StatChip.swift`（live な小コンポーネント置き場、`CircleButton` と同階層）。

```
StatChip(systemImage: String, tint: Color, text: String)
```

- レイアウト: `HStack(spacing:) { Image(systemName: systemImage).foregroundColor(tint); Text(text) }`
- 背景: `.ultraThinMaterial` を `Capsule` でクリップした frosted ピル。
- 文字色: `.primary`（semantic、light/dark 自動適応）。
- 適応性: `.ultraThinMaterial` が背景に応じて自動でライト/ダーク frosted を切替えるため、4状態すべてで可読。ハードコード色は使わない。
- アクセシビリティ: `.accessibilityElement(children: .combine)` で icon ＋ text を1要素にまとめる。`text`（「今日 0」「連続 0」）自体が語を含み意味が通るため、追加の a11y label は設けない（icon は装飾）。

`StatChip` は入力（icon名・tint・text）だけに依存し、内部状態を持たない純表示コンポーネント。単体で理解・差し替え可能。

### `TimerView` の変更

現在の単一 `Text`（65–74行）を、2つの `StatChip` を並べた `HStack` に置換:

- Today チップ: `systemImage: "leaf.fill"`, `tint: .green`, `text: String(format: NSLocalizedString("timer.stat.today", ...), todaysCount)`
- Streak チップ: `systemImage: "flame.fill"`, `tint: .orange`, `text: String(format: NSLocalizedString("timer.stat.streak", ...), currentStreak)`

`VStack` 内の配置・余白（`.padding(.top, 20)` 等）は現状の見た目を踏襲しつつチップ用に微調整。

### データフロー

View は `TimerViewModel.todaysCount` / `currentStreak` を読むだけ。**現状のインライン `Text` と同一のプロパティを同一の方法で参照する**ため、再描画挙動は現状から変化しない（#37 で出荷済みの表示挙動を維持）。ViewModel・Repository は変更しない。

### ローカライズ

`timer.todays_count_with_streak`（🔥 emoji 入り）を **削除**し、2キーを新設（ja / en 両方）:

| key | ja | en |
| --- | --- | --- |
| `timer.stat.today` | `今日 %d` | `Today %d` |
| `timer.stat.streak` | `連続 %d` | `Streak %d` |

**文言変更（ユーザー確認済み）**: 単位「回/日」を省略し、英語まじりの「Streak」→「連続」に統一。アイコンが意味を補うため省スペースを優先。

## Testing

View は純表示・新規ロジックなしのため、unit test の対象は薄い。プロジェクトに ViewInspector / snapshot 基盤は無い。

- **localization 整形テスト**（Quick/Nimble、既存 `LeafTimerTests` ターゲット）: `timer.stat.today` / `timer.stat.streak` が ja / en 両ロケールで `%d` を整形でき、結果に数値が含まれることを検証。キー欠落・英訳漏れ・`%d` 取り違えのガード。
- **手動 Simulator 検証**: `ios-simulator-app-verification` / `ios-simulator-locale-testing` skill を用い、work/break × light/dark × ja/en でスクリーンショットを取得し PR に添付。

## References

- Issue #39（スクリーンショット2枚: トップ画面 / 履歴画面）
- 既存パターン: `HistoryView.statRow(icon:color:text:)`、`EnhancedSettingView`（`leaf.fill`/`.green`）
- 関連 spec: `2026-05-28-pomodoro-log-visualization-design.md`（streak / count の導入元）
