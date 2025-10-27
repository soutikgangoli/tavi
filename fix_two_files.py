#!/usr/bin/env python3
"""
Properly configure Scan3DFlowView.swift and FaceScan3DViewModel.swift in Xcode project
"""

import subprocess

ruby_script = """
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Files to fix
files_to_fix = [
  'Tavi/Features/FaceScan3D/Views/Scan3DFlowView.swift',
  'Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift'
]

files_to_fix.each do |file_path|
  puts "\\n" + "="*50
  puts "Processing: #{file_path}"

  # Remove all existing references to this file
  basename = File.basename(file_path)

  # Remove from build phase
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.include?(basename)
      puts "  Removing from build phase: #{build_file.file_ref.path}"
      target.source_build_phase.files.delete(build_file)
    end
  end

  # Remove file references
  project.files.each do |file_ref|
    if file_ref.path && file_ref.path.include?(basename)
      puts "  Removing file reference: #{file_ref.path}"
      file_ref.remove_from_project
    end
  end

  # Now add fresh
  if File.exist?(file_path)
    # Navigate to correct group
    # Path structure: Tavi/Features/FaceScan3D/Views or ViewModels
    parts = file_path.split('/')

    # Find the Tavi group (the one with path = Tavi)
    tavi_group = project.main_group.groups.find { |g| g.path == "Tavi" }

    if tavi_group.nil?
      puts "  ERROR: Could not find Tavi group with path=Tavi"
      next
    end

    current_group = tavi_group

    # Navigate through: Features/FaceScan3D/Views or ViewModels
    # Skip first "Tavi" since we're already in that group
    parts[1..-2].each do |part|
      next_group = current_group.groups.find { |g| g.display_name == part || g.name == part }
      if next_group.nil?
        next_group = current_group.new_group(part)
        puts "  Created group: #{part}"
      end
      current_group = next_group
    end

    # Add file reference with path relative to Tavi group
    # Since Tavi group has path=Tavi, the file path should be relative to that
    relative_path = parts[1..-1].join('/')  # Skip "Tavi/" prefix

    file_ref = current_group.new_file(file_path)
    # Override the path to be relative
    file_ref.path = relative_path

    target.add_file_references([file_ref])

    puts "  ✅ Added: #{basename}"
    puts "     Group path: #{current_group.hierarchy_path}"
    puts "     File path: #{relative_path}"
  else
    puts "  ❌ File not found: #{file_path}"
  end
end

project.save
puts "\\n" + "="*50
puts "✅ Project saved"
"""

# Write Ruby script
with open('/tmp/fix_two_files.rb', 'w') as f:
    f.write(ruby_script)

# Execute
result = subprocess.run('ruby /tmp/fix_two_files.rb', shell=True, capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print("ERRORS:")
    print(result.stderr)
    exit(1)
