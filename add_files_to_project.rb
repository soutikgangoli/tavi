#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Define the new files to add
new_files = {
  'Tavi/Features/FaceScan3D/Processing' => [
    'FrameAverager.swift',
    'OutlierFilter.swift',
    'ICPAligner.swift',
    'MeshSmoother.swift',
    'HoleFiller.swift',
    'MeshValidator.swift',
    'LightingNormalizer.swift',
    'TextureExtractor.swift'
  ],
  'Tavi/Features/FaceScan3D/Metrics' => [
    'WrinkleAnalyzer.swift',
    'HydrationEstimator.swift',
    'PoreAnalyzer.swift',
    'PigmentationMapper.swift',
    'TemporalTracker.swift'
  ],
  'Tavi/Features/FaceScan3D/UI' => [
    'ResultsInterpretation.swift',
    'ProgressTracking.swift',
    'QualityIndicators.swift'
  ]
}

# Add each file to the project
new_files.each do |group_path, files|
  # Create or get the group
  group = project.main_group
  group_path.split('/').each do |part|
    group = group[part] || group.new_group(part)
  end

  files.each do |file|
    file_path = "#{group_path}/#{file}"

    # Check if file already exists in project
    unless group.files.any? { |f| f.path == file }
      # Add file reference
      file_ref = group.new_file(file_path)

      # Add to build phase
      target.source_build_phase.add_file_reference(file_ref)

      puts "Added #{file_path}"
    else
      puts "Skipped #{file_path} (already exists)"
    end
  end
end

# Save the project
project.save

puts "\nProject updated successfully!"
puts "Total files added: #{new_files.values.flatten.count}"
