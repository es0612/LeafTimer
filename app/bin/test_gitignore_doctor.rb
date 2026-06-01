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
