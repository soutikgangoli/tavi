#!/usr/bin/env python3
"""
Remove all duplicate file references from Xcode project
"""

import subprocess
import re

ruby_script = """
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Track files by name and their build file references
files_by_name = {}
duplicates_found = []

# Scan all build files in target
target.source_build_phase.files.each do |build_file|
  next unless build_file.file_ref

  filename = build_file.file_ref.path
  next unless filename

  if files_by_name[filename]
    # Duplicate found!
    duplicates_found << build_file
    puts "🔍 Found duplicate: #{filename}"
  else
    files_by_name[filename] = build_file
  end
end

puts "\\n" + "="*50
puts "📊 Found #{duplicates_found.count} duplicate build file references"

if duplicates_found.any?
  # Remove duplicates
  duplicates_found.each do |build_file|
    target.source_build_phase.files.delete(build_file)
    filename = build_file.file_ref ? build_file.file_ref.path : "unknown"
    puts "✅ Removed duplicate: #{filename}"
  end

  project.save
  puts "\\n✅ Project saved - removed #{duplicates_found.count} duplicates"
else
  puts "\\n✅ No duplicates found"
end
"""

# Write Ruby script
with open('/tmp/remove_all_duplicates.rb', 'w') as f:
    f.write(ruby_script)

# Execute
result = subprocess.run('ruby /tmp/remove_all_duplicates.rb', shell=True, capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print("ERRORS:")
    print(result.stderr)
    exit(1)
