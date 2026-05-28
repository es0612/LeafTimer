# Pomodoro 実行ログ可視化 設計

- **Issue**: [#8 ポモドーロの実行ログを可視化して達成感を得たい](https://github.com/es0612/LeafTimer/issues/8)
- **日付**: 2026-05-28
- **対象**: app/LeafTimer (iOS, SwiftUI, MVVM)

## Context

LeafTimer の現状の達成感表現は「画面下部に表示される今日のセッション数」のみ。`product.md` の Key Value Proposition には既に「日別カウント機能による達成感と習慣化支援」が掲げられており、Issue #8 はこの方向性を **streak (連続日数) と最長記録の追加** で強化するもの。

調査結果:

- セッション完了情報は `TimerViewModel.countWork()` で `userDefaultWrapper.saveData(key: "yyyy/MM/dd", value: count)` として保存されているが、**個別日付の retrieve 機構がなく、過去日列挙不能**。
- `View/Components/SessionStatsView.swift` は dead code (App entry / TabView / NavigationStack から参照ゼロ)。色 hardcoded / 文言が "Today" "Weekly Avg" の英語固定 / `weeklyAverage` が `todaysCount * 0.8` の mock。
- `TimerViewModel+extensions.swift` の `weeklyAverage` は computed property だが mock 値を返すのみ。
- 既存パターン: MVVM + protocol-based DI (`UserDefaultsWrapper` / `TimerManager` / `AudioManager` のいずれも protocol + Default 実装 + Spy)。

## Goals

- ユーザーが「今日のセッション数」だけでなく **連続日数 (streak)** と **最長記録** を見えるようにする。
- 過去 7 日間の振り返り画面 (棒グラフ) を提供する。
- product.md の「シンプル」「視覚的な癒し」「日本語対応」を維持する。
- 既存 MVVM + DI パターンを踏襲し、テスタブルに保つ。

## Non-Goals (このスコープでは扱わない)

- 個別セッション粒度のログ保存 (開始時刻 / duration / 集中度評価 等)。
- カレンダー型ヒートマップ (GitHub 風)。
- 月間サマリ / 任意月選択 / 年間グラフ。
- セッション完了時の追加演出 (お祝いトースト / アニメーション)。
- iCloud / リモート同期。
- Streak 復活機能 (Duolingo の "streak freeze" 相当)。
- 通知 / リマインダー (「streak が途切れそう」プッシュ通知 等)。

これらは将来別 Issue 化を想定。

## Architecture

既存 MVVM + DI を踏襲。新責務 (履歴・streak 集計) は既存の `UserDefaultsWrapper` には混ぜず別 protocol に分離する。

```
View                ViewModel              Component
TimerView    ←→    TimerViewModel  ──→    UserDefaultsWrapper      (既存・変更なし)
                                   ──→    SessionStatsRepository   (新規)
HistoryView  ←→    HistoryViewModel ─→    SessionStatsRepository   (新規)
                                          LocalSessionStatsRepository (新規)
                                                  ↓
                                          UserDefaults
                                          (1 key "sessionStats" に SessionStats を JSON 保存)
```

新責務を別 protocol に切り出す理由:

- 「1 protocol = 1 capability」を維持し、Test 時の Spy 粒度を最小化する。
- `UserDefaultsWrapper` を既存呼び出し元 (`SettingViewModel` 等) との共有のまま変えず、影響範囲を絞る。

## Components

### 新規 (Components/)

**`SessionStats`** (`app/LeafTimer/Components/SessionStats.swift`)

```swift
struct SessionStats: Codable, Equatable {
    var dailyCount: [String: Int]   // "yyyy/MM/dd" → 当日の完了セッション数
    var totalCount: Int             // 累計セッション数
    var currentStreak: Int          // 現在の連続日数
    var longestStreak: Int          // 最長連続日数
    var lastSessionDate: String?    // streak 判定用 ("yyyy/MM/dd" or nil)

    static let empty = SessionStats(dailyCount: [:], totalCount: 0,
                                     currentStreak: 0, longestStreak: 0,
                                     lastSessionDate: nil)
}
```

**`SessionStatsRepository`** protocol (`app/LeafTimer/Components/SessionStatsRepository.swift`)

```swift
protocol SessionStatsRepository {
    func load() -> SessionStats
    @discardableResult
    func recordSession(today: String) -> SessionStats
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)]
}
```

- `recordSession` は内部で `load` → mutate → `save` を完結させ、新しい `SessionStats` を return する (ViewModel 側で reload 呼び出し不要)。
- 「現在日」は `DateManager.getToday()` の戻り値を引数として注入する形で受け取り (pure function 寄り、テスタブル)。
- `recentDailyCounts` は古い→新しい順、欠損日は count=0 で埋める。

**`LocalSessionStatsRepository`** (`app/LeafTimer/Components/LocalSessionStatsRepository.swift`)

- `SessionStatsRepository` の本番実装。`UserDefaults.standard` を保持し JSON 永続化。
- key は単一: `"sessionStats"`。
- Migration: 初回 `load()` で `UserDefaults.bool(forKey: "statsMigrated") == false` の場合、既存の `yyyy/MM/dd` 形式 Int keys を新 `dailyCount` に集約し、totalCount / lastSessionDate / longestStreak / currentStreak を遡及計算して新 1 key で保存。旧 key 自体は安全のため削除しない (副作用ゼロのため放置)。Sentinel `"statsMigrated" = true` を立てて 2 度目以降は migration を skip する。

### 新規 (ViewModel/, View/)

**`HistoryViewModel`** (`app/LeafTimer/ViewModel/HistoryViewModel.swift`)

- `@Published` プロパティ: `last7Days: [(label: String, count: Int)]`, `currentStreak: Int`, `longestStreak: Int`, `totalCount: Int`。
- `init(repository: SessionStatsRepository)` で DI。
- `load()` 内で `repository.load()` と `repository.recentDailyCounts(days: 7, endingAt: today)` を呼び表示プロパティに反映する。

**`HistoryView`** (`app/LeafTimer/View/HistoryView.swift`)

- VStack: 上に「🔥 現在 N 日連続 / 最長 M 日 / 累計 K セッション」、下に過去 7 日棒グラフ。
- 棒グラフは SwiftUI 標準のみで実装 (`HStack(alignment: .bottom)` + 各日 `Rectangle().frame(height: …)`)。Charts framework は導入しない (target iOS / learning curve / シンプル路線への配慮)。
- `onAppear` で `viewModel.load()` を呼ぶ。

### 修正 (既存ファイル)

**`TimerViewModel`** (`app/LeafTimer/ViewModel/TimerViewModel.swift`)

- init に `sessionStatsRepository: SessionStatsRepository` を追加。
- `countWork()` 内の `userDefaultWrapper.saveData(key: today, value: todaysCount)` を **削除** し、`sessionStatsRepository.recordSession(today: today)` 呼び出しに置換。返り値 `stats` から `self.todaysCount` / `self.currentStreak` / `self.longestStreak` を更新。
- `@Published var currentStreak: Int` / `@Published var longestStreak: Int` を新設 (TimerView の表示用)。
- `readData()` で `sessionStatsRepository.load()` を呼び初期化。

**`TimerView`** (`app/LeafTimer/View/TimerView.swift`)

- 下部の `Text("today's count …")` を「`今日 %d 回 🔥 %d 日連続`」(ja) / 英 plural 版に変更 (1 行で表示)。
- toolbar に履歴ボタンを追加 (`NavigationLink(destination: HistoryView(viewModel: HistoryViewModel(repository: ...)))`、SF Symbol or 既存アイコンスタイル)。

**`AppDelegate`** (`app/LeafTimer/App/AppDelegate.swift`)

- DI 配線に `LocalSessionStatsRepository()` を追加し `TimerViewModel(..., sessionStatsRepository: ...)` に注入。
- `HistoryView` 用の `SessionStatsRepository` は TimerView 側から `NavigationLink` で渡す (同インスタンス共有、ライフサイクルは TimerView 経由)。

### 削除

- 既存の `app/LeafTimer/View/Components/SessionStatsView.swift` (dead code)。
- `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift` の `weeklyAverage` (mock 値、利用箇所なし)。利用箇所が他に無いか PR 作成時に再 grep して確認すること。

## Data Flow

### フロー 1: セッション完了

```
TimerManager.tick → tomatoFinished/.complete
   ↓
TimerViewModel.countWork()
   today = DateManager.getToday()        // "2026/05/28"
   ↓
sessionStatsRepository.recordSession(today: today)
   ── 内部処理 ──
   1) stats = load()
   2) stats.totalCount += 1
   3) stats.dailyCount[today, default: 0] += 1
   4) streak 更新:
      last = stats.lastSessionDate
      if last == today                   → streak は変えない (同日 2 件目以降)
      else if last == yesterday(today)   → currentStreak += 1
      else                               → currentStreak = 1
      longestStreak = max(longestStreak, currentStreak)
   5) stats.lastSessionDate = today
   6) save(stats)
   7) return stats
   ↓
self.todaysCount   = stats.dailyCount[today] ?? 0
self.currentStreak = stats.currentStreak
self.longestStreak = stats.longestStreak
   ↓
@Published 経由で TimerView 自動再描画
```

### フロー 2: HistoryView 表示

```
TimerView.toolbar 履歴ボタン tap
   ↓ NavigationLink(destination: HistoryView(...))
HistoryView.onAppear
   ↓
HistoryViewModel.load()
   stats = repository.load()
   last7Days = repository.recentDailyCounts(days: 7, endingAt: today)
   self.currentStreak / longestStreak / totalCount = stats から代入
   ↓
HistoryView 表示
```

### フロー 3: 初回起動時 migration

```
LocalSessionStatsRepository.load()
   if UserDefaults.bool("statsMigrated") == false:
     1) UserDefaults.dictionaryRepresentation から yyyy/MM/dd 形式の key を抽出
     2) その Int 値を新 SessionStats.dailyCount に集約 (Int 以外型は skip)
     3) totalCount = dailyCount.values.sum
     4) longestStreak / currentStreak / lastSessionDate を遡及計算
     5) save(stats)
     6) UserDefaults.set(true, "statsMigrated")
     ※ 旧 key 自体は削除しない (副作用ゼロのため放置)
```

### 日付境界の挙動

- `DateManager.getToday()` は端末ローカル TZ で `"yyyy/MM/dd"` を返す (既存実装に準拠)。
- 日跨ぎセッション (23:55 開始 → 00:20 完了) は `countWork()` 時点の `getToday()` を使う = **完了時の日付に記録** (既存挙動と一致)。
- streak 判定の「昨日」は `Calendar.current` で `today - 1 day` を計算。タイムゾーン跨ぎ移動 (旅行等) は考慮しない (端末ローカル運用が前提)。

## Error Handling

LeafTimer は「ログが失われても作業継続を妨げない」設計 (タイマー機能が最優先、stats は補助)。

| 失敗ケース | ふるまい |
|---|---|
| `SessionStats` の JSON decode 失敗 (データ破損) | `SessionStats.empty` を返してアプリ続行。`"statsMigrated"` sentinel はそのまま (migration 繰り返さない) |
| `SessionStats` の JSON encode 失敗 | 実装上 Codable 適合済みで失敗ケースなし。`try?` で吸収、UI 側に伝えない |
| Migration 中の旧 key パース失敗 | その key を skip、他 key の集約は続行 |
| `Calendar.current` で昨日計算失敗 | `currentStreak = 1` にフォールバック |
| `recentDailyCounts` で `dailyCount` に該当 key 無し | `count = 0` を返す (棒グラフは 0 高さ) |

- ユーザー向けエラー UI は出さない (集中阻害を避ける)。
- `SessionStatsRepository` の API は throws しない (ViewModel の差分最小化)。

## Testing

既存パターン (`Spy[Protocol].swift` + `[Feature]Spec.swift`、`LeafTimerTests/`) を踏襲。

### Test double 新設

- **`SpySessionStatsRepository.swift`** (`app/LeafTimerTests/`)
  - `load()` の戻り値固定、`recordSession(today:)` の呼び出し履歴と引数、戻り値を spy。
  - 既存 `SpyAudioManager` / `SpyTimerManager` と同じ受動 pattern。

### 新規テスト

- **`SessionStatsLogicSpec.swift`** — `LocalSessionStatsRepository` のロジック検証 (UserDefaults は in-memory な `UserDefaults(suiteName:)` で差し替え):
  - 空状態 → `recordSession(today: "2026/05/28")` → totalCount=1, currentStreak=1, longestStreak=1, dailyCount=["2026/05/28": 1]。
  - 同日 2 回目 → totalCount=2, currentStreak=1 (変化なし), dailyCount[today]=2。
  - last="2026/05/27", today="2026/05/28" → currentStreak=2。
  - last="2026/05/26", today="2026/05/28" (1 日空き) → currentStreak=1。
  - currentStreak=10, longestStreak=10 で連続継続 → currentStreak=11, longestStreak=11。
  - `recentDailyCounts(days:7, endingAt: "2026/05/28")` で間欠日が 0 埋め、古い→新しい順。

- **`SessionStatsMigrationSpec.swift`** — 旧形式から新形式への移行:
  - 旧 `yyyy/MM/dd → Int` keys のみの UserDefaults を load → 全 key が `dailyCount` に集約。
  - `"statsMigrated"` sentinel が立つ。
  - 2 度目の load では migration 処理が走らない。
  - 旧 keys に Int 以外型が混在しても skip して他 keys は集約。
  - `longestStreak` / `currentStreak` / `lastSessionDate` が遡及計算される。

- **`HistoryViewModelSpec.swift`** — ViewModel の表示用整形:
  - `SpySessionStatsRepository` を inject、`load()` を呼ぶと `last7Days` / `currentStreak` / `longestStreak` / `totalCount` が `@Published` に反映される。
  - 空 stats を返す repo の場合、`last7Days` は全 0 の 7 件。

### 既存テスト修正

- **`TimerViewSpec.swift`**:
  - `TimerViewModel` の init に `SpySessionStatsRepository` を inject。
  - セッション完了系 test で `recordSession(today:)` が 1 回だけ呼ばれることを assert (`userDefaultWrapper.saveData` の検証は削除)。
  - `todaysCount` / `currentStreak` / `longestStreak` が `@Published` で更新されることを検証。

### Localization

新規 String Catalog キー (i18n):

| key | ja | en (plural required) |
|---|---|---|
| `timer.todays_count_with_streak` | `今日 %d 回 🔥 %d 日連続` | `Today %d · 🔥 %d-day streak` (one/other) |
| `history.title` | `履歴` | `History` |
| `history.current_streak` | `現在 %d 日連続` | `%d-day current streak` (one/other) |
| `history.longest_streak` | `最長 %d 日` | `Longest: %d days` (one/other) |
| `history.total_sessions` | `累計 %d セッション` | `%d total sessions` (one/other) |
| `history.last_7_days` | `過去 7 日` | `Last 7 days` |

- en の **plural variations** を String Catalog で必ず定義し、Swift 側は `String(format:)` ではなく `String(localized: "\(count) ...")` の補間形を使う (CLAUDE.md の `xcstrings-plural-variations` skill 教訓: `String(format:)` は plural variations を silent bypass する)。
- 既存の `LocalizationStringCatalogTests` 系で「en 翻訳欠落 / plural 未定義」を検出 → 全 green を確認。
- `xcstrings-bulk-update` skill のフローで `.xcstrings` を編集 (Python `json.dump` は形式破壊リスクがあるため使わない)。

### Verification (実機/Simulator)

- `ios-simulator-app-verification` skill のフロー: UserDefaults を新形式に直接書いて起動し HistoryView を screenshot 確認。
- `ios-simulator-locale-testing` skill で ja/en 切替時の plural 文字列を side-by-side で確認 ("1 day" vs "2 days" の振り分け)。

## Implementation Order (writing-plans への hand-off の準備)

1. `SessionStats` (Codable struct) と `SessionStatsRepository` protocol を追加。
2. `LocalSessionStatsRepository` 実装 + migration ロジック (まずは新規 path のみ、migration は後ステップで)。
3. `SessionStatsLogicSpec` を TDD で先に書きながら実装。
4. Migration ロジックと `SessionStatsMigrationSpec` 追加。
5. `TimerViewModel` の修正 + `SpySessionStatsRepository` + `TimerViewSpec` 更新。
6. `HistoryViewModel` / `HistoryView` の追加 + `HistoryViewModelSpec`。
7. `TimerView` 修正 (toolbar 履歴ボタン + 下部文言更新)。
8. String Catalog (`.xcstrings`) のキー追加 (xcstrings-bulk-update skill 経由)。
9. `AppDelegate` の DI 配線変更。
10. 既存 `SessionStatsView.swift` 削除 + `weeklyAverage` 削除。
11. Localization テスト + Simulator verification (ja/en plural、screenshot)。

各ステップを TDD (test → fail → impl → green → refactor) で進める。

## Open Questions

- HistoryView の **toolbar アイコン** は SF Symbol (`chart.bar.fill` 等) を使うか、既存アセットスタイルに合わせて自作するか。実装時に既存 `settingIcon` / `reloadIcon` のスタイルと比較して決定。
- 棒グラフの **配色** は既存テーマ (緑 `#6b8e6b`) を流用 (現状の navigation / button 配色と統一)。
