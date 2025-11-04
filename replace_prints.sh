#!/bin/bash

# Script to replace print() statements with proper logging
# Usage: ./replace_prints.sh

TAVI_DIR="/Users/apple/Desktop/Tavi/Tavi"

echo "🔍 Finding and replacing print statements..."
echo "========================================"

# Counter
total_replaced=0

# Find all Swift files (excluding tests)
find "$TAVI_DIR" -name "*.swift" -not -path "*/Tests/*" -not -path "*/TaviTests/*" | while read -r file; do
    # Count prints in this file
    count=$(grep -c "print(" "$file" 2>/dev/null || echo "0")

    if [ "$count" -gt 0 ]; then
        echo "📝 Processing: $(basename "$file") ($count prints)"

        # Determine appropriate logger based on file path
        if [[ "$file" == *"/FaceScan3D/"* ]]; then
            logger="AppLogger.faceScan"
        elif [[ "$file" == *"/Metrics/"* ]]; then
            logger="AppLogger.metrics"
        elif [[ "$file" == *"/Settings/"* ]]; then
            logger="AppLogger.settings"
        elif [[ "$file" == *"/UI/"* ]] || [[ "$file" == *"/Views/"* ]]; then
            logger="AppLogger.ui"
        elif [[ "$file" == *"/Core/"* ]]; then
            logger="AppLogger.core"
        else
            logger="AppLogger.general"
        fi

        # Create backup
        cp "$file" "${file}.backup"

        # Replace print statements
        # Pattern 1: print("message")
        sed -i '' 's/print("\(.*\)")/'$logger'.debug("\1")/g' "$file"

        # Pattern 2: print("DEBUG: message")
        sed -i '' 's/'$logger'\.debug("DEBUG: \(.*\)")/'$logger'.debug("\1")/g' "$file"

        # Pattern 3: print("ERROR: message")
        sed -i '' 's/'$logger'\.debug("ERROR: \(.*\)")/'$logger'.error("\1")/g' "$file"

        # Pattern 4: print("WARNING: message")
        sed -i '' 's/'$logger'\.debug("WARNING: \(.*\)")/'$logger'.warning("\1")/g' "$file"

        # Pattern 5: print("✅ message") or print("✓ message")
        sed -i '' 's/'$logger'\.debug("✅ \(.*\)")/'$logger'.info("✅ \1")/g' "$file"
        sed -i '' 's/'$logger'\.debug("✓ \(.*\)")/'$logger'.info("✓ \1")/g' "$file"

        # Pattern 6: print("❌ message") or print("✗ message")
        sed -i '' 's/'$logger'\.debug("❌ \(.*\)")/'$logger'.error("❌ \1")/g' "$file"
        sed -i '' 's/'$logger'\.debug("✗ \(.*\)")/'$logger'.error("✗ \1")/g' "$file"

        echo "   ✅ Replaced with $logger"
        ((total_replaced += count))
    fi
done

echo "========================================"
echo "✅ Total replacements: $total_replaced"
echo ""
echo "Backup files created with .backup extension"
echo "To remove backups: find $TAVI_DIR -name '*.backup' -delete"
