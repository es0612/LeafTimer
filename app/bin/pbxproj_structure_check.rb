# frozen_string_literal: true

require 'set'

# Pure helpers for pbxproj-structure-check (Issue #73, CLAUDE.md rule 28).
# Kept free of I/O so they can be unit-tested (see
# test_pbxproj_structure_check.rb). The CLI glue lives in
# bin/pbxproj-structure-check.rb.
#
# Why this exists: editing project.pbxproj through the xcodeproj gem (target
# removal, SPM reference removal) can leave two kinds of residue that a
# string grep for the removed name never sees (PR #140 measured both):
#   - a UUID referenced somewhere but no longer defined in `objects`
#   - a TargetAttributes entry keyed by a target UUID that no longer exists
module PbxprojStructureCheck
  # Xcode object UUIDs are exactly 24 upper-case hex digits.
  UUID = /\b([0-9A-F]{24})\b/.freeze

  # Every 24-hex token in the file, as a Set (definitions and references
  # alike — callers subtract the defined set to find dangling references).
  def self.referenced_uuids(pbxproj_text)
    pbxproj_text.scan(UUID).flatten.to_set
  end

  # { ok:, dangling: [uuid...], orphan_target_attrs: [uuid...] } — both
  # arrays sorted so output is stable across runs.
  def self.report(defined_uuids:, referenced_uuids:, target_uuids:, target_attribute_keys:)
    dangling = (referenced_uuids - defined_uuids).to_a.sort
    orphans  = (target_attribute_keys - target_uuids).sort
    { ok: dangling.empty? && orphans.empty?, dangling: dangling, orphan_target_attrs: orphans }
  end
end
