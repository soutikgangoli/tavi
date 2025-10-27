#!/usr/bin/env python3
"""
Add texture mapping files to Tavi.xcodeproj
"""

import uuid
import re

# Read the project file
project_path = "Tavi.xcodeproj/project.pbxproj"
with open(project_path, 'r') as f:
    content = f.read()

# Files to add
files = {
    # Models
    'TextureModels.swift': 'Tavi/Features/FaceScan3D/Models/TextureModels.swift',

    # Utilities
    'ImageQualityAnalyzer.swift': 'Tavi/Features/FaceScan3D/Utilities/ImageQualityAnalyzer.swift',
    'TextureCapture.swift': 'Tavi/Features/FaceScan3D/Utilities/TextureCapture.swift',
    'AlbedoEstimator.swift': 'Tavi/Features/FaceScan3D/Utilities/AlbedoEstimator.swift',
    'TextureBaker.swift': 'Tavi/Features/FaceScan3D/Utilities/TextureBaker.swift',
    'MeshTextureExporter.swift': 'Tavi/Features/FaceScan3D/Utilities/MeshTextureExporter.swift',
    'ExportManager.swift': 'Tavi/Features/FaceScan3D/Utilities/ExportManager.swift',

    # Views
    'TexturedMeshPreviewView.swift': 'Tavi/Features/FaceScan3D/Views/TexturedMeshPreviewView.swift',
}

# Generate UUIDs for new files
file_refs = {}
build_file_refs = {}

for filename in files.keys():
    file_refs[filename] = str(uuid.uuid4()).replace('-', '')[:24].upper()
    build_file_refs[filename] = str(uuid.uuid4()).replace('-', '')[:24].upper()

# Create PBXFileReference entries
file_reference_section = "\n"
for filename, file_id in file_refs.items():
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

# Find Models group and add TextureModels.swift
models_marker = '/* Models */ = {'
facescan_start = content.find('/* FaceScan3D */ = {')
if facescan_start > 0:
    models_start = content.find(models_marker, facescan_start)
    if models_start > 0:
        children_start = content.find("children = (", models_start)
        children_end = content.find(");", children_start)

        texture_models_ref = f"\t\t\t\t{file_refs['TextureModels.swift']} /* TextureModels.swift */,\n"
        content = content[:children_end] + texture_models_ref + content[children_end:]

# Find Utilities group and add utility files
utilities_marker = '/* Utilities */ = {'
if facescan_start > 0:
    utilities_start = content.find(utilities_marker, facescan_start)
    if utilities_start > 0:
        children_start = content.find("children = (", utilities_start)
        children_end = content.find(");", children_start)

        utility_refs = ""
        utility_files = [
            'ImageQualityAnalyzer.swift',
            'TextureCapture.swift',
            'AlbedoEstimator.swift',
            'TextureBaker.swift',
            'MeshTextureExporter.swift',
            'ExportManager.swift'
        ]

        for filename in utility_files:
            utility_refs += f"\t\t\t\t{file_refs[filename]} /* {filename} */,\n"

        content = content[:children_end] + utility_refs + content[children_end:]

# Find Views group and add TexturedMeshPreviewView.swift
views_marker = '/* Views */ = {'
if facescan_start > 0:
    views_start = content.find(views_marker, facescan_start)
    if views_start > 0:
        children_start = content.find("children = (", views_start)
        children_end = content.find(");", children_start)

        preview_ref = f"\t\t\t\t{file_refs['TexturedMeshPreviewView.swift']} /* TexturedMeshPreviewView.swift */,\n"
        content = content[:children_end] + preview_ref + content[children_end:]

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

print("✅ Successfully added texture mapping files to Tavi.xcodeproj")
print("\nModels:")
print("  - TextureModels.swift")
print("\nUtilities:")
print("  - ImageQualityAnalyzer.swift")
print("  - TextureCapture.swift")
print("  - AlbedoEstimator.swift")
print("  - TextureBaker.swift")
print("  - MeshTextureExporter.swift")
print("  - ExportManager.swift")
print("\nViews:")
print("  - TexturedMeshPreviewView.swift")
