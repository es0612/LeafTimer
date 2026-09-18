# frozen_string_literal: true

require 'date'

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
    [a-z0-9]+(?:-[a-z0-9]+)*      # lowercase hyphenated slug (digits-only is
                                  # accepted on purpose — see note below)
    (?:\.[A-Za-z][A-Za-z0-9-]*)?  # optional companion suffix, e.g. .SKILL-source
    \.md
    \z
  /x.freeze

  # Note on ROOT_NAME's slug class: [a-z0-9]+ accepts a purely numeric segment,
  # so "2026-09-12-issue-84-123.md" parses as issue 84 with slug "123". This is
  # an accepted ambiguity, not an oversight — digits have to be legal in the
  # slug position because the bundle form (issue-86-78-149-84-slug) already
  # needs digits directly after "issue-", and disallowing a numeric-only slug
  # would require distinguishing the two by context. Do not "fix" this by
  # forbidding digit-only slugs; it would break bundle names.

  # Archive name: the date prefix only. History predates the strict rule and is
  # not renamed (triage decision 2026-09-12).
  ARCHIVE_NAME = /\A\d{4}-\d{2}-\d{2}-.+\.md\z/.freeze

  # 直下に置いたまま放置された plan/spec を検出する閾値 (#153)。ルール 44 は
  # 「plan の最終タスクで archive/ へ git mv してから gh pr create する」と定めて
  # いるので、直下に居てよいのは plan を書いてから PR を立てるまでの数時間。
  # 14 日は「長期化した PR を誤検出しない」ために十分な余裕を取った値。
  STALE_DAYS = 14

  # Sub-patterns used to tell the caller which part of the name is wrong.
  # 判定順は外側から: 拡張子 → 日付 (桁数) → 日付 (実在性) → issue-NN → slug →
  # companion suffix (#155 / fix round 1 F-1)。
  # ROOT_NAME / ARCHIVE_NAME の `\.md` は case-sensitive なので、拡張子だけが
  # 大文字の入力は「その手前の構成要素が違う」ように見えてしまう。拡張子の
  # 先出しで root の .MD / archive の .MD の 2 ケースを、ISSUE_PREFIX の
  # lookahead 化 (下記) で slug 欠落の 1 ケースを解消する (拡張子の判定順そのもの
  # は slug 欠落の解消とは無関係)。
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

  # [{name:, scope: :root|:archive, reason:}] — empty when everything conforms.
  # Root violations come first, each group sorted by name so output is stable.
  def self.violations(root_names:, archive_names:)
    list = []
    root_names.sort.each do |name|
      next if ROOT_NAME.match?(name) && valid_date?(name)

      list << { name: name, scope: :root, reason: root_reason(name) }
    end
    archive_names.sort.each do |name|
      next if ARCHIVE_NAME.match?(name)

      list << { name: name, scope: :archive, reason: archive_reason(name) }
    end
    list
  end

  # Which component (extension / date / issue-NN / slug / companion suffix)
  # failed. Ordered widest-first so the message points at the outermost
  # problem rather than a downstream symptom.
  def self.root_reason(name)
    return REASON_EXT unless EXT_OK.match?(name)
    return '日付プレフィックス YYYY-MM-DD- で始まっていない' unless DATE_PREFIX.match?(name)
    return '日付プレフィックスが実在しない日付になっている (例: 2026-09-31)' unless valid_date?(name)
    return 'issue-NN が無い (稼働中の plan/spec は対応 issue 番号を名前に持つ)' unless ISSUE_PREFIX.match?(name)
    return 'slug が無いか、小文字英数とハイフンのみになっていない' unless SLUG_OK.match?(name)

    'companion suffix が英字始まりの英数ハイフンになっていない (例: .SKILL-source)'
  end

  def self.archive_reason(name)
    return REASON_EXT unless EXT_OK.match?(name)

    '日付プレフィックス YYYY-MM-DD- で始まっていない'
  end

  # 日付プレフィックスの桁数は合っていても実在しない日付 (2026-09-31 /
  # 2026-13-45 等) になっていないか。ROOT_NAME / DATE_PREFIX は `\d{4}-\d{2}-\d{2}-`
  # の桁数しか見ないので、ここでの検証が無いと stale の Date.parse が例外を
  # 投げてしまう (fix round 1 F-1)。
  #
  # violations 側は実在しない日付を「違反」として報告するが、CLI は同じ
  # root_names を stale にも渡すため入力は絞られない (fix round 2 N-1)。stale 側の
  # `next unless valid_date?(name)` は冗長な二重防壁ではなく、これが無いと
  # Date.parse が例外を投げる (mutation M6 で実証)。
  def self.valid_date?(name)
    Date.parse(name[0, 10])
    true
  rescue Date::Error
    false
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
      next unless valid_date?(name)

      age = (today - Date.parse(name[0, 10])).to_i
      next if age <= threshold_days

      { name: name, scope: :root,
        reason: "作成から #{age} 日経過している (PR 作成前に archive/ へ git mv する — CLAUDE.md ルール 44)" }
    end
  end
end
