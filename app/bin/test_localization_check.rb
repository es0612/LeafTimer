#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in localization_check.rb.
# Run: ruby bin/test_localization_check.rb
require 'minitest/autorun'
require_relative 'localization_check'

class LocalizationCheckTest < Minitest::Test
  # --- code_keys ------------------------------------------------------------

  def test_code_keys_extracts_single_line_call
    swift = 'Text(NSLocalizedString("timer.title", comment: "Title"))'
    assert_equal ['timer.title'], LocalizationCheck.code_keys(swift)
  end

  # AboutSettingsSection.swift:36-39 はキーが次の行にある。行アンカーの
  # regex だとここを取りこぼし、キーを「未使用」と誤報告する。
  def test_code_keys_extracts_multiline_call
    swift = <<~SWIFT
      Text(NSLocalizedString(
          "settings.review_app_footer",
          comment: "Footer for review section"
      ))
    SWIFT
    assert_equal ['settings.review_app_footer'], LocalizationCheck.code_keys(swift)
  end

  def test_code_keys_finds_every_occurrence_in_order
    swift = <<~SWIFT
      NSLocalizedString("a", comment: "")
      NSLocalizedString("b", comment: "")
      NSLocalizedString("a", comment: "")
    SWIFT
    assert_equal %w[a b a], LocalizationCheck.code_keys(swift)
  end

  def test_code_keys_ignores_non_literal_argument
    swift = 'NSLocalizedString(someVariable, comment: "dynamic")'
    assert_empty LocalizationCheck.code_keys(swift)
  end

  # --- strings_keys ---------------------------------------------------------

  def test_strings_keys_parses_definitions
    strings = <<~STRINGS
      "timer.title" = "ポモドーロ";
      "settings.title" = "設定";
    STRINGS
    assert_equal ['timer.title', 'settings.title'], LocalizationCheck.strings_keys(strings)
  end

  def test_strings_keys_skips_block_and_line_comments
    strings = <<~STRINGS
      /*
         Localizable.strings
         "not.a.key" = "in a block comment";
      */

      // MARK: - Timer View
      // "old.key" = "コメントアウトされた定義";
      "timer.title" = "ポモドーロ";
    STRINGS
    assert_equal ['timer.title'], LocalizationCheck.strings_keys(strings)
  end

  def test_strings_keys_keeps_repeats_so_duplicates_are_detectable
    strings = <<~STRINGS
      "time.10_minutes" = "10 min";
      "time.15_minutes" = "15 min";
      "time.10_minutes" = "10 min";
    STRINGS
    assert_equal ['time.10_minutes', 'time.15_minutes', 'time.10_minutes'],
                 LocalizationCheck.strings_keys(strings)
  end

  # --- duplicate_keys -------------------------------------------------------

  def test_duplicate_keys_finds_repeated_definition
    strings = <<~STRINGS
      "a" = "1";
      "b" = "2";
      "a" = "1";
    STRINGS
    assert_equal ['a'], LocalizationCheck.duplicate_keys(strings)
  end

  def test_duplicate_keys_empty_when_all_unique
    strings = "\"a\" = \"1\";\n\"b\" = \"2\";\n"
    assert_empty LocalizationCheck.duplicate_keys(strings)
  end

  # --- report: RED パス (壊れた入力で正しく検出できるか) --------------------

  def test_report_flags_key_missing_from_one_locale
    report = LocalizationCheck.report(
      %w[timer.title settings.title],
      'ja' => "\"timer.title\" = \"ポモドーロ\";\n\"settings.title\" = \"設定\";\n",
      'en' => "\"timer.title\" = \"Pomodoro\";\n"
    )
    assert_empty report[:missing]['ja']
    assert_equal ['settings.title'], report[:missing]['en']
  end

  def test_report_flags_parity_gap_even_for_key_unused_in_code
    report = LocalizationCheck.report(
      [],
      'ja' => "\"only.in.ja\" = \"あ\";\n",
      'en' => ''
    )
    assert_equal ['only.in.ja'], report[:parity]['en']
    assert_empty report[:parity]['ja']
  end

  def test_report_flags_duplicates_per_locale
    report = LocalizationCheck.report(
      ['a'],
      'ja' => "\"a\" = \"1\";\n\"a\" = \"1\";\n",
      'en' => "\"a\" = \"1\";\n"
    )
    assert_equal ['a'], report[:duplicates]['ja']
    assert_empty report[:duplicates]['en']
  end

  def test_report_lists_unused_key_as_information
    report = LocalizationCheck.report(
      [],
      'ja' => "\"dead.key\" = \"あ\";\n",
      'en' => "\"dead.key\" = \"a\";\n"
    )
    assert_equal ['dead.key'], report[:unused]
  end

  # --- report: GREEN パス ---------------------------------------------------

  def test_report_clean_when_code_and_locales_agree
    ja = "\"a\" = \"あ\";\n\"b\" = \"い\";\n"
    en = "\"a\" = \"a\";\n\"b\" = \"b\";\n"
    report = LocalizationCheck.report(%w[a b a], 'ja' => ja, 'en' => en)
    assert_empty report[:missing]['ja']
    assert_empty report[:missing]['en']
    assert_empty report[:parity]['ja']
    assert_empty report[:parity]['en']
    assert_empty report[:duplicates]['ja']
    assert_empty report[:duplicates]['en']
    assert_empty report[:unused]
  end
end
