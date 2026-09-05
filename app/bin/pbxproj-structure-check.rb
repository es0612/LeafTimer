#!/usr/bin/env ruby
# frozen_string_literal: true

# pbxproj-structure-check: verify project.pbxproj has no dangling UUID
# references and no orphan TargetAttributes (Issue #73, CLAUDE.md rule 28).
#
# Usage:
#   ruby bin/pbxproj-structure-check.rb                       # app/LeafTimer.xcodeproj
#   ruby bin/pbxproj-structure-check.rb <path/to/Foo.xcodeproj>
#
# Exit 0 = clean (or xcodeproj gem absent → skipped with a warning, rule 27);
# exit 1 = residue found or the project cannot be opened.

require 'set'
require_relative 'pbxproj_structure_check'

XCODEPROJ_AVAILABLE =
  begin
    require 'xcodeproj'
    true
  rescue LoadError
    false
  end

unless XCODEPROJ_AVAILABLE
  warn '⚠️  pbxproj-structure-check skipped (xcodeproj gem not available — run under `bundle exec`)'
  exit 0
end

PROJECT_DIR = File.expand_path('..', __dir__) # app/
path = ARGV[0] || File.join(PROJECT_DIR, 'LeafTimer.xcodeproj')

unless File.directory?(path)
  warn "❌ pbxproj-structure-check failed: #{path} が無い"
  exit 1
end

# 参照 UUID ⊆ 定義 UUID の破れは 2 クラスある。(a) 参照だけ残り定義が消えた dangling
# 参照、(b) 定義は残るが rootObject から到達できない残骸オブジェクト (PR #140 の
# XCBuildConfiguration)。Xcodeproj::Project.open は rootObject から辿れるオブジェクトしか
# instantiate しないので、(a) も (b) も referenced (raw text) - defined (parsed graph) と
# して同じ経路で表面化する。defined を raw text 側から取るように変えると (b) の検出が
# 静かに消えるので変えないこと (Issue #73 final review M-1)。
project = Xcodeproj::Project.open(path)
text    = File.read(File.join(path, 'project.pbxproj'))

report = PbxprojStructureCheck.report(
  defined_uuids: project.objects.map(&:uuid).to_set,
  referenced_uuids: PbxprojStructureCheck.referenced_uuids(text),
  target_uuids: project.targets.map(&:uuid),
  target_attribute_keys: (project.root_object.attributes['TargetAttributes'] || {}).keys
)

if report[:ok]
  puts "✅ pbxproj-structure-check passed (#{project.objects.size} objects, 0 dangling, 0 orphan TargetAttributes)"
  exit 0
end

warn "❌ pbxproj-structure-check failed: #{report[:dangling].size} dangling/unreachable UUID(s), #{report[:orphan_target_attrs].size} orphan TargetAttributes"
report[:dangling].each { |u| warn "   dangling/unreachable: #{u}" }
report[:orphan_target_attrs].each { |u| warn "   orphan TargetAttributes: #{u}" }
warn '   pbxproj を手編集せず、xcodeproj gem で残骸オブジェクトを remove_from_project してから `make sort` する (ルール 28)'
exit 1
