#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in dynamic_type_check.rb.
# Run: ruby bin/test_dynamic_type_check.rb
require 'minitest/autorun'
require_relative 'dynamic_type_check'

class DynamicTypeCheckTest < Minitest::Test
  # --- RED: 検出されなければならない ----------------------------------------

  def test_detects_single_line_fixed_size
    swift = 'Text("hi").font(.system(size: 15, weight: .medium))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  # TimerView.swift:52-55 は .font(.system( の直後で改行している。行アンカーの
  # grep はここを取りこぼし 39 件に見える (改行を潰して数えると実際は 40 件)。
  # 行単位で照合する実装はこのテストで落ちる。
  def test_detects_multiline_fixed_size
    swift = <<~SWIFT
      Text(time)
          .font(.system(
              size: 78, weight: .bold, design: .monospaced
          )
          )
    SWIFT
    assert_equal [2], DynamicTypeCheck.violations(swift)
  end

  def test_reports_line_number_of_every_occurrence
    swift = <<~SWIFT
      Text("a").font(.system(size: 15))
      Text("b")
      Text("c").font(.system(size: 20))
    SWIFT
    assert_equal [1, 3], DynamicTypeCheck.violations(swift)
  end

  def test_detects_decimal_size
    swift = 'Text("a").font(.system(size: 15.5))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  # Issue #108: Font.custom(fixedSize:) / UIFont.systemFont も Dynamic Type を無効化する。
  # Font.custom(_:size:) は Apple 公式ドキュメントどおり body text style に追従して
  # スケールするので違反ではない (Font.custom(_:fixedSize:) が固定サイズの API)。
  def test_detects_font_custom_fixed_size
    swift = 'Text("a").font(Font.custom("Avenir", fixedSize: 15))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  def test_detects_font_custom_shorthand_fixed_size
    swift = 'Text("a").font(.custom("Avenir", fixedSize: 15))'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  def test_detects_uifont_system_font_fixed_size
    swift = 'label.font = UIFont.systemFont(ofSize: 15)'
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  def test_detects_uifont_bold_system_font_multiline
    swift = <<~SWIFT
      label.font = UIFont.boldSystemFont(
          ofSize: 17
      )
    SWIFT
    assert_equal [1], DynamicTypeCheck.violations(swift)
  end

  # --- GREEN: 検出されてはならない ------------------------------------------

  def test_ignores_scaled_metric_variable
    swift = 'Text(time).font(.system(size: timerFontSize, weight: .bold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  # 設計 2 で実際に書くコードは min(timerFontSize, 110) であり、数値リテラル
  # 110 を含む。「括弧内に数字があれば違反」という素朴な実装はこれを誤検出し、
  # ガードが自分自身の PR を落とす。判定は「size: の直後のトークンが
  # 数値リテラルか」でなければならない。
  def test_ignores_capped_scaled_metric
    swift = 'Text(time).font(.system(size: min(timerFontSize, 110), weight: .bold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  # 置換後のコード。design: / weight: を保持する正しい書き方を誤検出しない。
  def test_ignores_text_style_font
    swift = 'Text("a").font(.system(.subheadline, design: .rounded, weight: .semibold))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  def test_returns_empty_for_source_without_font
    swift = 'struct Foo: View { var body: some View { Text("a") } }'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  # Issue #108: Font.custom(_:size:) は body text style に追従してスケールするので許可。
  def test_ignores_font_custom_scaling_size
    swift = 'Text("a").font(Font.custom("Avenir", size: 15))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  def test_ignores_font_custom_relative_to
    swift = 'Text("a").font(.custom("Avenir", size: 15, relativeTo: .body))'
    assert_empty DynamicTypeCheck.violations(swift)
  end

  def test_ignores_uifont_preferred_font
    swift = 'label.font = UIFont.preferredFont(forTextStyle: .body)'
    assert_empty DynamicTypeCheck.violations(swift)
  end
end
