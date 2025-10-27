#!/usr/bin/env python3
"""
Remove specific duplicate file reference UUIDs
"""

def remove_duplicate_refs():
    project_path = '/Users/apple/Desktop/Tavi/Tavi.xcodeproj/project.pbxproj'

    # Read project file
    with open(project_path, 'r') as f:
        lines = f.readlines()

    # UUIDs to remove (the unused duplicates)
    uuids_to_remove = [
        '13E93DCB568BCCE9227D9C24',  # Unused FaceScan3DViewModel
        '5E0407B3167AACA2C116A0FE',  # Unused Scan3DFlowView
    ]

    # Filter out lines containing these UUIDs
    new_lines = []
    skip_count = 0

    for line in lines:
        should_skip = False
        for uuid in uuids_to_remove:
            if uuid in line:
                should_skip = True
                skip_count += 1
                print(f"✅ Removing line with UUID {uuid}: {line.strip()}")
                break

        if not should_skip:
            new_lines.append(line)

    # Also need to remove from children arrays in groups
    final_lines = []
    for line in new_lines:
        modified = line
        for uuid in uuids_to_remove:
            if f'{uuid} /* ' in modified:
                print(f"✅ Removing from children array: {uuid}")
                # Skip this line entirely if it's a reference in children
                modified = None
                break

        if modified is not None:
            final_lines.append(modified)

    # Backup
    with open(project_path + '.backup4', 'w') as f:
        f.writelines(lines)

    # Write cleaned content
    with open(project_path, 'w') as f:
        f.writelines(final_lines)

    print(f"\n✅ Removed {skip_count} duplicate references")
    print(f"   Backup: Tavi.xcodeproj/project.pbxproj.backup4")

if __name__ == '__main__':
    remove_duplicate_refs()
