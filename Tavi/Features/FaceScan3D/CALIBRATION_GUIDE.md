# FaceScan3D Calibration & Guidance System

Complete guide to the automatic calibration and guided capture features.

## Overview

The calibration system ensures optimal 3D face scanning by automatically checking:
- Lighting conditions
- Face distance from camera
- User stability

Once calibrated, the guidance system walks users through a 5-pose capture workflow with visual feedback and countdown timers.

## System Architecture

```
┌─────────────────────────────────────────┐
│         FaceScan3DView                  │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  ARFaceTrackingViewController     │ │
│  │  (ARKit + ARSCNView)              │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  CalibrationOverlay               │ │
│  │  - CalibrationStatusView          │ │
│  │  - GuidanceView                   │ │
│  │  - StatusBadge                    │ │
│  │  - StepIndicator                  │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  FaceScan3DViewModel              │ │
│  │  - CalibrationState               │ │
│  │  - GuidanceStep                   │ │
│  │  - CapturedPoseData               │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Calibration States

### LightingCondition

```swift
enum LightingCondition {
    case tooDark      // < 600 lumens
    case acceptable   // 600-800 or 1800-2000 lumens
    case good         // 800-1800 lumens (OPTIMAL)
    case tooBright    // > 2000 lumens
}
```

**Thresholds** (defined in `ScanConfiguration.swift`):
- `minAmbientLighting`: 600 lumens
- `optimalLightingMin`: 800 lumens
- `optimalLightingMax`: 1800 lumens
- `maxAmbientLighting`: 2000 lumens

**Messages:**
- "Please find better lighting"
- "Lighting is too bright"
- "Lighting is good"

### DistanceCondition

```swift
enum DistanceCondition {
    case tooClose     // < 20cm
    case acceptable   // 20-25cm or 50-60cm
    case good         // 30-50cm (OPTIMAL)
    case tooFar       // > 60cm
}
```

**Thresholds** (defined in `ScanConfiguration.swift`):
- `minFaceDistance`: 0.20m (20cm)
- `optimalDistanceMin`: 0.30m (30cm)
- `optimalDistanceMax`: 0.50m (50cm)
- `acceptableFarDistance`: 0.60m (60cm)
- `maxFaceDistance`: 0.70m (70cm)

**Messages:**
- "Please move back a bit"
- "Please move closer"
- "Distance is perfect"

### StabilityCondition

```swift
enum StabilityCondition {
    case moving     // > 3cm movement/frame
    case stable     // < 3cm movement/frame
}
```

**Thresholds** (defined in `ScanConfiguration.swift`):
- `stabilityMovementThreshold`: 0.03m (3cm)

**Messages:**
- "Please hold still"
- "Holding steady"

### CenterPosition (NEW!)

```swift
enum CenterPosition {
    case center          // ±5° (green)
    case slightlyLeft    // 5-10° left (yellow)
    case slightlyRight   // 5-10° right (yellow)
    case farLeft         // >10° left (red, shows "Turn Right")
    case farRight        // >10° right (red, shows "Turn Left")
}
```

**Display:**
- Shows below Direction badge
- Color-coded: green (center), yellow (slightly off), red (far off)
- Updates in real-time based on face yaw angle

## Guidance Steps

The system captures 5 different face poses with **STRICT validation** (defined in `ScanConfiguration.swift`):

### 1. Look Straight
- **Validation:** yaw ±5°, pitch ±5°, roll ±8° (STRICT!)
- **Instruction:** "Please look straight at the camera"
- **Feedback:** Progressive guidance ("Turn slightly right", "Almost centered - tiny bit right")
- **Constants:**
  - `maxCenterYawDegrees`: 5.0°
  - `maxCenterPitchDegrees`: 5.0°
  - `maxCenterRollDegrees`: 8.0°

### 2. Turn Left
- **Validation:** yaw 15-35°, pitch ±15°, roll ±8°
- **Instruction:** "Turn your head slightly to the left"
- **Constants:**
  - `minTurnLeftYawDegrees`: 15.0°
  - `maxTurnLeftYawDegrees`: 35.0°

### 3. Turn Right
- **Validation:** yaw -15 to -35°, pitch ±15°, roll ±8°
- **Instruction:** "Turn your head slightly to the right"
- **Constants:**
  - `minTurnRightYawDegrees`: -15.0°
  - `maxTurnRightYawDegrees`: -35.0°

### 4. Look Up
- **Validation:** pitch 10-22°, yaw ±15°, roll ±8°
- **Instruction:** "Tilt your head up a bit"
- **Constants:**
  - `minLookUpPitchDegrees`: 10.0°
  - `maxLookUpPitchDegrees`: 22.0°

### 5. Look Down
- **Validation:** pitch -12 to -25°, yaw ±15°, roll ±8°
- **Instruction:** "Tilt your head down a bit"
- **Constants:**
  - `minLookDownPitchDegrees`: -12.0°
  - `maxLookDownPitchDegrees`: -25.0°

## Configuration Source of Truth

**All calibration thresholds are defined in `ScanConfiguration.swift`.**

This provides:
- ✅ Single source of truth for all validation logic
- ✅ Easy tuning without modifying multiple files
- ✅ Consistent behavior across all scan features
- ✅ Well-documented and maintainable thresholds

## Capture Workflow

```
┌──────────────────────────┐
│ 1. ARKit Initialization  │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ 2. Face Detection        │◄──────┐
└────────┬─────────────────┘       │
         │                          │
         ▼                          │
┌──────────────────────────┐       │
│ 3. Calibration Check     │       │
│    - Lighting            │       │
│    - Distance            │       │
│    - Stability           │       │
└────────┬─────────────────┘       │
         │                          │
         ▼                          │
    ┌────────┐                     │
    │ Valid? ├──────NO──────────────┘
    └───┬────┘
        │ YES
        ▼
┌──────────────────────────┐
│ 4. Show "Start Scanning" │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ 5. User Taps Start       │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ 6. Guidance Mode Active  │◄──────┐
│    Current: Look Straight│       │
└────────┬─────────────────┘       │
         │                          │
         ▼                          │
┌──────────────────────────┐       │
│ 7. Check Pose Valid      │       │
└────────┬─────────────────┘       │
         │                          │
         ▼                          │
    ┌────────┐                     │
    │ Valid? ├──────NO──────────────┘
    └───┬────┘
        │ YES
        ▼
┌──────────────────────────┐
│ 8. Start 3s Countdown    │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ 9. Capture Pose!         │
│    + Haptic Feedback     │
└────────┬─────────────────┘
         │
         ▼
    ┌─────────────┐
    │ More Poses? ├─YES─→ Next Step ─┐
    └─────┬───────┘                   │
          │                           │
          NO                          │
          │                           │
          ▼                           │
┌──────────────────────────┐         │
│ 10. All Poses Captured!  │         │
│     Show Complete UI     │         │
└──────────────────────────┘         │
                                     │
          ┌──────────────────────────┘
          │
          ▼
    [Back to Step 6]
```

## UI Components

### CalibrationStatusView

Shows 3 status badges at the top:
- 🌞 Lighting (green/yellow/red)
- ↔️ Distance (green/yellow)
- ✋ Stability (green/yellow)

Plus a message at bottom:
- "Please find better lighting"
- "Please move closer"
- "Please hold still"

### GuidanceView

Shows during pose capture:
- Progress indicators (5 circles)
  - Gray: not started
  - Blue: current step
  - Green with checkmark: completed
- Large countdown number (3, 2, 1)
- Instruction text
- Warning if calibration lost

### Completion View

Shows after all poses captured:
- ✅ Checkmark icon
- "Scan Complete!"
- "Captured 5 poses"
- "Scan Again" button

## Polite Messaging

All messages use polite, friendly language:

✅ "Please find better lighting"
✅ "Please move closer"
✅ "Please move back a bit"
✅ "Please hold still"
✅ "Please look straight at the camera"
✅ "Please turn your head left"
✅ "Please turn your head right"
✅ "Please look up slightly"
✅ "Please look down slightly"

❌ NOT: "Too dark!"
❌ NOT: "Move closer"
❌ NOT: "Look straight"

## Data Access

### CalibrationState

```swift
viewModel.calibrationState.lighting      // LightingCondition
viewModel.calibrationState.distance      // DistanceCondition
viewModel.calibrationState.stability     // StabilityCondition
viewModel.calibrationState.faceDetected  // Bool
viewModel.calibrationState.isCalibrated  // Bool
```

### CapturedPoseData

```swift
for (step, poseData) in viewModel.capturedPoses {
    poseData.step       // GuidanceStep
    poseData.geometry   // FaceMeshGeometry (vertices, normals, indices)
    poseData.yaw        // Float (degrees)
    poseData.pitch      // Float (degrees)
    poseData.roll       // Float (degrees)
    poseData.timestamp  // TimeInterval
}
```

## Integration Example

```swift
import SwiftUI

struct MyScanView: View {
    @State private var capturedData: [GuidanceStep: CapturedPoseData] = [:]
    @State private var showResults = false

    var body: some View {
        ZStack {
            FaceScan3DView(
                showMesh: true,
                meshColor: .white,
                showCalibration: true,
                onCaptureComplete: { poses in
                    capturedData = poses
                    showResults = true
                }
            )

            if showResults {
                ResultsView(poses: capturedData)
            }
        }
    }
}

struct ResultsView: View {
    let poses: [GuidanceStep: CapturedPoseData]

    var body: some View {
        VStack {
            Text("Scan Complete!")
                .font(.title)

            ForEach(GuidanceStep.allCases, id: \.rawValue) { step in
                if let pose = poses[step] {
                    HStack {
                        Text(step.shortName)
                        Spacer()
                        Text("\(pose.geometry.vertexCount) vertices")
                    }
                    .padding()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
```

## Performance Notes

- Calibration checks run every frame (60 FPS)
- Minimal performance impact (< 1ms per check)
- Countdown uses Timer (1 second intervals)
- Haptic feedback on successful capture
- Automatic cleanup on guidance stop

## Troubleshooting

### "Please find better lighting"
- Move to area with more natural light
- Avoid direct sunlight (too bright)
- Use indoor lighting (500-1500 lux ideal)

### "Please move closer/back"
- Optimal distance: 40-50cm
- Minimum: 25cm
- Maximum: 70cm

### "Please hold still"
- Rest elbows on table
- Take a deep breath and relax
- System needs < 1cm movement

### Countdown keeps resetting
- All calibration conditions must stay valid
- Hold pose steady during countdown
- Check lighting hasn't changed

## Files Added

- `CalibrationState.swift` - State models and validation logic
- `CalibrationOverlay.swift` - SwiftUI overlay components
- Updated `FaceScan3DViewModel.swift` - Calibration management
- Updated `FaceScan3DView.swift` - Overlay integration
- Updated `FaceScan3DDemoView.swift` - Demo with calibration

## See Also

- [FaceScan3D README](README.md)
- [Usage Examples](USAGE_EXAMPLE.swift)
