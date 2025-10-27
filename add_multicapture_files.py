#!/usr/bin/env python3
"""
Add multi-capture files to Tavi.xcodeproj
"""

import uuid

# Read the project file
project_path = "Tavi.xcodeproj/project.pbxproj"
with open(project_path, 'r') as f:
    content = f.read()

# Generate UUIDs for new files
file_refs = {
    'CaptureSequence.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'MeshMerger.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
    'MeshExporter.swift': str(uuid.uuid4()).replace('-', '')[:24].upper(),
}

build_file_refs = {name: str(uuid.uuid4()).replace('-', '')[:24].upper() for name in file_refs}
utilities_group_ref = str(uuid.uuid4()).replace('-', '')[:24].upper()

# Create PBXFileReference entries
file_reference_section = "\n"
for filename, file_id in file_refs.items():
    if filename == 'CaptureSequence.swift':
        path = "Tavi/Features/FaceScan3D/Models/CaptureSequence.swift"
    else:
        path = f"Tavi/Features/FaceScan3D/Utilities/{filename}"

    file_reference_section += f'\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

# Create PBXBuildFile entries
build_file_section = "\n"
for filename, build_id in build_file_refs.items():
    file_id = file_refs[filename]
    build_file_section += f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};\n'

# Create Utilities group
utilities_group = f"""
\t\t{utilities_group_ref} /* Utilities */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_refs['MeshMerger.swift']} /* MeshMerger.swift */,
\t\t\t\t{file_refs['MeshExporter.swift']} /* MeshExporter.swift */,
\t\t\t);
\t\t\tpath = Utilities;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

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
    content = content[:insert_pos] + utilities_group + content[insert_pos:]

# Find FaceScan3D group and add Utilities
facescan3d_marker = "/* FaceScan3D */ = {"
if facescan3d_marker in content:
    facescan_start = content.find(facescan3d_marker)
    if facescan_start > 0:
        children_start = content.find("children = (", facescan_start)
        children_end = content.find(");", children_start)

        utilities_ref = f"\t\t\t\t{utilities_group_ref} /* Utilities */,\n"
        content = content[:children_end] + utilities_ref + content[children_end:]

# Find Models group and add CaptureSequence.swift
models_marker = "/* Models */ = {"
facescan_start = content.find('/* FaceScan3D */ = {')
if facescan_start > 0:
    models_start = content.find(models_marker, facescan_start)
    if models_start > 0:
        children_start = content.find("children = (", models_start)
        children_end = content.find(");", children_start)

        capture_seq_ref = f"\t\t\t\t{file_refs['CaptureSequence.swift']} /* CaptureSequence.swift */,\n"
        content = content[:children_end] + capture_seq_ref + content[children_end:]

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

print("✅ Successfully added multi-capture files to Tavi.xcodeproj")
print(f"   - CaptureSequence.swift (Models)")
print(f"   - MeshMerger.swift (Utilities)")
print(f"   - MeshExporter.swift (Utilities)")
