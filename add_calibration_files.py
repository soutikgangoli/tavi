#!/usr/bin/env python3
"""
Add calibration files to Tavi.xcodeproj
"""

import uuid

# Read the project file
project_path = "Tavi.xcodeproj/project.pbxproj"
with open(project_path, 'r') as f:
    content = f.read()

# Generate UUIDs for new files
file_refs = {
    'CalibrationState.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'CalibrationOverlay.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
}

build_file_refs = {name: str(uuid.uuid4()).replace('-', '')[:24].upper() for name in file_refs}

# Create PBXFileReference entries
file_reference_section = "\n"
for filename, file_id in file_refs.items():
    if filename == 'CalibrationState.swift':
        path = "Tavi/Features/FaceScan3D/Models/CalibrationState.swift"
    else:
        path = f"Tavi/Features/FaceScan3D/Views/{filename}"

    file_reference_section += f'\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

# Create PBXBuildFile entries
build_file_section = "\n"
for filename, build_id in build_file_refs.items():
    file_id = file_refs[filename]
    build_file_section += f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};\n'

# Find and insert sections
pbx_build_file_marker = "/* Begin PBXBuildFile section */"
pbx_file_ref_marker = "/* Begin PBXFileReference section */"
pbx_sources_marker = "/* Begin PBXSourcesBuildPhase section */"

if pbx_build_file_marker in content:
    insert_pos = content.find(pbx_build_file_marker) + len(pbx_build_file_marker)
    content = content[:insert_pos] + build_file_section + content[insert_pos:]

if pbx_file_ref_marker in content:
    insert_pos = content.find(pbx_file_ref_marker) + len(pbx_file_ref_marker)
    content = content[:insert_pos] + file_reference_section + content[insert_pos:]

# Find Models group and add CalibrationState.swift
models_marker = "/* Models */ = {"
if models_marker in content and 'FaceScan3D' in content:
    # Find the Models group within FaceScan3D
    facescan_start = content.find('/* FaceScan3D */ = {')
    if facescan_start > 0:
        models_start = content.find(models_marker, facescan_start)
        if models_start > 0:
            children_start = content.find("children = (", models_start)
            children_end = content.find(");", children_start)

            calibration_state_ref = f"\t\t\t\t{file_refs['CalibrationState.swift']} /* CalibrationState.swift */,\n"
            content = content[:children_end] + calibration_state_ref + content[children_end:]

# Find Views group and add CalibrationOverlay.swift
views_marker = "/* Views */ = {"
facescan_start = content.find('/* FaceScan3D */ = {')
if facescan_start > 0:
    views_start = content.find(views_marker, facescan_start)
    if views_start > 0:
        children_start = content.find("children = (", views_start)
        children_end = content.find(");", children_start)

        calibration_overlay_ref = f"\t\t\t\t{file_refs['CalibrationOverlay.swift']} /* CalibrationOverlay.swift */,\n"
        content = content[:children_end] + calibration_overlay_ref + content[children_end:]

# Add to Sources build phase
if pbx_sources_marker in content:
    sources_start = content.find(pbx_sources_marker)
    files_start = content.find("files = (", sources_start)
    files_end = content.find(");", files_start)

    sources_section = "\n"
    for filename, build_id in build_file_refs.items():
        sources_section += f"\t\t\t\t{build_id} /* {filename} in Sources */,\n"

    content = content[:files_end] + sources_section + content[files_end:]

# Write back
with open(project_path, 'w') as f:
    f.write(content)

print("✅ Successfully added calibration files to Tavi.xcodeproj")
print(f"   - CalibrationState.swift")
print(f"   - CalibrationOverlay.swift")
