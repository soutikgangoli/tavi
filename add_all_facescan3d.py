#!/usr/bin/env python3
"""
Add all FaceScan3D files to Xcode project
"""

import subprocess
import os

# Get all FaceScan3D Swift files
def find_swift_files(directory):
    """Recursively find all .swift files in directory"""
    swift_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.swift'):
                full_path = os.path.join(root, file)
                # Make relative to project root
                rel_path = os.path.relpath(full_path, '/Users/apple/Desktop/Tavi')
                swift_files.append(rel_path)
    return swift_files

facescan3d_dir = '/Users/apple/Desktop/Tavi/Tavi/Features/FaceScan3D'
swift_files = find_swift_files(facescan3d_dir)

print(f"Found {len(swift_files)} Swift files in FaceScan3D/")
for f in swift_files:
    print(f"  - {f}")

ruby_script = f"""
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Track stats
added_count = 0
skipped_count = 0

files_to_add = {swift_files}

files_to_add.each do |file_path|
  if File.exist?(file_path)
    # Determine group path
    parts = file_path.split('/')

    # Navigate to correct group
    current_group = project.main_group

    # Navigate through: Tavi/Features/FaceScan3D/...
    parts[0..-2].each do |part|
      next_group = current_group.groups.find {{ |g| g.display_name == part || g.name == part }}
      if next_group.nil?
        next_group = current_group.new_group(part)
      end
      current_group = next_group
    end

    filename = parts[-1]

    # Check if file already exists
    existing = current_group.files.find {{ |f| f.path == filename }}

    if existing.nil?
      # Add new file reference
      file_ref = current_group.new_file(file_path)
      target.add_file_references([file_ref])
      puts "✅ Added: #{{filename}}"
      added_count += 1
    else
      # Check if in target
      in_target = target.source_build_phase.files.any? {{ |bf| bf.file_ref == existing }}
      if !in_target
        target.add_file_references([existing])
        puts "✅ Added to target: #{{filename}}"
        added_count += 1
      else
        puts "⏭️  Already exists: #{{filename}}"
        skipped_count += 1
      end
    end
  else
    puts "❌ Not found: #{{file_path}}"
  end
end

project.save
puts "\\n" + "="*50
puts "✅ Project saved"
puts "📊 Added: #{{added_count}} files"
puts "⏭️  Skipped: #{{skipped_count}} files"
"""

# Write Ruby script
with open('/tmp/add_all_facescan3d.rb', 'w') as f:
    f.write(ruby_script)

# Execute
result = subprocess.run('ruby /tmp/add_all_facescan3d.rb', shell=True, capture_output=True, text=True)
print("\n" + "="*50)
print(result.stdout)
if result.returncode != 0:
    print("ERRORS:")
    print(result.stderr)
    exit(1)
