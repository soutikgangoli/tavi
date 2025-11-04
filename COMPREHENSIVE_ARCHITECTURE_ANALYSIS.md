# Tavi App - Comprehensive Architecture Analysis

**Date:** 2025-11-04  
**Total Swift Files:** 95  
**Key Components:** 30+ ViewModels and State-managed Classes

---

## EXECUTIVE SUMMARY

The Tavi app is a sophisticated skin health analysis application built on SwiftUI with ARKit integration for 3D face scanning. The architecture combines **modern reactive patterns** with **complex multi-stage processing pipelines**. The codebase is primarily well-organized but has several **critical pattern inconsistencies, incomplete flows, and state management fragility issues**.

---

## 1. OVERALL ARCHITECTURE & APP FLOW

### High-Level Flow
```
TaviApp (Entry)
├── ContentView → HomeView
├── NavigationStack (primary navigation)
├── PersistenceController (Core Data)
└── Memory & Crash monitoring

HomeView (Hub)
├── EmotionalScan3DFlowView (Scan Flow)
├── OnboardingFlowView (First Launch)
├── SettingsView (Configuration)
└── ResultsHistoryView (Data Review)
```

### Main Application Lifecycle
1. **App Launch** (`TaviApp.swift`)
   - Initializes `PersistenceController` (Core Data)
   - Starts `MemoryMonitor` & `CrashReporter`
   - Shows fancy loading screen (disabled in dev)

2. **Home Screen** (`HomeView.swift`)
   - Fetches latest sessions with `@FetchRequest`
   - Shows greeting, latest scan card, recent scans history
   - Sticky "Scan Now" button triggers flow

3. **Scan Flow** (`EmotionalScan3DFlowView.swift`)
   - Preparation countdown (3 seconds)
   - Real-time capture with guidance overlays
   - Multi-stage processing pipeline
   - Results celebration screen

4. **Results** (`CelebratoryResultsView.swift`)
   - Displays emotional metrics & clinical scores
   - Shows personalized recommendations
   - Share functionality

---

## 2. VIEW MODELS & STATE MANAGEMENT PATTERNS

### 2.1 Main ViewModels

#### **FaceScan3DViewModel** (Most Critical)
**File:** `/Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`  
**Type:** `@MainActor class` (~1800 lines)

**Published Properties:**
- `currentGeometry`, `lightEstimation`, `blendShapes` - Real-time ARKit data
- `calibrationState`, `currentGuidanceStep`, `countdownTimer` - Capture state
- `currentSequence`, `mergedMesh` - Mesh data
- `face3DMetrics`, `bakeResult` - Processing results
- `guidanceFeedback`, `qualityWarning` - User feedback

**Key Pattern Issues:**
- ✅ Uses `@MainActor` for thread safety
- ✅ Comprehensive error handling with detailed logging
- ⚠️ **TESTING MODE CODE:** Captures only 1 pose instead of 7 (production bug waiting)
  - Line: `if newCount >= 1 {` should be `>= GuidanceStep.allCases.count`
  - Also in `CalibrationOverlay.swift`
  - TODO comment at line ~1200

- ⚠️ **Mixed State Management:** Combining multiple concerns in single ViewModel
  - Guidance state
  - Calibration state
  - Sequence management
  - Texture baking
  - Metrics computation
  - All interconnected with complex logic

#### **ResultsViewModel**
**File:** `/Tavi/Features/Results/ResultsViewModel.swift`  
**Type:** `@MainActor class` (~50 lines)

**Pattern:** Simple CRUD operations on SessionResult  
**Issues:** None identified - well-designed for single responsibility

#### **DebugViewModel**
**File:** `/Tavi/Features/Debug/DebugViewModel.swift`  
**Published:** Frame rate, face detection, geometry stats

---

### 2.2 State Management Patterns Used

| Pattern | Location | Status |
|---------|----------|--------|
| `@State` (local) | All Views | ✅ Consistent |
| `@StateObject` | EmotionalScan3DFlowView | ✅ Proper |
| `@ObservedObject` | Views observing ViewModels | ✅ Correct usage |
| `@Published` | ViewModel properties | ✅ Standard |
| `@AppStorage` | Settings persistence | ✅ Consistent |
| `@FetchRequest` | HomeView (session fetching) | ✅ Proper Core Data integration |
| `@Environment` | Core Data context, dismiss | ✅ Correct |

**Key Insight:** State management is **sound**, but there's complexity from handling multiple interdependent states in single ViewModel.

---

## 3. NAVIGATION PATTERNS

### Navigation Structure
**Type:** NavigationStack + Sheet/FullScreenCover combinations

```
HomeView (NavigationStack root)
├── .fullScreenCover → OnboardingFlowView
├── .sheet → EmotionalScan3DFlowView (NavigationStack)
│   ├── Preparation view
│   ├── FaceScan3DView (ARKit)
│   ├── Processing view
│   └── CelebratoryResultsView
└── .sheet → SettingsView
```

### Navigation Issues Identified

**Issue 1: FullScreenCover for Onboarding**
- ✅ Correct pattern (interrupts main flow)
- Dismissal: `UserDefaults` toggle + `@Environment(\.dismiss)`

**Issue 2: Sheet for Scan Flow**
- ✅ Correct (modal over home)
- Internal navigation uses `NavigationStack` (nested)
- **Potential Issue:** Results view uses callback closures (`onShareResults`, `onClose`) instead of navigation

**Issue 3: Callback Hell in Results**
```swift
CelebratoryResultsView(
    emotionalMetrics: metrics,
    clinicalMetrics: clinicalMetrics,
    onShareResults: { showShareSheet = true },  // Callback
    onClose: { dismiss() }                       // Callback
)
```
- **Problem:** Mix of callbacks + NavigationStack
- **Better:** Use state-based navigation or NavigationLink

**Issue 4: Inconsistent Dismissal Patterns**
- Some screens use `@Environment(\.dismiss)`
- Some use callbacks
- Some use state variables (`showScanFlow`, `showSettings`)

---

## 4. CALLBACK, DELEGATE & CLOSURE PATTERNS

### Callbacks in FaceScan3DView
```swift
public var onGeometryUpdate: ((FaceMeshGeometry) -> Void)?
public var onCaptureComplete: (([GuidanceStep: CapturedPoseData]) -> Void)?
```

**Usage:**
- Called when `currentGeometry` updates
- Called when all poses captured (but **TESTING MODE:** triggers at 1 capture)

### Delegates: ARFaceTrackingViewController
**File:** `/Tavi/Features/FaceScan3D/Views/ARFaceTrackingViewController.swift`

**Delegates Implemented:**
- `ARSCNViewDelegate` - Face anchor updates
- `ARSessionDelegate` - Session lifecycle events

**Pattern Issues:**
- ✅ Proper delegate implementation
- ⚠️ Updates ViewModel via `Task { @MainActor in }` (thread-safe but verbose)
- All delegate callbacks safely update MainActor property

### Event Callbacks for Multi-Frame Capture
```swift
func onFrameCaptured(frameCount: Int, targetCount: Int, confidence: Float)
func onMultiFrameCaptureCompleted(frameCount: Int)
```
**Status:** Implemented but not actively used in current flow

---

## 5. DATA FLOW BETWEEN COMPONENTS

### Capture Pipeline Flow

```
ARFaceTrackingViewController (UIKit wrapper)
    │
    ├→ ARFaceAnchor + ARFrame
    │
    ↓ (via ARSCNViewDelegate)
    
FaceScan3DViewModel.updateGeometry()
    │
    ├→ Updates: currentGeometry, lightEstimation, blendShapes
    ├→ Validates: calibrationState, pose correctness
    └→ Triggers: Quality checks, auto-countdown
    
    │
    ↓ (if pose valid + all green)
    
startCaptureCountdown()
    │
    └→ Timer counts 3→0
       └→ Triggers capturePose()
    
capturePose()
    │
    ├→ Creates CapturedPoseData
    ├→ Calls captureStep() 3 times (multi-frame)
    │   └→ currentSequence.addCapture()
    ├→ Calls captureTextureSample()
    │   └→ currentSequence.addTextureSample()
    └→ Updates UI (3x haptic feedback commented out)
    
    │
    ↓ (TESTING MODE: auto-completes after 1 pose)
    
finalizeCapture()
    │
    ├→ Merges meshes with MeshMerger/StreamingMeshMerger
    ├→ Creates MergedFaceMesh
    └→ Sets currentSequence.complete()
    
    │
    ↓ (in EmotionalScan3DFlowView.processCapture())
    
bakeTextureFromSequence()
    │
    └→ Creates TextureBakeResult (unified mesh + albedo texture)
    
    │
    ↓
    
compute3DMetrics()
    │
    ├→ Analyzes unified mesh + texture
    └→ Returns Face3DMetrics (with ~20 sub-metrics)
    
    │
    ↓
    
saveToCoreData() + Results display
```

### Data Model Hierarchy

```
Raw ARKit Data
├── ARFaceAnchor (transform, blendShapes)
└── ARFrame (image, camera data)

FaceMeshGeometry (SIMD types)
├── vertices: [SIMD3<Float>]
├── triangleIndices: [UInt32]
├── normals: [SIMD3<Float>]
└── transform: simd_float4x4

MeshCapture (Codable version)
├── vertices: [Vector3]
├── triangleIndices: [Int32]
├── step: String
├── yaw/pitch/roll: Float
└── lighting data

CaptureSequence (class - mutable)
├── captures: [MeshCapture]
├── textureSamples: [PoseSample]
└── metadata: SequenceMetadata

MergedFaceMesh (unified multi-pose)
├── vertices: [Vector3]
├── triangleIndices: [Int32]
└── textureCoordinates: [Vector2]

TextureBakeResult
├── unifiedMesh: MergedFaceMesh
├── albedoTexture: CGImage
└── coveragePercentage: Float

Face3DMetrics (analysis result)
├── roiMetrics: [Face3DROI: ROI3DMetrics]
├── globalRoughnessScore: Float
├── glowAnalysis: GlowAnalysis?
└── wrinkleAnalysis: WrinkleAnalysis?

EmotionalMetrics (user-facing)
├── glowScore: Int
├── smoothness/radiance/freshness: Int
└── nextSteps: [ActionableStep]

SessionResult (Core Data entity)
├── emotionalMetricsData: Data (JSON)
├── clinicalMetricsData: Data (JSON)
└── individual scores
```

**Data Flow Issues:**

1. **Multiple Mesh Types:**
   - `FaceMeshGeometry` (SIMD, from ARKit)
   - `MeshCapture` (Codable, in sequence)
   - `MergedFaceMesh` (unified)
   - Multiple conversions between types

2. **Coupling in Metrics:**
   - `Face3DMetrics` computed from `MergedFaceMesh` + texture
   - Then converted to `EmotionalMetrics` for UI
   - Then JSON-encoded to `SessionResult`

---

## 6. CORE DATA INTEGRATION & PERSISTENCE

### Architecture

**File:** `/Tavi/Core/StorageKit/PersistenceController.swift`

```swift
final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext
    
    func saveSession(scores: ScoreSummary, faceImage: CGImage, 
                     heatmaps: [HeatmapType: CGImage]?) throws
    func fetchAllSessions() -> [SessionResult]
    func deleteSession(_ session: SessionResult) throws
}
```

**Data Model:** `TaviModel.xcdatamodeld`

**Entity: SessionResult**
```swift
@NSManaged public var id: UUID
@NSManaged public var date: Date
@NSManaged public var deviceModel: String
@NSManaged public var overallScore: Double
@NSManaged public var emotionalMetricsData: Data?  // JSON encoded
@NSManaged public var clinicalMetricsData: Data?   // JSON encoded
```

### Storage Issues Identified

1. **JSON Serialization Roundtrip:**
   - `Face3DMetrics` → JSON → `Data` → Core Data
   - Then reversed for display
   - ⚠️ **Risk:** Decoding failures not handled on retrieval
   - ⚠️ **Missing:** Version migration if metric schema changes

2. **Memory Warning Handler:**
   ```swift
   private func handleMemoryWarning() {
       if bakeResult != nil { bakeResult = nil }  // ~67MB cleared
       if mergedMesh != nil { mergedMesh = nil }  // ~30MB cleared
   }
   ```
   - ✅ Good practice, but happens AFTER low memory warning
   - ⚠️ Could be more proactive

3. **Preview Data:**
   - In-memory store for previews
   - Generates 5 sample sessions
   - ✅ Good for testing

4. **Thread Safety:**
   - `viewContext` used from main thread
   - Background contexts available via `newBackgroundContext()`
   - ⚠️ Some async operations don't use background contexts

---

## 7. INCOMPLETE FEATURES & TODO COMMENTS

### Critical TODOs

1. **Testing Mode Scan Capture**
   ```swift
   // Line: FaceScan3DViewModel.swift ~1200
   // TODO: Remove this before production - this is for testing skin analysis
   AppLogger.faceScan.info("🧪 TESTING MODE: Completing scan after first capture")
   ```
   **Impact:** App captures 1 pose instead of 7, breaks scan accuracy
   **Status:** Production blocker

2. **Production Code Disabled**
   ```swift
   // Original production code (commented out for testing):
   // Move to next step or finish...
   ```
   **Files Affected:**
   - `FaceScan3DViewModel.swift` (capturePose method)
   - `FaceScan3DView.swift` (onChange for capturedPoses.count)
   - `CalibrationOverlay.swift` (completion check)

3. **Challenge Update Mechanism**
   ```swift
   // Line: GamificationSystem.swift
   // TODO: Implement proper challenge update mechanism
   ```
   **Status:** Gamification incomplete

4. **Sentry Configuration**
   ```swift
   // Line: CrashReporter.swift
   // TODO: Replace with your Sentry DSN from https://sentry.io
   ```
   **Status:** Placeholder, needs real DSN

5. **Validation Study**
   ```swift
   // Line: ScanConfiguration.swift
   /// TODO: Conduct validation study to verify this factor
   ```
   **Status:** Calibration thresholds are empirical

---

### Incomplete Flows

1. **Before/After Comparison**
   - `BeforeAfterView.swift` exists but not integrated
   - Results view doesn't link to comparison feature
   - Historical metric tracking exists but UI incomplete

2. **Social Sharing**
   - `SocialSharingView.swift` created
   - Integration with results view exists via callback
   - But sharing actual image/metrics not fully implemented

3. **Achievements System**
   - `GamificationManager.shared.checkAndUnlockAchievements()` called
   - `AchievementUnlockOverlay` shown on results
   - But full achievement UI/progression missing

4. **Recommendations Engine**
   - `PersonalizedRecommendationEngine.swift` exists
   - Results show generic action plan
   - AI-personalized recommendations not integrated

---

## 8. PATTERN INCONSISTENCIES

### Navigation Patterns

| Screen | Pattern | Consistency |
|--------|---------|-------------|
| HomeView | State-based (showScanFlow, showSettings) | ❌ Inconsistent |
| EmotionalScan3DFlowView | State-based (flowState enum) | ✅ Consistent |
| CelebratoryResultsView | Callbacks (onClose, onShareResults) | ❌ Inconsistent |
| SettingsView | Dismiss environment | ⚠️ Mixed |

**Root Cause:** Different developers may have worked on screens at different times with evolving patterns.

### Closure Callback Patterns

**Pattern 1: View callbacks**
```swift
CelebratoryResultsView(
    onShareResults: { showShareSheet = true },
    onClose: { dismiss() }
)
```

**Pattern 2: ViewModel methods**
```swift
viewModel.startGuidance()
viewModel.captureStep()
```

**Pattern 3: ARKit delegates**
```swift
func renderer(_ renderer: SCNSceneRenderer, 
              didUpdate node: SCNNode, for anchor: ARAnchor)
```

**Pattern 4: Observation + onChange**
```swift
.onChange(of: viewModel.currentGeometry) { newGeometry in
    onGeometryUpdate?(newGeometry)
}
```

### Error Handling Inconsistencies

**Good Error Handling:**
```swift
do {
    try await withTimeout(seconds: timeout) {
        let merged = await viewModel.finalizeCapture()
    }
} catch let scanError as ScanError {
    // Detailed error specific handling
} catch let timeoutError as TimeoutError {
    // Timeout specific handling
}
```

**Weak Error Handling:**
```swift
guard let sessions = try? context.fetch(request),
      let lastSession = sessions.first,
      let data = lastSession.clinicalMetricsData,
      let metrics = try? JSONDecoder().decode(Face3DMetrics.self, from: data) else {
    print("ℹ️ No previous clinical metrics found")
    return nil  // Silently fails
}
```

---

## 9. MISSING ERROR HANDLING & EDGE CASES

### Critical Edge Cases Not Handled

1. **Multi-Pose Synchronization**
   - What if device loses face tracking between poses?
   - What if user cancels mid-sequence?
   - Currently: Guidance active flag is cleared, but partial data remains
   - ⚠️ **Risk:** Corrupted sequences with incomplete data

2. **Memory Pressure**
   - Texture baking: ~67MB
   - Merged mesh: ~30MB
   - Metrics computation: significant RAM
   - On older devices (iPhone 11), could cause crashes
   - **Mitigation:** Memory warning handler exists but reactive

3. **Network Access During Scan**
   - App doesn't require internet
   - But if metrics server integration added, no offline fallback
   - **Risk:** Future feature could break offline-first design

4. **Core Data Failures**
   - `saveToCoreData()` has try/catch in `processCapture()`
   - But continues if fails (silent)
   - **Risk:** User thinks scan saved, but it didn't

   ```swift
   do {
       try await withTimeout(seconds: ...) {
           await saveToCoreData(...)
       }
   } catch {
       AppLogger.faceScan.warning("⚠️ Core Data save failed... - continuing anyway")
   }
   ```

5. **JSON Deserialization**
   - When loading previous metrics from Core Data:
   - No version checking
   - No schema migration
   - If `Face3DMetrics` structure changes, old data fails silently

6. **Texture Baking**
   - Could fail if:
     - Texture samples missing (no coverage)
     - Mesh validation fails
     - Memory insufficient
   - **Current handling:** Generic error message

---

## 10. CONTINUITY & FLOW ISSUES

### Issue: Scan Completion Condition

**Current Code (TESTING MODE):**
```swift
.onChange(of: viewModel.capturedPoses.count) { newCount in
    if newCount >= 1 {  // ❌ TESTING MODE
        onCaptureComplete?(viewModel.capturedPoses)
    }
}
```

**Should Be:**
```swift
if newCount >= GuidanceStep.allCases.count {  // 7 poses
    onCaptureComplete?(viewModel.capturedPoses)
}
```

**Impact:** 
- Users only capture 1 angle (straight face)
- 3D reconstruction fails with insufficient data
- Results are unreliable

---

### Issue: Quality Check Inconsistency

**During Countdown:**
- Quality checks disabled
- Only pose validity checked
- **Rationale:** User already positioned correctly

**During Merge:**
```swift
if !edgeCases.shouldProceed && !continueAnywayOverride {
    errorMessage = "Scan blocked..."
    return false
}
```
- Runs pre-flight checks again
- **Inconsistency:** Different validation at different stages

---

### Issue: Guidance Step Completion

**Flow:**
1. User captures pose (3 frames captured)
2. Auto-moves to next step
3. OR: All steps captured, waits for finalize
4. **Problem:** No clear indication to user when ready to finalize

**Missing UI:**
- "All poses captured! Ready to finalize?" message
- "5/7 poses captured" progress indicator (shown but could be clearer)
- Finalize button not prominently displayed

---

### Issue: State Synchronization

**Potential Race Condition:**
```swift
// Thread 1: ARKit delegate
viewModel.updateGeometry(faceAnchor: faceAnchor, frame: frame)

// Thread 2: User taps "Cancel"
viewModel.stopGuidance()

// Could happen: updateGeometry runs after stopGuidance()
```

**Risk Level:** Low (both run on MainActor), but shows tight coupling

---

## 11. ARCHITECTURAL STRENGTHS

### What's Well Designed

1. **MainActor Safety**
   ```swift
   @MainActor public class FaceScan3DViewModel: ObservableObject
   ```
   - All UI updates guaranteed on main thread
   - Delegates properly marshal to main thread

2. **Separation of Concerns**
   - ARKit handling: `ARFaceTrackingViewController`
   - Mesh processing: `MeshMerger`, `StreamingMeshMerger`
   - Metrics analysis: `Face3DMetricsAnalyzer`
   - UI coordination: `FaceScan3DViewModel`
   - Screen flow: `EmotionalScan3DFlowView`

3. **Comprehensive Logging**
   - 5+ logging categories (AppLogger, faceScan, mesh, storage, etc.)
   - Structured logging with context
   - Easy to diagnose issues

4. **Memory Management**
   - Proper handling of large data structures
   - Observers deregistered in deinit
   - Memory warning handler
   - Streaming merger for large meshes

5. **Processing Pipeline**
   - Timeout protection on all long operations
   - Batch processing with progress reporting
   - Async/await for non-blocking ops
   - Proper error propagation

---

## 12. ARCHITECTURAL WEAKNESSES

### Critical Issues

1. **Testing Mode Code in Production**
   - Reduces capture from 7 poses to 1
   - Completely invalidates 3D scanning
   - **Priority:** Fix before any release

2. **Monolithic ViewModel**
   - `FaceScan3DViewModel` handles:
     - Calibration logic
     - Guidance state management
     - Mesh capture & merging
     - Texture baking
     - Metrics computation
     - Memory management
   - **Better approach:** Separate into:
     - `CalibrationManager`
     - `CaptureSequenceManager`
     - `MeshProcessor`
     - `MetricsAnalyzer`

3. **Tight Coupling in Data Flow**
   - `EmotionalScan3DFlowView` directly calls multiple ViewModel methods
   - No clear action/event pattern
   - Hard to test individual components
   - **Better approach:** Redux/MVVM-C pattern

4. **Magic Numbers**
   ```swift
   let targetFrameCount: Int = 12
   let minimumFrameCount: Int = 8
   let qualityCheckInterval: Int = 15
   let countdownToleranceFrames: Int = 15
   ```
   - No centralized configuration
   - Scattered across files
   - Hard to tune without rebuilding

5. **Inconsistent Error Handling**
   - Some errors thrown and caught
   - Some silently logged
   - Some shown to user
   - No clear pattern

---

## 13. DETAILED COMPONENT BREAKDOWN

### FaceScan3D Feature (95 total files in Features, 30+ are FaceScan3D)

**Directory Structure:**
```
FaceScan3D/
├── ViewModels/ (1 file - FaceScan3DViewModel.swift)
├── Views/ (9 files)
│   ├── FaceScan3DView.swift (SwiftUI wrapper)
│   ├── ARFaceTrackingViewController.swift (UIKit ARKit)
│   ├── EmotionalScan3DFlowView.swift (Flow coordinator)
│   ├── CalibrationOverlay.swift (Real-time UI)
│   ├── Face3DViewer.swift (Mesh visualization)
│   └── ... (ScanPreparationView, TexturedMeshPreviewView, etc.)
├── Models/ (8 files)
│   ├── CaptureSequence.swift
│   ├── Face3DMetrics.swift
│   ├── EmotionalMetrics.swift
│   └── ... (CalibrationState, ScanError, etc.)
├── Metrics/ (14 files)
│   ├── GlowAnalyzer.swift
│   ├── WrinkleAnalyzer.swift
│   ├── PoreAnalyzer.swift
│   └── ... (AcneAnalyzer, VolumeMetrics, etc.)
├── Processing/ (8 files)
│   ├── MeshMerger.swift
│   ├── StreamingMeshMerger.swift
│   ├── ICPAligner.swift
│   └── ... (HoleFiller, MeshSmoother, etc.)
├── Utilities/ (24 files)
│   ├── Face3DMetricsAnalyzer.swift (main analyzer)
│   ├── ExportManager.swift
│   ├── MeshExporter.swift
│   └── ... (EdgeCaseDetector, Scoring3D, etc.)
└── UI/ (7 files)
    ├── ClinicalInfoView.swift
    ├── ResultsInterpretation.swift
    └── ... (ComparisonView, ProgressTracking, etc.)
```

**Critical Files:**
1. `FaceScan3DViewModel.swift` - Central orchestrator (~1800 lines)
2. `Face3DMetricsAnalyzer.swift` - Main analysis engine
3. `EmotionalScan3DFlowView.swift` - Complete scan orchestration
4. `ARFaceTrackingViewController.swift` - ARKit integration

---

## 14. CONNECTION MAP: How Components Connect

### Data Flow Diagram

```
ARFaceTrackingViewController
    ↓ (ARSCNViewDelegate)
    └→ FaceScan3DViewModel
        ├→ Publishes: currentGeometry, lightEstimation, blendShapes
        ├→ Manages: calibrationState, guidanceFeedback
        ├→ Stores: currentSequence (MeshCapture[])
        │
        ├→ captureStep() → currentSequence.addCapture(MeshCapture)
        ├→ finalizeCapture() → MergedFaceMesh
        ├→ bakeTextureFromSequence() → TextureBakeResult
        └→ compute3DMetrics() → Face3DMetrics
            └→ Analyzed by: Face3DMetricsAnalyzer
                ├→ Wrinkles: WrinkleAnalyzer
                ├→ Acne: AcneAnalyzer
                ├→ Pores: PoreAnalyzer
                ├→ Elasticity: SkinElasticity
                ├→ Volume: VolumeMetrics
                └→ ... (10+ more specialized analyzers)

FaceScan3DView (SwiftUI wrapper)
    ├→ Observes: @ObservedObject viewModel
    ├→ Callbacks: onGeometryUpdate, onCaptureComplete
    └→ ARFaceTrackingViewRepresentable (UIViewControllerRepresentable)
        └→ Creates/updates: ARFaceTrackingViewController

CalibrationOverlay.swift
    ├→ Observes: viewModel.calibrationState
    ├→ Shows: Guidance feedback, countdown, warnings
    └→ Checks: viewModel.capturedPoses.count for completion

EmotionalScan3DFlowView (Main Coordinator)
    ├→ Creates: @StateObject viewModel = FaceScan3DViewModel()
    ├→ Manages: FlowState (enum)
    ├→ Orchestrates:
    │   ├→ viewModel.startGuidance()
    │   ├→ viewModel.finalizeCapture() → MergedFaceMesh
    │   ├→ viewModel.bakeTextureFromSequence() → TextureBakeResult
    │   ├→ viewModel.compute3DMetrics() → Face3DMetrics
    │   └→ saveToCoreData(metrics)
    │
    └→ Shows results: CelebratoryResultsView
        ├→ Callbacks: onShareResults, onClose
        └→ Shows: EmotionalMetrics (user-facing)

HomeView
    ├→ @FetchRequest: SessionResult[]
    ├→ Shows: Latest scan card from SessionResult
    └→ Navigation: .sheet → EmotionalScan3DFlowView

ResultsViewModel
    ├→ Uses: StorageManager.shared
    ├→ Operations: loadSessions, deleteSession, saveSession
    └→ Updates Core Data via: PersistenceController

Core Data Layer
    ├→ Entity: SessionResult
    ├→ Stores: emotionalMetricsData (JSON), clinicalMetricsData (JSON)
    └→ Managed by: PersistenceController.shared
```

### Callback Chains

```
ARFaceTrackingViewController.renderer(didUpdate:)
    ↓
viewModel.updateGeometry()
    ↓
checkGuidancePoseAndCapture()
    ├→ Validates: isPoseCorrect, isCalibrated, qualityGood
    ├→ If all good: startCaptureCountdown()
    │   └→ Timer fires 3 times
    │       └→ capturePose()
    │           ├→ Creates: CapturedPoseData
    │           ├→ Calls: captureStep() 3x
    │           │   └→ currentSequence.addCapture(MeshCapture)
    │           ├→ Calls: captureTextureSample()
    │           │   └→ currentSequence.addTextureSample()
    │           └→ Updates UI: isCaptureInProgress = false
    │
    ├→ FaceScan3DView.onChange(of: capturedPoses.count)
    │   └→ Calls: onCaptureComplete?(capturedPoses)
    │
    └→ EmotionalScan3DFlowView.onCaptureComplete
        └→ Triggers: processCapture()
            ├→ finalizeCapture() → MergedFaceMesh
            ├→ bakeTextureFromSequence() → TextureBakeResult
            ├→ compute3DMetrics() → Face3DMetrics
            ├→ saveToCoreData()
            └→ Display: CelebratoryResultsView
```

---

## 15. SUMMARY OF ISSUES

### Severity Breakdown

| Severity | Count | Examples |
|----------|-------|----------|
| **Critical** | 3 | Testing mode captures, Challenge update, JSON migration |
| **High** | 6 | State sync race conditions, Error handling inconsistency, Memory pressure handling |
| **Medium** | 8 | Navigation pattern inconsistency, Monolithic ViewModel, Magic numbers |
| **Low** | 5 | UI/UX improvements, Documentation, Code organization |

### By Category

**Architecture (8 issues)**
- Monolithic FaceScan3DViewModel
- Tight coupling in data flow
- Inconsistent error handling patterns
- Magic numbers scattered across files

**State Management (5 issues)**
- Navigation pattern inconsistency
- Callback vs environment inconsistency
- Race conditions possible (low risk)
- State duplication in multiple places

**Features (4 issues)**
- Testing mode code in production
- Incomplete gamification
- Incomplete social sharing
- Incomplete before/after comparison

**Data Handling (4 issues)**
- JSON schema migration missing
- Core Data save failures silent
- Memory pressure reactive (not proactive)
- No offline fallback for future network features

**Edge Cases (3 issues)**
- Multi-pose interruption handling
- Texture baking failures unclear
- Deserialization failures silent

---

## 16. RECOMMENDATIONS

### Immediate Actions (Pre-Release)

1. **Fix Testing Mode** (CRITICAL)
   - Change line ~1180 in FaceScan3DViewModel.swift
   - Change `if newCount >= 1` to `>= GuidanceStep.allCases.count`
   - Update CalibrationOverlay.swift similarly
   - Enable full 7-pose capture

2. **Add Completion State**
   - Add `.allCaptured` case to FlowState
   - Show clear "Ready to finalize?" message
   - Add prominent finalize button

3. **Implement Core Data Error Handling**
   - Don't silently fail on save
   - Show user if data wasn't saved
   - Retry mechanism for transient failures

### Short Term (Next Sprint)

1. **Refactor FaceScan3DViewModel**
   - Extract `CalibrationManager` (300 lines)
   - Extract `CaptureSequenceManager` (250 lines)
   - Keep ViewModel as thin coordinator
   - **Benefit:** Easier testing, clearer responsibilities

2. **Unify Navigation Pattern**
   - Convert all callbacks to state-based navigation
   - Use NavigationLink consistently
   - **Benefit:** Single pattern throughout app

3. **Centralize Configuration**
   - Create `ScanConstants.swift`
   - Move all magic numbers
   - Add documentation for each constant
   - **Benefit:** Easier tuning, clear intent

### Medium Term (v2.0)

1. **Add Data Versioning**
   - Version metrics structs
   - Add migration functions
   - Handle schema evolution
   - **Benefit:** Can update metrics without data loss

2. **Implement Offline Fallback**
   - If future network features added
   - Cache locally first
   - Sync when possible
   - **Benefit:** Works without internet

3. **Complete Gamification**
   - Finish challenge update mechanism
   - Add full achievement progression UI
   - Connect to results screen
   - **Benefit:** Full user engagement

4. **Add Metrics Export**
   - CSV export of session history
   - PDF detailed reports
   - Share progress with doctor
   - **Benefit:** Medical integration

---

## CONCLUSION

The Tavi app has a **solid foundation** with good separation of concerns, proper async/await usage, and comprehensive error handling in most places. However, **testing mode code must be removed before any production release**, and the monolithic ViewModel should be refactored into separate managers for maintainability.

The architecture is **scalable but shows signs of organic growth** - patterns evolved over time without full consolidation. Unifying navigation patterns and configuration management would significantly improve code maintainability.

**Overall Assessment:** 7.5/10
- Strengths: Threading, error handling, feature completeness
- Weaknesses: Testing code in production, monolithic ViewModel, pattern inconsistency
