# frozen_string_literal: true

# Pure helpers for cocoapods-lock-check (Issue #143). Kept free of I/O so they
# can be unit-tested (see test_cocoapods_lock_check.rb). The CLI glue lives in
# bin/cocoapods-lock-check.rb.
#
# Why this exists: `bundle exec pod install` runs whatever cocoapods version
# Gemfile.lock pins, while Podfile.lock records the version that last wrote
# it. If the two drift, pod install re-serializes project.pbxproj differently
# and the CI sort gate (git diff --exit-code project.pbxproj) fails for a
# reason unrelated to the PR.
module CocoapodsLockCheck
  # A Gemfile.lock specs entry: exactly four spaces, the gem name, a space,
  # then the version in parens. Anchoring on the four-space indent and the
  # bare name excludes:
  #   - `cocoapods-core (1.16.2)` (different gem)
  #   - `      cocoapods-core (= 1.16.2)` (6-space dependency sub-line)
  #   - `  cocoapods (= 1.16.2)` (DEPENDENCIES block, 2-space, has `= `)
  GEMFILE_SPEC = /^ {4}cocoapods \((\d+(?:\.\d+)*)\)$/.freeze

  # Podfile.lock trailer written by pod install: `COCOAPODS: 1.16.2`
  PODFILE_TRAILER = /^COCOAPODS: *(\S+)\s*$/.freeze

  # Version of the cocoapods gem pinned by Gemfile.lock, or nil if absent.
  def self.gemfile_lock_version(gemfile_lock_text)
    m = GEMFILE_SPEC.match(gemfile_lock_text)
    m && m[1]
  end

  # Version recorded in Podfile.lock's COCOAPODS: line, or nil if absent.
  def self.podfile_lock_version(podfile_lock_text)
    m = PODFILE_TRAILER.match(podfile_lock_text)
    m && m[1]
  end

  # { ok:, gem:, pod:, reason: } — reason is nil when ok.
  def self.report(gemfile_lock_text, podfile_lock_text)
    gem = gemfile_lock_version(gemfile_lock_text)
    pod = podfile_lock_version(podfile_lock_text)
    reason =
      if gem.nil?
        'Gemfile.lock に cocoapods の specs 行が無い (bundle install 未実行 or Gemfile から消えた)'
      elsif pod.nil?
        'Podfile.lock に COCOAPODS: 行が無い'
      elsif gem != pod
        "version mismatch: Gemfile.lock=#{gem} Podfile.lock=#{pod}"
      end
    { ok: reason.nil?, gem: gem, pod: pod, reason: reason }
  end
end
