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

  # --- fix round 1 (code quality review I-1): companion suffix misattribution ---

  def test_root_rejects_invalid_companion_suffix_with_companion_reason
    # date / issue-NN / slug はすべて正しいので、reason は slug ではなく
    # companion suffix (アンダースコアが不正) を指すべき。
    v = violations(root: ['2026-09-12-issue-84-slug.SKILL_source.md'])
    assert_equal 1, v.size
    assert_includes v[0][:reason], 'companion'
  end

  def test_root_still_accepts_valid_companion_suffix
    # SLUG_OK の追加で ROOT_NAME 自体が緩まっていないことの確認 (test_root_accepts_companion_suffix と重複だが
    # 新しい root_reason 分岐が既存の GREEN ケースを壊していないことを明示する)。
    assert_empty violations(root: [VALID_COMPANION])
  end
end
