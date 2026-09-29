# #171 CLAUDE.md サイズ上限 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** repo 直下の `CLAUDE.md` を 18,000B 以下に圧縮し、`make tests` 内の `claude-md-size-check` で再肥大を止める。

**Architecture:** checker は既存 checker と同じ 2 層 (純粋ロジック `claude_md_size_check.rb` + CLI `claude-md-size-check.rb` + minitest)。圧縮は (a) Simulator 検証 5 ルールと Xcode 構成・依存 5 ルールをプロジェクト skill 2 本へ移してポインタ行化、(b) 残るルールの経緯を `docs/claude-lessons-archive.md` へ退避。

**Tech Stack:** Ruby (app/.ruby-version = 3.4.4、Apple 同梱外 gem 不使用)、minitest、make、Claude Code project skills (`.claude/skills/<name>/SKILL.md`)

**Spec:** `docs/superpowers/specs/2026-09-29-issue-171-claude-md-size-limit.md`

## Global Constraints

- 上限は UTF-8 バイト数で `18_000`。ちょうど 18,000B は ok
- ルール番号は振り直さない。移したルールも番号付きのポインタ行として残す
- 情報は消さず移すだけ (CLAUDE.md / skill / archive のどこかに残す)
- ビルド/テスト系コマンドは `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置し、成否は出力マーカーで判定 (ルール 1)
- plan/spec は最終タスクで `archive/` へ `git mv` してから `gh pr create` (ルール 44)。PR merge は plan に含めない (ルール 22)

## Review Focus

- 日本語だけの CLAUDE.md: 文字数ではなくバイト数で判定されること → Task 1 `test_cli_counts_utf8_bytes_not_characters`
- ちょうど上限: 18,000B で fail しないこと → Task 1 `test_exactly_limit_is_ok` / `test_cli_passes_file_within_limit`
- CLAUDE.md が無い・パス違い: vacuous green にならず fail すること → Task 1 `test_cli_fails_when_file_is_missing`
- 圧縮で手順の要点が落ちる: 旧 CLAUDE.md の各ルールの要素が移動先で見つかること → Task 3 Step 4 の突き合わせ表
- skill が自動ロードされない: description が作業内容 (Simulator で画面確認 / pbxproj・Podfile・Gemfile・CI 依存) で書かれ、CLAUDE.md のポインタ行からも辿れること → Task 2 Step 3

---

### Task 1: claude-md-size-check (checker + make ターゲット、tests チェーンにはまだ入れない)

**Files:**
- Create: `app/bin/claude_md_size_check.rb`
- Create: `app/bin/claude-md-size-check.rb`
- Create: `app/bin/test_claude_md_size_check.rb`
- Modify: `app/Makefile` (`plan-docs-check:` ターゲットの直後に追加)

**Interfaces:**
- Produces: `ClaudeMdSizeCheck::LIMIT_BYTES` (Integer 18_000)、`ClaudeMdSizeCheck.result(bytesize:, limit: LIMIT_BYTES)` → `{ ok:, bytesize:, limit:, over: }`、`make claude-md-size-check`

- [ ] **Step 1: テストを書く** — `app/bin/test_claude_md_size_check.rb`

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for claude_md_size_check.rb and the CLI glue.
# Run: ruby bin/test_claude_md_size_check.rb
require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require_relative 'claude_md_size_check'

class ClaudeMdSizeCheckTest < Minitest::Test
  BIN = File.expand_path('claude-md-size-check.rb', __dir__)

  def test_limit_is_18000_bytes
    assert_equal 18_000, ClaudeMdSizeCheck::LIMIT_BYTES
  end

  def test_under_limit_is_ok
    r = ClaudeMdSizeCheck.result(bytesize: 17_999)
    assert r[:ok]
    assert_equal 0, r[:over]
  end

  def test_exactly_limit_is_ok
    r = ClaudeMdSizeCheck.result(bytesize: 18_000)
    assert r[:ok]
    assert_equal 0, r[:over]
  end

  def test_one_byte_over_limit_is_ng
    r = ClaudeMdSizeCheck.result(bytesize: 18_001)
    refute r[:ok]
    assert_equal 1, r[:over]
  end

  def test_cli_counts_utf8_bytes_not_characters
    # 6,001 文字 × 3B = 18,003B: 文字数で数えると通ってしまう入力
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'CLAUDE.md')
      File.write(path, 'あ' * 6_001)
      out, status = Open3.capture2e('ruby', BIN, path)
      assert_equal 1, status.exitstatus, out
      assert_includes out, '18,003 / 18,000 bytes (+3)'
    end
  end

  def test_cli_passes_file_within_limit
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'CLAUDE.md')
      File.write(path, 'a' * 18_000)
      out, status = Open3.capture2e('ruby', BIN, path)
      assert_equal 0, status.exitstatus, out
      assert_includes out, '✅ claude-md-size-check passed (CLAUDE.md 18,000 / 18,000 bytes)'
    end
  end

  def test_cli_fails_when_file_is_missing
    Dir.mktmpdir do |dir|
      out, status = Open3.capture2e('ruby', BIN, File.join(dir, 'CLAUDE.md'))
      assert_equal 1, status.exitstatus, out
      assert_includes out, 'が無い'
    end
  end
end
```

- [ ] **Step 2: RED を確認**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_claude_md_size_check.rb`
Expected: `cannot load such file -- .../claude_md_size_check` で LoadError

- [ ] **Step 3: 純粋ロジック** — `app/bin/claude_md_size_check.rb`

```ruby
# frozen_string_literal: true

# Pure helpers for claude-md-size-check (Issue #171). Kept free of I/O so they
# can be unit-tested (see test_claude_md_size_check.rb). The CLI glue lives in
# bin/claude-md-size-check.rb.
#
# Why this exists: CLAUDE.md was compressed to 11.5KB in #111 (2026-08-15) and
# grew back to 30KB in six weeks, because "add one line to CLAUDE.md" was the
# only place a lesson could go. The limit forces the opposite move: when it is
# exceeded, incident history goes to docs/claude-lessons-archive.md and
# task-specific procedures go to .claude/skills/.
module ClaudeMdSizeCheck
  # UTF-8 bytes, not characters: Japanese is 3 bytes per character, and the
  # issue and PR bodies talk about the size in KB.
  LIMIT_BYTES = 18_000

  # Returns { ok: Boolean, bytesize: Integer, limit: Integer, over: Integer }.
  # Exactly LIMIT_BYTES is ok; over is 0 when ok.
  def self.result(bytesize:, limit: LIMIT_BYTES)
    over = bytesize - limit
    { ok: over <= 0, bytesize: bytesize, limit: limit, over: [over, 0].max }
  end
end
```

- [ ] **Step 4: CLI** — `app/bin/claude-md-size-check.rb` (endless def は使わない: rbenv の別 Ruby 2.7 でも動かすため)

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# claude-md-size-check: fail when the repo-root CLAUDE.md exceeds the byte limit.
#
# Issue #171.
#
# Usage:
#   ruby bin/claude-md-size-check.rb                # repo 直下の CLAUDE.md
#   ruby bin/claude-md-size-check.rb <path>         # 明示パス (fixture 用)
#
# Exit code 0 = 上限以内、1 = 上限超過 or ファイルが無い。

require_relative 'claude_md_size_check'

REPO_ROOT = File.expand_path('../..', __dir__) # app/bin -> app -> repo root

path = ARGV[0] || File.join(REPO_ROOT, 'CLAUDE.md')

unless File.file?(path)
  warn "❌ claude-md-size-check failed: #{path} が無い"
  exit 1
end

r = ClaudeMdSizeCheck.result(bytesize: File.size(path))
name = File.basename(path)

def commas(n)
  n.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
end

if r[:ok]
  puts "✅ claude-md-size-check passed (#{name} #{commas(r[:bytesize])} / #{commas(r[:limit])} bytes)"
  exit 0
end

warn "❌ claude-md-size-check failed: #{name} #{commas(r[:bytesize])} / #{commas(r[:limit])} bytes (+#{commas(r[:over])})"
warn '   直し方: 事故の経緯・PR 番号・実測値は docs/claude-lessons-archive.md へ移し、CLAUDE.md には「何をするか」だけ残す'
warn '   作業時だけ要る手順 (Simulator 検証・Xcode 構成など) は .claude/skills/ の skill へ移し、CLAUDE.md は 1 行のポインタにする'
exit 1
```

- [ ] **Step 5: GREEN を確認**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_claude_md_size_check.rb`
Expected: `7 runs, 16 assertions, 0 failures, 0 errors, 0 skips` (Ruby 3.4.4 で実測)。この数値と違ったら止めて報告

- [ ] **Step 6: mutation で RED を実証 (ルール 8)** — 1 つずつ壊して実行し、必ず元に戻す

| # | 壊し方 | 期待 (実測) | 守るテスト |
| --- | --- | --- | --- |
| M1 | `claude_md_size_check.rb` の `over <= 0` → `over < 0` | 2 failures | exactly_limit / cli_passes |
| M2 | `LIMIT_BYTES = 18_000` → `18_001` | 4 failures | limit / one_byte_over / cli_counts_utf8 / cli_passes |
| M3 | CLI の `File.size(path)` → `File.read(path).size` | 1 failure | cli_counts_utf8 |
| M4 | CLI の `unless File.file?(path)` → `unless true` | 1 failure | cli_fails_when_missing (…が無い の文言) |
| M5 | `ok: over <= 0` → `ok: over == 0` | 1 failure | under_limit |

新規テスト 7 件すべてがどれかの mutation で RED になることを上表で確認する。最後に元のコードで `7 runs, 16 assertions, 0 failures` に戻ること。

- [ ] **Step 7: make ターゲット** — `app/Makefile` の `plan-docs-check:` ブロックの直後に追加 (レシピ行はタブ)

```make
# Issue #171: repo 直下の CLAUDE.md が 18,000B を超えたら fail させる。
# 「学び → CLAUDE.md に 1 行足す」だけだと #111 の圧縮後 6 週間で 30KB に戻ったため。
claude-md-size-check:
	@echo "Running claude-md-size-check..."
	@ruby bin/test_claude_md_size_check.rb
	@ruby bin/claude-md-size-check.rb
```

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make claude-md-size-check`
Expected: minitest が `0 failures`、続いて `❌ claude-md-size-check failed: CLAUDE.md 30,077 / 18,000 bytes (+12,077)` と make の `Error 1` (この時点では超過が正しい)

- [ ] **Step 8: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/claude_md_size_check.rb app/bin/claude-md-size-check.rb app/bin/test_claude_md_size_check.rb app/Makefile && git commit -m "feat(#171): claude-md-size-check を追加"
```

### Task 2: プロジェクト skill 2 本へ領域を分離

**Files:**
- Create: `.claude/skills/leaftimer-simulator-verification/SKILL.md` (ルール 12, 30, 31, 32, 42)
- Create: `.claude/skills/leaftimer-xcode-deps/SKILL.md` (ルール 26, 27, 28, 29, 43 の Podfile 制約部分)
- Modify: `CLAUDE.md` (上記ルールを 1 行ポインタへ)
- Modify: `docs/claude-lessons-archive.md` (移したルールの経緯)

**Interfaces:**
- Consumes: なし
- Produces: skill 名 `leaftimer-simulator-verification` / `leaftimer-xcode-deps` (Task 3 のポインタ行・ルール間参照で使う)

- [ ] **Step 1: SKILL.md を書く** — frontmatter は次の 2 行。本文は元ルールの手順 (コマンド・フラグ・判定条件) を全部残し、PR 番号・事故の経緯は archive への参照に置き換える

```yaml
---
name: leaftimer-simulator-verification
description: Use when verifying LeafTimer screens in the iOS Simulator — finding which screen shows a View, getting the built .app path, checking the 4 background states (work/break × light/dark), Dynamic Type sizes, onboarding/ATT bypass, tapping with cliclick, notification banner timing, animation still/playing checks, and comparing screenshots with the old store screenshots.
---
```

```yaml
---
name: leaftimer-xcode-deps
description: Use when touching LeafTimer's Xcode project or dependencies — adding/removing Swift files or targets (pbxproj), Podfile / Podfile.lock / Gemfile / Gemfile.lock, SPM Package.resolved, CI install steps for CocoaPods/Bundler, ruby checkers wired into make, or choosing a test framework.
---
```

- [ ] **Step 2: 経緯を archive へ** — `docs/claude-lessons-archive.md` 末尾に `## 2026-09-29 追記: #171 で CLAUDE.md から退避した経緯` を作り、`### ルール N` ごとに移した経緯 (PR 番号・実測値) を書く

- [ ] **Step 3: CLAUDE.md をポインタ行へ** — 番号は残す。ルール 43 は「テストは新規は XCTest、View 構造は ViewInspector。Quick/Nimble は新規追加禁止」を 1 文残し、Podfile 制約以降をポインタにする。例:

```text
32. Dynamic Type・onboarding/ATT の回避・cliclick の tap・通知バナー・アニメ判定・スクショ目視 → skill `leaftimer-simulator-verification`
```

Run: `ruby -e 'puts File.read("/Users/shinya/workspace/claude/LeafTimer/CLAUDE.md").bytesize'`
Expected: 30,077 より約 8,000B 減 (移す 10 ルールの合計は 9,663B、ポインタ行が戻す分を引く)。値を記録する

- [ ] **Step 4: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add .claude/skills/leaftimer-simulator-verification/SKILL.md .claude/skills/leaftimer-xcode-deps/SKILL.md CLAUDE.md docs/claude-lessons-archive.md && git commit -m "docs(#171): Simulator 検証と Xcode 構成・依存のルールをプロジェクト skill へ分離"
```

### Task 3: 残るルールの経緯を退避して 18,000B 以下へ

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/claude-lessons-archive.md` (Task 2 で作った節に追記)

- [ ] **Step 1: 大きい順に圧縮** — 各ルールを「何をするか」だけに縮め、PR 番号・実測値・事故の経緯は archive の `### ルール N` へ移す。優先順は 8 (2.2KB) → 7 (2.0KB) → 23 (1.7KB) → 44 → 45 → 14 → 13 → 残り
- [ ] **Step 2: バイト数を確認**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/claude-md-size-check.rb`
Expected: `✅ claude-md-size-check passed (CLAUDE.md N / 18,000 bytes)`。経緯の退避だけで届かない場合は、ルールの統合・廃止案をユーザーに AskUserQuestion で聞いてから進める (勝手に削らない)

- [ ] **Step 3: 読み手の確認** — CLAUDE.md 内のルール間参照 (`ルール 37 と同じ形で` 等) が移動後も解決できること

Run: `/usr/bin/grep -on "ルール *[0-9]\+" /Users/shinya/workspace/claude/LeafTimer/CLAUDE.md`
Expected: 参照先の番号がすべて CLAUDE.md に行として存在する (ポインタ行を含む)

- [ ] **Step 4: 情報が落ちていないか突き合わせる** — `git show master:CLAUDE.md` の各ルールについて、コマンド・フラグ・パス・判定条件が CLAUDE.md / skill / archive のどこにあるかを表にして scratchpad に残し、見つからない要素が 0 件であること

- [ ] **Step 5: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add CLAUDE.md docs/claude-lessons-archive.md && git commit -m "docs(#171): CLAUDE.md の経緯を archive へ退避し 18,000B 以下に圧縮"
```

### Task 4: tests チェーンに組み込み、整合確認して PR

**Files:**
- Modify: `app/Makefile` (`tests:` 行)
- Move: spec / plan → `archive/`

- [ ] **Step 1: tests チェーンに追加** — `plan-docs-check` の直後に `claude-md-size-check` を入れる

```make
tests: precheck cocoapods-lock-check localization-check dynamic-type-check plan-docs-check claude-md-size-check gitignore-check store-screenshots-check-test sort lint unit-tests
```

- [ ] **Step 2: ルール 45 の自己矛盾チェック** — CLAUDE.md・2 本の SKILL.md で、同じ話題 (plan 命名、削除ゲート、bundle exec、Simulator 起動引数) を扱う行を `/usr/bin/grep` し、矛盾が無いこと。ルール 45 自体に「CLAUDE.md は 18,000B 上限 (`make claude-md-size-check`)。超えたら経緯は archive、作業時の手順は `.claude/skills/`」を 1 文足す

- [ ] **Step 3: spec / plan を archive へ**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git mv docs/superpowers/specs/2026-09-29-issue-171-claude-md-size-limit.md docs/superpowers/specs/archive/ && git mv docs/superpowers/plans/2026-09-29-issue-171-claude-md-size-limit.md docs/superpowers/plans/archive/
```

- [ ] **Step 4: 全体テスト** (Bash timeout 600000)

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && set -o pipefail && make tests 2>&1 | tee /tmp/171-tests.log | tail -5; grep -E "✅ claude-md-size-check passed|✅ plan-docs-check passed|\*\* TEST SUCCEEDED \*\*" /tmp/171-tests.log`
Expected: 3 行すべてが出る。`** TEST FAILED **` / `Error 1` / `Error 6x` が無い

- [ ] **Step 5: Commit と PR**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/Makefile CLAUDE.md && git commit -m "chore(#171): claude-md-size-check を tests チェーンへ組み込み、spec/plan を archive へ" && git fetch && gh pr list --state all --head docs/171-claude-md-size-limit && git push -u origin docs/171-claude-md-size-limit
```

PR 本文に書くこと: `Closes #171`、CLAUDE.md のバイト数 30,077 → 実測値、移した先の一覧 (skill 2 本 / archive 節)、mutation 表、物差し (導入後 3 回の振り返りで上限内か)。merge はしない (ルール 22)
