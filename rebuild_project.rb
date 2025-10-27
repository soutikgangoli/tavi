#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first
puts "Working with target: #{target.name}"

# Get the main group
main_group = project.main_group['Tavi']

# Clear existing file references and build files
puts "Clearing existing file references..."
main_group.clear
target.source_build_phase.clear
target.resources_build_phase.clear

# Find all Swift files in the Tavi directory
tavi_dir = 'Tavi'
swift_files = Dir.glob("#{tavi_dir}/**/*.swift").sort

puts "Found #{swift_files.length} Swift files"

# Create group structure
def create_group_structure(project, parent_group, path_components)
  return parent_group if path_components.empty?

  group_name = path_components.first
  group = parent_group[group_name] || parent_group.new_group(group_name)

  create_group_structure(project, group, path_components[1..-1])
end

# Add each Swift file
swift_files.each do |file_path|
  relative_path = file_path.sub("#{tavi_dir}/", '')
  path_components = relative_path.split('/')
  file_name = path_components.last
  group_path = path_components[0..-2]

  # Create group hierarchy
  if group_path.empty?
    file_group = main_group
  else
    file_group = create_group_structure(project, main_group, group_path)
  end

  # Add file reference - use relative path from Tavi group
  file_ref = file_group.new_reference(relative_path)
  file_ref.source_tree = '<group>'

  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref)

  puts "Added: #{relative_path}"
end

# Add Assets.xcassets
assets_path = "#{tavi_dir}/Assets.xcassets"
if Dir.exist?(assets_path)
  assets_ref = main_group.new_reference('Assets.xcassets')
  assets_ref.source_tree = '<group>'
  target.resources_build_phase.add_file_reference(assets_ref)
  puts "Added Assets.xcassets"
end

# Add Info.plist reference (don't add to build phases, just to project)
info_plist_path = "#{tavi_dir}/Info.plist"
if File.exist?(info_plist_path)
  info_ref = main_group.new_reference('Info.plist')
  info_ref.source_tree = '<group>'
  puts "Added Info.plist reference"
end

# Save the project
project.save

puts "\nProject rebuilt successfully!"
puts "Please clean build folder in Xcode (Shift+Cmd+K) and rebuild."
