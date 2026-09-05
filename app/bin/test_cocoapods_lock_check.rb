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
