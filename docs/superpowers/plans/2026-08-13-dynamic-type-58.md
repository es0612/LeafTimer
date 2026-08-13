# Dynamic Type 対応 実装計画 (Issue #58)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 固定 font size 40 箇所を SwiftUI 標準 text style / 上限付き `@ScaledMetric` へ移行し、iOS の「文字を大きく」に AX5 まで追従させる（HistoryView の 7 日グラフのみ `accessibility3` 上限、詳細は設計ドキュメントの「例外」節を参照）。

**Architecture:** 独自の Font 抽象レイヤは作らず、SwiftUI 標準 text style へ直接置換する (設計の案A)。40 箇所中 38 箇所は tap でしか到達できないため、`#if DEBUG` の起動引数フックで観測手段を先に用意する。再発防止は `make dynamic-type-check` (Ruby) で機械的に担保する。

**Tech Stack:** SwiftUI (iOS 16+ / `NavigationStack`)、Ruby + minitest (ガードスクリプト)、`xcrun simctl` (検証)

**設計ドキュメント:** `docs/superpowers/specs/2026-08-13-dynamic-type-design.md`

## Global Constraints

- ガードの走査対象は `app/LeafTimer/` 配下の `.swift` のみ。テストコードは対象外
- 保証する文字サイズは **AX5** (`accessibility-extra-extra-extra-large`) まで
- DEBUG フックは `#if DEBUG` で囲み、**Release ビルドに一切入れない**
- `DebugInitialScreen` は**新規ファイルを作らず `TimerView.swift` 内に置く**。新規 Swift ファイルは `project.pbxproj` 登録 / orphan 検査 / `make sort` のセレモニーを呼び込むため
- **本計画で新規作成する Swift ファイルは無い。** 追加するのは Ruby 3 ファイルのみで、これらはビルド対象外。したがって `project.pbxproj` は変更されず、`make sort` / orphan 対応は不要
- `make` / `xcodebuild` 系は**毎回同一コマンド内に絶対パスの `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する**。直前ターンの cwd に依存すると `No rule to make target` で無言失敗する
- ビルド/テストの成否は**出力マーカー** (`** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` / `✅` の存在と `❌` の不在) で判定する。zsh では `${PIPESTATUS[0]}` は空を返すため使わない
- `grep --include` の glob は必ずクォートする (`--include="*.swift"`)。zsh では未クォートだと `no matches found` でコマンドごと不成立になり、`wc -l` が `0` を返して「該当なし」に見える
- Simulator は `iPhone 17` (`app/Makefile` の `SIMULATOR ?= iPhone 17`)
- `xcrun simctl` に tap は無い。foreground の `sleep` も使えないため、**launch と screenshot は別コマンドとして実行する**

## タスク依存関係

```
Task 1 (ガード TDD) ──────────────────┐
                                      │
Task 2 (DEBUG フック) → Task 3 (baseline 撮影) → Task 4 (通常 37 箇所)
                                                        │
                                                        ↓
                                                  Task 5 (特大 3 箇所)
                                                        │
                                                        ↓
                                      └────────→ Task 6 (make 配線)
                                                        │
                                                        ↓
                                                  Task 7 (検証 13 枚)
                                                        │
                                                        ↓
                                                  Task 8 (PR)
```

Task 3 は Task 2 の後でなければならない (フック無しでは設定/履歴/プレビューを撮れない)。Task 6 は Task 4・5 の後でなければならない (置換前は 40 件が違反なので `make tests` が落ちる)。

---

### Task 1: 再発防止ガードを TDD で実装する

**Files:**
- Create: `app/bin/dynamic_type_check.rb` (ロジック module)
- Create: `app/bin/dynamic-type-check.rb` (CLI 層)
- Create: `app/bin/test_dynamic_type_check.rb` (minitest)

**Interfaces:**
- Consumes: なし
- Produces: `DynamicTypeCheck.violations(swift_text) -> Array<Integer>` — 違反箇所の 1-indexed 行番号の配列。違反が無ければ空配列

**このタスクの本体は FAIL(RED) パス。** 正常系が GREEN なだけの確認は "vacuously green" で、検査ツール最大の盲点。特に GREEN フィクスチャ 3 種 (変数 / 上限付き変数 / text style) は、**素朴な実装なら必ず落とす**ように選んである。

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_dynamic_type_check.rb` を作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in dynamic_type_check.rb.
# Run: ruby bin/test_dynamic_type_check.rb
require 'minitest/autorun'
require_relative 'dynamic_type_check'

class DynamicTypeCheckTest < Minitest::Test
  # --- RED: 検出されなければならない ----------------------------------------

  def test_detects_single_line_fixed_size
    swift = 'Text("hi").font(.system(size: 15, weight: .medium))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  # TimerView.swift:52-55 は .font(.system( の直後で改行している。行アンカーの
  # grep はここを取りこぼし 39 件に見える (改行を潰して数えると実際は 40 件)。
  # 行単位で照合する実装はこのテストで落ちる。
  def test_detects_multiline_fixed_size
    swift = <<~SWIFT
      Text(time)
          .font(.system(
              size: 78, weight: .bold, design: .monospaced
          )
          )
    SWIFT
    assert_equal [2], DynamicTypeCheck.violations(swift)
  end

  def test_reports_line_number_of_every_occurrence
    swift = <<~SWIFT
      Text("a").font(.system(size: 15))
      Text("b")
      Text("c").font(.system(size: 20))
    SWIFT
    assert_equal [1, 3], DynamicTypeCheck.violations(swift)
  end

  def test_detects_decimal_size
    swift = 'Text("a").font(.system(size: 15.5))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  # --- GREEN: 検出されてはならない ------------------------------------------

  def test_ignores_scaled_metric_variable
    swift = 'Text(time).font(.system(size: timerFontSize, weight: .bold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  # 設計 2 で実際に書くコードは min(timerFontSize, 110) であり、数値リテラル
  # 110 を含む。「括弧内に数字があれば違反」という素朴な実装はこれを誤検出し、
  # ガードが自分自身の PR を落とす。判定は「size: の直後のトークンが
  # 数値リテラルか」でなければならない。
  def test_ignores_capped_scaled_metric
    swift = 'Text(time).font(.system(size: min(timerFontSize, 110), weight: .bold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  # 置換後のコード。design: / weight: を保持する正しい書き方を誤検出しない。
  def test_ignores_text_style_font
    swift = 'Text("a").font(.system(.subheadline, design: .rounded, weight: .semibold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  def test_returns_empty_for_source_without_font
    swift = 'struct Foo: View { var body: some View { Text("a") } }'
    assert_empty DynamicTypeCheck.violations(swift)
  end
end
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_dynamic_type_check.rb
```

期待: `cannot load such file -- dynamic_type_check` (LoadError) で全件失敗

- [ ] **Step 3: ロジック module を実装する**

`app/bin/dynamic_type_check.rb` を作成:

```ruby
# frozen_string_literal: true

# Pure helpers for dynamic-type-check. Kept free of I/O so they can be
# unit-tested (see test_dynamic_type_check.rb). The CLI glue lives in
# bin/dynamic-type-check.rb.
module DynamicTypeCheck
  # A hard-coded font size: `.system(size: <numeric literal>`.
  #
  # Two properties this pattern must have, both learned the hard way:
  #
  #   1. `\s*` between the tokens lets it span newlines. TimerView.swift wraps
  #      the call as `.font(.system(\n    size: 78, ...)`, and a line-anchored
  #      match silently misses it — 39 hits where there are really 40.
  #
  #   2. It requires a digit *immediately after* `size:`. The post-migration
  #      code reads `size: min(timerFontSize, 110)`, which contains the literal
  #      110; a looser "any digit inside .system(...)" pattern would flag the
  #      very code this check exists to allow, and the guard would fail its own
  #      pull request.
  #
  # `.font(` is deliberately not required, so `Font.system(size: 12)` is caught
  # too.
  FIXED_FONT_SIZE = /\.system\(\s*size:\s*[0-9]/m.freeze

  # 1-indexed line numbers of every hard-coded font size, in source order.
  def self.violations(swift_text)
    swift_text.enum_for(:scan, FIXED_FONT_SIZE).map do
      swift_text[0...Regexp.last_match.begin(0)].count("\n") + 1
    end
  end
end
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_dynamic_type_check.rb
```

期待: `8 runs, 8 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: CLI 層を実装する**

`app/bin/dynamic-type-check.rb` を作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# dynamic-type-check: fail the build when a hard-coded font size is introduced.
#
# `.font(.system(size: 15))` ignores the user's "Larger Text" setting entirely,
# so the app stays unreadable for low-vision users no matter what they choose.
# Issue #58 removed 40 such sites; this check keeps them from coming back.
#
# The fix is a standard text style (`.subheadline`, `.caption2`, …), or — for
# the few genuinely oversized numerals — `@ScaledMetric` with a cap, e.g.
# `.font(.system(size: min(timerFontSize, 110), weight: .bold))`, which this
# check deliberately allows.
#
# Usage:
#   ruby bin/dynamic-type-check.rb
#
# Exit code 0 = no hard-coded size; non-zero = at least one found.

require_relative 'dynamic_type_check'

PROJECT_DIR = File.expand_path('..', __dir__)            # app/
SOURCE_DIR  = File.join(PROJECT_DIR, 'LeafTimer')

files = Dir.glob(File.join(SOURCE_DIR, '**', '*.swift')).sort

# Guard the false-green: if SOURCE_DIR ever moves, the glob yields nothing and
# every check below passes vacuously.
if files.empty?
  warn "❌ dynamic-type-check failed: no Swift file found under #{SOURCE_DIR}"
  exit 1
end

violations = files.flat_map do |path|
  relative = path.sub("#{PROJECT_DIR}/", '')
  DynamicTypeCheck.violations(File.read(path)).map { |line| "#{relative}:#{line}" }
end

if violations.empty?
  puts "✅ dynamic-type-check passed (#{files.size} files scanned)"
  exit 0
else
  warn "❌ dynamic-type-check failed: #{violations.size} hard-coded font size(s) found"
  violations.each { |site| warn "   - #{site}" }
  warn '   Use a text style (.subheadline / .caption2 / …) or @ScaledMetric with a cap.'
  exit 1
end
```

- [ ] **Step 6: 実コードに対して RED になることを確認する (このタスクの要)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/dynamic-type-check.rb; echo "exit=$?"
```

期待:
- `❌ dynamic-type-check failed: 40 hard-coded font size(s) found`
- `exit=1`
- 一覧に **`LeafTimer/View/TimerView.swift:52`** が含まれる (折り返し箇所を捕捉できている証拠。ここが無ければ 39 件になっているはずで、regex が改行を跨げていない)

**件数が 40 でない場合は先に進まない。** 39 なら複数行対応が壊れている。41 以上なら誤検出しているので、どのファイルの何行目かを確認する。

- [ ] **Step 7: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/dynamic_type_check.rb app/bin/dynamic-type-check.rb app/bin/test_dynamic_type_check.rb && git commit -m "$(cat <<'EOF'
test(a11y): #58 固定 font size を検出するガードを追加

.font(.system(size: 15)) は「文字を大きく」を完全に無視するため、
弱視ユーザーには何を設定しても読めないままになる。40 箇所を直した後の
再混入を機械的に防ぐ。

判定は「size: の直後のトークンが数値リテラルか」で行う:
- 改行を跨いで照合する (TimerView.swift の折り返しを行アンカーだと落とす)
- min(timerFontSize, 110) は許可する (素朴な実装だとガードが自分自身の
  PR を落とす)

この時点では実コードに 40 件の違反があるため CLI は意図的に RED。
Makefile への配線は置換完了後 (Task 6)。

Refs #58
EOF
)"
```

---

### Task 2: DEBUG 専用の起動引数フックを実装する

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift`

**Interfaces:**
- Consumes: なし
- Produces: 起動引数 `-InitialScreen=settings` / `-InitialScreen=history` / `-InitialScreen=timePreview` で各画面を直接表示できる (DEBUG ビルドのみ)

**このタスクは表示内容を一切変えない。** それが Task 3 の baseline を正当なものにする条件。引数なしで起動したときのレンダリング結果は変更前と完全に同一でなければならない。

- [ ] **Step 1: 既存の body を `timerContent` にリネームする**

`TimerView.swift:15` の `var body: some View {` を次に変更する。中身 (`NavigationStack { ... }` 以下) はそのまま:

```swift
    private var timerContent: some View {
        NavigationStack {
```

- [ ] **Step 2: 新しい `body` と DEBUG 分岐を追加する**

`timerContent` の直前 (元の `// MARK: - View` の下) に挿入:

```swift
    var body: some View {
#if DEBUG
        if let screen = DebugInitialScreen.requested {
            debugScreen(screen)
        } else {
            timerContent
        }
#else
        timerContent
#endif
    }

#if DEBUG
    /// 検証用に単一画面を直接表示する。`simctl` には tap が無いため、
    /// 設定・履歴・プレビューは通常の導線 (歯車 → NavigationLink) では
    /// スクリーンショットを撮れない。
    ///
    /// EnhancedSettingView / HistoryView は通常 NavigationStack の内側で
    /// 描画されるので、ここでも NavigationStack で包む。裸で返すと
    /// ツールバーと navigationTitle が出ず、baseline が不正確になる。
    /// TimerPreviewSheet は自前で NavigationView を持つため包まない。
    @ViewBuilder
    private func debugScreen(_ screen: String) -> some View {
        switch screen {
        case "settings":
            NavigationStack {
                EnhancedSettingView(settingViewModel: settingViewModel)
            }
        case "history":
            NavigationStack {
                HistoryView(viewModel: timerViewModel.historyViewModel)
            }
        case "timePreview":
            TimerPreviewSheet(
                workingTime: ItemValue.workingTimeList[settingViewModel.workingTime],
                breakTime: ItemValue.breakTimeList[settingViewModel.breakTime]
            )
        default:
            timerContent
        }
    }
#endif
```

- [ ] **Step 3: `DebugInitialScreen` をファイル末尾に追加する**

`TimerView.swift` の末尾 (`struct TimerView` の閉じ括弧の後) に追加。**新規ファイルは作らない** (pbxproj 登録 / orphan 検査を呼び込むため):

```swift
#if DEBUG
/// 起動引数 `-InitialScreen=<name>` を読む。既存の `-UMPDebugGeographyEEA`
/// (Components/AdsConsentServices.swift:20) と同じ発想。
enum DebugInitialScreen {
    static var requested: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-InitialScreen=") }?
            .replacingOccurrences(of: "-InitialScreen=", with: "")
    }
}
#endif
```

- [ ] **Step 4: ビルドとテストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tee /tmp/58-task2.log | tail -20
```

期待: 出力に `** TEST SUCCEEDED **` が含まれる。`Error 6x` / `** TEST FAILED **` が無いこと。

**もし ViewInspector 系のテストが落ちたら、それはフックのバグではない。** `body` を `if let ... else` で包んだことで階層に `ConditionalContent` が 1 段挟まり、既存テストの traversal path がずれたのが原因。正しい対処は**テスト側の traversal を直すこと**で、フックを撤回することではない。

```bash
grep -c "\*\* TEST SUCCEEDED \*\*" /tmp/58-task2.log
```

期待: 1 以上

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View/TimerView.swift && git commit -m "$(cat <<'EOF'
test(a11y): #58 検証用の DEBUG 起動引数フックを追加

固定 font size 40 箇所のうち 38 箇所は設定/履歴/プレビュー画面にあり、
これらは NavigationLink の tap でしか到達できない。simctl に tap が無いため
(Issue #90 で判明した制約)、このままでは AX5 でのレイアウト検証ができない。

-InitialScreen=settings / history / timePreview で各画面を直接表示する。
#if DEBUG で囲むため Release ビルドには入らない。

表示内容は一切変えていない。この commit 時点のスクリーンショットが
置換前 baseline になる。

Refs #58
EOF
)"
```

---

### Task 3: 置換前の baseline スクリーンショットを撮る

**Files:**
- Create: `/tmp/58-baseline/*.png` (リポジトリには commit しない)

**Interfaces:**
- Consumes: Task 2 の `-InitialScreen=` フック
- Produces: `/tmp/58-baseline/{timer,settings,history,timePreview,onboarding}-large.png` の 5 枚

**このタスクは Task 4 より前でなければならない。** 「置換前後で見た目が変わらない」は、置換前の画像が無ければ検証できない。

- [ ] **Step 1: Simulator を起動してビルド成果物のパスを取得する**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl bootstatus "iPhone 17" -b
```

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tail -5
```

期待: `** BUILD SUCCEEDED **`

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'
```

**`find app/build ...` で `.app` を探してはいけない。** そこには古いビルドの残骸があり、掴むと「変更が反映されていない」と誤診する (エラーにならず古い画面が出るだけなので silent に間違った結論になる)。

- [ ] **Step 2: install して文字サイズを標準にする**

`$BUILT_DIR` は Step 1 の出力を絶対パスで使う:

```bash
xcrun simctl install booted "<BUILT_DIR>/LeafTimer.app"
xcrun simctl ui booted content_size large
mkdir -p /tmp/58-baseline
```

- [ ] **Step 3: トップ画面を撮る**

launch と screenshot は**別コマンド**にする (foreground の `sleep` が使えないため、ターン境界を splash の待ち時間に充てる):

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer
```

```bash
xcrun simctl io booted screenshot /tmp/58-baseline/timer-large.png && echo "saved"
```

- [ ] **Step 4: 設定・履歴・プレビューを撮る**

各画面について terminate → launch → screenshot を繰り返す:

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=settings
```

```bash
xcrun simctl io booted screenshot /tmp/58-baseline/settings-large.png && echo "saved"
```

続いて履歴画面:

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=history
```

```bash
xcrun simctl io booted screenshot /tmp/58-baseline/history-large.png && echo "saved"
```

続いてプレビュー画面:

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=timePreview
```

```bash
xcrun simctl io booted screenshot /tmp/58-baseline/timePreview-large.png && echo "saved"
```

- [ ] **Step 5: オンボーディングを撮る**

`simctl uninstall` は使わない。ATT の決定までリセットされ、次回起動で ATT ダイアログが出て手動タップが必要になる (Issue #90 のコメントに記録済み):

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl spawn booted defaults delete jp.ema.LeafTimer hasSeenOnboarding; xcrun simctl launch booted jp.ema.LeafTimer
```

```bash
xcrun simctl io booted screenshot /tmp/58-baseline/onboarding-large.png && echo "saved"
```

- [ ] **Step 6: 5 枚が揃ったことを確認する**

```bash
ls -la /tmp/58-baseline/ && ls /tmp/58-baseline/*.png | wc -l
```

期待: 5

各 png を Read ツールで開き、**意図した画面が写っていること**を目視で確認する (splash や真っ黒の画像が混ざっていないか)。写っていなければ launch し直して撮り直す。

- [ ] **Step 7: commit は不要**

スクリーンショットはリポジトリに入れない。次のタスクへ進む。

---

### Task 4: 通常の 37 箇所を text style へ置換する

**Files:**
- Modify: `app/LeafTimer/View/EnhancedSettingView.swift` (7)
- Modify: `app/LeafTimer/View/Settings/TimerSettingsSection.swift` (9 — 全 10 箇所のうち 173 行目のみ Task 5)
- Modify: `app/LeafTimer/View/Settings/SoundSettingsSection.swift` (7)
- Modify: `app/LeafTimer/View/Settings/ResetSettingsSection.swift` (5)
- Modify: `app/LeafTimer/View/Settings/AboutSettingsSection.swift` (4)
- Modify: `app/LeafTimer/View/HistoryView.swift` (4)
- Modify: `app/LeafTimer/View/Elements/StatChip.swift` (1)

**Interfaces:**
- Consumes: なし
- Produces: なし (見た目の等価な置換)

**行番号は 2026-08-13 時点。** ずれている場合は「内容」列で同定する。`weight` と `design` は必ず保持する。

- [ ] **Step 1: `EnhancedSettingView.swift` の 7 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 24 | Label 行タイトル | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 30 | Image `checkmark` | `.font(.system(size: 14, weight: .semibold))` | `.font(.subheadline.weight(.semibold))` |
| 40 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 44 | Section footer | `.font(.system(size: 11))` | `.font(.caption2)` |
| 57 | Label 行タイトル | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 65 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 88 | Done ボタン | `.font(.system(size: 16, weight: .medium))` | `.font(.callout.weight(.medium))` |

- [ ] **Step 2: `TimerSettingsSection.swift` の 9 箇所を置換する**

このファイルには固定サイズが 10 箇所ある。**下表の 9 箇所を置換し、173 行目 (48pt) だけは触らずに残す** (Task 5 で `@ScaledMetric` にするため)。

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 16 | Label 作業時間 | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 22 | 設定値 | `.font(.system(size: 15, weight: .semibold, design: .rounded))` | `.font(.system(.subheadline, design: .rounded, weight: .semibold))` |
| 52 | Label 休憩時間 | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 58 | 設定値 | `.font(.system(size: 15, weight: .semibold, design: .rounded))` | `.font(.system(.subheadline, design: .rounded, weight: .semibold))` |
| 87 | Image `eye` | `.font(.system(size: 14))` | `.font(.subheadline)` |
| 89 | プレビューボタン文言 | `.font(.system(size: 14, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 104 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 136 | Image `arrow.down` | `.font(.system(size: 20))` | `.font(.title3)` |
| 169 | プレビュー内タイトル | `.font(.system(size: 14, weight: .medium))` | `.font(.subheadline.weight(.medium))` |

置換後、このファイルに残る固定サイズは 173 行目の 1 箇所だけになる。

- [ ] **Step 3: `SoundSettingsSection.swift` の 7 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 18 | Label 作業音 | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 30 | Image `checkmark.circle` | `.font(.system(size: 20))` | `.font(.title3)` |
| 33 | サウンド名 | `.font(.system(size: 15))` | `.font(.subheadline)` |
| 44 | Image `play.circle` | `.font(.system(size: 22))` | `.font(.title2)` |
| 65 | Label バイブレーション | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 94 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 98 | Section footer | `.font(.system(size: 11))` | `.font(.caption2)` |

- [ ] **Step 4: `ResetSettingsSection.swift` の 5 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 15 | Image `arrow.counterclockwise` | `.font(.system(size: 20))` | `.font(.title3)` |
| 19 | リセットボタン文言 | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 47 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 52 | Footer アプリ名 | `.font(.system(size: 11, weight: .medium))` | `.font(.caption2.weight(.medium))` |
| 54 | Footer 著作権表記 | `.font(.system(size: 10))` | `.font(.caption2)` |

- [ ] **Step 5: `AboutSettingsSection.swift` の 4 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 16 | Label レビュー | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |
| 22 | Image `chevron.right` | `.font(.system(size: 12, weight: .semibold))` | `.font(.caption.weight(.semibold))` |
| 33 | Section header | `.font(.system(size: 13, weight: .semibold))` | `.font(.footnote.weight(.semibold))` |
| 40 | Section footer | `.font(.system(size: 11))` | `.font(.caption2)` |

- [ ] **Step 6: `HistoryView.swift` の 4 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 50 | 統計行テキスト | `.font(.system(size: 17, weight: .medium))` | `.font(.body.weight(.medium))` |
| 59 | 「直近7日」見出し | `.font(.system(size: 14, weight: .semibold))` | `.font(.subheadline.weight(.semibold))` |
| 67 | 棒グラフの件数 | `.font(.system(size: 11))` | `.font(.caption2)` |
| 73 | 日付ラベル | `.font(.system(size: 10))` | `.font(.caption2)` |

- [ ] **Step 7: `StatChip.swift` の 1 箇所を置換する**

| 行 | 内容 | Before | After |
| --- | --- | --- | --- |
| 16 | ピル内テキスト | `.font(.system(size: 15, weight: .medium))` | `.font(.subheadline.weight(.medium))` |

- [ ] **Step 8: 残りが 3 箇所であることをガードで確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/dynamic-type-check.rb; echo "exit=$?"
```

期待: `3 hard-coded font size(s) found` で、内訳が次の 3 件のみ:
- `LeafTimer/View/TimerView.swift:<タイマー行>`
- `LeafTimer/View/OnboardingView.swift:50`
- `LeafTimer/View/Settings/TimerSettingsSection.swift:173`

**4 件以上残っていたら置換漏れがある。** 一覧の行番号を直接修正してから次へ進む。

- [ ] **Step 9: ビルドとテストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tee /tmp/58-task4.log | tail -20
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 10: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View && git commit -m "$(cat <<'EOF'
fix(a11y): #58 固定 font size 37 箇所を text style へ置換

固定値は標準 text style のデフォルトサイズとほぼ一致していた
(15pt=.subheadline / 13pt=.footnote / 11pt=.caption2 / 17pt=.body /
16pt=.callout / 12pt=.caption / 20pt=.title3 / 22pt=.title2)。
そのため標準サイズでの見た目は変えずに「文字を大きく」への追従だけを
付加できる。

標準に無い 14pt (5 箇所) は隣接要素に合わせて .subheadline、
10pt (2 箇所) は標準最小の .caption2 に寄せた (いずれも +1pt)。
weight と design (.rounded) は全て保持している。

特大 3 箇所 (78/72/48pt) は比例拡大すると画面に収まらないため別 commit。

Refs #58
EOF
)"
```

---

### Task 5: 特大 3 箇所を上限付き `@ScaledMetric` にする

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift`
- Modify: `app/LeafTimer/View/OnboardingView.swift:50`
- Modify: `app/LeafTimer/View/Settings/TimerSettingsSection.swift:173`

**Interfaces:**
- Consumes: なし
- Produces: なし

AX5 では本文が約 3.1 倍になるため、78pt を素直に比例拡大すると約 240pt となり iPhone の画面幅 390pt に `25:00` の 5 文字が収まらない。`relativeTo: .largeTitle` を基準にすると伸び率が約 1.76 倍に緩み、さらに上限と `minimumScaleFactor` で二重に保護する。

- [ ] **Step 1: `TimerView.swift` にタイマー用の `@ScaledMetric` を追加する**

`TimerView.swift:11` の `@State private var showOnboarding = false` の直後に追加:

```swift
    /// タイマー数字は 78pt と大きく、本文と同率 (AX5 で約 3.1 倍) に拡大すると
    /// 画面幅に収まらない。largeTitle 基準 (約 1.76 倍) に緩めた上で上限を張る。
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 78
```

- [ ] **Step 2: タイマー表示を置換する**

`TimerView.swift:52-55` の以下を:

```swift
                        .font(.system(
                            size: 78, weight: .bold, design: .monospaced
                        )
                        )
```

次に置き換える:

```swift
                        .font(.system(size: min(timerFontSize, 110), weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
```

`.lineLimit(1)` + `.minimumScaleFactor(0.8)` は安全弁。上限 110 の見積もりが多少ずれても、レイアウト破綻ではなく緩やかな縮小に留まる。

- [ ] **Step 3: `OnboardingView.swift` の絵文字を置換する**

`OnboardingView.swift:5` の `@State private var selection = 0` の直後に追加:

```swift
    @ScaledMetric(relativeTo: .largeTitle) private var emojiFontSize: CGFloat = 72
```

`OnboardingView.swift:50` を置換:

```swift
                                .font(.system(size: min(emojiFontSize, 100)))
```

- [ ] **Step 4: `PreviewTimerDisplay` の時刻表示を置換する**

`TimerSettingsSection.swift:158` の `let color: Color` の直後に追加:

```swift
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 48
```

`TimerSettingsSection.swift:173` を置換:

```swift
                .font(.system(size: min(timeFontSize, 72), weight: .light, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
```

- [ ] **Step 5: ガードが green になることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/dynamic-type-check.rb; echo "exit=$?"
```

期待:
- `✅ dynamic-type-check passed (N files scanned)`
- `exit=0`

**ここで `min(timerFontSize, 110)` が違反として報告されたら、Task 1 の regex が間違っている。** Task 1 の `test_ignores_capped_scaled_metric` が通っているはずなので、その場合は CLI 側の実装を確認する。

- [ ] **Step 6: ビルドとテストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tee /tmp/58-task5.log | tail -20
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 7: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View && git commit -m "$(cat <<'EOF'
fix(a11y): #58 特大 3 箇所を上限付き @ScaledMetric にする

タイマー 78pt / 絵文字 72pt / プレビュー 48pt は、本文と同率 (AX5 で
約 3.1 倍) に拡大すると 78pt→約 240pt となり画面幅 390pt に 25:00 の
5 文字が収まらない。

relativeTo: .largeTitle で伸び率を約 1.76 倍に緩め、さらに上限
(110/100/72pt) を張る。上限値は実測前の暫定値のため、タイマーと
プレビューには minimumScaleFactor(0.8) を安全弁として入れ、見積もりが
ずれてもレイアウト破綻ではなく緩やかな縮小で済むようにした。

これで dynamic-type-check が green になる。

Refs #58
EOF
)"
```

---

### Task 6: ガードを `make tests` に配線する

**Files:**
- Modify: `app/Makefile`

**Interfaces:**
- Consumes: Task 1 の `bin/dynamic-type-check.rb`
- Produces: `make dynamic-type-check` ターゲット

**このタスクは Task 5 の後でなければならない。** 置換前に配線すると `make tests` が 40 件の違反で落ちる。

- [ ] **Step 1: `dynamic-type-check` ターゲットを追加する**

`app/Makefile` の `localization-check:` ターゲットの直後に追加 (既存の書式に揃え、ユニットテストを先に走らせてから本体を実行する):

```make
dynamic-type-check:
	@echo "Running dynamic-type-check..."
	@ruby bin/test_dynamic_type_check.rb
	@ruby bin/dynamic-type-check.rb
```

- [ ] **Step 2: `tests` チェーンに組み込む**

`app/Makefile` の以下の行を:

```make
tests: precheck localization-check sort lint unit-tests
```

次に変更する:

```make
tests: precheck localization-check dynamic-type-check sort lint unit-tests
```

- [ ] **Step 3: ターゲット単体で green になることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make dynamic-type-check
```

期待: `8 runs, ... 0 failures, 0 errors` と `✅ dynamic-type-check passed`

- [ ] **Step 4: 意図的に壊した入力で RED になることを実証する**

**このステップを飛ばさない。** 正常系が GREEN なだけの確認は "vacuously green" で、検査ツール最大の盲点。

既存ファイルの末尾にコメント行として違反を 1 つ足す。コメントなのでビルドは壊れず、`git checkout` で確実に戻せる (新規 Swift ファイルを置くと orphan 検査を呼び込むため避ける):

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && printf '\n// RED fixture: .font(.system(size: 99))\n' >> LeafTimer/View/Elements/StatChip.swift && ruby bin/dynamic-type-check.rb; echo "exit=$?"
```

期待: `❌ dynamic-type-check failed: 1 hard-coded font size(s) found` と `exit=1`

確認後、必ず元に戻す:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git checkout app/LeafTimer/View/Elements/StatChip.swift && cd app && ruby bin/dynamic-type-check.rb
```

期待: `✅ dynamic-type-check passed`

- [ ] **Step 5: `make tests` 全体が green になることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tee /tmp/58-task6.log | tail -30
```

判定は**成功マーカーの存在と失敗マーカーの不在の両方**で行う (「失敗しそうな単語」を想像で grep すると、成功メッセージや引数に同じ語が含まれて偽陽性になる):

```bash
grep -c "✅ dynamic-type-check passed" /tmp/58-task6.log
grep -c "✅ localization-check passed" /tmp/58-task6.log
grep -c "\*\* TEST SUCCEEDED \*\*" /tmp/58-task6.log
grep -c "❌" /tmp/58-task6.log
```

期待: 最初の 3 つが 1 以上、最後の `❌` が 0

- [ ] **Step 6: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/Makefile && git commit -m "$(cat <<'EOF'
build(a11y): #58 dynamic-type-check を make tests に配線

localization-check の隣に置き、固定 font size の新規混入を CI で止める。
置換完了後に配線している (置換前に入れると 40 件の違反で make tests が
落ちるため)。

意図的に壊した入力で RED になることを確認済み。

Refs #58
EOF
)"
```

---

### Task 7: 検証マトリクス 13 枚を撮影し上限値を確定する

**Files:**
- Create: `/tmp/58-verify/*.png` (リポジトリには commit しない)
- Modify (必要なら): `app/LeafTimer/View/TimerView.swift`、`OnboardingView.swift`、`TimerSettingsSection.swift` の上限値

**Interfaces:**
- Consumes: Task 3 の baseline、Task 2 の `-InitialScreen=` フック
- Produces: 検証済みの上限値

- [ ] **Step 1: 再ビルドして install する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tail -5
```

期待: `** BUILD SUCCEEDED **`

ビルド成果物のパスを取得する。**`find app/build ...` で `.app` を探してはいけない** — そこには古いビルドの残骸があり、掴むと「変更が反映されていない」と silent に誤診する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'
```

出力された絶対パスを使って install する:

```bash
xcrun simctl install booted "<上で得た BUILT_PRODUCTS_DIR>/LeafTimer.app"
mkdir -p /tmp/58-verify
```

- [ ] **Step 2: 標準サイズ 5 枚を撮って baseline と比較する**

```bash
xcrun simctl ui booted content_size large
```

launch と screenshot は**別コマンド**で実行する (foreground の `sleep` が使えないため、ターン境界を splash の待ち時間に充てる)。5 画面ぶんを順に撮る:

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer
```

```bash
xcrun simctl io booted screenshot /tmp/58-verify/timer-large.png && echo "saved"
```

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=settings
```

```bash
xcrun simctl io booted screenshot /tmp/58-verify/settings-large.png && echo "saved"
```

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=history
```

```bash
xcrun simctl io booted screenshot /tmp/58-verify/history-large.png && echo "saved"
```

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl launch booted jp.ema.LeafTimer -InitialScreen=timePreview
```

```bash
xcrun simctl io booted screenshot /tmp/58-verify/timePreview-large.png && echo "saved"
```

オンボーディングは `simctl uninstall` を使わない (ATT の決定までリセットされ、次回起動で ATT ダイアログが出て手動タップが必要になる。Issue #90 のコメントに記録済み):

```bash
xcrun simctl terminate booted jp.ema.LeafTimer 2>/dev/null; xcrun simctl spawn booted defaults delete jp.ema.LeafTimer hasSeenOnboarding; xcrun simctl launch booted jp.ema.LeafTimer
```

```bash
xcrun simctl io booted screenshot /tmp/58-verify/onboarding-large.png && echo "saved"
```

各画像を Read ツールで開き、`/tmp/58-baseline/<screen>-large.png` と**並べて目視比較**する。

期待: **実質同一**。文字サイズ・配置・行折り返しが変わっていないこと。14pt→15pt / 10pt→11pt の 7 箇所だけ 1pt 大きくなるが、レイアウトは動かないはず。ずれていたら対応表の割り当てを見直す。

- [ ] **Step 3: 中間サイズ 3 枚を撮る**

```bash
xcrun simctl ui booted content_size extra-extra-extra-large
```

本 Task の Step 2 に挙げた terminate/launch → screenshot のコマンド対を、`timer` / `settings` / `history` の 3 画面について再実行する。保存先だけ `-large.png` から `-xxxl.png` に変える (`/tmp/58-verify/timer-xxxl.png` など)。

期待: 文字が拡大しており、見切れ・重なりが無いこと。

- [ ] **Step 4: AX5 で 5 枚を撮る (保証対象)**

```bash
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
```

本 Task の Step 2 に挙げた terminate/launch → screenshot のコマンド対を、5 画面すべてについて再実行する。保存先だけ `-large.png` から `-ax5.png` に変える (`/tmp/58-verify/settings-ax5.png` など)。オンボーディングは再度 `defaults delete jp.ema.LeafTimer hasSeenOnboarding` を挟む。

各画像を Read ツールで開き、次を確認する:

| 確認項目 | 対象 |
| --- | --- |
| タイマー数字が画面幅に収まっている | `timer-ax5.png` |
| 統計ピル (StatChip) の文字が切れていない | `timer-ax5.png` |
| 設定各行のラベルと値が重なっていない | `settings-ax5.png` |
| セクションヘッダ・フッターが読める | `settings-ax5.png` |
| 棒グラフの日付ラベルが潰れていない | `history-ax5.png` |
| プレビューの時刻が収まっている | `timePreview-ax5.png` |
| オンボーディングの絵文字と本文が収まっている | `onboarding-ax5.png` |

- [ ] **Step 5: 上限値を必要に応じて調整する**

Step 4 で見切れ・重なりがあった場合のみ、該当箇所の上限を下げる:

| 箇所 | 現在の上限 | ファイル |
| --- | --- | --- |
| タイマー | `min(timerFontSize, 110)` | `TimerView.swift` |
| 絵文字 | `min(emojiFontSize, 100)` | `OnboardingView.swift` |
| プレビュー | `min(timeFontSize, 72)` | `TimerSettingsSection.swift` |

調整したら Step 1 から撮り直す。調整不要なら次へ。

- [ ] **Step 6: 文字サイズを標準に戻す**

```bash
xcrun simctl ui booted content_size large
```

- [ ] **Step 7: 上限値を調整した場合のみ commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View && git commit -m "$(cat <<'EOF'
fix(a11y): #58 AX5 実測に基づき特大文字の上限を調整

Refs #58
EOF
)"
```

調整不要だった場合は commit せず次のタスクへ。

---

### Task 8: PR を作成する

**Files:**
- なし (git 操作のみ)

**Interfaces:**
- Consumes: Task 1〜7 の全 commit
- Produces: GitHub PR

- [ ] **Step 1: 既存 PR / merge 状況を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch origin && gh pr list --state all --head feature/58-dynamic-type --json number,state,title
```

期待: `[]` (既存 PR なし)

- [ ] **Step 2: 最終確認として `make tests` を回す**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tee /tmp/58-final.log | tail -30
```

```bash
grep -c "✅ dynamic-type-check passed" /tmp/58-final.log; grep -c "\*\* TEST SUCCEEDED \*\*" /tmp/58-final.log; grep -c "❌" /tmp/58-final.log
```

期待: 1 以上 / 1 以上 / 0

- [ ] **Step 3: 作業ツリーがクリーンなことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git status --short
```

期待: 空。`project.pbxproj` に差分が出ていたら想定外 (本計画は Swift ファイルを新規追加しないため)。出ていたら `make sort` を実行して commit する。

- [ ] **Step 4: push して PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git push -u origin feature/58-dynamic-type
```

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create --title "fix(a11y): #58 Dynamic Type 対応 — 固定 font size 40 箇所を text style へ移行" --body "$(cat <<'EOF'
## 概要

固定 font size 40 箇所により、iOS の「文字を大きく」を最大にしても文字が拡大せず、弱視・高齢ユーザーが読めない状態だった (Issue #58)。全 40 箇所を SwiftUI 標準 text style / 上限付き `@ScaledMetric` へ移行し、AX5 まで追従するようにした。

設計: `docs/superpowers/specs/2026-08-13-dynamic-type-design.md`
計画: `docs/superpowers/plans/2026-08-13-dynamic-type-58.md`

## 変更内容

- **37 箇所を text style へ置換** — 固定値は標準 text style のデフォルトサイズとほぼ一致していたため (15pt=`.subheadline` / 13pt=`.footnote` / 11pt=`.caption2` 等)、標準サイズでの見た目は変えずに追従能力だけを付加
- **特大 3 箇所を上限付き `@ScaledMetric` に** — タイマー 78pt を素直に比例拡大すると AX5 で約 240pt となり画面幅 390pt に収まらないため、`relativeTo: .largeTitle` + 上限 + `minimumScaleFactor(0.8)` の三重の保護
- **`make dynamic-type-check` を追加** — 固定 font size の新規混入を CI で止める。意図的に壊した入力で RED になることを確認済み
- **DEBUG 専用の `-InitialScreen=` フックを追加** — 40 箇所中 38 箇所は tap でしか到達できず、`simctl` に tap が無いため検証手段として追加。`#if DEBUG` で囲んでおり Release ビルドには入らない

## 検証

`iPhone 17` Simulator で 13 枚のスクリーンショットを取得:

| 文字サイズ | 対象画面 | 結果 |
| --- | --- | --- |
| `large` (標準) | 全 5 画面 | 置換前 baseline と実質同一 |
| `extra-extra-extra-large` | timer / settings / history | 崩れなし |
| `accessibility-extra-extra-extra-large` (AX5) | 全 5 画面 | 崩れず読める |

## スクリーンショット

<!-- ここに AX5 のスクリーンショットをドラッグ&ドロップで添付 -->

Closes #58

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_018dNQQKDDzLNLWECz6J8E3b
EOF
)"
```

- [ ] **Step 5: スクリーンショットをユーザーに渡す**

`gh pr create` の本文に**ローカルファイルパスの画像は埋め込めない** (GitHub は到達可能な URL しか取得しない)。`SendUserFile` で AX5 の 5 枚をユーザーに渡し、PR 説明欄の「スクリーンショット」セクションへブラウザからドラッグ&ドロップで添付してもらう。

- [ ] **Step 6: CI の完了を待つ**

`gh pr checks --watch` は GraphQL API の `read: operation timed out` で落ちることがあるため、ポーリングループを使う:

```bash
until gh pr checks <PR番号> --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done; gh pr checks <PR番号>
```

**このループが実行環境で `sleep` を弾かれて動かない場合**は、`Monitor` ツールで同じ条件 (`bucket != "pending"` が全件 true) を待つか、`gh pr checks <PR番号>` を数分おきに単発で叩いて代替する。Global Constraints の「foreground の `sleep` は使えない」はここにも当てはまる。

このリポジトリは Auto-merge が無効 (`gh pr merge --auto` は失敗する)。CI 完了を確認してから `gh pr merge <PR番号> --merge` を明示的に実行する。

---

## 完了条件

- [ ] `ruby bin/dynamic-type-check.rb` が `✅` かつ exit 0
- [ ] 意図的に壊した入力で `❌` かつ exit 1 になることを実証済み (Task 6 Step 4)
- [ ] `make tests` が green (`✅ dynamic-type-check passed` / `** TEST SUCCEEDED **` があり `❌` が 0)
- [ ] 標準サイズ 5 枚が置換前 baseline と実質同一
- [ ] AX5 の 5 枚で見切れ・重なりが無い
- [ ] `git status --short` が空 (`project.pbxproj` に差分が出ていない)
- [ ] PR が作成され CI が green
