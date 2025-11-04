# Tavi App - Architecture Diagrams & Visual References

---

## 1. COMPLETE APP STATE MACHINE

```
┌─────────────────────────────────────────────────────────────┐
│                       TaviApp (Entry)                       │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ├─→ PersistenceController.init()
                             ├─→ CrashReporter.configure()
                             └─→ MemoryMonitor.start()
                                  │
                                  ↓
┌─────────────────────────────────────────────────────────────┐
│                   ContentView (Navigation)                  │
│                         ↓                                    │
│                    HomeView (Hub)                           │
└────────────────────────────┬────────────────────────────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
                ↓            ↓            ↓
         ┌─────────┐  ┌─────────┐  ┌──────────┐
         │ Onboard │  │  Scan   │  │ Settings │
         │  Flow   │  │  Flow   │  │   View   │
         └────┬────┘  └────┬────┘  └──────────┘
              │             │
              ↓             ↓
      [State: preparing] [EmotionalScan3DFlowView]
                            │
                ┌───────────┼───────────┐
                │           │           │
                ↓           ↓           ↓
         ┌──────────┐ ┌──────────┐ ┌──────────┐
         │Prepare   │ │Capturing │ │Processing│
         │(countdown)│ │(ARKit)   │ │(Mesh+    │
         │3→0       │ │          │ │ Texture) │
         └──────────┘ └──────────┘ └──────────┘
                │           │           │
                └───────────┼───────────┘
                            │
                            ↓
                    ┌────────────────┐
                    │ Results Ready  │
                    │(EmotionalScore)│
                    └────────┬───────┘
                             │
                    ┌────────┴────────┐
                    ↓                 ↓
              [Share]            [Close]
                    │                 │
                    └────────┬────────┘
                             │
                             ↓
                    [Save to Core Data]
                             │
                             ↓
                    [Back to HomeView]
```

---

## 2. FACESCAN3D COMPONENT INTERACTION DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARKit Layer (Delegate)                       │
│         ARFaceTrackingViewController (UIViewController)         │
│                    + ARSCNViewDelegate                          │
│                   + ARSessionDelegate                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┤─────────────────────┐
         │                   │                     │
    renderer()          renderer(didUpdate)   session(didFail)
    nodeFor()           for ARFaceAnchor       Error delegate
         │                   │                     │
         ↓                   ↓                     ↓
      Create          ┌─────────────────┐    sessionFailed()
     SCNNode       (Main Thread)         │    error reporting
       from         updateGeometry()     │
    ARSCNFace         + lighting        │
    Geometry       + blend shapes       │
         │                   │                     │
         └───────────────────┼─────────────────────┘
                             │
         ┌───────────────────┴───────────────────┐
         │                                       │
         ↓ @Published properties                ↓ observers
    
┌──────────────────────────────────────┐  ┌────────────────────┐
│ FaceScan3DViewModel                  │  │  FaceScan3DView    │
│ @MainActor class                     │  │  @ObservedObject   │
├──────────────────────────────────────┤  └────────────────────┘
│ @Published currentGeometry           │           │
│ @Published lightEstimation           │→──────────┤
│ @Published blendShapes               │           │
│ @Published calibrationState          │  ┌────────────────────┐
│ @Published currentGuidanceStep       │  │CalibrationOverlay  │
│ @Published countdownTimer            │  │Shows real-time     │
│ @Published currentSequence           │  │feedback & guidance │
│ @Published face3DMetrics             │  └────────────────────┘
│ @Published errorMessage              │
│                                      │
│ Methods:                             │
│ • updateGeometry(...)               │
│ • startGuidance()                   │
│ • captureStep() → MeshCapture       │
│ • finalizeCapture() → MergedMesh    │
│ • bakeTextureFromSequence()         │
│ • compute3DMetrics() → Face3DMetrics│
│                                      │
│ Private:                             │
│ • checkGuidancePoseAndCapture()     │
│ • startCaptureCountdown()           │
│ • capturePose()                     │
│ • checkImageQuality()               │
└──────────────────────────────────────┘
         │
         ├─→ currentSequence: CaptureSequence
         │        ├─→ captures: [MeshCapture]
         │        └─→ textureSamples: [PoseSample]
         │
         ├─→ mergedMesh: MergedFaceMesh
         │        └─→ (from MeshMerger/StreamingMeshMerger)
         │
         └─→ bakeResult: TextureBakeResult
                  ├─→ unifiedMesh: MergedFaceMesh
                  └─→ albedoTexture: CGImage
```

---

## 3. CAPTURE PIPELINE - DETAILED FLOW

```
FaceScan3DViewModel.checkGuidancePoseAndCapture()
│
├─→ Extract rotation angles (yaw, pitch, roll)
│
├─→ Check: isPoseValid (within bounds for current step)
│
├─→ Update: calibrationState
│   ├─→ calibrationState.distance (from face anchor)
│   ├─→ calibrationState.lighting (from ARFrame)
│   └─→ calibrationState.stability (from transform delta)
│
├─→ Check: isCalibrated (all three green)
│
├─→ Check: Image quality (if pose valid)
│   ├─→ Quality check throttling (every 15 frames)
│   ├─→ Lighting consistency
│   ├─→ Blend shapes validation
│   │   ├─→ No smiling/frowning
│   │   ├─→ No jaw movement
│   │   ├─→ No eye blinking
│   │   ├─→ No eyebrow movement
│   │   └─→ etc.
│   ├─→ Exposure analysis
│   ├─→ Occlusion detection
│   └─→ returns: qualityGood (bool)
│
├─→ If [isPoseValid && isCalibrated && qualityGood && !busy]
│   │
│   ├─→ IF countdownTimer == 0:
│   │   └─→ startCaptureCountdown(3)
│   │       ├─→ Timer: every 1 second
│   │       │   ├─→ Check pose still valid
│   │       │   ├─→ Decrement counter
│   │       │   ├─→ Update UI "Hold still! 2..."
│   │       │   └─→ At count == 0: Capture!
│   │       │
│   │       └─→ Haptic feedback (medium pulse)
│   │
│   └─→ Reset tolerance counter
│
└─→ ELSE: Log reasons for not starting countdown
```

**When Timer Reaches 0: capturePose() is called**

```
capturePose(faceAnchor, yaw, pitch, roll)
│
├─→ Create: CapturedPoseData
│   ├─→ step: currentGuidanceStep
│   ├─→ geometry: currentGeometry
│   ├─→ angles: (yaw, pitch, roll)
│   └─→ timestamp
│
├─→ Store in capturedPoses[step] = poseData
│
├─→ Capture 3 frames per pose (multi-frame averaging)
│   │
│   └─→ FOR i IN 0..<3:
│       └─→ captureStep()
│           │
│           ├─→ Guard: geometry, lightEstimation, currentSequence
│           │
│           ├─→ Create: MeshCapture
│           │   ├─→ vertices: [Vector3]
│           │   ├─→ triangleIndices: [Int32]
│           │   ├─→ normals: [Vector3]
│           │   ├─→ textureCoordinates: [Vector2]
│           │   ├─→ transform: Matrix4x4
│           │   ├─→ angles: yaw, pitch, roll
│           │   └─→ lighting: ambient intensity, color temp
│           │
│           └─→ currentSequence.addCapture(meshCapture)
│               └─→ Updates metadata (lighting, distance ranges)
│
├─→ Capture texture sample
│   │
│   └─→ captureTextureSample(faceAnchor)
│       ├─→ Get camera image from ARFrame
│       ├─→ Create: PoseSample
│       │   ├─→ step: "lookStraight"
│       │   ├─→ rgbFrame: UIImage
│       │   ├─→ exposure: Float
│       │   └─→ focusSharpness: Float
│       │
│       └─→ currentSequence.addTextureSample(sample)
│
├─→ Set: isCaptureInProgress = false
│
└─→ [Back to checkGuidancePoseAndCapture for next frame]
    ├─→ If all 7 poses captured:
    │   └─→ FaceScan3DView.onChange triggers onCaptureComplete
    │       └─→ EmotionalScan3DFlowView.onCaptureComplete called
    │           └─→ processCapture() starts
    │
    └─→ If next pose needed:
        └─→ currentGuidanceStep moved to next
            └─→ Calibration starts fresh for new angle
```

---

## 4. PROCESSING PIPELINE - MESH & METRICS

```
EmotionalScan3DFlowView.processCapture()
│
├─→ flowState = .processing
│   └─→ Shows: "Merging your 3D face scan... ✨"
│
├─→ Step 1: MERGE MESHES
│   │
│   └─→ viewModel.finalizeCapture()
│       │
│       ├─→ Guard: currentSequence has captures
│       │
│       ├─→ Validate captures (check vertices not empty)
│       │
│       ├─→ Calculate total vertices
│       │
│       ├─→ Choose merger strategy:
│       │   │
│       │   ├─→ IF vertices > 50K: StreamingMeshMerger
│       │   │   ├─→ Process frames in chunks
│       │   │   ├─→ Avoid memory spikes
│       │   │   └─→ Progress: streaming merge progress
│       │   │
│       │   └─→ ELSE: Standard MeshMerger
│       │       ├─→ Merge all captures with ICP alignment
│       │       ├─→ Returns: MergedFaceMesh
│       │       └─→ Mesh format: vertices, triangles, normals, UVs
│       │
│       ├─→ Validate merged mesh not nil
│       │
│       ├─→ Mark sequence.complete()
│       │
│       └─→ Return: MergedFaceMesh
│
├─→ Step 2: BAKE TEXTURE
│   │
│   └─→ flowState = .processing
│       └─→ Shows: "Creating your skin texture map... 🎨"
│
│   └─→ viewModel.bakeTextureFromSequence()
│       │
│       ├─→ Guard: mergedMesh exists
│       ├─→ Guard: textureSamples not empty
│       │
│       ├─→ textureBaker.bakeUnifiedTexture(
│       │       unifiedMesh: mergedMesh,
│       │       samples: textureSamples
│       │   )
│       │
│       ├─→ TextureBaker processes:
│       │   ├─→ Read resolution from settings
│       │   │   ├─→ High-res: 4096×4096
│       │   │   └─→ Standard: 2048×2048
│       │   │
│       │   ├─→ For each texture sample:
│       │   │   ├─→ Project RGB frame onto merged mesh
│       │   │   ├─→ Handle UV coordinates
│       │   │   ├─→ Blend overlapping regions
│       │   │   └─→ Handle occlusions
│       │   │
│       │   └─→ Returns: TextureBakeResult
│       │       ├─→ unifiedMesh: MergedFaceMesh
│       │       ├─→ albedoTexture: CGImage (RGB)
│       │       ├─→ coveragePercentage: Float
│       │       └─→ processingTime: TimeInterval
│       │
│       └─→ Return: TextureBakeResult
│
├─→ Step 3: COMPUTE METRICS
│   │
│   └─→ flowState = .processing
│       └─→ Shows: "Analyzing your skin... 🔬"
│
│   └─→ viewModel.compute3DMetrics()
│       │
│       ├─→ Guard: bakeResult exists
│       │
│       ├─→ Task.detached (off main thread):
│       │   │
│       │   └─→ metricsAnalyzer.computeMetrics(
│       │           unifiedMesh: bakeResult.unifiedMesh,
│       │           unifiedTexture: bakeResult.albedoTexture
│       │       )
│       │
│       └─→ Face3DMetricsAnalyzer.computeMetrics():
│           │
│           ├─→ For each ROI (forehead, cheeks, chin, etc.):
│           │   │
│           │   ├─→ Create: ROIMaskGenerator
│           │   │   ├─→ Extract ROI vertices from merged mesh
│           │   │   ├─→ Extract ROI pixels from texture
│           │   │   └─→ Create binary mask
│           │   │
│           │   ├─→ Analyze ROI texture:
│           │   │   ├─→ RoughnessAnalyzer
│           │   │   │   └─→ High-frequency texture analysis
│           │   │   │       → roughnessScore (0-100)
│           │   │   │
│           │   │   ├─→ PigmentationAnalyzer
│           │   │   │   └─→ LAB color variance across ROI
│           │   │   │       → pigmentationScore (0-100)
│           │   │   │
│           │   │   ├─→ SpecularAnalyzer
│           │   │   │   └─→ Specular highlight ratio
│           │   │   │       → specularScore (0-100)
│           │   │   │
│           │   │   ├─→ HydrationEstimator
│           │   │   │   └─→ Specular + roughness proxy
│           │   │   │       → moistureProxy
│           │   │   │
│           │   │   ├─→ WrinkleAnalyzer
│           │   │   │   ├─→ 3D curvature analysis on mesh
│           │   │   │   ├─→ Measure actual wrinkle depth (mm)
│           │   │   │   └─→ Regional analysis (crow's feet, forehead)
│           │   │   │
│           │   │   ├─→ PoreAnalyzer
│           │   │   │   ├─→ High-frequency dark spot detection
│           │   │   │   ├─→ Pore density calculation
│           │   │   │   └─→ Average pore size
│           │   │   │
│           │   │   ├─→ AcneAnalyzer
│           │   │   │   ├─→ Color + texture based detection
│           │   │   │   ├─→ Identify blemishes
│           │   │   │   └─→ Severity classification
│           │   │   │
│           │   │   ├─→ RednessAnalyzer
│           │   │   │   ├─→ LAB a* channel (red-green axis)
│           │   │   │   ├─→ Identify inflammation/redness
│           │   │   │   └─→ Severity scoring
│           │   │   │
│           │   │   ├─→ GlowAnalyzer
│           │   │   │   ├─→ Combined: smoothness + evenness + specular
│           │   │   │   ├─→ Formula: 40% smooth + 30% even + 20% no-discolor + 10% specular
│           │   │   │   ├─→ Also compute: radianceScore (pure luminosity)
│           │   │   │   └─→ Regional glow per ROI
│           │   │   │
│           │   │   ├─→ VolumeAnalyzer
│           │   │   │   ├─→ 3D mesh analysis
│           │   │   │   ├─→ Cheek hollowing (age indicator)
│           │   │   │   ├─→ Under-eye bags
│           │   │   │   └─→ Facial symmetry
│           │   │   │
│           │   │   ├─→ SkinTypeClassifier
│           │   │   │   ├─→ Dry/Normal/Oily/Combination
│           │   │   │   └─→ Based on pore size + specular patterns
│           │   │   │
│           │   │   └─→ SunDamageAnalyzer
│           │   │       ├─→ Age spots + discoloration
│           │   │       ├─→ Texture damage patterns
│           │   │       └─→ UV exposure assessment
│           │   │
│           │   └─→ Create: ROI3DMetrics
│           │       ├─→ roi: Face3DROI
│           │       ├─→ roughnessScore, pigmentationScore, specularScore
│           │       ├─→ textureEnergy, labVariance
│           │       ├─→ pixelCount, averageLuminance
│           │       └─→ confidenceLevel
│           │
│           └─→ Aggregate ROI metrics → global scores:
│               ├─→ globalRoughnessScore (weighted by ROI pixel count)
│               ├─→ globalPigmentationScore
│               ├─→ globalDiscolorationScore (inter-ROI variance)
│               ├─→ globalSpecularScore
│               └─→ overallScore (composite 0-100)
│
│           └─→ Return: Face3DMetrics
│               ├─→ roiMetrics: [Face3DROI: ROI3DMetrics]
│               ├─→ globalScores (all float 0-100)
│               ├─→ elasticityAnalysis?
│               ├─→ volumeAnalysis?
│               ├─→ wrinkleAnalysis?
│               ├─→ acneAnalysis?
│               ├─→ rednessAnalysis?
│               ├─→ glowAnalysis?
│               └─→ ... (and more 10+ other analyses)
│
├─→ Step 4: CONVERT TO EMOTIONAL METRICS
│   │
│   └─→ flowState = .processing
│       └─→ Shows: "Calculating your Skin Health Index... 🌟"
│
│   └─→ EmotionalMetricsGenerator.generate(
│           from: clinicalMetrics,
│           previousMetrics: previousMetrics,
│           userProfile: userProfile
│       )
│
│       Returns: EmotionalMetrics
│       ├─→ glowScore: Int (0-100)  [from globalGlowScore]
│       ├─→ smoothness: Int          [from roughnessScore]
│       ├─→ radiance: Int            [from luminosity]
│       ├─→ evenness: Int            [from pigmentationScore]
│       ├─→ youthfulness: Int        [from elasticity/volume]
│       ├─→ freshness: Int           [from hydration proxy]
│       ├─→ sunProtection: Int       [from sun damage analysis]
│       ├─→ personalizedMessage: String
│       └─→ nextSteps: [ActionableStep]
│
├─→ Step 5: UPDATE GAMIFICATION
│   │
│   └─→ flowState = .processing
│       └─→ Shows: "Updating your progress... 🎉"
│
│   ├─→ GamificationManager.recordScan()
│   │   └─→ Updates: currentStreak, totalScans, lastScanDate
│   │
│   └─→ GamificationManager.checkAndUnlockAchievements(
│           totalScans, currentStreak, glowScore,
│           glowImprovement, challengeComplete
│       )
│       └─→ Returns: [Achievement] (newly unlocked)
│
├─→ Step 6: SAVE TO CORE DATA
│   │
│   └─→ flowState = .processing
│       └─→ Shows: "Saving your results... 💾"
│
│   └─→ saveToCoreData(
│           emotionalMetrics: emotional,
│           clinicalMetrics: computedMetrics
│       )
│
│       ├─→ Create: SessionResult (Core Data entity)
│       │   ├─→ id: UUID
│       │   ├─→ date: Date
│       │   ├─→ overallScore: Double (from emotional.glowScore)
│       │   ├─→ emotionalMetricsData: Data (JSON encoded)
│       │   └─→ clinicalMetricsData: Data (JSON encoded)
│       │
│       └─→ context.save()
│           └─→ Persists to database
│
└─→ Step 7: DISPLAY RESULTS
    │
    ├─→ flowState = .complete
    │
    ├─→ Display: CelebratoryResultsView(emotionalMetrics)
    │   ├─→ Hero section: Score interpretation
    │   ├─→ Main score card: Circular progress
    │   ├─→ Metrics breakdown: 5 metric cards
    │   ├─→ Action plan: 3 recommended steps
    │   └─→ Share button: Social sharing
    │
    └─→ Show: Achievement unlock overlay (if any)
        └─→ Display unlocked achievement with emoji
```

---

## 5. STATE DEPENDENCIES MATRIX

```
State Variable                  Depends On                    Updates
─────────────────────────────────────────────────────────────────────
faceDetected                  ARFaceAnchor presence        ✓ every frame
currentGeometry               ARFaceAnchor.geometry        ✓ every frame
lightEstimation               ARFrame light data           ✓ every frame
blendShapes                   ARFaceAnchor.blendShapes     ✓ every frame

calibrationState              distance, lighting, stability  ✓ every frame
  - distance                  face anchor position         ✓ calculated
  - lighting                  lightEstimation              ✓ every frame
  - stability                 transform delta              ✓ each frame

isPoseCorrect                 currentGuidanceStep angles   ✓ calculated
guidanceFeedback              isPoseCorrect + step         ✓ every frame
qualityWarning                checkImageQuality()          ✓ throttled

countdownTimer                isPoseCorrect + calibrated   ✓ 1Hz timer
isCaptureInProgress           capturePose() execution      ✓ event-driven

capturedPoses                 capturePose() completion     ✓ per pose
currentSequence               captureStep() calls          ✓ 3 frames/pose
mergedMesh                    finalizeCapture()            ✓ once per scan

bakeResult                    mergedMesh + textureSamples  ✓ once
face3DMetrics                 bakeResult + analyzer        ✓ once

emotionalMetrics              face3DMetrics + history      ✓ once
achievements                  emotionalMetrics + streaks   ✓ once

flowState                     Pipeline progress            ✓ manual transitions
```

---

## 6. CLASS DEPENDENCY GRAPH

```
TaviApp (main entry)
  ├→ PersistenceController (Core Data, singleton)
  │   ├→ NSPersistentContainer
  │   └→ SessionResult (entity)
  │
  ├→ CrashReporter (singleton)
  ├→ MemoryMonitor (singleton)
  │
  └→ ContentView → HomeView
      ├→ @FetchRequest: SessionResult[]
      ├→ @State: showOnboarding, showScanFlow, showSettings
      │
      ├→ OnboardingFlowView
      │   └→ OnboardingPageView
      │
      ├→ EmotionalScan3DFlowView
      │   ├→ @StateObject FaceScan3DViewModel
      │   │   ├→ @Published: currentGeometry, calibrationState, etc.
      │   │   ├→ MeshMerger
      │   │   ├→ StreamingMeshMerger
      │   │   ├→ TextureBaker
      │   │   ├→ Face3DMetricsAnalyzer
      │   │   │   ├→ RoughnessAnalyzer
      │   │   │   ├→ PigmentationAnalyzer
      │   │   │   ├→ SpecularAnalyzer
      │   │   │   ├→ WrinkleAnalyzer
      │   │   │   ├→ PoreAnalyzer
      │   │   │   ├→ AcneAnalyzer
      │   │   │   ├→ RednessAnalyzer
      │   │   │   ├→ GlowAnalyzer
      │   │   │   ├→ VolumeAnalyzer
      │   │   │   └→ ... (10+ more)
      │   │   ├→ EdgeCaseDetector
      │   │   └→ ImageQualityAnalyzer
      │   │
      │   ├→ FaceScan3DView (SwiftUI wrapper)
      │   │   ├→ @ObservedObject viewModel
      │   │   └→ ARFaceTrackingViewRepresentable
      │   │       └→ ARFaceTrackingViewController (UIViewController)
      │   │           ├→ ARSession (ARKit)
      │   │           ├→ ARSCNView
      │   │           ├→ SCNScene
      │   │           └→ FrameAverager
      │   │
      │   ├→ CalibrationOverlay
      │   │   ├→ @ObservedObject viewModel
      │   │   └→ Real-time calibration UI
      │   │
      │   └→ CelebratoryResultsView
      │       ├→ emotionalMetrics (input)
      │       └→ clinicalMetrics (input, optional)
      │
      ├→ SettingsView
      │   ├→ @AppStorage settings
      │   ├→ CaptureSettingsView
      │   └→ DeviceInfoView
      │
      └→ ResultsViewModel (for history)
          ├→ @Published sessions: [SessionResult]
          └→ StorageManager.shared
              └→ PersistenceController.shared

GamificationManager (singleton)
  ├→ recordScan()
  ├→ getStreak()
  ├→ checkAndUnlockAchievements()
  └→ getCurrentChallenge()

UserProfileManager (singleton)
  ├→ loadProfile()
  └→ updateName()
```

---

## 7. ERROR HANDLING PATHS

```
processCapture() Error Handling Tree
│
├─→ Mesh Merge Phase
│   └─→ viewModel.finalizeCapture()
│       ├─→ Guard: sequence has captures
│       │   └─→ ScanError.invalidData
│       │
│       ├─→ TimeoutError (if merge > 60s)
│       │   └─→ flowState = .error("Processing timed out...")
│       │
│       ├─→ Merge returns nil
│       │   └─→ ScanError.mergeFailed(reason)
│       │       └─→ flowState = .error(userMessage)
│       │
│       └─→ Success: return MergedFaceMesh
│
├─→ Texture Bake Phase
│   └─→ viewModel.bakeTextureFromSequence()
│       ├─→ Guard: mergedMesh exists
│       │   └─→ ScanError.bakeFailed
│       │
│       ├─→ Guard: textureSamples not empty
│       │   └─→ ScanError.bakeFailed
│       │
│       ├─→ Baking fails
│       │   └─→ ScanError.bakeFailed(reason)
│       │
│       └─→ Success: return TextureBakeResult
│
├─→ Metrics Computation Phase
│   └─→ viewModel.compute3DMetrics()
│       ├─→ Guard: bakeResult exists
│       │   └─→ ScanError.metricsFailed
│       │
│       ├─→ Task.detached() fails
│       │   └─→ ScanError.metricsFailed
│       │
│       ├─→ Timeout (if > 90s)
│       │   └─→ ScanError.processingTimeout
│       │
│       └─→ Success: return Face3DMetrics
│
├─→ Gamification Update Phase
│   └─→ GamificationManager.recordScan()
│       └─→ (Cannot fail - just updates local state)
│
├─→ Core Data Save Phase
│   └─→ saveToCoreData()
│       ├─→ CoreData save fails
│       │   └─→ Log warning but continue!
│       │       └─→ ⚠️ User thinks scan saved, but it didn't
│       │
│       └─→ Success: Data persisted
│
└─→ Display Results
    └─→ flowState = .complete
        └─→ CelebratoryResultsView shown
```

---

## 8. DATA SERIALIZATION PATHS

```
Raw ARKit Data                  Internal Processing          Persistence
──────────────────────────────────────────────────────────────────────
ARFaceAnchor
├─ geometry                     FaceMeshGeometry
│  └─ vertices (SIMD3[Float])    ├─ vertices (SIMD3[Float])
│  └─ normals (SIMD3[Float])     ├─ normals (SIMD3[Float])
│  └─ textureCoords              └─ textureCoordinates
│
└─ transform                    MeshCapture (Codable)
   └─ simd_float4x4 matrix      ├─ vertices (Vector3[])      [→ JSON]
                                ├─ normals (Vector3[])       [→ JSON]
                                ├─ transform (Matrix4x4)     [→ JSON]
                                └─ yaw, pitch, roll
                                
ARFrame (image)                 PoseSample
├─ capturedImage (CVPixelBuffer) ├─ rgbFrame (UIImage)
├─ camera parameters            ├─ exposure (Float)
└─ timestamp                     ├─ focusSharpness (Float)
                                └─ step (String)

CaptureSequence (class)
├─ captures: [MeshCapture]
├─ textureSamples: [PoseSample]
└─ metadata

                                MergedFaceMesh (Codable)   SessionResult (Core Data)
                                ├─ vertices (Vector3[])     ├─ id: UUID
                                ├─ normals (Vector3[])      ├─ date: Date
                                ├─ textureCoordinates       ├─ overallScore: Double
                                └─ sourceCount              ├─ emotionalMetricsData:
                                                            │   Data (JSON of
                                                            │   EmotionalMetrics)
Face3DMetrics (Codable)                                     │
├─ roiMetrics: [ROI3DMetrics]   ─────────────────────→     ├─ clinicalMetricsData:
├─ globalScores                                            │   Data (JSON of
├─ elasticityAnalysis?           [Also stored as JSON]     │   Face3DMetrics)
└─ ... (20+ sub-analyses)                                  └─ individual scores
                                                            (redundant copy)

EmotionalMetrics (Codable)
├─ glowScore: Int
├─ smoothness: Int
├─ radiance: Int
└─ nextSteps: [ActionableStep]
```

---

## 9. TESTING MODE vs PRODUCTION MODE

```
CURRENT STATE (TESTING MODE)
═════════════════════════════════════════════════════════════

File: FaceScan3DViewModel.swift, line ~1180
File: FaceScan3DView.swift, line ~53
File: CalibrationOverlay.swift

Code:
    if newCount >= 1 {  // ❌ BUG
        onCaptureComplete?(viewModel.capturedPoses)
    }

Impact:
  • Scan completes after 1 pose (straight face)
  • 3D mesh reconstruction insufficient
  • Results completely unreliable
  • All metrics inaccurate

Example Flow:
  1. User starts scan
  2. Captures "look straight" → count = 1
  3. Automatically triggers completion
  4. User never captures other 6 poses
  5. Merge fails or produces garbage
  6. Metrics meaningless


PRODUCTION MODE (SHOULD BE)
═════════════════════════════════════════════════════════════

Code:
    if newCount >= GuidanceStep.allCases.count {  // ✓ CORRECT
        onCaptureComplete?(viewModel.capturedPoses)
    }

GuidanceStep.allCases = [
    .lookStraight (0°, 0°, 0°)
    .lookUp (0°, +30°, 0°)
    .lookDown (0°, -30°, 0°)
    .lookLeft (+40°, 0°, 0°)
    .lookRight (-40°, 0°, 0°)
    .lookTiltLeft (0°, 0°, +30°)
    .lookTiltRight (0°, 0°, -30°)
]

Flow:
  1. User starts scan
  2. Captures "look straight" → count = 1 → move to step 2
  3. Captures "look up" → count = 2 → move to step 3
  4. ... (continue through all 7)
  5. Captures "look tilt right" → count = 7 → COMPLETE!
  6. Merge 7 poses with proper coverage
  7. Generate accurate 3D model
  8. Metrics reliable across all face regions
```

---

## 10. CRITICAL PATH SUMMARY

```
Success Path (Happy Path)
────────────────────────────────────────────────────────
User taps "Scan Now"
    │
    ↓ (3 second countdown)
    │
    ├─→ Flow: .preparing(3) → .preparing(2) → .preparing(1) → .capturing
    │
    ↓
ARKit tracks face continuously
    │
    ├─→ Update geometry 30-60 fps
    ├─→ Validate: pose, calibration, quality
    ├─→ IF all green → start 3-second countdown
    ├─→ At countdown=0 → capture 3 frames + texture sample
    │
    ├─→ Repeat for all 7 guidance poses
    │   (or 1 pose in TESTING MODE ❌)
    │
    ↓
flowState = .processing
    │
    ├─→ "Merging..." → finalizeCapture() → MergedFaceMesh
    ├─→ "Creating texture..." → bakeTexture() → TextureBakeResult
    ├─→ "Analyzing..." → compute3DMetrics() → Face3DMetrics
    ├─→ Convert to → EmotionalMetrics
    ├─→ Update → GamificationManager
    ├─→ Save → SessionResult (Core Data)
    │
    ↓
flowState = .complete
    │
    ├─→ Show CelebratoryResultsView
    ├─→ Show achievement unlock (if any)
    ├─→ Option to share results
    ├─→ Dismiss back to HomeView
    │
    ↓
HomeView.latestSession shows new scan


Failure Paths
────────────────────────────────────────────────────────
ARKit fails to track face
    └─→ sessionFailed() → flowState = .error("Face tracking failed")

Pose validation fails during countdown
    └─→ Cancel countdown, wait for user to reposition

Quality check fails
    └─→ qualityWarning = "Adjust lighting..."
    └─→ Wait for conditions to improve

Mesh merge fails
    └─→ flowState = .error("Failed to merge 3D face meshes...")
    └─→ Button: "Try Again"

Texture bake fails
    └─→ flowState = .error("Failed to generate skin texture...")

Metrics computation times out
    └─→ flowState = .error("Processing timed out...")

Core Data save fails
    └─→ Still show results, but log warning
    └─→ ⚠️ RISK: Data not persisted

User cancels during capture
    └─→ Dismiss sheet
    └─→ Return to HomeView
    └─→ No data saved
```

---

This comprehensive diagram set provides a complete visual reference for understanding the Tavi app's architecture, data flows, and error handling paths.
