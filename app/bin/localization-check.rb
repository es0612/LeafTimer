#!/usr/bin/env ruby
# frozen_string_literal: true

# localization-check: verify that every NSLocalizedString key used in the app
# source is defined in every locale's Localizable.strings, and that those
# files are internally consistent.
#
# Catches three silent failures (Issue #99, from PR #96 Rec#1):
#   1. A key typo, or a key added to only one locale. iOS falls back to
#      showing the raw key string, so this never crashes — it ships.
#   2. A key present in one locale but absent in another (parity), even if
#      no code references it yet.
#   3. A key defined twice in one file; the later definition silently wins.
#
# Usage:
#   ruby bin/localization-check.rb
#
# Exit code 0 = all checks passed; non-zero = at least one check failed.

require_relative 'localization_check'

PROJECT_DIR = File.expand_path('..', __dir__)            # app/
SOURCE_DIR  = File.join(PROJECT_DIR, 'LeafTimer')
LOCALES     = %w[ja en].freeze

def strings_path(locale)
  File.join(SOURCE_DIR, 'App', "#{locale}.lproj", 'Localizable.strings')
end

# --- gather inputs ----------------------------------------------------------

absent = LOCALES.reject { |locale| File.exist?(strings_path(locale)) }
unless absent.empty?
  warn "❌ localization-check failed: missing Localizable.strings for #{absent.join(', ')}"
  exit 1
end

# Tripwire: if the on-disk locale set drifts from LOCALES (a new .lproj added,
# or one renamed/removed), fail loudly instead of silently checking a subset.
# Globbing on Localizable.strings (not the .lproj dir) excludes Base.lproj,
# which has no such file.
found_locales = Dir.glob(File.join(SOURCE_DIR, 'App', '*.lproj', 'Localizable.strings'))
                    .map { |path| File.basename(File.dirname(path), '.lproj') }.sort
unless found_locales == LOCALES.sort
  warn "❌ localization-check failed: locale set changed (found #{found_locales.join(', ')}, expected #{LOCALES.join(', ')})"
  exit 1
end

swift_text = Dir.glob(File.join(SOURCE_DIR, '**', '*.swift')).sort.map { |f| File.read(f) }.join("\n")
code_keys  = LocalizationCheck.code_keys(swift_text)

# Guard the other false-green: if SOURCE_DIR ever moves, or the code migrates
# off NSLocalizedString entirely, the glob above yields nothing and the report
# below would find zero keys to compare — a silent, empty "pass".
if code_keys.empty?
  warn "❌ localization-check failed: no NSLocalizedString call found under #{SOURCE_DIR}"
  exit 1
end

locale_texts = LOCALES.to_h { |locale| [locale, File.read(strings_path(locale))] }
report       = LocalizationCheck.report(code_keys, locale_texts)

# --- run checks -------------------------------------------------------------

failures = []

LOCALES.each do |locale|
  keys = report[:missing][locale]
  next if keys.empty?

  failures << "missing:#{locale}"
  warn "❌ #{locale}: #{keys.size} key(s) used in code but not defined:"
  keys.each { |key| warn "   - #{key}" }
end

LOCALES.each do |locale|
  keys = report[:parity][locale]
  next if keys.empty?

  failures << "parity:#{locale}"
  warn "❌ #{locale}: #{keys.size} key(s) defined in another locale but missing here:"
  keys.each { |key| warn "   - #{key}" }
end

LOCALES.each do |locale|
  keys = report[:duplicates][locale]
  next if keys.empty?

  failures << "duplicate:#{locale}"
  warn "❌ #{locale}: #{keys.size} key(s) defined more than once (the last one wins):"
  keys.each { |key| warn "   - #{key}" }
end

unless report[:unused].empty?
  puts "ℹ️  #{report[:unused].size} key(s) defined but never referenced by NSLocalizedString:"
  report[:unused].each { |key| puts "   - #{key}" }
end

# --- result -----------------------------------------------------------------

if failures.empty?
  puts "✅ localization-check passed (#{code_keys.uniq.size} keys × #{LOCALES.size} locales)"
  exit 0
else
  warn "❌ localization-check failed: #{failures.join(', ')}"
  exit 1
end
