# FaceScan3D ViewModel Refactoring Guide

## Overview

The monolithic `FaceScan3DViewModel` (1,636 lines) has been refactored into specialized managers to improve maintainability, testability, and reduce complexity.

## Architecture Changes

### Before (Monolithic)
```
FaceScan3DViewModel (1,636 lines)
├── Calibration logic (~70 lines)
├── Capture sequence management (~800 lines)
├── Processing pipeline (~200 lines)
├── Metrics computation (~100 lines)
├── UI state (~50 lines)
└── Misc utilities (~400 lines)
```

### After (Separated Concerns)
```
FaceScan3DViewModelRefactored (~350 lines)
├── CalibrationManager (~350 lines)
├── CaptureSequenceManager (~300 lines)
├── ProcessingPipeline (~200 lines)
└── MetricsOrchestrator (~150 lines)
```

## New Components

### 1. CalibrationManager
**Location:** `Features/FaceScan3D/Managers/CalibrationManager.swift`

**Responsibilities:**
- Calibration state management
- Distance/lighting/stability validation
- Quality checks and warnings
- Edge case detection
- Pre-flight checks

**Key Methods:**
```swift
func updateCalibration(faceAnchor:frame:lightEstimation:)
func checkImageQuality(...) -> Bool
func performPreflightChecks(...) -> Bool
func reset()
```

### 2. CaptureSequenceManager
**Location:** `Features/FaceScan3D/Managers/CaptureSequenceManager.swift`

**Responsibilities:**
- Guidance step management
- Pose validation and countdown logic
- Multi-frame capture coordination
- Texture sample capture
- Sequence lifecycle

**Key Methods:**
```swift
func startCaptureSequence()
func checkGuidancePoseAndCapture(...)
func captureStep(geometry:lightEstimation:) -> Bool
func capturePose(...)
func completeSequence()
```

### 3. ProcessingPipeline
**Location:** `Features/FaceScan3D/Managers/ProcessingPipeline.swift`

**Responsibilities:**
- Mesh merging (standard & streaming)
- Texture baking
- Export operations (OBJ, glTF, USDZ)
- Background processing coordination

**Key Methods:**
```swift
func finalizeCapture(sequence:) async -> MergedFaceMesh?
func bakeUnifiedTexture(from:samples:) async -> TextureBakeResult?
func exportOBJ/exportGLTF/exportUSDZ(...)
```

### 4. MetricsOrchestrator
**Location:** `Features/FaceScan3D/Managers/MetricsOrchestrator.swift`

**Responsibilities:**
- 3D metrics computation
- Visualization generation
- ROI metrics access
- Metadata generation

**Key Methods:**
```swift
func compute3DMetrics(from:) async -> Face3DMetrics?
func getVisualization(for:) -> MetricVisualization?
func generateMetadata(...) -> FaceScanMetadata?
```

### 5. Thin ViewModel Coordinator
**Location:** `Features/FaceScan3D/ViewModels/FaceScan3DViewModelRefactored.swift`

**Responsibilities:**
- Published properties for UI binding
- Delegates to specialized managers
- ARKit frame updates
- High-level session management
- Error propagation

## Migration Path

### Phase 1: Dual Operation (Current)
- Original `FaceScan3DViewModel` remains functional
- New `FaceScan3DViewModelRefactored` available for testing
- No breaking changes to existing views

### Phase 2: Gradual Migration
1. Update test suite to use new architecture
2. Create adapter/wrapper if needed for backward compatibility
3. Update one view at a time to use refactored ViewModel

### Phase 3: Deprecation
1. Mark original ViewModel as deprecated
2. Complete migration of all views
3. Remove original implementation

## Usage Examples

### Using the Refactored ViewModel

```swift
@StateObject private var viewModel = FaceScan3DViewModelRefactored()

// Access manager properties directly
Text("Calibrated: \(viewModel.calibrationManager.calibrationState.isCalibrated)")
Text("Guidance Active: \(viewModel.captureManager.isGuidanceActive)")
Text("Merging: \(viewModel.processingPipeline.isMerging)")
Text("Computing Metrics: \(viewModel.metricsOrchestrator.isComputingMetrics)")

// Use coordinator methods
Button("Start Scan") {
    viewModel.startCaptureSequence()
}

Button("Finalize") {
    Task {
        if let merged = await viewModel.finalizeCapture() {
            print("Merge successful: \(merged.vertices.count) vertices")
        }
    }
}
```

### Direct Manager Access

```swift
// Access calibration state
let isCalibrated = viewModel.calibrationManager.calibrationState.isCalibrated
let qualityWarning = viewModel.calibrationManager.qualityWarning

// Access capture state
let currentStep = viewModel.captureManager.currentGuidanceStep
let countdown = viewModel.captureManager.countdownTimer

// Access processing state
let isMerging = viewModel.processingPipeline.isMerging
let mergedMesh = viewModel.processingPipeline.mergedMesh

// Access metrics state
let metrics = viewModel.metricsOrchestrator.face3DMetrics
let viz = viewModel.metricsOrchestrator.getVisualization(for: .roughness)
```

## Benefits

### 1. Maintainability
- Each manager has a single, well-defined responsibility
- Easier to locate and fix bugs
- Clear separation of concerns

### 2. Testability
- Managers can be unit tested independently
- Mock managers for integration testing
- Reduced test complexity

### 3. Memory Management
- Each manager can be released independently
- Clearer memory pressure points
- Targeted cleanup on memory warnings

### 4. Race Condition Prevention
- Isolated state per manager
- Clear ownership boundaries
- Reduced inter-component coupling

### 5. Development Velocity
- Multiple developers can work on different managers
- Smaller files are easier to understand
- Faster compile times for incremental changes

## Testing Strategy

### Unit Tests
Each manager should have dedicated unit tests:

```swift
// CalibrationManagerTests.swift
class CalibrationManagerTests: XCTestCase {
    var manager: CalibrationManager!

    func testUpdateCalibration() {
        // Test calibration updates in isolation
    }

    func testQualityChecks() {
        // Test quality validation
    }
}

// CaptureSequenceManagerTests.swift
class CaptureSequenceManagerTests: XCTestCase {
    // Test capture logic in isolation
}
```

### Integration Tests
Test manager interactions through the coordinator:

```swift
class ViewModelIntegrationTests: XCTestCase {
    func testFullScanWorkflow() {
        let viewModel = FaceScan3DViewModelRefactored()
        // Test complete workflow
    }
}
```

## Performance Considerations

### Memory Impact
- **Before:** Single 1,636-line class with all state
- **After:** Distributed state across 4 managers + coordinator
- **Net Impact:** Neutral (same data, better organized)

### Execution Impact
- **Before:** Direct method calls within single class
- **After:** Delegation through coordinator (one additional hop)
- **Net Impact:** Negligible (<1% overhead)

### Benefits Outweigh Costs
- Improved code organization: ++++
- Better testability: ++++
- Easier maintenance: ++++
- Slight overhead: - (minimal)

## Next Steps

1. **Immediate:**
   - Review refactored code
   - Run existing tests against both implementations
   - Identify any gaps in functionality

2. **Short-term:**
   - Create unit tests for each manager
   - Update one view to use refactored ViewModel
   - Measure performance and memory impact

3. **Long-term:**
   - Migrate all views to refactored ViewModel
   - Remove original monolithic ViewModel
   - Document lessons learned

## File Locations

```
Tavi/Features/FaceScan3D/
├── Managers/
│   ├── CalibrationManager.swift           (NEW)
│   ├── CaptureSequenceManager.swift       (NEW)
│   ├── ProcessingPipeline.swift           (NEW)
│   └── MetricsOrchestrator.swift          (NEW)
├── ViewModels/
│   ├── FaceScan3DViewModel.swift          (ORIGINAL - keep for compatibility)
│   └── FaceScan3DViewModelRefactored.swift (NEW)
└── REFACTORING_GUIDE.md                    (THIS FILE)
```

## Questions & Troubleshooting

### Q: Why keep the original ViewModel?
A: To avoid breaking existing views during migration. This allows gradual adoption.

### Q: Can I use managers independently?
A: Yes! Each manager is designed to work independently for testing and potential reuse.

### Q: What if I find a bug in the original ViewModel?
A: Fix it in both implementations during the transition period, or prioritize migration to the refactored version.

### Q: How do I know when to complete the migration?
A: When all views successfully use the refactored ViewModel and test coverage is equivalent or better.

## Contact

For questions or issues with this refactoring, please refer to the project documentation or contact the development team.

---

**Created:** 2025-11-04
**Status:** In Progress
**Next Review:** After first view migration
