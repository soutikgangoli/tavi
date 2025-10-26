# Calibration System Implementation

This document describes the calibration system added to the Tavi camera app.

## Overview

The calibration system computes real-time metrics from camera frames and provides visual feedback to guide users to optimal lighting conditions before locking exposure and white balance.

## Components

### 1. CalibrationMetrics Model (`Core/ModelsKit/CalibrationMetrics.swift`)

**Data Structure:**
- `averageLuma: Double` - Average luminance (0-1 normalized)
- `histogram: [Int]` - 256-bin grayscale histogram
- `totalPixels: Int` - Total pixel count
- `isHistogramClipped: Bool` - Computed property checking if >1% pixels are at extremes
- `calibrationStatus: CalibrationStatus` - Overall status (tooLow/clipped/good)

**Status Rules:**
- **Red (tooLow)**: Average luma < 0.35 or > 0.65
- **Yellow (clipped)**: Histogram clipped (>1% in first/last 5 bins)
- **Green (good)**: Luma in range and no clipping

### 2. CameraSession Extensions (`Core/CameraKit/CameraSession.swift`)

**Added Properties:**
- `metricsPublisher: AnyPublisher<CalibrationMetrics, Never>` - Publishes metrics via Combine

**Added Methods:**
- `computeMetrics(from: CVPixelBuffer) -> CalibrationMetrics?`
  - Processes pixel buffer in BGRA format
  - Computes luma using Rec. 709 coefficients (0.2126*R + 0.7152*G + 0.0722*B)
  - Builds 256-bin histogram
  - Runs on dedicated `metricsQueue` (QoS: userInitiated)

**Frame Processing:**
- Metrics computed for every frame in `captureOutput(_:didOutput:from:)`
- Published asynchronously to avoid blocking video pipeline

### 3. CalibrationHUD (`Shared/UI/CalibrationHUD.swift`)

**Main Components:**

#### CalibrationHUD View
- Color-coded status indicator (red/yellow/green circle)
- Status icon and message
- Real-time luma value display
- Histogram status (OK/Clipped)
- "Calibrate" button (appears when status is green)
- "Locked" text when exposure/WB locked
- Smooth animations for state transitions

#### DetailedCalibrationView
- Full-screen overlay with detailed metrics
- Luma bar with target range visualization (0.35-0.65)
- Current luma indicator on bar
- Histogram chart with clipping zones highlighted
- Status summary with color coding

#### HistogramView
- Visual histogram display (256 bars)
- Red highlighting for clipping zones (first/last 5 bins)
- Normalized to max value for visibility

### 4. CameraViewModel Updates (`Features/Camera/CameraViewModel.swift`)

**Added Properties:**
- `@Published var currentMetrics: CalibrationMetrics?`
- `@Published var isCalibrated: Bool`

**Added Methods:**
- `calibrate()` - Locks exposure/WB when conditions are good
- Reset `isCalibrated` when switching cameras or unlocking exposure

**Bindings:**
- Subscribes to `metricsPublisher` with 200ms throttle
- Updates `currentMetrics` on main thread

### 5. CameraView Integration (`Features/Camera/CameraView.swift`)

**UI Integration:**
- CalibrationHUD displayed above camera controls when capturing
- Tap gesture on HUD opens detailed calibration view
- Smooth transitions (move + opacity)
- Automatic state management

**User Flow:**
1. Start camera
2. CalibrationHUD shows real-time status
3. Adjust lighting until status is green
4. Tap "Calibrate" button
5. Exposure and white balance locked
6. "Locked" status displayed
7. Switching camera or unlocking resets calibration

## Performance Considerations

- Metrics computation runs on dedicated queue (QoS: userInitiated)
- 200ms throttle on metrics updates to reduce UI updates
- Histogram computation optimized for BGRA pixel format
- No blocking operations on main thread

## Usage Example

```swift
// In CameraView
CalibrationHUD(
    metrics: viewModel.currentMetrics,
    isCalibrated: viewModel.isCalibrated,
    isExposureLocked: viewModel.isExposureLocked,
    onCalibrate: {
        viewModel.calibrate()
    }
)
```

## File Locations

- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/ModelsKit/CalibrationMetrics.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/CameraKit/CameraSession.swift` (extended)
- `/Users/apple/Desktop/Skin App IOS/Tavi/Shared/UI/CalibrationHUD.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraViewModel.swift` (updated)
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraView.swift` (updated)

## Testing Recommendations

1. Test in various lighting conditions (dark, bright, mixed)
2. Verify red status when too dark/bright
3. Verify yellow status when histogram clips
4. Verify green status in optimal conditions
5. Test calibration lock/unlock cycle
6. Test camera switching resets calibration
7. Verify histogram visualization accuracy
8. Test detailed view with edge cases (all pixels in one bin, etc.)
