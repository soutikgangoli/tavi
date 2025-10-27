#!/usr/bin/env python3
"""
Remove duplicate PBXFileReference entries from Xcode project
"""

import subprocess
import re

ruby_script = """
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Track files by path and keep first occurrence
files_by_path = {}
duplicates_to_remove = []

# Collect all file references
project.files.each do |file_ref|
  next unless file_ref.path

  path_key = file_ref.path

  if files_by_path[path_key]
    # Duplicate found!
    duplicates_to_remove << file_ref
    puts "🔍 Found duplicate file reference: #{path_key}"
  else
    files_by_path[path_key] = file_ref
  end
end

puts "\\n" + "="*50
puts "📊 Found #{duplicates_to_remove.count} duplicate file references"

if duplicates_to_remove.any?
  # Remove duplicates
  duplicates_to_remove.each do |file_ref|
    # Remove from parent group
    file_ref.parent.children.delete(file_ref) if file_ref.parent

    # Remove the actual reference
    project.main_group.recursive_children_groups.each do |group|
      group.children.delete(file_ref)
    end

    puts "✅ Removed duplicate: #{file_ref.path}"
  end

  project.save
  puts "\\n✅ Project saved - removed #{duplicates_to_remove.count} duplicate file references"
else
  puts "\\n✅ No duplicate file references found"
end
"""

# Write Ruby script
with open('/tmp/remove_duplicate_file_refs.rb', 'w') as f:
    f.write(ruby_script)

# Execute
result = subprocess.run('ruby /tmp/remove_duplicate_file_refs.rb', shell=True, capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print("ERRORS:")
    print(result.stderr)
    exit(1)
