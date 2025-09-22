#!/usr/bin/env ruby

require 'fileutils'
require 'securerandom'

# Read the project file
project_file = 'LeafTimer.xcodeproj/project.pbxproj'
content = File.read(project_file)

# Files to add
files_to_add = [
  { path: 'LeafTimer/View/EnhancedSettingView.swift', group: 'View' },
  { path: 'LeafTimer/View/Settings/TimerSettingsSection.swift', group: 'Settings' },
  { path: 'LeafTimer/View/Settings/SoundSettingsSection.swift', group: 'Settings' },
  { path: 'LeafTimer/View/Settings/ResetSettingsSection.swift', group: 'Settings' },
]

# Generate UUIDs for each file
file_refs = {}
build_file_refs = {}

files_to_add.each do |file_info|
  # Generate two UUIDs - one for file reference, one for build file
  file_ref = SecureRandom.hex(12).upcase
  build_ref = SecureRandom.hex(12).upcase

  file_refs[file_info[:path]] = file_ref
  build_file_refs[file_info[:path]] = build_ref
end

# Find the View group UUID
view_group_match = content.match(/([A-F0-9]+) \/\* View \*\/ = \{/)
if view_group_match.nil?
  puts "Could not find View group"
  exit 1
end
view_group_uuid = view_group_match[1]
puts "Found View group UUID: #{view_group_uuid}"

# Find or create Settings group
settings_group_match = content.match(/([A-F0-9]+) \/\* Settings \*\/ = \{/)
settings_group_uuid = nil

if settings_group_match.nil?
  # Need to create Settings group
  settings_group_uuid = SecureRandom.hex(12).upcase
  puts "Creating Settings group with UUID: #{settings_group_uuid}"
else
  settings_group_uuid = settings_group_match[1]
  puts "Found Settings group UUID: #{settings_group_uuid}"
end

# Find the Sources build phase UUID
sources_phase_match = content.match(/([A-F0-9]+) \/\* Sources \*\/ = \{/)
if sources_phase_match.nil?
  puts "Could not find Sources build phase"
  exit 1
end
sources_phase_uuid = sources_phase_match[1]
puts "Found Sources build phase UUID: #{sources_phase_uuid}"

# Add file references to PBXFileReference section
pbx_file_ref_section = content.match(/(\/\* Begin PBXFileReference section \*\/.*?)(\/\* End PBXFileReference section \*\/)/m)[1]

files_to_add.each do |file_info|
  file_name = File.basename(file_info[:path])
  file_ref = file_refs[file_info[:path]]

  new_file_ref = "\t\t#{file_ref} /* #{file_name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{file_name}; sourceTree = \"<group>\"; };\n"

  # Insert before the end of PBXFileReference section
  content.sub!(/(\/\* End PBXFileReference section \*\/)/, "#{new_file_ref}\\1")
  puts "Added file reference for #{file_name}"
end

# Add build file references
pbx_build_file_section = content.match(/(\/\* Begin PBXBuildFile section \*\/.*?)(\/\* End PBXBuildFile section \*\/)/m)[1]

files_to_add.each do |file_info|
  file_name = File.basename(file_info[:path])
  file_ref = file_refs[file_info[:path]]
  build_ref = build_file_refs[file_info[:path]]

  new_build_file = "\t\t#{build_ref} /* #{file_name} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref} /* #{file_name} */; };\n"

  # Insert before the end of PBXBuildFile section
  content.sub!(/(\/\* End PBXBuildFile section \*\/)/, "#{new_build_file}\\1")
  puts "Added build file for #{file_name}"
end

# Add files to View group
view_group_content = content.match(/#{view_group_uuid} \/\* View \*\/ = \{.*?children = \((.*?)\);/m)[1]
enhanced_setting_ref = file_refs['LeafTimer/View/EnhancedSettingView.swift']

# Add EnhancedSettingView.swift to View group
if !view_group_content.include?(enhanced_setting_ref)
  # Find SettingView.swift in the group and add after it
  setting_view_line = view_group_content.match(/.*SettingView\.swift.*/)
  if setting_view_line
    new_line = "\t\t\t\t#{enhanced_setting_ref} /* EnhancedSettingView.swift */,\n"
    content.sub!(/(#{Regexp.escape(setting_view_line[0])})/, "\\1\n#{new_line}")
    puts "Added EnhancedSettingView.swift to View group"
  end
end

# Create or update Settings group
if settings_group_match.nil?
  # Create new Settings group
  settings_group_content = "\t\t#{settings_group_uuid} /* Settings */ = {\n"
  settings_group_content += "\t\t\tisa = PBXGroup;\n"
  settings_group_content += "\t\t\tchildren = (\n"

  # Add Settings files
  files_to_add.select { |f| f[:group] == 'Settings' }.each do |file_info|
    file_name = File.basename(file_info[:path])
    file_ref = file_refs[file_info[:path]]
    settings_group_content += "\t\t\t\t#{file_ref} /* #{file_name} */,\n"
  end

  settings_group_content += "\t\t\t);\n"
  settings_group_content += "\t\t\tpath = Settings;\n"
  settings_group_content += "\t\t\tsourceTree = \"<group>\";\n"
  settings_group_content += "\t\t};\n"

  # Insert Settings group after View group definition
  view_group_def = content.match(/(#{view_group_uuid} \/\* View \*\/ = \{.*?\};)/m)[0]
  content.sub!(view_group_def, "#{view_group_def}\n#{settings_group_content}")

  # Add Settings group to View group's children
  content.sub!(/(#{view_group_uuid} \/\* View \*\/ = \{.*?children = \()(.*?)(\);)/m) do |match|
    prefix = $1
    children = $2
    suffix = $3
    "#{prefix}#{children}\n\t\t\t\t#{settings_group_uuid} /* Settings */,#{suffix}"
  end

  puts "Created Settings group and added to View group"
else
  # Add files to existing Settings group
  files_to_add.select { |f| f[:group] == 'Settings' }.each do |file_info|
    file_name = File.basename(file_info[:path])
    file_ref = file_refs[file_info[:path]]

    # Add to Settings group children
    content.sub!(/(#{settings_group_uuid} \/\* Settings \*\/ = \{.*?children = \()(.*?)(\);)/m) do |match|
      prefix = $1
      children = $2
      suffix = $3

      if !children.include?(file_ref)
        "#{prefix}#{children}\n\t\t\t\t#{file_ref} /* #{file_name} */,#{suffix}"
      else
        match
      end
    end
  end
  puts "Added files to existing Settings group"
end

# Add files to Sources build phase
files_to_add.each do |file_info|
  file_name = File.basename(file_info[:path])
  build_ref = build_file_refs[file_info[:path]]

  content.sub!(/(#{sources_phase_uuid} \/\* Sources \*\/ = \{.*?files = \()(.*?)(\);)/m) do |match|
    prefix = $1
    files = $2
    suffix = $3

    if !files.include?(build_ref)
      "#{prefix}#{files}\n\t\t\t\t#{build_ref} /* #{file_name} in Sources */,#{suffix}"
    else
      match
    end
  end
end
puts "Added files to Sources build phase"

# Write the modified content back
File.write(project_file, content)
puts "Successfully updated #{project_file}"