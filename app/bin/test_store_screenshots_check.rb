#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in store_screenshots_check.rb (Issue #161).
# Run: ruby bin/test_store_screenshots_check.rb
require 'minitest/autorun'
require_relative 'store_screenshots_check'

class StoreScreenshotsCheckTest < Minitest::Test
  CONFIG = {
    'locales' => %w[ja en],
    'devices' => { 'iphone' => { 'size' => [1320, 2868] } },
    'screens' => [{ 'id' => '01-timer' }]
  }.freeze

  def png(width, height)
    "\x89PNG\r\n\x1A\n".b + [13].pack('N') + 'IHDR' + [width, height].pack('NN') + "\x08\x02\x00\x00\x00".b
  end

  def complete_sizes
    { 'ja/iphone/01-timer.png' => [1320, 2868], 'en/iphone/01-timer.png' => [1320, 2868] }
  end

  def test_png_size_reads_ihdr
    assert_equal [1320, 2868], StoreScreenshotsCheck.png_size(png(1320, 2868))
  end

  def test_png_size_rejects_non_png
    assert_nil StoreScreenshotsCheck.png_size('GIF89a' + ("\x00" * 30))
  end

  def test_complete_set_has_no_violations
    assert_empty StoreScreenshotsCheck.violations(config: CONFIG, sizes: complete_sizes)
  end

  def test_missing_file_is_reported
    sizes = complete_sizes.tap { |s| s.delete('en/iphone/01-timer.png') }
    assert_equal ['missing: en/iphone/01-timer.png'], StoreScreenshotsCheck.violations(config: CONFIG, sizes: sizes)
  end

  def test_off_by_one_size_is_reported
    sizes = complete_sizes.merge('ja/iphone/01-timer.png' => [1320, 2867])
    assert_equal ['wrong size: ja/iphone/01-timer.png is 1320x2867, expected 1320x2868'],
                 StoreScreenshotsCheck.violations(config: CONFIG, sizes: sizes)
  end

  def test_non_png_is_reported
    sizes = complete_sizes.merge('ja/iphone/01-timer.png' => nil)
    assert_equal ['not a PNG: ja/iphone/01-timer.png'], StoreScreenshotsCheck.violations(config: CONFIG, sizes: sizes)
  end

  def test_unexpected_file_is_reported
    sizes = complete_sizes.merge('ja/iphone/99-old.png' => [1320, 2868])
    assert_equal ['unexpected: ja/iphone/99-old.png'], StoreScreenshotsCheck.violations(config: CONFIG, sizes: sizes)
  end
end
