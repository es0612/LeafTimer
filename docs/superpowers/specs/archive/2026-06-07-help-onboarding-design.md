# #4 ヘルプ導入（初回オンボーディング）設計

- Issue: #4「ヘルプ導入をつける。」
- 日付: 2026-06-07
- フェーズ: brainstorming（設計合意済み）→ 次は writing-plans

## 背景・目的

LeafTimer はポモドーロタイマーアプリ。起動するといきなりメイン画面（`TimerView`）が表示され、育つ葉っぱ🍃のGIF・カウントダウン・開始/停止ボタン・統計チップ2つ（今日の回数🍃 / 連続日数🔥）が並ぶ。しかし **オンボーディング/チュートリアル/ヘルプは現状ゼロ**で、新規ユーザーは「葉・タイマー・ボタン・チップが何を意味するか」を説明されないまま放り込まれる。

本 issue のゴールは、新規ユーザーの「最初の戸惑い」を解消する軽量なヘルプ導線を追加すること。

## 確定した要件（ブレストで決定）

| 軸 | 決定 |
| --- | --- |
| ヘルプの形 | **初回オンボーディング**（アプリ初回起動時のみ表示） |
| ボリューム | **ミニマル2画面**（離脱を避ける） |
| 再表示動線 | **設定に「使い方をもう一度見る」を追加**（同じオンボーディングを再生） |
| 既存ユーザー | **新規インストールにだけ表示**（既存ユーザーには出さない） |

## 採用アプローチ

**案A: 再利用可能な `OnboardingView` を `.fullScreenCover` で2箇所から提示。**

理由：既存構造（UIKit `AppDelegate` → `UIHostingController` → `TimerView`）に最小侵襲で、テスト用の `UserDefaultsWrapper` 差し替え seam をそのまま使えるため。

不採用案：
- 案B（ルート coordinator 新設）: ルート構造変更で影響大。ミニマル方針に過剰。
- 案C（`.sheet` 提示）: スワイプで閉じられ没入感が低くオンボには不向き。

## コンポーネント構成

### 新規 `OnboardingView.swift`（`app/LeafTimer/View/`）
- `TabView` + `.tabViewStyle(.page)` で**2ページのスワイプ**＋ページドット表示。
- 1ページ目: 右上に「スキップ」。2ページ目: 下部に「はじめる」ボタン。
- 背景は **`.ultraThinMaterial` + semantic color（`.primary` / `.secondary` / `.green`）** を使い light/dark 両対応にする。
  - ※ ハードコード白（`rgba(255,255,255,.x)` 相当）は light モードで不可視になる（Issue #39 の教訓）。`OnboardingView` は full-screen cover なので work/break 背景は無関係だが、light/dark と ja/en は影響する。
- 状態を持たない部品とし、完了/スキップで `onFinish: () -> Void` を呼ぶだけ。

### `UserDefaultItem`（`app/LeafTimer/Components/UserDefaultItem.swift`）
- `case hasSeenOnboarding` を追加。

### `SettingViewModel`（`app/LeafTimer/ViewModel/SettingViewModel.swift`）
既存の `readBool` / `write(isOn:item:)` / `readInt` を流用し、以下を追加：
- `shouldShowOnboarding() -> Bool`（初回ゲート判定）
- `markOnboardingSeen()`（初回完了時にフラグ書き込み）

## データフロー（初回ゲート）

`TimerView.onAppear` で `SettingViewModel.shouldShowOnboarding()` を評価する：

```
shouldShowOnboarding():
  if readBool(hasSeenOnboarding):
      return false                         # 既に見た / シード済み
  if readInt(totalPomodoroCount) > 0:
      write(isOn: true, item: hasSeenOnboarding)  # 既存ユーザー → シードして抑制
      return false
  return true                              # 真の新規ユーザー
```

- `totalPomodoroCount` はポモドーロ完了ごとに `TimerViewModel`（`TimerViewModel.swift:180-185`）で `loadData + 1` → `saveData` され、確実にインクリメントされている（live コードで verify 済み）。よって「既存ユーザー = 1回以上完了経験あり」の代理指標として信頼できる。
  - インストールしただけで未完了のユーザーは `count == 0` のためオンボーディングが出るが、実質未使用なので妥当。
- 初回表示の完了/スキップ時に `markOnboardingSeen()` で `hasSeenOnboarding = true` を書き込む（二度と出ない）。
- 設定の「もう一度見る」からの再生は **フラグを書かない**（見返しても初回状態に戻さない）。

## 変更ファイル一覧

| ファイル | 変更 |
| --- | --- |
| `View/OnboardingView.swift` | **新規**（要 target attach → `make precheck` / `make sort`） |
| `Components/UserDefaultItem.swift` | `hasSeenOnboarding` 追加 |
| `ViewModel/SettingViewModel.swift` | `shouldShowOnboarding()` / `markOnboardingSeen()` 追加 |
| `View/TimerView.swift` | `@State showOnboarding` ＋ `.fullScreenCover` ＋ `onAppear` ゲート |
| `View/EnhancedSettingView.swift` | 「ヘルプ」Section に「使い方をもう一度見る」行＋`.fullScreenCover` |
| `App/ja.lproj/Localizable.strings` | 日本語文言を追加 |
| `App/en.lproj/Localizable.strings` | 英語文言を追加 |

> **ローカライズの注意:** このアプリは String Catalog（`.xcstrings`）ではなく**クラシックな `.strings`** を使う（`ja.lproj` / `en.lproj` の `Localizable.strings`、形式は `"key" = "value";`）。よって `xcstrings-bulk-update` 系スキルは**不適合**。ja/en 両方に同じキーを追加し、`// MARK:` のセクション構成に倣う。既存の `StatLocalizationTests.swift`（`app/LeafTimerTests/`）と同様に、必要ならオンボーディングキーのローカライズ存在テストを追加する。

## 文言ドラフト（ja / en）

| | 日本語 | English |
| --- | --- | --- |
| 1 タイトル | LeafTimer へようこそ 🍃 | Welcome to LeafTimer 🍃 |
| 1 本文 | 集中した時間を、葉っぱを育てて記録しよう。 | Grow a leaf as you focus and watch your effort take root. |
| 2 タイトル | 使い方はかんたん | How it works |
| 2 本文 | ボタンを押すとタイマー開始。集中するほど葉っぱが育ち、今日の回数と連続日数も記録されます。 | Tap to start the timer. Your leaf grows as you focus, and your daily count and streak are tracked. |
| ボタン | スキップ / はじめる | Skip / Get Started |
| 設定行 | 使い方をもう一度見る | View the intro again |

※ in-app の英語文言なので emoji 可。ASC の「英語ロケールで emoji 不可」ルールはメタデータ（Description / What's New）限定で、in-app 文字列には適用されない。

## テスト方針（TDD）

- **`SettingViewModel`**（in-memory な `UserDefaultsWrapper` テストダブルを使用）
  - 新規（flag=false, count=0）→ `shouldShowOnboarding() == true`
  - 既存（count>0）→ `false` かつ `hasSeenOnboarding` が `true` にシードされる
  - `markOnboardingSeen()` 後 → `shouldShowOnboarding() == false`
- **`OnboardingView`**（ViewInspector）: 2ページ存在 / 「はじめる」で `onFinish` が発火
- `.fullScreenCover` 自体の検証は ViewInspector で深追いせず、ロジックは ViewModel 側テストで担保する。

## 完了基準（done-criteria）

- `make tests`（`precheck` / `sort` 含む）が green。
- **Simulator で light/dark × ja/en の4状態を目視**し、文字・背景の可読性を確認（Issue #39 教訓）。
- 既存ユーザー（`totalPomodoroCount > 0` をシード投入した状態）でオンボーディングが**出ないこと**を確認。
- 新規ユーザー（フラグ無し・count=0）で初回1回だけ出て、2回目以降は出ないことを確認。
- 設定の「もう一度見る」で再生でき、再生してもフラグが初回状態に戻らないことを確認。

## スコープ外（YAGNI）

- 3画面以上・コーチマーク・動画・FAQ・設定内の常設ヘルプページ。
- 休憩 / 履歴 / 設定の詳細解説（ミニマル方針）。
- `SettingView.swift`（dead code 疑い）の整理 — 本 issue とは無関係なので触らない。
