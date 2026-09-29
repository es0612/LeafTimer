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
