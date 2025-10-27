#!/usr/bin/env python3
"""
Remove duplicate file references from Xcode project
"""

import re

def remove_duplicates():
    project_path = '/Users/apple/Desktop/Tavi/Tavi.xcodeproj/project.pbxproj'

    # Read project file
    with open(project_path, 'r') as f:
        lines = f.readlines()

    # Track UUIDs to remove (keep first occurrence of each file)
    files_seen = {}
    uuids_to_remove = set()

    # Files that have duplicates
    duplicate_files = [
        'FaceMeshGeometry.swift',
        'FaceScan3DViewModel.swift',
        'ARFaceTrackingViewController.swift',
        'FaceScan3DView.swift',
        'FaceScan3DDemoView.swift'
    ]

    # First pass: identify duplicate UUIDs
    for i, line in enumerate(lines):
        for filename in duplicate_files:
            if filename in line and 'in Sources' in line:
                # Extract UUID from the line like: UUID /* filename in Sources */
                match = re.search(r'([A-F0-9]{24})\s+/\*\s+' + re.escape(filename), line)
                if match:
                    uuid = match.group(1)
                    if filename in files_seen:
                        # Duplicate found - mark for removal
                        uuids_to_remove.add(uuid)
                        print(f"Marking duplicate {filename} with UUID {uuid} for removal")
                    else:
                        files_seen[filename] = uuid
                        print(f"Keeping first occurrence of {filename} with UUID {uuid}")

    if not uuids_to_remove:
        print("✅ No duplicates found to remove")
        return

    # Backup original
    with open(project_path + '.backup2', 'w') as f:
        f.writelines(lines)

    # Second pass: remove lines containing duplicate UUIDs
    new_lines = []
    removed_count = 0

    for line in lines:
        should_keep = True
        for uuid in uuids_to_remove:
            if uuid in line:
                should_keep = False
                removed_count += 1
                print(f"Removing line with UUID {uuid}")
                break

        if should_keep:
            new_lines.append(line)

    # Write back
    with open(project_path, 'w') as f:
        f.writelines(new_lines)

    print(f"\n✅ Removed {removed_count} duplicate references")
    print(f"   Backup saved to: Tavi.xcodeproj/project.pbxproj.backup2")

if __name__ == '__main__':
    remove_duplicates()
