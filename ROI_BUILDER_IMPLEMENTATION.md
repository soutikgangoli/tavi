# ROI Builder Implementation

This document describes the Region of Interest (ROI) Builder system added to the Tavi camera app.

## Overview

The ROI Builder computes normalized rectangular regions for facial analysis based on detected landmarks. It identifies specific facial regions (cheeks, forehead, chin) scaled relative to inter-pupil distance (IPD) and face bounds, and provides methods to extract these regions as separate images.

## Components

### 1. ROI Data Models (`Core/ModelsKit/ROIModels.swift`)

#### ROIType Enum
Defines the four primary facial regions:
- `leftCheek` - Left cheek region
- `rightCheek` - Right cheek region
- `foreheadCenter` - Center of forehead
- `chinCenter` - Center of chin

#### FaceROI Struct
Represents a single region of interest:
```swift
public struct FaceROI {
    let type: ROIType
    let normalizedRect: CGRect      // 0-1 relative to face bounds
    let imageRect: CGRect            // Image coordinates
    let scaleFactorIPD: CGFloat      // Scale relative to IPD
    let confidence: Float            // 0-1 quality score
}
```

#### FaceROISet Struct
Collection of all ROIs for one detected face:
```swift
public struct FaceROISet {
    let rois: [ROIType: FaceROI]
    let faceResult: FaceDetectionResult
    let interPupilDistance: CGFloat  // In pixels
    let faceBounds: CGRect           // In image coordinates
}
```

**Convenience accessors:**
- `leftCheek`, `rightCheek`, `foreheadCenter`, `chinCenter`
- `allROIs` - Array of all ROIs

#### ExtractedROIImage Struct
Result of ROI extraction:
```swift
public struct ExtractedROIImage {
    let type: ROIType
    let image: CGImage
    let roi: FaceROI
    var size: CGSize
}
```

#### ROIConfiguration Struct
Configurable parameters for ROI computation:
```swift
public struct ROIConfiguration {
    let sizeRelativeToIPD: CGFloat   // Default: 1.5
    let minimumSize: CGSize           // Default: 50x50
    let maximumSize: CGSize           // Default: 300x300
    let padding: CGFloat              // Default: 0.1 (10%)
}
```

**Presets:**
- `.default` - Standard ROIs (1.5× IPD)
- `.highResolution` - Larger ROIs (2.0× IPD, 512px max)
- `.compact` - Smaller ROIs (1.0× IPD, 200px max)

### 2. ROIBuilder Class (`Core/VisionKit/ROIBuilder.swift`)

Main class for computing and extracting facial ROIs.

#### Initialization
```swift
let roiBuilder = ROIBuilder(configuration: .default)
```

#### ROI Computation

```swift
func computeROIs(
    for faceResult: FaceDetectionResult,
    imageSize: CGSize
) throws -> FaceROISet
```

**Algorithm:**

**1. Inter-Pupil Distance (IPD) Calculation**
- Uses left and right pupils from landmarks
- Computes Euclidean distance in normalized coordinates
- Converts to pixels using face bounds

**2. Left Cheek ROI**
- Position: Left of left pupil, between eye and mouth
- Horizontal: Left pupil - 0.6× IPD
- Vertical: 40% from eye line to mouth center
- Confidence: 0.95 (with eye landmarks), 0.7 (without)

**3. Right Cheek ROI**
- Position: Right of right pupil, between eye and mouth
- Horizontal: Right pupil + 0.6× IPD
- Vertical: 40% from eye line to mouth center
- Confidence: 0.95 (with eye landmarks), 0.7 (without)

**4. Forehead Center ROI**
- Position: Above eyes, horizontally centered
- Horizontal: Midpoint between pupils
- Vertical: Eye line - 1.2× IPD
- Confidence: 0.9

**5. Chin Center ROI**
- Position: Below mouth, horizontally centered
- Horizontal: Midpoint between pupils
- Vertical: Mouth bottom + 0.8× IPD
- Confidence: 0.9 (with good lips), 0.75 (limited lips)

**ROI Sizing:**
- Base size: IPD × `sizeRelativeToIPD` (default 1.5)
- Square regions (width = height)
- Clamped to min/max from configuration
- Padding applied (10% by default)
- Ensured within image bounds

#### Image Extraction

```swift
// Extract from CGImage
func extractROIImages(
    from faceImage: CGImage,
    using roiSet: FaceROISet
) throws -> [ExtractedROIImage]

// Extract from CVPixelBuffer
func extractROIImages(
    from pixelBuffer: CVPixelBuffer,
    using roiSet: FaceROISet
) throws -> [ExtractedROIImage]
```

**Process:**
1. Clamps ROI rectangles to image bounds
2. Rounds to integer coordinates
3. Uses `CGImage.cropping(to:)` for extraction
4. Returns array of `ExtractedROIImage`

#### Coordinate Conversion

```swift
static func convertROIToViewCoordinates(
    _ roi: FaceROI,
    imageSize: CGSize,
    viewSize: CGSize,
    isMirrored: Bool = false
) -> CGRect
```

Handles:
- Mirroring for front camera
- Aspect-fit scaling to view
- Centering in view

### 3. ROI Overlay (`Shared/UI/ROIOverlay.swift`)

SwiftUI visualization system for ROIs.

#### ROIOverlay
Main overlay view:
```swift
ROIOverlay(
    roiSets: [FaceROISet],
    imageSize: CGSize,
    viewSize: CGSize,
    isMirrored: Bool,
    showLabels: Bool
)
```

#### Visual Elements

**ROI Rectangle:**
- Colored border (2pt stroke)
- Corner markers (L-shaped, 12pt)
- Center crosshair (8pt)
- Color-coded by type

**Color Coding:**
- 🔵 **Blue**: Left cheek
- 🔵 **Cyan**: Right cheek
- 🟣 **Purple**: Forehead center
- 🟠 **Orange**: Chin center

**Label:**
- ROI type name
- Confidence percentage
- Positioned above rectangle
- Colored background matching ROI

#### Supporting Views

**ROIInfoPanel:**
- Inter-pupil distance display
- List of all ROIs with dimensions
- Confidence scores
- Scale factors

**ROILegend:**
- Compact color legend
- Shows all ROI types
- Matches overlay colors

**ExtractedROIGrid:**
- Grid layout for extracted ROI images
- Configurable columns (default: 2)
- Cards with image + metadata
- Color-coded borders

### 4. CameraViewModel Integration (`Features/Camera/CameraViewModel.swift`)

#### Added Properties
```swift
@Published var faceROIs: [FaceROISet] = []
@Published var showROIs = false
@Published var extractedROIs: [ExtractedROIImage] = []

private let roiBuilder = ROIBuilder(configuration: .default)
```

#### ROI Computation Pipeline

Integrated into face detection:
```swift
// Compute ROIs if enabled
var roiSets: [FaceROISet] = []
if showROIs, let imageSize = getImageSize() {
    for face in faces {
        if let roiSet = try? roiBuilder.computeROIs(for: face, imageSize: imageSize) {
            roiSets.append(roiSet)
        }
    }
}
```

#### Methods
```swift
func toggleROIs()                      // Toggle ROI visualization
func extractROIsFromCurrentFrame()     // Extract ROI images from frame
```

### 5. CameraView Integration (`Features/Camera/CameraView.swift`)

#### ROI Overlay Display
```swift
if viewModel.showROIs,
   !viewModel.faceROIs.isEmpty,
   let imageSize = viewModel.getImageSize() {
    ROIOverlay(
        roiSets: viewModel.faceROIs,
        imageSize: imageSize,
        viewSize: geometry.size,
        isMirrored: viewModel.currentCameraPosition == .front,
        showLabels: true
    )
}
```

#### UI Controls
- **ROI toggle button** (rectangle.3.group icon)
  - White when off, purple when on
  - Next to face landmarks toggle
- **ROI legend overlay**
  - Positioned in top-right
  - Shows when ROIs enabled

## Usage Examples

### Basic ROI Computation

```swift
let roiBuilder = ROIBuilder()

// Detect face first
let faceDetector = FaceDetector()
let faces = try await faceDetector.detectFaces(in: pixelBuffer)
guard let face = faces.first else { return }

// Compute ROIs
let imageSize = CGSize(width: 1920, height: 1080)
let roiSet = try roiBuilder.computeROIs(for: face, imageSize: imageSize)

print("Inter-pupil distance: \(roiSet.interPupilDistance) px")

// Access specific ROIs
if let leftCheek = roiSet.leftCheek {
    print("Left cheek: \(leftCheek.imageRect)")
    print("Confidence: \(leftCheek.confidence)")
}

if let forehead = roiSet.foreheadCenter {
    print("Forehead: \(forehead.imageRect)")
}
```

### Extract ROI Images

```swift
// Compute ROIs
let roiSet = try roiBuilder.computeROIs(for: face, imageSize: imageSize)

// Extract images from CGImage
let faceImage: CGImage = ...
let extractedROIs = try roiBuilder.extractROIImages(
    from: faceImage,
    using: roiSet
)

// Process each ROI
for extracted in extractedROIs {
    print("\(extracted.type.displayName): \(extracted.size)")

    // Use extracted.image (CGImage)
    let uiImage = UIImage(cgImage: extracted.image)
    // ... process image
}
```

### Extract from Pixel Buffer

```swift
let roiSet = try roiBuilder.computeROIs(for: face, imageSize: imageSize)

// Extract directly from pixel buffer
let extractedROIs = try roiBuilder.extractROIImages(
    from: pixelBuffer,
    using: roiSet
)
```

### Custom Configuration

```swift
// High-resolution ROIs
let config = ROIConfiguration(
    sizeRelativeToIPD: 2.0,
    minimumSize: CGSize(width: 100, height: 100),
    maximumSize: CGSize(width: 512, height: 512),
    padding: 0.15
)

let roiBuilder = ROIBuilder(configuration: config)
```

### Multiple Faces

```swift
// Detect all faces
let faces = try await faceDetector.detectFaces(in: pixelBuffer)

// Compute ROIs for each face
var allROISets: [FaceROISet] = []
for face in faces {
    if let roiSet = try? roiBuilder.computeROIs(for: face, imageSize: imageSize) {
        allROISets.append(roiSet)
    }
}

// Extract all ROIs
var allExtractedROIs: [ExtractedROIImage] = []
for roiSet in allROISets {
    let extracted = try roiBuilder.extractROIImages(from: image, using: roiSet)
    allExtractedROIs.append(contentsOf: extracted)
}

print("Extracted \(allExtractedROIs.count) ROIs from \(faces.count) faces")
```

## ROI Positioning Details

### Coordinate System
- Vision framework uses **bottom-left** origin
- Converted to **top-left** origin for image processing
- Normalized coordinates (0-1) relative to face bounding box
- Image coordinates in pixels

### Scaling Strategy
1. **Measure IPD** in normalized coordinates
2. **Convert to pixels** using face bounds
3. **Calculate ROI size**: IPD × scale factor
4. **Apply constraints**: min/max from configuration
5. **Add padding**: percentage of final size
6. **Clamp to bounds**: ensure within image

### Position Calculations

**Left Cheek:**
```
centerX = leftPupil.x - (0.6 × IPD)
centerY = leftPupil.y + (mouthCenter.y - leftPupil.y) × 0.4
```

**Right Cheek:**
```
centerX = rightPupil.x + (0.6 × IPD)
centerY = rightPupil.y + (mouthCenter.y - rightPupil.y) × 0.4
```

**Forehead:**
```
centerX = (leftPupil.x + rightPupil.x) / 2
centerY = eyeLine.y - (1.2 × IPD)
```

**Chin:**
```
centerX = (leftPupil.x + rightPupil.x) / 2
centerY = mouthBottom.y + (0.8 × IPD)
```

## Performance Characteristics

- **Computation**: O(1) per face (constant time)
- **Memory**: Minimal (only CGRect storage)
- **Extraction**: Fast (native CGImage cropping)
- **Thread-safe**: Can compute ROIs on background queue
- **No copying**: Extraction references original image

## Error Handling

```swift
enum ROIBuilderError: LocalizedError {
    case insufficientLandmarks    // Missing pupils
    case roiComputationFailed     // No ROIs computed
    case extractionFailed         // Image cropping failed
    case imageConversionFailed    // Format conversion failed
}
```

## File Locations

- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/ModelsKit/ROIModels.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/VisionKit/ROIBuilder.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Shared/UI/ROIOverlay.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraViewModel.swift` (updated)
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraView.swift` (updated)

## Testing Recommendations

1. ✅ Test with various face sizes (near/far from camera)
2. ✅ Test with head rotation (roll/yaw/pitch)
3. ✅ Test ROI positioning accuracy
4. ✅ Verify IPD scaling works correctly
5. ✅ Test extraction produces valid images
6. ✅ Test with multiple faces simultaneously
7. ✅ Verify ROIs stay within image bounds
8. ✅ Test with different configurations
9. ✅ Test coordinate conversion for overlay
10. ✅ Verify mirroring for front camera

## Use Cases

**Skin Analysis:**
- Extract cheek regions for color analysis
- Compare left vs right cheek symmetry
- Analyze forehead for shine/texture
- Monitor chin area for acne/blemishes

**Feature Tracking:**
- Track ROI metrics over time
- Compare before/after photos
- Measure changes in specific regions

**Machine Learning:**
- Pre-crop regions for ML models
- Consistent input sizing via IPD scaling
- Training data extraction

## Future Enhancements

- Additional ROI types (nose, temples, jawline)
- Adaptive sizing based on face pose
- ROI quality metrics (blur, lighting, occlusion)
- Temporal smoothing for video
- Custom ROI shapes (ellipses, polygons)
- ROI tracking across frames
- Heatmap visualization
