#!/usr/bin/env python3
"""
Add 3D Face Metrics files to Tavi Xcode project
"""

import sys
import os

def main():
    project_path = "Tavi.xcodeproj/project.pbxproj"

    if not os.path.exists(project_path):
        print(f"Error: {project_path} not found")
        return 1

    # Read project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Files to add
    files_to_add = [
        ("Face3DMetrics.swift", "Tavi/Features/FaceScan3D/Models/Face3DMetrics.swift"),
        ("ROIMaskGenerator.swift", "Tavi/Features/FaceScan3D/Utilities/ROIMaskGenerator.swift"),
        ("RoughnessAnalyzer.swift", "Tavi/Features/FaceScan3D/Utilities/RoughnessAnalyzer.swift"),
        ("PigmentationAnalyzer.swift", "Tavi/Features/FaceScan3D/Utilities/PigmentationAnalyzer.swift"),
        ("Face3DMetricsAnalyzer.swift", "Tavi/Features/FaceScan3D/Utilities/Face3DMetricsAnalyzer.swift"),
        ("MetricsVisualizer.swift", "Tavi/Features/FaceScan3D/Utilities/MetricsVisualizer.swift"),
        ("Face3DMetricsResultsView.swift", "Tavi/Features/FaceScan3D/Views/Face3DMetricsResultsView.swift"),
        ("FACE3D_METRICS_GUIDE.md", "Tavi/Features/FaceScan3D/FACE3D_METRICS_GUIDE.md"),
    ]

    # Check if files already exist in project
    files_already_added = []
    files_to_process = []

    for filename, filepath in files_to_add:
        if filename in content:
            files_already_added.append(filename)
        else:
            files_to_process.append((filename, filepath))

    if files_already_added:
        print(f"Files already in project: {', '.join(files_already_added)}")

    if not files_to_process:
        print("All files already added to Xcode project")
        return 0

    print(f"\nAdding {len(files_to_process)} files to Xcode project...")

    # Generate unique IDs for each file (using simple incrementing hex)
    import random
    base_id = random.randint(0x10000000, 0x99999999)

    # Build file references and build file entries
    file_refs = []
    build_files = []

    for i, (filename, filepath) in enumerate(files_to_process):
        file_id = f"{base_id + i*2:08X}000000{i:02d}00000000"
        build_id = f"{base_id + i*2 + 1:08X}000000{i:02d}00000001"

        # Determine file type
        if filename.endswith('.swift'):
            last_known_type = "sourcecode.swift"
            build_phase = "Sources"
        elif filename.endswith('.md'):
            last_known_type = "net.daringfireball.markdown"
            build_phase = None  # Don't add .md files to build phases
        else:
            last_known_type = "text"
            build_phase = None

        # Create PBXFileReference
        file_ref = f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {last_known_type}; path = {filename}; sourceTree = \"<group>\"; }};"
        file_refs.append(file_ref)

        # Create PBXBuildFile (only for Swift files)
        if build_phase == "Sources":
            build_file = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};"
            build_files.append((build_file, build_id, filename, file_id))

    # Find insertion points
    pbx_file_ref_section = content.find("/* Begin PBXFileReference section */")
    if pbx_file_ref_section == -1:
        print("Error: Could not find PBXFileReference section")
        return 1

    # Insert file references
    insert_pos = content.find("\n", pbx_file_ref_section) + 1
    content = content[:insert_pos] + "\n".join(file_refs) + "\n" + content[insert_pos:]

    # Insert build files
    if build_files:
        pbx_build_file_section = content.find("/* Begin PBXBuildFile section */")
        if pbx_build_file_section == -1:
            print("Error: Could not find PBXBuildFile section")
            return 1

        insert_pos = content.find("\n", pbx_build_file_section) + 1
        build_file_entries = "\n".join([bf[0] for bf in build_files])
        content = content[:insert_pos] + build_file_entries + "\n" + content[insert_pos:]

    # Add files to appropriate groups
    # Find FaceScan3D Models group
    models_group_pattern = "/* Models */ = {"
    models_group_pos = content.find(models_group_pattern)

    if models_group_pos != -1:
        # Find children array in Models group
        children_start = content.find("children = (", models_group_pos)
        if children_start != -1:
            children_end = content.find(");", children_start)
            # Add Face3DMetrics.swift to Models group
            for filename, filepath in files_to_process:
                if "Models" in filepath:
                    file_id = f"{base_id + files_to_process.index((filename, filepath))*2:08X}000000{files_to_process.index((filename, filepath)):02d}00000000"
                    file_entry = f"\n\t\t\t\t{file_id} /* {filename} */,"
                    content = content[:children_end] + file_entry + content[children_end:]
                    print(f"  Added {filename} to Models group")

    # Find FaceScan3D Utilities group
    utilities_group_pattern = "/* Utilities */ = {"
    utilities_group_pos = content.find(utilities_group_pattern)

    if utilities_group_pos != -1:
        # Find children array
        children_start = content.find("children = (", utilities_group_pos)
        if children_start != -1:
            children_end = content.find(");", children_start)
            # Add utility files
            for filename, filepath in files_to_process:
                if "Utilities" in filepath:
                    idx = files_to_process.index((filename, filepath))
                    file_id = f"{base_id + idx*2:08X}000000{idx:02d}00000000"
                    file_entry = f"\n\t\t\t\t{file_id} /* {filename} */,"
                    content = content[:children_end] + file_entry + content[children_end:]
                    print(f"  Added {filename} to Utilities group")

    # Find FaceScan3D Views group
    views_group_pattern = "/* Views */ = {"
    views_group_pos = content.find(views_group_pattern)

    if views_group_pos != -1:
        # Find children array
        children_start = content.find("children = (", views_group_pos)
        if children_start != -1:
            children_end = content.find(");", children_start)
            # Add view files
            for filename, filepath in files_to_process:
                if "Views" in filepath and filename.endswith('.swift'):
                    idx = files_to_process.index((filename, filepath))
                    file_id = f"{base_id + idx*2:08X}000000{idx:02d}00000000"
                    file_entry = f"\n\t\t\t\t{file_id} /* {filename} */,"
                    content = content[:children_end] + file_entry + content[children_end:]
                    print(f"  Added {filename} to Views group")

    # Find FaceScan3D root group and add documentation
    facescan3d_pattern = "/* FaceScan3D */ = {"
    facescan3d_pos = content.find(facescan3d_pattern)

    if facescan3d_pos != -1:
        children_start = content.find("children = (", facescan3d_pos)
        if children_start != -1:
            children_end = content.find(");", children_start)
            # Add .md files to FaceScan3D root
            for filename, filepath in files_to_process:
                if filename.endswith('.md'):
                    idx = files_to_process.index((filename, filepath))
                    file_id = f"{base_id + idx*2:08X}000000{idx:02d}00000000"
                    file_entry = f"\n\t\t\t\t{file_id} /* {filename} */,"
                    content = content[:children_end] + file_entry + content[children_end:]
                    print(f"  Added {filename} to FaceScan3D group")

    # Add build files to PBXSourcesBuildPhase
    if build_files:
        sources_build_phase = content.find("/* Sources */ = {")
        if sources_build_phase != -1:
            files_start = content.find("files = (", sources_build_phase)
            if files_start != -1:
                files_end = content.find(");", files_start)
                for build_file, build_id, filename, file_id in build_files:
                    build_entry = f"\n\t\t\t\t{build_id} /* {filename} in Sources */,"
                    content = content[:files_end] + build_entry + content[files_end:]
                    print(f"  Added {filename} to Sources build phase")

    # Write modified project file
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"\n✅ Successfully added {len(files_to_process)} files to Xcode project")
    print("\nRecommendation: Open Xcode and verify the project builds successfully")

    return 0

if __name__ == "__main__":
    sys.exit(main())
