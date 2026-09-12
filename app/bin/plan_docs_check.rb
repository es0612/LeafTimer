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

  # Sub-patterns used to tell the caller which part of the name is wrong.
  DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}-/.freeze
  ISSUE_PREFIX = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*-/.freeze
  # date + issue-NN + slug までが正しいか (companion suffix の形は問わない)。
  # root_reason がどの構成要素を指して失敗を報告するかを分けるためだけに使う。
  SLUG_OK = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*-[a-z0-9]+(?:-[a-z0-9]+)*(?:\..*)?\.md\z/.freeze

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

  # Which of the four components (date / issue-NN / slug / companion suffix)
  # failed. Ordered widest-first so the message points at the outermost
  # problem rather than a downstream symptom.
  def self.root_reason(name)
    return '日付プレフィックス YYYY-MM-DD- で始まっていない' unless DATE_PREFIX.match?(name)
    return 'issue-NN が無い (稼働中の plan/spec は対応 issue 番号を名前に持つ)' unless ISSUE_PREFIX.match?(name)
    return 'slug が小文字英数とハイフンのみになっていない' unless SLUG_OK.match?(name)

    'companion suffix が英字始まりの英数ハイフンになっていない (例: .SKILL-source)'
  end
end
