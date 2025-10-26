# Tavi - Skin Analysis iOS App

A comprehensive SwiftUI iOS application for advanced facial skin analysis using multi-frame capture, face detection, and deterministic metrics computation.

## Overview

Tavi is a professional-grade skin analysis application that leverages iPhone's camera capabilities, Vision framework, and custom image processing to deliver quantitative skin quality metrics. The app captures multiple frames with blur detection, aligns them by facial landmarks, combines them for noise reduction, and computes deterministic metrics for skin analysis.

## Key Features

### 📸 Advanced Camera System
- Front (TrueDepth preferred) and back camera support
- 4K/1080p @ 30fps capture
- Real-time calibration with exposure/white balance lock
- Live face detection and landmark visualization
- ROI (Region of Interest) overlay and extraction

### 🎯 Multi-Frame Capture
- Captures 5 frames over ~1.5 seconds
- Laplacian variance blur detection
- Automatic sharp frame selection
- Eye-based landmark alignment
- Median combining for noise reduction

### 📊 Deterministic Metrics
- **Blur Score** - Sharpness measurement (0-1)
- **Texture Energy** - High-frequency texture analysis (0-1)
- **LAB Variance** - Pigmentation evenness (0-1)
- **Discoloration Index** - Inter-ROI color variance (0-1)
- **Moisture Proxy** - Specular highlights + smoothness (0-1)

### 🎨 Comprehensive UI
- Real-time camera preview with overlays
- Calibration HUD with visual feedback
- Interactive landmark and ROI visualization
- Progress tracking during capture
- Detailed metrics display with interpretations

## Project Structure

```
Tavi/
├── App/
│   ├── TaviApp.swift                    # Main app entry point
│   └── ContentView.swift                # Root content view
│
├── Features/
│   ├── Camera/
│   │   ├── CameraView.swift            # Main camera UI
│   │   ├── CameraViewModel.swift       # Camera logic and state
│   │   ├── CaptureController.swift     # Multi-frame capture orchestration
│   │   └── CaptureModels.swift         # Capture data structures
│   │
│   └── Results/
│       ├── ResultsView.swift
│       └── ResultsViewModel.swift
│
├── Core/
│   ├── CameraKit/
│   │   ├── CameraSession.swift         # AVFoundation camera management
│   │   └── CameraManager.swift         # Singleton camera manager
│   │
│   ├── VisionKit/
│   │   ├── FaceDetector.swift          # Face detection with Vision
│   │   ├── ROIBuilder.swift            # Facial ROI computation
│   │   ├── ImageProcessing.swift       # Blur, alignment, median combining
│   │   └── VisionAnalyzer.swift        # Placeholder for future analysis
│   │
│   ├── MetricsKit/
│   │   ├── MetricsComputer.swift       # Metrics computation engine
│   │   ├── MetricsModels.swift         # Metrics data structures
│   │   └── MetricsCalculator.swift     # Placeholder
│   │
│   ├── ModelsKit/
│   │   ├── CalibrationMetrics.swift    # Calibration data models
│   │   ├── FaceDetectionModels.swift   # Face detection structures
│   │   ├── ROIModels.swift             # ROI data structures
│   │   └── DataModels.swift            # General data models
│   │
│   └── StorageKit/
│       └── StorageManager.swift        # Data persistence
│
└── Shared/
    └── UI/
        ├── CalibrationHUD.swift        # Calibration overlay
        ├── FaceLandmarksOverlay.swift  # Landmark visualization
        ├── ROIOverlay.swift            # ROI visualization
        ├── CaptureProgressView.swift   # Capture progress UI
        ├── CaptureResultView.swift     # Capture results display
        ├── MetricsResultView.swift     # Metrics analysis display
        ├── PrimaryButton.swift         # Reusable button
        ├── LoadingView.swift           # Loading indicator
        └── CardView.swift              # Card component
```

## Technical Architecture

### Camera Pipeline

```
Camera Session (AVFoundation)
    ↓
Frame Publisher (Combine)
    ↓
Face Detection (Vision)
    ↓
ROI Computation
    ↓
Multi-Frame Capture
    ↓
Blur Analysis (Laplacian)
    ↓
Frame Alignment (Eye Landmarks)
    ↓
Median Combining
    ↓
ROI Extraction
    ↓
Metrics Computation
```

### Metrics Computation

1. **Blur Score** - Laplacian variance normalized to 0-1
2. **Texture Energy** - High-pass filter energy analysis
3. **LAB Variance** - Color variance in perceptual LAB space
4. **Discoloration Index** - Inter-ROI color comparison
5. **Moisture Proxy** - Specular ratio + low-frequency smoothness

### Face ROI Regions

- Left Cheek (blue)
- Right Cheek (cyan)
- Forehead Center (purple)
- Chin Center (orange)

All ROIs scaled relative to inter-pupil distance (IPD) for consistency.

## Implementation Details

### Calibration System
- **Luma Analysis** - Rec. 709 coefficients (0.2126R + 0.7152G + 0.0722B)
- **Histogram Clipping** - Detects overexposure/underexposure
- **Status Indicators** - Red (poor), Yellow (clipped), Green (good)
- **Exposure Lock** - Locks AE and AWB when calibrated

### Face Detection
- **Vision Framework** - VNDetectFaceLandmarksRequest
- **76 Landmarks** - Full facial feature points
- **Alignment** - Eye-based rotation and scaling
- **Coordinate Conversion** - Vision (bottom-left) ↔ UIKit (top-left)

### Blur Detection
- **Laplacian Variance** - 3×3 edge detection kernel
- **Threshold** - Default 100.0 (configurable)
- **Per-Frame Analysis** - Rejects blurry frames automatically

### Image Alignment
- Eye angle calculation: `atan2(dy, dx)`
- Affine transformation: translate → rotate → scale → center
- Target size: 1024×1024 (configurable)

### Median Combining
- Pixel-wise median across aligned frames
- Better edge preservation than averaging
- Removes transient artifacts (blinks, etc.)
- Requires odd number of frames for best results

### LAB Color Space
- Full RGB → XYZ → LAB conversion
- D65 illuminant (standard daylight)
- Gamma correction (sRGB)
- Perceptually uniform distance metric

## Usage Example

```swift
// 1. Start camera
await viewModel.startCapture()

// 2. Calibrate (when conditions are good)
viewModel.calibrate()

// 3. Capture multi-frame image
await viewModel.startMultiFrameCapture()

// 4. View results (automatic)
// - Combined denoised image
// - Extracted ROI images
// - Comprehensive metrics
// - Quality scores and interpretations
```

## Performance

### Multi-Frame Capture (Default Config)
- Frame capture: 1.5s (5 frames)
- Blur processing: ~0.3s
- Alignment: ~0.2s
- Median combining: ~0.1s
- ROI extraction: ~0.05s
- **Total**: ~2.2s

### Metrics Computation (4 ROIs @ 256×256)
- Blur score: ~20ms
- Texture energy: ~60ms
- LAB variance: ~80ms
- Moisture proxy: ~72ms
- Discoloration: ~10ms
- **Total**: ~250ms

### Memory Usage
- 5 frames @ 1920×1080 BGRA: ~40 MB
- Aligned frames @ 1024×1024: ~20 MB
- Combined image: ~4 MB
- Metrics computation: ~8 MB per ROI
- **Peak usage**: ~70 MB

## Configuration

### Capture Configuration
```swift
CaptureConfiguration(
    frameCount: 5,              // Number of frames
    captureDuration: 1.5,       // Total capture time (seconds)
    blurThreshold: 100.0,       // Laplacian variance threshold
    minimumSharpFrames: 3,      // Minimum required sharp frames
    alignedImageSize: CGSize(width: 1024, height: 1024)
)
```

### Metrics Configuration
```swift
MetricsConfiguration(
    minBlur: 50.0, maxBlur: 200.0,
    minTextureEnergy: 0.01, maxTextureEnergy: 0.5,
    minLABVariance: 0.0, maxLABVariance: 50.0,
    specularThreshold: 220,
    smoothnessKernelSize: 15
)
```

## Quality Interpretation

### Overall Quality Score
- **0.8-1.0**: Excellent (green)
- **0.6-0.8**: Good (green)
- **0.4-0.6**: Fair (orange)
- **0.2-0.4**: Poor (orange)
- **0.0-0.2**: Very Poor (red)

### Individual Metrics
- **Blur**: Higher is better (0.7+ = sharp)
- **Texture**: Lower is smoother (0.0-0.2 = very smooth)
- **LAB Variance**: Lower is more even (0.0-0.2 = even pigmentation)
- **Discoloration**: Lower is more uniform (0.0-0.3 = uniform tone)
- **Moisture**: 0.4-0.8 ideal (0.0-0.3 = dry, 0.8-1.0 = oily)

## Documentation

Comprehensive implementation documentation available:

- **CALIBRATION_IMPLEMENTATION.md** - Calibration system details
- **FACE_DETECTION_IMPLEMENTATION.md** - Face detection and alignment
- **ROI_BUILDER_IMPLEMENTATION.md** - ROI computation algorithms
- **CAPTURE_CONTROLLER_IMPLEMENTATION.md** - Multi-frame capture workflow
- **METRICSKIT_IMPLEMENTATION.md** - Metrics computation details
- **METRICSKIT_USAGE_EXAMPLES.md** - Code examples and patterns
- **PROMPT_7_SUMMARY.md** - MetricsKit implementation summary

## Dependencies

- **Swift Algorithms** (v1.2.0+) - Apple's Swift Algorithms package
- **AVFoundation** - Camera capture and media processing
- **Vision** - Face detection and landmark recognition
- **Accelerate** - Image processing optimization (future)
- **Combine** - Reactive data flow
- **SwiftUI** - Declarative UI framework

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.9+
- iPhone with TrueDepth camera (for optimal face detection)
- iPhone 14 Pro or later (for 4K 30fps)

## Permissions

Required permissions in Info.plist:
- **NSCameraUsageDescription** - "Tavi uses the camera for facial skin analysis"
- **NSPhotoLibraryUsageDescription** - "Tavi saves analysis results to Photos"

## Getting Started

1. Clone the repository
2. Open `Tavi.xcodeproj` in Xcode
3. Wait for Swift Package dependencies to resolve
4. Select your target device (physical device recommended)
5. Build and run (⌘R)

## Best Practices

### For Optimal Capture
1. Use front-facing TrueDepth camera
2. Ensure good, even lighting
3. Calibrate before capture (green indicator)
4. Hold device steady during capture
5. Keep face centered and level

### For Accurate Metrics
1. Always use calibrated capture
2. Ensure sharp frames (blur score > 0.5)
3. Use consistent lighting across sessions
4. Compare metrics over time, not absolute values
5. Consider environmental factors (lighting, angle)

## Future Enhancements

### Planned Features
- Temporal analysis (track changes over time)
- GPU acceleration (Metal compute shaders)
- Additional metrics (pore size, wrinkles, redness)
- Recommendations engine based on metrics
- Export functionality (PDF reports, CSV data)
- Cloud sync and multi-device support
- Machine learning for skin type classification

### Optimization Opportunities
- Batch processing for multiple captures
- Adaptive thresholds based on lighting
- Real-time sharpness feedback during capture
- Automatic retry on insufficient quality
- Progressive rendering for large images

## Troubleshooting

### Common Issues

**Camera not starting:**
- Check camera permissions in Settings
- Ensure device has working camera
- Restart app

**No face detected:**
- Ensure face is well-lit and centered
- Remove glasses or accessories if needed
- Try back camera if front camera fails

**All frames blurry:**
- Hold device steady during capture
- Improve lighting conditions
- Clean camera lens
- Lower blur threshold in configuration

**Metrics computation slow:**
- Reduce ROI image size
- Use fewer ROIs
- Process on background thread (already implemented)

## Contributing

This is a demonstration project. For production use, consider:
- Unit tests for all metrics computations
- UI tests for capture workflow
- Performance profiling and optimization
- Accessibility improvements
- Localization support

## License

Copyright © 2025. All rights reserved.

## Acknowledgments

- Apple Vision framework for face detection
- AVFoundation for camera management
- SwiftUI for modern UI development
- CIE LAB color space for perceptual color analysis
