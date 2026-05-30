#!/usr/bin/env ruby
# frozen_string_literal: true

# xcode-precheck: fast pre-flight checks before `xcodebuild test`.
#
# Catches two classes of silent/confusing failure observed in this repo:
#   1. The Makefile `-destination` simulator is not installed (Issue #9):
#      surfaces a clear message + available alternatives instead of a cryptic
#      "Unable to find a destination" deep in the xcodebuild log.
#   2. A Swift file exists on disk but is attached to no target (Issue #15):
#      such a file silently compiles/tests nothing. Pre-existing orphans are
#      grandfathered via a committed baseline, so only NEWLY orphaned files
#      fail the gate. Regenerate the baseline with `--update-baseline`.
#
# Usage:
#   ruby bin/xcode-precheck.rb              # run checks, non-zero exit on failure
#   ruby bin/xcode-precheck.rb --update-baseline   # rewrite the orphan baseline
#
# Exit code 0 = all checks passed; non-zero = at least one check failed.

require 'pathname'
require_relative 'xcode_precheck'

# The orphan check needs the `xcodeproj` gem to read target membership. Because
# `precheck` runs as part of `make tests`, a hard `require` would turn a green
# build red with a LoadError on any machine without the gem — exactly the
# managed-CI-toolchain trap. Guard it: skip the orphan check when absent, still
# run the (gem-free) destination check, and never fail purely for a missing gem.
XCODEPROJ_AVAILABLE =
  begin
    require 'xcodeproj'
    true
  rescue LoadError
    false
  end

PROJECT_DIR   = File.expand_path('..', __dir__)            # app/
PROJECT_PATH  = File.join(PROJECT_DIR, 'LeafTimer.xcodeproj')
MAKEFILE_PATH = File.join(PROJECT_DIR, 'Makefile')
BASELINE_FILE = File.join(__dir__, 'xcode-precheck-orphans.txt')
SOURCE_DIRS   = %w[LeafTimer LeafTimerTests LeafTimerUITests].freeze

def rel(path)
  Pathname.new(path).relative_path_from(Pathname.new(PROJECT_DIR)).to_s
end

# --- gather inputs ----------------------------------------------------------

def disk_swift_files
  SOURCE_DIRS.flat_map { |d| Dir.glob(File.join(PROJECT_DIR, d, '**', '*.swift')) }
             .map { |f| rel(f) }.uniq.sort
end

def attached_swift_files
  project = Xcodeproj::Project.open(PROJECT_PATH)
  attached = []
  project.targets.each do |target|
    target.source_build_phase.files.each do |build_file|
      ref = build_file.file_ref
      next unless ref.respond_to?(:real_path)

      path = ref.real_path.to_s
      attached << rel(path) if path.end_with?('.swift')
    end
  end
  attached.uniq
end

def load_baseline
  return [] unless File.exist?(BASELINE_FILE)

  File.readlines(BASELINE_FILE, chomp: true)
      .map(&:strip)
      .reject { |l| l.empty? || l.start_with?('#') }
end

BASELINE_HEADER = <<~HEADER
  # xcode-precheck orphan baseline — Swift files on disk attached to no target.
  # These are grandfathered (pre-existing dead/unwired code); only NEW orphans
  # fail `make precheck`. Regenerate with: ruby bin/xcode-precheck.rb --update-baseline
HEADER

def write_baseline(orphans)
  File.write(BASELINE_FILE, BASELINE_HEADER + orphans.sort.join("\n") + "\n")
end

# --- --update-baseline mode -------------------------------------------------

if ARGV.include?('--update-baseline')
  unless XCODEPROJ_AVAILABLE
    warn '❌ --update-baseline requires the xcodeproj gem (gem install xcodeproj)'
    exit 1
  end
  report = XcodePrecheck.orphan_report(disk_swift_files, attached_swift_files, [])
  write_baseline(report[:all_orphans])
  puts "✅ Wrote #{report[:all_orphans].size} orphan(s) to #{rel(BASELINE_FILE)}"
  exit 0
end

# --- run checks -------------------------------------------------------------

failures = []

# Check 1: simulator destination availability
makefile_text = File.exist?(MAKEFILE_PATH) ? File.read(MAKEFILE_PATH) : ''
simctl_text   = `xcrun simctl list devices available 2>/dev/null`
destination   = XcodePrecheck.destination_name(makefile_text)

if destination.nil?
  puts '⚠️  destination: no `-destination name=` found in Makefile (skipped)'
elsif XcodePrecheck.simulator_available?(destination, simctl_text)
  puts "✅ destination: simulator \"#{destination}\" is available"
else
  failures << 'destination'
  puts "❌ destination: simulator \"#{destination}\" is NOT installed"
  suggestions = XcodePrecheck.iphone_suggestions(simctl_text)
  puts "   available iPhone simulators: #{suggestions.join(', ')}" unless suggestions.empty?
  puts '   → install it in Xcode, or update the Makefile -destination name='
end

# Check 2: orphan Swift files (new orphans vs grandfathered baseline)
if XCODEPROJ_AVAILABLE
  report = XcodePrecheck.orphan_report(disk_swift_files, attached_swift_files, load_baseline)

  if report[:new_orphans].empty?
    grandfathered = report[:all_orphans].size
    puts "✅ targets: no new orphan Swift files (#{grandfathered} grandfathered in baseline)"
  else
    failures << 'orphans'
    puts "❌ targets: #{report[:new_orphans].size} Swift file(s) attached to no target:"
    report[:new_orphans].sort.each { |f| puts "   - #{f}" }
    puts '   → attach with: ruby bin/add-to-target.rb LeafTimer.xcodeproj <file> <Target> <Group>'
    puts '   → or, if intentionally unwired, grandfather it: ruby bin/xcode-precheck.rb --update-baseline'
  end

  unless report[:resolved].empty?
    puts "ℹ️  baseline: #{report[:resolved].size} stale entry(ies) no longer orphan; " \
         'consider `--update-baseline` to trim'
  end
else
  puts '⚠️  targets: orphan check skipped (xcodeproj gem not installed — `gem install xcodeproj`)'
end

# --- result -----------------------------------------------------------------

if failures.empty?
  puts '✅ xcode-precheck passed'
  exit 0
else
  warn "❌ xcode-precheck failed: #{failures.join(', ')}"
  exit 1
end
