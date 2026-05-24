# Issue #26 + #27: ダークモード視認性改善 + ビルド情報表示削除 — Design

- **Date**: 2026-05-24
- **Author**: Shinya (with Claude Opus 4.7)
- **Status**: Approved (brainstorming completed)
- **Related Issues**: [#26](https://github.com/es0612/LeafTimer/issues/26), [#27](https://github.com/es0612/LeafTimer/issues/27)

## 背景

### Issue #26: ダークモードの画面が暗すぎる
ユーザー報告: 「アイコンなど見えづらい。デザイン性が良くない」。
Explore 結果から根本原因が 3 レイヤーに分かれることが判明:

1. **カスタム PDF アイコンの dark 対応欠落**: `reloadIcon` / `settingIcon` / `splashIcon` の Contents.json に `template-rendering-intent` 指定が無く、PDF の色がそのまま使われている。SwiftUI 側で `.foregroundColor(.primary)` を当てても効いていない (TimerView.swift:75, 80)。
2. **ハードコードされた gray / white**: TimerView / SessionStatsView / TimerControlsView の計 ~10 箇所で `Color(red: ..., ..., ...)` や `Color.white` を直接指定しており、ダークモードに追従しない。
3. **Color asset は完備済だが未活用**: `Assets.xcassets/Colors/` に `TextPrimary` / `BackgroundSecondary` 等 14 色が dark variant 込みで定義済だが、view 側で参照されていない。

### Issue #27: ビルド番号などユーザに見せる必要のない情報は不要
`ResetSettingsSection.swift:41-63` で `CFBundleShortVersionString` と `CFBundleVersion` を Settings 画面に表示している。ユーザー向け情報として不要。

### 同一 PR で扱う理由
両者とも UI 表面のみの変更で互いに独立。コンフリクトが起きないため 1 PR にまとめてレビュー負荷を最小化する。

## スコープ

ブレストの結果 **B 案 (アイコン + 主要画面の明らかな記述バグ)** に決定:

- ✅ アイコン: `reloadIcon` / `settingIcon` の template-rendering 化
- ✅ TimerView / SessionStatsView / TimerControlsView の hardcoded gray/white を semantic color へ置換
- ❌ ViewModel の circle button color (`getColor1`〜`4`) — 別 issue で扱う (C 案領域)
- ❌ splashIcon の dark variant — launch screen 専用で runtime ダークモード問題に無関係
- ❌ 全 hardcoded 色の design token 移行 — C 案領域、今回は実施しない

## 設計

### A. アイコン修正 (Issue #26 アイコン部分)

**対象ファイル**:
- `app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json`
- `app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json`

**変更**: `properties` ブロックを追加し `template-rendering-intent: template` を指定。

```json
{
  "images" : [ { "filename" : "reloadIcon.pdf", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

**Swift 側**: 変更不要。`TimerView.swift:75,80` の `.foregroundColor(.primary)` がこの設定変更で初めて有効化される。

### B. Hardcoded color 置換 (Issue #26 色部分)

ハイブリッド方針 — テキスト系は SwiftUI built-in (`.primary`/`.secondary`)、背景系は project の semantic asset を使う。

| ファイル                 | 行    | Before                                         | After                              |
|-------------------------|------|------------------------------------------------|------------------------------------|
| TimerView.swift         | 55   | `Color(red: 0.65, green: 0.65, blue: 0.65, opacity: 0.9)` (timer 文字) | `.primary.opacity(0.9)`            |
| TimerView.swift         | 66   | `Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9)` (本日カウント)  | `.secondary.opacity(0.9)`          |
| SessionStatsView.swift  | 22   | `Color(red: 0.3, green: 0.3, blue: 0.3)` (stat 数字)                 | `.primary`                         |
| SessionStatsView.swift  | 35   | `Color.white.opacity(0.9)` (カード背景)                                | `Color("BackgroundSecondary")`     |
| SessionStatsView.swift  | 49   | `Color(red: 0.3, green: 0.3, blue: 0.3)` (週平均数字)                | `.primary`                         |
| SessionStatsView.swift  | 62   | `Color.white.opacity(0.9)` (カード背景)                                | `Color("BackgroundSecondary")`     |
| TimerControlsView.swift | 52-53| `Color.white.opacity(0.3)` / `Color.white.opacity(0.1)` (stroke)       | `.primary.opacity(0.3)` / `.primary.opacity(0.1)` |
| TimerControlsView.swift | 78   | `Color.gray.opacity(0.2)` (reset 背景)                                 | `.secondary.opacity(0.2)`          |
| TimerControlsView.swift | 83   | `Color.gray.opacity(0.8)` (reset icon)                                 | `.secondary.opacity(0.8)`          |

#### 設計判断: なぜハイブリッドか
- `.primary` / `.secondary` は OS が light/dark で適切にコントラストを保証する標準色。テキスト用途では project asset を新設するより信頼性が高い。
- カード背景は project 固有の brand color が必要なため `BackgroundSecondary` asset を使う。これは既に dark variant 付きで定義済。
- stroke の `Color.white.opacity(...)` は dark 背景でも見える可能性があるが light モードで全く見えないバグになっている。`.primary.opacity(...)` にすると両モードで適切なコントラスト。

#### Opacity の扱い
SessionStatsView の背景 `Color.white.opacity(0.9)` → `Color("BackgroundSecondary")` で **opacity は外す**。理由: `BackgroundSecondary` asset は light/dark の双方で意図された色がチューニング済のため、追加の opacity は不要 (むしろ下地が透けて意図しない見た目になる)。screenshot で違和感があれば 0.95 等を後追いで足す。

### C. ビルド/バージョン表示削除 (Issue #27)

**対象**: `app/LeafTimer/View/Settings/ResetSettingsSection.swift:41-63`

**変更**: System セクションの VStack ブロックを丸ごと削除。`Bundle.main.infoDictionary` への参照もそこにしか無いため、Settings 画面からはアプリバージョン情報が完全に消える。

### D. 検証

`ios-simulator-app-verification` skill に従い:

1. `make tests` で既存ユニットテストの実行 (色値を直接テストしている箇所が無いことを確認)
2. `xcrun simctl boot` で iPhone 17 シミュレータ起動
3. アプリビルド → install
4. `xcrun simctl ui booted appearance light` → TimerView と Settings 画面 screenshot 撮影
5. `xcrun simctl ui booted appearance dark` → 同 screenshot
6. 計 4 枚 (TimerView light/dark, Settings light/dark) を PR description に添付

### E. テスト戦略

- **ユニットテスト**: 既存テストへの影響をまず確認。色値テストが無ければ追加せず通過確認のみ。
- **UI snapshot test**: プロジェクトに導入されておらず、今回も追加しない。
- **手動検証**: 上記 D の screenshot を一次エビデンスとする。

### F. PR / Commit 戦略

- **ブランチ名**: `feature/issue-26-27-dark-mode-improvements`
- **Commit 分割** (レビュー容易性のため):
  1. `Issue #27: ResetSettingsSection からバージョン/ビルド表示を削除`
  2. `Issue #26: reloadIcon/settingIcon を template 化 + hardcoded color を semantic asset へ置換`
- **PR タイトル**: `Issue #26 #27: ダークモード視認性改善 + ビルド情報表示削除`
- **PR 本文**: `Closes #26, Closes #27` + screenshot 4 枚 + scope の B 案を選んだ理由 + 残課題 (C 案領域は別 issue へ)

## リスク・残課題

- **ViewModel の circle button color 未対応**: ダークモードで円ボタンの色が浮く可能性が残る。別 issue (例: "Issue #26 後続: ViewModel の circle button を dark mode 対応") を triage 段階で作成済かを後で確認。無ければ別途立てる。
- **splashIcon は対象外**: 起動画面は一瞬しか出ないため優先度低。気になるようなら後続 issue。
- **template-rendering 化で PDF の元色が失われる**: reloadIcon / settingIcon は元々シンプルな線画 (推定) なのでこの方針で問題ないはずだが、screenshot で確認する。万一複雑な配色 PDF だった場合は方針 C (dark variant PDF 追加) に切り替える必要あり。

## 関連

- 過去 spec: `docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md`
- Issue triage: 同セッションで `daily-issue-triage` skill により #27 + #26 を選択
