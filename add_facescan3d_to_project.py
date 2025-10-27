#!/usr/bin/env python3
"""
Add FaceScan3D files to Tavi.xcodeproj
"""

import uuid
import sys

# Read the project file
project_path = "Tavi.xcodeproj/project.pbxproj"
with open(project_path, 'r') as f:
    content = f.read()

# Generate UUIDs for new files
file_refs = {
    'FaceMeshGeometry.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'FaceScan3DViewModel.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'ARFaceTrackingViewController.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'FaceScan3DView.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'FaceScan3DDemoView.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
}

build_file_refs = {name: str(uuid.uuid4()).replace('-', '')[:24].upper() for name in file_refs}
group_refs = {
    'FaceScan3D': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'Models': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'ViewModels': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'Views': str(uuid.uuid4()).replace('-', '')[:24].upper(),
}

# Create PBXFileReference entries
file_reference_section = "\n"
for filename, file_id in file_refs.items():
    path = ""
    if filename == 'FaceMeshGeometry.swift':
        path = "Tavi/Features/FaceScan3D/Models/FaceMeshGeometry.swift"
    elif filename == 'FaceScan3DViewModel.swift':
        path = "Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift"
    else:
        path = f"Tavi/Features/FaceScan3D/Views/{filename}"

    file_reference_section += f'\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

# Create PBXBuildFile entries
build_file_section = "\n"
for filename, build_id in build_file_refs.items():
    file_id = file_refs[filename]
    build_file_section += f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};\n'

# Create PBXGroup entries
group_section = f"""
\t\t{group_refs['FaceScan3D']} /* FaceScan3D */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{group_refs['Models']} /* Models */,
\t\t\t\t{group_refs['ViewModels']} /* ViewModels */,
\t\t\t\t{group_refs['Views']} /* Views */,
\t\t\t);
\t\t\tpath = FaceScan3D;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{group_refs['Models']} /* Models */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_refs['FaceMeshGeometry.swift']} /* FaceMeshGeometry.swift */,
\t\t\t);
\t\t\tpath = Models;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{group_refs['ViewModels']} /* ViewModels */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_refs['FaceScan3DViewModel.swift']} /* FaceScan3DViewModel.swift */,
\t\t\t);
\t\t\tpath = ViewModels;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{group_refs['Views']} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_refs['ARFaceTrackingViewController.swift']} /* ARFaceTrackingViewController.swift */,
\t\t\t\t{file_refs['FaceScan3DView.swift']} /* FaceScan3DView.swift */,
\t\t\t\t{file_refs['FaceScan3DDemoView.swift']} /* FaceScan3DDemoView.swift */,
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

# Find Features group and add FaceScan3D
features_marker = "/* Features */ = {"
if features_marker in content:
    # Find the children array in Features group
    features_start = content.find(features_marker)
    children_start = content.find("children = (", features_start)
    children_end = content.find(");", children_start)

    # Add FaceScan3D to Features children
    insert_pos = children_end
    facescan3d_ref = f"\t\t\t\t{group_refs['FaceScan3D']} /* FaceScan3D */,\n"
    content = content[:insert_pos] + facescan3d_ref + content[insert_pos:]

# Find and insert sections
pbx_build_file_marker = "/* Begin PBXBuildFile section */"
pbx_file_ref_marker = "/* Begin PBXFileReference section */"
pbx_group_marker = "/* Begin PBXGroup section */"
pbx_sources_marker = "/* Begin PBXSourcesBuildPhase section */"

if pbx_build_file_marker in content:
    insert_pos = content.find(pbx_build_file_marker) + len(pbx_build_file_marker)
    content = content[:insert_pos] + build_file_section + content[insert_pos:]

if pbx_file_ref_marker in content:
    insert_pos = content.find(pbx_file_ref_marker) + len(pbx_file_ref_marker)
    content = content[:insert_pos] + file_reference_section + content[insert_pos:]

if pbx_group_marker in content:
    insert_pos = content.find(pbx_group_marker) + len(pbx_group_marker)
    content = content[:insert_pos] + group_section + content[insert_pos:]

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

print("✅ Successfully added FaceScan3D files to Tavi.xcodeproj")
print(f"   - Added {len(file_refs)} source files")
print(f"   - Created {len(group_refs)} groups")
