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

  def test_parse_expectations_raises_on_malformed_line
    # 'keep:'/'ignore:' のタイポ等を黙って捨てると「守っているつもりで守れていない」
    # 事故になるため、malformed 行は hard fail (raise) する。
    text = "keep: app/ok\nkeeep: app/typo\n"
    err = assert_raises(GitignoreDoctor::ParseError) do
      GitignoreDoctor.parse_expectations(text)
    end
    # メッセージに行番号と該当行を含めて気づけるようにする
    assert_includes err.message, 'line 2'
    assert_includes err.message, 'keeep: app/typo'
  end

  def test_parse_expectations_raises_on_path_with_space_inline_comment
    # path にスペースを含む行は malformed として raise する。
    # gitignore のパスにスペースは通常無く、inline '# comment' の混入検出になる
    # (例 'keep: foo # because' は path が 'foo # because' になってしまう)。
    text = "keep: foo # because\n"
    err = assert_raises(GitignoreDoctor::ParseError) do
      GitignoreDoctor.parse_expectations(text)
    end
    assert_includes err.message, 'line 1'
    assert_includes err.message, 'foo # because'
  end

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
end
