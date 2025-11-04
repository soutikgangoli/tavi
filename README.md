# Tavi - Advanced 3D Skin Analysis iOS App

A professional-grade SwiftUI iOS application for comprehensive facial skin analysis using ARKit depth scanning, advanced 3D mesh processing, and clinical-grade metrics computation with emotional wellness tracking.

## Overview

Tavi is a production-ready skin analysis application that leverages iPhone's TrueDepth camera, ARKit, Vision framework, and advanced 3D processing to deliver quantitative skin quality metrics. The app captures high-fidelity 3D facial scans, processes them with clinical-grade algorithms, and presents results through an intuitive, Headspace-quality UI with gamification elements.

## Key Features

### 🎯 3D Face Scanning
- **Multi-pose ARKit capture** - Guided 5-pose sequence for complete coverage
- **Real-time depth processing** - TrueDepth camera depth map analysis
- **Adaptive quality system** - Device-specific optimizations (iPhone 12+, 13+, 14+)
- **Environmental adaptation** - Lighting condition detection and compensation
- **Edge case handling** - Glasses, makeup, accessories detection
- **Progress tracking** - Real-time feedback with time estimation

### 📊 Clinical-Grade Metrics
- **Skin texture analysis** - Surface roughness and smoothness quantification
- **Pigmentation assessment** - Tone uniformity and discoloration detection
- **Hydration metrics** - Moisture and skin barrier evaluation
- **Elasticity measurement** - Skin firmness and resilience analysis
- **Volume tracking** - Facial volume changes over time
- **Sun damage detection** - UV exposure and photoaging assessment
- **Wrinkle depth mapping** - Fine lines and deep wrinkles quantification
- **Regional analysis** - Separate metrics for cheeks, forehead, under-eye areas

### 💾 Robust Data Management
- **Core Data persistence** - Session history with automatic migration
- **Fallback storage system** - JSON-based backup when Core Data unavailable
- **Automatic retry queue** - Failed saves retry automatically every 30 seconds
- **Migration on recovery** - Seamless data transfer from fallback to Core Data
- **Export capability** - Backup data to shareable JSON files
- **Visual save indicators** - Real-time feedback on save status

### 🎨 Professional UI/UX
- **Headspace-quality design** - Clean, calming, professional interface
- **Emotional metrics** - Glow Score, Radiance, Smoothness, Evenness, Youthfulness, Freshness
- **Progress comparison** - Single-line metrics with color-coded deltas
- **Interactive help** - Tap ? for metric explanations
- **First-time guidance** - Contextual banners for new users
- **Celebratory results** - Positive, encouraging feedback
- **Achievement system** - Gamification with unlockable milestones

### 🔄 Smart Comparison System
- **Side-by-side 3D views** - Before/after visual comparison
- **Synchronized controls** - Rotate and inspect both scans together
- **Single-line metrics** - Clean layout with inline point changes
- **Color-coded deltas** - Green (improved), Red (declined), Gray (stable)
- **Overall summary** - "4 metrics improved" instant feedback
- **Trend analysis** - Track progress over time

### 🎮 Gamification Features
- **Streak tracking** - Daily scan consistency rewards
- **Achievement unlocks** - Milestone celebrations
- **Challenges** - Weekly skin improvement goals
- **Progress badges** - Visual rewards for consistency

## Project Structure

```
Tavi/
├── TaviApp.swift                          # Main app entry point with data recovery
├── ContentView.swift                      # Root navigation
│
├── Features/
│   ├── FaceScan3D/
│   │   ├── Views/
│   │   │   ├── EmotionalScan3DFlowView.swift     # Complete scan flow with save handling
│   │   │   └── FaceScan3DView.swift              # Legacy ARKit scan view
│   │   │
│   │   ├── ViewModels/
│   │   │   └── FaceScan3DViewModel.swift         # Scan state management
│   │   │
│   │   ├── Processing/
│   │   │   ├── MeshProcessor.swift               # 3D mesh processing & merging
│   │   │   ├── DepthAnalyzer.swift               # Depth map analysis
│   │   │   └── CaptureSequenceManager.swift      # Multi-pose orchestration
│   │   │
│   │   ├── Metrics/
│   │   │   ├── SkinElasticity.swift              # Elasticity computation
│   │   │   ├── VolumeMetrics.swift               # Facial volume analysis
│   │   │   ├── RegionalAnalyzers.swift           # Area-specific metrics
│   │   │   └── SkinTypeClassifier.swift          # Fitzpatrick skin type
│   │   │
│   │   ├── Utilities/
│   │   │   ├── CoreDataSaveQueue.swift           # Persistent retry queue
│   │   │   ├── FallbackStorage.swift             # JSON backup system
│   │   │   ├── ProcessingTimeEstimator.swift     # Time prediction
│   │   │   ├── DeviceCalibration.swift           # Device-specific tuning
│   │   │   ├── EnvironmentalAdapter.swift        # Lighting compensation
│   │   │   └── EdgeCaseDetector.swift            # Accessory detection
│   │   │
│   │   └── UI/
│   │       ├── CelebrationView.swift             # Achievement celebrations
│   │       └── ComparisonView.swift              # Before/after comparison
│   │
│   ├── Results/
│   │   ├── CelebratoryResultsView.swift          # Main results screen
│   │   └── MetricExplanationView.swift           # Educational overlays
│   │
│   └── Export/
│       └── PDFReportGenerator.swift              # Results export
│
├── Core/
│   ├── StorageKit/
│   │   ├── PersistenceController.swift           # Core Data stack
│   │   ├── TaviModel.xcdatamodeld                # Data model
│   │   ├── SessionResult+CoreData.swift          # Session entity
│   │   └── CoreDataMigrationManager.swift        # Schema migrations
│   │
│   ├── Analytics/
│   │   ├── AnalyticsManager.swift                # Event tracking
│   │   ├── CrashReporter.swift                   # Error logging
│   │   └── MemoryMonitor.swift                   # Performance monitoring
│   │
│   ├── Gamification/
│   │   ├── GamificationManager.swift             # Achievement system
│   │   └── Achievement.swift                     # Achievement models
│   │
│   └── Design/
│       └── HeadspaceDesign.swift                 # Design tokens & styles
│
└── Models/
    ├── EmotionalMetrics.swift                    # User-facing metrics
    ├── Face3DMetrics.swift                       # Clinical metrics
    ├── ScanConfiguration.swift                   # Capture settings
    └── ScanError.swift                           # Error types
```

## Technical Architecture

### 3D Scan Pipeline

```
ARKit Session (TrueDepth Camera)
    ↓
Multi-Pose Capture (5 poses)
    ↓
Depth Map Analysis
    ↓
Mesh Extraction & Validation
    ↓
Pose-wise Processing
    ↓
Mesh Merging & Alignment
    ↓
Clinical Metrics Computation
    ↓
Emotional Metrics Translation
    ↓
Core Data Save (with Fallback)
    ↓
Results Display
```

### Data Persistence Flow

```
Scan Complete → Attempt Core Data Save
                    ↓
         ┌──────────┴──────────┐
         ↓                     ↓
    Core Data OK?         Unavailable?
         ↓                     ↓
    Try Save              Use FallbackStorage
         ↓                     ↓
    ┌────┴────┐               ↓
    ↓         ↓               ↓
Success?   Failed?      Save to JSON
    ↓         ↓               ↓
  Done    Queue Retry    Show Warning
              ↓               ↓
        Auto-retry      Export Option
        every 30s            ↓
              ↓          Migrate when
        Max 5 tries     Core Data returns
```

### Save Status Indicators

| Status | Visual | Meaning |
|--------|--------|---------|
| **Saving** | Gray spinner | "Saving to History..." |
| **Saved** | No banner | Successfully saved |
| **Queued** | Orange ⚠️ | "Queued for Retry - will retry automatically" |
| **Core Data Unavailable** | Red 🔴💾 | "Storage Issue - saved to backup file" |

## Clinical Metrics

### Computed Metrics (from 3D scan)

1. **Texture Roughness** (0-100)
   - Surface irregularity analysis
   - High-frequency depth variations
   - Mesh normal vector analysis

2. **Pigmentation Uniformity** (0-100)
   - Color variance across regions
   - LAB color space analysis
   - Regional comparison

3. **Hydration Level** (0-100)
   - Surface smoothness
   - Specular reflection analysis
   - Moisture proxy computation

4. **Elasticity Score** (0-100)
   - Skin firmness estimation
   - Volume preservation analysis
   - Regional elasticity mapping

5. **Volume Metrics**
   - Facial volume quantification
   - Region-specific measurements
   - Temporal volume tracking

6. **Wrinkle Analysis**
   - Depth mapping
   - Fine vs. deep wrinkle classification
   - Regional wrinkle density

7. **Sun Damage Assessment**
   - Photoaging indicators
   - Pigmentation anomalies
   - UV exposure estimation

### Emotional Metrics (user-facing)

- **Glow Score** (0-100) - Overall skin health
- **Radiance** (0-100) - Light reflection quality
- **Smoothness** (0-100) - Surface texture
- **Evenness** (0-100) - Tone uniformity
- **Youthfulness** (0-100) - Elasticity & firmness
- **Freshness** (0-100) - Overall vitality
- **Sun Protection** (0-100) - UV damage resistance

## Data Safety Features

### 1. Core Data Save Queue
- **Persistent storage** using UserDefaults
- **Survives app termination** and restarts
- **Automatic retry** every 30 seconds
- **Max 5 attempts** per save
- **Background processing** on app launch
- **Published state** for UI updates

### 2. Fallback Storage System
- **JSON-based** session storage
- **Documents directory** persistence
- **Export capability** to shareable files
- **Import from backup** functionality
- **Automatic migration** when Core Data recovers
- **Redundant storage** (list + individual files)
- **Keeps last 100 sessions**

### 3. Visual Feedback
- **Real-time status banners** in results view
- **Color-coded indicators** (green/orange/red)
- **Contextual messaging** based on state
- **Export prompts** when Core Data unavailable

## Performance Optimizations

### Device-Specific Tuning

| Device | Mesh Quality | Timeout | Features |
|--------|-------------|---------|----------|
| iPhone 12-13 | Standard | +20% | Basic processing |
| iPhone 13 Pro+ | High | Standard | Enhanced capture |
| iPhone 14 Pro+ | Ultra | -10% | All features enabled |

### Processing Times (iPhone 14 Pro)

- **Pose Capture**: ~1.5s per pose
- **Mesh Processing**: ~2-3s per pose
- **Mesh Merging**: ~4-5s
- **Metrics Computation**: ~3-4s
- **Core Data Save**: ~0.5s
- **Total**: ~25-30s for complete scan

### Memory Management
- **Active monitoring** via MemoryMonitor
- **Automatic cleanup** after processing
- **Mesh optimization** before merging
- **Peak usage**: ~200 MB during processing

## Configuration

### Scan Configuration
```swift
ScanConfiguration(
    requiredPoses: 5,
    meshQuality: .high,
    depthSmoothingFactor: 0.3,
    minimumConfidence: 0.7,
    timeoutPerPose: 10.0,
    coreDataSaveTimeout: 5.0
)
```

### Fallback Storage
```swift
FallbackStorage.shared.saveSession(
    emotionalMetrics: metrics,
    clinicalMetrics: clinicalMetrics
)

// Export to file
let exportURL = try FallbackStorage.shared.exportToFile()

// Migrate when Core Data returns
let migratedCount = await FallbackStorage.shared.migrateToCoreDataIfPossible()
```

## Comparison View

### Single-Line Metrics
```
Smoothness      78.5 /100  ↑ 5.3 pts
                           └─ Green badge

Wrinkle Depth   0.42 mm    ↑ 0.03 pts
                           └─ Green (lower is better!)
```

### Overall Summary
```
┌────────────────────────────────────┐
│ ✓ Great progress! 4 metrics improved│
│ ↑ 4 improved  ↓ 1 declined  − 1 stable│
└────────────────────────────────────┘
```

## Usage Example

```swift
// 1. Start scan flow
EmotionalScan3DFlowView()

// 2. Follow guided poses (automatic)
// - Center pose
// - Look left
// - Look right
// - Look up
// - Look down

// 3. Processing (automatic with progress)
// - Mesh merging
// - Metrics computation
// - Clinical analysis
// - Achievement checking
// - Save to Core Data (with fallback)

// 4. View results
// - Glow score celebration
// - Individual metrics with help
// - Save status indicator
// - Share/export options
```

## Data Recovery on App Launch

```swift
init() {
    // ...existing setup...

    Task { @MainActor in
        // Process any pending saves from queue
        await CoreDataSaveQueue.shared.processQueue()

        // Migrate fallback data if Core Data becomes available
        let migratedCount = await FallbackStorage.shared.migrateToCoreDataIfPossible()
        if migratedCount > 0 {
            AppLogger.storage.info("✅ Migrated \(migratedCount) sessions from fallback")
        }
    }
}
```

## Dependencies

- **AVFoundation** - Camera and media processing
- **ARKit** - 3D face tracking and depth scanning
- **Vision** - Face detection and landmark recognition
- **SceneKit** - 3D mesh visualization
- **CoreData** - Persistent storage
- **Combine** - Reactive data flow
- **SwiftUI** - Declarative UI framework

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- iPhone with TrueDepth camera (iPhone X or later)
- iPhone 12 or later recommended for optimal performance
- iPhone 14 Pro or later for best quality

## Permissions

Required permissions in Info.plist:
- **NSCameraUsageDescription** - "Tavi uses the camera for 3D facial skin analysis"
- **NSFaceIDUsageDescription** - "Tavi uses TrueDepth camera for depth scanning"

## Getting Started

1. Clone the repository
2. Open `Tavi.xcodeproj` in Xcode
3. Select your target device (must have TrueDepth camera)
4. Build and run (⌘R)
5. Grant camera permissions
6. Follow guided scan sequence

## Best Practices

### For Optimal Scans
1. **Good lighting** - Even, natural light preferred
2. **Clean face** - Remove makeup if possible
3. **Remove accessories** - Glasses, headbands, etc.
4. **Hold steady** - Follow pose guidance carefully
5. **Centered face** - Keep face in frame overlay

### For Accurate Comparisons
1. **Consistent conditions** - Same time of day, lighting
2. **Regular tracking** - Scan weekly for trends
3. **Clean device** - Wipe TrueDepth sensors
4. **Same distance** - Maintain consistent capture distance

## Troubleshooting

### Common Issues

**Scan failing repeatedly:**
- Improve lighting conditions
- Remove glasses/accessories
- Clean TrueDepth camera
- Check for ARKit availability

**Core Data unavailable:**
- Check device storage space
- Force quit and restart app
- Export backup via Settings
- Wait for automatic migration

**Metrics seem incorrect:**
- Ensure proper lighting
- Verify face detection quality
- Check mesh quality indicators
- Compare with previous scans

**Save failures:**
- Check storage space
- Results queued automatically
- Export to JSON if needed
- Automatic retry every 30s

## Recent Improvements

### Data Integrity (Latest)
- ✅ Persistent save queue with UserDefaults
- ✅ Fallback JSON storage when Core Data unavailable
- ✅ Automatic retry mechanism (30s intervals)
- ✅ Visual save status indicators
- ✅ Export/import capability
- ✅ Automatic migration on recovery

### UX Enhancements
- ✅ Single-line comparison metrics
- ✅ Color-coded point deltas
- ✅ Overall improvement summary
- ✅ Interactive metric help (tap ?)
- ✅ First-time user guidance

### Performance
- ✅ Device-specific optimizations
- ✅ Processing time estimation
- ✅ Memory monitoring
- ✅ Automatic cleanup

## Future Enhancements

### Planned Features
- **Lazy metric computation** - Save 20-30s by computing secondary metrics in background
- **Trend graphs** - Multi-scan temporal analysis
- **AI recommendations** - Personalized skincare suggestions
- **Share comparisons** - Export progress images
- **Cloud sync** - Multi-device support
- **Dermatologist export** - Clinical report generation

### Optimization Opportunities
- Background metric computation
- GPU acceleration for mesh processing
- Predictive quality assessment
- Adaptive pose requirements based on device

## License

Copyright © 2025. All rights reserved.

## Acknowledgments

- Apple ARKit for depth scanning
- Apple Vision framework for face detection
- Core Data for robust persistence
- SwiftUI for modern UI development
- Headspace for design inspiration
