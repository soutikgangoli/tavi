# Core Data Migration Strategy

## Overview

This document outlines the comprehensive Core Data migration strategy for the Tavi app, addressing the critical need for data version tracking, migration safety, and data loss prevention.

## Problem Statement

**Before:**
- Status: Auto-migration enabled, but no versioning strategy
- Risks:
  - No data version tracking
  - No migration tests
  - Potential data loss on model changes
  - No rollback mechanism
  - No user visibility into migrations

**After:**
- ✅ Versioned data models with explicit version identifiers
- ✅ Custom migration manager with safety checks
- ✅ Automatic backup before migrations
- ✅ Rollback on migration failure
- ✅ Comprehensive migration tests
- ✅ User-facing backup and recovery tools

## Architecture

### Components

```
Core Data Migration System
├── CoreDataMigrationManager
│   ├── Migration detection
│   ├── Automatic backup creation
│   ├── Safe migration execution
│   ├── Post-migration validation
│   └── Automatic rollback on failure
│
├── DataBackupManager
│   ├── User-initiated backups
│   ├── Backup restoration
│   ├── Import/Export functionality
│   └── Backup management UI
│
├── Model Versions
│   ├── TaviModel v1.0 (initial)
│   ├── TaviModel v2.0 (current)
│   └── Future versions with mapping models
│
└── Tests
    ├── Migration detection tests
    ├── Backup/restore tests
    ├── Data integrity tests
    └── Performance tests
```

## Model Versioning Strategy

### Version Identifiers

Each Core Data model version has an explicit identifier:

```xml
<!-- TaviModel v1.0 -->
<model ... userDefinedModelVersionIdentifier="1.0">
  ...
</model>

<!-- TaviModel v2.0 -->
<model ... userDefinedModelVersionIdentifier="2.0">
  ...
</model>
```

### Adding New Model Versions

When making schema changes:

1. **Create New Model Version**
   ```
   Xcode → Model File → Editor → Add Model Version
   ```

2. **Update Version Identifier**
   ```xml
   userDefinedModelVersionIdentifier="3.0"
   ```

3. **Make Schema Changes**
   - Add/remove entities
   - Add/remove attributes
   - Modify relationships

4. **Create Mapping Model (if needed)**
   ```
   For complex migrations that can't be inferred:
   File → New → Mapping Model
   ```

5. **Test Migration**
   - Create test with v2.0 data
   - Verify migration to v3.0
   - Validate data integrity

## Migration Process

### Automatic Migration Flow

```
App Launch
    ↓
PersistenceController.init()
    ↓
CoreDataMigrationManager.migrateStoreIfNeeded()
    ↓
[Check if store exists] → No → No migration needed
    ↓ Yes
[Check if migration needed] → No → Load store normally
    ↓ Yes
[Create backup]
    ↓
[Perform migration]
    ↓
[Validate migrated store]
    ↓
Success? → Yes → [Clean up old backups] → Load store
    ↓ No
[Rollback from backup] → Load store (original data)
```

### Migration Safety Measures

1. **Pre-Migration Backup**
   - Automatic backup before every migration
   - Stored in Caches directory (not in iCloud)
   - Timestamped for identification

2. **Migration Validation**
   - Post-migration integrity check
   - Verifies store can be loaded
   - Validates entity structure
   - Checks data accessibility

3. **Automatic Rollback**
   - On migration failure
   - On validation failure
   - Restores original data
   - Preserves user data

4. **Error Reporting**
   - Detailed error logging
   - User-friendly error messages
   - Migration metrics (duration, etc.)

## User-Facing Features

### Data Backup Manager

Users can:
- Create manual backups
- View all available backups
- Restore from any backup
- Export backups for safekeeping
- Import backups from files
- Delete old backups

### Backup Locations

```
Manual Backups (User-initiated):
~/Documents/Backups/
  └── Manual_2025-11-04.sqlite
  └── Pre_Update_Backup.sqlite

Automatic Backups (Migration):
~/Library/Caches/CoreDataBackups/
  └── backup_2025-11-04T10:30:00Z.sqlite
  └── backup_2025-11-03T14:20:00Z.sqlite
```

### Backup Retention

- **Manual backups**: Kept indefinitely (user manages)
- **Auto backups**: Keep 5 most recent (automatic cleanup)

## Migration Types

### 1. Lightweight Migration

**When to use:**
- Adding new attributes with default values
- Removing attributes
- Making optional attributes non-optional (with default)
- Renaming entities/attributes (with renaming identifiers)

**Configuration:**
```swift
// Handled automatically by CoreDataMigrationManager
performLightweightMigration(...)
```

### 2. Heavyweight Migration

**When to use:**
- Complex data transformations
- Splitting/merging entities
- Migrating data between attributes
- Custom validation logic

**Configuration:**
```swift
// Create custom mapping model in Xcode
// CoreDataMigrationManager will detect and use it
```

## Testing Strategy

### Unit Tests

```swift
// CoreDataMigrationTests.swift

testNoStoreNoMigration()
testCompatibleStoreNoMigration()
testBackupCreation()
testMigrationValidation()
testMigrationFailureRollback()
testCorruptedStoreHandling()
```

### Integration Tests

```swift
// CoreDataMigrationIntegrationTests.swift

testPersistenceControllerWithMigration()
testMigrationPreservesData()
testMultiVersionMigration()  // v1 → v2 → v3
```

### Performance Tests

```swift
measure {
    // Test migration performance with realistic data
    migrateStoreWithData(recordCount: 1000)
}
```

### Test Data Generation

```swift
func createTestStore(version: String, recordCount: Int) {
    // Create store with specified model version
    // Populate with test data
    // Used for migration testing
}
```

## Migration Scenarios

### Scenario 1: Simple Attribute Addition

```
Model v2.0 → v3.0
Added: SessionResult.skinType: String?

Migration Type: Lightweight
Mapping Model: Not required
Data Loss Risk: None (new attribute is optional)
```

### Scenario 2: Attribute Type Change

```
Model v2.0 → v3.0
Changed: SessionResult.overallScore: Double → Float

Migration Type: Lightweight
Mapping Model: Not required (compatible types)
Data Loss Risk: Minimal (precision loss acceptable)
```

### Scenario 3: Entity Split

```
Model v2.0 → v3.0
Split: SessionResult → SessionResult + SessionMetrics

Migration Type: Heavyweight
Mapping Model: Required
Data Loss Risk: Medium (requires custom mapping)
```

## Monitoring and Metrics

### Migration Metrics

Track and log:
- Migration duration
- Store size before/after
- Number of records migrated
- Success/failure rate
- Rollback frequency

### Store Health Monitoring

```swift
PersistenceController logs:
- Store size (MB)
- Record count
- Last successful save
- Error frequency
```

## Error Handling

### Migration Errors

```swift
enum MigrationError: LocalizedError {
    case storeNotFound(URL)
    case metadataReadFailed(URL)
    case incompatibleModel(current: String, store: String)
    case backupFailed(Error)
    case migrationFailed(from: String, to: String, Error)
    case rollbackFailed(Error)
    case invalidModelVersion(String)
}
```

### User Communication

- **Migration in progress**: Show loading indicator
- **Migration successful**: Silent (logged only)
- **Migration failed**: Show error with recovery options
- **Rollback successful**: Notify user data was preserved

## Recovery Procedures

### If Migration Fails

1. **Automatic Rollback**
   - App automatically restores from backup
   - User data preserved
   - App continues with original data

2. **Manual Recovery (if needed)**
   ```
   Settings → Data Management → Restore from Backup
   Select most recent backup
   Confirm restore
   App restarts with restored data
   ```

### If Store Corrupted

1. **Detection**
   ```swift
   if nsError.code == NSPersistentStoreIncompatibleVersionHashError {
       // Store is corrupted or incompatible
   }
   ```

2. **Recovery Options**
   - Restore from backup
   - Reset store (data loss)
   - Contact support (export backup first)

## Best Practices

### For Developers

1. **Always test migrations**
   - Create test with old model version
   - Verify data integrity after migration
   - Test with realistic data volumes

2. **Version carefully**
   - Increment version for any schema change
   - Document what changed in commit message
   - Update this document

3. **Consider data impact**
   - Will migration be destructive?
   - Is custom mapping needed?
   - Should we notify users?

4. **Monitor in production**
   - Track migration success rate
   - Monitor store size growth
   - Watch for error patterns

### For Users

1. **Regular backups**
   - Create manual backups before updates
   - Export important backups to Files app
   - Verify backups after creation

2. **Update safely**
   - Ensure device has enough space
   - Don't interrupt migration process
   - Contact support if issues occur

## File Locations

```
Tavi/Core/StorageKit/
├── Migration/
│   ├── CoreDataMigrationManager.swift      (Automatic migration)
│   ├── DataBackupManager.swift             (User backups)
│   └── MIGRATION_STRATEGY.md               (This file)
│
├── PersistenceController.swift             (Integration)
└── SessionResult.swift                      (Entity)

TaviTests/CoreData/
└── CoreDataMigrationTests.swift            (Tests)

Tavi.xcdatamodeld/
├── TaviModel.xcdatamodel                   (v1.0)
└── TaviModel 2.xcdatamodel                 (v2.0 - current)
```

## Migration Checklist

Before making schema changes:

- [ ] Create new model version
- [ ] Update version identifier
- [ ] Test with old data
- [ ] Create mapping model (if needed)
- [ ] Write migration tests
- [ ] Update this documentation
- [ ] Test on device
- [ ] Monitor after release

## Future Enhancements

### Planned Features

1. **Cloud Sync**
   - Sync backups to iCloud
   - Restore from any device
   - Conflict resolution

2. **Analytics**
   - Migration success metrics
   - Store health dashboard
   - Performance monitoring

3. **Advanced Recovery**
   - Partial data recovery
   - Merge from multiple backups
   - Data export to JSON

4. **Migration Preview**
   - Show user what will change
   - Estimate migration time
   - Allow cancellation

## Support

### For Developers

- Review migration tests in `CoreDataMigrationTests.swift`
- Check AppLogger.storage logs for migration info
- Use `CoreDataMigrationManager` directly for manual migrations

### For Users

- Settings → Data Management → Backups
- Settings → Help → Data Recovery Guide
- Support email with backup attached

## References

- [Core Data Versioning and Migration Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/)
- [Lightweight vs Heavyweight Migration](https://developer.apple.com/documentation/coredata/using_lightweight_migration)
- [NSManagedObjectModel Documentation](https://developer.apple.com/documentation/coredata/nsmanagedobjectmodel)

---

**Created:** 2025-11-04
**Status:** Implemented
**Last Updated:** 2025-11-04
**Next Review:** After first production migration
