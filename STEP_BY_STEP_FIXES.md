# Step-by-Step Fixes for Tavi App Issues

## Critical Issues

### 1. Testing Mode in Production (🔴 CRITICAL)

**Location:** `FaceScan3DViewModel.swift:1209-1219`

**Problem:** App only captures 1 pose instead of 7 due to testing code left active.

**Step-by-Step Fix:**

1. Open `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`
2. Navigate to the `capturePose()` method (around line 1160)
3. **Delete lines 1209-1219:**
   ```swift
   // TESTING MODE: Complete after first capture only
   // TODO: Remove this before production - this is for testing skin analysis
   AppLogger.faceScan.info("🧪 TESTING MODE: Completing scan after first capture")
   ```
4. **Uncomment lines 1221-1241** (the production 7-pose flow)
5. Verify the capture sequence includes all poses:
   - Center
   - Left profile
   - Right profile
   - Up angle
   - Down angle
   - Smile
   - Neutral
6. Test the full scan flow to ensure all 7 poses are captured
7. Update any related tests that expect single-pose capture

**Files to Modify:**
- `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`

**Testing:**
- Run a complete face scan
- Verify all 7 pose indicators appear
- Confirm scan doesn't complete until all poses captured

---

### 2. Incomplete Challenge Updates (🔴 CRITICAL)

**Location:** `GamificationSystem.swift:309-321`

**Problem:** Challenge check-ins don't actually update challenge progress.

**Step-by-Step Fix:**

1. **Make GlowChallenge mutable:**
   - Open `Tavi/Features/Gamification/GamificationSystem.swift`
   - Change `GlowChallenge` from `struct` to `class` (line 15)
   - Or add `mutating` methods if keeping as struct

2. **Implement proper storage:**
   ```swift
   // Add to GamificationSystem
   private var activeChallenges: [GlowChallenge] = []
   ```

3. **Update `recordChallengeCheckIn()` method (lines 309-321):**
   ```swift
   public func recordChallengeCheckIn(glowScore: Int) {
       guard var challenge = getCurrentChallenge() else { return }

       // Update check-ins array
       var updatedCheckIns = challenge.checkIns
       updatedCheckIns.append(Date())

       // Update glow score
       let updatedScore = glowScore

       // Check milestone progress
       let progress = updatedCheckIns.count
       let completed = progress >= challenge.targetDays

       // Create updated challenge
       let updatedChallenge = GlowChallenge(
           id: challenge.id,
           title: challenge.title,
           description: challenge.description,
           duration: challenge.duration,
           targetDays: challenge.targetDays,
           reward: challenge.reward,
           checkIns: updatedCheckIns,
           startDate: challenge.startDate,
           isCompleted: completed,
           currentGlowScore: updatedScore,
           milestones: challenge.milestones
       )

       // Save to storage (implement persistence)
       saveChallenge(updatedChallenge)

       // Post notification for UI updates
       NotificationCenter.default.post(
           name: .challengeProgressUpdated,
           object: updatedChallenge
       )
   }
   ```

4. **Add persistence methods:**
   ```swift
   private func saveChallenge(_ challenge: GlowChallenge) {
       // Save to UserDefaults or Core Data
       if let encoded = try? JSONEncoder().encode(challenge) {
           UserDefaults.standard.set(encoded, forKey: "activeChallenge_\(challenge.id)")
       }
   }

   private func loadChallenges() -> [GlowChallenge] {
       // Load from storage
   }
   ```

5. **Update `EmotionalScan3DFlowView.swift` (line 441):**
   - Ensure it passes the correct `glowScore` value
   - Add visual feedback for milestone achievements

**Files to Modify:**
- `Tavi/Features/Gamification/GamificationSystem.swift`
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`

**Testing:**
- Start a new challenge
- Complete multiple scans
- Verify check-ins are recorded
- Confirm milestones trigger
- Test challenge completion

---

### 3. Missing JSON Migration (🔴 CRITICAL)

**Location:** `CoreData/TaviModel.xcdatamodeld/`

**Problem:** No versioning support for Core Data schema changes.

**Step-by-Step Fix:**

1. **Create new model version:**
   - In Xcode, select `TaviModel.xcdatamodeld`
   - Editor → Add Model Version
   - Name it: `TaviModel 2`
   - Base on: Current model

2. **Set current version:**
   - Select `TaviModel.xcdatamodeld` in Project Navigator
   - In File Inspector, set "Current" to `TaviModel 2`

3. **Update `PersistenceController.swift` for migrations:**
   ```swift
   lazy var persistentContainer: NSPersistentContainer = {
       let container = NSPersistentContainer(name: "TaviModel")

       // Migration options
       let description = container.persistentStoreDescriptions.first
       description?.shouldMigrateStoreAutomatically = true
       description?.shouldInferMappingModelAutomatically = true

       // For custom migrations (when lightweight fails):
       description?.setOption(true as NSNumber,
                             forKey: NSMigratePersistentStoresAutomaticallyOption)
       description?.setOption(true as NSNumber,
                             forKey: NSInferMappingModelAutomaticallyOption)

       container.loadPersistentStores { description, error in
           if let error = error {
               // Log migration errors
               AppLogger.storage.error("Migration failed: \(error)")
               fatalError("Failed to load Core Data: \(error)")
           }
       }
       return container
   }()
   ```

4. **Create migration mapping (if needed for complex changes):**
   - File → New → Mapping Model
   - Source: `TaviModel`
   - Destination: `TaviModel 2`

5. **Add version metadata:**
   ```swift
   // Add to PersistenceController
   private func getCurrentModelVersion() -> String {
       // Track which version is active
       return "TaviModel_v2"
   }
   ```

6. **Test migration:**
   - Install current app version
   - Add test data
   - Update to new version
   - Verify data persists

**Files to Modify:**
- Create: `TaviModel 2.xcdatamodel`
- Modify: `Tavi/Core/StorageKit/PersistenceController.swift`

**Testing:**
- Test fresh install
- Test upgrade from previous version
- Verify no data loss
- Check migration performance

---

## High Priority Issues

### 4. Monolithic ViewModel (🟠 HIGH)

**Location:** `FaceScan3DViewModel.swift` (1,613 lines)

**Problem:** Single ViewModel handles 9+ separate concerns.

**Step-by-Step Fix:**

1. **Create new manager classes:**

   **a) CalibrationManager.swift:**
   ```swift
   @MainActor
   class CalibrationManager: ObservableObject {
       @Published var state: CalibrationState
       @Published var lightingLevel: Double

       func checkCalibration(_ frame: ARFrame) -> CalibrationState
       func updateLighting(_ level: Double)
   }
   ```

   **b) GuidanceCoordinator.swift:**
   ```swift
   @MainActor
   class GuidanceCoordinator: ObservableObject {
       @Published var currentGuidance: String
       @Published var headPosition: HeadPosition

       func updateGuidance(for pose: FacePose, position: HeadPosition)
       func shouldShowFeedback() -> Bool
   }
   ```

   **c) QualityValidator.swift:**
   ```swift
   @MainActor
   class QualityValidator {
       func validateImageQuality(_ image: CVPixelBuffer) -> QualityResult
       func checkLighting(_ brightness: Double) -> Bool
       func checkSharpness(_ image: CVPixelBuffer) -> Bool
   }
   ```

   **d) CaptureOrchestrator.swift:**
   ```swift
   @MainActor
   class CaptureOrchestrator: ObservableObject {
       @Published var capturedPoses: [FacePose: CapturedFrame]
       @Published var currentPose: FacePose

       func capturePose(_ pose: FacePose, frame: ARFrame)
       func getNextRequiredPose() -> FacePose?
       func isComplete() -> Bool
   }
   ```

2. **Refactor FaceScan3DViewModel:**
   ```swift
   @MainActor
   class FaceScan3DViewModel: ObservableObject {
       // Inject managers
       private let calibrationManager: CalibrationManager
       private let guidanceCoordinator: GuidanceCoordinator
       private let qualityValidator: QualityValidator
       private let captureOrchestrator: CaptureOrchestrator

       // Keep only ARKit coordination logic
       func session(_ session: ARSession, didUpdate frame: ARFrame) {
           // Delegate to appropriate manager
           calibrationManager.checkCalibration(frame)
           guidanceCoordinator.updateGuidance(...)
           // etc.
       }
   }
   ```

3. **Migration steps:**
   - Create each manager file
   - Move relevant code from ViewModel
   - Update dependencies
   - Add manager instances to ViewModel
   - Update view to use managers where needed
   - Test each refactored component

4. **Update views to access managers:**
   ```swift
   // In EmotionalScan3DFlowView
   @StateObject private var calibrationManager = CalibrationManager()
   @StateObject private var viewModel = FaceScan3DViewModel(
       calibrationManager: calibrationManager,
       // ... other managers
   )
   ```

**Files to Create:**
- `Tavi/Features/FaceScan3D/Managers/CalibrationManager.swift`
- `Tavi/Features/FaceScan3D/Managers/GuidanceCoordinator.swift`
- `Tavi/Features/FaceScan3D/Managers/QualityValidator.swift`
- `Tavi/Features/FaceScan3D/Managers/CaptureOrchestrator.swift`

**Files to Modify:**
- `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`

**Testing:**
- Test each manager independently
- Verify scan flow works identically
- Check memory usage improvements
- Validate thread safety

---

### 5. Navigation Inconsistencies (🟠 HIGH)

**Location:** Multiple files using 4 different navigation patterns

**Problem:** Mixed navigation prevents deep linking and programmatic navigation.

**Step-by-Step Fix:**

1. **Create centralized navigation coordinator:**
   ```swift
   // Create AppCoordinator.swift
   @MainActor
   class AppCoordinator: ObservableObject {
       @Published var path = NavigationPath()
       @Published var presentedSheet: Sheet?
       @Published var presentedFullScreen: FullScreenCover?

       enum Sheet: Identifiable {
           case settings
           case scanFlow

           var id: String {
               switch self {
               case .settings: return "settings"
               case .scanFlow: return "scanFlow"
               }
           }
       }

       enum FullScreenCover: Identifiable {
           case onboarding

           var id: String { "onboarding" }
       }

       func showSettings() {
           presentedSheet = .settings
       }

       func startScan() {
           presentedSheet = .scanFlow
       }

       func showOnboarding() {
           presentedFullScreen = .onboarding
       }

       func navigateToDetails(_ session: SessionResult) {
           path.append(session)
       }
   }
   ```

2. **Update HomeView.swift:**
   ```swift
   struct HomeView: View {
       @StateObject private var coordinator = AppCoordinator()

       var body: some View {
           NavigationStack(path: $coordinator.path) {
               // Main content
               ZStack {
                   // ... existing content
               }
               .navigationDestination(for: SessionResult.self) { session in
                   ResultsDetailView(session: session)
               }
               .sheet(item: $coordinator.presentedSheet) { sheet in
                   switch sheet {
                   case .settings:
                       SettingsView()
                   case .scanFlow:
                       NavigationStack {
                           EmotionalScan3DFlowView()
                       }
                   }
               }
               .fullScreenCover(item: $coordinator.presentedFullScreen) { cover in
                   switch cover {
                   case .onboarding:
                       OnboardingFlowView()
                   }
               }
           }
       }
   }
   ```

3. **Update button actions:**
   ```swift
   // Settings button
   Button {
       coordinator.showSettings()
   } label: { /* ... */ }

   // Scan button
   Button {
       coordinator.startScan()
   } label: { /* ... */ }

   // View details
   Button {
       coordinator.navigateToDetails(session)
   } label: { /* ... */ }
   ```

4. **Standardize across app:**
   - Update all views to use NavigationStack
   - Use coordinator for all navigation
   - Remove mixed patterns
   - Enable deep linking support

**Files to Create:**
- `Tavi/Core/Navigation/AppCoordinator.swift`

**Files to Modify:**
- `Tavi/Features/Home/HomeView.swift`
- `Tavi/Features/Settings/SettingsView.swift`
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`

**Testing:**
- Test all navigation flows
- Verify back button behavior
- Test deep linking
- Check state restoration

---

### 6. Silent Core Data Failures (🟠 HIGH)

**Location:** `PersistenceController.swift:95-107` and `EmotionalScan3DFlowView.swift:669-674`

**Problem:** Save failures are logged but never shown to users.

**Step-by-Step Fix:**

1. **Create error handling enum:**
   ```swift
   // Create StorageError.swift
   enum StorageError: LocalizedError {
       case saveFailed(Error)
       case fetchFailed(Error)
       case deleteFailed(Error)
       case migrationFailed(Error)

       var errorDescription: String? {
           switch self {
           case .saveFailed(let error):
               return "Failed to save your scan: \(error.localizedDescription)"
           case .fetchFailed(let error):
               return "Failed to load scans: \(error.localizedDescription)"
           case .deleteFailed(let error):
               return "Failed to delete scan: \(error.localizedDescription)"
           case .migrationFailed(let error):
               return "Failed to update app data: \(error.localizedDescription)"
           }
       }

       var recoverySuggestion: String? {
           "Please try again. If the problem persists, contact support."
       }
   }
   ```

2. **Update PersistenceController.swift:**
   ```swift
   func save() throws {
       guard context.hasChanges else { return }

       do {
           try context.save()
           AppLogger.storage.info("✅ Core Data saved successfully")
       } catch {
           let nsError = error as NSError
           AppLogger.storage.error("❌ Save failed: \(nsError)")

           // Post notification for UI to handle
           NotificationCenter.default.post(
               name: .storageErrorOccurred,
               object: StorageError.saveFailed(error)
           )

           throw StorageError.saveFailed(error)
       }
   }

   func saveWithRetry(maxAttempts: Int = 3) async throws {
       var attempts = 0
       var lastError: Error?

       while attempts < maxAttempts {
           do {
               try save()
               return
           } catch {
               lastError = error
               attempts += 1
               if attempts < maxAttempts {
                   try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
               }
           }
       }

       throw lastError ?? StorageError.saveFailed(NSError(domain: "Unknown", code: -1))
   }
   ```

3. **Update EmotionalScan3DFlowView.swift:**
   ```swift
   @State private var storageError: StorageError?
   @State private var showStorageErrorAlert = false

   // In save logic:
   do {
       try await PersistenceController.shared.saveWithRetry()
       AppLogger.faceScan.info("✅ Session saved successfully")
   } catch {
       storageError = error as? StorageError
       showStorageErrorAlert = true
       AppLogger.faceScan.error("❌ Failed to save: \(error)")
   }

   // Add alert:
   .alert("Save Failed", isPresented: $showStorageErrorAlert, presenting: storageError) { error in
       Button("Retry") {
           Task {
               await saveSession()
           }
       }
       Button("Cancel", role: .cancel) { }
   } message: { error in
       Text(error.errorDescription ?? "Unknown error")
       Text(error.recoverySuggestion ?? "")
   }
   ```

4. **Add global error handler:**
   ```swift
   // In TaviApp.swift
   .onReceive(NotificationCenter.default.publisher(for: .storageErrorOccurred)) { notification in
       if let error = notification.object as? StorageError {
           // Show global error banner
           handleStorageError(error)
       }
   }
   ```

**Files to Create:**
- `Tavi/Core/StorageKit/StorageError.swift`

**Files to Modify:**
- `Tavi/Core/StorageKit/PersistenceController.swift`
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`
- `Tavi/TaviApp.swift`

**Testing:**
- Simulate disk full error
- Test retry mechanism
- Verify user sees alerts
- Check error recovery

---

### 7. Incomplete Comparison Feature (🟠 HIGH)

**Location:** `ComparisonView.swift:120-150`

**Problem:** Shows placeholder icon instead of actual 3D meshes.

**Step-by-Step Fix:**

1. **Create 3D scene manager:**
   ```swift
   // Create MeshSceneManager.swift
   import SceneKit

   @MainActor
   class MeshSceneManager: ObservableObject {
       private var scene: SCNScene
       private var cameraNode: SCNNode

       func loadMesh(from data: Data) -> SCNNode? {
           // Load mesh from stored data
           // Convert ARKit mesh to SCNGeometry
       }

       func applyHeatmap(to node: SCNNode, values: [Float]) {
           // Apply color gradient based on metric values
       }

       func synchronizeRotation(node1: SCNNode, node2: SCNNode) {
           // Link rotation between two nodes
       }
   }
   ```

2. **Create SceneKit view wrapper:**
   ```swift
   // Create MeshComparisonSceneView.swift
   import SwiftUI
   import SceneKit

   struct MeshComparisonSceneView: UIViewRepresentable {
       let meshData: Data
       let heatmapValues: [Float]

       func makeUIView(context: Context) -> SCNView {
           let sceneView = SCNView()
           sceneView.scene = SCNScene()
           sceneView.allowsCameraControl = true
           sceneView.autoenablesDefaultLighting = true
           sceneView.backgroundColor = .clear

           // Load mesh
           if let node = loadMeshNode(from: meshData) {
               applyHeatmap(to: node, values: heatmapValues)
               sceneView.scene?.rootNode.addChildNode(node)
           }

           return sceneView
       }

       func updateUIView(_ uiView: SCNView, context: Context) {
           // Update heatmap if needed
       }

       private func loadMeshNode(from data: Data) -> SCNNode? {
           // Implementation
       }

       private func applyHeatmap(to node: SCNNode, values: [Float]) {
           // Implementation
       }
   }
   ```

3. **Update ComparisonView.swift:**
   ```swift
   // Replace placeholder (lines 120-150):
   if let oldMeshData = oldSession.meshData,
      let newMeshData = newSession.meshData {

       HStack(spacing: 16) {
           // Old scan
           VStack {
               MeshComparisonSceneView(
                   meshData: oldMeshData,
                   heatmapValues: oldSession.metricsArray
               )
               .frame(height: 300)

               Text("Previous")
                   .font(.caption)
           }

           // New scan
           VStack {
               MeshComparisonSceneView(
                   meshData: newMeshData,
                   heatmapValues: newSession.metricsArray
               )
               .frame(height: 300)

               Text("Current")
                   .font(.caption)
           }
       }
   } else {
       // Fallback to placeholder
       Image(systemName: "cube.fill")
   }
   ```

4. **Add synchronized rotation:**
   ```swift
   @State private var rotation: SCNVector3 = SCNVector3(0, 0, 0)

   // Pass rotation binding to both scene views
   // Implement rotation synchronization
   ```

5. **Add heatmap shader:**
   ```swift
   // Create custom SCNMaterial with shader
   let material = SCNMaterial()
   material.shaderModifiers = [
       .fragment: """
       // GLSL shader for heatmap
       uniform float values[100];
       _output.color.rgb = heatmapColor(values, _surface.position);
       """
   ]
   ```

**Files to Create:**
- `Tavi/Features/FaceScan3D/Rendering/MeshSceneManager.swift`
- `Tavi/Features/FaceScan3D/Rendering/MeshComparisonSceneView.swift`
- `Tavi/Features/FaceScan3D/Rendering/HeatmapShader.metal`

**Files to Modify:**
- `Tavi/Features/FaceScan3D/UI/ComparisonView.swift`

**Testing:**
- Test mesh loading from Core Data
- Verify synchronized rotation
- Check heatmap colors
- Test performance with large meshes

---

### 8. Broken Celebration Flow (🟠 HIGH)

**Location:** `EmotionalScan3DFlowView.swift:488-494` and `CelebrationView.swift`

**Problem:** CelebrationView never shown even when improvements occur.

**Step-by-Step Fix:**

1. **Add improvement detection logic:**
   ```swift
   // In EmotionalScan3DFlowView.swift

   private func detectImprovements(newSession: SessionResult) -> [MetricImprovement]? {
       // Fetch previous session
       let fetchRequest: NSFetchRequest<SessionResult> = SessionResult.fetchRequest()
       fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
       fetchRequest.fetchLimit = 2 // Get current + previous

       guard let sessions = try? context.fetch(fetchRequest),
             sessions.count >= 2 else {
           return nil // First scan, no comparison
       }

       let previous = sessions[1]
       let current = newSession

       var improvements: [MetricImprovement] = []

       // Check overall score
       let scoreDiff = current.overallScore - previous.overallScore
       if scoreDiff > 5 {
           improvements.append(MetricImprovement(
               name: "Overall Glow",
               previousValue: previous.overallScore,
               currentValue: current.overallScore,
               percentChange: (scoreDiff / previous.overallScore) * 100,
               isImprovement: true
           ))
       }

       // Check individual metrics
       if current.hydrationScore > previous.hydrationScore + 5 {
           improvements.append(MetricImprovement(
               name: "Hydration",
               previousValue: previous.hydrationScore,
               currentValue: current.hydrationScore,
               percentChange: ((current.hydrationScore - previous.hydrationScore) / previous.hydrationScore) * 100,
               isImprovement: true
           ))
       }

       // Similar checks for other metrics...

       return improvements.isEmpty ? nil : improvements
   }
   ```

2. **Add state for celebration:**
   ```swift
   @State private var showCelebration = false
   @State private var metricImprovements: [MetricImprovement]?
   ```

3. **Update navigation logic (around line 488):**
   ```swift
   // After processing completes
   if flowState == .processing {
       // Check for improvements
       if let improvements = detectImprovements(newSession: savedSession) {
           metricImprovements = improvements
           showCelebration = true
       } else {
           // Go directly to results
           flowState = .complete
       }
   }
   ```

4. **Add celebration sheet:**
   ```swift
   .sheet(isPresented: $showCelebration) {
       if let improvements = metricImprovements {
           CelebrationView(
               improvements: improvements,
               onContinue: {
                   showCelebration = false
                   flowState = .complete
               }
           )
       }
   }
   ```

5. **Update CelebrationView to be dismissible:**
   ```swift
   struct CelebrationView: View {
       let improvements: [MetricImprovement]
       let onContinue: () -> Void

       var body: some View {
           // ... existing celebration UI

           Button("See Full Results") {
               onContinue()
           }
           .buttonStyle(.primary)
       }
   }
   ```

**Files to Modify:**
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`
- `Tavi/Features/FaceScan3D/UI/CelebrationView.swift`

**Testing:**
- Test first scan (no celebration)
- Test scan with improvements (show celebration)
- Test scan with no improvements (skip celebration)
- Verify transition to results

---

### 9. Missing History Details Navigation (🟠 HIGH)

**Location:** `HomeView.swift:162-174` and `HomeView.swift:235-274`

**Problem:** Buttons exist but don't navigate anywhere.

**Step-by-Step Fix:**

1. **Make SessionResult Hashable:**
   ```swift
   // In SessionResult+Extensions.swift
   extension SessionResult: Hashable {
       public func hash(into hasher: inout Hasher) {
           hasher.combine(id)
       }

       public static func == (lhs: SessionResult, rhs: SessionResult) -> Bool {
           lhs.id == rhs.id
       }
   }
   ```

2. **Update HomeView with NavigationStack:**
   ```swift
   // Already handled in Fix #5 (Navigation Inconsistencies)
   // Just need to add navigation links

   // For latest scan card (line 162):
   Button {
       coordinator.navigateToDetails(latest)
   } label: {
       HStack(spacing: 6) {
           Text("View details")
               .font(.system(size: 16, weight: .semibold, design: .rounded))
           Image(systemName: "chevron.right")
               .font(.system(size: 13, weight: .bold))
       }
       .foregroundColor(HeadspaceDesign.Colors.primary)
   }
   ```

3. **Make recent scan items tappable (line 235):**
   ```swift
   private func recentScanListItem(_ session: SessionResult) -> some View {
       Button {
           coordinator.navigateToDetails(session)
       } label: {
           HStack(spacing: HeadspaceDesign.Spacing.lg) {
               // ... existing content
           }
           .padding(HeadspaceDesign.Spacing.lg)
           .background(Color.white)
           .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
       }
       .buttonStyle(.plain) // Prevent button styling
   }
   ```

4. **Add navigation destination:**
   ```swift
   // In HomeView body
   .navigationDestination(for: SessionResult.self) { session in
       ResultsDetailView(session: session)
   }
   ```

**Files to Create:**
- `Tavi/Core/Models/SessionResult+Extensions.swift`

**Files to Modify:**
- `Tavi/Features/Home/HomeView.swift`

**Testing:**
- Tap "View details" on latest scan
- Tap recent scan list items
- Verify navigation to ResultsDetailView
- Test back navigation

---

## Medium Priority Issues

### 10. No Offline Handling (Not an Issue ✅)

**Finding:** App is 100% local with no network calls.

**No action required** - App works fully offline by design.

---

### 11. Hardcoded Thresholds (🟡 MEDIUM)

**Location:** Various analyzer files

**Problem:** Some magic numbers still exist outside ScanConfiguration.

**Step-by-Step Fix:**

1. **Identify remaining hardcoded values:**
   - `FaceScan3DViewModel.swift:147` - Quality check interval: `15`
   - `FaceScan3DViewModel.swift:157` - Streaming threshold: `50_000`
   - Check all analyzer files for more

2. **Add to ScanConfiguration.swift:**
   ```swift
   // Add to ScanConfiguration
   public static let qualityCheckInterval: Int = 15
   public static let streamingVertexThreshold: Int = 50_000
   public static let minConfidenceThreshold: Float = 0.7
   public static let maxProcessingTime: TimeInterval = 30
   ```

3. **Replace hardcoded values:**
   ```swift
   // In FaceScan3DViewModel.swift line 147:
   // Before:
   if frameCount % 15 == 0 {

   // After:
   if frameCount % ScanConfiguration.qualityCheckInterval == 0 {
   ```

4. **Search and replace across codebase:**
   - Search for numeric literals in analyzer files
   - Move to ScanConfiguration
   - Update references

5. **Document thresholds:**
   ```swift
   /// Quality check interval in frames
   /// Lower = more frequent checks, higher CPU usage
   /// Default: 15 frames (~0.5 seconds at 30fps)
   public static let qualityCheckInterval: Int = 15
   ```

**Files to Modify:**
- `Tavi/Core/Utilities/ScanConfiguration.swift`
- `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`
- All analyzer files with magic numbers

**Testing:**
- Verify behavior unchanged
- Test configuration changes
- Document threshold meanings

---

### 12. Missing Settings Persistence (Not an Issue ✅)

**Finding:** All settings use `@AppStorage` and persist correctly.

**No action required** - Settings persistence works as designed.

---

### 13. Incomplete PDF Export (🟡 MEDIUM)

**Location:** `PDFReportGenerator.swift:70` and throughout

**Problem:** No error handling when PDF generation fails, missing heatmap images.

**Step-by-Step Fix:**

1. **Add error handling:**
   ```swift
   // Update generate() method
   public func generate() async throws -> URL {
       let pdfData = await MainActor.run {
           renderPDF()
       }

       guard let data = pdfData else {
           throw PDFError.generationFailed
       }

       let fileURL = try saveToFile(data)
       return fileURL
   }

   enum PDFError: LocalizedError {
       case generationFailed
       case saveFailed
       case missingData

       var errorDescription: String? {
           switch self {
           case .generationFailed: return "Failed to generate PDF"
           case .saveFailed: return "Failed to save PDF file"
           case .missingData: return "Missing required data for PDF"
           }
       }
   }
   ```

2. **Add heatmap images to PDF:**
   ```swift
   // In renderPDF() method, add new page:
   private func addHeatmapPage(to context: CGContext) {
       // Start new page
       context.beginPage()

       // Add title
       drawText("Detailed Analysis", at: CGPoint(x: 50, y: 50))

       // Render heatmap visualizations
       if let heatmapImage = generateHeatmapImage() {
           context.draw(heatmapImage, in: CGRect(x: 50, y: 100, width: 500, height: 500))
       }

       // Add legend
       drawHeatmapLegend(at: CGPoint(x: 50, y: 620))

       context.endPage()
   }

   private func generateHeatmapImage() -> CGImage? {
       // Use MeshSceneManager to render heatmap
       // Capture as image
   }
   ```

3. **Update ResultsDetailView error handling:**
   ```swift
   Button("Export PDF") {
       Task {
           do {
               let url = try await pdfGenerator.generate()
               sharePDF(url: url)
           } catch {
               pdfExportError = error
               showPDFError = true
           }
       }
   }
   .alert("Export Failed", isPresented: $showPDFError, presenting: pdfExportError) { error in
       Button("OK") { }
   } message: { error in
       Text(error.localizedDescription)
   }
   ```

4. **Add progress indicator:**
   ```swift
   @State private var isGeneratingPDF = false

   Button("Export PDF") {
       isGeneratingPDF = true
       Task {
           defer { isGeneratingPDF = false }
           // ... generation code
       }
   }
   .disabled(isGeneratingPDF)
   .overlay {
       if isGeneratingPDF {
           ProgressView()
       }
   }
   ```

**Files to Modify:**
- `Tavi/Features/Export/PDFReportGenerator.swift`
- `Tavi/Features/Results/ResultsDetailView.swift`

**Testing:**
- Test PDF generation success
- Test error scenarios
- Verify heatmap images appear
- Check file size reasonable

---

### 14. View Details Button (Duplicate of #9)

**See Fix #9** - Same solution covers this issue.

---

### 15. Recent Scans Navigation (Duplicate of #9)

**See Fix #9** - Same solution covers this issue.

---

### 16. No Retry Mechanism (🟡 MEDIUM)

**Location:** `EmotionalScan3DFlowView.swift:296-343`

**Problem:** Manual retry exists, but no automatic retry or limits.

**Step-by-Step Fix:**

1. **Add retry tracking:**
   ```swift
   @State private var retryCount = 0
   @State private var maxRetries = 3
   @State private var isAutoRetrying = false
   ```

2. **Implement automatic retry for transient errors:**
   ```swift
   private func handleScanError(_ error: ScanError) {
       // Check if error is transient
       if error.isTransient && retryCount < maxRetries {
           // Automatic retry
           isAutoRetrying = true
           retryCount += 1

           Task {
               try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
               await retryWithExponentialBackoff()
           }
       } else {
           // Show error to user
           currentError = error
           flowState = .error
           isAutoRetrying = false
       }
   }

   private func retryWithExponentialBackoff() async {
       let delay = pow(2.0, Double(retryCount)) // 2, 4, 8 seconds
       try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

       // Reset and restart
       await restartScan()
   }
   ```

3. **Categorize errors:**
   ```swift
   extension ScanError {
       var isTransient: Bool {
           switch self {
           case .poorLighting: return true
           case .faceNotDetected: return true
           case .movementDetected: return true
           case .processingTimeout: return true
           case .deviceNotSupported: return false
           case .permissionDenied: return false
           default: return false
           }
       }
   }
   ```

4. **Update error view to show retry status:**
   ```swift
   if isAutoRetrying {
       VStack(spacing: 16) {
           ProgressView()
           Text("Retrying automatically...")
               .font(.headline)
           Text("Attempt \(retryCount) of \(maxRetries)")
               .font(.caption)
               .foregroundColor(.secondary)
       }
   } else {
       // Show manual retry button
       Button("Retry") {
           retryCount = 0
           restartWithCountdown()
       }

       if retryCount > 0 {
           Text("Previous attempts: \(retryCount)")
               .font(.caption)
       }
   }
   ```

5. **Reset retry count on success:**
   ```swift
   private func onScanSuccess() {
       retryCount = 0
       isAutoRetrying = false
       // Continue with processing
   }
   ```

**Files to Modify:**
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`
- `Tavi/Features/FaceScan3D/Models/ScanError.swift`

**Testing:**
- Test automatic retry on transient errors
- Verify retry count limits
- Test exponential backoff timing
- Check manual retry still works

---

### 17. Missing Analytics (🟡 MEDIUM)

**Location:** N/A (feature doesn't exist)

**Problem:** No event tracking for user behavior analysis.

**Step-by-Step Fix:**

1. **Create analytics manager:**
   ```swift
   // Create AnalyticsManager.swift
   @MainActor
   class AnalyticsManager {
       static let shared = AnalyticsManager()

       private init() {}

       // Event tracking
       func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
           let event = AnalyticsEvent(
               name: name,
               parameters: parameters,
               timestamp: Date()
           )

           // Log locally
           AppLogger.analytics.info("Event: \(name), params: \(parameters ?? [:])")

           // Store for later upload (if analytics service added)
           saveEvent(event)
       }

       // Performance tracking
       func trackTiming(_ metric: String, duration: TimeInterval) {
           trackEvent("timing", parameters: [
               "metric": metric,
               "duration_ms": duration * 1000
           ])
       }

       // Screen tracking
       func trackScreen(_ name: String) {
           trackEvent("screen_view", parameters: ["screen": name])
       }

       // Error tracking
       func trackError(_ error: Error, context: String) {
           trackEvent("error", parameters: [
               "error": error.localizedDescription,
               "context": context
           ])
       }

       private func saveEvent(_ event: AnalyticsEvent) {
           // Save to UserDefaults or local database
           // Can be uploaded later if needed
       }
   }

   struct AnalyticsEvent: Codable {
       let name: String
       let parameters: [String: String]?
       let timestamp: Date
   }
   ```

2. **Add event tracking throughout app:**

   **In EmotionalScan3DFlowView.swift:**
   ```swift
   // Track scan start
   private func startScan() {
       AnalyticsManager.shared.trackEvent("scan_started")
       // ... existing code
   }

   // Track scan completion
   private func onScanComplete() {
       let duration = Date().timeIntervalSince(scanStartTime)
       AnalyticsManager.shared.trackTiming("scan_duration", duration: duration)
       AnalyticsManager.shared.trackEvent("scan_completed", parameters: [
           "pose_count": String(capturedPoses.count)
       ])
   }

   // Track errors
   private func handleError(_ error: Error) {
       AnalyticsManager.shared.trackError(error, context: "face_scan")
   }
   ```

   **In HomeView.swift:**
   ```swift
   .onAppear {
       AnalyticsManager.shared.trackScreen("home")
   }

   Button("Scan Now") {
       AnalyticsManager.shared.trackEvent("scan_button_tapped")
       showScanFlow = true
   }
   ```

   **In SettingsView.swift:**
   ```swift
   .onAppear {
       AnalyticsManager.shared.trackScreen("settings")
   }

   Toggle("High Resolution", isOn: $enableHighResCapture)
       .onChange(of: enableHighResCapture) { newValue in
           AnalyticsManager.shared.trackEvent("setting_changed", parameters: [
               "setting": "high_resolution",
               "value": String(newValue)
           ])
       }
   ```

3. **Add performance tracking:**
   ```swift
   // Create PerformanceTimer.swift
   class PerformanceTimer {
       private let name: String
       private let startTime: Date

       init(_ name: String) {
           self.name = name
           self.startTime = Date()
       }

       func stop() {
           let duration = Date().timeIntervalSince(startTime)
           AnalyticsManager.shared.trackTiming(name, duration: duration)
       }
   }

   // Usage:
   let timer = PerformanceTimer("mesh_processing")
   // ... do work
   timer.stop()
   ```

4. **Add crash breadcrumbs:**
   ```swift
   // Integrate with existing CrashReporter
   extension AnalyticsManager {
       func addBreadcrumb(_ message: String, category: String) {
           CrashReporter.shared.addBreadcrumb(message, category: category)

           // Also track locally
           trackEvent("breadcrumb", parameters: [
               "message": message,
               "category": category
           ])
       }
   }
   ```

5. **Privacy compliance:**
   ```swift
   // Add analytics opt-out
   class AnalyticsManager {
       @AppStorage("analytics_enabled") private var isEnabled = true

       func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
           guard isEnabled else { return }
           // ... tracking code
       }
   }

   // Add to settings
   Toggle("Analytics", isOn: $analyticsEnabled)
   ```

**Files to Create:**
- `Tavi/Core/Analytics/AnalyticsManager.swift`
- `Tavi/Core/Analytics/PerformanceTimer.swift`
- `Tavi/Core/Analytics/AnalyticsEvent.swift`

**Files to Modify:**
- `Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`
- `Tavi/Features/Home/HomeView.swift`
- `Tavi/Features/Settings/SettingsView.swift`
- `Tavi/Features/Results/ResultsViewModel.swift`

**Testing:**
- Verify events are tracked
- Check performance timings
- Test opt-out functionality
- Validate data privacy

---

## Summary

**Total Issues: 14 actionable fixes**
- Critical: 3 fixes
- High Priority: 6 fixes
- Medium Priority: 5 fixes
- Not Issues: 3 items

**Priority Order for Implementation:**
1. Testing Mode in Production (CRITICAL - 30 min)
2. Silent Core Data Failures (HIGH - 2 hours)
3. Missing History Navigation (HIGH - 1 hour)
4. Incomplete Challenge Updates (CRITICAL - 3 hours)
5. Broken Celebration Flow (HIGH - 2 hours)
6. Navigation Inconsistencies (HIGH - 4 hours)
7. Missing JSON Migration (CRITICAL - 2 hours)
8. Incomplete Comparison Feature (HIGH - 6 hours)
9. Monolithic ViewModel (HIGH - 8 hours)
10. Incomplete PDF Export (MEDIUM - 3 hours)
11. No Retry Mechanism (MEDIUM - 2 hours)
12. Hardcoded Thresholds (MEDIUM - 1 hour)
13. Missing Analytics (MEDIUM - 4 hours)

**Estimated Total: ~40 hours of development**
