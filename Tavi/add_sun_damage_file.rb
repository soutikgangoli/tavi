#!/usr/bin/env ruby

require 'securerandom'

# Read the project file
project_path = 'Tavi.xcodeproj/project.pbxproj'
content = File.read(project_path)

# Generate UUIDs
file_ref_uuid = SecureRandom.hex(12).upcase
build_file_uuid = SecureRandom.hex(12).upcase

# File reference entry
file_ref = "\t\t#{file_ref_uuid} /* SunDamageAnalyzer.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = SunDamageAnalyzer.swift; path = Tavi/Features/FaceScan3D/Metrics/SunDamageAnalyzer.swift; sourceTree = SOURCE_ROOT; };"

# Build file entry  
build_file = "\t\t#{build_file_uuid} /* SunDamageAnalyzer.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* SunDamageAnalyzer.swift */; };"

# Add to PBXFileReference section (after AcneAnalyzer)
content.sub!(/(\t\t2395F842D49ABD9ADA6BC372 \/\* AcneAnalyzer\.swift \*\/ = \{[^\}]+\};)/, "\\1\n#{file_ref}")

# Add to PBXBuildFile section (after AcneAnalyzer)
content.sub!(/(\t\tDB9FAA12E3BBDE338EBC34F9 \/\* AcneAnalyzer\.swift in Sources \*\/ = \{[^\}]+\};)/, "\\1\n#{build_file}")

# Add to file list in group (after AcneAnalyzer)
content.sub!(/(\t\t\t\t2395F842D49ABD9ADA6BC372 \/\* AcneAnalyzer\.swift \*\/,)/, "\\1\n\t\t\t\t#{file_ref_uuid} /* SunDamageAnalyzer.swift */,")

# Add to sources build phase
content.sub!(/(\t\t\t\tDB9FAA12E3BBDE338EBC34F9 \/\* AcneAnalyzer\.swift in Sources \*\/,)/, "\\1\n\t\t\t\t#{build_file_uuid} /* SunDamageAnalyzer.swift in Sources */,")

File.write(project_path, content)
puts "Added SunDamageAnalyzer.swift to project"
