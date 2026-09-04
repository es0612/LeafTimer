# #143 CocoaPods 固定を Gemfile + bundle exec に移行する — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CI (`pr-tests.yml`) とローカル (`make install`) の CocoaPods バージョンを `app/Gemfile` + `Gemfile.lock` で固定し、`bundle exec pod install` に一本化する。#141 の `ensure-cocoapods-version.sh` (binstub 事情で downgrade できない) を廃止し、代わりに「Gemfile.lock の cocoapods 版 == Podfile.lock の `COCOAPODS:` 行」を検証する Ruby チェッカーを `make tests` チェーンに入れる。

**Architecture:** Ruby のバージョン解決を RubyGems の binstub 挙動に頼らず Bundler に任せる。CI は `ruby/setup-ruby@v1` (`working-directory: app`, `bundler-cache: true`) で `app/.ruby-version` の Ruby を入れて `bundle install` まで済ませ、Pod install ステップは `bundle exec pod install` にする。ローカルは同じ `.ruby-version` を rbenv が読むので CI と同一 Ruby で動く。バージョン drift の検出は既存 `bin/` の 3 層構成 (純粋ロジック `foo_bar.rb` / minitest `test_foo_bar.rb` / CLI `foo-bar.rb`) に倣った `cocoapods-lock-check` で行う。

**Tech Stack:** Ruby 3.4.4 (rbenv / setup-ruby) / Bundler (3.4.4 同梱) / CocoaPods 1.16.2 / GitHub Actions `ruby/setup-ruby@v1` / minitest (Ruby 同梱)

**Spec:** issue #143 本文 (方針 (A)) + 2026-09-05 セッションでの決定:
- Gemfile は **cocoapods のみ** (既存の `gem "fastlane"` 行は削除。fastlane の実体は brew 版 `/opt/homebrew/bin/fastlane` で bundle 経由の利用者ゼロ)
- ローカル Ruby は **`app/.ruby-version` = `3.4.4`** を置き rbenv install で揃える (CI runner で cocoapods 1.16.2 の動作実績がある 3.4 系に合わせる)
- **Xcode Cloud の `app/ci_scripts/ci_post_clone.sh` はスコープ外** (master 限定トリガーで PR 検証不能。#143 にフォローアップとしてコメントを残す)

## Global Constraints

- CocoaPods 版は `app/Podfile.lock` の `COCOAPODS: 1.16.2` を単一の情報源とし、Gemfile の pin と一致させる。
- Ruby は `3.4.4` (`app/.ruby-version`)。CI の setup-ruby は `ruby-version` 入力を書かず `.ruby-version` を読ませる (二重管理しない)。
- `app/Gemfile.lock` は **commit する** (Bundler の再現性の要)。`.bundle/` / `vendor/bundle/` が生成された場合のみ `app/.gitignore` に追加する。
- `app/bin/ensure-cocoapods-version.sh` の削除は **ユーザーが `! git rm app/bin/ensure-cocoapods-version.sh` を自分の turn で実行する** (CLAUDE.md ルール 14)。subagent は削除しない。削除済みかは Task 3 で `git ls-files app/bin/ensure-cocoapods-version.sh` が空であることで確認する。
- `pr-tests.yml` の Coverage step にはバッククォート 3 連が含まれる。plan 内では**差分ハンクだけ**を示し、ファイル全文をフェンスに埋め込まない (ルール 41)。
- ビルド/テスト系コマンドは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (ルール 1)。`make unit-tests` / `make tests` を回す時は Bash timeout 600000 (ルール 16)。
- 受け入れは green check ではなく CI ログ行で行う (ルール 23、後述「受け入れ基準」)。
- plan に merge ステップは含めない (ルール 22)。PR 作成まで。

---

## 事前条件 (コントローラが Task 1 dispatch 前に確認)

- [ ] `rbenv versions` に `3.4.4` が出る (背景で `rbenv install -s 3.4.4` 実行済み。失敗していたら `brew upgrade ruby-build && rbenv install 3.4.4` で再試行)
- [ ] `git ls-files app/bin/ensure-cocoapods-version.sh` が空 (ユーザーが `! git rm` 済み)。空でなければ Task 3 の Step 1 で再確認し、残っていれば Task 3 を止めてコントローラに報告する

---

### Task 1: Ruby / Gem の固定 (`.ruby-version` + Gemfile + Gemfile.lock)

**Files:**
- Create: `app/.ruby-version`
- Modify: `app/Gemfile` (全 3 行を置換)
- Create: `app/Gemfile.lock` (`bundle install` が生成)
- Modify (条件付き): `app/.gitignore` — `bundle install` / `bundle exec pod install` 後に `.bundle/` や `vendor/` が untracked に出た場合のみ

**Interfaces:**
- Produces: `app/Gemfile.lock` の specs ブロックに `    cocoapods (1.16.2)` 行 (Task 2 のチェッカーが読む)。`app/.ruby-version` (Task 3 の setup-ruby が読む)。

- [ ] **Step 1: `.ruby-version` を置き、rbenv がそれを拾うことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && printf '3.4.4\n' > .ruby-version && ruby --version && bundle --version
```

Expected: `ruby 3.4.4 ...` と `Bundler version 2.6.x`。`ruby 2.7.5` が出たら rbenv が 3.4.4 を持っていない → コントローラに報告して止まる (自分で `rbenv install` しない)。

- [ ] **Step 2: Gemfile を cocoapods のみに書き換える**

`app/Gemfile` の全文を次にする:

```ruby
source "https://rubygems.org"

# Issue #143: CI (pr-tests.yml の setup-ruby) とローカル (make install) が
# 同じ CocoaPods を使うように Bundler で固定する。バージョンは
# Podfile.lock の `COCOAPODS:` 行と一致させる (make cocoapods-lock-check が検証)。
gem "cocoapods", "1.16.2"
```

- [ ] **Step 3: `bundle install` して lock を生成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && bundle install && bundle exec pod --version
```

Expected: 最後の行が `1.16.2`。`bundle install` が native extension のビルドで失敗した場合は、エラーの gem 名と行をコントローラに報告して止まる。

- [ ] **Step 4: lock の中身と untracked ファイルを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && /usr/bin/grep -n "^    cocoapods (\|^   cocoapods (\|BUNDLED WITH" -A1 Gemfile.lock && git status --short
```

Expected:
- `    cocoapods (1.16.2)` 行が specs ブロックにある
- `git status --short` に出るのは `?? app/.ruby-version`, ` M app/Gemfile`, `?? app/Gemfile.lock` の 3 つだけ。`.bundle/` や `vendor/` が出た場合は `app/.gitignore` の `# CocoaPods` セクションの直前に次を追加してから再度 `git status --short` で消えたことを確認する:

```gitignore
# Bundler (Issue #143)
.bundle/
vendor/bundle/
```

- [ ] **Step 5: `bundle exec pod install` が pbxproj を動かさないことを確認する (= #141/#143 の本来の目的)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec pod install && git diff --exit-code -- LeafTimer.xcodeproj/project.pbxproj && echo "PBXPROJ_STABLE"
```

Expected: `PBXPROJ_STABLE` が出る。出ない (diff が出る) 場合は diff をそのまま報告して止まる。**`git checkout -- ` で戻さない**。

- [ ] **Step 6: 既存の Ruby スクリプト群が 3.4.4 でも通ることを確認する**

`.ruby-version` によりローカルの `ruby bin/*.rb` は全て 2.7.5 → 3.4.4 に切り替わる。回帰がないことを実測する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make precheck && make localization-check && make dynamic-type-check && make gitignore-check && ruby bin/test_add_to_target.rb && ruby -e 'require "xcodeproj"; puts "xcodeproj OK"'
```

Expected: 各 make ターゲットが `✅ ... passed` / minitest の `0 failures, 0 errors` で終わり、最後に `xcodeproj OK` (cocoapods の依存として xcodeproj gem が入るので `make add-file` も 3.4.4 で動く)。失敗したら**修正せず**、失敗した script 名と出力をコントローラに報告して止まる (スコープ判断はコントローラが行う)。

- [ ] **Step 7: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/.ruby-version app/Gemfile app/Gemfile.lock && git status --short && git commit -m "build(#143): CocoaPods 1.16.2 を Gemfile + Gemfile.lock で固定し、Ruby 3.4.4 を .ruby-version で揃える

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

(`app/.gitignore` を変更した場合は `git add app/.gitignore` も含める。)

---

### Task 2: `cocoapods-lock-check` — Gemfile.lock と Podfile.lock のバージョン一致チェッカー

**Files:**
- Create: `app/bin/cocoapods_lock_check.rb` (純粋ロジック、I/O なし)
- Create: `app/bin/test_cocoapods_lock_check.rb` (minitest)
- Create: `app/bin/cocoapods-lock-check.rb` (CLI)
- Modify: `app/Makefile` — `cocoapods-lock-check` ターゲット追加、`tests:` チェーンに組み込み

**Interfaces:**
- Consumes: `app/Gemfile.lock` の specs 行 `    cocoapods (1.16.2)` (Task 1)、`app/Podfile.lock` の `COCOAPODS: 1.16.2`
- Produces: `CocoapodsLockCheck.gemfile_lock_version(text) -> String | nil`、`CocoapodsLockCheck.podfile_lock_version(text) -> String | nil`、`CocoapodsLockCheck.report(gemfile_lock_text, podfile_lock_text) -> Hash` (`{ ok: Boolean, gem: String|nil, pod: String|nil, reason: String|nil }`)。CLI は引数なしで `app/Gemfile.lock` と `app/Podfile.lock` を読み、`ruby bin/cocoapods-lock-check.rb <Gemfile.lock> <Podfile.lock>` の 2 引数で別パスも受ける (RED fixture 用)。成功時 stdout に `✅ cocoapods-lock-check passed (1.16.2)`、失敗時 stderr に `❌ cocoapods-lock-check failed: ...` で exit 1。

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_cocoapods_lock_check.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in cocoapods_lock_check.rb.
# Run: ruby bin/test_cocoapods_lock_check.rb
require 'minitest/autorun'
require_relative 'cocoapods_lock_check'

class CocoapodsLockCheckTest < Minitest::Test
  GEMFILE_LOCK = <<~LOCK
    GEM
      remote: https://rubygems.org/
      specs:
        cocoapods (1.16.2)
          addressable (~> 2.8)
          cocoapods-core (= 1.16.2)
        cocoapods-core (1.16.2)
          activesupport (>= 5.0, < 8)
        cocoapods-plugins (1.0.0)

    PLATFORMS
      arm64-darwin-25

    DEPENDENCIES
      cocoapods (= 1.16.2)

    BUNDLED WITH
       2.6.7
  LOCK

  PODFILE_LOCK = <<~LOCK
    PODS:
      - Firebase/Core (10.29.0)

    SPEC CHECKSUMS:
      Firebase: abc

    PODFILE CHECKSUM: def

    COCOAPODS: 1.16.2
  LOCK

  # --- gemfile_lock_version ------------------------------------------------

  def test_gemfile_lock_version_reads_specs_line
    assert_equal '1.16.2', CocoapodsLockCheck.gemfile_lock_version(GEMFILE_LOCK)
  end

  # `cocoapods-core (1.16.2)` や `DEPENDENCIES` の `cocoapods (= 1.16.2)` を
  # 拾ってはいけない。specs ブロックの `cocoapods (x.y.z)` だけが対象。
  def test_gemfile_lock_version_ignores_cocoapods_core_and_dependencies
    lock = GEMFILE_LOCK.sub("    cocoapods (1.16.2)\n", '')
    assert_nil CocoapodsLockCheck.gemfile_lock_version(lock)
  end

  def test_gemfile_lock_version_returns_nil_for_empty_text
    assert_nil CocoapodsLockCheck.gemfile_lock_version('')
  end

  # --- podfile_lock_version ------------------------------------------------

  def test_podfile_lock_version_reads_cocoapods_line
    assert_equal '1.16.2', CocoapodsLockCheck.podfile_lock_version(PODFILE_LOCK)
  end

  def test_podfile_lock_version_returns_nil_when_line_missing
    assert_nil CocoapodsLockCheck.podfile_lock_version(PODFILE_LOCK.sub(/^COCOAPODS:.*\n/, ''))
  end

  # --- report --------------------------------------------------------------

  def test_report_ok_when_versions_match
    r = CocoapodsLockCheck.report(GEMFILE_LOCK, PODFILE_LOCK)
    assert r[:ok]
    assert_equal '1.16.2', r[:gem]
    assert_equal '1.16.2', r[:pod]
    assert_nil r[:reason]
  end

  def test_report_fails_on_mismatch
    r = CocoapodsLockCheck.report(GEMFILE_LOCK, PODFILE_LOCK.sub('COCOAPODS: 1.16.2', 'COCOAPODS: 1.15.2'))
    refute r[:ok]
    assert_equal '1.16.2', r[:gem]
    assert_equal '1.15.2', r[:pod]
    assert_match(/mismatch/, r[:reason])
  end

  def test_report_fails_when_gemfile_lock_has_no_cocoapods
    r = CocoapodsLockCheck.report('', PODFILE_LOCK)
    refute r[:ok]
    assert_nil r[:gem]
    assert_match(/Gemfile\.lock/, r[:reason])
  end

  def test_report_fails_when_podfile_lock_has_no_cocoapods_line
    r = CocoapodsLockCheck.report(GEMFILE_LOCK, '')
    refute r[:ok]
    assert_nil r[:pod]
    assert_match(/Podfile\.lock/, r[:reason])
  end
end
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_cocoapods_lock_check.rb
```

Expected: `cannot load such file -- .../cocoapods_lock_check (LoadError)` で失敗。

- [ ] **Step 3: 純粋ロジックを実装する**

`app/bin/cocoapods_lock_check.rb`:

```ruby
# frozen_string_literal: true

# Pure helpers for cocoapods-lock-check (Issue #143). Kept free of I/O so they
# can be unit-tested (see test_cocoapods_lock_check.rb). The CLI glue lives in
# bin/cocoapods-lock-check.rb.
#
# Why this exists: `bundle exec pod install` runs whatever cocoapods version
# Gemfile.lock pins, while Podfile.lock records the version that last wrote
# it. If the two drift, pod install re-serializes project.pbxproj differently
# and the CI sort gate (git diff --exit-code project.pbxproj) fails for a
# reason unrelated to the PR.
module CocoapodsLockCheck
  # A Gemfile.lock specs entry: exactly four spaces, the gem name, a space,
  # then the version in parens. Anchoring on the four-space indent and the
  # bare name excludes:
  #   - `cocoapods-core (1.16.2)` (different gem)
  #   - `      cocoapods-core (= 1.16.2)` (6-space dependency sub-line)
  #   - `  cocoapods (= 1.16.2)` (DEPENDENCIES block, 2-space, has `= `)
  GEMFILE_SPEC = /^ {4}cocoapods \((\d+(?:\.\d+)*)\)$/.freeze

  # Podfile.lock trailer written by pod install: `COCOAPODS: 1.16.2`
  PODFILE_TRAILER = /^COCOAPODS: *(\S+)\s*$/.freeze

  # Version of the cocoapods gem pinned by Gemfile.lock, or nil if absent.
  def self.gemfile_lock_version(gemfile_lock_text)
    m = GEMFILE_SPEC.match(gemfile_lock_text)
    m && m[1]
  end

  # Version recorded in Podfile.lock's COCOAPODS: line, or nil if absent.
  def self.podfile_lock_version(podfile_lock_text)
    m = PODFILE_TRAILER.match(podfile_lock_text)
    m && m[1]
  end

  # { ok:, gem:, pod:, reason: } — reason is nil when ok.
  def self.report(gemfile_lock_text, podfile_lock_text)
    gem = gemfile_lock_version(gemfile_lock_text)
    pod = podfile_lock_version(podfile_lock_text)
    reason =
      if gem.nil?
        'Gemfile.lock に cocoapods の specs 行が無い (bundle install 未実行 or Gemfile から消えた)'
      elsif pod.nil?
        'Podfile.lock に COCOAPODS: 行が無い'
      elsif gem != pod
        "version mismatch: Gemfile.lock=#{gem} Podfile.lock=#{pod}"
      end
    { ok: reason.nil?, gem: gem, pod: pod, reason: reason }
  end
end
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_cocoapods_lock_check.rb
```

Expected: `9 runs, ... 0 failures, 0 errors`。

- [ ] **Step 5: CLI を書く**

`app/bin/cocoapods-lock-check.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# cocoapods-lock-check: verify that the cocoapods version pinned by
# app/Gemfile.lock equals the `COCOAPODS:` trailer in app/Podfile.lock.
#
# Issue #143. Replaces bin/ensure-cocoapods-version.sh (#141), which tried to
# install the right cocoapods into the runner's RubyGems and could not
# downgrade past the binstub. With Bundler the version is whatever
# Gemfile.lock says, so the only thing left to guard is drift between the two
# lock files.
#
# Usage:
#   ruby bin/cocoapods-lock-check.rb                              # app/Gemfile.lock vs app/Podfile.lock
#   ruby bin/cocoapods-lock-check.rb <Gemfile.lock> <Podfile.lock> # explicit paths (fixtures)
#
# Exit code 0 = versions match; 1 = mismatch or a lock file is unreadable.

require_relative 'cocoapods_lock_check'

PROJECT_DIR = File.expand_path('..', __dir__) # app/

gemfile_lock = ARGV[0] || File.join(PROJECT_DIR, 'Gemfile.lock')
podfile_lock = ARGV[1] || File.join(PROJECT_DIR, 'Podfile.lock')

[gemfile_lock, podfile_lock].each do |path|
  next if File.file?(path)

  warn "❌ cocoapods-lock-check failed: #{path} が無い"
  exit 1
end

report = CocoapodsLockCheck.report(File.read(gemfile_lock), File.read(podfile_lock))

if report[:ok]
  puts "✅ cocoapods-lock-check passed (#{report[:gem]})"
  exit 0
else
  warn "❌ cocoapods-lock-check failed: #{report[:reason]}"
  warn "   Gemfile.lock: #{gemfile_lock}"
  warn "   Podfile.lock: #{podfile_lock}"
  warn '   直し方: Gemfile の cocoapods pin を Podfile.lock の COCOAPODS: 行に合わせて `bundle install`、' \
       'または `bundle exec pod install` で Podfile.lock を書き直す'
  exit 1
end
```

- [ ] **Step 6: CLI を本物の lock で GREEN、壊した fixture で RED にする (ルール 8)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && chmod +x bin/cocoapods-lock-check.rb && ruby bin/cocoapods-lock-check.rb && FX=/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/lockfix && mkdir -p "$FX" && sed 's/^COCOAPODS: .*/COCOAPODS: 1.15.2/' Podfile.lock > "$FX/Podfile.lock" && cp Gemfile.lock "$FX/Gemfile.lock" && { ruby bin/cocoapods-lock-check.rb "$FX/Gemfile.lock" "$FX/Podfile.lock"; echo "mutated exit=$?"; }
```

Expected: 1 行目 `✅ cocoapods-lock-check passed (1.16.2)`、続いて `❌ cocoapods-lock-check failed: version mismatch: Gemfile.lock=1.16.2 Podfile.lock=1.15.2` と `mutated exit=1`。tracked ファイルは触らない。

- [ ] **Step 7: Makefile に配線する**

`app/Makefile` の `dynamic-type-check:` ターゲットの直後 (ファイル末尾) に追加:

```makefile

# Issue #143: Gemfile.lock の cocoapods 版と Podfile.lock の COCOAPODS: 行の一致を検証する。
# ずれると bundle exec pod install が pbxproj を別形式で再シリアライズし、CI の sort gate が偽 fail する。
cocoapods-lock-check:
	@echo "Running cocoapods-lock-check..."
	@ruby bin/test_cocoapods_lock_check.rb
	@ruby bin/cocoapods-lock-check.rb
```

`tests:` 行を次に置換:

```makefile
tests: precheck cocoapods-lock-check localization-check dynamic-type-check sort lint unit-tests
```

(Makefile のレシピ行はタブインデント必須。スペースにすると `missing separator` で壊れる。)

- [ ] **Step 8: make 経由で GREEN を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make cocoapods-lock-check && make -n tests | head -3
```

Expected: `Running cocoapods-lock-check...` → minitest `0 failures` → `✅ cocoapods-lock-check passed (1.16.2)`。`make -n tests` の出力に precheck の次に `cocoapods-lock-check` の echo が並ぶ。

- [ ] **Step 9: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/cocoapods_lock_check.rb app/bin/test_cocoapods_lock_check.rb app/bin/cocoapods-lock-check.rb app/Makefile && git commit -m "build(#143): cocoapods-lock-check で Gemfile.lock と Podfile.lock の CocoaPods 版一致を make tests で検証する

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

---

### Task 3: CI workflow と Makefile を bundle exec に切り替える

**Files:**
- Modify: `.github/workflows/pr-tests.yml` — "Ensure tools" step と "Pod install" step
- Modify: `app/Makefile` — 冒頭コメント、`install:` / `update:` レシピ
- 削除確認: `app/bin/ensure-cocoapods-version.sh` (ユーザーが `git rm` 済みであること)

**Interfaces:**
- Consumes: `app/.ruby-version` と `app/Gemfile.lock` (Task 1) を `ruby/setup-ruby@v1` が `working-directory: app` で読む。

- [ ] **Step 1: ensure script が削除済みか確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git ls-files app/bin/ensure-cocoapods-version.sh; ls app/bin/ensure-cocoapods-version.sh 2>&1; git log --oneline -1 -- app/bin/ensure-cocoapods-version.sh
```

Expected: `git ls-files` が空、`ls` が `No such file or directory`。**ファイルがまだあれば削除せず**、コントローラに「ensure-cocoapods-version.sh が未削除」と報告して止まる (ルール 14)。

- [ ] **Step 2: pr-tests.yml の "Ensure tools" step を setup-ruby + swiftlint に置き換える**

現在の step:

```yaml
      - name: Ensure tools (managed runner は preinstall を保証しない)
        run: |
          which pod || brew install cocoapods
          bash app/bin/ensure-cocoapods-version.sh
          which swiftlint || brew install swiftlint
```

これを次の 2 step に置き換える (位置は "Show toolchain versions" の直後のまま):

```yaml
      # Issue #143: Ruby は app/.ruby-version、gem は app/Gemfile.lock を setup-ruby が読む。
      # bundler-cache: true が bundle install とキャッシュを行うので、以降は bundle exec pod で
      # Podfile.lock と同じ CocoaPods が必ず動く (brew / RubyGems binstub のバージョンに依存しない)。
      - name: Set up Ruby + Bundler (CocoaPods は Gemfile.lock 固定)
        uses: ruby/setup-ruby@v1
        with:
          working-directory: app
          bundler-cache: true

      - name: Ensure tools (managed runner は preinstall を保証しない)
        run: |
          which swiftlint || brew install swiftlint
```

- [ ] **Step 3: "Pod install" step を bundle exec に置き換える**

現在の step:

```yaml
      - name: Pod install
        working-directory: app
        run: |
          want="$(sed -n 's/^COCOAPODS: *//p' Podfile.lock | tr -d '[:space:]')"
          pod "_${want}_" install
```

これを次に置き換える (`bundle exec pod --version` の出力行がルール 23 の受け入れ根拠になる):

```yaml
      - name: Pod install (bundle exec)
        working-directory: app
        run: |
          echo "cocoapods via bundler: $(bundle exec pod --version)"
          bundle exec pod install
```

- [ ] **Step 4: YAML 構文と step 構成を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && ruby -ryaml -e 'y = YAML.load_file(".github/workflows/pr-tests.yml"); steps = y["jobs"]["pr-tests"]["steps"]; steps.each { |s| puts(s["name"] || s["uses"]) }' && /usr/bin/grep -c "ensure-cocoapods-version\|brew install cocoapods\|pod \"_" .github/workflows/pr-tests.yml```
```

Expected: step 名の一覧に `Set up Ruby + Bundler (CocoaPods は Gemfile.lock 固定)` と `Pod install (bundle exec)` が含まれ、`Ensure tools ...` も残る。grep の count は `0` (旧経路の残骸なし)。ripgrep ではなく `/usr/bin/grep` を使う (ルール 4)。

- [ ] **Step 5: Makefile の `install:` / `update:` と冒頭コメントを bundle exec 化する**

`app/Makefile` 冒頭 2 行:

```makefile
# Pods/ is intentionally not committed and may be absent locally.
# Run `make install` to fetch dependencies before the first build.
```

を次に置換:

```makefile
# Pods/ is intentionally not committed and may be absent locally.
# Run `make install` to fetch dependencies before the first build.
# Issue #143: CocoaPods は app/Gemfile.lock で固定し bundle exec 経由で動かす。
# 初回は `rbenv install $(cat .ruby-version) && bundle install` が必要 (CI は
# .github/workflows/pr-tests.yml の setup-ruby が同じ .ruby-version / Gemfile.lock を読む)。
```

`install:` / `update:` ターゲット:

```makefile
install:
	pod install
update:
	pod update
```

を次に置換:

```makefile
install:
	bundle exec pod install
update:
	bundle exec pod update
```

- [ ] **Step 6: ローカルで `make install` が bundle 経由で通り、pbxproj が動かないことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make install && git diff --exit-code -- LeafTimer.xcodeproj/project.pbxproj && echo "PBXPROJ_STABLE" && make cocoapods-lock-check
```

Expected: `bundle exec pod install` のログ → `PBXPROJ_STABLE` → `✅ cocoapods-lock-check passed (1.16.2)`。

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/pr-tests.yml app/Makefile && git commit -m "ci(#143): pr-tests を setup-ruby + bundle exec pod install に切り替え、make install も bundle exec 化

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

---

### Task 4: CLAUDE.md ルール 26 の書き換え

**Files:**
- Modify: `CLAUDE.md` — ルール 26 (行頭 `26.` の 1 行)

**Interfaces:** なし (docs のみ)

- [ ] **Step 1: ルール 26 を現状に合わせて置換する**

`CLAUDE.md` の `26.` で始まる行 (現在 `ensure-cocoapods-version.sh` と `pod _<lock版>_ install` を案内している) を、次の 1 行に置換する:

```text
26. マネージド CI runner は CocoaPods / Bundler 等の preinstall を保証しない。CI hook の冒頭で `set -euo pipefail` 配下の明示 install を先頭に置く。**CocoaPods は `app/Gemfile.lock` で固定し常に `bundle exec pod …` で動かす** (#143。Ruby は `app/.ruby-version`、CI は `ruby/setup-ruby@v1` の `working-directory: app` + `bundler-cache: true` が両方を読む)。素の `pod` / `gem install cocoapods` / `pod _<ver>_` に戻さない — macos runner の `pod` は brew ruby の RubyGems binstub で**常に最新 install 版を activate する**ため lock 版へ downgrade できない (PR #144 で実測)。Gemfile.lock と Podfile.lock の `COCOAPODS:` 行の一致は `make cocoapods-lock-check` (tests チェーン内) が守る。Xcode Cloud の `ci_post_clone.sh` は master 限定トリガーで PR 検証できないため #143 のフォローアップ (未着手)。
```

- [ ] **Step 2: 旧経路の言及が CLAUDE.md に残っていないことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -n "ensure-cocoapods-version\|pod _<lock版>_" CLAUDE.md docs/claude-lessons-archive.md; echo "grep exit=$?"
```

Expected: CLAUDE.md からはヒットなし。`docs/claude-lessons-archive.md` に残る言及は**履歴なので触らない** (ヒットしてもそのまま)。

- [ ] **Step 3: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add CLAUDE.md && git commit -m "docs(#143): ルール 26 を Gemfile + bundle exec 方式に書き換え

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

---

### Task 5: フル検証と PR 作成 (コントローラが実行)

- [ ] **Step 1: `make tests` を通す** (Bash timeout 600000)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` があり `** TEST FAILED **` / `Error 6x` / `No rule to make target` が無い。途中に `✅ cocoapods-lock-check passed (1.16.2)`。`Mach error -308` / `Lost connection to testmanagerd` は Simulator 再起動して 1 回リトライ (ルール 1)。

- [ ] **Step 2: 既存 PR の有無を確認して push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/143-cocoapods-gemfile-bundle-exec && git push -u origin feature/143-cocoapods-gemfile-bundle-exec
```

- [ ] **Step 3: PR 作成**

本文に含めること: 3 つの決定 (Gemfile は cocoapods のみ / `.ruby-version` 3.4.4 / Xcode Cloud はスコープ外)、ローカル開発者向けの初回手順 (`rbenv install 3.4.4 && cd app && bundle install`)、`fastlane/README.md` の `[bundle exec] fastlane` 表記は brew 版 fastlane を直接叩く前提で bundle exec を付けない旨、受け入れ基準 (下記)。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create --base master --title "build/ci(#143): CocoaPods を Gemfile + bundle exec で固定 (ensure-cocoapods-version.sh 廃止)" --body-file /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pr-143-body.md
```

- [ ] **Step 4: #143 にフォローアップコメント (Xcode Cloud)**

```bash
gh issue comment 143 --body "PR <番号> で pr-tests.yml と make install を Gemfile + bundle exec 化しました。Xcode Cloud の app/ci_scripts/ci_post_clone.sh (brew install cocoapods → pod install) は master 限定トリガーで PR から検証できないためスコープ外にしています。TestFlight 配信で pbxproj 差分や版ずれが問題になった時点で、ci_post_clone.sh を gem install bundler → bundle install → bundle exec pod install に切り替える別 PR を切ってください。"
```

---

## 受け入れ基準 (ルール 23: green check ではなく CI ログ行で判定)

PR の pr-tests run に対して `gh run view <run-id> --log` を取り、次の 3 行が**すべて**存在すること:

| step | 期待するログ行 | 意味 |
| --- | --- | --- |
| `Set up Ruby + Bundler (CocoaPods は Gemfile.lock 固定)` | `ruby 3.4.4` を含む行 (setup-ruby が `.ruby-version` を読んだ証拠) | Ruby 固定が効いている |
| `Pod install (bundle exec)` | `cocoapods via bundler: 1.16.2` | Podfile.lock と同じ CocoaPods が bundle 経由で動いた |
| `Run make tests` | `✅ cocoapods-lock-check passed (1.16.2)` | drift チェッカーが CI で live |

取り方:

```bash
RUN_ID=$(gh pr checks <PR> --json name,link --jq '.[] | select(.name=="pr-tests") | .link' | sed 's#.*/runs/##; s#/job.*##')
gh run view "$RUN_ID" --log | /usr/bin/grep -E "ruby 3\.4\.4|cocoapods via bundler: 1\.16\.2|cocoapods-lock-check passed" | head
```

加えて `Sort gate` step が pass していること (`bundle exec pod install` が pbxproj を動かしていない = #141/#143 の本来の目的)。

## 自己レビュー

- **Spec coverage**: 方針 (A) の「Gemfile に cocoapods pin」→ Task 1、「CI を bundle exec」→ Task 3、「make install を bundle exec」→ Task 3、ensure script の退役 → 事前条件 (ユーザー `git rm`) + Task 2 (代替チェッカー) + Task 4 (ルール 26)、Xcode Cloud スコープ外 → Task 5 Step 4 のコメント。
- **Placeholder scan**: 各 step にコマンド・期待出力・ファイル全文 or ハンクを記載済み。`<PR>` / `<run-id>` / `<番号>` は実行時に確定する値。
- **Type consistency**: `CocoapodsLockCheck.gemfile_lock_version` / `podfile_lock_version` / `report` の名前と戻り値 (`{ ok:, gem:, pod:, reason: }`) は Task 2 のテスト・実装・CLI で一致。Makefile ターゲット名 `cocoapods-lock-check` は Task 2 / Task 4 / 受け入れ基準で一致。step 名 `Set up Ruby + Bundler (CocoaPods は Gemfile.lock 固定)` / `Pod install (bundle exec)` は Task 3 Step 2-4 と受け入れ基準で一致。
