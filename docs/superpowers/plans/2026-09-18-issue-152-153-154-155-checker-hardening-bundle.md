# checker 群の堅牢化バンドル (#152 / #153 / #154 / #155) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PR #156 の final review で分離された 4 件 (ViewInspector の strict pin / plan 滞留の検出 / checker 依存の明示宣言 / 失敗理由の文言) を 1 PR で解消する。

**Architecture:** 変更は開発ループ側のゲートのみで、本番アプリのコードには触れない。`app/bin/plan_docs_check.rb` は「命名の検証 (`violations`)」と「滞留の検証 (`stale`)」を別関数に分け、後者だけが `today` を受け取る。これにより既存 13 テストのシグネチャが変わらず、滞留テストだけが日付を固定できる。

**Tech Stack:** Ruby 3.4.4 (`app/.ruby-version`) / minitest / CocoaPods 1.16.2 (Bundler 経由) / GNU make

**Spec:** `docs/superpowers/specs/2026-09-18-issue-152-153-154-155-checker-hardening-bundle.md`

## Global Constraints

- ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (CLAUDE.md ルール 1)。
- `make tests` を実行する Bash の timeout は `600000` (10 分) にする (ルール 16)。
- `make tests` の成否は exit code でなく出力マーカーで判定する: `** TEST SUCCEEDED **` の存在 かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在 (ルール 1)。
- CocoaPods は常に `bundle exec pod …` で動かす。素の `pod` / `gem install cocoapods` に戻さない (ルール 26)。
- `grep` でファイル不在・参照ゼロを主張する検証は `/usr/bin/grep` を使う (ハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重する — ルール 4)。
- このリポジトリの default branch は **master**。作業ブランチは `feature/152-153-154-155-checker-hardening-bundle` (作成済み)。
- **PR merge はこの plan に含めない** (ルール 22)。plan は「PR 作成まで」で切る。
- 破壊的操作 (`rm` / `git reset` / 既存ファイルの丸ごと上書き) は行わない (ルール 14)。

## 事前に実測済みの数値 (ルール 7)

実装者はこの数値を成否判定に使う。食い違ったら止めて報告すること。

| 検証 | 実測値 |
| --- | --- |
| Task 1 の新規テストを現行実装に当てたとき | `7 runs, 9 assertions, 3 failures, 4 errors` (7 件すべて RED) |
| Task 1 実装後の新規テスト | `7 runs, 19 assertions, 0 failures, 0 errors` |
| Task 1 実装後の既存テスト | `13 runs, 34 assertions, 0 failures, 0 errors` (件数・assertion 数とも現行と不変) |
| mutation M1: `STALE_DAYS` 14 → 9999 | `1 failures` |
| mutation M2: `STALE_DAYS` 14 → 0 | `2 failures` |
| mutation M3: `ISSUE_PREFIX` を lookahead から末尾ハイフン要求に戻す | `1 failures` |
| mutation M4: `return REASON_EXT unless EXT_OK.match?(name)` の 2 行を削除 | `2 failures` |
| Task 2 後の `gitignore-doctor` | `✅ gitignore-doctor: 7 expectation(s) satisfied` (現在は 6) |

**注意 (vacuous 検証の罠):** `bin/gitignore-doctor.rb` は `FIXTURE_FILE` をハードコードしており **ARGV を読まない**。別ファイルを引数に渡しても必ず repo の `bin/gitignore-doctor-expectations.txt` を読むので、「引数で fixture を差し替えて確認した」は検証になっていない。実ファイルを編集してから `make gitignore-check` で確認すること。

---

### Task 1: plan_docs_check の失敗理由の並べ替えと滞留検出 (#155 / #153)

**Files:**
- Modify: `app/bin/plan_docs_check.rb`
- Modify: `app/bin/plan-docs-check.rb`
- Test: `app/bin/test_plan_docs_check.rb`

**Interfaces:**
- Consumes: なし (このタスクが最初)
- Produces:
  - `PlanDocsCheck.violations(root_names:, archive_names:)` → `[{name: String, scope: :root|:archive, reason: String}]` — **シグネチャは現行のまま変えない**
  - `PlanDocsCheck.stale(root_names:, today:, threshold_days: STALE_DAYS)` → `[{name: String, scope: :root, reason: String}]`
  - `PlanDocsCheck::STALE_DAYS` = `14`
  - `PlanDocsCheck::REASON_EXT` = `'拡張子が小文字の .md になっていない'`

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_plan_docs_check.rb` の末尾 (`test_root_still_accepts_valid_companion_suffix` の後、クラスの `end` の前) に以下を追記する。ファイル先頭の `require 'minitest/autorun'` の次の行に `require 'date'` も足す。

```ruby
  # --- #155: reason が「壊れていない構成要素」を指してしまう 3 ケース ---

  def test_root_uppercase_extension_reports_extension
    # 壊れているのは拡張子だけ。slug は正しいので slug のせいにしてはいけない。
    v = violations(root: ['2026-09-12-issue-84-fixture.MD'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], '拡張子'
  end

  def test_archive_uppercase_extension_reports_extension
    # archive 側は日付プレフィックスが付いているので、日付のせいにしてはいけない。
    v = violations(archive: ['2026-01-01-legacy.MD'])
    assert_equal 1, v.size
    assert_equal :archive, v[0][:scope]
    assert_includes v[0][:reason], '拡張子'
  end

  def test_root_missing_slug_reports_slug
    # issue-84 は付いているので「issue-NN が無い」は誤り。欠けているのは slug。
    v = violations(root: ['2026-09-12-issue-84.md'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], 'slug'
  end

  # --- #153: 直下に置きっぱなしの plan を滞留として検出する ---
  # today を明示的に渡すのは、純粋関数の中で Date.today を呼ぶとテストが
  # 実行日に依存して将来 silent に壊れるため。

  STALE_TODAY = Date.new(2026, 9, 18)

  def test_stale_13_days_is_green
    assert_empty PlanDocsCheck.stale(root_names: ['2026-09-05-issue-84-x.md'], today: STALE_TODAY)
  end

  def test_stale_exactly_14_days_is_green
    # 閾値ちょうどは許容する (14 日「より」古い場合に落とす)。
    assert_empty PlanDocsCheck.stale(root_names: ['2026-09-04-issue-84-x.md'], today: STALE_TODAY)
  end

  def test_stale_15_days_is_violation
    s = PlanDocsCheck.stale(root_names: ['2026-09-03-issue-84-x.md'], today: STALE_TODAY)
    assert_equal 1, s.size
    assert_equal :root, s[0][:scope]
    assert_includes s[0][:reason], '15'
  end

  def test_stale_ignores_naming_violations
    # 命名違反は violations が既に報告しているので、stale は二重計上しない。
    assert_empty PlanDocsCheck.stale(root_names: ['2020-01-01-no-issue.md'], today: STALE_TODAY)
  end
```

- [ ] **Step 2: テストを実行して RED を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -5`

Expected: 既存 13 件は通り、新規 7 件が落ちる。実測済みの内訳は新規分だけで `3 failures, 4 errors` (`stale` 未定義の `NoMethodError` が 4 件、reason 文字列の不一致が 3 件)。合計は `20 runs, 3 failures, 4 errors`。

**この数値と違ったら止めて報告すること** (別の原因で赤くなっている可能性がある)。

- [ ] **Step 3: plan_docs_check.rb を実装する**

`app/bin/plan_docs_check.rb` を次のように変更する。

ファイル先頭の `# frozen_string_literal: true` の後に追加:

```ruby
require 'date'
```

`ARCHIVE_NAME` の定義の後に追加:

```ruby
  # 直下に置いたまま放置された plan/spec を検出する閾値 (#153)。ルール 44 は
  # 「plan の最終タスクで archive/ へ git mv してから gh pr create する」と定めて
  # いるので、直下に居てよいのは plan を書いてから PR を立てるまでの数時間。
  # 14 日は「長期化した PR を誤検出しない」ために十分な余裕を取った値。
  STALE_DAYS = 14
```

`DATE_PREFIX` / `ISSUE_PREFIX` / `SLUG_OK` のブロックを次で置き換える (`EXT_OK` の追加、`ISSUE_PREFIX` の lookahead 化):

```ruby
  # Sub-patterns used to tell the caller which part of the name is wrong.
  # 判定順は外側から: 拡張子 → 日付 → issue-NN → slug → companion suffix (#155)。
  # ROOT_NAME / ARCHIVE_NAME の `\.md` は case-sensitive なので、拡張子だけが
  # 大文字の入力は「その手前の構成要素が違う」ように見えてしまう。拡張子を
  # 最初に判定することで 3 ケース (root の .MD / archive の .MD / slug 欠落) が
  # 同時に解消する。
  EXT_OK = /\.md\z/.freeze
  DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}-/.freeze
  # issue-NN / issue-NN-NN... の直後が「-」か「.」であることだけを見る。
  # 末尾ハイフンまで要求すると slug 欠落 (2026-09-12-issue-84.md) が
  # 「issue-NN が無い」と誤報告される (#155)。
  #   正: 2026-09-12-issue-84-slug.md / 2026-09-12-issue-86-78-149-84-bundle.md
  #       2026-09-12-issue-84.md (issue 部分だけは満たす → slug 分岐へ送る)
  #   反: 2026-09-12-slug.md / 2026-09-12-issue--slug.md / 2026-09-12-issueX-84-slug.md
  ISSUE_PREFIX = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*(?=[-.])/.freeze
  # date + issue-NN + slug までが正しいか (companion suffix の形は問わない)。
  SLUG_OK = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*-[a-z0-9]+(?:-[a-z0-9]+)*(?:\..*)?\.md\z/.freeze

  REASON_EXT = '拡張子が小文字の .md になっていない'
```

`violations` の archive ループの `reason:` を `archive_reason(name)` に差し替える:

```ruby
    archive_names.sort.each do |name|
      next if ARCHIVE_NAME.match?(name)

      list << { name: name, scope: :archive, reason: archive_reason(name) }
    end
```

`root_reason` を次で置き換え、その後ろに `stale` と `archive_reason` を追加する:

```ruby
  # Which component (extension / date / issue-NN / slug / companion suffix)
  # failed. Ordered widest-first so the message points at the outermost
  # problem rather than a downstream symptom.
  def self.root_reason(name)
    return REASON_EXT unless EXT_OK.match?(name)
    return '日付プレフィックス YYYY-MM-DD- で始まっていない' unless DATE_PREFIX.match?(name)
    return 'issue-NN が無い (稼働中の plan/spec は対応 issue 番号を名前に持つ)' unless ISSUE_PREFIX.match?(name)
    return 'slug が無いか、小文字英数とハイフンのみになっていない' unless SLUG_OK.match?(name)

    'companion suffix が英字始まりの英数ハイフンになっていない (例: .SKILL-source)'
  end

  def self.archive_reason(name)
    return REASON_EXT unless EXT_OK.match?(name)

    '日付プレフィックス YYYY-MM-DD- で始まっていない'
  end

  # 直下に STALE_DAYS より長く置かれている plan/spec (#153)。
  # today は呼び出し側が渡す (純粋関数の中で Date.today を呼ぶとテストが実行日に
  # 依存する)。判定は mtime でなくファイル名の日付プレフィックスに対して行う —
  # mtime は git checkout / fresh clone でチェックアウト時刻に書き換わるため。
  # 命名違反は violations が既に報告しているので、ここでは ROOT_NAME に適合する
  # 名前だけを対象にして二重計上を避ける。
  def self.stale(root_names:, today:, threshold_days: STALE_DAYS)
    root_names.sort.filter_map do |name|
      next unless ROOT_NAME.match?(name)

      age = (today - Date.parse(name[0, 10])).to_i
      next if age <= threshold_days

      { name: name, scope: :root,
        reason: "作成から #{age} 日経過している (PR 作成前に archive/ へ git mv する — CLAUDE.md ルール 44)" }
    end
  end
```

- [ ] **Step 4: テストを実行して GREEN を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -3`

Expected: `20 runs, 53 assertions, 0 failures, 0 errors, 0 skips`

(既存 13 runs / 34 assertions + 新規 7 runs / 19 assertions。既存分の件数が変わっていたら `violations` のシグネチャを壊している。)

- [ ] **Step 5: mutation で「壊すと赤くなる」ことを実証する (ルール 8)**

4 つの mutation を 1 つずつ入れてテストを走らせ、毎回元に戻す。各 mutation の期待 failure 数は実測済み。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
cp bin/plan_docs_check.rb /tmp/plan_docs_check.good.rb

# M1: 閾値を実質無限大に → 滞留を一切検出しなくなる (期待 1 failures)
sed -i '' 's/STALE_DAYS = 14/STALE_DAYS = 9999/' bin/plan_docs_check.rb
bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -1
cp /tmp/plan_docs_check.good.rb bin/plan_docs_check.rb

# M2: 閾値を 0 に → 新しい plan まで滞留扱いになる (期待 2 failures)
sed -i '' 's/STALE_DAYS = 14/STALE_DAYS = 0/' bin/plan_docs_check.rb
bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -1
cp /tmp/plan_docs_check.good.rb bin/plan_docs_check.rb

# M4: 拡張子分岐を削除 (root_reason と archive_reason の 2 行) (期待 2 failures)
sed -i '' '/return REASON_EXT unless EXT_OK.match?(name)/d' bin/plan_docs_check.rb
bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -1
cp /tmp/plan_docs_check.good.rb bin/plan_docs_check.rb
```

M3 (`ISSUE_PREFIX` を lookahead から末尾ハイフン要求に戻す、期待 `1 failures`) は sed で正規表現を書き換えるとエスケープが壊れやすいので、エディタで該当行を次に置き換えてテストし、元に戻す:

```ruby
  ISSUE_PREFIX = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*-/.freeze
```

最後に元に戻っていることを確認する:

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && git diff --stat bin/plan_docs_check.rb && bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -1`
Expected: `20 runs, 53 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 6: CLI を滞留検出に配線し、失敗メッセージに issue 誘導を足す**

`app/bin/plan-docs-check.rb` の `require_relative 'plan_docs_check'` の直前に追加:

```ruby
require 'date'
```

`counts = {}` の直前に追加:

```ruby
# 実行日は 1 回だけ取って全 kind で共有する (日付をまたいだ実行でも判定がぶれない)。
today = Date.today
```

`%w[plans specs].each do |kind|` ブロックの中、既存の `PlanDocsCheck.violations(...)` の呼び出しの直後に追加:

```ruby
  PlanDocsCheck.stale(root_names: root_names, today: today).each do |v|
    violations << v.merge(kind: kind)
  end
```

末尾の `warn '   直し方: ...'` の行の直後に 1 行追加:

```ruby
warn '   issue 未起票なら先に gh issue create — 厳格名は保存前に issue 番号を要求する (CLAUDE.md ルール 44)'
```

- [ ] **Step 7: CLI を実行して緑を確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec ruby bin/plan-docs-check.rb; echo "exit=$?"`

Expected: `✅ plan-docs-check passed (root: plans 1 / specs 1, archive: plans 35 / specs 12)` と `exit=0`

(この時点では本 plan と spec が直下に居るので root は 1/1。日付は今日なので滞留しない。)

- [ ] **Step 8: CLI の滞留検出が実際に赤くなることを fixture で確認する**

正常系の緑だけでは vacuously green なので、一時ディレクトリで古い日付の plan を置いて赤を実証する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app
FIX=$(mktemp -d)
mkdir -p "$FIX/plans/archive" "$FIX/specs/archive"
touch "$FIX/plans/2020-01-01-issue-84-ancient-plan.md"
bundle exec ruby bin/plan-docs-check.rb "$FIX"; echo "exit=$?"
rm -rf "$FIX"
```

Expected: `❌ plan-docs-check failed: 1 件` と `docs/superpowers/plans/2020-01-01-issue-84-ancient-plan.md: 作成から NNNN 日経過している …`、`exit=1`

- [ ] **Step 9: コミットする**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/plan_docs_check.rb app/bin/plan-docs-check.rb app/bin/test_plan_docs_check.rb && git commit -m "$(cat <<'EOF'
fix(#155/#153): 失敗理由の分岐を並べ替え、plan の滞留検出を追加

#155: root_reason / archive_reason の判定順を「拡張子 → 日付 → issue-NN →
slug → companion」にし、拡張子が大文字の 2 ケースと slug 欠落の 1 ケースが
壊れていない構成要素を指す問題を解消した。ISSUE_PREFIX は末尾ハイフン要求を
やめて lookahead にした。

#153: PlanDocsCheck.stale を追加し、直下に 14 日より長く置かれた plan/spec を
検出する。today は呼び出し側が渡す (純粋関数を日付非依存に保つ)。判定は mtime
ではなくファイル名の日付プレフィックスに対して行う。失敗メッセージに
「issue 未起票なら先に gh issue create」の 1 行を足した。

mutation で実証済み: 閾値 14→9999 で 1 件、14→0 で 2 件、ISSUE_PREFIX を
戻すと 1 件、拡張子分岐の削除で 2 件が fail する。

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0132zVdwbnUR3u7o7uhhsqGk
EOF
)"
```

---

### Task 2: 依存の明示宣言と ViewInspector の strict pin (#154 / #152)

**Files:**
- Modify: `app/Gemfile`
- Modify: `app/Gemfile.lock` (`bundle install` が生成)
- Modify: `app/bin/gitignore-doctor-expectations.txt`
- Modify: `app/Podfile`
- Modify: `app/Podfile.lock` (`bundle exec pod install` が生成)

**Interfaces:**
- Consumes: Task 1 の成果物には依存しない (並行実施可能だが、同じブランチなので順に行う)
- Produces: `app/Gemfile` の `DEPENDENCIES` に `minitest`、`app/Podfile.lock` の `DEPENDENCIES` に `ViewInspector (= 0.10.3)`

- [ ] **Step 1: Gemfile に minitest を明示宣言する**

`app/Gemfile` の末尾に追加する。

```ruby
# Issue #154: bin/test_*.rb (7 本) は素の `require 'minitest/autorun'` を使うが、
# minitest は cocoapods-core → activesupport の transitive 依存としてのみ
# lock に入っていた。CocoaPods が activesupport を落とすと 7 本の checker の
# unit test が全部 LoadError で壊れるため、直接の依存として宣言する。
# `rescue LoadError` ガードは足さない — ガード付きの minitest はテストを黙って
# スキップし、ルール 27 が警告する silent green の罠そのものになる。
gem "minitest", "~> 5.27"
```

- [ ] **Step 2: bundle install して lock を更新し、解決バージョンが変わらないことを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle install 2>&1 | tail -3 && git diff app/Gemfile.lock`

Expected: `Gemfile.lock` の差分は `DEPENDENCIES` セクションへの `minitest (~> 5.27)` の 1 行追加のみ。`minitest (5.27.0)` の解決バージョンは変わらない (`~> 5.27` = `>= 5.27, < 6.0` で、activesupport の `>= 5.1, < 6` と両立する)。

**バージョンが 5.27.0 から動いていたら止めて報告すること。**

- [ ] **Step 3: minitest が直接依存として届いていることを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && /usr/bin/grep -A3 "^DEPENDENCIES" Gemfile.lock && bundle exec ruby bin/test_plan_docs_check.rb 2>&1 | tail -1`

Expected: `DEPENDENCIES` に `cocoapods (= 1.16.2)` と `minitest (~> 5.27)` が並ぶ。テストは `20 runs, 53 assertions, 0 failures, 0 errors, 0 skips`。

- [ ] **Step 4: gitignore expectations に specs/ を足す**

`app/bin/gitignore-doctor-expectations.txt` の `keep:   docs/superpowers/plans/archive/` の次の行に追加する (`specs/archive/` の直前に置いて plans → specs の順を保つ)。

```text
keep:   docs/superpowers/specs/
```

- [ ] **Step 5: doctor を実行して期待件数が 1 増えることを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make gitignore-check 2>&1 | tail -2`

Expected: `✅ gitignore-doctor: 7 expectation(s) satisfied` (追加前は 6)

件数が 6 のままなら編集が反映されていない。**`bin/gitignore-doctor.rb` は `FIXTURE_FILE` をハードコードしており ARGV を読まないので、引数で別ファイルを渡す確認は無効。**

- [ ] **Step 6: Podfile の ViewInspector を strict pin にする**

`app/Podfile` のテスト用 pod のコメントブロックと 3 行を次で置き換える。置き換える範囲は「`# …一気に上げうる。ViewInspector は patch 差…`」で始まるコメントから `pod 'ViewInspector', '~> 0.10.3'` までの全体。

```ruby
    # Quick / Nimble は optimistic 制約 (`~> 7.6` = `>= 7.6, < 8.0`) で major 越え
    # だけを止める。patch は Podfile.lock が実質のピンとして押さえている。
    #
    # ViewInspector だけは strict pin にしてある (#152)。0.10.2 → 0.10.3 の patch
    # 差だけで ModernTimerViewSpec の accessibility テスト 2 件の結果が反転した
    # 実例があるため (#73 / PR #150)、アップグレードを必ず明示的な Podfile 編集に
    # する。
    #
    # 注意: lock は万能ではない。引数なしの `bundle exec pod update` と
    # Podfile.lock の喪失は lock を無視して解決し直す
    # (cocoapods-1.16.2/lib/cocoapods/installer/analyzer.rb:934-947 の
    # `update_mode == :all` / `!lockfile` 分岐)。更新は必ず pod を名指しした
    # `bundle exec pod update <pod>` で行う。
    pod 'Quick', '~> 7.6'
    pod 'Nimble', '~> 13.7'
    pod 'ViewInspector', '0.10.3'
```

- [ ] **Step 7: pod install して lock の差分が想定どおりか確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec pod install 2>&1 | tail -5 && git diff Podfile.lock`

Expected: `Podfile.lock` の差分は 2 行だけ。

1. `DEPENDENCIES:` の `- ViewInspector (~> 0.10.3)` → `- ViewInspector (= 0.10.3)`
2. `PODFILE CHECKSUM:` の値

`PODS:` の `- ViewInspector (0.10.3)` と `SPEC CHECKSUMS:` の `ViewInspector: 41ca945fbd364118b48113a8cf2b9fb528f581e0` は**変わらない** (解決バージョンが同じなので pod バイナリは同一)。**これ以外の差分が出たら止めて報告すること。**

- [ ] **Step 8: pbxproj が安定していることを確認する (ルール 28)**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make sort && git status --short`

Expected: `LeafTimer.xcodeproj/project.pbxproj` が `git status` に出ない (= `pod install` が pbxproj を書き換えていない)。出た場合は差分を確認し、意味のある変更か再シリアライズのノイズかを報告する。

- [ ] **Step 9: cocoapods-lock-check を通す**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make cocoapods-lock-check 2>&1 | tail -2`

Expected: `lock-check passed` を含む ✅ 行が出る (`Gemfile.lock` と `Podfile.lock` の `COCOAPODS:` 行が 1.16.2 で一致)。

- [ ] **Step 10: コミットする**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/Gemfile app/Gemfile.lock app/bin/gitignore-doctor-expectations.txt app/Podfile app/Podfile.lock && git commit -m "$(cat <<'EOF'
build(#154/#152): minitest を明示宣言し ViewInspector を strict pin にする

#154: bin/test_*.rb (7 本) が依存する minitest は cocoapods-core →
activesupport の transitive 依存としてのみ lock に入っていた。CocoaPods が
activesupport を落とすと 7 本の checker の unit test が全部 LoadError で壊れる
ため、`gem "minitest", "~> 5.27"` を直接の依存として宣言する。解決バージョンは
5.27.0 のまま変わらない。あわせて gitignore-doctor-expectations.txt に
`keep: docs/superpowers/specs/` を足し、4 エントリの非対称を解消した
(6 → 7 expectations)。

#152: ViewInspector を '0.10.3' に strict pin。0.10.2 → 0.10.3 の patch 差だけ
で a11y テスト 2 件が反転した実例 (#73 / PR #150) があるのは ViewInspector だけ
なので、証拠のある側だけ厳しくする。Quick / Nimble は `~>` 据え置き。
Podfile.lock の差分は DEPENDENCIES 1 行と CHECKSUM のみで、解決バージョンと
SPEC CHECKSUMS は不変 (pod バイナリは同一)。

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0132zVdwbnUR3u7o7uhhsqGk
EOF
)"
```

---

### Task 3: CLAUDE.md ルール 43 / 44 の改訂 (#152 N1 / #153 N2)

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Task 2 で確定した Podfile の制約 (Quick `~> 7.6` / Nimble `~> 13.7` / ViewInspector `'0.10.3'`)、Task 1 で確定した `STALE_DAYS = 14`
- Produces: なし (doc のみ)

- [ ] **Step 1: 同じ話題を扱う既存行を洗い出す (ルール 45)**

Run: `cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -n "ViewInspector\|0\.10\.3\|strict pin\|pod update\|archive/\|plan-docs-check" CLAUDE.md`

期待される既知のヒット: ルール 7 (`~> 0.10.3` を教訓の実例として引用)、ルール 43 (テスト方針と pod 制約)、ルール 44 (plan 命名と archive)。**これ以外の行がヒットしたら、その行も新しい方針と矛盾しないか確認してから次へ進むこと。**

ルール 7 は「演算子の意味を推測で書かず実測しろ」という教訓の記述で、`~> 0.10.3` を**過去の誤りの実例**として引用している。Podfile の現状を主張する文ではないので**変更しない**。

- [ ] **Step 2: ルール 43 を書き換える**

`CLAUDE.md` のルール 43 の「`app/Podfile` のテスト用 pod は `~>` で制約する (#149):」以降を、次で置き換える (前半の XCTest / Quick/Nimble 新規追加禁止の部分はそのまま残す)。

```text
`app/Podfile` のテスト用 pod の制約は 2 段構えにしてある (#149 / #152): Quick `~> 7.6` / Nimble `~> 13.7` は optimistic 制約で major 越えだけを止め、**ViewInspector は strict pin `'0.10.3'`** — #150 で 0.10.2 → 0.10.3 の patch 差だけで `ModernTimerViewSpec` の accessibility テスト 2 件の結果が変わったため、patch も含めてアップグレードを明示的な Podfile 編集にしている。**`~>` は patch を固定しない** (`~> 7.6` = `>= 7.6, < 8.0`) ので、Quick/Nimble の patch を止めているのは `Podfile.lock` だけ。その lock も万能ではなく、**引数なしの `bundle exec pod update` と `Podfile.lock` の喪失は lock を無視して解決し直す** (`cocoapods-1.16.2/lib/cocoapods/installer/analyzer.rb:934-947` の `update_mode == :all` / `!lockfile` 分岐) — 更新は必ず pod を名指しした `bundle exec pod update <pod>` で行う。
```

- [ ] **Step 3: ルール 44 の最終文を書き換え、滞留検出を追記する**

ルール 44 の末尾 2 文を次で置き換える。

置き換え前:

```text
旧規則で書かれた歴史はリネームせず、日付プレフィックスのみを要求する。`make plan-docs-check` (tests チェーン内) がこの命名を検証する。
```

置き換え後:

```text
`archive/` 配下は日付プレフィックスのみを要求する (旧規則で書かれた歴史はリネームしない)。`make plan-docs-check` (tests チェーン内) がこの命名を検証し、あわせて**直下に 14 日より長く置かれた plan/spec を滞留として fail させる** (#153。判定は mtime でなくファイル名の日付プレフィックス)。厳格名は保存前に issue 番号を要求するので、**issue 未起票の題材は先に `gh issue create` してから** plan/spec を保存する (`drafts/` のような逃げ道は作らない)。
```

- [ ] **Step 4: 自己矛盾が残っていないか再確認する (ルール 45)**

Run: `cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -n "ViewInspector\|0\.10\.3\|~> で制約\|旧規則で書かれた歴史" CLAUDE.md`

Expected: 「`app/Podfile` のテスト用 pod は `~>` で制約する」という旧文言が残っていない。「旧規則で書かれた歴史はリネームせず、日付プレフィックスのみを要求する」という旧文言が残っていない。

- [ ] **Step 5: コミットする**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add CLAUDE.md && git commit -m "$(cat <<'EOF'
docs(#152/#153): CLAUDE.md ルール 43/44 を新しい制約に合わせる

ルール 43: ViewInspector の strict pin を反映し、「テスト用 pod は ~> で制約
する」という一律の記述をやめて 2 段構え (Quick/Nimble は optimistic、
ViewInspector は strict) に書き換えた。あわせて N1 の指摘を反映し、lock が
無視される条件を「pod を名指しした update を叩いた時だけ」から「引数なしの
pod update と Podfile.lock の喪失」に正した (analyzer.rb:934-947 の実装)。

ルール 44: N2 の指摘を反映し、最終文の主語を「旧規則で書かれた歴史」から
「archive/ 配下」に正した (checker の ARCHIVE_NAME は archive/ 全体に適用
される)。滞留検出 14 日と、issue 未起票の題材は先に gh issue create する方針を
追記した。

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0132zVdwbnUR3u7o7uhhsqGk
EOF
)"
```

---

### Task 4: 全体検証・archive 移動・PR 作成

**Files:**
- Move: `docs/superpowers/plans/2026-09-18-issue-152-153-154-155-checker-hardening-bundle.md` → `docs/superpowers/plans/archive/`
- Move: `docs/superpowers/specs/2026-09-18-issue-152-153-154-155-checker-hardening-bundle.md` → `docs/superpowers/specs/archive/`

**Interfaces:**
- Consumes: Task 1〜3 のすべての変更
- Produces: PR

- [ ] **Step 1: make tests を通す**

Run (Bash timeout は `600000`):

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` が出力に含まれ、`** TEST FAILED **` / `Error 6x` / `No rule to make target` が含まれないこと。あわせて precheck 側の ✅ 行 (`plan-docs-check passed` / `gitignore-doctor: 7 expectation(s) satisfied` / `lock-check passed`) が出ていること、`⚠️ skipped` が出ていないこと (ルール 27)。

`Mach error -308 (ipc/mig) server died` / `Lost connection to testmanagerd` 系の FAIL は Simulator インフラ起因の偽 FAIL。コード原因と診断する前に次を実行して 1 回リトライすること (ルール 1):

```bash
xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

- [ ] **Step 2: plan / spec を archive へ移す (ルール 44)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
  git mv docs/superpowers/plans/2026-09-18-issue-152-153-154-155-checker-hardening-bundle.md docs/superpowers/plans/archive/ && \
  git mv docs/superpowers/specs/2026-09-18-issue-152-153-154-155-checker-hardening-bundle.md docs/superpowers/specs/archive/
```

- [ ] **Step 3: plan-docs-check で直下が空になったことを確認する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec ruby bin/plan-docs-check.rb`

Expected: `✅ plan-docs-check passed (root: plans 0 / specs 0, archive: plans 36 / specs 13)`

- [ ] **Step 4: コミットする**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add -A docs/superpowers && git commit -m "$(cat <<'EOF'
docs(#152/#153/#154/#155): plan と spec を archive へ移動

CLAUDE.md ルール 44 に従い、PR 作成前に直下から archive/ へ移す。

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0132zVdwbnUR3u7o7uhhsqGk
EOF
)"
```

- [ ] **Step 5: 既存 PR の有無を確認してから push する (ルール 21)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/152-153-154-155-checker-hardening-bundle
```

Expected: 空 (既存 PR なし)。何か出たらそちらを更新する方針に切り替えて報告する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git push -u origin feature/152-153-154-155-checker-hardening-bundle
```

- [ ] **Step 6: PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create --base master --title "fix/build(#152/#153/#154/#155): checker 群の堅牢化バンドル" --body "$(cat <<'EOF'
PR #156 (#78/#149/#84) の final review で分離された 4 件をまとめて解消します。本番アプリのコードには触れず、変更は開発ループ側のゲートのみです。

## 変更内容

### #155 失敗理由が壊れていない構成要素を指す 3 ケース

`root_reason` / `archive_reason` の判定順を「拡張子 → 日付 → issue-NN → slug → companion」に並べ替え、`ISSUE_PREFIX` を末尾ハイフン要求から lookahead に変えました。

| 入力 | 修正前の理由 | 修正後の理由 |
| --- | --- | --- |
| `plans/2026-09-12-issue-84-fixture.MD` | slug が小文字英数… | 拡張子が小文字の .md になっていない |
| `plans/archive/2026-01-01-legacy.MD` | 日付プレフィックスで始まっていない | 拡張子が小文字の .md になっていない |
| `plans/2026-09-12-issue-84.md` | issue-NN が無い | slug が無いか、小文字英数… |

### #153 plan の archive 忘れを検出する

`PlanDocsCheck.stale` を追加し、直下に 14 日より長く置かれた plan/spec を fail させます。`today` は呼び出し側が渡すので、テストは実行日に依存しません。判定は mtime ではなくファイル名の日付プレフィックスに対して行います (mtime は `git checkout` で書き換わるため)。

`gh` は使いません (オフラインを保つ — #84 の plan で下した判断を踏襲)。issue 未起票の題材は先に `gh issue create` する方針とし、失敗メッセージにその 1 行を足しました。

### #154 checker 群の依存の堅牢化

`minitest` は `cocoapods-core → activesupport` の transitive 依存としてのみ lock に入っていました。CocoaPods が activesupport を落とすと `bin/test_*.rb` 7 本が全部 LoadError で壊れるため、`gem "minitest", "~> 5.27"` を直接宣言します。解決バージョンは 5.27.0 のまま不変です。`rescue LoadError` ガードは足していません (ルール 27 の silent green を避けるため)。

`gitignore-doctor-expectations.txt` に `keep: docs/superpowers/specs/` を足し、非対称を解消しました (6 → 7 expectations)。

### #152 ViewInspector の strict pin

ViewInspector のみ `'0.10.3'` に strict pin し、Quick / Nimble は `~>` 据え置きにしました。patch 差で結果が反転した実例 (#73 / PR #150) があるのは ViewInspector だけなので、証拠のある側だけ厳しくしています。

`Podfile.lock` の差分は `DEPENDENCIES` の 1 行と `PODFILE CHECKSUM` のみで、解決バージョンと `SPEC CHECKSUMS` は不変です (pod バイナリは同一)。

あわせて CLAUDE.md ルール 43 / 44 を改訂しました (N1: lock が無視される条件は「引数なしの `pod update`」と「`Podfile.lock` の喪失」も含む / N2: 日付プレフィックスのみの要求は `archive/` 配下全体に適用される)。

## 検証

- `bundle exec ruby bin/test_plan_docs_check.rb` → `20 runs, 53 assertions, 0 failures, 0 errors`
- mutation (ルール 8): 閾値 14→9999 で 1 件、14→0 で 2 件、`ISSUE_PREFIX` を戻すと 1 件、拡張子分岐の削除で 2 件が fail することを実証
- 古い日付の fixture で CLI が `exit=1` になることを確認 (滞留検出の正方向)
- `make gitignore-check` → `7 expectation(s) satisfied`
- `make cocoapods-lock-check` → passed
- `make sort` 後に pbxproj の差分なし
- `make tests` → `** TEST SUCCEEDED **`

Closes #152
Closes #153
Closes #154
Closes #155

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_0132zVdwbnUR3u7o7uhhsqGk
EOF
)"
```

- [ ] **Step 7: PR が作成されたことを確認して報告する**

Run: `cd /Users/shinya/workspace/claude/LeafTimer && gh pr list --state open --head feature/152-153-154-155-checker-hardening-bundle`

最終報告の全文を SendMessage で main へ送ってから idle になること (ルール 15)。

## Self-Review メモ

- **spec coverage**: spec の決定事項 3 件 (#152 pin 範囲 / #153 検出方式 / #153 doc 置き場) はそれぞれ Task 2 Step 6、Task 1 Step 3、Task 1 Step 6 + Task 3 Step 3 が実装する。spec の「スコープ外」4 項目はどのタスクにも現れない。
- **placeholder**: なし。すべてのコードステップに実コードを載せた。
- **型整合**: `PlanDocsCheck.stale` の戻り値 (`{name:, scope:, reason:}`) は `violations` と同形で、CLI が `v.merge(kind: kind)` をそのまま適用できる。`STALE_DAYS` は Task 1 で定義し Task 3 の doc が 14 という数値だけを引用する。
