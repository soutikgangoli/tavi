#!/usr/bin/env python3
"""
Script to regenerate Xcode project file with all source files
"""

import os
import hashlib
from pathlib import Path

def generate_uuid(name):
    """Generate a 24-character hex string as UUID"""
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

def find_swift_files(base_path):
    """Find all Swift files in the project"""
    swift_files = []
    for root, dirs, files in os.walk(base_path):
        # Skip hidden directories and Xcode project
        dirs[:] = [d for d in dirs if not d.startswith('.') and not d.endswith('.xcodeproj')]
        for file in files:
            if file.endswith('.swift'):
                rel_path = os.path.relpath(os.path.join(root, file), base_path)
                swift_files.append(rel_path)
    return sorted(swift_files)

def main():
    project_dir = Path("/Users/apple/Desktop/Tavi")
    tavi_dir = project_dir / "Tavi"

    # Find all Swift files
    swift_files = find_swift_files(str(tavi_dir))

    print(f"Found {len(swift_files)} Swift files:")
    for f in swift_files:
        print(f"  - {f}")

    # Generate file references
    file_refs = {}
    build_files = {}

    for swift_file in swift_files:
        file_name = os.path.basename(swift_file)
        safe_name = swift_file.replace('/', '_').replace('.swift', '')

        file_refs[swift_file] = {
            'uuid': generate_uuid(f"ref_{swift_file}"),
            'name': file_name,
            'path': swift_file
        }

        build_files[swift_file] = {
            'uuid': generate_uuid(f"build_{swift_file}"),
            'file_ref': file_refs[swift_file]['uuid']
        }

    print(f"\nGenerated {len(file_refs)} file references")
    print("\nTo complete the fix, you'll need to either:")
    print("1. Use the manual steps in regenerate_project.sh")
    print("2. Or install xcodeproj Ruby gem: gem install xcodeproj")

if __name__ == "__main__":
    main()
