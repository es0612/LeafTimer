# gitignore-doctor Implementation Plan (Issue #11)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `.gitignore` の意図（keep/ignore したいパス）と git の実挙動のズレを `make gitignore-check` で機械検出し、#9（アンカー漏れ）/ #31（whitelist 漏れ）型の事故を再発防止する。

**Architecture:** 既存 `xcode-precheck` と同じ 2 層 + テスト構造。純粋関数モジュール `gitignore_doctor.rb`（I/O なし・minitest 対象）と、リポジトリルートで `git check-ignore --no-index -v` を path ごとに叩く実行スクリプト `gitignore-doctor.rb` に分離。判定は exit code を使わず、出力の last-rule が `!`（negation）で始まるかでパースする。

**Tech Stack:** Ruby（標準ライブラリ + minitest のみ・gem 不要）、git `check-ignore --no-index -v`、GNU/BSD make。

---

## 前提（着手前に必読）

- ブランチ `feature/11-gitignore-doctor` は作成済み、設計（`docs/superpowers/specs/2026-06-01-gitignore-doctor-design.md`）はコミット済み。
- スクリプトは `app/` ディレクトリではなく **リポジトリルート**で `git` を実行する必要がある
  （`check-ignore` の path 引数を repo ルート相対で扱うため）。実行スクリプトが repo ルートを
  特定して `Dir.chdir` する（後述 Task 4）。
- minitest は Ruby 同梱（`require 'minitest/autorun'`）。`test_xcode_precheck.rb` と同じ。
- `gitignore_doctor.rb`（アンダースコア）= 純粋ロジック、`gitignore-doctor.rb`（ハイフン）= 実行。
- このプロジェクトの shell は **zsh**。`${PIPESTATUS[0]}` は使わない（空を返す）。テスト成否は
  minitest の出力末尾（`0 failures, 0 errors` / `Failure`）と終了コードで判定する。

## File Structure

| ファイル | 責務 |
|---|---|
| `app/bin/gitignore_doctor.rb` | 純粋関数モジュール `GitignoreDoctor`: `parse_expectations`, `ignored?`, `evaluate` |
| `app/bin/test_gitignore_doctor.rb` | 上記の minitest ユニットテスト |
| `app/bin/gitignore-doctor.rb` | 実行: fixture 読込 → repo ルートで `git check-ignore` → `evaluate` → 表示・exit |
| `app/bin/gitignore-doctor-expectations.txt` | 期待 fixture（`keep:` / `ignore:` 行） |
| `app/Makefile` | `gitignore-check` ターゲット追加（既存ファイルの末尾に追記） |

---

## Task 1: 純粋関数 `parse_expectations`

fixture テキストを `[{kind:, path:}]` にパースする。`#` コメント・空行スキップ、`keep:` / `ignore:` 行を分類し、path の先頭 `./`・末尾 `/` を吸収する。

**Files:**
- Create: `app/bin/gitignore_doctor.rb`
- Test: `app/bin/test_gitignore_doctor.rb`

- [ ] **Step 1: Write the failing test**

`app/bin/test_gitignore_doctor.rb` を新規作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in gitignore_doctor.rb.
# Run: ruby bin/test_gitignore_doctor.rb
require 'minitest/autorun'
require_relative 'gitignore_doctor'

class GitignoreDoctorTest < Minitest::Test
  # --- parse_expectations ---------------------------------------------------

  def test_parse_expectations_classifies_keep_and_ignore
    text = <<~TXT
      # comment line
      keep:   app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved

      ignore: app/Pods
    TXT
    result = GitignoreDoctor.parse_expectations(text)
    assert_equal(
      [
        { kind: :keep,   path: 'app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved' },
        { kind: :ignore, path: 'app/Pods' }
      ],
      result
    )
  end

  def test_parse_expectations_strips_leading_dot_but_keeps_trailing_slash
    # 先頭 './' は吸収。末尾 '/' は dir 意図として保持し check-ignore にそのまま渡す
    # (不在ディレクトリを安定 match させるため。設計の「dir パターン × 不在」の罠対策)
    text = "ignore: ./plans/\nkeep: docs/superpowers/plans/\nkeep: a/File.txt\n"
    result = GitignoreDoctor.parse_expectations(text)
    assert_equal(
      [
        { kind: :ignore, path: 'plans/' },
        { kind: :keep,   path: 'docs/superpowers/plans/' },
        { kind: :keep,   path: 'a/File.txt' }
      ],
      result
    )
  end

  def test_parse_expectations_skips_blank_and_comment_lines
    text = "\n# only comments\n   \n"
    assert_equal [], GitignoreDoctor.parse_expectations(text)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: FAIL — `cannot load such file -- .../gitignore_doctor` (モジュール未作成) または `NoMethodError`。

- [ ] **Step 3: Write minimal implementation**

`app/bin/gitignore_doctor.rb` を新規作成:

```ruby
# frozen_string_literal: true

# Pure helpers for gitignore-doctor. Kept free of I/O so they can be unit-tested
# (see test_gitignore_doctor.rb). The CLI glue lives in bin/gitignore-doctor.rb.
#
# Oracle: `git check-ignore --no-index -v -- <path>` OUTPUT (not exit code).
# See docs/superpowers/specs/2026-06-01-gitignore-doctor-design.md and MEMORY
# feedback-gitignore-check-ignore-semantics for why exit code is unusable.
module GitignoreDoctor
  EXPECTATION_LINE = /\A(keep|ignore):\s*(.+)\z/.freeze

  # Parse the expectations fixture text into [{kind: :keep|:ignore, path: String}].
  # Skips blank lines and lines starting with '#'. Normalizes a leading './' and a
  # trailing '/' so the same path written either way compares equal.
  def self.parse_expectations(text)
    text.each_line.filter_map do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.start_with?('#')

      m = stripped.match(EXPECTATION_LINE)
      next unless m

      { kind: m[1].to_sym, path: normalize_path(m[2].strip) }
    end
  end

  # Normalize a repo-relative path: drop a leading './'. A trailing '/' is KEPT
  # on purpose — it signals directory intent, which git check-ignore needs to
  # match a directory-only pattern (e.g. "Pods/") when the path is absent on disk
  # (fresh clone / before `make install`). Stripping it would cause an
  # environment-dependent false "NOT ignored". See the design doc's trap section.
  def self.normalize_path(path)
    path.sub(%r{\A\./}, '')
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: PASS — `3 runs, ... 0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add app/bin/gitignore_doctor.rb app/bin/test_gitignore_doctor.rb
git commit -m "feat(gitignore-doctor): #11 parse_expectations 純粋関数 + テスト"
```

---

## Task 2: 純粋関数 `ignored?`

`git check-ignore --no-index -v -- <path>` の生出力（0 or 1 行）を受け取り、ignore されているかを返す。exit code は使わない。TAB 先割り → 行頭 `source:line:` を strip してパターンを取り、`!` 始まりなら NOT ignored。

**Files:**
- Modify: `app/bin/gitignore_doctor.rb`
- Test: `app/bin/test_gitignore_doctor.rb`

- [ ] **Step 1: Write the failing test**

`test_gitignore_doctor.rb` の `parse_expectations` テスト群の下（クラス内）に追記:

```ruby
  # --- ignored? -------------------------------------------------------------

  def test_ignored_false_for_empty_output
    refute GitignoreDoctor.ignored?('')
  end

  def test_ignored_false_when_last_rule_is_negation
    # whitelist が効いている: マッチ行のパターンが '!' で始まる
    out = ".gitignore:6:!ws/xcshareddata/swiftpm/Package.resolved\tws/xcshareddata/swiftpm/Package.resolved"
    refute GitignoreDoctor.ignored?(out)
  end

  def test_ignored_true_for_normal_rule
    # 通常ルールがマッチ = ignore されている
    out = ".gitignore:1:ws/\tws/xcshareddata/swiftpm/Package.resolved"
    assert GitignoreDoctor.ignored?(out)
  end

  def test_ignored_handles_pattern_containing_colon
    # パターン自体に ':' を含んでも TAB 先割りで壊れない (脆い末尾マッチ回帰防止)
    out = ".gitignore:3:foo:bar\tpath/foo:bar"
    assert GitignoreDoctor.ignored?(out)
  end

  def test_ignored_trailing_newline_tolerated
    out = ".gitignore:1:plans\tdocs/superpowers/plans\n"
    assert GitignoreDoctor.ignored?(out)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: FAIL — `NoMethodError: undefined method 'ignored?' for GitignoreDoctor`.

- [ ] **Step 3: Write minimal implementation**

`gitignore_doctor.rb` の `module GitignoreDoctor` 内、`normalize_path` の下に追記:

```ruby
  # Decide whether a path is ignored, from the OUTPUT of
  # `git check-ignore --no-index -v -- <path>`. The output is 0 or 1 line:
  #   "<source>:<line>:<pattern>\t<path>"
  # We never use the exit code (it returns 0 even for a '!' negation).
  #   - empty output            -> not ignored (no rule matched)
  #   - matched pattern is '!…'  -> not ignored (effective whitelist)
  #   - any other matched rule   -> ignored
  # Split on TAB first, then strip the leading "source:line:" so a pattern that
  # itself contains ':' is parsed correctly.
  def self.ignored?(check_ignore_output)
    line = check_ignore_output.to_s.strip
    return false if line.empty?

    meta = line.split("\t", 2).first        # "<source>:<line>:<pattern>"
    pattern = meta.sub(/\A[^:]*:\d+:/, '')   # strip "source:line:"
    !pattern.start_with?('!')
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: PASS — `8 runs, ... 0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add app/bin/gitignore_doctor.rb app/bin/test_gitignore_doctor.rb
git commit -m "feat(gitignore-doctor): #11 ignored? 出力パース (negation aware・exit code 不使用)"
```

---

## Task 3: 純粋関数 `evaluate`

期待リストと「path → check-ignore 出力」の Hash を受け取り、違反リストを返す。keep が ignored なら違反（#31）、ignore が NOT ignored なら違反（#9）。

**Files:**
- Modify: `app/bin/gitignore_doctor.rb`
- Test: `app/bin/test_gitignore_doctor.rb`

- [ ] **Step 1: Write the failing test**

`test_gitignore_doctor.rb` のクラス内に追記:

```ruby
  # --- evaluate -------------------------------------------------------------

  def test_evaluate_flags_keep_that_is_ignored
    # #31 シナリオ: keep したい Package.resolved が ignore されている
    expectations = [{ kind: :keep, path: 'ws/swiftpm/Package.resolved' }]
    results = { 'ws/swiftpm/Package.resolved' => ".gitignore:1:ws/\tws/swiftpm/Package.resolved" }
    violations = GitignoreDoctor.evaluate(expectations, results)
    assert_equal 1, violations.size
    assert_equal :keep, violations.first[:kind]
    assert_equal 'ws/swiftpm/Package.resolved', violations.first[:path]
  end

  def test_evaluate_flags_ignore_that_is_not_ignored
    # #9 シナリオ: ignore したい plans が ignore されていない (アンカー修正後に取りこぼし)
    expectations = [{ kind: :ignore, path: 'plans' }]
    results = { 'plans' => '' } # no rule matched
    violations = GitignoreDoctor.evaluate(expectations, results)
    assert_equal 1, violations.size
    assert_equal :ignore, violations.first[:kind]
  end

  def test_evaluate_no_violations_when_all_expectations_met
    expectations = [
      { kind: :keep,   path: 'docs/plans' },
      { kind: :ignore, path: 'plans' }
    ]
    results = {
      'docs/plans' => '',                                  # keep: not ignored -> OK
      'plans'      => ".gitignore:1:plans\tplans"          # ignore: ignored  -> OK
    }
    assert_empty GitignoreDoctor.evaluate(expectations, results)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: FAIL — `NoMethodError: undefined method 'evaluate'`.

- [ ] **Step 3: Write minimal implementation**

`gitignore_doctor.rb` の `ignored?` の下に追記:

```ruby
  # Compare expectations against per-path `git check-ignore` outputs.
  # `results` maps a path String to the raw check-ignore output String.
  # Returns a list of violations: [{path:, kind:, message:}].
  #   keep   + ignored      -> violation (#31: a must-keep path is ignored)
  #   ignore + not ignored  -> violation (#9: a must-ignore path leaks through)
  def self.evaluate(expectations, results)
    expectations.filter_map do |exp|
      output = results.fetch(exp[:path], '')
      is_ignored = ignored?(output)

      case exp[:kind]
      when :keep
        next unless is_ignored

        { path: exp[:path], kind: :keep,
          message: "expected to be committable but is IGNORED by .gitignore" }
      when :ignore
        next if is_ignored

        { path: exp[:path], kind: :ignore,
          message: "expected to be ignored but is NOT ignored by .gitignore" }
      end
    end
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: PASS — `11 runs, ... 0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add app/bin/gitignore_doctor.rb app/bin/test_gitignore_doctor.rb
git commit -m "feat(gitignore-doctor): #11 evaluate (keep/ignore 両方向の違反検出)"
```

---

## Task 4: 実行スクリプト `gitignore-doctor.rb`

fixture を読み、repo ルートで各 path に `git check-ignore --no-index -v` を実行、`evaluate` で違反を集めて表示・exit code を返す。

**Files:**
- Create: `app/bin/gitignore-doctor.rb`

- [ ] **Step 1: Write the execution script**

`app/bin/gitignore-doctor.rb` を新規作成:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# gitignore-doctor: verify that .gitignore behaves as intended.
#
# Reads bin/gitignore-doctor-expectations.txt (keep:/ignore: lines), then for
# each path runs `git check-ignore --no-index -v -- <path>` AT THE REPO ROOT and
# decides ignored/not via the matched rule (never the exit code). Reports any
# mismatch and exits non-zero. See the design doc + MEMORY for the rationale.
#
# Usage:
#   ruby bin/gitignore-doctor.rb     # run checks, non-zero exit on violation
#
# Exit code 0 = all expectations met (or fixture absent/empty); 1 = violation
# or a git failure.

require 'open3'
require_relative 'gitignore_doctor'

SCRIPT_DIR    = __dir__                                   # app/bin
FIXTURE_FILE  = File.join(SCRIPT_DIR, 'gitignore-doctor-expectations.txt')

# Resolve the repository top level so check-ignore path args are root-relative.
def repo_root
  root, status = Open3.capture2('git', 'rev-parse', '--show-toplevel')
  raise 'not inside a git repository' unless status.success?

  root.strip
end

# Run `git check-ignore --no-index -v -- <path>` at the repo root, return its
# stdout (0 or 1 line). check-ignore exits 1 when nothing matches; that is a
# normal "not ignored" result, NOT an error, so we don't treat exit on it.
def check_ignore_output(root, path)
  out, _err, _status = Open3.capture3(
    'git', '-C', root, 'check-ignore', '--no-index', '-v', '--', path
  )
  out
end

# --- run --------------------------------------------------------------------

unless File.exist?(FIXTURE_FILE)
  puts "⚠️  gitignore-doctor: no expectations file (#{File.basename(FIXTURE_FILE)}); skipped"
  exit 0
end

expectations = GitignoreDoctor.parse_expectations(File.read(FIXTURE_FILE))

if expectations.empty?
  puts '✅ gitignore-doctor: no expectations declared (nothing to check)'
  exit 0
end

begin
  root = repo_root
rescue RuntimeError => e
  warn "❌ gitignore-doctor: #{e.message}"
  exit 1
end

results = expectations.each_with_object({}) do |exp, acc|
  acc[exp[:path]] = check_ignore_output(root, exp[:path])
end

violations = GitignoreDoctor.evaluate(expectations, results)

if violations.empty?
  puts "✅ gitignore-doctor: #{expectations.size} expectation(s) satisfied"
  exit 0
else
  warn "❌ gitignore-doctor: #{violations.size} violation(s):"
  violations.each do |v|
    warn "   - [#{v[:kind]}] #{v[:path]}: #{v[:message]}"
  end
  warn '   → fix the .gitignore rule or update bin/gitignore-doctor-expectations.txt'
  exit 1
end
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x app/bin/gitignore-doctor.rb`
Expected: no output, exit 0.

- [ ] **Step 3: Commit (実行確認は Task 5 の fixture 投入後)**

```bash
git add app/bin/gitignore-doctor.rb
git commit -m "feat(gitignore-doctor): #11 実行スクリプト (repo ルートで check-ignore)"
```

---

## Task 5: 初期 fixture + 実行確認（green）

リポジトリの既知の意図を fixture に書き、実際に `make` 経由ではなく直接実行して green を確認する。

**Files:**
- Create: `app/bin/gitignore-doctor-expectations.txt`

- [ ] **Step 1: Write the fixture**

`app/bin/gitignore-doctor-expectations.txt` を新規作成:

```text
# gitignore-doctor expectations — declares intended keep/ignore paths.
# Verified by `make gitignore-check` (bin/gitignore-doctor.rb).
#
# `keep:`   = must be committable (NOT ignored). Catches #31-type accidents
#             (a needed file swallowed by a broad wildcard).
# `ignore:` = must be ignored. Catches #9-type anchor-leak accidents
#             (an unanchored pattern matching at any depth).
#
# Paths are REPO-ROOT-relative (no leading slash). DIRECTORY-intent paths MUST
# end with a trailing slash (e.g. "app/Pods/") so check-ignore matches a
# directory-only pattern even when the path is absent on disk (fresh clone /
# before `make install`). FILE-intent paths have no trailing slash.
# Lines starting with '#' and blank lines are skipped.

# --- #31: Package.resolved must survive the *.xcworkspace ignore ladder (FILE) ---
keep:   app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved

# --- #9: plan docs must NOT be swallowed by an unanchored 'plans' (DIR) ---
keep:   docs/superpowers/plans/

# --- paths that genuinely must stay ignored (DIRs → trailing slash) ---
ignore: app/Pods/
ignore: plans/
```

- [ ] **Step 2: Run the doctor directly and verify green**

Run: `cd app && ruby bin/gitignore-doctor.rb`
Expected: `✅ gitignore-doctor: 4 expectation(s) satisfied`, exit 0.

確認: `echo $?` が `0`。

- [ ] **Step 3: Sanity-check the RED path (一時的に fixture を壊す)**

`keep:` 宣言が IGNORED なら RED になることを一時確認する。
fixture を一時編集して、確実に ignore される `app/Pods/` を `keep:` にしてみる:

Run:
```bash
cd app
cp bin/gitignore-doctor-expectations.txt /tmp/expect-orig.txt
ruby -e 'puts File.read("bin/gitignore-doctor-expectations.txt").sub("ignore: app/Pods/","keep: app/Pods/")' > bin/gitignore-doctor-expectations.txt
ruby bin/gitignore-doctor.rb; echo "exit=$?"
cp /tmp/expect-orig.txt bin/gitignore-doctor-expectations.txt
```
Expected: `❌ gitignore-doctor: 1 violation(s):` と `[keep] app/Pods/: ...IGNORED...`、`exit=1`。
その後 fixture が元に戻っていること（`git diff --stat app/bin/gitignore-doctor-expectations.txt` が空）を確認。

- [ ] **Step 3b: Sanity-check the directory-absent scenario (環境依存 false-RED 回帰防止)**

設計の核心バグ（dir パターンを不在パスにスラッシュ無しで問うと false "NOT ignored"）が
末尾スラッシュ方式で解消されていることを scratch repo で確認する:

Run:
```bash
TMP=$(mktemp -d); cd "$TMP"; git init -q; printf 'Pods/\n' > .gitignore
git -C "$TMP" check-ignore --no-index -v -- Pods;  echo "noslash/absent exit=$?"   # 期待: 出力なし・exit 1
git -C "$TMP" check-ignore --no-index -v -- Pods/; echo "slash/absent exit=$?"     # 期待: ".gitignore:1:Pods/<TAB>Pods/" ・exit 0
rm -rf "$TMP"
```
Expected: スラッシュ無しは出力なし（不在で no-match）、**スラッシュ付きは matched**。
これが fixture で `ignore: app/Pods/` と書く根拠（不在環境でも安定 ignored 判定）。

- [ ] **Step 4: Commit**

```bash
git add app/bin/gitignore-doctor-expectations.txt
git commit -m "feat(gitignore-doctor): #11 初期 expectations fixture (#9/#31 の意図を明記)"
```

---

## Task 6: Makefile に `gitignore-check` ターゲット追加

**Files:**
- Modify: `app/Makefile`（末尾に追記。`make tests` には**入れない**）

- [ ] **Step 1: Add the target**

`app/Makefile` の末尾（`beta:` ブロックの後）に追記:

```makefile

gitignore-check:
	@echo "Running gitignore-doctor..."
	@ruby bin/gitignore-doctor.rb
```

- [ ] **Step 2: Run via make and verify green**

Run: `cd app && make gitignore-check`
Expected:
```
Running gitignore-doctor...
✅ gitignore-doctor: 4 expectation(s) satisfied
```
exit 0（`echo $?` が `0`）。

- [ ] **Step 3: Commit**

```bash
git add app/Makefile
git commit -m "feat(gitignore-doctor): #11 make gitignore-check ターゲット追加"
```

---

## Task 7: 仕上げ（README 追記 + 最終確認）

**Files:**
- Modify: `app/bin/` に既存 README があれば追記。無ければスキップ（新規 README は作らない=YAGNI）。

- [ ] **Step 1: bin/ の既存ドキュメント有無を確認**

Run: `ls app/bin/*.md 2>/dev/null; grep -rl "xcode-precheck" app/*.md docs/*.md 2>/dev/null | head`
- 既存の bin ツール一覧ドキュメントがあれば `gitignore-check` を 1 行追記。
- 無ければ何もしない（このタスクはスキップ）。

- [ ] **Step 2: 全テスト + lint 最終確認**

Run: `cd app && ruby bin/test_gitignore_doctor.rb`
Expected: `11 runs, ... 0 failures, 0 errors`.

Run: `cd app && make gitignore-check`
Expected: `✅ gitignore-doctor: 4 expectation(s) satisfied`.

- [ ] **Step 3: 新規 Ruby スクリプトに Rubocop 等の lint があるか確認**

Run: `ls app/.rubocop.yml 2>/dev/null && echo "rubocop config exists" || echo "no rubocop"`
- あれば `rubocop bin/gitignore_doctor.rb bin/gitignore-doctor.rb` を実行し違反を修正。
- 無ければスキップ（SwiftLint は Swift 専用なので Ruby には無関係）。

- [ ] **Step 4: PR 前のセルフチェック**

Run: `git log --oneline master..HEAD`
Expected: spec 2 commit + 実装 5〜6 commit が並ぶ。

Run: `git status --short`
Expected: クリーン（追跡漏れファイルなし）。

> 注: 新規ファイルは Xcode project に追加しない（`app/bin/` 配下は project.pbxproj 管理外の
> リポジトリスクリプト）。よって `make sort` / `make precheck` の pbxproj 影響は無い。

---

## Self-Review（plan 作成者によるチェック）

- **Spec coverage**:
  - オラクル（check-ignore --no-index -v 出力パース）→ Task 2 ✅
  - keep/ignore 両方向の判定 → Task 3 ✅
  - fixture 宣言形式 + repo ルート相対 → Task 1（正規化）+ Task 5 ✅
  - dir パターン × 不在パスの罠（末尾スラッシュ保持で安定 match）→ Task 1（末尾 `/` 保持）
    + Task 5 Step 3b（不在 dir の RED 確認）✅
  - repo ルートで git 実行 → Task 4（`git -C root` + `rev-parse --show-toplevel`）✅
  - `make gitignore-check` 独立ターゲット・tests に入れない → Task 6 ✅
  - fixture 不在/空で exit 0 → Task 4 実装 ✅
  - keep 物理ファイル無しは判定に影響しない（`--no-index`）→ Task 4 が物理存在チェックを
    含まないことで担保 ✅
- **Placeholder scan**: コードは全タスクで完全。Task 7 の README/rubocop は「あれば追記/なければ
  スキップ」と条件を明示（プレースホルダではなく分岐指示）。
- **Type consistency**: `parse_expectations` → `[{kind:, path:}]`、`ignored?(String)→Bool`、
  `evaluate(expectations, results:Hash)→[{path:,kind:,message:}]`。Task 3 のテストと Task 4 の
  実行スクリプトで同じ shape を使用。違反 Hash のキー（`:path` `:kind` `:message`）も一致。
