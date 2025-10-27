#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'Tavi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Define ALL new files to add
new_files = {
  'Tavi/Features/FaceScan3D/Metrics' => [
    'SkinElasticity.swift',
    'VolumeMetrics.swift',
    'RegionalAnalyzers.swift',
    'SkinTypeClassifier.swift'
  ],
  'Tavi/Features/Onboarding' => [
    'OnboardingFlow.swift'
  ],
  'Tavi/Features/User' => [
    'UserProfile.swift'
  ],
  'Tavi/Features/Recommendations' => [
    'PersonalizedRecommendationEngine.swift'
  ],
  'Tavi/Features/FaceScan3D/UI' => [
    'ComparisonView.swift',
    'CelebrationView.swift'
  ],
  'Tavi/Features/Export' => [
    'PDFReportGenerator.swift'
  ],
  'Tavi/Features/FaceScan3D/Utilities' => [
    'EdgeCaseDetector.swift',
    'EnvironmentalAdapter.swift',
    'DeviceCalibration.swift'
  ]
}

added_count = 0

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
      begin
        # Add file reference
        file_ref = group.new_file(file_path)

        # Add to build phase
        target.source_build_phase.add_file_reference(file_ref)

        puts "✅ Added #{file_path}"
        added_count += 1
      rescue => e
        puts "⚠️  Error adding #{file_path}: #{e.message}"
      end
    else
      puts "⏭️  Skipped #{file_path} (already exists)"
    end
  end
end

# Save the project
project.save

puts "\n" + "="*60
puts "PROJECT UPDATE COMPLETE!"
puts "="*60
puts "Total new files added: #{added_count}"
puts "Total files in project: #{target.source_build_phase.files.count}"
puts "\n✨ All new features integrated into Xcode project!"
