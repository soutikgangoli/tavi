#!/bin/bash
# Script to regenerate Xcode project with all source files

# This script will help you regenerate the Xcode project
echo "To fix your Xcode project, please follow these steps:"
echo ""
echo "1. Close Xcode completely"
echo "2. In Finder, navigate to /Users/apple/Desktop/Tavi"
echo "3. Delete or rename Tavi.xcodeproj (backup is at Tavi.xcodeproj.backup)"
echo "4. Open Xcode"
echo "5. Choose File > New > Project"
echo "6. Select iOS > App, click Next"
echo "7. Set:"
echo "   - Product Name: Tavi"
echo "   - Team: (leave empty or select yours)"
echo "   - Organization Identifier: com.tavi"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Storage: Core Data"
echo "   - Uncheck 'Include Tests'"
echo "8. Save to /Users/apple/Desktop (it will create a Tavi folder)"
echo "9. When Xcode creates the new project:"
echo "   - Delete the auto-generated Swift files (keep the project)"
echo "   - Right-click on Tavi folder in project navigator"
echo "   - Select 'Add Files to Tavi...'"
echo "   - Select all folders: Core, Features, Shared"
echo "   - Make sure 'Copy items if needed' is UNCHECKED"
echo "   - Make sure 'Create groups' is selected"
echo "   - Make sure 'Tavi' target is checked"
echo "   - Click Add"
echo "10. Add the Swift Package:"
echo "   - File > Add Package Dependencies"
echo "   - Search: https://github.com/apple/swift-algorithms.git"
echo "   - Select 'swift-algorithms' and add"
echo ""
echo "OR use the automatic fix below..."
echo ""

# Alternative: Try to fix the current project programmatically
# This requires xcodeproj gem
if command -v gem &> /dev/null; then
    echo "Would you like me to attempt an automatic fix using Ruby xcodeproj gem?"
    echo "This will require installing the 'xcodeproj' gem."
    echo "Run: gem install xcodeproj"
fi
