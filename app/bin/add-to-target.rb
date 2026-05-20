#!/usr/bin/env ruby
# Add a Swift file reference into a Xcode project group and attach it to a target.
# Usage: add-to-target.rb <project_path> <file_path> <target_name> <group_path>
#   project_path : path to .xcodeproj (e.g. LeafTimer.xcodeproj)
#   file_path    : project-relative file path (e.g. LeafTimer/Components/Foo.swift)
#   target_name  : Xcode target (e.g. LeafTimer or LeafTimerTests)
#   group_path   : project-relative group path (e.g. LeafTimer/Components)
# Idempotent: re-running is a no-op if the file is already attached to the target.

require 'xcodeproj'

abort "usage: add-to-target.rb <project> <file> <target> <group>" if ARGV.length != 4
proj_path, file_path, target_name, group_path = ARGV

project = Xcodeproj::Project.open(proj_path)
target = project.targets.find { |t| t.name == target_name }
abort "target not found: #{target_name}" unless target

group = project.main_group.find_subpath(group_path, true)
group.set_source_tree('SOURCE_ROOT') if group.source_tree.nil? || group.source_tree.empty?

basename = File.basename(file_path)
ref = group.files.find { |f| f.path == basename || f.path == file_path }

if ref.nil?
  ref = group.new_reference(file_path)
  ref.source_tree = 'SOURCE_ROOT'
end

already_in_target = target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
if already_in_target
  puts "no-op: #{file_path} already attached to #{target_name}"
else
  target.add_file_references([ref])
  puts "added: #{file_path} -> #{target_name}"
end

project.save
