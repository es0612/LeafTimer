# ローカライズ検証の恒久化 + sentinel 抜け穴修正 Implementation Plan (Issue #99 / #98)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PR #96 で手動実行した「コード中の全 `NSLocalizedString` キーが ja/en 両 `Localizable.strings` に存在するか」の検証を `make` ターゲットとして恒久化し、あわせて 2 つの localization テストに残っている sentinel 抜け穴を塞ぎ、`settings.footer.app_name` の翻訳方針をコメントで確定させる。

**Architecture:** 既存の `bin/xcode-precheck.rb` / `bin/gitignore-doctor.rb` と同じ 3 層構成を踏襲する — 純粋ロジック module (`localization_check.rb`) + CLI glue (`localization-check.rb`) + minitest (`test_localization_check.rb`)。`make localization-check` を新設し `make tests` の依存に入れる。検査ツールなので **RED パス (壊れた入力で正しく落ちること) をテストと実ファイル改変の両方で実証**してから green を信用する。

**Tech Stack:** Ruby 2.7.5 (システム同梱、`tally` / `filter_map` 使用可)、minitest (Ruby 同梱)、GNU make、XCTest (Swift テスト修正分)

## Global Constraints

- default branch は `master`。作業ブランチは `chore/99-98-localization-followup` (作成済み)
- Bash でビルド/テスト系を打つ時は**毎回**絶対パスの `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を同一コマンド内に含める (cwd ドリフトで `No rule to make target` になる)
- テスト成否は exit code ではなく**出力マーカー** (`** TEST SUCCEEDED **` / `✅ localization-check passed`) の存在と `❌` の不在の両方で判定する。zsh のため `${PIPESTATUS[0]}` は使用禁止
- `cd app && make unit-tests` は Bash timeout を `600000` (10 分) に明示する
- 新規 **Ruby** ファイルは Xcode target への attach 不要 (`bin/` 配下は project 管理外)。よって `add-to-target.rb` / `make sort` は本 plan では不要
- `print()` 追加禁止 (Swift 側)
- 既存の翻訳値は 1 文字も変更しない。本 plan で `.strings` に加える変更は「en の重複行 1 行の削除」と「ja へのコメント 1 行追加」のみ

## 着手前に確定している事実 (2026-08-12 実測)

| 事実 | 値 | 出典 |
| --- | --- | --- |
| コード中のユニークキー数 | **80** | `NSLocalizedString(` の全走査 |
| `ja.lproj` 定義キー (ユニーク) | 80 | `comm` による突き合わせ |
| `en.lproj` 定義キー (ユニーク) | 80 | 同上 |
| 欠落キー (コードにあるが strings に無い) | **0 件** | 同上 |
| 未使用キー (strings にあるがコードに無い) | **0 件** | 同上 |
| `en.lproj` の重複定義 | **1 件** — `"time.10_minutes"` が 24 行目と 44 行目 (値はどちらも `"10 min"`) | `uniq -d` |
| `ja.lproj` の重複定義 | 0 件 | 同上 |

**重要な落とし穴 (実際に踏んだ):** `AboutSettingsSection.swift:36-39` の `NSLocalizedString(` は **キーが次の行**にある:

```swift
Text(NSLocalizedString(
    "settings.review_app_footer",
    comment: "Footer for review section"
))
```

行アンカーの regex (`NSLocalizedString("[^"]*"`) で走査すると**この呼び出しを取りこぼし**、`settings.review_app_footer` を「未使用キー」と誤報告する。checker は**改行をまたいで**キーを拾わなければならない。この 1 件が唯一の複数行呼び出しで、非リテラル引数 (`NSLocalizedString(someVar)`) は 0 件。

→ 結果として **missing / unused の検査は現状の repo では最初から GREEN**。したがって「壊れた入力で RED になること」を Task 2 で明示的に実証するまで、この checker を信用してはならない。duplicate 検査だけは現状で RED になる (Task 3 で解消)。

---

## Task 0: Plan commit

**Files:**
- Create: `docs/superpowers/plans/2026-08-12-99-98-localization-followup.md` (this file)

- [ ] **Step 1: plan を commit する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add docs/superpowers/plans/2026-08-12-99-98-localization-followup.md && \
git commit -m "docs(plan): #99/#98 ローカライズ検証の make ターゲット化と sentinel 修正の実装 plan"
```

---

## Task 1: 純粋ロジック module + minitest (TDD)

**Files:**
- Create: `app/bin/localization_check.rb`
- Test: `app/bin/test_localization_check.rb`

**Interfaces:**
- Produces (Task 2 が依存する契約):
  - `LocalizationCheck.code_keys(swift_text) -> Array<String>` — 出現順、重複あり
  - `LocalizationCheck.strings_keys(strings_text) -> Array<String>` — 出現順、重複あり (重複検出のため uniq しない)
  - `LocalizationCheck.duplicate_keys(strings_text) -> Array<String>` — ソート済み
  - `LocalizationCheck.report(code_keys, locale_texts) -> Hash` — `locale_texts` は `{ "ja" => <本文>, "en" => <本文> }`。戻り値は次の 4 キー:
    - `:missing` — `{ locale => Array<String> }` コードで使われているがそのロケールに定義が無いキー (FAIL 対象)
    - `:parity` — `{ locale => Array<String> }` 他ロケールには在るがそのロケールに無いキー (FAIL 対象)
    - `:duplicates` — `{ locale => Array<String> }` そのファイル内で 2 回以上定義されたキー (FAIL 対象)
    - `:unused` — `Array<String>` どのコードからも参照されない定義済みキー (情報表示のみ、FAIL しない)

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_localization_check.rb` を以下の内容で作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in localization_check.rb.
# Run: ruby bin/test_localization_check.rb
require 'minitest/autorun'
require_relative 'localization_check'

class LocalizationCheckTest < Minitest::Test
  # --- code_keys ------------------------------------------------------------

  def test_code_keys_extracts_single_line_call
    swift = 'Text(NSLocalizedString("timer.title", comment: "Title"))'
    assert_equal ['timer.title'], LocalizationCheck.code_keys(swift)
  end

  # AboutSettingsSection.swift:36-39 はキーが次の行にある。行アンカーの
  # regex だとここを取りこぼし、キーを「未使用」と誤報告する。
  def test_code_keys_extracts_multiline_call
    swift = <<~SWIFT
      Text(NSLocalizedString(
          "settings.review_app_footer",
          comment: "Footer for review section"
      ))
    SWIFT
    assert_equal ['settings.review_app_footer'], LocalizationCheck.code_keys(swift)
  end

  def test_code_keys_finds_every_occurrence_in_order
    swift = <<~SWIFT
      NSLocalizedString("a", comment: "")
      NSLocalizedString("b", comment: "")
      NSLocalizedString("a", comment: "")
    SWIFT
    assert_equal %w[a b a], LocalizationCheck.code_keys(swift)
  end

  def test_code_keys_ignores_non_literal_argument
    swift = 'NSLocalizedString(someVariable, comment: "dynamic")'
    assert_empty LocalizationCheck.code_keys(swift)
  end

  # --- strings_keys ---------------------------------------------------------

  def test_strings_keys_parses_definitions
    strings = <<~STRINGS
      "timer.title" = "ポモドーロ";
      "settings.title" = "設定";
    STRINGS
    assert_equal ['timer.title', 'settings.title'], LocalizationCheck.strings_keys(strings)
  end

  def test_strings_keys_skips_block_and_line_comments
    strings = <<~STRINGS
      /*
         Localizable.strings
         "not.a.key" = "in a block comment";
      */

      // MARK: - Timer View
      "timer.title" = "ポモドーロ";
    STRINGS
    assert_equal ['timer.title'], LocalizationCheck.strings_keys(strings)
  end

  def test_strings_keys_keeps_repeats_so_duplicates_are_detectable
    strings = <<~STRINGS
      "time.10_minutes" = "10 min";
      "time.15_minutes" = "15 min";
      "time.10_minutes" = "10 min";
    STRINGS
    assert_equal ['time.10_minutes', 'time.15_minutes', 'time.10_minutes'],
                 LocalizationCheck.strings_keys(strings)
  end

  # --- duplicate_keys -------------------------------------------------------

  def test_duplicate_keys_finds_repeated_definition
    strings = <<~STRINGS
      "a" = "1";
      "b" = "2";
      "a" = "1";
    STRINGS
    assert_equal ['a'], LocalizationCheck.duplicate_keys(strings)
  end

  def test_duplicate_keys_empty_when_all_unique
    strings = "\"a\" = \"1\";\n\"b\" = \"2\";\n"
    assert_empty LocalizationCheck.duplicate_keys(strings)
  end

  # --- report: RED パス (壊れた入力で正しく検出できるか) --------------------

  def test_report_flags_key_missing_from_one_locale
    report = LocalizationCheck.report(
      %w[timer.title settings.title],
      'ja' => "\"timer.title\" = \"ポモドーロ\";\n\"settings.title\" = \"設定\";\n",
      'en' => "\"timer.title\" = \"Pomodoro\";\n"
    )
    assert_empty report[:missing]['ja']
    assert_equal ['settings.title'], report[:missing]['en']
  end

  def test_report_flags_parity_gap_even_for_key_unused_in_code
    report = LocalizationCheck.report(
      [],
      'ja' => "\"only.in.ja\" = \"あ\";\n",
      'en' => ''
    )
    assert_equal ['only.in.ja'], report[:parity]['en']
    assert_empty report[:parity]['ja']
  end

  def test_report_flags_duplicates_per_locale
    report = LocalizationCheck.report(
      ['a'],
      'ja' => "\"a\" = \"1\";\n\"a\" = \"1\";\n",
      'en' => "\"a\" = \"1\";\n"
    )
    assert_equal ['a'], report[:duplicates]['ja']
    assert_empty report[:duplicates]['en']
  end

  def test_report_lists_unused_key_as_information
    report = LocalizationCheck.report(
      [],
      'ja' => "\"dead.key\" = \"あ\";\n",
      'en' => "\"dead.key\" = \"a\";\n"
    )
    assert_equal ['dead.key'], report[:unused]
  end

  # --- report: GREEN パス ---------------------------------------------------

  def test_report_clean_when_code_and_locales_agree
    ja = "\"a\" = \"あ\";\n\"b\" = \"い\";\n"
    en = "\"a\" = \"a\";\n\"b\" = \"b\";\n"
    report = LocalizationCheck.report(%w[a b a], 'ja' => ja, 'en' => en)
    assert_empty report[:missing]['ja']
    assert_empty report[:missing]['en']
    assert_empty report[:parity]['ja']
    assert_empty report[:parity]['en']
    assert_empty report[:duplicates]['ja']
    assert_empty report[:duplicates]['en']
    assert_empty report[:unused]
  end
end
```

- [ ] **Step 2: テストを実行して落ちることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_localization_check.rb
```

Expected: `cannot load such file -- .../bin/localization_check` (LoadError)。まだ module が無いので 1 件も走らない。

- [ ] **Step 3: 最小実装を書く**

`app/bin/localization_check.rb` を以下の内容で作成:

```ruby
# frozen_string_literal: true

# Pure helpers for localization-check. Kept free of I/O so they can be
# unit-tested (see test_localization_check.rb). The CLI glue lives in
# bin/localization-check.rb.
module LocalizationCheck
  # NSLocalizedString("key", comment: ...) — the key may sit on a *following*
  # line (AboutSettingsSection.swift:36-39 does exactly that), so this pattern
  # deliberately spans newlines. A line-anchored grep silently misses those
  # calls and then reports a perfectly live key as "unused".
  CODE_KEY = /NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"/m.freeze

  # A key definition in a .strings file: "key" = "value";
  # Anchored at line start so that a `//` comment line (which never begins
  # with a quote) needs no special handling.
  STRINGS_KEY = /^\s*"((?:[^"\\]|\\.)*)"\s*=/.freeze

  BLOCK_COMMENT = %r{/\*.*?\*/}m.freeze

  # Every NSLocalizedString key literal, in source order, repeats included.
  def self.code_keys(swift_text)
    swift_text.scan(CODE_KEY).flatten
  end

  # Every key definition, in file order, repeats included — callers rely on
  # the repeats to detect duplicate definitions.
  def self.strings_keys(strings_text)
    strings_text.gsub(BLOCK_COMMENT, '')
                .each_line
                .filter_map { |line| line[STRINGS_KEY, 1] }
  end

  # Keys defined two or more times in one file. iOS keeps the last definition
  # and drops the earlier ones without a warning.
  def self.duplicate_keys(strings_text)
    strings_keys(strings_text).tally.select { |_key, count| count > 1 }.keys.sort
  end

  # Cross-check code keys against every locale's .strings text.
  #   locale_texts: { "ja" => <file text>, "en" => <file text> }
  def self.report(code_keys, locale_texts)
    used    = code_keys.uniq
    defined = locale_texts.transform_values { |text| strings_keys(text).uniq }
    union   = defined.values.flatten.uniq

    {
      missing: defined.transform_values { |keys| (used - keys).sort },
      parity: defined.transform_values { |keys| (union - keys).sort },
      duplicates: locale_texts.transform_values { |text| duplicate_keys(text) },
      unused: (union - used).sort
    }
  end
end
```

- [ ] **Step 4: テストが通ることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_localization_check.rb
```

Expected: `13 runs, ... 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/bin/localization_check.rb app/bin/test_localization_check.rb && \
git commit -m "test(i18n): #99 NSLocalizedString キー↔strings 突き合わせの純粋ロジックと minitest"
```

---

## Task 2: CLI + make ターゲット + RED パスの実証

**Files:**
- Create: `app/bin/localization-check.rb`
- Modify: `app/Makefile:57` (`tests` の依存に `localization-check` を追加) と末尾 (新ターゲット追加)

**Interfaces:**
- Consumes: Task 1 の `LocalizationCheck.code_keys` / `.report`
- Produces: `make localization-check` — 成功時に `✅ localization-check passed` を出力し exit 0、失敗時に `❌` 行を出力し exit 1

- [ ] **Step 1: CLI を書く**

`app/bin/localization-check.rb` を以下の内容で作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# localization-check: verify that every NSLocalizedString key used in the app
# source is defined in every locale's Localizable.strings, and that those
# files are internally consistent.
#
# Catches three silent failures (Issue #99, from PR #96 Rec#1):
#   1. A key typo, or a key added to only one locale. iOS falls back to
#      showing the raw key string, so this never crashes — it ships.
#   2. A key present in one locale but absent in another (parity), even if
#      no code references it yet.
#   3. A key defined twice in one file; the later definition silently wins.
#
# Usage:
#   ruby bin/localization-check.rb
#
# Exit code 0 = all checks passed; non-zero = at least one check failed.

require_relative 'localization_check'

PROJECT_DIR = File.expand_path('..', __dir__)            # app/
SOURCE_DIR  = File.join(PROJECT_DIR, 'LeafTimer')
LOCALES     = %w[ja en].freeze

def strings_path(locale)
  File.join(SOURCE_DIR, 'App', "#{locale}.lproj", 'Localizable.strings')
end

# --- gather inputs ----------------------------------------------------------

absent = LOCALES.reject { |locale| File.exist?(strings_path(locale)) }
unless absent.empty?
  warn "❌ localization-check failed: missing Localizable.strings for #{absent.join(', ')}"
  exit 1
end

swift_text   = Dir.glob(File.join(SOURCE_DIR, '**', '*.swift')).sort.map { |f| File.read(f) }.join("\n")
code_keys    = LocalizationCheck.code_keys(swift_text)
locale_texts = LOCALES.to_h { |locale| [locale, File.read(strings_path(locale))] }
report       = LocalizationCheck.report(code_keys, locale_texts)

# --- run checks -------------------------------------------------------------

failures = []

LOCALES.each do |locale|
  keys = report[:missing][locale]
  next if keys.empty?

  failures << "missing:#{locale}"
  puts "❌ #{locale}: #{keys.size} key(s) used in code but not defined:"
  keys.each { |key| puts "   - #{key}" }
end

LOCALES.each do |locale|
  keys = report[:parity][locale]
  next if keys.empty?

  failures << "parity:#{locale}"
  puts "❌ #{locale}: #{keys.size} key(s) defined in another locale but missing here:"
  keys.each { |key| puts "   - #{key}" }
end

LOCALES.each do |locale|
  keys = report[:duplicates][locale]
  next if keys.empty?

  failures << "duplicate:#{locale}"
  puts "❌ #{locale}: #{keys.size} key(s) defined more than once (the last one wins):"
  keys.each { |key| puts "   - #{key}" }
end

unless report[:unused].empty?
  puts "ℹ️  #{report[:unused].size} key(s) defined but never referenced by NSLocalizedString:"
  report[:unused].each { |key| puts "   - #{key}" }
end

# --- result -----------------------------------------------------------------

if failures.empty?
  puts "✅ localization-check passed (#{code_keys.uniq.size} keys × #{LOCALES.size} locales)"
  exit 0
else
  warn "❌ localization-check failed: #{failures.join(', ')}"
  exit 1
end
```

- [ ] **Step 2: 実リポジトリに対して走らせ、既知の重複 1 件で RED になることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/localization-check.rb; echo "exit=$?"
```

Expected (Task 3 で直すまではこの状態が正しい):

```
❌ en: 1 key(s) defined more than once (the last one wins):
   - time.10_minutes
❌ localization-check failed: duplicate:en
exit=1
```

**missing / parity / unused は 1 行も出ないこと**を確認する (現状の repo はその 3 観点では clean)。

- [ ] **Step 3: 意図的に壊した入力で missing / parity が RED になることを実証する**

checker 本体は FAIL パスなので、正常系が通るだけでは信用できない。実ファイルを一時的に壊して RED を確認し、必ず復元する:

バックアップの置き場所は**セッションの scratchpad**を使う (`/tmp` 直下は使わない — 権限プロンプトで背景実行が止まることがある):

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
cp LeafTimer/App/en.lproj/Localizable.strings "$SCRATCH/en_backup.strings" && \
grep -v '^"timer.title"' "$SCRATCH/en_backup.strings" > LeafTimer/App/en.lproj/Localizable.strings && \
ruby bin/localization-check.rb; echo "exit=$?"
```

Expected: `timer.title` が missing:en と parity:en の**両方**に現れ、`exit=1`。

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
cp "$SCRATCH/en_backup.strings" LeafTimer/App/en.lproj/Localizable.strings && \
git diff --stat LeafTimer/App/en.lproj/Localizable.strings
```

Expected: `git diff --stat` が**空** (完全に復元された)。空でなければ手動で `git checkout -- LeafTimer/App/en.lproj/Localizable.strings` する。

- [ ] **Step 4: Makefile にターゲットを追加する**

`app/Makefile:57` を変更:

```make
tests: precheck localization-check sort lint unit-tests
```

`app/Makefile` の末尾 (`gitignore-check` ブロックの後) に追加:

```make
localization-check:
	@echo "Running localization-check..."
	@ruby bin/test_localization_check.rb
	@ruby bin/localization-check.rb
```

- [ ] **Step 5: make ターゲットが動くことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make localization-check; echo "exit=$?"
```

Expected: minitest が `0 failures` で通った後、Task 3 未着手なので `❌ ... duplicate:en` で `exit=1`。

- [ ] **Step 6: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/bin/localization-check.rb app/Makefile && \
git commit -m "feat(i18n): #99 localization-check を make ターゲット化し make tests の依存に追加"
```

---

## Task 3: en.lproj の重複キーを解消して gate を GREEN にする

**Files:**
- Modify: `app/LeafTimer/App/en.lproj/Localizable.strings` (重複している 2 つ目の `"time.10_minutes"` 行を削除)

**Interfaces:**
- Consumes: Task 2 の `make localization-check`
- Produces: `make localization-check` が `✅ localization-check passed (80 keys × 2 locales)` で exit 0

- [ ] **Step 1: 重複の実体を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -n '"time.10_minutes"' LeafTimer/App/en.lproj/Localizable.strings
```

Expected: 2 行ヒットする (24 行目と 44 行目、値はどちらも `"10 min"`)。**値が同一であること**を目視確認する。もし値が違っていたら、後勝ちで実際に表示されているのは後ろの行の値なので、そちらを残す。

- [ ] **Step 2: 重複した 2 つ目の定義を削除する**

**行番号ではなく内容でアンカーすること** (ファイルは 2026-08-08 に編集されており、行番号は前後しうる)。判定基準:

- `// MARK: - Time Options` セクションの中にある `"time.10_minutes"` が**正**。これを残す。
- そのセクションの**外**にあるもう 1 つが重複挿入された方。**こちらを削除する。**
- 2 つとも同じセクション内にあった場合は、後ろに出てくる方を削除する。

Edit ツールで該当 1 行のみを削除する (`sed -i` は使わない — 意図しない行を消してもエラーにならず silent に壊れるため)。前後のコメント行や他のキーは触らない。

- [ ] **Step 3: 重複が解消したことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -c '"time.10_minutes"' LeafTimer/App/en.lproj/Localizable.strings
```

Expected: `1`

- [ ] **Step 4: checker が GREEN になることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make localization-check; echo "exit=$?"
```

Expected:

```
✅ localization-check passed (80 keys × 2 locales)
exit=0
```

`❌` が 1 件も出ないこと、かつ `✅ localization-check passed` が出ていることの**両方**で判定する。

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/App/en.lproj/Localizable.strings && \
git commit -m "fix(i18n): #99 en.lproj の time.10_minutes 重複定義を解消"
```

---

## Task 4: sentinel 抜け穴の横展開修正 (Stat / Onboarding)

**Files:**
- Modify: `app/LeafTimerTests/StatLocalizationTests.swift:8-15`
- Modify: `app/LeafTimerTests/OnboardingLocalizationTests.swift:7-14`

**Interfaces:**
- Consumes: なし (独立)
- Produces: なし (テストのみ)

**背景:** `SettingsLocalizationTests` は PR #96 の `4b9e73f` で修正済みだが、同じ helper をコピペした 2 ファイルに抜け穴が残っている。`.lproj` ディレクトリが丸ごと消えた時、helper は `"<<missing ja.lproj>>"` を返す。これは `value:` に渡している sentinel `"<<missing>>"` と**文字列として異なる**ため:

- `OnboardingLocalizationTests` の `XCTAssertNotEqual(localized(key), "<<missing>>")` が **8 キー全て通ってしまう** (最も純粋な抜け穴)
- `StatLocalizationTests` の `testNoFireEmojiInTopScreenStrings` は `XCTAssertFalse(...contains("🔥"))` なので、`"<<missing ja.lproj>>"` には 🔥 が無く**空振り PASS** する

修正は `SettingsLocalizationTests` と同形 — `XCTFail` を呼び、sentinel を `"<<missing>>"` に統一する。

- [ ] **Step 1: 抜け穴が実在することを実証する**

修正前に、抜け穴が本当に存在することを確認する。`localized` helper は 3 ファイルとも**クラス内の `private func`** で共有されていないため、`OnboardingLocalizationTests.swift` を細工しても影響はそのクラス内に閉じる (Stat / Settings のテストは巻き込まれない)。

`OnboardingLocalizationTests.swift` の helper の `guard` を一時的に必ず失敗させる:

```swift
        guard let path = appBundle.path(forResource: "\(locale)_NONEXISTENT", ofType: "lproj"),
```

この状態で実行し、**Onboarding の 2 テストが個別に PASS していること**を直接確認する (全体マーカーではなくテスト名で判定する):

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
make unit-tests > "$SCRATCH/sabotage_before.log" 2>&1; \
grep -E "OnboardingLocalizationTests.*(passed|failed)" "$SCRATCH/sabotage_before.log"
```

(Bash timeout は `600000` を指定)

Expected: `testOnboardingKeysExistInJapanese` と `testOnboardingKeysExistInEnglish` の 2 件がいずれも **`passed`** と出る。`.lproj` を一切解決できていないのにパスする — **これが抜け穴の実証**。

確認できたら `"\(locale)_NONEXISTENT"` を `locale` に戻す。

- [ ] **Step 2: 両ファイルの helper を修正する**

`app/LeafTimerTests/StatLocalizationTests.swift` の 8-15 行目を以下に置換:

```swift
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            XCTFail("\(locale).lproj が見つからない")
            return "<<missing>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }
```

`app/LeafTimerTests/OnboardingLocalizationTests.swift` の 7-14 行目を、上と**まったく同じ本文**に置換する (doc コメント行 `/// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。` は両ファイルとも残す)。

- [ ] **Step 3: 修正後、同じ細工で今度は RED になることを確認する**

再び `OnboardingLocalizationTests.swift` の `forResource:` を `"\(locale)_NONEXISTENT"` にして:

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
make unit-tests > "$SCRATCH/sabotage_after.log" 2>&1; \
grep -E "OnboardingLocalizationTests.*(passed|failed)" "$SCRATCH/sabotage_after.log"; \
grep -c "lproj が見つからない" "$SCRATCH/sabotage_after.log"
```

(Bash timeout は `600000`)

Expected: Step 1 で `passed` だった 2 件が今度は **`failed`** になり、`lproj が見つからない` の XCTFail メッセージが 1 件以上出る。**同じ細工が修正前は PASS・修正後は FAIL になることが修正の証明**。

確認できたら `"\(locale)_NONEXISTENT"` を `locale` に戻す。

- [ ] **Step 4: 通常状態でテストが通ることを確認**

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
make unit-tests > "$SCRATCH/unit_tests_clean.log" 2>&1; \
echo "SUCCEEDED (>=1): $(grep -c '\*\* TEST SUCCEEDED \*\*' "$SCRATCH/unit_tests_clean.log")"; \
echo "FAILED (=0): $(grep -c '\*\* TEST FAILED \*\*' "$SCRATCH/unit_tests_clean.log")"
```

(Bash timeout は `600000`)

Expected: `SUCCEEDED` が 1 以上、`FAILED` が 0。両方を満たして初めて GREEN と判断する。

- [ ] **Step 5: 細工が残っていないことを確認して commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git diff app/LeafTimerTests/ | grep -c "NONEXISTENT"
```

Expected: `0` (1 以上なら細工が残っている — 戻すこと)

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimerTests/StatLocalizationTests.swift app/LeafTimerTests/OnboardingLocalizationTests.swift && \
git commit -m "test(i18n): #99 Stat/Onboarding の localized helper に sentinel 抜け穴修正を横展開"
```

---

## Task 5: #98 — settings.footer.app_name を「意図的な未翻訳」として明記する

**Files:**
- Modify: `app/LeafTimer/App/ja.lproj/Localizable.strings` (`settings.footer.app_name` の行の直前にコメントを追加)

**Interfaces:**
- Consumes: なし
- Produces: なし

**方針 (ユーザー確定済み):** 翻訳せず現状維持し、ブランドコピーとして意図的に未翻訳である旨をコメントで残す。将来「翻訳漏れ」として再度 issue 化されるのを防ぐのが目的。

- [ ] **Step 1: 該当行の位置を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -n "settings.footer" LeafTimer/App/ja.lproj/Localizable.strings
```

Expected: `settings.footer.app_name` と `settings.footer.copyright` の 2 行が見つかる。

- [ ] **Step 2: コメントを追加する**

`settings.footer.app_name` の行の**直前**に、以下の 2 行を挿入する (Edit ツールを使用):

```
// アプリ名 + タグラインはブランド表記として意図的に未翻訳のまま英語を維持する (Issue #98)。
// 翻訳漏れではないので、i18n の棚卸しで日本語化しないこと。
```

値そのもの (`"LeafTimer - Focus & Productivity"`) は**変更しない**。

- [ ] **Step 3: 値が変わっていないことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git diff app/LeafTimer/App/ja.lproj/Localizable.strings
```

Expected: 追加行 (`+`) が**コメント 2 行のみ**で、`"settings.footer.app_name" = ...` の行が削除・変更されていないこと。

- [ ] **Step 4: checker がコメント追加で壊れていないことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make localization-check; echo "exit=$?"
```

Expected: `✅ localization-check passed (80 keys × 2 locales)` / `exit=0`。`//` コメント行がキーとして誤検出されないことの実地確認も兼ねる。

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/App/ja.lproj/Localizable.strings && \
git commit -m "docs(i18n): #98 settings.footer.app_name を意図的な未翻訳ブランドコピーとして明記"
```

---

## Task 6: 総合検証と PR 作成

**Files:** なし (検証のみ)

- [ ] **Step 1: `make tests` フルパスを通す**

ログは全量を scratchpad に残し、判定はその全量ログに対して行う (`tail` の結果で判定しない — 成功マーカーが切り落とされる):

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
make tests > "$SCRATCH/make_tests.log" 2>&1; \
tail -30 "$SCRATCH/make_tests.log"
```

(Bash timeout は `600000`)

判定は全量ログのマーカーで行う。**回数の一致ではなく「成功マーカーが 1 件以上」かつ「失敗マーカーが 0 件」の両方**で判定する (実行回数によって成功マーカーは複数出うるため、`= 1` を条件にすると誤 RED になる):

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/5f1f1590-dcda-40a4-98fe-347b139f665a/scratchpad && \
echo "precheck OK (>=1): $(grep -c '✅ xcode-precheck passed' "$SCRATCH/make_tests.log")" && \
echo "l10n OK (>=1): $(grep -c '✅ localization-check passed' "$SCRATCH/make_tests.log")" && \
echo "TEST SUCCEEDED (>=1): $(grep -c '\*\* TEST SUCCEEDED \*\*' "$SCRATCH/make_tests.log")" && \
echo "TEST FAILED (=0): $(grep -c '\*\* TEST FAILED \*\*' "$SCRATCH/make_tests.log")" && \
echo "No rule to make target (=0): $(grep -c 'No rule to make target' "$SCRATCH/make_tests.log")" && \
echo "l10n failure lines (=0): $(grep -c '❌ localization-check failed' "$SCRATCH/make_tests.log")"
```

Expected: 先頭 3 つが **1 以上**、後ろ 3 つが **0**。いずれかが外れたら全量ログを読んで原因を特定する (空出力は「成功」ではなく「コマンドが走っていない」を疑う)。

- [ ] **Step 2: 作業ツリーがクリーンなことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git status --short
```

Expected: 空 (`build/` や `/tmp` の一時ファイルが repo に紛れ込んでいないこと)。何か出たら内容を確認して対処する。

- [ ] **Step 3: 既存 PR の有無を確認して push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch && gh pr list --state all --head chore/99-98-localization-followup
```

Expected: 空 (既存 PR 無し)。空であれば push する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git push -u origin chore/99-98-localization-followup
```

- [ ] **Step 4: PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create --base master --title "chore(i18n): #99/#98 ローカライズ検証の make ターゲット化と sentinel 抜け穴修正" --body "$(cat <<'EOF'
## 概要

PR #96 の final review で後送とした follow-up 2 件 (Issue #99 / #98) をまとめて対応した。

### Issue #99-1: キー↔strings 突き合わせの恒久化

PR #96 で手動 grep していた検証を `make localization-check` として恒久化し、`make tests` の依存に追加した。既存の `xcode-precheck` / `gitignore-doctor` と同じ 3 層構成 (純粋ロジック module + CLI + minitest)。

検出する 3 つの silent failure:

1. **missing** — コードで使っているキーがそのロケールに無い (iOS はキー文字列をそのまま表示するのでクラッシュせず出荷される)
2. **parity** — 片方のロケールにしか定義が無いキー
3. **duplicate** — 同一ファイル内の二重定義 (後勝ちで前の定義が黙って消える)

未使用キーは `ℹ️` の情報表示のみで fail させない。

**実際に 1 件検出した**: `en.lproj` の `"time.10_minutes"` が 24 行目と 44 行目で二重定義されていた (値は同一なので実害は無かったが、本 PR で解消)。

**実装上の落とし穴**: `AboutSettingsSection.swift:36-39` の `NSLocalizedString(` はキーが次の行にある。行アンカーの regex で走査すると取りこぼし、`settings.review_app_footer` を「未使用」と誤報告する。checker は改行をまたいでキーを拾うようにし、この挙動を回帰テストで固定した。

### Issue #99-2: sentinel 抜け穴の横展開

`.lproj` が丸ごと欠落した時に helper が `"<<missing \(locale).lproj>>"` を返し、sentinel `"<<missing>>"` と一致しないため誤 PASS する抜け穴を `StatLocalizationTests` / `OnboardingLocalizationTests` にも横展開修正した (`SettingsLocalizationTests` は PR #96 の 4b9e73f で対応済み)。

特に `OnboardingLocalizationTests` は `XCTAssertNotEqual(..., "<<missing>>")` のみなので、**8 キー全てが空振り PASS** する状態だった。

### Issue #98: タグラインの翻訳判断

`settings.footer.app_name` = "LeafTimer - Focus & Productivity" は**ブランドコピーとして意図的に未翻訳**という方針を確定し、`ja.lproj` にコメントで明記した。将来 i18n の棚卸しで「翻訳漏れ」として再着手されるのを防ぐ。

## 検証

- `make localization-check` — `✅ localization-check passed (80 keys × 2 locales)`
- 意図的に `en.lproj` からキーを 1 件削って RED になることを実証 (checker の FAIL パスを確認済み)
- `OnboardingLocalizationTests` の helper を細工して、修正前は誤 PASS・修正後は `XCTFail` で RED になることを実証
- `make tests` フルパス — `** TEST SUCCEEDED **`

Closes #99
Closes #98

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_018dV4PcHrN9gAa9UDx5QjZ5
EOF
)"
```

- [ ] **Step 5: CI 完了を待って結果を確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
PR=$(gh pr view --json number --jq .number) && \
until gh pr checks "$PR" --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done; \
gh pr checks "$PR"
```

(`gh pr checks --watch` は GraphQL timeout で落ちる実績があるためポーリングを使う。Bash timeout は `600000`)

Expected: 全チェックが pass。fail があれば内容を読んで対処する。

---

## Self-Review 結果

**1. Spec coverage**

| Issue の要求 | 対応 Task |
| --- | --- |
| #99-1 キー↔strings 突き合わせを `app/bin/` スクリプト + make ターゲットに昇格 | Task 1 (ロジック) / Task 2 (CLI + Makefile) |
| #99-1 `make tests` の依存に入れる | Task 2 Step 4 |
| #99-2 `StatLocalizationTests` の抜け穴確認・修正 | Task 4 |
| #99-2 `OnboardingLocalizationTests` の抜け穴確認・修正 | Task 4 |
| #98 タグラインの翻訳判断 (現状維持 + コメント明記) | Task 5 |

**2. Placeholder scan** — 「TBD」「適切にエラー処理」等の曖昧表現なし。全コードブロックが実内容。

**3. Type consistency** — Task 1 が produce する `report` の 4 キー (`:missing` / `:parity` / `:duplicates` / `:unused`) を Task 2 の CLI が同名で consume している。`code_keys` / `strings_keys` / `duplicate_keys` / `report` のシグネチャは Task 1 の Interfaces ブロックと実装・テストで一致。

**4. 追加した安全策** — checker 系タスクなので Task 2 Step 3 に「実ファイルを壊して RED を確認 → 復元を `git diff --stat` で検証」を、Task 4 Step 1/3 に「細工して修正前後の挙動差を実証 → 細工の残存を `grep -c NONEXISTENT` で検証」を入れた。どちらも CLAUDE.md の「checker の本体は FAIL パス」「vacuously green を疑う」教訓に対応。
