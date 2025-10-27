#!/usr/bin/env python3
"""
Add new 3D scan flow files to Xcode project
"""

import subprocess
import sys

def run_command(cmd):
    """Execute shell command"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
    print(result.stdout)
    return True

def add_files_to_project():
    """Add missing files using gem install xcodeproj approach"""

    # Files that need to be added
    files_to_add = [
        "Tavi/Features/FaceScan3D/Views/Scan3DFlowView.swift",
    ]

    print("Adding files to Tavi project...")

    # Use a simple Ruby script to add files
    ruby_script = """
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find or create FaceScan3D group
main_group = project.main_group
tavi_group = main_group.groups.find { |g| g.name == 'Tavi' } || main_group.new_group('Tavi')
features_group = tavi_group.groups.find { |g| g.display_name == 'Features' } || tavi_group.new_group('Features')
facescan_group = features_group.groups.find { |g| g.display_name == 'FaceScan3D' } || features_group.new_group('FaceScan3D')
views_group = facescan_group.groups.find { |g| g.display_name == 'Views' } || facescan_group.new_group('Views')

# Add Scan3DFlowView.swift
file_path = 'Tavi/Features/FaceScan3D/Views/Scan3DFlowView.swift'
if File.exist?(file_path)
  file_ref = views_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "✅ Added Scan3DFlowView.swift"
else
  puts "❌ File not found: #{file_path}"
end

project.save
puts "✅ Project saved"
"""

    # Write Ruby script to temp file
    with open('/tmp/add_files.rb', 'w') as f:
        f.write(ruby_script)

    # Execute Ruby script
    success = run_command('ruby /tmp/add_files.rb')

    if success:
        print("\n✅ Successfully added files to project")
    else:
        print("\n❌ Failed to add files")

    return success

if __name__ == '__main__':
    add_files_to_project()
