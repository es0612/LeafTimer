# Issue #86 / #78 / #149 / #84 ドキュメント・テスト方針バンドル Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** テストフレームワーク方針を明文化して Podfile のテスト用 pod にバージョン制約を入れ、`docs/superpowers/` の plan/spec 46 件を `archive/` へ退避して命名規則を機械検証できるようにする。

**Architecture:** 4 issue すべて XS/S で、判断は triage 時点で確定済み。Task 1 は「Quick/Nimble をどうするか」という 1 つの判断の 2 つの帰結 (#78 の CLAUDE.md 明文化 + #149 の Podfile 制約) を 1 commit にまとめる。Task 2 は既存 checker と同じ 2 層構成 (rule 33) で `plan-docs-check` を TDD で作り、Task 3 で実際の 46 件移行に適用する。Task 4 で plan 自身を archive へ移して PR を作る (これが新規則の第 1 号実例になる)。

**Tech Stack:** Ruby (標準ライブラリのみ、minitest)、GNU Make、CocoaPods (Bundler 経由)、Markdown

**Spec:** none — spec は作らない。スコープと設計判断は 2026-09-12 の daily-issue-triage で確定済みで、確定内容は下の Global Constraints に verbatim で記載する。XS/S バンドルに対して spec を捏造しない。

## Global Constraints

triage でユーザーが選択した内容 (この 3 つは実装中に再解釈しない):

1. **スコープ** = 「XS/S 4件バンドル」: #86 close + #78 + #149 + #84 を 1 PR で。
2. **#78 の方針** = 「XCTest + ViewInspector を標準」: 新規は XCTest、View 構造テストは ViewInspector。Quick/Nimble は**新規追加禁止・既存 8 本は据え置き**。#149 は 3 つとも `~>` 制約を入れて lock からの逸脱を防ぐ。
3. **#84 の方式** = 「archive/ サブディレクトリに移動」: 対応 issue が closed の plan/spec を `plans/archive/` `specs/archive/` へ `git mv`。**既存ファイルの中身は一切触らない** (front-matter 追記はしない)。過去分の一斉リネームもしない。

プロジェクト規律 (CLAUDE.md より、全 Task に適用):

- ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (rule 1)。
- 成否は exit code でなく出力マーカーで判定する。`** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在かつ `** TEST FAILED **` / `Error 6x` の不在 (rule 1)。
- `Mach error -308` / `Lost connection to testmanagerd` 系 FAIL は Simulator インフラ起因の偽 FAIL。`xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライする (rule 1)。
- grep は `/usr/bin/grep` を使う。このハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重するため「参照ゼロ」の主張に使えない (rule 4)。
- `make unit-tests` を含むコマンドの Bash timeout は 600000 (10 分) にする (rule 16)。
- CocoaPods は常に `bundle exec pod …` で動かす。素の `pod` / `gem install cocoapods` に戻さない (rule 26)。
- checker は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。正常系 GREEN だけの確認は vacuously green (rule 8)。
- **PR merge は plan に含めない。Task 4 の `gh pr create` で終わる** (rule 22)。

## File Structure

| パス | 役割 | 操作 |
| --- | --- | --- |
| `CLAUDE.md` | 常時ルール。ルール 43 (テスト方針) / 44 (plan 命名・archive) を「環境・その他」セクション末尾 (現ルール 42 の後) に追加 | Modify |
| `app/Podfile` | テスト用 pod 3 つに `~>` 制約 + 理由コメント | Modify |
| `app/Podfile.lock` | `bundle exec pod install` が DEPENDENCIES 行を書き換える | Modify (生成物) |
| `app/bin/plan_docs_check.rb` | 純粋ロジック層。ファイル名リストを受け取り違反配列を返す。I/O なし | Create |
| `app/bin/plan-docs-check.rb` | CLI 層。`docs/superpowers/` を走査して ✅/❌ を出す | Create |
| `app/bin/test_plan_docs_check.rb` | minitest。RED 4 ケース + GREEN 4 ケース | Create |
| `app/Makefile` | `plan-docs-check` ターゲット追加 + `tests` チェーンに組み込み | Modify |
| `app/bin/gitignore-doctor-expectations.txt` | `keep: docs/superpowers/plans/archive/` を追加 (#9 型の anchor 事故予防) | Modify |
| `docs/superpowers/plans/archive/` | 既存 plan 34 件の退避先 | Create (dir) |
| `docs/superpowers/specs/archive/` | 既存 spec 12 件の退避先 | Create (dir) |
| `app/bin/gitignore_doctor.rb:7` | spec への path コメントを archive/ 入りに更新 | Modify |
| `app/ci_scripts/ci_post_clone.sh:6` | spec への path コメントを archive/ 入りに更新 | Modify |
| `docs/ver1_2/xcode-cloud-setup.md:3,144` | spec への path 参照を archive/ 入りに更新 | Modify |
| `docs/claude-lessons-archive.md:44` | plan 命名の記述を新規則に更新 | Modify |

## 事前調査で確定した事実 (実装中に再調査しない)

- **移行対象は 46 件すべて。** plans 34 件 + specs 12 件の全ファイルについて、ファイル名 (日付プレフィックス除去後の hyphen 区切りトークン) または本文冒頭 8 行の `#NN` から issue 番号を解決し、`gh issue list --state open` の結果と突き合わせた。**open issue に対応する plan/spec は 0 件**。番号が解決できなかった 2 件 (`2026-05-12-app-store-review-prompt.md` / `2026-05-30-top-screen-stats-ui.md`) は対応する `-design.md` 側が #3 / #39 (ともに closed) を参照しているため完了済み。
- **`a11y` の "11" を issue 番号と誤読しないこと。** 番号抽出は日付プレフィックスを除いた後 hyphen 区切りトークンが純数字のものだけを拾う。`2026-08-03-a11y-bundle.md` の実際の issue は本文の #59 / #60。
- **`.gitignore` の `/plans/` は leading slash で anchor 済み** (`.gitignore:4-5` にその意図のコメントあり)。`docs/superpowers/plans/archive/` を作っても ignore されないが、`gitignore-doctor-expectations.txt` に `keep:` を 1 行足して回帰を機械検証する。
- **`.superpowers/` は untracked** (`git ls-files .superpowers` = 0 件)。過去の SDD 台帳が plan path を参照しているが git 管理外なので修正不要。
- **現在の lock バージョン**: Quick 7.6.2 / Nimble 13.7.1 / ViewInspector 0.10.3 / `COCOAPODS: 1.16.2`。
- **`app/bin/test_gitignore_doctor.rb` の `docs/superpowers/plans/` は fixture 文字列**で実パス依存ではない。変更不要。

---

### Task 1: #78 テスト方針明文化 + #149 Podfile バージョン制約

**Files:**
- Modify: `CLAUDE.md` (「### 環境・その他」セクション、現ルール 42 の直後)
- Modify: `app/Podfile:11-16`
- Modify: `app/Podfile.lock` (生成物)

**Interfaces:**
- Consumes: なし (最初の Task)
- Produces: CLAUDE.md のルール 43。Task 2 / Task 3 は本文を参照しないので文字列依存はない。

- [ ] **Step 1: Podfile の現状を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && sed -n '11,16p' Podfile
```

期待出力 (これと違ったら停止して報告):

```text
  target 'LeafTimerTests' do
    inherit! :search_paths
    # Pods for testing
    pod 'Quick'
    pod 'Nimble'
    pod 'ViewInspector'
  end
```

- [ ] **Step 2: Podfile に `~>` 制約と理由コメントを入れる**

`app/Podfile` の `# Pods for testing` から 3 行の `pod` 宣言までを、次のブロックで置き換える:

```ruby
    # Pods for testing (Issue #149 / CLAUDE.md ルール 43)
    # 制約を入れる理由: 引数なしの `bundle exec pod update` が major 越えまで
    # 一気に上げうる。ViewInspector は patch 差 0.10.2 → 0.10.3 だけで
    # ModernTimerViewSpec の accessibility テスト 2 件の結果が変わった実例が
    # あるため (#73 / PR #150)、ViewInspector のみ patch まで固定する。
    pod 'Quick', '~> 7.6'
    pod 'Nimble', '~> 13.7'
    pod 'ViewInspector', '~> 0.10.3'
```

- [ ] **Step 3: 制約が既存 lock を上げも下げもしないことを実測する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec pod install 2>&1 | tail -20
```

続けて lock を検証する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && /usr/bin/grep -nE "^  - (Quick|Nimble|ViewInspector)| (Quick|Nimble|ViewInspector) \(~>|^COCOAPODS:" Podfile.lock
```

期待: PODS 側が `Quick (7.6.2)` / `Nimble (13.7.1)` / `ViewInspector (0.10.3)` のまま、DEPENDENCIES 側が `- Nimble (~> 13.7)` のように制約付きに変わり、`COCOAPODS: 1.16.2` が不変。

- [ ] **Step 4: pbxproj が動いていないことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git status --short
```

期待: `app/Podfile` と `app/Podfile.lock` のみ。**`app/LeafTimer.xcodeproj/project.pbxproj` が出たら commit せず停止して報告する** (rule 28 の再シリアライズ事故)。

- [ ] **Step 5: CLAUDE.md にルール 43 を追加する**

`CLAUDE.md` の「### 環境・その他」セクション内、ルール 42 の行の直後に次の 1 項目を挿入する (ルール 43 は既存に存在しないことを `/usr/bin/grep -n "^43\." CLAUDE.md` で先に確認する — 0 件であること):

```markdown
43. テストは **新規は XCTest**、View 構造の検証は **ViewInspector** で書く (#78)。Quick/Nimble (`*Spec.swift` 8 本) は**新規追加禁止・既存は据え置き**で、一括移行はしない。`app/Podfile` のテスト用 pod は `~>` で制約する (#149): Quick `~> 7.6` / Nimble `~> 13.7` / **ViewInspector は `~> 0.10.3` と patch まで固定** (0.10.2 → 0.10.3 の patch 差だけで `ModernTimerViewSpec` の accessibility テスト 2 件の結果が変わった実例があるため — PR #150)。
```

- [ ] **Step 6: tests チェーンを通す**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Bash timeout は 600000。期待: 出力に `** TEST SUCCEEDED **` が存在し、`** TEST FAILED **` / `Error 6` が不在。`cocoapods-lock-check passed (1.16.2)` も出ること。`Mach error -308` / `Lost connection to testmanagerd` が出た場合は Simulator を再起動して 1 回リトライする。

- [ ] **Step 7: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add CLAUDE.md app/Podfile app/Podfile.lock && git commit -m "$(cat <<'EOF'
build(#78/#149): テスト方針を XCTest + ViewInspector に明文化し Podfile のテスト用 pod に ~> 制約を入れる

- CLAUDE.md ルール 43: 新規テストは XCTest / View 構造は ViewInspector、Quick/Nimble は新規禁止・既存据え置き
- Podfile: Quick ~> 7.6 / Nimble ~> 13.7 / ViewInspector ~> 0.10.3 (patch 差で a11y テスト結果が変わった実例のため patch 固定)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01H8p5h8iDoCzxLStpCKZF65
EOF
)"
```
---

### Task 2: #84 plan-docs-check を TDD で作る (移行はまだしない)

**Files:**
- Create: `app/bin/plan_docs_check.rb` (純粋ロジック、I/O なし)
- Create: `app/bin/plan-docs-check.rb` (CLI 層)
- Create: `app/bin/test_plan_docs_check.rb` (minitest)
- Modify: `app/Makefile` (`plan-docs-check` ターゲット追加。**`tests` 依存にはまだ足さない**)

**Interfaces:**
- Consumes: なし (Task 1 と独立)
- Produces:
  - `PlanDocsCheck.violations(root_names:, archive_names:) -> Array<{name: String, scope: :root|:archive, reason: String}>` — root は先に、それぞれ名前昇順。違反ゼロなら空配列。
  - `PlanDocsCheck.root_reason(name) -> String`
  - 定数 `ROOT_NAME` / `ARCHIVE_NAME` / `DATE_PREFIX` / `ISSUE_PREFIX`
  - CLI: `ruby bin/plan-docs-check.rb [<superpowers dir>]`。引数省略時は repo root の `docs/superpowers`。成功時 stdout に `✅ plan-docs-check passed (root: plans N / specs M, archive: plans P / specs Q)` を出して exit 0、違反時は stderr に一覧を出して exit 1。
  - Task 3 はこの CLI と make ターゲット名 `plan-docs-check` に依存する。

**設計の背景 (実装者向け):** 規則は「**稼働中の plan/spec だけが `plans/` `specs/` 直下にいる**」。plan の最終タスクが自分自身を `archive/` へ `git mv` してから PR を作るので、master の直下は常に空になる。よって直下は厳格な命名 (`YYYY-MM-DD-issue-NN[-NN…]-slug.md`)、`archive/` は旧規則で書かれた歴史なので日付プレフィックスのみを要求する。「対応 issue が closed か」の判定は `gh` = ネットワーク依存なので checker には入れない (rule 40: 機械的に検証できる部分だけをスクリプトにする)。

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_plan_docs_check.rb` を次の内容で作る:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in plan_docs_check.rb (Issue #84).
# Run: ruby bin/test_plan_docs_check.rb
require 'minitest/autorun'
require_relative 'plan_docs_check'

class PlanDocsCheckTest < Minitest::Test
  VALID_ROOT = '2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md'
  VALID_COMPANION = '2026-06-04-issue-48-asc-metadata-skill.SKILL-source.md'

  def violations(root: [], archive: [])
    PlanDocsCheck.violations(root_names: root, archive_names: archive)
  end

  # --- GREEN: 規則に沿った入力は違反ゼロ ---

  def test_root_accepts_bundle_of_issue_numbers
    assert_empty violations(root: [VALID_ROOT])
  end

  def test_root_accepts_single_issue_number
    assert_empty violations(root: ['2026-09-12-issue-84-plan-docs-check.md'])
  end

  def test_root_accepts_companion_suffix
    assert_empty violations(root: [VALID_COMPANION])
  end

  def test_archive_accepts_legacy_name_without_issue_number
    assert_empty violations(archive: ['2026-05-12-app-store-review-prompt.md'])
  end

  def test_empty_directories_are_green
    assert_empty violations
  end

  # --- RED: 意図的に壊した入力で正しく落ちる (CLAUDE.md ルール 8) ---
  # 各ケースがどの分岐を通るかを reason で突き合わせる。

  def test_root_rejects_missing_issue_number
    # ISSUE_PREFIX 分岐。移行前の実データ 23 件 (plans) がこの形。
    v = violations(root: ['2026-08-13-dynamic-type-58.md'])
    assert_equal 1, v.size
    assert_equal :root, v[0][:scope]
    assert_includes v[0][:reason], 'issue-NN が無い'
  end

  def test_root_rejects_missing_date_prefix
    # DATE_PREFIX 分岐。
    v = violations(root: ['issue-84-plan-docs-check.md'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], '日付プレフィックス'
  end

  def test_root_rejects_uppercase_slug
    # slug 分岐 (date と issue-NN は通るが slug が大文字)。
    v = violations(root: ['2026-09-12-issue-84-Plan-Docs-Check.md'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], 'slug'
  end

  def test_root_rejects_underscore_slug
    v = violations(root: ['2026-09-12-issue-84-plan_docs_check.md'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], 'slug'
  end

  def test_archive_rejects_missing_date_prefix
    v = violations(archive: ['app-store-review-prompt.md'])
    assert_equal 1, v.size
    assert_equal :archive, v[0][:scope]
    assert_includes v[0][:reason], '日付プレフィックス'
  end

  def test_reports_every_violation_sorted_by_name
    v = violations(root: ['zz-bad.md', 'aa-bad.md'], archive: ['no-date.md'])
    assert_equal 3, v.size
    assert_equal %w[aa-bad.md zz-bad.md no-date.md], v.map { |x| x[:name] }
  end
end
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_plan_docs_check.rb
```

期待: `cannot load such file -- .../plan_docs_check` (LoadError)。実装がまだ無いため。

- [ ] **Step 3: 純粋ロジック層を実装する**

`app/bin/plan_docs_check.rb` を次の内容で作る:

```ruby
# frozen_string_literal: true

# Pure helpers for plan-docs-check (Issue #84). Kept free of I/O so they can be
# unit-tested (see test_plan_docs_check.rb). The CLI glue lives in
# bin/plan-docs-check.rb.
#
# Why this exists: docs/superpowers/{plans,specs} accumulated 46 flat files with
# no way to tell in-flight work from finished work (the issue was filed when it
# was 16 and 8). The convention is now: a plan sits at the directory root only
# while its branch is in flight, and the plan's own final task git-mv's it into
# archive/ before `gh pr create`. Root therefore holds only current work and can
# carry a strict name; archive/ holds history written under older conventions and
# only has to keep its date prefix so the listing stays chronological.
module PlanDocsCheck
  # Root (in-flight) name: YYYY-MM-DD-issue-NN[-NN...]-slug[.Companion].md
  #   2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md  ok (bundle)
  #   2026-06-04-issue-48-asc-metadata-skill.SKILL-source.md   ok (companion, rule 41)
  #   2026-08-13-dynamic-type-58.md                            violation (no issue- prefix)
  # The slug is lowercase so names stay unique on case-insensitive APFS.
  ROOT_NAME = /
    \A
    \d{4}-\d{2}-\d{2}-            # date prefix
    issue-\d+(?:-\d+)*-           # issue-NN, or issue-NN-NN... for a bundle
    [a-z0-9]+(?:-[a-z0-9]+)*      # lowercase hyphenated slug
    (?:\.[A-Za-z][A-Za-z0-9-]*)?  # optional companion suffix, e.g. .SKILL-source
    \.md
    \z
  /x.freeze

  # Archive name: the date prefix only. History predates the strict rule and is
  # not renamed (triage decision 2026-09-12).
  ARCHIVE_NAME = /\A\d{4}-\d{2}-\d{2}-.+\.md\z/.freeze

  # Sub-patterns used to tell the caller which part of the name is wrong.
  DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}-/.freeze
  ISSUE_PREFIX = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*-/.freeze

  # [{name:, scope: :root|:archive, reason:}] — empty when everything conforms.
  # Root violations come first, each group sorted by name so output is stable.
  def self.violations(root_names:, archive_names:)
    list = []
    root_names.sort.each do |name|
      next if ROOT_NAME.match?(name)

      list << { name: name, scope: :root, reason: root_reason(name) }
    end
    archive_names.sort.each do |name|
      next if ARCHIVE_NAME.match?(name)

      list << { name: name, scope: :archive, reason: '日付プレフィックス YYYY-MM-DD- で始まっていない' }
    end
    list
  end

  # Which part of a root name failed. Ordered widest-first so the message points
  # at the outermost problem rather than a downstream symptom.
  def self.root_reason(name)
    return '日付プレフィックス YYYY-MM-DD- で始まっていない' unless DATE_PREFIX.match?(name)
    return 'issue-NN が無い (稼働中の plan/spec は対応 issue 番号を名前に持つ)' unless ISSUE_PREFIX.match?(name)

    'slug が小文字英数とハイフンのみになっていない'
  end
end
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_plan_docs_check.rb
```

期待: `11 runs, 29 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: mutation でテストが本当に守れていることを実証する (rule 8)**

checker を意図的に壊して RED を確認し、必ず復元する。**scratchpad にコピーを取ってから壊す** (repo のファイルを直接編集して戻し忘れない):

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app/bin && cp plan_docs_check.rb /tmp/plan_docs_check.orig.rb && \
  sed 's|issue-\\d+(?:-\\d+)\*-           #|\\d+(?:-\\d+)*-           #|' /tmp/plan_docs_check.orig.rb > plan_docs_check.rb && \
  { diff -q /tmp/plan_docs_check.orig.rb plan_docs_check.rb >/dev/null && echo "❌ sed が一致せず無変更 — mutation 不成立" || echo "✅ mutation A 適用"; } && \
  ruby test_plan_docs_check.rb 2>&1 | tail -2
```

期待 (mutation A = ROOT_NAME から `issue-` 必須を外す): `✅ mutation A 適用` と `3 failures`。**`❌ sed が一致せず無変更` が出た場合は mutation が成立していないので `0 failures` を GREEN と読まない** — その場合は該当行 (`issue-\d+(?:-\d+)*-` の行) を Edit で手で書き換えて `git diff` で 1 行だけ変わったことを確認してから走らせる。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app/bin && \
  sed 's|ARCHIVE_NAME = .*|ARCHIVE_NAME = /.*/.freeze|' /tmp/plan_docs_check.orig.rb > plan_docs_check.rb && \
  { diff -q /tmp/plan_docs_check.orig.rb plan_docs_check.rb >/dev/null && echo "❌ sed が一致せず無変更 — mutation 不成立" || echo "✅ mutation B 適用"; } && \
  ruby test_plan_docs_check.rb 2>&1 | tail -2
```

期待 (mutation B = ARCHIVE_NAME を全許可): `✅ mutation B 適用` と `2 failures`。無変更だった場合は mutation A と同じ扱い (手で書き換えて再実行)。

復元して GREEN に戻す:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app/bin && cp /tmp/plan_docs_check.orig.rb plan_docs_check.rb && \
  ruby test_plan_docs_check.rb 2>&1 | tail -2 && git diff --stat plan_docs_check.rb
```

期待: `11 runs, ... 0 failures` かつ `git diff --stat` が**空** (復元漏れなし)。

- [ ] **Step 6: CLI 層を実装する**

`app/bin/plan-docs-check.rb` を次の内容で作る:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# plan-docs-check: verify the naming convention of docs/superpowers/{plans,specs}.
#
# Issue #84. Directory root = work in flight → strict name
# (YYYY-MM-DD-issue-NN[-NN...]-slug.md). archive/ = merged history → date prefix
# only. The move into archive/ is the plan's own final task (CLAUDE.md ルール 44),
# so on master both roots are normally empty.
#
# Usage:
#   ruby bin/plan-docs-check.rb                      # repo の docs/superpowers
#   ruby bin/plan-docs-check.rb <superpowers dir>    # 明示パス (fixture 用)
#
# Exit code 0 = すべて規則どおり、1 = 違反あり or ディレクトリが無い。

require_relative 'plan_docs_check'

REPO_ROOT = File.expand_path('../..', __dir__) # app/bin -> app -> repo root

def md_names(dir)
  return [] unless File.directory?(dir)

  Dir.children(dir).select { |n| n.end_with?('.md') && File.file?(File.join(dir, n)) }
end

base = ARGV[0] || File.join(REPO_ROOT, 'docs', 'superpowers')

unless File.directory?(base)
  warn "❌ plan-docs-check failed: #{base} が無い"
  exit 1
end

counts = {}
violations = []

%w[plans specs].each do |kind|
  root_dir = File.join(base, kind)
  root_names = md_names(root_dir)
  archive_names = md_names(File.join(root_dir, 'archive'))
  counts[kind] = { root: root_names.size, archive: archive_names.size }
  PlanDocsCheck.violations(root_names: root_names, archive_names: archive_names).each do |v|
    violations << v.merge(kind: kind)
  end
end

if violations.empty?
  puts format('✅ plan-docs-check passed (root: plans %d / specs %d, archive: plans %d / specs %d)',
              counts['plans'][:root], counts['specs'][:root],
              counts['plans'][:archive], counts['specs'][:archive])
  exit 0
end

warn "❌ plan-docs-check failed: #{violations.size} 件"
violations.each do |v|
  sub = v[:scope] == :archive ? '/archive' : ''
  warn "   docs/superpowers/#{v[:kind]}#{sub}/#{v[:name]}: #{v[:reason]}"
end
warn '   直し方: 稼働中は YYYY-MM-DD-issue-NN[-NN…]-slug.md。merge 前に archive/ へ git mv する (CLAUDE.md ルール 44)'
exit 1
```

- [ ] **Step 7: CLI が実データで RED になることを確認する (これが移行前の実地 fixture)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/plan-docs-check.rb; echo "exit=$?"
```

期待: `❌ plan-docs-check failed: 35 件` と出て `exit=1`。35 件の内訳は plans 直下の旧命名 23 件 + specs 直下 12 件 (`issue-` prefix 付きの 11 件と本 plan 自身は通過する)。**この 35 件は Task 3 で 0 件になる。**

- [ ] **Step 8: Makefile にターゲットを追加する (`tests` 依存にはまだ足さない)**

`app/Makefile` の `pbxproj-structure-check:` ブロックの後ろに追加する:

```makefile
# Issue #84 / ルール 44: docs/superpowers/{plans,specs} の命名規則を検証する。
# 直下 = 稼働中なので YYYY-MM-DD-issue-NN[-NN…]-slug.md を厳格に要求し、
# archive/ = merge 済みの歴史なので日付プレフィックスのみを要求する。
plan-docs-check:
	@echo "Running plan-docs-check..."
	@ruby bin/test_plan_docs_check.rb
	@ruby bin/plan-docs-check.rb
```

`tests` ターゲットの依存には Task 3 で足す (この時点で足すと 35 件の既存違反で `make tests` が落ちる)。

- [ ] **Step 9: ターゲット単体で期待どおり落ちることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make plan-docs-check; echo "exit=$?"
```

期待: minitest が `0 failures` で通り、その後 CLI が `❌ plan-docs-check failed: 35 件` を出して make が非ゼロで終わる (この Mac は GNU Make 3.81 なので `make: *** [plan-docs-check] Error 1` を報告して exit 2)。**成否はこの ❌ 行の存在で判定する** (rule 1: exit code でなく出力マーカー)。

- [ ] **Step 10: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/plan_docs_check.rb app/bin/plan-docs-check.rb app/bin/test_plan_docs_check.rb app/Makefile && git commit -m "$(cat <<'EOF'
build(#84): plan/spec の命名規則 checker (plan-docs-check) を追加

- bin/plan_docs_check.rb (純粋ロジック) / bin/plan-docs-check.rb (CLI) / bin/test_plan_docs_check.rb (minitest 11 件) の 2 層構成 (ルール 33)
- 直下は YYYY-MM-DD-issue-NN[-NN…]-slug.md を厳格に、archive/ は日付プレフィックスのみを要求
- mutation 2 種 (ROOT_NAME の issue- 必須除去 / ARCHIVE_NAME 全許可) で 3 failures / 2 failures を実証 (ルール 8)
- tests チェーンへの組み込みは移行 commit と同じ Task で行う (この時点では既存 35 件が違反のため)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01H8p5h8iDoCzxLStpCKZF65
EOF
)"
```

---

### Task 3: #84 既存 46 件を archive/ へ移行し checker を tests チェーンに入れる

**Files:**
- Create (dir): `docs/superpowers/plans/archive/`, `docs/superpowers/specs/archive/`
- Modify (move): `docs/superpowers/plans/*.md` 34 件 (本 plan 自身を除く) → `plans/archive/`
- Modify (move): `docs/superpowers/specs/*.md` 12 件 → `specs/archive/`
- Modify: `app/bin/gitignore_doctor.rb:7`
- Modify: `app/ci_scripts/ci_post_clone.sh:6`
- Modify: `docs/ver1_2/xcode-cloud-setup.md:3,144`
- Modify: `docs/claude-lessons-archive.md:44`
- Modify: `app/bin/gitignore-doctor-expectations.txt`
- Modify: `CLAUDE.md` (ルール 44)
- Modify: `app/Makefile` (`tests` 依存に `plan-docs-check` を追加)

**Interfaces:**
- Consumes: Task 2 の `make plan-docs-check` と CLI `ruby bin/plan-docs-check.rb`
- Produces: 移行後のディレクトリ構造。Task 4 は `docs/superpowers/plans/archive/` が存在することに依存する。

- [ ] **Step 1: 移行前の状態を記録する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && echo "plans=$(ls docs/superpowers/plans/*.md | wc -l) specs=$(ls docs/superpowers/specs/*.md | wc -l)"
```

期待: `plans=35 specs=12` (35 = 既存 34 + 本 plan)。数が違ったら停止して報告する (並行セッションの書き換えを疑う — rule 13)。

- [ ] **Step 2: archive/ を作り、本 plan 以外を git mv する**

本 plan 自身は Task 4 で移すので**ここでは除外する** (除外しないと Task 4 の実例デモが成立しない):

```bash
cd /Users/shinya/workspace/claude/LeafTimer && mkdir -p docs/superpowers/plans/archive docs/superpowers/specs/archive && \
  for f in /Users/shinya/workspace/claude/LeafTimer/docs/superpowers/plans/*.md; do \
    b=$(basename "$f"); \
    [ "$b" = "2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md" ] && continue; \
    git mv "$f" /Users/shinya/workspace/claude/LeafTimer/docs/superpowers/plans/archive/; \
  done && \
  for f in /Users/shinya/workspace/claude/LeafTimer/docs/superpowers/specs/*.md; do \
    git mv "$f" /Users/shinya/workspace/claude/LeafTimer/docs/superpowers/specs/archive/; \
  done && \
  echo "root: plans=$(ls docs/superpowers/plans/*.md 2>/dev/null | wc -l) specs=$(ls docs/superpowers/specs/*.md 2>/dev/null | wc -l)" && \
  echo "archive: plans=$(ls docs/superpowers/plans/archive/*.md | wc -l) specs=$(ls docs/superpowers/specs/archive/*.md | wc -l)"
```

期待: `root: plans=1 specs=0` / `archive: plans=34 specs=12`

パスは絶対で組んでいる (rule 5: 直前の `cd` で相対パスが二重化して無言タイムアウトするのを避ける)。

- [ ] **Step 3: checker が GREEN になることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/plan-docs-check.rb; echo "exit=$?"
```

期待: `✅ plan-docs-check passed (root: plans 1 / specs 0, archive: plans 34 / specs 12)` と `exit=0`。Task 2 Step 7 で 35 件 RED だったものが 0 件になる = RED → GREEN の両方向が実データで取れた。

- [ ] **Step 4: 移動で壊れた path 参照を直す**

移動前に grep で洗い出した live な参照は 4 ファイル。`.superpowers/` 配下のヒットは untracked なので対象外。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
  /usr/bin/sed -i '' 's|docs/superpowers/specs/2026-06-01-gitignore-doctor-design.md|docs/superpowers/specs/archive/2026-06-01-gitignore-doctor-design.md|' app/bin/gitignore_doctor.rb && \
  /usr/bin/sed -i '' 's|docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md|docs/superpowers/specs/archive/2026-05-23-xcode-cloud-migration-design.md|g' app/ci_scripts/ci_post_clone.sh docs/ver1_2/xcode-cloud-setup.md && \
  /usr/bin/grep -rn "superpowers/specs/2026" app/bin/gitignore_doctor.rb app/ci_scripts/ci_post_clone.sh docs/ver1_2/xcode-cloud-setup.md
```

期待: 出力の全行が `superpowers/specs/archive/2026-...` になっていること (`archive/` 無しのヒットが残っていたら手で直す)。

続けて `docs/claude-lessons-archive.md:44` の plan 命名の記述を新規則に合わせる。該当行の `docs/superpowers/plans/<date>-<feature>.md` を次に置き換える:

```text
docs/superpowers/plans/YYYY-MM-DD-issue-NN[-NN…]-slug.md
```

- [ ] **Step 5: 移動後に残った参照が無いことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -rn "superpowers/plans/2026\|superpowers/specs/2026" --include="*.md" --include="*.rb" --include="*.sh" --include="Makefile" . 2>/dev/null | /usr/bin/grep -v "^./docs/superpowers/" | /usr/bin/grep -v "^./.superpowers/" | /usr/bin/grep -v "/archive/"
```

続けて、`2026` を含まないため上の grep に掛からない `docs/claude-lessons-archive.md` の旧表記も確認する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -n "plans/<date>" docs/claude-lessons-archive.md
```

期待: **出力 0 行** (Step 4 後半の置換が済んでいれば 0 件。`no matches found` ではなく 0 行であることを確認する — rule 4)。

期待: 最初の grep も **出力 0 行**。`/usr/bin/grep` を使うのは、このハーネスの `grep` が ripgrep 実装で `.gitignore` を尊重し `.superpowers/` のヒットを落とすため (rule 4)。0 行だった場合は「本当に 0 件」であることを、上の除外を外した grep が非ゼロ行を返すことで確かめる (コマンド不成立と区別する)。

- [ ] **Step 6: gitignore-doctor の expectations に archive/ を足す**

`app/bin/gitignore-doctor-expectations.txt` の `keep:   docs/superpowers/plans/` の行の直後に追加する:

```text
keep:   docs/superpowers/plans/archive/
keep:   docs/superpowers/specs/archive/
```

- [ ] **Step 7: gitignore-check が通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make gitignore-check
```

期待: minitest が `0 failures` で通り、gitignore-doctor が ✅ を出すこと。`/plans/` は `.gitignore` で leading slash により anchor 済みなので archive/ も committable なまま。

- [ ] **Step 8: CLAUDE.md にルール 44 を追加する**

「### 環境・その他」セクション、Task 1 で追加したルール 43 の直後に挿入する:

```markdown
44. plan / spec のファイル名は `YYYY-MM-DD-issue-NN[-NN…]-slug.md` (slug は小文字英数とハイフン。companion は `….SKILL-source.md` のように suffix を足す)。**`plans/` `specs/` 直下は稼働中のものだけ** — plan の最終タスクで `git mv` して `plans/archive/` へ移してから `gh pr create` する (#84。「merge 後に別 commit で片付ける」設計にすると 34 件溜まった実績がある)。`archive/` 配下は旧規則の歴史なのでリネームせず、日付プレフィックスのみを要求する。`make plan-docs-check` (tests チェーン内) がこの命名を検証する。
```

- [ ] **Step 9: Makefile の tests チェーンに組み込む**

`app/Makefile` の `tests:` 行を次に置き換える:

```makefile
tests: precheck cocoapods-lock-check localization-check dynamic-type-check plan-docs-check sort lint unit-tests
```

- [ ] **Step 10: tests チェーン全体を通す**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Bash timeout は 600000。期待: `plan-docs-check passed` の ✅ 行が出て、`** TEST SUCCEEDED **` が存在し `** TEST FAILED **` / `Error 6` が不在。

- [ ] **Step 11: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add -A docs/superpowers CLAUDE.md app/Makefile app/bin/gitignore-doctor-expectations.txt app/bin/gitignore_doctor.rb app/ci_scripts/ci_post_clone.sh docs/ver1_2/xcode-cloud-setup.md docs/claude-lessons-archive.md && git commit -m "$(cat <<'EOF'
docs(#84): plan/spec 46 件を archive/ へ退避し plan-docs-check を tests チェーンに入れる

- plans 34 件 / specs 12 件を archive/ へ git mv (対応 issue は全件 closed を確認済み。中身は無変更)
- CLAUDE.md ルール 44: 直下は稼働中のみ、plan の最終タスクで archive/ へ移してから PR を作る
- 移動で壊れる path 参照 4 ファイルを修正 + gitignore-doctor expectations に archive/ を keep: 追加
- make tests に plan-docs-check を追加 (移行後なので GREEN)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01H8p5h8iDoCzxLStpCKZF65
EOF
)"
```

---

### Task 4: plan 自身を archive/ へ移して PR を作る

**Files:**
- Modify (move): `docs/superpowers/plans/2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md` → `plans/archive/`

**Interfaces:**
- Consumes: Task 3 が作った `docs/superpowers/plans/archive/`
- Produces: PR。**merge はしない** (rule 22: レビュー通過後にコントローラがルール 24 のチェーンで行う)

- [ ] **Step 1: ルール 44 の第 1 号実例として plan を archive へ移す**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git mv docs/superpowers/plans/2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md docs/superpowers/plans/archive/ && ls docs/superpowers/plans/
```

期待: `archive` のみ (直下に .md が 0 件)。

- [ ] **Step 2: checker が空の直下で GREEN になることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make plan-docs-check
```

期待: `✅ plan-docs-check passed (root: plans 0 / specs 0, archive: plans 35 / specs 12)`

- [ ] **Step 3: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add -A docs/superpowers/plans && git commit -m "$(cat <<'EOF'
docs(#84): 本 plan を archive/ へ移動 (ルール 44 の第 1 号実例)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01H8p5h8iDoCzxLStpCKZF65
EOF
)"
```

- [ ] **Step 4: 既存 PR と merge 状況を確認する (rule 21)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/86-78-149-84-doc-test-policy-bundle
```

期待: 0 件 (既存 PR があれば push 前に停止して報告)。

- [ ] **Step 5: push して PR を作る**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git push -u origin feature/86-78-149-84-doc-test-policy-bundle && gh pr create --base master --title "docs/build(#78/#149/#84): テスト方針の明文化 + Podfile 制約 + plan/spec の archive 規則" --body "$(cat <<'EOF'
## 概要

2026-09-12 の daily-issue-triage で選んだ XS/S 4 件バンドル。

- **#78** テストフレームワーク方針を明文化 (CLAUDE.md ルール 43): 新規は XCTest、View 構造は ViewInspector、Quick/Nimble は新規禁止・既存 8 本は据え置き
- **#149** Podfile のテスト用 pod に `~>` 制約: Quick `~> 7.6` / Nimble `~> 13.7` / ViewInspector `~> 0.10.3` (patch 差で a11y テスト結果が変わった実例があるため patch 固定)
- **#84** plan/spec 46 件を `archive/` へ退避 + 命名 checker (`make plan-docs-check`) を tests チェーンに追加 (CLAUDE.md ルール 44)
- **#86** は別途 close (スキル `auditing-repo-to-issues` として既に実装済みだった)

## 検証

- `make tests` GREEN (`plan-docs-check passed` / `cocoapods-lock-check passed` の ✅ 行を確認)
- `make gitignore-check` GREEN (archive/ が `.gitignore` の `/plans/` に巻き込まれないことを expectations で機械検証)
- checker の mutation 2 種で RED を実証: ROOT_NAME の `issue-` 必須除去 → 3 failures / ARCHIVE_NAME 全許可 → 2 failures
- 移行前の実データ 35 件が RED、移行後 0 件で GREEN (両方向)
- `bundle exec pod install` 後に PODS のバージョンが不変・`project.pbxproj` に差分が出ないことを確認

## 実装計画

`docs/superpowers/plans/archive/2026-09-12-issue-86-78-149-84-doc-test-policy-bundle.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01H8p5h8iDoCzxLStpCKZF65
EOF
)"
```

**ここで止まる。** merge はレビュー通過後にコントローラが `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで行う (rule 22 / 24)。

---

## CI 受け入れ基準 (rule 23)

この PR は `app/Makefile` を変更するので、**green check ではなく当該 step のログ行で受け入れる**。summary 系 step は入力欠落でも exit 0 するため、green は「何も出なかった」と区別できない。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh run view <run-id> --log | /usr/bin/grep -E "plan-docs-check passed|cocoapods-lock-check passed|lock-check passed|⚠️ skipped"
```

受け入れ条件:
- `✅ plan-docs-check passed (root: plans 0 / specs 0, archive: plans 35 / specs 12)` が**存在する**
- `✅ cocoapods-lock-check passed (1.16.2)` が**存在する**
- `⚠️ skipped` の行が**存在しない** (素の `skipped` で grep すると GitHub Actions 自身の step status 行や minitest の `0 skips` に誤ヒットするため、rule 27 の事故で実際に出た絵文字付きの文言に絞る) (rule 27: `rescue LoadError` ガード付き checker は CI の `vendor/bundle` 隔離で黙って skip しうる。今回の checker は標準ライブラリのみなので skip 分岐は無いが、既存 checker の skip 混入を同時に検出する)

`gh run watch` は成功時に結論行を出さないことがあるので、watch の出力だけで pass と判断せず、完了後に `gh pr checks <PR>` で再確認する (rule 23)。

## この plan に含めない付随作業 (コントローラが実施、silent drop 禁止 — rule 19)

1. **#86 の close**: `~/.claude/skills/auditing-repo-to-issues/perspectives.md` に live/dead 判定の 1 行 (「dead code は修正対象にしない — live 参照を grep で確認してから起票する」) を追記したうえで、`gh issue close 86` する。issue が要求した内容 (5 観点テンプレート / 重複チェック / ラベル規則 / `gh issue create` バッチ) は既に SKILL.md + perspectives.md に実装済み。skill は repo 外 (`~/.claude/skills/`) なので本 PR には含まれない。
2. **#109 に前提崩れのコメント**: 案 (a)「XCUITest を復活させる」の拠り所だった #76 は PR #140 で UITests ターゲットを**削除**して COMPLETED になった。残る選択肢は (b) DEBUG 起動引数の拡張 / (c) セクション単位で直接開く / (d) UITests を新規に作り直す。
3. **#74 に CLAUDE.md ルール 42 との衝突コメント**: 本文は `docs/ver1_2/screen/Slice*.png` の退避・削除を提案しているが、ルール 42 はこの 8 枚を「レイアウト回帰判定の live リファレンス」として参照している。スコープから除外するか、ルール 42 の参照先を移すかを決めてから着手する。あわせて `app/fastlane/metadata` の PLACEHOLDER は `privacy_url` だけでなく `copyright` / `subtitle` / `keywords` にも残っている。

## Self-Review

- **スコープ網羅**: #78 → Task 1 Step 5 (ルール 43) / #149 → Task 1 Step 2-4 / #84 → Task 2 + Task 3 + ルール 44 / #86 → 付随作業 1。4 件すべてに行き先がある。
- **Placeholder スキャン**: 「TBD」「適切に」「Task N と同様」は無し。checker の 3 ファイルは全文を掲載し、`ruby -c` と実行で検証済み (11 runs / 29 assertions / 0 failures、mutation A 3 failures・B 2 failures、実データ 35 件 RED)。
- **型・名前の一貫性**: `PlanDocsCheck.violations(root_names:, archive_names:)` の keyword 名、返り値の `:name` / `:scope` / `:reason` キー、make ターゲット名 `plan-docs-check`、✅ メッセージの文言が Task 2 / 3 / 4 と CI 受け入れ基準で一致している。
- **Task 順序の依存**: Task 2 で `tests` 依存に足さないのは、移行前は 35 件 RED で `make tests` が落ちるため。組み込みは Task 3 Step 9 (移行後)。Task 4 が plan 自身を移すので Task 3 Step 2 では除外している。
