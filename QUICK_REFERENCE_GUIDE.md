# Tavi App - Quick Reference Guide

## FILE LOCATIONS & PURPOSES

### Entry Points
- **TaviApp.swift** - App lifecycle, initialization
- **ContentView.swift** - Thin wrapper
- **HomeView.swift** - Main hub screen

### Core Systems
- **FaceScan3DViewModel.swift** - Central orchestrator (1800 lines) ⚠️ MONOLITHIC
- **PersistenceController.swift** - Core Data management
- **StorageManager.swift** - Legacy wrapper (redirects to PersistenceController)

### Main Flows
- **EmotionalScan3DFlowView.swift** - Complete scan coordination
  - State machine: preparing → capturing → processing → complete/error
  - Handles: timeout, error recovery, result display
  
- **ARFaceTrackingViewController.swift** - ARKit integration
  - Delegates: ARSCNViewDelegate, ARSessionDelegate
  - Updates ViewModel every frame (~30-60fps)

### Results & Display
- **CelebratoryResultsView.swift** - Results display (score + metrics)
- **ResultsViewModel.swift** - Session history management
- **CalibrationOverlay.swift** - Real-time guidance UI

### Settings & Configuration
- **SettingsView.swift** - App preferences
- **CaptureSettingsView.swift** - Scan-specific settings
- **DeviceInfoView.swift** - Device information

### Data Models
- **CaptureSequence.swift** - ✅ Changed to class (was struct bug)
- **Face3DMetrics.swift** - Comprehensive metrics (20+ fields)
- **EmotionalMetrics.swift** - User-facing scores
- **ScanError.swift** - Error types

### Processing Pipeline
- **MeshMerger.swift** - Merge captures with ICP alignment
- **StreamingMeshMerger.swift** - Memory-efficient merger for large meshes
- **TextureBaker.swift** - Bake albedo texture onto mesh
- **Face3DMetricsAnalyzer.swift** - Main analysis engine

### Metrics Analyzers (14 files)
- **GlowAnalyzer.swift** - Combined smoothness/evenness/specular
- **WrinkleAnalyzer.swift** - 3D curvature-based depth
- **PoreAnalyzer.swift** - High-frequency texture analysis
- **AcneAnalyzer.swift** - Blemish detection
- **RednessAnalyzer.swift** - Inflammation detection
- **VolumeAnalyzer.swift** - 3D volume metrics
- **SkinTypeClassifier.swift** - Dry/Normal/Oily classification
- **SunDamageAnalyzer.swift** - UV damage detection
- Plus: Elasticity, Pigmentation, Specular, Roughness, etc.

### Utilities & Helpers
- **EdgeCaseDetector.swift** - Pre-flight validation
- **ImageQualityAnalyzer.swift** - Exposure/sharpness checks
- **CalibrationState.swift** - Distance/lighting/stability tracking
- **ScanConfiguration.swift** - Tuning constants
- **ExportManager.swift** - Export functionality
- **HapticManager.swift** - Vibration feedback

---

## CRITICAL BUGS & TODOs

### 🔴 BLOCKING ISSUE - TESTING MODE IN PRODUCTION

**Files Affected:**
1. `FaceScan3DViewModel.swift` line ~1180
2. `FaceScan3DView.swift` line ~53  
3. `CalibrationOverlay.swift`

**Problem:**
```swift
if newCount >= 1 {  // ❌ Should be >= 7
    onCaptureComplete?(viewModel.capturedPoses)
}
```

**Impact:**
- Scan completes after capturing only 1 pose
- 3D reconstruction impossible with single angle
- All metrics are meaningless
- **Status:** Production blocker

**Fix:**
```swift
if newCount >= GuidanceStep.allCases.count {  // 7 poses
    onCaptureComplete?(viewModel.capturedPoses)
}
```

---

### 🟡 HIGH PRIORITY ISSUES

1. **Challenge Update Mechanism**
   - File: `GamificationSystem.swift`
   - Status: TODO comment, not implemented
   - Impact: Gamification incomplete

2. **Sentry Configuration**
   - File: `CrashReporter.swift`
   - Status: Placeholder DSN
   - Impact: Crash reporting not functional

3. **JSON Schema Migration**
   - File: `PersistenceController.swift`
   - Status: No version checking
   - Impact: Data corruption if metrics schema changes

---

## STATE MANAGEMENT QUICK MAP

### ViewModel Classes (with @MainActor)
```
FaceScan3DViewModel (1800 lines)
├─ calibrationState: CalibrationState
├─ currentGeometry: FaceMeshGeometry?
├─ currentSequence: CaptureSequence?
├─ mergedMesh: MergedFaceMesh?
├─ bakeResult: TextureBakeResult?
├─ face3DMetrics: Face3DMetrics?
├─ countdownTimer: Int
├─ errorMessage: String?
├─ qualityWarning: String?
└─ capturedPoses: [GuidanceStep: CapturedPoseData]

ResultsViewModel (50 lines)
├─ sessions: [SessionResult]
├─ isLoading: Bool
└─ errorMessage: String?

DebugViewModel
└─ Various debug metrics
```

### View State (@State/@AppStorage)
```
HomeView
├─ showOnboarding: Bool
├─ showScanFlow: Bool
└─ showSettings: Bool

EmotionalScan3DFlowView
├─ flowState: FlowState (enum)
├─ emotionalMetrics: EmotionalMetrics?
├─ clinicalMetrics: Face3DMetrics?
├─ processingProgress: String
└─ showResults: Bool

SettingsView (@AppStorage)
├─ enableFaceMesh: Bool
├─ enableHighResCapture: Bool
├─ lightingStrictness: String
├─ enableHapticFeedback: Bool
└─ debugModeEnabled: Bool
```

---

## NAVIGATION PATTERNS

### Current Patterns (Inconsistent ⚠️)

**Pattern 1: State Variables**
```swift
@State private var showScanFlow = false
.sheet(isPresented: $showScanFlow) { ... }
```
Used by: HomeView

**Pattern 2: Callbacks**
```swift
CelebratoryResultsView(
    onShareResults: { showShareSheet = true },
    onClose: { dismiss() }
)
```
Used by: CelebratoryResultsView

**Pattern 3: Dismiss Environment**
```swift
@Environment(\.dismiss) private var dismiss
Button("Done") { dismiss() }
```
Used by: SettingsView, OnboardingFlow

**Pattern 4: NavigationStack + Sheet**
```swift
NavigationStack {
    FaceScan3DView()
}.sheet(isPresented: $...) { ... }
```
Used by: EmotionalScan3DFlowView

### Recommendation
Standardize on **State-based navigation** or **NavigationLink** throughout.

---

## DATA FLOW PIPELINE

### Capture → Processing → Results

```
1. ARKit Frame (30-60fps)
   └→ ARFaceTrackingViewController.renderer(didUpdate:)
      └→ FaceScan3DViewModel.updateGeometry()

2. Validation (Real-time)
   ├→ Pose validation
   ├→ Calibration check (distance, lighting, stability)
   └→ Quality check (expression, exposure, blur)

3. Countdown (When all valid)
   └→ 3-second timer
      └→ capturePose() at 0

4. Capture (Per pose, 3 frames)
   ├→ captureStep() × 3
   │  └→ currentSequence.addCapture(MeshCapture)
   └→ captureTextureSample()
      └→ currentSequence.addTextureSample()

5. Repeat (For each of 7 poses)
   └→ After all captured: finalizeCapture()

6. Process (Off-main-actor)
   ├→ Merge: finalizeCapture() → MergedFaceMesh
   ├→ Texture: bakeTextureFromSequence() → TextureBakeResult
   ├→ Analyze: compute3DMetrics() → Face3DMetrics
   ├→ Convert: EmotionalMetricsGenerator → EmotionalMetrics
   ├→ Gamify: GamificationManager.recordScan()
   └→ Persist: saveToCoreData() → SessionResult

7. Display
   └→ CelebratoryResultsView(emotionalMetrics)
      └→ Show score, metrics, recommendations

8. Archive
   └→ HomeView.latestSession shows new scan
```

---

## ERROR HANDLING QUICK REFERENCE

### Timeout Protection (All Operations)
```swift
try await withTimeout(seconds: ScanConfiguration.meshMergeTimeout, ...) { 
    // operation
}
```

**Timeouts:**
- Mesh merge: 120 seconds
- Texture bake: 180 seconds
- Metrics computation: 180 seconds
- Core Data save: 30 seconds

### Error Types (ScanError enum)
```swift
.mergeFailed(reason: String?)
.bakeFailed(reason: String?)
.metricsFailed(analyzer: String?, reason: String?)
.processingTimeout
.arSessionFailed(Error)
.invalidData
.lightingTooLow(current: Float, required: Float)
.blurryImage
.occludedFace
.invalidExpression
.coreDataSaveFailed(Error)
```

### Error Handling Pattern
```swift
do {
    // operation with timeout
} catch let scanError as ScanError {
    // Handle specific scan error
    flowState = .error(scanError.userMessage)
} catch let timeoutError as TimeoutError {
    // Handle timeout
    flowState = .error("Processing timed out...")
} catch {
    // Generic error
    flowState = .error(error.localizedDescription)
}
```

---

## CONFIGURATION CONSTANTS

### Located in: `ScanConfiguration.swift`

**Calibration Thresholds:**
- Max distance: 1.2m
- Min distance: 0.5m
- Lighting acceptable range: 200-2000 lux
- Lighting change acceptable: ±30%
- Color temp change acceptable: ±20%

**Pose Validation (degrees):**
- Yaw tolerance: ±15° per step
- Pitch tolerance: ±15° per step
- Roll tolerance: ±10° per step

**Expression Constraints:**
- Max smile threshold: 0.15
- Max jaw open threshold: 0.15
- Max mouth pucker threshold: 0.15
- Blink detection threshold: 0.5
- Squint threshold: 0.3

**Image Quality:**
- Underexposure threshold: 0.3
- Overexposure threshold: 0.7
- Sharpness threshold: 0.4

---

## CORE DATA SCHEMA

### Entity: SessionResult
```swift
@NSManaged public var id: UUID
@NSManaged public var date: Date
@NSManaged public var deviceModel: String
@NSManaged public var deviceOS: String

// Individual scores (duplicated for easy access)
@NSManaged public var overallScore: Double
@NSManaged public var textureAvg: Double
@NSManaged public var pigmentationAvg: Double
@NSManaged public var blurQuality: Double
@NSManaged public var moistureSpecular: Double
@NSManaged public var moistureSmoothness: Double

// Full metrics as JSON (for detailed access)
@NSManaged public var emotionalMetricsData: Data?  // JSON
@NSManaged public var clinicalMetricsData: Data?   // JSON

// Image data
@NSManaged public var faceImage: Data?
@NSManaged public var heatmaps: [HeatmapType: Data]?
```

---

## MEMORY MANAGEMENT

### Large Data Structures
```
TextureBakeResult       ~67 MB (4K texture)
MergedFaceMesh          ~30 MB (200K+ vertices)
Face3DMetrics           ~5 MB (with all analyses)
Temporary frame buffers ~20 MB (during processing)
```

### Memory Warning Handler
```swift
private func handleMemoryWarning() {
    if bakeResult != nil { bakeResult = nil }      // Free ~67MB
    if mergedMesh != nil { mergedMesh = nil }      // Free ~30MB
    if currentSequence != nil && !isGuidanceActive {
        currentSequence = nil                       // Free ~100MB
    }
}
```

### Best Practices
- ✅ Use `StreamingMeshMerger` for large meshes (>50K vertices)
- ✅ Clear large data in deinit
- ✅ Register memory warning observer
- ✅ Use Task.detached for heavy computation (off main thread)

---

## TESTING MODE DETECTION

### How to Check If Testing Mode Is Active

**Indicator 1:** Scan completes after 1 pose
```swift
// If scan finishes immediately after straight face capture,
// you're in testing mode
```

**Indicator 2:** Check FaceScan3DView.swift line ~53
```swift
.onChange(of: viewModel.capturedPoses.count) { newCount in
    if newCount >= 1 {  // ❌ Testing mode
        onCaptureComplete?(viewModel.capturedPoses)
    }
}
```

**Indicator 3:** Check CalibrationOverlay.swift
```swift
// DEBUG: Show why countdown not starting when everything appears green
```

---

## KEY METRICS EXPLAINED

### Glow Score (0-100)
**Formula:** 40% smoothness + 30% evenness + 20% discoloration + 10% specular

- 90+: Outstanding (skin is smooth, even-toned, not oily, radiant)
- 80-89: Excellent
- 70-79: Good
- 60-69: Fair
- <60: Needs improvement

### Sub-Metrics
| Metric | Range | Meaning |
|--------|-------|---------|
| **Smoothness** | 0-100 | Surface texture quality (inverse of roughness) |
| **Radiance** | 0-100 | Pure luminosity/brightness (LAB L* channel) |
| **Evenness** | 0-100 | Tone uniformity (inverse of pigmentation variance) |
| **Firmness** | 0-100 | Elasticity/youthfulness (from volume analysis) |
| **Clarity** | 0-100 | Overall vitality/freshness (from hydration proxy) |
| **Specular** | 0-100 | Oil control (inverse of oiliness) |
| **Wrinkles** | Depth (mm) | Actual 3D curvature measurement |
| **Pores** | Count/cm² | Pore density |
| **Acne** | Severity | Blemish detection |
| **Redness** | 0-100 | Inflammation level |

---

## COMMON ISSUES & FIXES

### Issue 1: Scan Completes Too Early
**Cause:** Testing mode enabled  
**Check:** Line ~1180 in FaceScan3DViewModel.swift  
**Fix:** Change `>= 1` to `>= GuidanceStep.allCases.count`

### Issue 2: "No face detected"
**Cause:** 
- Device doesn't support Face ID/TrueDepth
- Poor lighting
- Face too far from camera
**Check:** `DeviceCapabilities.current.supportsTrueDepth`

### Issue 3: Quality checks always failing
**Cause:** 
- User blinking/smiling
- Poor lighting
- Overexposure/underexposure
**Check:** `qualityWarning` in ViewModel

### Issue 4: Metrics computation times out
**Cause:**
- Mesh too large (>100K vertices)
- Texture baking failed
- Device under memory pressure
**Check:** Device RAM, close other apps

### Issue 5: Core Data save silent failure
**Cause:**
- No persistent store
- Database corruption
- Insufficient storage
**Check:** `errorMessage` field (often nil even on failure)

---

## USEFUL DEBUG COMMANDS

### Enable Debug Mode
```swift
UserDefaults.standard.set(true, forKey: "debugModeEnabled")
// Then in SettingsView, Debug Mode toggle appears
```

### Show 3D Mesh
```swift
UserDefaults.standard.set(true, forKey: "enableFaceMesh")
// FaceScan3DView will show wireframe during capture
```

### Enable High-Res Texture
```swift
UserDefaults.standard.set(true, forKey: "enableHighResCapture")
// TextureBaker will use 4096×4096 instead of 2048×2048
```

### Reset Onboarding
```swift
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
// Next launch will show onboarding again
```

### Disable Haptic Feedback
```swift
UserDefaults.standard.set(false, forKey: "enableHapticFeedback")
```

### Change Lighting Strictness
```swift
UserDefaults.standard.set("Relaxed", forKey: "lightingStrictness")
// Options: "Strict", "Relaxed", "Off"
```

---

## PERFORMANCE TARGETS

### Frame Rate
- **Target:** 30-60 FPS during capture
- **Actual:** Typically 50-60 FPS on iPhone 14+
- **Bottleneck:** Quality checks (throttled to every 15 frames)

### Capture Duration
- **Per pose:** 3-5 seconds (countdown 3s + capture 0-2s)
- **All 7 poses:** 30-45 seconds
- **Total (with processing):** 5-7 minutes

### Processing Duration
- **Mesh merge:** 30-60 seconds
- **Texture bake:** 60-120 seconds
- **Metrics computation:** 60-120 seconds
- **Total:** ~3-5 minutes per scan

### Memory Usage
- **Peak during capture:** ~200-300 MB
- **Peak during processing:** ~500-700 MB
- **At rest:** ~50 MB
- **Limit:** 1GB (iOS auto-kills if exceeded)

---

## VERSION HISTORY

**Current Build:** Production (with testing mode bug)

**Key Changes:**
- v1.0 (Oct 2024): Initial 3D scanning release
- Added emotional metrics system
- Added comprehensive skin analysis (20+ metrics)
- Added gamification & achievements
- Added Core Data persistence
- ⚠️ Testing mode bug introduced and never fixed

---

## ADDITIONAL RESOURCES

- **FaceScan3D README:** `/Tavi/Features/FaceScan3D/README.md`
- **Calibration Guide:** `/Tavi/Features/FaceScan3D/CALIBRATION_GUIDE.md`
- **Metrics Guide:** `/Tavi/Features/FaceScan3D/FACE3D_METRICS_GUIDE.md`
- **Texture Mapping Guide:** `/Tavi/Features/FaceScan3D/TEXTURE_MAPPING_GUIDE.md`
- **Core Data Setup:** `/Tavi/Core/StorageKit/CORE_DATA_SETUP.md`

---

**Last Updated:** 2025-11-04  
**Architecture Version:** 1.0 (needs refactoring)  
**Status:** Production with critical testing-mode bug
