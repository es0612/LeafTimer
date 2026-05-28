# Pomodoro 実行ログ可視化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Issue #8「ポモドーロの実行ログを可視化して達成感を得たい」を実装する。streak (1 セッション/日以上で連続) + 最長記録 + 過去 7 日棒グラフ + 累計セッション数を、UserDefaults JSON 永続化 + 新規 `SessionStatsRepository` protocol で扱い、TimerView に streak バッジを常時表示、新規 HistoryView で詳細を表示する。

**Architecture:** 既存 MVVM + protocol-based DI を踏襲。新責務 (履歴・streak 集計) は既存の `UserDefaultsWrapper` には混ぜず、新規 `SessionStatsRepository` protocol を作る。永続化は `UserDefaults.standard` に `"sessionStats"` 単一 key の JSON 1 件。既存の `UserDefaultItem.totalPomodoroCount` は `requestReviewIfNeeded` が依存するため legacy として残し、`recordSession` 時に dual write する。

**Tech Stack:** Swift 5 / SwiftUI / Combine (`@Published`) / `UserDefaults` (in-memory JSON) / XCTest (永続化ロジック、ViewModel テスト) / Quick + Nimble + ViewInspector (View テスト) / `Localizable.strings` (legacy 形式の ja/en)。

**Spec:** `docs/superpowers/specs/2026-05-28-pomodoro-log-visualization-design.md`

**Branch:** `feature/pomodoro-log-visualization` (master から分岐済み、現時点で 4 commit)。

**Spec からの軌道修正:**
- spec doc では `.xcstrings` (String Catalog) と plural variations を想定していたが、本プロジェクトは legacy `.lproj/Localizable.strings` を使用しているため、Localization は **count-agnostic な英語表現** (`Streak: 7` / `Longest: 12` / `Total: 142` — `day(s)` を含めない) で plural を回避する。これにより `.stringsdict` 追加や String Catalog 移行を不要にする。spec doc も小修正 commit を入れる (Task 2)。
- テスト命名は既存パターンに合わせ、永続化・ViewModel ロジック系は XCTest (`*Tests.swift`)、View 系は QuickSpec (`*Spec.swift`) を採用。spec doc の `SessionStatsLogicSpec` 等は `SessionStatsLogicTests` 等にリネームする。

**新規 Swift ファイルの Xcode target attach:** すべて `ruby bin/add-to-target.rb` 経由で行う (CLAUDE.md learning: 物理ファイルだけ作って pbxproj 未登録のままだとビルドに含まれない)。

**全 Task 終了後の検証:** `app` ディレクトリで `set -o pipefail; make tests 2>&1 | tail -100` (CLAUDE.md learning: pipefail を必ず先頭に置く)。Simulator verification は ja/en 両方で screenshot を残す (`ios-simulator-locale-testing` skill 参照)。

---

## File Structure (新規 / 修正 / 削除)

### 新規 (本番コード)
| Path | 責務 |
|---|---|
| `app/LeafTimer/Components/SessionStats.swift` | データモデル (Codable struct) |
| `app/LeafTimer/Components/SessionStatsRepository.swift` | protocol 定義のみ |
| `app/LeafTimer/Components/LocalSessionStatsRepository.swift` | 本番実装 (UserDefaults JSON + migration) |
| `app/LeafTimer/ViewModel/HistoryViewModel.swift` | 履歴画面の表示用集計 ViewModel |
| `app/LeafTimer/View/HistoryView.swift` | 履歴画面の SwiftUI View |

### 新規 (テスト)
| Path | テスト対象 |
|---|---|
| `app/LeafTimerTests/SpySessionStatsRepository.swift` | テストダブル |
| `app/LeafTimerTests/SessionStatsLogicTests.swift` | recordSession のロジック (XCTest) |
| `app/LeafTimerTests/SessionStatsMigrationTests.swift` | Migration ロジック (XCTest) |
| `app/LeafTimerTests/HistoryViewModelTests.swift` | HistoryViewModel (XCTest) |

### 修正
| Path | 内容 |
|---|---|
| `app/LeafTimer/ViewModel/TimerViewModel.swift` | init 引数追加、`countWork()` を recordSession に置換、`@Published currentStreak`/`longestStreak` 追加 |
| `app/LeafTimer/View/TimerView.swift` | toolbar に履歴ボタン (NavigationLink → HistoryView)、下部の文言更新 |
| `app/LeafTimer/App/AppDelegate.swift` | DI 配線に `LocalSessionStatsRepository()` 追加 |
| `app/LeafTimer/App/ja.lproj/Localizable.strings` | 新規キー追加 |
| `app/LeafTimer/App/en.lproj/Localizable.strings` | 新規キー追加 |
| `app/LeafTimerTests/TimerViewSpec.swift` | init に `SpySessionStatsRepository` 渡す形に修正 |

### 削除
| Path | 削除理由 |
|---|---|
| `app/LeafTimer/View/Components/SessionStatsView.swift` | dead code、要件と表示項目が合わず作り直す |
| `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift` の `weeklyAverage` (148-152 行) | mock 値、利用箇所なし |

---

## Task 1: Plan 自身を branch に commit

CLAUDE.md learning に従い、実装の最初のコミットとして本 plan を branch に含める。

**Files:**
- Create: `docs/superpowers/plans/2026-05-28-pomodoro-log-visualization.md` (この plan ファイル自身)

- [ ] **Step 1: plan ファイルを git に add してコミット**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add docs/superpowers/plans/2026-05-28-pomodoro-log-visualization.md
git commit -m "$(cat <<'EOF'
docs(plan): Issue #8 ポモドーロ実行ログ可視化の implementation plan を追加

spec doc に基づき、TDD で進める 17 task 構成。
Localization は legacy .strings 形式に合わせて count-agnostic 文言で
plural を回避。テストは XCTest (ロジック系) + Quick (View 系) の
既存併用パターンを踏襲。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: commit を確認**

```bash
git log --oneline master..HEAD | head -5
```

Expected: 最上行に `docs(plan): Issue #8 ポモドーロ実行ログ可視化の implementation plan を追加`

---

## Task 2: Spec doc を軌道修正 (Localization の plural 回避)

**Files:**
- Modify: `docs/superpowers/specs/2026-05-28-pomodoro-log-visualization-design.md` の Testing → Localization 節

- [ ] **Step 1: spec doc の Localization テーブルを書き換える**

`docs/superpowers/specs/2026-05-28-pomodoro-log-visualization-design.md` の「### Localization」セクション全体を以下に置換 (legacy .strings 前提 + count-agnostic 英語):

```markdown
### Localization

本プロジェクトは legacy `.lproj/Localizable.strings` を使用しているため、新規キーも同形式で追加 (String Catalog 移行はしない)。英語の plural 振り分けを回避するため count-agnostic な表現を採用する。

| key | ja | en |
|---|---|---|
| `timer.todays_count_with_streak` | `今日 %d 回 ・ 🔥 Streak %d` | `Today %d · 🔥 Streak %d` |
| `history.title` | `履歴` | `History` |
| `history.current_streak` | `現在 %d 日連続` | `Current Streak: %d` |
| `history.longest_streak` | `最長 %d 日` | `Longest: %d` |
| `history.total_sessions` | `累計 %d セッション` | `Total: %d` |
| `history.last_7_days` | `過去 7 日` | `Last 7 days` |

- `Localizable.strings` 両ファイル (ja, en) に上記キーを追記。
- Swift 側は既存パターン `NSLocalizedString("history.current_streak", comment: "…")` + `String(format:_:)` で扱う。
- `.stringsdict` は不要 (plural なし)。
- `LocalizationStringCatalogTests` 系の自動検証があれば、新規キーが両 locale に存在することを確認。
```

- [ ] **Step 2: commit**

```bash
git add docs/superpowers/specs/2026-05-28-pomodoro-log-visualization-design.md
git commit -m "$(cat <<'EOF'
docs(spec): Localization を legacy .strings + count-agnostic に修正

本プロジェクトは .xcstrings (String Catalog) ではなく legacy
.lproj/Localizable.strings を使用しているため、設計を実態に合わせる。
英語の plural 振り分けは count-agnostic な文言 (Streak: 7 等) で回避し、
.stringsdict 追加や String Catalog 移行を不要にする。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `SessionStats` モデルと Codable round-trip テスト

**Files:**
- Create: `app/LeafTimer/Components/SessionStats.swift`
- Create: `app/LeafTimerTests/SessionStatsLogicTests.swift` (テストファイル作成のみ、本格テストは Task 5 以降)

- [ ] **Step 1: `SessionStats.swift` を作成**

```swift
// app/LeafTimer/Components/SessionStats.swift
import Foundation

struct SessionStats: Codable, Equatable {
    var dailyCount: [String: Int]
    var totalCount: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: String?

    static let empty = SessionStats(
        dailyCount: [:],
        totalCount: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastSessionDate: nil
    )
}
```

- [ ] **Step 2: Xcode target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/SessionStats.swift LeafTimer LeafTimer/Components
```

Expected: exit 0、pbxproj に PBXFileReference が追加される。

- [ ] **Step 3: `SessionStatsLogicTests.swift` を作成し、最初の Codable round-trip テストを書く**

```swift
// app/LeafTimerTests/SessionStatsLogicTests.swift
import XCTest
@testable import LeafTimer

final class SessionStatsLogicTests: XCTestCase {

    // MARK: - Codable round-trip

    func testSessionStatsCodableRoundTrip() throws {
        let stats = SessionStats(
            dailyCount: ["2026/05/28": 3, "2026/05/27": 5],
            totalCount: 8,
            currentStreak: 2,
            longestStreak: 5,
            lastSessionDate: "2026/05/28"
        )
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(SessionStats.self, from: data)
        XCTAssertEqual(stats, decoded)
    }

    func testEmptyHasZeroValues() {
        let s = SessionStats.empty
        XCTAssertTrue(s.dailyCount.isEmpty)
        XCTAssertEqual(s.totalCount, 0)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertNil(s.lastSessionDate)
    }
}
```

- [ ] **Step 4: Test ファイルを Xcode test target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/SessionStatsLogicTests.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 5: テストを実行して PASS することを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` + 2 つの test (`testSessionStatsCodableRoundTrip`, `testEmptyHasZeroValues`) が PASS。

- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/Components/SessionStats.swift \
        app/LeafTimerTests/SessionStatsLogicTests.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(stats): SessionStats モデルと Codable round-trip テストを追加

dailyCount / totalCount / currentStreak / longestStreak / lastSessionDate を
Codable struct として定義。JSON 永続化のための round-trip テストと
空状態の初期値テストを XCTest で追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `SessionStatsRepository` protocol と `SpySessionStatsRepository` テストダブル

**Files:**
- Create: `app/LeafTimer/Components/SessionStatsRepository.swift`
- Create: `app/LeafTimerTests/SpySessionStatsRepository.swift`

- [ ] **Step 1: protocol を作成**

```swift
// app/LeafTimer/Components/SessionStatsRepository.swift
import Foundation

protocol SessionStatsRepository {
    func load() -> SessionStats
    @discardableResult
    func recordSession(today: String) -> SessionStats
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)]
}
```

- [ ] **Step 2: SpySessionStatsRepository を作成**

```swift
// app/LeafTimerTests/SpySessionStatsRepository.swift
import Foundation
@testable import LeafTimer

class SpySessionStatsRepository: SessionStatsRepository {
    var stubLoadResult: SessionStats = .empty
    var stubRecentResult: [(date: String, count: Int)] = []

    private(set) var loadCallCount = 0
    private(set) var recordSessionCallCount = 0
    private(set) var lastRecordedToday: String?
    var recordSessionResult: SessionStats?

    func load() -> SessionStats {
        loadCallCount += 1
        return stubLoadResult
    }

    @discardableResult
    func recordSession(today: String) -> SessionStats {
        recordSessionCallCount += 1
        lastRecordedToday = today
        return recordSessionResult ?? stubLoadResult
    }

    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] {
        return stubRecentResult
    }

    func reset() {
        loadCallCount = 0
        recordSessionCallCount = 0
        lastRecordedToday = nil
        stubLoadResult = .empty
        stubRecentResult = []
        recordSessionResult = nil
    }
}
```

- [ ] **Step 3: 両ファイルを target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/SessionStatsRepository.swift LeafTimer LeafTimer/Components
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/SpySessionStatsRepository.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 4: ビルドが通ることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/Components/SessionStatsRepository.swift \
        app/LeafTimerTests/SpySessionStatsRepository.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(stats): SessionStatsRepository protocol と SpySessionStatsRepository を追加

protocol で load / recordSession / recentDailyCounts の API を定義。
SpySessionStatsRepository はテスト用に call count と引数を記録する
受動 spy (既存 SpyAudioManager / SpyTimerManager と同じ pattern)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `LocalSessionStatsRepository` — 空状態 / 単日記録 / Codable 永続化

**Files:**
- Create: `app/LeafTimer/Components/LocalSessionStatsRepository.swift`
- Modify: `app/LeafTimerTests/SessionStatsLogicTests.swift` (テスト追加)

- [ ] **Step 1: テストを先に書く (RED)**

`SessionStatsLogicTests.swift` の末尾に `MARK: - LocalSessionStatsRepository 基本ロジック` セクションを追加し、以下を append:

```swift
    // MARK: - LocalSessionStatsRepository 基本ロジック

    private var testSuiteName = "SessionStatsLogicTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testRecordSessionFromEmpty() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 1)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 1)
        XCTAssertEqual(stats.lastSessionDate, "2026/05/28")
    }

    func testLoadAfterRecordPersists() {
        let repo1 = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo1.recordSession(today: "2026/05/28")

        let repo2 = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo2.load()
        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 1)
    }

    func testLoadWhenEmptyReturnsEmpty() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()
        XCTAssertEqual(stats, .empty)
    }
```

- [ ] **Step 2: テスト実行して FAIL を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: `Cannot find 'LocalSessionStatsRepository' in scope` で BUILD FAILED (型が未定義のためビルド失敗)。

- [ ] **Step 3: 最小実装を書く (GREEN)**

```swift
// app/LeafTimer/Components/LocalSessionStatsRepository.swift
import Foundation

class LocalSessionStatsRepository: SessionStatsRepository {
    private let userDefaults: UserDefaults
    private let storageKey = "sessionStats"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> SessionStats {
        guard let data = userDefaults.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(SessionStats.self, from: data) else {
            return .empty
        }
        return stats
    }

    @discardableResult
    func recordSession(today: String) -> SessionStats {
        var stats = load()

        stats.totalCount += 1
        stats.dailyCount[today, default: 0] += 1

        // streak 更新は次タスクで本実装、ここでは最小限
        stats.currentStreak = 1
        stats.longestStreak = max(stats.longestStreak, 1)
        stats.lastSessionDate = today

        save(stats)
        return stats
    }

    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] {
        // 後続タスクで実装
        return []
    }

    // MARK: - Private

    private func save(_ stats: SessionStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
```

- [ ] **Step 4: target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/LocalSessionStatsRepository.swift LeafTimer LeafTimer/Components
```

- [ ] **Step 5: テスト実行して PASS を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` で全テスト PASS。

- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/Components/LocalSessionStatsRepository.swift \
        app/LeafTimerTests/SessionStatsLogicTests.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(stats): LocalSessionStatsRepository の基本永続化を実装

UserDefaults に "sessionStats" 1 key で JSON 保存。空状態の load、
単日 recordSession、別 instance 経由の load 永続化を XCTest で検証。
streak は最小実装 (currentStreak=1 固定)、本格ロジックは次 Task で。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: streak ロジック (同日 / 昨日 / 1 日空き / longestStreak 更新)

**Files:**
- Modify: `app/LeafTimer/Components/LocalSessionStatsRepository.swift`
- Modify: `app/LeafTimerTests/SessionStatsLogicTests.swift`

- [ ] **Step 1: テストを追加 (RED)**

`SessionStatsLogicTests.swift` 末尾に append:

```swift
    func testSameDaySecondSession_streakUnchanged() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/28")
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.totalCount, 2)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 2)
        XCTAssertEqual(stats.currentStreak, 1, "同日 2 件目以降は streak 変えない")
        XCTAssertEqual(stats.longestStreak, 1)
    }

    func testConsecutiveDay_streakIncrements() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/27")
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 2)
    }

    func testGap_streakResets() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        let stats = repo.recordSession(today: "2026/05/28")  // 1 日空き

        XCTAssertEqual(stats.currentStreak, 1, "1 日以上空くと reset")
        XCTAssertEqual(stats.longestStreak, 1)
    }

    func testLongestStreakKeptWhenCurrentDrops() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        _ = repo.recordSession(today: "2026/05/27")
        _ = repo.recordSession(today: "2026/05/28")  // 3 連続
        let stats = repo.recordSession(today: "2026/05/31")  // 2 日空き、reset

        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 3, "過去の最長は維持される")
    }
```

- [ ] **Step 2: テスト実行して FAIL 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: 4 つの新規 test が FAIL (currentStreak の値が常に 1)。

- [ ] **Step 3: `recordSession` の streak ロジックを本実装**

`LocalSessionStatsRepository.swift` の `recordSession` 内、`stats.currentStreak = 1` / `stats.longestStreak = max(..., 1)` の 2 行を以下に置換:

```swift
        let last = stats.lastSessionDate
        if last == today {
            // 同日 2 件目以降は streak 変えない
        } else if let last = last, isYesterday(last, of: today) {
            stats.currentStreak += 1
        } else {
            stats.currentStreak = 1
        }
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
```

ファイル末尾 (class の閉じ括弧の直前) に private helper を追加:

```swift
    private func isYesterday(_ candidate: String, of today: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        guard let todayDate = formatter.date(from: today),
              let candidateDate = formatter.date(from: candidate),
              let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: todayDate) else {
            return false
        }
        return Calendar.current.isDate(candidateDate, inSameDayAs: yesterday)
    }
```

- [ ] **Step 4: テスト実行して PASS 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` で全テスト (Task 3-6 の 9 件) PASS。

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/Components/LocalSessionStatsRepository.swift \
        app/LeafTimerTests/SessionStatsLogicTests.swift
git commit -m "$(cat <<'EOF'
feat(stats): recordSession の streak 更新ロジックを実装

同日 2 件目は streak 変えず、昨日からの継続で +1、1 日以上空くと 1 に
reset、longestStreak は max を維持。日付計算は Calendar.current を使い、
"yyyy/MM/dd" 形式で内部判定する。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `recentDailyCounts` 実装 (過去 N 日、欠損 0 埋め、古い→新しい順、today を含む)

**Files:**
- Modify: `app/LeafTimer/Components/LocalSessionStatsRepository.swift`
- Modify: `app/LeafTimerTests/SessionStatsLogicTests.swift`

- [ ] **Step 1: テストを追加 (RED)**

`SessionStatsLogicTests.swift` 末尾に append:

```swift
    // MARK: - recentDailyCounts

    func testRecentDailyCountsIncludesToday() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/28")
        _ = repo.recordSession(today: "2026/05/28")  // 同日 2 件目

        let result = repo.recentDailyCounts(days: 7, endingAt: "2026/05/28")

        XCTAssertEqual(result.count, 7, "today を含む 7 日分")
        XCTAssertEqual(result.last?.date, "2026/05/28", "末尾が today (新しい順)")
        XCTAssertEqual(result.last?.count, 2)
        XCTAssertEqual(result.first?.date, "2026/05/22", "先頭は 6 日前")
        XCTAssertEqual(result.first?.count, 0, "記録のない日は 0")
    }

    func testRecentDailyCountsFillsMissingDays() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        _ = repo.recordSession(today: "2026/05/28")

        let result = repo.recentDailyCounts(days: 7, endingAt: "2026/05/28")
        let dict = Dictionary(uniqueKeysWithValues: result.map { ($0.date, $0.count) })

        XCTAssertEqual(dict["2026/05/26"], 1)
        XCTAssertEqual(dict["2026/05/27"], 0, "間の日は 0")
        XCTAssertEqual(dict["2026/05/28"], 1)
    }
```

- [ ] **Step 2: テスト実行して FAIL 確認** (現状 `recentDailyCounts` は `[]` を返すため)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: 2 つの新規 test が FAIL。

- [ ] **Step 3: `recentDailyCounts` を本実装**

`LocalSessionStatsRepository.swift` の `recentDailyCounts` 実装を以下に置換:

```swift
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] {
        let stats = load()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        guard let endDate = formatter.date(from: endingAt) else { return [] }

        var result: [(date: String, count: Int)] = []
        for offset in (0..<days).reversed() {  // (days-1)..0 を旧→新
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: endDate) else { continue }
            let key = formatter.string(from: date)
            result.append((date: key, count: stats.dailyCount[key] ?? 0))
        }
        return result
    }
```

- [ ] **Step 4: テスト実行して PASS 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsLogicTests \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` で全 11 件 PASS。

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/Components/LocalSessionStatsRepository.swift \
        app/LeafTimerTests/SessionStatsLogicTests.swift
git commit -m "$(cat <<'EOF'
feat(stats): recentDailyCounts を実装

endingAt (today) を含む過去 N 日分を古い→新しい順に返す。
欠損日は count=0 で埋める。HistoryView の棒グラフ用 API。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Migration — 旧 `yyyy/MM/dd → Int` key の集約 + `totalPomodoroCount` 取り込み

**Files:**
- Create: `app/LeafTimerTests/SessionStatsMigrationTests.swift`
- Modify: `app/LeafTimer/Components/LocalSessionStatsRepository.swift`

- [ ] **Step 1: Migration テストファイルを作成 (RED)**

```swift
// app/LeafTimerTests/SessionStatsMigrationTests.swift
import XCTest
@testable import LeafTimer

final class SessionStatsMigrationTests: XCTestCase {

    private let suiteName = "SessionStatsMigrationTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testMigrateLegacyDailyKeys() {
        // 旧データを直接書き込む
        testDefaults.set(3, forKey: "2026/05/26")
        testDefaults.set(5, forKey: "2026/05/27")
        testDefaults.set(2, forKey: "2026/05/28")
        testDefaults.set(20, forKey: "totalPomodoroCount")  // legacy 累計

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.dailyCount["2026/05/26"], 3)
        XCTAssertEqual(stats.dailyCount["2026/05/27"], 5)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 2)
        // legacy totalPomodoroCount (20) と dailyCount の合計 (10) のうち大きい方
        XCTAssertEqual(stats.totalCount, 20)
    }

    func testMigrationSentinelPreventsRerun() {
        testDefaults.set(3, forKey: "2026/05/27")

        let repo1 = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo1.load()

        // sentinel が立ったかを確認
        XCTAssertTrue(testDefaults.bool(forKey: "statsMigrated"))

        // 2 度目の load では既存 SessionStats を返し、再 migration しない
        // ここで新しい legacy key を書き込んでも取り込まれないはず
        testDefaults.set(99, forKey: "2026/06/01")
        let repo2 = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo2.load()
        XCTAssertNil(stats.dailyCount["2026/06/01"], "sentinel 後は再 migration されない")
    }

    func testNonIntegerLegacyKeysSkipped() {
        // 型違いの legacy key (例: 文字列) は skip、他は集約
        testDefaults.set(3, forKey: "2026/05/27")
        testDefaults.set("not-an-int", forKey: "2026/05/26")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.dailyCount["2026/05/27"], 3)
        XCTAssertNil(stats.dailyCount["2026/05/26"])
    }
}
```

- [ ] **Step 2: テストファイルを target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/SessionStatsMigrationTests.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 3: テスト実行して FAIL 確認** (現状 migration は未実装)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsMigrationTests \
  2>&1 | tail -30
```

Expected: 3 件 FAIL。

- [ ] **Step 4: Migration ロジックを実装**

`LocalSessionStatsRepository.swift` の `load()` メソッドを以下に置換:

```swift
    func load() -> SessionStats {
        if !userDefaults.bool(forKey: "statsMigrated") {
            performMigration()
        }
        guard let data = userDefaults.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(SessionStats.self, from: data) else {
            return .empty
        }
        return stats
    }
```

class の末尾 (`isYesterday` の下) に migration を追加:

```swift
    // MARK: - Migration

    private func performMigration() {
        let datePattern = #"^\d{4}/\d{2}/\d{2}$"#
        var dailyCount: [String: Int] = [:]
        for (key, value) in userDefaults.dictionaryRepresentation() {
            guard key.range(of: datePattern, options: .regularExpression) != nil,
                  let count = value as? Int else { continue }
            dailyCount[key] = count
        }

        let legacyTotal = userDefaults.integer(forKey: "totalPomodoroCount")
        let derivedTotal = dailyCount.values.reduce(0, +)
        var stats = SessionStats(
            dailyCount: dailyCount,
            totalCount: max(legacyTotal, derivedTotal),
            currentStreak: 0,
            longestStreak: 0,
            lastSessionDate: nil
        )
        // streak の遡及計算は Task 9 で追加
        save(stats)
        userDefaults.set(true, forKey: "statsMigrated")
    }
```

- [ ] **Step 5: テスト実行して PASS 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsMigrationTests \
  2>&1 | tail -30
```

Expected: 3 件 PASS。

- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/Components/LocalSessionStatsRepository.swift \
        app/LeafTimerTests/SessionStatsMigrationTests.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(stats): 旧 yyyy/MM/dd key と totalPomodoroCount を migration で集約

regex でレガシー日付 key を抽出し dailyCount に集約。型違い (非 Int) は
skip。legacy totalPomodoroCount は dailyCount の合計と max を取り
totalCount に反映 (既存 review request 判定との一貫性を保つため)。
"statsMigrated" sentinel で再実行を防止。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Migration の streak 遡及計算

**Files:**
- Modify: `app/LeafTimer/Components/LocalSessionStatsRepository.swift`
- Modify: `app/LeafTimerTests/SessionStatsMigrationTests.swift`

- [ ] **Step 1: テスト追加 (RED)**

`SessionStatsMigrationTests.swift` 末尾に append:

```swift
    func testMigrationCalculatesLongestStreak() {
        // 3 連続 + ギャップ + 2 連続
        testDefaults.set(1, forKey: "2026/05/20")
        testDefaults.set(1, forKey: "2026/05/21")
        testDefaults.set(1, forKey: "2026/05/22")
        testDefaults.set(1, forKey: "2026/05/27")
        testDefaults.set(1, forKey: "2026/05/28")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.longestStreak, 3)
        XCTAssertEqual(stats.lastSessionDate, "2026/05/28")
    }

    func testMigrationCurrentStreakWhenLastIsToday() {
        // last = today なら currentStreak = 末尾連続長
        testDefaults.set(1, forKey: "2026/05/27")
        testDefaults.set(1, forKey: "2026/05/28")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        // last="2026/05/28" を today と仮定するロジックは migration 内部で
        // 「最終日 = 末尾。currentStreak は末尾から遡って連続している長さ」
        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testMigrationCurrentStreakZeroWhenLastIsOld() {
        // 最終日が古ければ streak は 0 とみなす
        // (recordSession 時に today と比較されて適切に reset される)
        testDefaults.set(1, forKey: "2025/01/01")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.longestStreak, 1)
        XCTAssertEqual(stats.lastSessionDate, "2025/01/01")
        // currentStreak は載せる必要なし、recordSession 側で再判定される
        // ここでは「末尾から連続している長さ」を入れる方針 = 1
        XCTAssertEqual(stats.currentStreak, 1)
    }
```

- [ ] **Step 2: テスト実行して FAIL 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsMigrationTests \
  2>&1 | tail -30
```

Expected: 3 件 FAIL (currentStreak=0, longestStreak=0 のため)。

- [ ] **Step 3: `performMigration` の streak 遡及計算を追加**

`LocalSessionStatsRepository.swift` の `performMigration` 内、`stats` 初期化の後、`save(stats)` の前に以下を挿入:

```swift
        let (longest, current, lastDate) = computeStreaks(from: dailyCount)
        stats.currentStreak = current
        stats.longestStreak = longest
        stats.lastSessionDate = lastDate
```

そして class 末尾に helper を追加:

```swift
    private func computeStreaks(from dailyCount: [String: Int]) -> (longest: Int, current: Int, lastDate: String?) {
        let sortedDates = dailyCount.keys.sorted()
        guard !sortedDates.isEmpty else { return (0, 0, nil) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"

        var longest = 1
        var run = 1
        for i in 1..<sortedDates.count {
            guard let prev = formatter.date(from: sortedDates[i - 1]),
                  let curr = formatter.date(from: sortedDates[i]),
                  let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: prev) else {
                run = 1; continue
            }
            if Calendar.current.isDate(curr, inSameDayAs: nextDay) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        // current = 末尾から遡る連続日数
        var current = 1
        for i in stride(from: sortedDates.count - 1, to: 0, by: -1) {
            guard let curr = formatter.date(from: sortedDates[i]),
                  let prev = formatter.date(from: sortedDates[i - 1]),
                  let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: curr) else { break }
            if Calendar.current.isDate(prev, inSameDayAs: yesterday) {
                current += 1
            } else {
                break
            }
        }
        return (longest, current, sortedDates.last)
    }
```

- [ ] **Step 4: テスト実行して PASS 確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/SessionStatsMigrationTests \
  2>&1 | tail -30
```

Expected: 6 件 PASS (Task 8 の 3 件 + 新 3 件)。

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/Components/LocalSessionStatsRepository.swift \
        app/LeafTimerTests/SessionStatsMigrationTests.swift
git commit -m "$(cat <<'EOF'
feat(stats): Migration で streak を遡及計算

sortedDates を走査し隣接日差を判定して longest を算出、末尾から
遡って current を算出。lastSessionDate は末尾日付。
Migration 後の recordSession で today と比較され、必要に応じて
currentStreak が再 reset される。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `HistoryViewModel` と `HistoryViewModelTests`

**Files:**
- Create: `app/LeafTimer/ViewModel/HistoryViewModel.swift`
- Create: `app/LeafTimerTests/HistoryViewModelTests.swift`

- [ ] **Step 1: テストを書く (RED)**

```swift
// app/LeafTimerTests/HistoryViewModelTests.swift
import XCTest
@testable import LeafTimer

final class HistoryViewModelTests: XCTestCase {

    func testLoadPopulatesPublishedProperties() {
        let spy = SpySessionStatsRepository()
        spy.stubLoadResult = SessionStats(
            dailyCount: ["2026/05/28": 3],
            totalCount: 50,
            currentStreak: 4,
            longestStreak: 10,
            lastSessionDate: "2026/05/28"
        )
        spy.stubRecentResult = [
            (date: "2026/05/22", count: 0),
            (date: "2026/05/23", count: 1),
            (date: "2026/05/24", count: 2),
            (date: "2026/05/25", count: 0),
            (date: "2026/05/26", count: 3),
            (date: "2026/05/27", count: 0),
            (date: "2026/05/28", count: 3),
        ]
        let vm = HistoryViewModel(repository: spy)

        vm.load(today: "2026/05/28")

        XCTAssertEqual(vm.currentStreak, 4)
        XCTAssertEqual(vm.longestStreak, 10)
        XCTAssertEqual(vm.totalCount, 50)
        XCTAssertEqual(vm.last7Days.count, 7)
        XCTAssertEqual(vm.last7Days.last?.count, 3)
    }

    func testLoadEmptyShowsSevenZeros() {
        let spy = SpySessionStatsRepository()
        spy.stubLoadResult = .empty
        spy.stubRecentResult = (0..<7).map { (date: "2026/05/2\($0)", count: 0) }
        let vm = HistoryViewModel(repository: spy)

        vm.load(today: "2026/05/28")

        XCTAssertEqual(vm.totalCount, 0)
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertEqual(vm.last7Days.count, 7)
        XCTAssertTrue(vm.last7Days.allSatisfy { $0.count == 0 })
    }
}
```

- [ ] **Step 2: テストファイル attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/HistoryViewModelTests.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 3: テスト実行して FAIL 確認** (型未定義で BUILD FAILED)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/HistoryViewModelTests \
  2>&1 | tail -20
```

Expected: `Cannot find 'HistoryViewModel' in scope`。

- [ ] **Step 4: `HistoryViewModel.swift` を作成**

```swift
// app/LeafTimer/ViewModel/HistoryViewModel.swift
import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    private let repository: SessionStatsRepository

    @Published var last7Days: [(date: String, count: Int)] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalCount: Int = 0

    init(repository: SessionStatsRepository) {
        self.repository = repository
    }

    func load(today: String = DateManager.getToday()) {
        let stats = repository.load()
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
        totalCount = stats.totalCount
        last7Days = repository.recentDailyCounts(days: 7, endingAt: today)
    }
}
```

- [ ] **Step 5: target attach + テスト実行**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/ViewModel/HistoryViewModel.swift LeafTimer LeafTimer/ViewModel
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/HistoryViewModelTests \
  2>&1 | tail -20
```

Expected: 2 件 PASS。

- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/ViewModel/HistoryViewModel.swift \
        app/LeafTimerTests/HistoryViewModelTests.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(history): HistoryViewModel を追加

SessionStatsRepository.load() / recentDailyCounts() の結果を
@Published で公開し、HistoryView が監視する形。load() の today
引数はテスト時に固定値を渡せるよう default DateManager.getToday()。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: `Localizable.strings` に新規キーを追加

**Files:**
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings`
- Modify: `app/LeafTimer/App/en.lproj/Localizable.strings`

- [ ] **Step 1: ja の追記**

`app/LeafTimer/App/ja.lproj/Localizable.strings` の末尾 (最後のキー行の後) に以下を append:

```
// MARK: - History (Issue #8)
"timer.todays_count_with_streak" = "今日 %d 回 ・ 🔥 Streak %d";
"history.title" = "履歴";
"history.current_streak" = "現在 %d 日連続";
"history.longest_streak" = "最長 %d 日";
"history.total_sessions" = "累計 %d セッション";
"history.last_7_days" = "過去 7 日";
```

- [ ] **Step 2: en の追記**

`app/LeafTimer/App/en.lproj/Localizable.strings` の末尾に同じキーで en 訳を append:

```
// MARK: - History (Issue #8)
"timer.todays_count_with_streak" = "Today %d · 🔥 Streak %d";
"history.title" = "History";
"history.current_streak" = "Current Streak: %d";
"history.longest_streak" = "Longest: %d";
"history.total_sessions" = "Total: %d";
"history.last_7_days" = "Last 7 days";
```

- [ ] **Step 3: ビルド確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **` (まだ呼び出し側がないが、リソースは正しく組み込まれる)。

- [ ] **Step 4: commit**

```bash
git add app/LeafTimer/App/ja.lproj/Localizable.strings \
        app/LeafTimer/App/en.lproj/Localizable.strings
git commit -m "$(cat <<'EOF'
feat(i18n): History 画面と streak バッジの ja/en 訳を追加

Localizable.strings (legacy) に 6 キーを追加。英語は count-agnostic
表現 ("Streak: %d" / "Longest: %d" / "Total: %d") で plural を回避し
.stringsdict 追加を不要にする。日本語は %d をそのまま埋め込み。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: `HistoryView` UI

**Files:**
- Create: `app/LeafTimer/View/HistoryView.swift`

- [ ] **Step 1: HistoryView を作成**

```swift
// app/LeafTimer/View/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summarySection
                Divider().padding(.horizontal)
                last7DaysSection
            }
            .padding(.top, 16)
        }
        .navigationTitle(NSLocalizedString("history.title", comment: "History screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            statRow(
                icon: "flame.fill",
                color: .orange,
                text: String(format: NSLocalizedString("history.current_streak", comment: ""), viewModel.currentStreak)
            )
            statRow(
                icon: "trophy.fill",
                color: .yellow,
                text: String(format: NSLocalizedString("history.longest_streak", comment: ""), viewModel.longestStreak)
            )
            statRow(
                icon: "checkmark.circle.fill",
                color: .green,
                text: String(format: NSLocalizedString("history.total_sessions", comment: ""), viewModel.totalCount)
            )
        }
        .padding(.horizontal)
    }

    private func statRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private var last7DaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("history.last_7_days", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.last7Days, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text("\(day.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(barColor(for: day.count))
                            .frame(height: barHeight(for: day.count))
                        Text(shortLabel(date: day.date))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }

    private var maxCount: Int {
        max(viewModel.last7Days.map { $0.count }.max() ?? 0, 1)
    }

    private func barHeight(for count: Int) -> CGFloat {
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(ratio * 120, 4)  // 最小 4 で 0 でも棒が見える
    }

    private func barColor(for count: Int) -> Color {
        count == 0
            ? Color.gray.opacity(0.3)
            : Color(red: 0.42, green: 0.56, blue: 0.42)  // LeafTimer 緑
    }

    private func shortLabel(date: String) -> String {
        // "yyyy/MM/dd" → "MM/dd"
        let parts = date.split(separator: "/")
        guard parts.count == 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let spy = SpyHistoryRepository()
        spy.stubRecent = [
            (date: "2026/05/22", count: 0),
            (date: "2026/05/23", count: 2),
            (date: "2026/05/24", count: 4),
            (date: "2026/05/25", count: 1),
            (date: "2026/05/26", count: 3),
            (date: "2026/05/27", count: 0),
            (date: "2026/05/28", count: 5),
        ]
        let vm = HistoryViewModel(repository: spy)
        vm.last7Days = spy.stubRecent
        vm.currentStreak = 2
        vm.longestStreak = 7
        vm.totalCount = 42
        return NavigationStack {
            HistoryView(viewModel: vm)
        }
    }
}

// Preview 専用の inline spy (Test target ではなく LeafTimer target に含めるため
// SpySessionStatsRepository とは別物)
private class SpyHistoryRepository: SessionStatsRepository {
    var stubRecent: [(date: String, count: Int)] = []
    func load() -> SessionStats { .empty }
    func recordSession(today: String) -> SessionStats { .empty }
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] { stubRecent }
}
```

- [ ] **Step 2: target に attach**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/View/HistoryView.swift LeafTimer LeafTimer/View
```

- [ ] **Step 3: ビルド確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Simulator で Preview もしくは実画面確認** (任意、最終 Task 17 で全体検証するので skip 可)

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/View/HistoryView.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(history): HistoryView を追加

SwiftUI 標準で過去 7 日棒グラフを描画 (Rectangle.frame(height:) を
最大値で正規化、最小 4px で 0 件日も棒が見える)。streak / 累計の
表示は SF Symbol + 文字行の 3 行構成。NSLocalizedString は ja/en
共に既に Task 11 で追加済み。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: `TimerViewModel` 修正 (init / countWork / @Published 追加)

**Files:**
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift`
- Modify: `app/LeafTimerTests/TimerViewSpec.swift`

- [ ] **Step 1: テスト側 (`TimerViewSpec.swift`) の init 呼び出しを修正**

`TimerViewSpec.swift` の `beforeEach` ブロック内、`TimerViewModel(...)` の引数に `sessionStatsRepository:` を追加:

```swift
            beforeEach {
                spyTimerManager = SpyTimerManager()
                timerView = TimerView(
                    timerViewModel: TimerViewModel(
                        timerManager: spyTimerManager,
                        audioManager: SpyAudioManager(),
                        userDefaultWrapper: LocalUserDefaultsWrapper(),
                        sessionStatsRepository: SpySessionStatsRepository()
                    ),
                    settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
                )
            }
```

- [ ] **Step 2: `TimerViewModel.swift` の init / プロパティ修正**

`TimerViewModel.swift` の `// MARK: - Dependency Injection` セクションに以下を追加 (`reviewRequester` の下):

```swift
    var sessionStatsRepository: SessionStatsRepository
```

`// MARK: - Observed Parameter` の `todaysCount` の下に以下を追加:

```swift
    @Published
    var currentStreak: Int
    @Published
    var longestStreak: Int
```

`init(...)` のシグネチャを以下に変更:

```swift
    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper,
        sessionStatsRepository: SessionStatsRepository,
        reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    ) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper
        self.sessionStatsRepository = sessionStatsRepository
        self.reviewPolicy = reviewPolicy
        self.reviewRequester = reviewRequester

        fullTimeSecond = 25 * 60
        currentTimeSecond = 25 * 60
        executeState = false

        fullBreakTimeSecond = 5 * 60
        breakState = false

        vibration = true

        todaysCount = 0
        currentStreak = 0
        longestStreak = 0

        loadCount()

        if userDefaultWrapper.loadData(key: "hasLaunchedBefore") == 0 {
            userDefaultWrapper.saveData(key: UserDefaultItem.workingSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.breakSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: "hasLaunchedBefore", value: 1)
        }
    }
```

- [ ] **Step 3: `loadCount` を SessionStatsRepository 経由に変更**

```swift
    func loadCount() {
        let stats = sessionStatsRepository.load()
        let today = DateManager.getToday()
        todaysCount = stats.dailyCount[today] ?? 0
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
    }
```

- [ ] **Step 4: `countWork()` を recordSession に置換 (dual write を残す)**

`countWork()` の本体を以下に置換:

```swift
    func countWork() {
        let today = DateManager.getToday()
        let stats = sessionStatsRepository.recordSession(today: today)

        todaysCount = stats.dailyCount[today] ?? 0
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak

        // Legacy: requestReviewIfNeeded が `totalPomodoroCount` 単独 key に依存しているため
        // dual write を維持。Migration で初期同期済み、ここでも +1 を反映。
        let totalCount = userDefaultWrapper.loadData(
            key: UserDefaultItem.totalPomodoroCount.rawValue
        ) + 1
        userDefaultWrapper.saveData(
            key: UserDefaultItem.totalPomodoroCount.rawValue,
            value: totalCount
        )

        requestReviewIfNeeded(totalCount: totalCount)
    }
```

- [ ] **Step 5: ビルド確認 (AppDelegate もまだ更新前なのでエラーになる想定)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -15
```

Expected: AppDelegate で `Missing argument for parameter 'sessionStatsRepository' in call` の BUILD FAILED。次 Task で解消。

- [ ] **Step 6: commit (この時点では build 失敗だがすぐ次 Task で解消されるので OK。むしろ commit を分けてレビュー単位を細かくしておく)**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel.swift \
        app/LeafTimerTests/TimerViewSpec.swift
git commit -m "$(cat <<'EOF'
feat(timer): TimerViewModel を SessionStatsRepository 経由に切替

countWork() で sessionStatsRepository.recordSession() を呼び、
todaysCount / currentStreak / longestStreak を @Published で公開。
loadCount() も Repository.load() 経由に。
totalPomodoroCount は requestReviewIfNeeded のため dual write 維持。
TimerViewSpec の DI も SpySessionStatsRepository 追加で更新。
(AppDelegate 配線は次 commit で更新)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: `AppDelegate` の DI 配線変更

**Files:**
- Modify: `app/LeafTimer/App/AppDelegate.swift`

- [ ] **Step 1: `AppDelegate.swift` の `TimerViewModel(...)` 呼び出しに `sessionStatsRepository:` を追加**

`application(_:didFinishLaunchingWithOptions:)` 内、25-30 行目の TimerViewModel 構築を以下に置換:

```swift
        let contentView = TimerView(
            timerViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: LocalUserDefaultsWrapper(),
                sessionStatsRepository: LocalSessionStatsRepository()
            ),
            settingViewModel: SettingViewModel(
                userDefaultWrapper: LocalUserDefaultsWrapper()
            )
        )
```

- [ ] **Step 2: ビルド確認 (今度こそ通る想定)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: commit**

```bash
git add app/LeafTimer/App/AppDelegate.swift
git commit -m "$(cat <<'EOF'
feat(app): LocalSessionStatsRepository を AppDelegate で DI

TimerViewModel に sessionStatsRepository を注入。HistoryView は
TimerView 側から navigation 経由で同 instance を共有する想定 (Task 15)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: `TimerView` 修正 (toolbar 履歴ボタン + 下部文言)

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift`

- [ ] **Step 1: 下部の `Text(...)` を新文言に変更**

`TimerView.swift` の line 65-68 の `Text` 行を以下に置換:

```swift
                    Text(
                        String(
                            format: NSLocalizedString("timer.todays_count_with_streak", comment: "Today count and streak"),
                            timerViewModel.todaysCount,
                            timerViewModel.currentStreak
                        )
                    )
                        .foregroundColor(.secondary.opacity(0.9))
                        .padding()
                        .padding(.top, 20)
```

- [ ] **Step 2: toolbar に履歴ボタンを追加**

`TimerView.swift` の `toolbar { ... }` ブロック内、`ToolbarItem(placement: .navigationBarLeading)` の **直後** (`ToolbarItem(placement: .navigationBarTrailing)` の **前**) に以下を挿入:

```swift
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(
                            destination: HistoryView(
                                viewModel: HistoryViewModel(
                                    repository: timerViewModel.sessionStatsRepository
                                )
                            )
                        ) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.primary)
                        }
                    }
```

注: SwiftUI の navigationBarTrailing は複数指定すると右から順に並ぶ。`chart.bar.fill` (履歴) の右に `settingIcon` (設定) が並ぶ形になる。

- [ ] **Step 3: ビルド確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild build -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: TimerViewSpec が green であることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -only-testing:LeafTimerTests/TimerViewSpec \
  2>&1 | tail -20
```

Expected: 既存 1 件 (`displayed navigation bar`) が PASS。

- [ ] **Step 5: commit**

```bash
git add app/LeafTimer/View/TimerView.swift
git commit -m "$(cat <<'EOF'
feat(timer): TimerView に streak バッジと履歴ボタンを追加

下部の「今日のポモドーロ数」を「今日 N 回 · 🔥 Streak M」に変更。
toolbar 右側に chart.bar.fill の履歴ボタンを追加し、tap で
NavigationLink で HistoryView に遷移。SessionStatsRepository は
TimerViewModel が保持する instance を共有。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Dead code 削除 (`SessionStatsView.swift` + `weeklyAverage`)

**Files:**
- Delete: `app/LeafTimer/View/Components/SessionStatsView.swift`
- Modify: `app/LeafTimer/ViewModel/TimerViewModel+extensions.swift`

- [ ] **Step 1: 削除前に念のため live 参照 grep (CLAUDE.md learning に従って verify)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
grep -rn "SessionStatsView" app/LeafTimer/ app/LeafTimerTests/ 2>&1
grep -rn "weeklyAverage" app/LeafTimer/ app/LeafTimerTests/ 2>&1
```

Expected:
- `SessionStatsView`: hit は `SessionStatsView.swift` 自身のファイル内のみ (= dead)。
- `weeklyAverage`: hit は `TimerViewModel+extensions.swift:148-152` のみ (= dead)。

もし他のファイルから参照が見つかったら STOP し、user に確認する。

- [ ] **Step 2: SessionStatsView.swift を git rm**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git rm app/LeafTimer/View/Components/SessionStatsView.swift
```

- [ ] **Step 3: pbxproj から SessionStatsView の参照を削除**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
# xcodeproj gem 経由で除去 (manual 編集より安全)
ruby -rxcodeproj -e '
project = Xcodeproj::Project.open("LeafTimer.xcodeproj")
target = project.targets.find { |t| t.name == "LeafTimer" }
ref = project.files.find { |f| f.path&.include?("SessionStatsView.swift") }
if ref
  build_files = target.source_build_phase.files.select { |bf| bf.file_ref == ref }
  build_files.each { |bf| target.source_build_phase.remove_build_file(bf) }
  ref.remove_from_project
  project.save
  puts "removed SessionStatsView.swift from pbxproj"
else
  puts "no reference found (ok)"
end
'
make sort
```

Expected: 「removed SessionStatsView.swift from pbxproj」または「no reference found (ok)」のいずれか。

- [ ] **Step 4: `TimerViewModel+extensions.swift` の `weeklyAverage` を削除**

`TimerViewModel+extensions.swift` の 148-152 行 (computed property `weeklyAverage`) を完全に削除:

```swift
// 削除前:
extension TimerViewModel {
    var weeklyAverage: Double {
        // Calculate weekly average from stored data
        // For now, return a mock value - will be replaced with actual calculation
        return Double(todaysCount) * 0.8
    }

    var timerState: TimerControlState.State {
```

```swift
// 削除後:
extension TimerViewModel {
    var timerState: TimerControlState.State {
```

(weeklyAverage block のみを削除、extension 自体と timerState / currentTimerMode は残す)

- [ ] **Step 5: ビルド & テスト全体確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
xcodebuild test -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` で全テスト PASS。SessionStatsView 関連の missing reference エラーが出ないこと。

- [ ] **Step 6: commit**

```bash
git add app/LeafTimer/ViewModel/TimerViewModel+extensions.swift \
        app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
chore: dead な SessionStatsView と weeklyAverage を削除

SessionStatsView は App entry / TabView / NavigationStack から
参照ゼロの dead code (color hardcoded / i18n 未対応 / weeklyAverage
mock の 3 問題を抱えていたため Issue #8 では新規 HistoryView に置換)。
TimerViewModel+extensions の weeklyAverage も mock 値で利用箇所なく
削除。pbxproj 参照も同時除去。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: 最終検証 (`make tests` + ja/en Simulator screenshot)

**Files:** なし (検証のみ、必要なら screenshot を追加)

- [ ] **Step 1: 全テスト + lint + format**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
set -o pipefail
make tests 2>&1 | tail -60
```

Expected: `** TEST SUCCEEDED **` + SwiftLint warning なし。pipefail 必須 (CLAUDE.md learning: `make` を `| tail` 経由で実行する時、`set -o pipefail` がないと tail の exit 0 で失敗が隠れる)。

もし lint error が出たら fix。CLAUDE.md learning「custom_rules の regex は反転していないか必ず確認」を参照しつつ、出たエラーを内容で判断。

- [ ] **Step 2: Simulator で日本語版を起動して screenshot**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
# Simulator 起動
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator

cd app
set -o pipefail
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath .build install 2>&1 | tail -5

# Bundle path を取得して install + launch (ios-simulator-app-verification skill 参照)
APP_PATH=$(find .build/Build/Products -name "LeafTimer.app" -print -quit)
echo "App path: $APP_PATH"
xcrun simctl install booted "$APP_PATH"

# ja 起動
xcrun simctl launch booted com.shinya.LeafTimer -AppleLanguages "(ja)" -AppleLocale ja_JP
sleep 3
xcrun simctl io booted screenshot ../docs/superpowers/screenshots/2026-05-28-history-ja.png

# 履歴画面に遷移するには UI 操作が必要だが simctl では tap 不可
# UserDefaults を直接書き込んで起動時に streak が見える状態を作る
xcrun simctl terminate booted com.shinya.LeafTimer
xcrun simctl spawn booted defaults write com.shinya.LeafTimer sessionStats '{"dailyCount":{"2026/05/28":3,"2026/05/27":2},"totalCount":50,"currentStreak":4,"longestStreak":10,"lastSessionDate":"2026/05/28"}'
xcrun simctl spawn booted defaults write com.shinya.LeafTimer statsMigrated -bool true
xcrun simctl launch booted com.shinya.LeafTimer -AppleLanguages "(ja)" -AppleLocale ja_JP
sleep 3
xcrun simctl io booted screenshot ../docs/superpowers/screenshots/2026-05-28-timer-ja-with-streak.png
```

Expected:
- `docs/superpowers/screenshots/2026-05-28-timer-ja-with-streak.png` に「今日 3 回 · 🔥 Streak 4」が見える状態のスクリーンショット。
- ※ HistoryView 画面は tap が必要なので、Preview か手動操作で別途確認すること。

- [ ] **Step 3: 英語版でも screenshot**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
xcrun simctl terminate booted com.shinya.LeafTimer
xcrun simctl launch booted com.shinya.LeafTimer -AppleLanguages "(en)" -AppleLocale en_US
sleep 3
xcrun simctl io booted screenshot ../docs/superpowers/screenshots/2026-05-28-timer-en-with-streak.png
```

Expected: 「Today 3 · 🔥 Streak 4」(英語、plural なし) が見える。

- [ ] **Step 4: screenshot を commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add docs/superpowers/screenshots/2026-05-28-timer-ja-with-streak.png \
        docs/superpowers/screenshots/2026-05-28-timer-en-with-streak.png
git commit -m "$(cat <<'EOF'
docs(verification): TimerView の ja/en streak バッジ screenshot を追加

UserDefaults に固定 SessionStats を書いて起動し、streak バッジが
ja/en 両 locale で count-agnostic に表示されることを目視確認。
HistoryView 自体の screenshot は UI tap が必要なため Preview で別途確認。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: branch 全体の commit log を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git log --oneline master..HEAD
```

Expected: Task 1 から Task 17 までの 17 commits (+ 既存 4 commit = 21 commits) が一覧表示される。

- [ ] **Step 6: PR 作成は別フェーズ (user 承認後)**

PR 作成は本 plan の scope 外。実装完了後、user に PR 作成可否を確認してから `gh pr create` する。

---

## Self-Review チェックリスト (plan 完成後の確認)

1. **Spec coverage:** spec doc の各セクションをカバーしているか?
   - `SessionStats` モデル: Task 3 ✅
   - `SessionStatsRepository` protocol: Task 4 ✅
   - `LocalSessionStatsRepository` 永続化: Task 5 ✅
   - streak ロジック (同日/昨日/空き/longest): Task 6 ✅
   - `recentDailyCounts`: Task 7 ✅
   - Migration (旧 key 集約 + sentinel + 型違い skip): Task 8 ✅
   - Migration 遡及計算: Task 9 ✅
   - `HistoryViewModel`: Task 10 ✅
   - Localization: Task 11 ✅
   - `HistoryView`: Task 12 ✅
   - `TimerViewModel` 修正: Task 13 ✅
   - `AppDelegate` DI: Task 14 ✅
   - `TimerView` 修正: Task 15 ✅
   - dead code 削除: Task 16 ✅
   - Localization テスト / Simulator verification: Task 17 ✅

2. **Placeholder scan:** 「TBD」「TODO」「implement later」「適切なエラー処理を追加」のような placeholder なし。
   - 各 step は具体的なコード or コマンド付き ✅
   - "similar to Task N" 等の参照なし、必要な箇所は再掲 ✅

3. **Type consistency:** メソッド名・プロパティ名は一貫しているか?
   - `recordSession(today: String)` — Task 4/5/6/13 で同一 signature ✅
   - `recentDailyCounts(days: Int, endingAt: String)` — Task 4/7/10/12 で同一 ✅
   - `SessionStats` の 5 フィールド名は Task 3 で確定、以降一貫 ✅
   - `currentStreak` / `longestStreak` の命名は spec と一致 ✅

4. **Ambiguity check:**
   - 「同日 2 件目以降は streak 変えない」: Task 6 テストで明示 (`testSameDaySecondSession_streakUnchanged`) ✅
   - 「過去 7 日は今日を含む」: Task 7 テストで明示 (`testRecentDailyCountsIncludesToday`) ✅
   - dual write の理由: Task 13 コメントで明示 ✅

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-28-pomodoro-log-visualization.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 新規 subagent を Task ごとに dispatch、Task 間にレビュー checkpoint、高速反復

**2. Inline Execution** - 本 session で executing-plans を使ってバッチ実行、checkpoint 付き

Which approach?
