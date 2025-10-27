#!/usr/bin/env python3
"""
Fix paths: Remove extra Tavi/ prefix from FaceScan3D file paths
The paths should be Features/FaceScan3D/... not Tavi/Features/FaceScan3D/...
"""

import re

def fix_paths():
    project_path = '/Users/apple/Desktop/Tavi/Tavi.xcodeproj/project.pbxproj'

    # Read project file
    with open(project_path, 'r') as f:
        content = f.read()

    original_content = content

    # Fix pattern: Change "path = Tavi/Features/FaceScan3D/" to "path = Features/FaceScan3D/"
    pattern = r'path = Tavi/Features/FaceScan3D/'
    replacement = 'path = Features/FaceScan3D/'

    matches = re.findall(pattern, content)
    if matches:
        content = re.sub(pattern, replacement, content)
        print(f"✅ Fixed {len(matches)} occurrence(s) of: {pattern}")

        # Backup
        with open(project_path + '.backup5', 'w') as f:
            f.write(original_content)

        # Write fixed content
        with open(project_path, 'w') as f:
            f.write(content)

        print(f"\n✅ Applied {len(matches)} path fixes")
        print(f"   Backup: Tavi.xcodeproj/project.pbxproj.backup5")
    else:
        print("ℹ️  No path fixes needed")

if __name__ == '__main__':
    fix_paths()
