#!/usr/bin/env ruby
# frozen_string_literal: true

# store-screenshots-check: verify the composed App Store screenshots (Issue #161).
#
# Every locale x device x screen in store-screenshots/screens.json must exist as
# a PNG of exactly the device's Apple-spec size, and nothing else may be there
# (a stale file from a removed screen would otherwise be uploaded by mistake).
#
# Usage:
#   ruby bin/store-screenshots-check.rb                 # build/store-screenshots/final
#   ruby bin/store-screenshots-check.rb <final dir>     # 明示パス (fixture 用)
#
# Exit code 0 = すべて揃っている、1 = 違反あり or ディレクトリが無い。

require 'json'
require_relative 'store_screenshots_check'

APP_ROOT = File.expand_path('..', __dir__)

config = JSON.parse(File.read(File.join(APP_ROOT, 'store-screenshots', 'screens.json')))
final_dir = ARGV[0] || File.join(APP_ROOT, 'build', 'store-screenshots', 'final')

unless File.directory?(final_dir)
  warn "❌ store-screenshots-check failed: #{final_dir} が無い (make store-screenshots を先に実行)"
  exit 1
end

sizes = Dir.glob('**/*.png', base: final_dir).to_h do |relative|
  [relative, StoreScreenshotsCheck.png_size(File.binread(File.join(final_dir, relative), 32))]
end

problems = StoreScreenshotsCheck.violations(config: config, sizes: sizes)
if problems.empty?
  puts "✅ store-screenshots-check: #{sizes.size} screenshot(s) match screens.json"
else
  warn "❌ store-screenshots-check: #{problems.size} violation(s):"
  problems.each { |p| warn "   #{p}" }
  exit 1
end
