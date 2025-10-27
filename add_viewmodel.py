#!/usr/bin/env python3
"""
Add FaceScan3DViewModel to Xcode project
"""

import subprocess

ruby_script = """
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Navigate to FaceScan3D/ViewModels group
main_group = project.main_group
tavi_group = main_group.groups.find { |g| g.name == 'Tavi' }
features_group = tavi_group.groups.find { |g| g.display_name == 'Features' }
facescan_group = features_group.groups.find { |g| g.display_name == 'FaceScan3D' }

# Find or create ViewModels group
viewmodels_group = facescan_group.groups.find { |g| g.display_name == 'ViewModels' }
if viewmodels_group.nil?
  viewmodels_group = facescan_group.new_group('ViewModels')
end

# Add FaceScan3DViewModel.swift
file_path = 'Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift'
if File.exist?(file_path)
  # Check if already exists
  existing = viewmodels_group.files.find { |f| f.path == 'FaceScan3DViewModel.swift' }

  if existing.nil?
    file_ref = viewmodels_group.new_file(file_path)
    target.add_file_references([file_ref])
    puts "✅ Added FaceScan3DViewModel.swift to project"
  else
    # Make sure it's in the target
    if !target.source_build_phase.files.any? { |bf| bf.file_ref == existing }
      target.add_file_references([existing])
      puts "✅ Added FaceScan3DViewModel.swift to build target"
    else
      puts "ℹ️  FaceScan3DViewModel.swift already in project and target"
    end
  end
else
  puts "❌ File not found: #{file_path}"
  exit 1
end

project.save
puts "✅ Project saved"
"""

# Write Ruby script
with open('/tmp/add_viewmodel.rb', 'w') as f:
    f.write(ruby_script)

# Execute
result = subprocess.run('ruby /tmp/add_viewmodel.rb', shell=True, capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print(result.stderr)
    exit(1)
