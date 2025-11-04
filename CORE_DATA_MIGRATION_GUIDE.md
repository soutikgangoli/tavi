# Core Data Migration Guide

## Overview

Core Data migration is now properly configured for the Tavi app. This ensures that future schema changes won't crash the app for existing users and their data will be safely migrated.

## What Was Fixed

### 1. Version Identifiers Added
- **TaviModel v1.0**: Original model (existing user data)
- **TaviModel v2.0**: Current model with migration support

### 2. Automatic Lightweight Migration Enabled
Location: `PersistenceController.swift`

The following migration options are now enabled:
```swift
storeDescription.shouldMigrateStoreAutomatically = true
storeDescription.shouldInferMappingModelAutomatically = true
```

### 3. Model Versioning Structure
```
TaviModel.xcdatamodeld/
├── .xccurrentversion (points to v2)
├── TaviModel.xcdatamodel/ (v1.0 - for existing users)
└── TaviModel 2.xcdatamodel/ (v2.0 - current version)
```

## How It Works

### For Existing Users
1. App detects old data store is at v1.0
2. Automatic migration runs from v1.0 → v2.0
3. User data is preserved
4. App continues normally

### For New Users
1. App creates fresh data store at v2.0
2. No migration needed

## Making Future Schema Changes

When you need to add/modify/remove Core Data attributes, follow these steps:

### Step 1: Create New Model Version
```bash
# In Xcode:
# 1. Select TaviModel.xcdatamodeld in Project Navigator
# 2. Editor menu → Add Model Version
# 3. Name it "TaviModel 3"
# 4. Based on: "TaviModel 2"
```

### Step 2: Make Your Changes
- Edit the NEW version (TaviModel 3)
- Add/remove/modify attributes as needed
- Update version identifier to "3.0"

### Step 3: Set Current Version
```bash
# In Xcode:
# 1. Select TaviModel.xcdatamodeld
# 2. File Inspector → Model Version
# 3. Select "TaviModel 3"
```

### Step 4: Test Migration
```swift
// Add to PersistenceController for testing:
func testMigration() {
    if let storeURL = container.persistentStoreDescriptions.first?.url {
        if isMigrationNeeded(at: storeURL) {
            print("⚠️ Migration will occur")
        } else {
            print("✅ No migration needed")
        }
    }
}
```

## Supported Migration Types

### Lightweight Migration (Automatic)
Core Data handles these automatically:
- ✅ Adding new entity
- ✅ Adding new attribute with default value
- ✅ Removing attribute
- ✅ Making non-optional attribute optional
- ✅ Making optional attribute non-optional (with default)
- ✅ Renaming entity/attribute (with renaming identifier)

### Heavy Migration (Manual Required)
These need custom mapping models:
- ❌ Changing attribute type (e.g., String → Int)
- ❌ Complex data transformations
- ❌ Splitting/merging entities

## Current Schema (v2.0)

### SessionResult Entity
Attributes:
- `id: UUID` - Unique identifier
- `date: Date` - Scan date
- `deviceModel: String` - Device info
- `deviceOS: String` - OS info
- `overallScore: Double` - Main score
- `blurQuality: Double` - Quality metric
- `textureAvg: Double` - Texture score
- `pigmentationAvg: Double` - Pigmentation score
- `moistureSpecular: Double` - Moisture (specular)
- `moistureSmoothness: Double` - Moisture (smoothness)
- `discolorationIndex: Double` - Discoloration metric
- `leftCheekScore: Double` - Regional score
- `rightCheekScore: Double` - Regional score
- `foreheadScore: Double` - Regional score
- `chinScore: Double` - Regional score
- `emotionalMetricsData: Binary?` - JSON data
- `clinicalMetricsData: Binary?` - JSON data
- `thumbnail: Binary?` - Image data
- `heatmapComposite: Binary?` - Heatmap image
- `heatmapMoisture: Binary?` - Heatmap image
- `heatmapPigmentation: Binary?` - Heatmap image
- `heatmapSharpness: Binary?` - Heatmap image
- `heatmapTexture: Binary?` - Heatmap image

## Migration Utilities

### Check Current Version
```swift
let version = PersistenceController.shared.getCurrentModelVersion()
print("Current model version: \(version ?? "unknown")")
```

### Check If Migration Needed
```swift
if let storeURL = PersistenceController.shared.container.persistentStoreDescriptions.first?.url {
    let needsMigration = PersistenceController.shared.isMigrationNeeded(at: storeURL)
    print("Migration needed: \(needsMigration)")
}
```

## Logging

Migration progress is logged via `AppLogger.storage`:
```
✅ Core Data automatic migration enabled
   - shouldMigrateStoreAutomatically: true
   - shouldInferMappingModelAutomatically: true
✅ Core Data persistent store loaded successfully
   Store URL: file:///.../TaviModel.sqlite
```

## Troubleshooting

### Issue: Migration Fails
**Solution**: Check that version identifiers are unique and sequential

### Issue: Data Loss After Update
**Solution**: Verify .xccurrentversion points to correct version

### Issue: "Can't find model for entity"
**Solution**: Regenerate NSManagedObject subclasses in Xcode

## Best Practices

1. **Always test migrations** on a copy of production data
2. **Never skip versions** (v1→v2→v3, not v1→v3)
3. **Use descriptive version identifiers** ("2.0", "2.1", not "current")
4. **Back up user data** before major schema changes
5. **Test on devices** with old app versions installed

## Emergency Rollback

If migration fails in production:

### Option 1: Release Hotfix
1. Revert to previous model version
2. Release emergency update

### Option 2: Force Fresh Start
```swift
// DANGER: This deletes all user data!
try? PersistenceController.shared.deleteAllSessions()
```

## Future Enhancements

Consider adding these for production:

1. **Manual Migration Manager**
   - Custom progress UI during migration
   - Fallback strategies for failed migrations

2. **Migration Analytics**
   - Track migration success/failure rates
   - Monitor migration duration

3. **Backup/Restore**
   - Export user data before migration
   - Restore on migration failure

4. **Version Compatibility Matrix**
   - Document which app versions work with which schemas
   - Plan deprecation strategy

## Summary

✅ **Core Data versioning is now configured**
✅ **Automatic migration enabled**
✅ **Future schema changes won't crash the app**
✅ **User data is protected**

Next time you need to change the schema, just create a new model version and the migration will happen automatically!
