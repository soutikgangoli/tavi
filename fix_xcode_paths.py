#!/usr/bin/env python3
"""
Fix Xcode project file paths and remove duplicates
"""

import sys
import re

def fix_xcode_project():
    project_path = '/Users/apple/Desktop/Tavi/Tavi.xcodeproj/project.pbxproj'

    # Read project file
    with open(project_path, 'r') as f:
        content = f.read()

    original_content = content

    # Fix incorrect paths (missing "Features/" in path)
    # Replace: Tavi/FaceScan3D/ with Tavi/Features/FaceScan3D/
    content = re.sub(
        r'(path = )"Tavi/FaceScan3D/',
        r'\1"Tavi/Features/FaceScan3D/',
        content
    )

    if content != original_content:
        # Backup original
        with open(project_path + '.backup', 'w') as f:
            f.write(original_content)

        # Write fixed content
        with open(project_path, 'w') as f:
            f.write(content)

        print("✅ Fixed Xcode project file paths")
        print("   Backup saved to: Tavi.xcodeproj/project.pbxproj.backup")
    else:
        print("ℹ️  No path fixes needed")

if __name__ == '__main__':
    fix_xcode_project()
