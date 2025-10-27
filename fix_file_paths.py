#!/usr/bin/env python3
"""
Fix incorrect file paths in Xcode project
"""

import re

def fix_paths():
    project_path = '/Users/apple/Desktop/Tavi/Tavi.xcodeproj/project.pbxproj'

    # Read project file
    with open(project_path, 'r') as f:
        content = f.read()

    original_content = content

    # Files that have incorrect paths (starting with Tavi/Features/ instead of Features/)
    # when sourceTree is <group>
    incorrect_patterns = [
        (r'path = Tavi/Features/FaceScan3D/FaceScan3DAPI\.swift;', 'path = Features/FaceScan3D/FaceScan3DAPI.swift;'),
        (r'path = Tavi/Features/FaceScan3D/USAGE_EXAMPLE\.swift;', 'path = Features/FaceScan3D/USAGE_EXAMPLE.swift;'),
        (r'path = Tavi/Features/FaceScan3D/Integration/Face3DResultsIntegration\.swift;', 'path = Features/FaceScan3D/Integration/Face3DResultsIntegration.swift;'),
        (r'path = Tavi/Features/FaceScan3D/', 'path = Features/FaceScan3D/'),
    ]

    fixes_applied = 0
    for pattern, replacement in incorrect_patterns:
        matches = re.findall(pattern, content)
        if matches:
            content = re.sub(pattern, replacement, content)
            fixes_applied += len(matches)
            print(f"✅ Fixed {len(matches)} occurrence(s) of: {pattern}")

    if fixes_applied > 0:
        # Backup
        with open(project_path + '.backup3', 'w') as f:
            f.write(original_content)

        # Write fixed content
        with open(project_path, 'w') as f:
            f.write(content)

        print(f"\n✅ Applied {fixes_applied} path fixes")
        print(f"   Backup: Tavi.xcodeproj/project.pbxproj.backup3")
    else:
        print("ℹ️  No path fixes needed")

if __name__ == '__main__':
    fix_paths()
