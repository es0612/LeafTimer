#!/usr/bin/env ruby
# frozen_string_literal: true

# dynamic-type-check: fail the build when a hard-coded font size is introduced.
#
# `.font(.system(size: 15))` ignores the user's "Larger Text" setting entirely,
# so the app stays unreadable for low-vision users no matter what they choose.
# Issue #58 removed 40 such sites; this check keeps them from coming back.
#
# The fix is a standard text style (`.subheadline`, `.caption2`, …), or — for
# the few genuinely oversized numerals — `@ScaledMetric` with a cap, e.g.
# `.font(.system(size: min(timerFontSize, 110), weight: .bold))`, which this
# check deliberately allows.
#
# Issue #108 widened the net to `Font.custom("Name", fixedSize: 15)` and
# `UIFont.systemFont(ofSize: 15)` (and its bold/italic/monospaced variants):
# they bypass Dynamic Type the same way. Use `Font.custom("Name", size: 15)`
# (scales with the body text style) / `relativeTo:` or
# `UIFont.preferredFont(forTextStyle:)` instead.
#
# Usage:
#   ruby bin/dynamic-type-check.rb
#
# Exit code 0 = no hard-coded size; non-zero = at least one found.

require_relative 'dynamic_type_check'

PROJECT_DIR = File.expand_path('..', __dir__)            # app/
SOURCE_DIR  = File.join(PROJECT_DIR, 'LeafTimer')

files = Dir.glob(File.join(SOURCE_DIR, '**', '*.swift')).sort

# Guard the false-green: if SOURCE_DIR ever moves, the glob yields nothing and
# every check below passes vacuously.
if files.empty?
  warn "❌ dynamic-type-check failed: no Swift file found under #{SOURCE_DIR}"
  exit 1
end

violations = files.flat_map do |path|
  relative = path.sub("#{PROJECT_DIR}/", '')
  DynamicTypeCheck.violations(File.read(path)).map { |line| "#{relative}:#{line}" }
end

if violations.empty?
  puts "✅ dynamic-type-check passed (#{files.size} files scanned)"
  exit 0
else
  warn "❌ dynamic-type-check failed: #{violations.size} hard-coded font size(s) found"
  violations.each { |site| warn "   - #{site}" }
  warn '   Use a text style (.subheadline / .caption2 / …) or @ScaledMetric with a cap.'
  exit 1
end
