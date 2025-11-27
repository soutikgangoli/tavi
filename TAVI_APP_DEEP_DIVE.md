# TAVI APP - COMPREHENSIVE DEEP DIVE DOCUMENTATION

> **Last Updated**: November 28, 2025
> **App Version**: Production
> **Platform**: iOS (SwiftUI + ARKit)

---

## TABLE OF CONTENTS

1. [App Overview](#1-app-overview)
2. [Architecture & File Structure](#2-architecture--file-structure)
3. [All Screens & Views](#3-all-screens--views)
4. [Navigation Flow](#4-navigation-flow)
5. [Scanning System](#5-scanning-system)
6. [All Analyzers & Metrics](#6-all-analyzers--metrics)
7. [Clinical Results & Interpretations](#7-clinical-results--interpretations)
8. [Data Models & Persistence](#8-data-models--persistence)
9. [Services & Utilities](#9-services--utilities)
10. [Configuration & Thresholds](#10-configuration--thresholds)

---

## 1. APP OVERVIEW

### What is Tavi?

Tavi is a **3D skin analysis iOS application** that uses ARKit face tracking to capture multi-angle face scans and analyze various skin health metrics. The app provides:

- **Real-time 3D face mesh capture** from 5 different angles
- **Comprehensive skin analysis** including texture, pigmentation, pores, acne, and more
- **Skin-tone fair analysis** that works across all Fitzpatrick skin types (I-VI)
- **Clinical-grade metrics** with confidence scores
- **Progress tracking** over time with gamification elements
- **Personalized recommendations** based on analysis results

### Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| 3D Capture | ARKit (Face Tracking) |
| GPU Processing | Metal Framework |
| Data Persistence | Core Data |
| Crash Reporting | Sentry (optional) |
| Analytics | Custom AnalyticsManager |
| Architecture | MVVM + Feature-Based Modular |

### Key Statistics

- **Total Swift Files**: 161
- **View Files**: 43
- **Analyzer Classes**: 14+
- **Configuration Parameters**: 60+
- **Supported Face Poses**: 5
- **Metrics Tracked**: 15+

---

## 2. ARCHITECTURE & FILE STRUCTURE

### Directory Structure

```
Tavi/
├── TaviApp.swift                    # Main app entry point
├── ContentView.swift                # Root view container
├── Info.plist                       # App configuration
├── PrivacyInfo.xcprivacy           # Privacy manifest (iOS 17+)
│
├── Core/                            # Core infrastructure
│   ├── Analytics/
│   │   └── AnalyticsManager.swift
│   ├── Memory/
│   │   ├── AdvancedMemoryMonitor.swift
│   │   ├── MemoryBudgetManager.swift
│   │   ├── MemoryDiagnosticsView.swift
│   │   └── MemoryManagedResource.swift
│   ├── ModelsKit/
│   │   ├── AnalysisTypes.swift
│   │   ├── DataModels.swift
│   │   └── DeviceCapabilities.swift
│   ├── Performance/
│   │   ├── PerformanceAnalyzer.swift
│   │   └── PerformanceDiagnosticsView.swift
│   ├── Persistence/
│   │   └── VersionedMetricsWrapper.swift
│   ├── StorageKit/
│   │   ├── PersistenceController.swift
│   │   ├── StorageManager.swift
│   │   ├── SessionResult.swift
│   │   └── Migration/
│   │       ├── CoreDataMigrationManager.swift
│   │       ├── DataBackupManager.swift
│   │       └── DataBackupView.swift
│   ├── Utilities/
│   │   ├── AppLogger.swift
│   │   ├── AsyncTimeout.swift
│   │   ├── BiometricAuth.swift
│   │   ├── CrashReporter.swift
│   │   ├── DebugSettings.swift
│   │   ├── InputValidator.swift
│   │   ├── MemoryMonitor.swift
│   │   └── ScanConfiguration.swift
│   └── HapticManager.swift
│
├── Features/                        # Feature modules
│   ├── Navigation/
│   │   └── MainTabView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── ProgressGraphView.swift
│   ├── FaceScan3D/                  # Main scanning feature (75+ files)
│   │   ├── FaceScan3DAPI.swift
│   │   ├── Models/
│   │   ├── Metrics/
│   │   ├── Processing/
│   │   ├── Managers/
│   │   ├── Metal/
│   │   ├── Utilities/
│   │   ├── ARKit/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   └── UI/
│   ├── Results/
│   │   ├── ResultsHistoryView.swift
│   │   ├── ResultsDetailView.swift
│   │   ├── ResultsViewModel.swift
│   │   └── CelebratoryResultsView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── CaptureSettingsView.swift
│   │   ├── NotificationsSettingsView.swift
│   │   ├── PrivacySettingsView.swift
│   │   ├── AboutView.swift
│   │   └── DeviceInfoView.swift
│   ├── Gamification/
│   │   ├── GamificationSystem.swift
│   │   ├── AchievementDetailView.swift
│   │   └── ChallengeDetailView.swift
│   ├── User/
│   │   └── UserProfile.swift
│   ├── Recommendations/
│   │   └── PersonalizedRecommendationEngine.swift
│   ├── Onboarding/
│   │   ├── OnboardingFlow.swift
│   │   └── OnboardingModels.swift
│   ├── Debug/
│   │   ├── DebugScreen.swift
│   │   ├── DebugViewModel.swift
│   │   ├── DebugOverlayView.swift
│   │   └── HistogramView.swift
│   ├── Export/
│   │   └── PDFReportGenerator.swift
│   └── Social/
│       └── SocialSharingView.swift
│
├── Shared/                          # Shared UI components
│   └── UI/
│       ├── DesignSystem.swift
│       ├── HeadspaceDesignSystem.swift
│       ├── FaceIDStyleGuide.swift
│       ├── PrimaryButton.swift
│       ├── CardView.swift
│       ├── LoadingView.swift
│       ├── LoadingOverlay.swift
│       ├── FancyLoadingScreen.swift
│       ├── FaceGuidanceView.swift
│       ├── FaceBoundaryGuide.swift
│       ├── FaceLandmarksOverlay.swift
│       ├── CalibrationHUD.swift
│       ├── CaptureProgressView.swift
│       ├── MetricsResultView.swift
│       ├── ScoreSummaryView.swift
│       ├── HeatmapView.swift
│       └── ROIOverlay.swift
│
├── CoreData/
│   └── TaviModel.xcdatamodeld       # Core Data schema
│
├── Assets.xcassets/                 # Images, icons, colors
└── Resources/                       # Additional resources
```

### Architectural Patterns

1. **MVVM Architecture**
   - Models: DataModels, Face3DMetrics, etc.
   - Views: SwiftUI views throughout Features/
   - ViewModels: FaceScan3DViewModel, ResultsViewModel, DebugViewModel

2. **Feature-Based Modular Organization**
   - Each feature is self-contained in Features/
   - Clear separation of concerns
   - Shared components in Shared/UI/

3. **Layered Architecture**
   - **Core/**: Services, utilities, storage, models
   - **Features/**: Feature-specific business logic and UI
   - **Shared/**: Reusable UI components

4. **Dependency Injection**
   - Singleton managers: PersistenceController, StorageManager, MemoryMonitor
   - Environment-based injection for SwiftUI views

---

## 3. ALL SCREENS & VIEWS

### 3.1 Main Tab Navigation

**File**: `Features/Navigation/MainTabView.swift`

The app uses a custom 5-tab bottom navigation:

| Tab | Icon | View | Description |
|-----|------|------|-------------|
| Home | house.fill | HomeView | Dashboard with scores and recent scans |
| History | clock.fill | ResultsHistoryView | All past scan sessions |
| Scan | camera.fill (center) | EmotionalScan3DFlowView | Start new 3D face scan |
| Insights | chart.line.uptrend.xyaxis | InsightsTabView | Trends and analytics |
| Profile | person.fill | ProfileTabView | User profile and settings |

### 3.2 Home Screen

**File**: `Features/Home/HomeView.swift`

**Components Displayed**:
- Greeting section (time-based: "Good morning/afternoon/evening")
- Status widgets row (active challenge + last scan info)
- Hero rings section (1 large overall score ring + 3 smaller metric rings)
- Latest scan summary card with trend indicator
- Progress graph (if 2+ scans exist)
- Recent scans list (max 5 items)
- First-time user hero card (prompts to start first scan)
- Science explanation card
- Quick benefits card with expandable metrics list

**Navigation From Home**:
- Scan button → EmotionalScan3DFlowView (sheet)
- Scan item tap → ResultsDetailView
- "View All" → History tab
- Settings icon → SettingsView (sheet)
- Challenge card → ChallengeDetailView (sheet)
- Metric tap → MetricDetailView (sheet)

### 3.3 History Screen

**File**: `Features/Results/ResultsHistoryView.swift`

**Components**:
- Time period filters (All, Last 30 Days, Last 3 Months)
- Session cards with scores, dates, trend indicators
- Delete functionality with confirmation alerts

**Data**: Uses `@FetchRequest` with Core Data, sorted newest first

### 3.4 Scan Flow Screens

#### 3.4.1 Main Scan Flow

**File**: `Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`

**Flow States**:
1. **Preparing**: 3-second countdown with breathing animation
2. **Capturing**: Live 3D face mesh with real-time guidance
3. **Processing**: Progress indicator with stage updates
4. **Saving**: Core Data save with retry logic
5. **Complete**: Celebratory results view

**Processing Stages Shown**:
- Face detection
- Texture capture
- Mesh processing
- Metric calculation
- Analysis
- AI insights generation

#### 3.4.2 Scan Preparation

**File**: `Features/FaceScan3D/Views/ScanPreparationView.swift`

**Displays**:
- Breathing animation circle
- 3-second countdown
- Checklist (lighting, glasses, phone position)
- "Start scan" button

#### 3.4.3 3D Face Scan View

**File**: `Features/FaceScan3D/Views/FaceScan3DView.swift`

**Components**:
- ARKit live camera feed
- Optional 3D mesh wireframe overlay
- Calibration overlay with real-time guidance
- Debug info (FPS, face angles, vertices, triangles)
- Error messages with "Continue Anyway" option

#### 3.4.4 Lighting Calibration

**File**: `Features/FaceScan3D/UI/LightingCalibrationView.swift`

**States**:
- Too Dark (red)
- Suboptimal (orange)
- Optimal (green)
- Bright (orange)
- Too Bright (red)

#### 3.4.5 Face Guidance Overlay

**File**: `Shared/UI/FaceGuidanceView.swift`

**Displays**:
- Face detection status
- Distance guidance
- Angle guidance (yaw, pitch, roll)
- Real-time validation feedback

### 3.5 Results Screens

#### 3.5.1 Celebratory Results

**File**: `Features/Results/CelebratoryResultsView.swift`

**Components**:
- Animated overall score ring (0-100%)
- Save status banner
- Comparison warning (if version mismatch)
- Individual metric cards (8 metrics)
- Confidence breakdown
- Share and close buttons

#### 3.5.2 Results Detail

**File**: `Features/Results/ResultsDetailView.swift`

**Components**:
- Heatmap selector (composite, individual metrics)
- Original image toggle
- Clinical confidence scores
- Regional scores breakdown
- Share and delete buttons

#### 3.5.3 3D Metrics Results

**File**: `Features/FaceScan3D/Views/Face3DMetricsResultsView.swift`

**Components**:
- Header section
- 3D viewer button
- Global metrics section
- Metric type selector
- Heatmap visualization
- Per-ROI metrics table
- Export/save action buttons

### 3.6 Insights Screen

**File**: `Features/FaceScan3D/Views/InsightsTabView.swift`

**States**:
- Empty state (if no scans)
- Baseline state (if 1 scan)
- Full insights (if 2+ scans):
  - Progress trends chart
  - Key metrics analysis
  - Personalized recommendations
  - Improvement patterns

### 3.7 Profile Screen

**File**: `Features/Navigation/MainTabView.swift` (ProfileTabView)

**Components**:
- User profile header (avatar with initials)
- User name and email
- Active challenge card
- Achievements carousel
- Statistics section:
  - Total scans
  - Current streak
  - Longest streak
  - Average score
  - Best score
  - 30-day improvement
- Settings link

### 3.8 Settings Screens

#### Main Settings

**File**: `Features/Settings/SettingsView.swift`

**Sections**:
- **Scan Settings**:
  - Show 3D Face Mesh toggle
  - High Quality Mode toggle
  - Haptic Feedback toggle
  - Lighting Validation picker (Strict/Relaxed/Off)
- **Advanced**:
  - Capture Settings
  - Device Info
- **App**:
  - Notifications
  - Privacy
  - About
- **Danger Zone**:
  - Delete all data button

#### Other Settings Views

| View | File | Purpose |
|------|------|---------|
| CaptureSettingsView | CaptureSettingsView.swift | Camera capture configuration |
| DeviceInfoView | DeviceInfoView.swift | Device capabilities and optimization |
| NotificationsSettingsView | NotificationsSettingsView.swift | Notification preferences |
| PrivacySettingsView | PrivacySettingsView.swift | Privacy and data handling |
| AboutView | AboutView.swift | App information and credits |

### 3.9 Gamification Screens

#### Challenge Detail

**File**: `Features/Gamification/ChallengeDetailView.swift`

**Components**:
- Header with flame icon
- Progress bar with percentage
- Calendar grid showing days completed
- Glow improvement chart
- Milestone section

#### Achievement Detail

**File**: `Features/Gamification/AchievementDetailView.swift`

**Components**:
- Large achievement icon (locked/unlocked)
- Title and description
- Unlock status and date
- Progress toward unlock

### 3.10 Metric Detail

**File**: `Features/FaceScan3D/Views/MetricDetailView.swift`

**Components**:
- Large ring visualization of metric score
- History chart showing trend
- Metric breakdown
- Timeline of changes
- Normal range reference

### 3.11 Debug Screens

| View | File | Purpose |
|------|------|---------|
| DebugScreen | Debug/DebugScreen.swift | Comprehensive debugging |
| DebugOverlayView | Debug/DebugOverlayView.swift | In-app debug overlay |
| HistogramView | Debug/HistogramView.swift | Histogram visualization |
| MemoryDiagnosticsView | Core/Memory/MemoryDiagnosticsView.swift | Memory monitoring |
| PerformanceDiagnosticsView | Core/Performance/PerformanceDiagnosticsView.swift | Performance metrics |
| DataBackupView | Core/StorageKit/Migration/DataBackupView.swift | Backup interface |

### 3.12 Other Screens

| View | File | Purpose |
|------|------|---------|
| OnboardingFlow | Onboarding/OnboardingFlow.swift | First-time user onboarding |
| SocialSharingView | Social/SocialSharingView.swift | Share results |
| Face3DViewer | FaceScan3D/Views/Face3DViewer.swift | 3D mesh visualization |
| TexturedMeshPreviewView | FaceScan3D/Views/TexturedMeshPreviewView.swift | Preview textured mesh |
| ComparisonView | FaceScan3D/UI/ComparisonView.swift | Before/after comparison |
| ClinicalInfoView | FaceScan3D/UI/ClinicalInfoView.swift | Scientific methodology |
| CelebrationView | FaceScan3D/UI/CelebrationView.swift | Improvement celebration |

---

## 4. NAVIGATION FLOW

```
ContentView
├── MainTabView (5-tab navigation)
│   │
│   ├── HOME TAB
│   │   └── HomeView
│   │       ├── [Tap Scan] → EmotionalScan3DFlowView (sheet)
│   │       ├── [Tap Scan Item] → ResultsDetailView
│   │       ├── [Tap Metric] → MetricDetailView (sheet)
│   │       ├── [Tap Challenge] → ChallengeDetailView (sheet)
│   │       └── [Tap Settings] → SettingsView (sheet)
│   │
│   ├── HISTORY TAB
│   │   └── ResultsHistoryView
│   │       ├── [Tap Session] → ResultsDetailView (sheet)
│   │       │   ├── [Share] → SocialSharingView
│   │       │   ├── [Heatmap] → HeatmapView
│   │       │   └── [Delete] → Confirmation
│   │       └── [Insights] → InsightsTabView
│   │
│   ├── SCAN TAB (Center Button)
│   │   └── EmotionalScan3DFlowView
│   │       ├── ScanPreparationView (3s countdown)
│   │       ├── FaceScan3DView (ARKit capture)
│   │       │   ├── CalibrationOverlay
│   │       │   ├── LightingCalibrationView
│   │       │   ├── FaceGuidanceView
│   │       │   └── DebugInfoView (if debug)
│   │       ├── CaptureProgressView (processing)
│   │       └── CelebratoryResultsView (results)
│   │           ├── [Share] → SocialSharingView
│   │           ├── [Metric] → MetricDetailView
│   │           └── [Close] → MainTabView
│   │
│   ├── INSIGHTS TAB
│   │   └── InsightsTabView
│   │       ├── Empty state (no scans)
│   │       ├── Baseline state (1 scan)
│   │       └── Full insights (2+ scans)
│   │
│   └── PROFILE TAB
│       └── ProfileTabView
│           ├── [Challenge] → ChallengeDetailView (sheet)
│           ├── [Achievement] → AchievementDetailView (sheet)
│           └── [Settings] → SettingsView (sheet)
│
└── Settings (Sheet)
    ├── SettingsView
    │   ├── → CaptureSettingsView
    │   ├── → DeviceInfoView
    │   ├── → NotificationsSettingsView
    │   ├── → PrivacySettingsView
    │   └── → AboutView
    └── [Delete All Data] → Confirmation
```

---

## 5. SCANNING SYSTEM

### 5.1 Camera Capture Architecture

**Primary File**: `Features/FaceScan3D/Views/ARFaceTrackingViewController.swift`

The app uses **ARKit Face Tracking** with:
- **ARSCNView** (UIKit wrapper) for AR session management
- **ARFaceTrackingConfiguration** with light estimation enabled
- Maximum 1 tracked face at a time
- Session reset on each scan start

### 5.2 Multi-Angle Capture System

**5 Required Poses**:

| Step | Instruction | Yaw Range | Pitch Range | Roll Tolerance |
|------|-------------|-----------|-------------|----------------|
| lookStraight | "Look straight at camera" | ±5° | ±5° | ±8° |
| turnLeft | "Turn head left" | 15-35° | ±15° | ±8° |
| turnRight | "Turn head right" | -15 to -35° | ±15° | ±8° |
| lookUp | "Tilt head up" | ±15° | 10-22° | ±8° |
| lookDown | "Tilt head down" | ±15° | -12 to -25° | ±8° |

### 5.3 Capture Flow

```
START SCAN
    ↓
Initialize CaptureSequence
    ↓
Set currentGuidanceStep = .lookStraight
    ↓
[60fps AR TRACKING LOOP]
    ├─ Extract ARFaceAnchor + light estimation
    ├─ Update FaceMeshGeometry
    ├─ Check calibration (lighting, distance, stability)
    ├─ Check pose validity
    ├─ Generate guidance feedback
    └─ All conditions met? → Start 1-second countdown
    ↓
COUNTDOWN COMPLETION
    ├─ Capture mesh frame (3-5 frames averaged)
    ├─ Capture texture sample
    ├─ Mark pose as captured
    └─ Move to next pose (or finish if all 5 captured)
    ↓
ALL POSES CAPTURED
    ↓
FINALIZE CAPTURE
    ├─ Merge multi-angle meshes → UnifiedMesh
    └─ ProcessingPipeline.finalizeCapture()
    ↓
TEXTURE BAKING
    ├─ TextureBaker processes all samples
    ├─ Apply lighting normalization
    ├─ Apply color correction
    └─ Generate albedo texture (2K or 4K)
    ↓
METRICS COMPUTATION
    ├─ Face3DMetricsAnalyzer processes mesh + texture
    ├─ Calculate per-region metrics (Face3DROI)
    ├─ Generate heatmap visualizations
    └─ Return Face3DMetrics with overall score
    ↓
SAVE RESULTS
    ├─ Create SessionResult in Core Data
    ├─ Store images (thumbnail, face, heatmaps)
    └─ Store metrics JSON (versioned)
    ↓
SCAN COMPLETE → Show Results
```

### 5.4 Quality Detection System

#### Sharpness Detection (Blur)

**Method**: Laplacian variance

```
Process:
1. Focus on center 60% of image (face region)
2. Convert to grayscale
3. Apply Laplacian kernel: center × 4 - (top + bottom + left + right)
4. Calculate variance using vDSP Accelerate
5. Return Laplacian variance (0-500+ range)

Thresholds:
- Minimum sharp: 60.0 (baseline)
- Poor lighting (<500 lux): 30.0
- Optimal lighting (>1000 lux): 60.0
```

#### Exposure Analysis

**Method**: Average pixel brightness with skin-tone adaptation

```
Process:
1. Convert to grayscale
2. Calculate mean brightness via vDSP
3. Analyze dynamic range (max - min)
4. Apply skin-tone adjustment for dark skin

Thresholds:
- Underexposed: <0.25
- Overexposed: >0.75
- Ideal: 0.5 ± 0.3
```

#### Expression Detection

Uses ARKit blend shapes to detect non-neutral expressions:

| Expression | Threshold |
|------------|-----------|
| Smile | <0.25 |
| Frown | <0.25 |
| Jaw Open | <0.15 |
| Mouth Pucker | <0.2 |
| Cheek Puff | <0.2 |
| Eye Blink | <0.7 |
| Eye Wide | <0.3 |
| Eye Squint | <0.3 |
| Brow Movement | <0.3 |

### 5.5 Real-Time Guidance Feedback

**Priority-Based Messaging**:

1. **Yaw (left/right)** - Highest priority
   - >30°: "Turn your head to the [LEFT/RIGHT]"
   - 10-30°: "Turn slightly [left/right]"
   - 5-10°: "Almost centered - tiny bit [left/right]"

2. **Pitch (up/down)** - Secondary
   - <-15°: "Look UP toward camera"
   - -5°±5°: "Almost level - lift/lower chin slightly"

3. **Roll (tilt)** - Tertiary
   - >25°: "Level your head"
   - 8°±8°: "Almost level - straighten head"

### 5.6 Texture Resolution Options

| Mode | Resolution | Frames/Pose | File Size | Confidence |
|------|------------|-------------|-----------|------------|
| Standard | 2048×2048 | 3 | ~1.5-2MB | 83-85% |
| High-Res | 4096×4096 | 5 | ~12-16MB | 90-92% |

---

## 6. ALL ANALYZERS & METRICS

### 6.1 Analyzer Inventory

| Analyzer | Type | Input | Output | File |
|----------|------|-------|--------|------|
| ImageQualityAnalyzer | Quality | UIImage | sharpness, exposure | Utilities/ImageQualityAnalyzer.swift |
| SpecularAnalyzer | Quality | ROITexture | specularProxy (0-1) | Utilities/SpecularAnalyzer.swift |
| RoughnessAnalyzer | Texture | ROITexture | roughnessProxy (0-1) | Utilities/RoughnessAnalyzer.swift |
| PigmentationAnalyzer | Texture | ROITexture | pigmentationIndex (0-1) | Utilities/PigmentationAnalyzer.swift |
| DiscolorationAnalyzer | Texture | ROITexture | discolorationIndex (0-1) | Utilities/DiscolorationAnalyzer.swift |
| WrinkleAnalyzer | Geometry | FaceMeshGeometry | depths (mm), count | Metrics/WrinkleAnalyzer.swift |
| PoreAnalyzer | Texture | UIImage | density, visibility | Metrics/PoreAnalyzer.swift |
| AcneAnalyzer | Combined | UIImage + Mesh | blemish count, severity | Metrics/AcneAnalyzer.swift |
| RednessAnalyzer | Texture | UIImage | inflammationLevel | Metrics/RednessAnalyzer.swift |
| SunDamageAnalyzer | Composite | Face3DMetrics | protectionScore | Metrics/SunDamageAnalyzer.swift |
| GlowAnalyzer | Composite | Texture + Metrics | glowScore, radianceScore | Metrics/GlowAnalyzer.swift |
| MeshTopologyAnalyzer | Geometry | FaceMeshGeometry | quality metrics | Metrics/MeshTopologyAnalyzer.swift |
| SkinTypeClassifier | Combined | Metrics | skinType | Metrics/SkinTypeClassifier.swift |
| Face3DMetricsAnalyzer | Master | UnifiedMesh + Texture | Complete analysis | Utilities/Face3DMetricsAnalyzer.swift |

### 6.2 Detailed Analyzer Specifications

#### 6.2.1 ImageQualityAnalyzer

**Purpose**: Assesses image quality for texture capture

**Input**:
- `image`: UIImage
- Configuration: `minSharpnessThreshold` (60.0), `idealExposure` (0.5), `maxExposureDeviation` (0.3)

**Output**:
- `sharpness`: Float (0-500+, Laplacian variance)
- `isSharp`: Bool (>= threshold)
- `exposure`: Float (0-1, 0.5 = ideal)
- `isWellExposed`: Bool
- `overallQuality`: Bool
- `histogram`: [Int] (256-bin)

**Sharpness Calculation**:
```
1. Crop to center 60% (face region)
2. Convert to grayscale
3. Apply 3x3 Laplacian kernel
4. Calculate variance using vDSP
5. High variance = sharp, low variance = blurry
```

#### 6.2.2 RoughnessAnalyzer

**Purpose**: Analyzes skin texture roughness

**Input**: ROITextureSample (RGB pixels)

**Output**:
- `roughnessProxy`: Float (0-1, higher = rougher)

**Score Mapping**:
| Roughness | Score | Interpretation |
|-----------|-------|----------------|
| <0.08 | 90-100 | Excellent smoothness |
| 0.08-0.25 | 60-90 | Good smoothness |
| 0.25-0.50 | 20-60 | Moderate roughness |
| >0.50 | 0-20 | High roughness |

**Calculation**:
```
GPU Path (Metal):
1. No downsampling - processes full resolution
2. GPU-accelerated Gaussian blur
3. High-pass filter: original - lowpass(original)
4. Normalized energy = mean(abs(highpass)) / mean(luminance) * 10.0

CPU Fallback:
1. Downsample to 512px max
2. Box filter approximation of Gaussian
3. Same high-pass and normalization
```

#### 6.2.3 PigmentationAnalyzer

**Purpose**: Measures skin tone evenness using CIELAB color space

**Input**: ROITextureSample, optional lightingQuality, optional skinTone

**Output**:
- `pigmentationIndex`: Float (0-1, higher = more uneven)
- `evenness`: Float (100 - index*100)
- `confidence`: Float (0-100)

**Calculation**:
```
1. Convert RGB → Linear RGB (sRGB gamma)
2. Linear RGB → XYZ (D65 illuminant)
3. XYZ → LAB
4. Calculate variance in A* (green-red) and B* (blue-yellow)
5. Combined variance = A* × 0.5 + B* × 0.5
6. Apply lighting quality correction
7. Apply skin-tone normalization factor
8. Final index = sqrt(variance) / normalization
```

**Skin-Tone Normalization Factors**:
| Skin Tone | Factor |
|-----------|--------|
| Very Light/Light | 100.0 |
| Medium/MediumDark | 120.0 |
| Dark/VeryDark | 130.0 |

#### 6.2.4 WrinkleAnalyzer

**Purpose**: Analyzes wrinkle depth using 3D mesh curvature

**Input**: FaceMeshGeometry (3D mesh in meters)

**Output**:
- `overallScore`: Float (0-100)
- `wrinkleDepth`: WrinkleDepth enum
- `wrinkleCount`: Int
- `wrinkleRegions`: [WrinkleRegion]
- `confidence`: Float (40-80%)
- `avgDepthMM`: Float
- `maxDepthMM`: Float

**Depth Classification**:
| Category | Depth | Score |
|----------|-------|-------|
| Fine Lines | <0.7mm | 85 |
| Moderate | 0.7-1.2mm | 55 |
| Deep | >1.2mm | 25 |

**Calculation**:
```
1. Build vertex adjacency from triangle indices
2. For each vertex: calculate normal variation vs neighbors
3. curvature = Σ||normal_diff|| / edgeLength / neighbor_count
4. Stage 1: Initial threshold (curvature >70)
5. Stage 2: Depth validation (>= 0.5mm)
6. Estimated depth = curvature × 0.000015
7. Cluster high-curvature vertices into regions
8. Filter regions with <10 vertices
```

#### 6.2.5 PoreAnalyzer

**Purpose**: Detects and analyzes skin pore visibility

**Input**: UIImage (skin texture)

**Output**:
- `visibility`: Float (0-100, lower = better)
- `density`: Float (pores/cm²)
- `averageSize`: Float (pixels)
- `sizeDistribution`: PoreSizeDistribution
- `dominantSize`: PoreSize enum
- `confidence`: Float (40-95%)

**Size Classifications**:
| Size | Pixels | Score |
|------|--------|-------|
| Small | <3 | 90 |
| Medium | 3-6 | 70 |
| Large | 6-10 | 50 |
| Very Large | >10 | 30 |

**Calculation**:
```
High-Frequency Energy:
1. Apply Laplacian operator
2. Average energy = Σ|laplacian| / pixel_count
3. Visibility = min(100, energy × 10)

Individual Pore Detection:
1. Convert to grayscale + Gaussian blur
2. Calculate adaptive darkness threshold
3. Detect local minima (darker than all 8 neighbors)
4. Flood-fill to measure pore size
5. Filter: 2-50 pixel range
```

**Skin-Tone Adaptive Thresholds**:
| Condition | Multiplier |
|-----------|------------|
| Bright (>220) | 0.75 |
| Optimal (100-200) | 0.70 |
| Dark (<80) | 0.60 |

#### 6.2.6 AcneAnalyzer

**Purpose**: Detects acne using unified skin-tone-fair method

**Input**: UIImage + optional FaceMeshGeometry

**Output**:
- `overallScore`: Float (0-100)
- `blemishCount`: Int
- `severity`: AcneSeverity enum
- `blemishes`: [Blemish]
- `regionalScores`: [String: Float]
- `confidence`: Float (30-90%)

**Severity Levels**:
| Level | Blemishes | Score |
|-------|-----------|-------|
| Clear | 0-5 | 95 |
| Mild | 6-20 | 75 |
| Moderate | 21-50 | 50 |
| Severe | 50+ | 25 |

**Blemish Types** (classified by 3D elevation):
| Type | Elevation | Appearance |
|------|-----------|------------|
| Blackhead | 0mm | Flat, dark |
| PIH | 0mm | Flat, dark |
| Papule | <1mm | Small bump |
| Pustule | 1-2mm | Medium bump |
| Cyst | >2mm | Large bump |

**Calculation**:
```
Step 1: Darkness Detection (Skin-Tone Adaptive)
- Calculate average brightness in face center
- Apply skin-tone multiplier:
  - Very Light/Light: 0.70
  - Medium: 0.73
  - Medium Dark: 0.76
  - Dark: 0.80
  - Very Dark: 0.82
- Threshold = max(30, avg × multiplier)

Step 2: Local Dark Spot Detection
- Check each pixel against 8 neighbors
- Flood-fill to measure size (2-50 pixels)

Step 3: 3D Elevation Detection (if geometry available)
- Calculate local elevation = z - neighbors_avg_z
- Threshold: >0.5mm

Step 4: Correlation
- Match darkness spots with nearby elevations
- Classify by elevation height

Step 5: Scoring
- severity = (size/50) × 0.5 + (elevation/3) × 0.5
- overallScore = base - avg_severity × 20
```

#### 6.2.7 RednessAnalyzer

**Purpose**: Detects inflammation, accounting for dark skin

**Input**: UIImage (RGB texture)

**Output**:
- `overallScore`: Float (0-100)
- `rednessLevel`: RednessLevel enum
- `globalRedness`: Float (0-1)
- `regionalRedness`: [String: Float]
- `inflamedAreas`: [InflammedRegion]
- `confidence`: Float (50-90%)
- `detectionMethod`: String ("redness" or "darkening")

**Level Classifications**:
| Level | Global Redness | Score |
|-------|----------------|-------|
| Minimal | <0.05 | 95 |
| Mild | 0.05-0.20 | 75 |
| Moderate | 0.20-0.30 | 50 |
| Severe | >0.30 | 25 |

**Skin-Tone Adaptive Detection**:
```
Light Skin Path:
- Adaptive threshold = max(0.08, baseline_redness × 1.5)
- Relative redness = current_redness - baseline_redness
- Inflammation = pixels with redness > threshold

Dark Skin Path:
- Use darkening method instead of redness
- Relative darkness = baseline_brightness - current_brightness
- Inflammation detected when darkness > 10%
```

#### 6.2.8 SunDamageAnalyzer

**Purpose**: Composite sun damage assessment

**Input**: Face3DMetrics, skinTone

**Output**:
- `protectionScore`: Float (0-100)
- `damageLevel`: SunDamageLevel enum
- Component scores with weights:
  - `pigmentationHealth`: 30%
  - `photoagingResistance`: 25%
  - `textureHealth`: 20%
  - `vascularHealth`: 15%
  - `poreHealth`: 10%
- `recommendations`: [String] (up to 5)

**Damage Levels**:
| Level | Score Range |
|-------|-------------|
| Excellent Protection | 85-100 |
| Good Protection | 70-84 |
| Moderate Protection | 55-69 |
| Needs Attention | 40-54 |
| High Concern | <40 |

#### 6.2.9 GlowAnalyzer

**Purpose**: Differentiates health (glow) from luminosity (radiance)

**Input**: UIImage, FaceMeshGeometry, Face3DMetrics

**Output**:
- `glowScore`: Float (0-100) - Overall health index
- `radianceScore`: Float (0-100) - Pure luminosity
- Component contributions with weights:
  - `smoothnessContribution`: 25%
  - `evennessContribution`: 20%
  - `radianceContribution`: 20%
  - `discolorationContribution`: 15% (inverted)
  - `rednessContribution`: 10% (inverted)
  - `acneContribution`: 10%
- `labLightness`: Float (0-1)
- `specularHighlightRatio`: Float (0-0.3)

**Glow Calculation**:
```
glowScore = (
  smoothness × 0.25 +
  evenness × 0.20 +
  radiance × 0.20 +
  clarity × 0.15 +
  (100 - redness) × 0.10 +
  acne × 0.10
)

Excludes: Firmness/Wrinkles (age-related), Oil Control (low confidence)
```

**Radiance Calculation**:
```
radianceScore = (labLightness × 0.70 + specularRatio × 0.30) × 100
```

### 6.3 Master Analyzer: Face3DMetricsAnalyzer

**File**: `Utilities/Face3DMetricsAnalyzer.swift`

**Purpose**: Orchestrates all analyzers and produces final metrics

**Processing Pipeline**:
```
1. Texture Quality Validation → QualityMetrics
2. ROI Generation → 5 masks (forehead, cheeks L/R, nose, chin)
3. Texture Sampling → ROITextureSample per ROI
4. Parallel ROI Analysis (roughness, pigmentation, specular, luminance)
5. Global Metrics Aggregation (weighted by pixel count)
6. Lighting Assessment
7. Skin Tone Detection
8. Color Temperature Normalization
9. Parallel Advanced Analyzers (TaskGroup):
   - Volume, Regional, Skin Type, Pores, Acne,
   - Redness, Topology, Wrinkles
10. Skin-Tone Normalization
11. Glow & Radiance Analysis
12. Sun Damage Analysis (if enabled)
```

**Overall Score Formula** (5 High-Confidence Metrics):
```
overallScore = (
  smoothnessScore × 0.224 +
  pigmentationScore × 0.224 +
  poresScore × 0.149 +
  discolorationScore × 0.149 +
  acneScore × 0.149
)

High-Confidence (70%+ confidence) ONLY:
- Smoothness: 85%
- Pigmentation: 80%
- Pores: 70-90%
- Discoloration: 80%
- Acne: 75-85%

Excluded (low/variable confidence):
- Elasticity (requires 2+ scans)
- Hydration (65% proxy method)
- Oil control (disabled)
- Redness (measurement limitations)
```

### 6.4 Score Mappings (Scoring3D.swift)

**Roughness → Smoothness**:
| Proxy | Score |
|-------|-------|
| <0.08 | 90-100 |
| 0.08-0.25 | 60-90 |
| 0.25-0.50 | 20-60 |
| >0.50 | 0-20 |

**Pigmentation → Evenness**:
| Index | Score |
|-------|-------|
| <0.04 | 95-100 |
| 0.04-0.10 | 75-95 |
| 0.10-0.20 | 50-75 |
| 0.20-0.35 | 25-50 |
| >0.35 | 0-25 |

**Specular → Oil Control**:
| Proxy | Score |
|-------|-------|
| <0.02 | 95-100 |
| 0.02-0.08 | 75-95 |
| 0.08-0.15 | 50-75 |
| 0.15-0.22 | 25-50 |
| >0.22 | 0-25 |

---

## 7. CLINICAL RESULTS & INTERPRETATIONS

### 7.1 Score Grade System

| Grade | Score Range | Description |
|-------|-------------|-------------|
| A+ | 90-100 | Exceptional skin quality |
| A | 80-89 | Good overall skin quality |
| B | 70-79 | Moderate with some concerns |
| C | 60-69 | Below average |
| D | 0-59 | Significant concerns |

### 7.2 Health Rating Classifications

| Rating | Score | Icon |
|--------|-------|------|
| Excellent | 90-100 | ⭐ |
| Very Good | 80-89 | ✨ |
| Good | 70-79 | 👍 |
| Fair | 60-69 | ⚠️ |
| Needs Attention | <60 | 🔴 |

### 7.3 Metrics Displayed in Results

**Core Metrics (Included in Overall Score)**:
| Metric | Weight | Description |
|--------|--------|-------------|
| Smoothness | 22.4% | Skin texture smoothness |
| Pigmentation | 22.4% | Tone evenness |
| Pores | 14.9% | Pore visibility |
| Discoloration | 14.9% | Color uniformity |
| Acne | 14.9% | Blemish detection |

**Additional Indicators (NOT in Overall Score)**:
- Glow (Health Index composite)
- Radiance (Pure luminosity)
- Hydration (Proxy method)
- Redness/Inflammation
- Oil Control
- Wrinkles (categorical)

**Regional Scores**:
- Left Cheek
- Right Cheek
- Forehead
- Chin
- Nose Bridge

### 7.4 Confidence Levels

| Level | Range | Color |
|-------|-------|-------|
| High | 75-100% | Green |
| Moderate | 50-74% | Orange |
| Low | <50% | Yellow |

### 7.5 Clinical Info Display

**File**: `Features/FaceScan3D/UI/ClinicalInfoView.swift`

Shows expandable methodology for each metric:

**Radiance**:
- Formula: (60% Skin Tone Evenness) + (40% Healthy Shine)
- Measures: LAB L* lightness + specular highlights

**Smoothness**:
- Uses: 3D mesh vertices + texture frequency analysis
- Detects: Sub-millimeter texture irregularities

**Evenness**:
- Method: Pigmentation uniformity in LAB color space
- Normalized by baseline skin tone

**Youthfulness**:
- Formula: (Smoothness + Wrinkle Assessment) / 2

**Freshness**:
- Formula: (50% Tone Evenness) + (50% Smoothness)
- Serves as hydration proxy

### 7.6 Recommendations System

**Priority Levels**: High, Medium, Low

**Example Recommendations by Metric**:

| Metric | Threshold | Recommendation |
|--------|-----------|----------------|
| Smoothness | <70 | "Use gentle exfoliating product 2-3x/week" |
| Pigmentation | <70 | "Apply Vitamin C serum daily + SPF 30+" |
| Discoloration | <70 | "Use brightening serum (niacinamide/alpha arbutin)" |
| Wrinkles | <70 | "Incorporate retinol serum 3-4 nights/week" |
| Pores | >30 visibility | "Use niacinamide serum + clay mask weekly" |
| Universal | - | "Apply SPF 30+ sunscreen every morning" |

**Expected Impact Timelines**:
| Metric | Timeline |
|--------|----------|
| Smoothness | 2-4 weeks |
| Pigmentation | 4-6 weeks |
| Discoloration | 6-8 weeks |
| Wrinkles | 8-12 weeks |
| Pores | 3-4 weeks |

---

## 8. DATA MODELS & PERSISTENCE

### 8.1 Core Data Schema

**Entity**: `SessionResult`

**File**: `CoreData/TaviModel.xcdatamodeld`

```swift
SessionResult {
    // Identifiers
    id: UUID
    date: Date

    // Device Info
    deviceModel: String
    deviceOS: String

    // Overall Metrics (0-100)
    overallScore: Double
    blurQuality: Double
    discolorationIndex: Double
    textureAvg: Double
    pigmentationAvg: Double
    moistureSpecular: Double
    moistureSmoothness: Double
    poresScore: Double
    acneScore: Double

    // ROI Scores
    leftCheekScore: Double
    rightCheekScore: Double
    foreheadScore: Double
    chinScore: Double

    // Image Data (JPEG @ 0.8)
    thumbnail: Data           // 200×200
    faceImage: Data           // Full resolution
    heatmapComposite: Data    // 300×300
    heatmapSharpness: Data
    heatmapTexture: Data
    heatmapPigmentation: Data
    heatmapMoisture: Data

    // Metrics JSON (versioned)
    emotionalMetricsData: Data
    clinicalMetricsData: Data
}
```

### 8.2 Key Data Models

#### EmotionalMetrics

**File**: `Features/FaceScan3D/Models/EmotionalMetrics.swift`

Consumer-friendly metrics:
```swift
struct EmotionalMetrics: Codable {
    glowScore: Int              // 0-100
    radiance: Int
    smoothness: Int
    evenness: Int
    youthfulness: Int
    freshness: Int
    sunProtection: Int
    primaryInsight: String
    celebration: String
    personalizedMessage: String
    improvements: [EmotionalImprovement]
    concerns: [EmotionalConcern]
    nextSteps: [ActionableStep]
    timeEstimate: String
}
```

#### Face3DMetrics

**File**: `Features/FaceScan3D/Models/Face3DMetrics.swift`

Clinical-grade analysis:
```swift
struct Face3DMetrics: Codable {
    // Global scores (0-100%)
    globalRoughnessScore: Float
    globalPigmentationScore: Float
    globalDiscolorationScore: Float
    globalSpecularScore: Float?

    // Raw metrics (0-1)
    globalRoughnessProxy: Float
    globalPigmentationIndex: Float
    globalDiscolorationIndex: Float
    globalSpecularProxy: Float?

    // Confidence scores
    smoothnessConfidence: Float
    pigmentationConfidence: Float
    hydrationConfidence: Float
    discolorationConfidence: Float

    // Per-ROI analysis
    roiMetrics: [Face3DROI: ROI3DMetrics]

    // Advanced analyses
    glowAnalysis: GlowAnalysis?
    wrinkleAnalysis: WrinkleAnalysis?
    poreAnalysis: PoreAnalysis?
    acneAnalysis: AcneAnalysis?
    rednessAnalysis: RednessAnalysis?
    sunDamageAnalysis: SunDamageAnalysis?
    volumeAnalysis: VolumeAnalysis?
    elasticityAnalysis: ElasticityAnalysis?
}
```

#### UserProfile

**File**: `Features/User/UserProfile.swift`

```swift
struct UserProfile: Codable {
    // Identification
    id: UUID
    name: String
    email: String?
    createdAt: Date
    updatedAt: Date

    // Demographics
    age: Int?
    gender: Gender?
    skinTone: Int?  // Fitzpatrick 1-6

    // Skin Info
    skinType: SkinType?
    skinConcerns: Set<SkinConcern>
    skinGoals: Set<SkinGoal>

    // Lifestyle
    waterIntake: WaterIntake?
    sleepQuality: SleepQuality?
    stressLevel: StressLevel?
    sunExposure: SunExposure?
    smokingStatus: SmokingStatus?
    alcoholConsumption: AlcoholConsumption?
    exerciseFrequency: ExerciseFrequency?

    // Preferences
    preferredProducts: Set<ProductType>
    budget: BudgetRange?
}
```

### 8.3 Persistence Architecture

#### PersistenceController

**File**: `Core/StorageKit/PersistenceController.swift`

```swift
class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    // Session methods
    func saveSession(scores:faceImage:heatmaps:clinicalMetrics:)
    func fetchAllSessions() -> [SessionResult]
    func fetchRecentSessions(limit:) -> [SessionResult]
    func deleteSession(_:)
    func deleteAllSessions()
    func newBackgroundContext() -> NSManagedObjectContext
}
```

**Configuration**:
- Automatic lightweight migration enabled
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`
- Preview mode for SwiftUI previews (in-memory store)

### 8.4 Save Flow

```
Session Scan Complete
    ↓
Create ScoreSummary + Face3DMetrics
    ↓
SessionResult(context:scores:faceImage:heatmaps:clinicalMetrics:)
    ↓
Async Image Processing (background Task):
    - Resize face image → JPEG 0.8
    - Generate 200×200 thumbnail
    - Compress heatmaps to 300×300
    ↓
Versioned JSON Encoding:
    - VersionedFace3DMetrics wrapper
    - VersionedEmotionalMetrics wrapper
    ↓
context.save()
    ↓
If failed → CoreDataSaveQueue for retry
```

### 8.5 Versioned Metrics System

**File**: `Core/Persistence/VersionedMetricsWrapper.swift`

```swift
struct MetricsVersion {
    major: Int
    minor: Int
    patch: Int
}

// Current: 1.1.0
// Legacy: 1.0.0
```

**Load Results**:
```swift
enum Face3DMetricsLoadResult {
    case success(metrics, version)
    case migrated(metrics, from, to)
    case incompatible(version, reason)
    case corrupted(error)
    case notFound
}
```

### 8.6 Backup & Migration

#### CoreDataMigrationManager

**Features**:
- Automatic backup before migration
- Lightweight migration support
- Custom mapping model support
- Automatic rollback on failure

**Backup Location**: Caches/ (not iCloud)

#### DataBackupManager

**User-Facing Operations**:
- `createBackup(named:)`
- `restoreFromBackup(_:)`
- `exportBackup(_:)`
- `importBackup(from:named:)`
- `deleteBackup(_:)`

**Storage**: Documents/ (iCloud-eligible)

### 8.7 Failed Save Recovery

**File**: `Features/FaceScan3D/Utilities/CoreDataSaveQueue.swift`

```swift
struct PendingSave: Codable {
    id: UUID
    emotionalMetricsJSON: Data
    clinicalMetricsJSON: Data
    timestamp: Date
    retryCount: Int  // Max 5 attempts
}
```

**Retry Logic**:
- Automatic retry every 30 seconds
- Max 5 attempts per save
- Stored in UserDefaults
- Loads on app launch

### 8.8 Export Functionality

**File**: `Features/FaceScan3D/Utilities/ExportManager.swift`

**Supported Formats**:
| Format | Files Generated |
|--------|-----------------|
| OBJ | .obj + .mtl + .png |
| glTF | .gltf + .bin + .png |
| USDZ | .usdz (embedded) |

### 8.9 User Settings Storage

**@AppStorage Keys**:
```swift
enableFaceMesh: Bool = true
enableHighResCapture: Bool = false
lightingStrictness: String = "Strict"
enableHapticFeedback: Bool = true
debugModeEnabled: Bool = false
skipOnboarding: Bool = false
```

---

## 9. SERVICES & UTILITIES

### 9.1 Core Services

#### HapticManager

**File**: `Core/HapticManager.swift`

**Purpose**: Centralized haptic feedback

**Methods**:
| Method | Use Case |
|--------|----------|
| `light()` | Button tap |
| `medium()` | Toggle switch |
| `heavy()` | Important action |
| `success()` | Calibration complete |
| `warning()` | Warning feedback |
| `error()` | Error feedback |
| `selection()` | Picker change |
| `calibrationSuccess()` | Double success |
| `captureComplete()` | Pose captured |
| `analysisComplete()` | Analysis done |

#### AnalyticsManager

**File**: `Core/Analytics/AnalyticsManager.swift`

**Purpose**: Event tracking with local storage

**Features**:
- Generic event tracking
- Screen view tracking
- Performance timing
- Error tracking with context
- User action tracking
- Scan lifecycle events

**Storage**: JSON in UserDefaults (1000 event limit)

#### MemoryBudgetManager

**File**: `Core/Memory/MemoryBudgetManager.swift`

**Purpose**: Memory budget enforcement

**Default Budgets**:
| Component | Budget | Priority |
|-----------|--------|----------|
| FaceScanCapture | 50 MB | 5 |
| MeshMerging | 100 MB | 4 |
| TextureBaking | 150 MB | 4 |
| MetricsComputation | 50 MB | 3 |
| CoreDataCache | 30 MB | 2 |
| ImageCache | 50 MB | 2 |
| General | 70 MB | 1 |

**Device Scaling**:
- 6GB+ RAM: 1.5x
- 4-6GB RAM: 1.0x
- <4GB RAM: 0.7x

#### CrashReporter

**File**: `Core/Utilities/CrashReporter.swift`

**Purpose**: Crash reporting via Sentry (optional)

**Features**:
- Automatic crash detection
- Non-fatal error logging
- Performance monitoring (20% sample)
- User context (anonymized)
- Breadcrumb logging

### 9.2 Core Utilities

#### AppLogger

**File**: `Core/Utilities/AppLogger.swift`

**Purpose**: Centralized logging with os.log

**Category Loggers**:
- `faceScan`, `metrics`, `mesh`, `storage`
- `network`, `ui`, `gamification`, `auth`
- `export`, `social`, `app`

**Log Levels**: debug, info, warning, error, critical, fault

#### BiometricAuth

**File**: `Core/Utilities/BiometricAuth.swift`

**Purpose**: Face ID / Touch ID authentication

**Methods**:
- `isBiometricAvailable()`
- `biometricType()` → .faceID, .touchID, .none
- `authenticate(reason:)`
- `authenticateWithPasscode(reason:)`

#### InputValidator

**File**: `Core/Utilities/InputValidator.swift`

**Purpose**: User input validation

**Validations**:
- Name (2-50 chars)
- Age (13-120)
- Email format
- Text length
- Numeric range
- Date (past, reasonable)
- Skin type

#### AsyncTimeout

**File**: `Core/Utilities/AsyncTimeout.swift`

**Purpose**: Timeout protection for async operations

```swift
try await withTimeout(seconds: 60) {
    await longOperation()
}
```

### 9.3 Scan Managers

#### ScanStateManager

**Purpose**: Manages scan state machine

**States**:
- Guidance step (5 poses)
- Countdown timer
- Capture status
- Pose correctness
- Current sequence

#### ValidationManager

**Purpose**: Validate lighting, position, quality

**Checks**:
- Lighting conditions
- Face position/angles
- Edge cases (glasses, hands, hat)
- Lighting consistency (±20%)

#### CalibrationManager

**Purpose**: Comprehensive quality validation

**Quality Checks (every 30 frames)**:
1. Lighting consistency
2. Neutral expression
3. Exposure (multi-region)
4. Sharpness (adaptive threshold)
5. Occlusion detection

#### CaptureSequenceManager

**Purpose**: Manage capture sequences and countdown

**Features**:
- Tolerance frame handling (15 frames)
- Multi-frame capture (3 or 5 per pose)
- Texture capture integration
- Debug logging (throttled)

#### MetricsOrchestrator

**Purpose**: Orchestrate metrics computation

**Operations**:
- Compute 3D metrics from baked result
- Generate visualizations
- Track device info and timing
- Generate scan metadata

---

## 10. CONFIGURATION & THRESHOLDS

### 10.1 Central Configuration

**File**: `Core/Utilities/ScanConfiguration.swift`

All scan thresholds are centralized in this file.

### 10.2 Lighting Calibration

| Parameter | Value |
|-----------|-------|
| Max lighting change | 30% |
| Max color temp change | 15% |
| Min lighting level | 0.3 |
| Max lighting level | 0.7 |
| Min ambient (lumens) | 600 |
| Max ambient (lumens) | 2000 |
| Optimal min (lumens) | 800 |
| Optimal max (lumens) | 1800 |

### 10.3 Face Expression Thresholds

| Expression | Max Threshold |
|------------|---------------|
| Jaw Open | 0.15 |
| Eye Blink | 0.20 |
| Smile | 0.25 |
| Mouth Pucker | 0.20 |
| Cheek Puff | 0.20 |
| Eye Wide | 0.30 |
| Squint | 0.30 |
| Brow Movement | 0.30 |

### 10.4 Face Pose Thresholds (degrees)

| Pose | Yaw | Pitch | Roll |
|------|-----|-------|------|
| Center | ±5° | ±5° | ±8° |
| Turn Left | 15-35° | ±15° | ±8° |
| Turn Right | -15 to -35° | ±15° | ±8° |
| Look Up | ±15° | 10-22° | ±8° |
| Look Down | ±15° | -12 to -25° | ±8° |

### 10.5 Image Quality

| Parameter | Value |
|-----------|-------|
| Min sharpness | 0.5 |
| Max blur | 0.25 |
| Min exposure | 0.2 |
| Max exposure | 0.8 |
| Ideal exposure | 0.5 |
| Underexposed | <0.25 |
| Overexposed | >0.75 |
| Blink detection | 0.7 |

### 10.6 Distance Calibration (meters)

| Parameter | Value |
|-----------|-------|
| Min face distance | 0.20m |
| Optimal min | 0.25m |
| Optimal max | 0.50m |
| Acceptable far | 0.60m |
| Max face distance | 0.70m |
| Stability threshold | 0.03m |

### 10.7 Processing Timeouts

| Operation | Timeout |
|-----------|---------|
| Mesh merge | 60s |
| Texture bake | 60s |
| Metrics computation | 240s (4 min) |
| Core Data save | 20s |

### 10.8 Texture Resolution

| Mode | Resolution | Compression |
|------|------------|-------------|
| Standard | 2048×2048 | 0.8 JPEG |
| High-Res | 4096×4096 | 0.8 JPEG |

### 10.9 Multi-Frame Capture

| Parameter | Recommended | Best Case |
|-----------|-------------|-----------|
| Frames per pose | 3 | 5 |
| Memory limit | 7 frames | 7 frames |
| System confidence | 83-85% | 90-92% |

### 10.10 Score Thresholds

| Rating | Score |
|--------|-------|
| Excellent | 80+ |
| Good | 60+ |
| Fair | 40+ |
| Poor | <40 |

### 10.11 Performance Throttling

| Check | Interval |
|-------|----------|
| Quality analysis | Every 30 frames |
| Debug logging | Every 30 frames |
| Countdown tolerance | 15 frames |
| Streaming mesh | >50,000 vertices |

---

## APPENDIX A: FACE REGIONS (ROI)

| Region | Code | Description |
|--------|------|-------------|
| Forehead | `.forehead` | Upper face above eyebrows |
| Left Cheek | `.leftCheek` | Left side of face |
| Right Cheek | `.rightCheek` | Right side of face |
| Nose Bridge | `.noseBridge` | Bridge of nose |
| Chin | `.chin` | Lower face below mouth |
| Lips | `.lips` | Lip area (if analyzed) |

---

## APPENDIX B: SKIN TONE CATEGORIES

| Category | Fitzpatrick | Normalization Factor |
|----------|-------------|----------------------|
| Very Light | I | 100.0 |
| Light | II | 100.0 |
| Medium | III | 120.0 |
| Medium Dark | IV | 120.0 |
| Dark | V | 130.0 |
| Very Dark | VI | 130.0 |

---

## APPENDIX C: FILE COUNTS BY CATEGORY

| Category | Count |
|----------|-------|
| Views/Screens | 43 |
| Analyzers | 14+ |
| Data Models | 12 |
| Managers | 7 |
| Utilities | 30+ |
| Processing | 8 |
| Metal | 2 |
| Tests | 10 |
| **Total** | **161** |

---

## APPENDIX D: KEY DEPENDENCIES

| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI Framework |
| ARKit | Face Tracking |
| Metal | GPU Processing |
| CoreData | Persistence |
| Accelerate | vDSP Math |
| AVFoundation | Camera Access |
| LocalAuthentication | Biometrics |
| Sentry (optional) | Crash Reporting |

---

*End of Documentation*
