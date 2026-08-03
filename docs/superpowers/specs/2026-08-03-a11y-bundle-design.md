# Issue #59 + #60: A11y/i18n バンドル — 設計

- 日付: 2026-08-03
- 対象 Issue: #59 (VoiceOver 対応) / #60 (設定画面のハードコード英語文言解消)
- ステータス: 承認済み (スコープ・アプローチとも AskUserQuestion で確認済み)
- PR 構成: 1 ブランチ・1 PR、commit は issue ごとに分ける

## 背景 / 問題

- **#59**: accessibilityLabel が全 View で 0 件。開始/停止の `CircleButton`
  (`app/LeafTimer/View/Elements/CircleButton.swift`) は同心円 + 状態テキストの純粋な
  ビジュアル View で、`TimerView.swift:60-64` の `.onTapGesture` でタップ処理している。
  Button ではないため VoiceOver から操作不能。ツールバー 3 アイコン (リセット/履歴/設定)
  もラベル無し、残り時間 Text (`TimerView.swift:51`) にも accessibilityValue が無い。
- **#60**: 設定画面 (live な `EnhancedSettingView` + Settings セクション群) に
  未ローカライズの英語文言が約 17 箇所。i18n 基盤は **Localizable.strings (ja/en .lproj)**
  (String Catalog ではない)。`AboutSettingsSection` はローカライズ済みで対象外。

## スコープ

含む:

- #59: **TimerView のみ** (Issue 記載範囲どおり)。開始/停止 Button 化・ツールバー 3
  アイコンのラベル・残り時間の accessibilityLabel/Value。
- #60: `EnhancedSettingView.swift` (2箇所) / `TimerSettingsSection.swift` (4箇所) /
  `SoundSettingsSection.swift` (1箇所) / `ResetSettingsSection.swift` (約10箇所) の
  ハードコード英語文言の NSLocalizedString 化 + ja/en キー追加。

含まない:

- 設定画面のスライダー/トグルへの accessibilityLabel 付与 (別 issue 相当)
- Dynamic Type (#58) / Reduce Motion (#62) など他の a11y issue
- String Catalog への移行

## 設計

### #59: 本物の Button 化 (案A)

- `TimerView.swift:60-64` を
  `Button(action: didTapTimerButton) { CircleButton(viewModel: timerViewModel) }`
  + `.buttonStyle(.plain)` に置換。見た目は不変、セマンティクスだけ Button になる
  (VoiceOver / Switch Control / キーボード操作すべてに効く)。
- accessibilityLabel は状態連動: 停止中 =「タイマーを開始」/ 実行中 =「タイマーを停止」。
  実行中かどうかは `TimerViewModel` の既存状態 (`getButtonState()` が返す表示文字列の
  元になっている実行状態) から導出し、View 側で分岐する。
- ツールバー: リセット Button・履歴 NavigationLink・設定 NavigationLink に
  `.accessibilityLabel` を付与 (ja/en ローカライズ)。
- 残り時間 Text: `.accessibilityLabel` (「残り時間」) + `.accessibilityValue`
  (`getDisplayedTime()` の値) を付与。

不採用案 (案B): `.accessibilityAddTraits(.isButton)` + `accessibilityAction` を
onTapGesture に足す方式。VoiceOver 以外の支援技術に届かず、「ボタンのフリ」が残るため。

### #60: NSLocalizedString 化

- 対象文言を `NSLocalizedString("<key>", comment: "...")` に置換し、
  `app/LeafTimer/App/ja.lproj/Localizable.strings` と `en.lproj` の両方にキーを追加する。
- キー命名は既存規約 (`timer.stat.today` 等の dot 区切り) を踏襲し、
  `settings.<section>.<name>` 形式にする (例: `settings.reset.title`)。
- #59 の a11y ラベルも同じ仕組みでローカライズし、キーは `timer.a11y.<name>` 形式。

## テスト戦略 (TDD)

- **#60 / a11y ラベルキー**: 既存 `StatLocalizationTests` のパターンを踏襲した
  `SettingsLocalizationTests` を新設。新キー全部について「ja/en 両バンドルに存在し、
  値がキー自身と異なる」ことを検証。先にテストを書いて **RED (キー未登録)** を確認
  → キー追加 + コード置換で GREEN。
- **#59**: 既存 `ModernTimerViewSpec` (ViewInspector) に「開始/停止が `Button` として
  存在する」検証を追加。Button 化前に実行して **RED** を確認 → Button 化で GREEN。
- **新規テストファイルは target attach + `make precheck` で orphan でないことを確認**。
- **仕上げの目視検証**: Simulator で設定画面を ja/en 両ロケールでスクショ
  (`ios-simulator-locale-testing` skill)。TimerView は背景 4 状態ルールの対象だが、
  今回は色を触らないため light/dark 各 1 枚の回帰確認に留める。
- PR は新設した CI ゲート (pr-tests) の保護下で green を確認する。

## 成功基準

- VoiceOver で開始/停止がボタンとして読み上げられ、操作できる (ラベルは状態連動・ja/en)
- ツールバー 3 アイコンと残り時間が意味のある読み上げになる
- 設定画面に英語ハードコード文言が残らない (ja では日本語表示)
- 新設キーの欠落を SettingsLocalizationTests が検知できる
