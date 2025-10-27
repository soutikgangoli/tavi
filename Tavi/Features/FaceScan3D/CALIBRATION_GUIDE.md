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
    case tooDark    // < 300 lumens
    case tooBright  // > 2500 lumens
    case good       // 300-2500 lumens
}
```

**Messages:**
- "Please find better lighting"
- "Lighting is too bright"
- "Lighting is good"

### DistanceCondition

```swift
enum DistanceCondition {
    case tooClose   // < 25cm
    case tooFar     // > 70cm
    case good       // 25-70cm
}
```

**Messages:**
- "Please move back a bit"
- "Please move closer"
- "Distance is perfect"

### StabilityCondition

```swift
enum StabilityCondition {
    case moving     // > 1cm movement/frame
    case stable     // < 1cm movement/frame
}
```

**Messages:**
- "Please hold still"
- "Holding steady"

## Guidance Steps

The system captures 5 different face poses:

### 1. Look Straight
- **Validation:** yaw < 5°, pitch < 5°, roll < 8°
- **Instruction:** "Please look straight at the camera"

### 2. Turn Left
- **Validation:** yaw 15-35°, pitch < 15°, roll < 12°
- **Instruction:** "Please turn your head left"

### 3. Turn Right
- **Validation:** yaw -15 to -35°, pitch < 15°, roll < 12°
- **Instruction:** "Please turn your head right"

### 4. Look Up
- **Validation:** pitch -10 to -25°, yaw < 15°, roll < 12°
- **Instruction:** "Please look up slightly"

### 5. Look Down
- **Validation:** pitch 10-25°, yaw < 15°, roll < 12°
- **Instruction:** "Please look down slightly"

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
