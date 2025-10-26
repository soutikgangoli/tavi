# Face Detection & Alignment Implementation

This document describes the face detection and alignment system added to the Tavi camera app.

## Overview

The face detection system uses Apple's Vision framework to detect faces and facial landmarks in real-time from the camera feed. It provides face alignment capabilities (crop + rotate to level eyes) and comprehensive SwiftUI overlays for debugging and visualization.

## Components

### 1. Face Detection Models (`Core/ModelsKit/FaceDetectionModels.swift`)

#### FaceDetectionResult
Contains all information about a detected face:
- `boundingBox: CGRect` - Normalized bounding box (0-1 coordinate space)
- `landmarks: FaceLandmarks` - All detected facial landmarks
- `confidence: Float` - Detection confidence (0-1)
- `roll: CGFloat?` - Head roll angle in degrees
- `yaw: CGFloat?` - Head yaw angle in degrees
- `pitch: CGFloat?` - Head pitch angle in degrees

#### FaceLandmarks
Detailed facial landmark data:
- **Feature regions**: leftEye, rightEye, leftEyebrow, rightEyebrow, nose, noseCrest, medianLine, outerLips, innerLips, faceContour
- **Pupils**: leftPupil, rightPupil (CGPoint)
- **All points**: Combined array of all landmark points

**Helper methods:**
- `eyeAngle() -> CGFloat?` - Calculate angle between eyes (for alignment)
- `eyeCenter() -> CGPoint?` - Calculate center point between eyes
- `eyeDistance() -> CGFloat?` - Calculate distance between eyes

#### AlignedFace
Result of face alignment operation:
- `image: CGImage` - Aligned and cropped face image
- `detectionResult: FaceDetectionResult` - Original detection
- `rotationAngle: CGFloat` - Applied rotation in radians
- `scaleFactor: CGFloat` - Applied scale factor

### 2. FaceDetector (`Core/VisionKit/FaceDetector.swift`)

Main class for face detection and alignment using Vision framework.

#### Detection Methods

```swift
// Detect faces in CVPixelBuffer
func detectFaces(in pixelBuffer: CVPixelBuffer,
                orientation: CGImagePropertyOrientation = .up)
    async throws -> [FaceDetectionResult]

// Detect faces in CGImage
func detectFaces(in image: CGImage,
                orientation: CGImagePropertyOrientation = .up)
    async throws -> [FaceDetectionResult]
```

**Features:**
- Uses `VNDetectFaceLandmarksRequest` (Revision 3)
- Runs on dedicated queue (QoS: userInitiated)
- Returns normalized coordinates (0-1 range)
- Extracts 76 landmark points including pupils

#### Face Alignment Methods

```swift
// Align face from pixel buffer
func alignedFace(from pixelBuffer: CVPixelBuffer,
                faceResult: FaceDetectionResult,
                targetSize: CGSize = CGSize(width: 512, height: 512))
    throws -> AlignedFace?

// Align face from CGImage
func alignedFace(from image: CGImage,
                faceResult: FaceDetectionResult,
                targetSize: CGSize = CGSize(width: 512, height: 512))
    throws -> AlignedFace?
```

**Alignment process:**
1. Calculate eye angle using pupils or eye centers
2. Determine eye center point
3. Create transformation matrix:
   - Translate to make eye center the origin
   - Rotate to level eyes (negative angle)
   - Scale based on desired eye distance (35% of target width)
   - Translate to center of target image
4. Apply transformation and render to new image

**Works with both front and back cameras** - orientation parameter handles mirroring.

#### Coordinate Conversion Helpers

```swift
// Convert normalized Vision coordinates to view coordinates
static func convertFromNormalizedCoordinates(
    _ point: CGPoint,
    imageSize: CGSize,
    viewSize: CGSize,
    isMirrored: Bool = false
) -> CGPoint

// Convert normalized bounding box to view coordinates
static func convertBoundingBox(
    _ box: CGRect,
    imageSize: CGSize,
    viewSize: CGSize,
    isMirrored: Bool = false
) -> CGRect
```

Handles:
- Vision's bottom-left origin → top-left origin
- Mirroring for front camera
- Aspect-fit scaling to view size
- Centering in view

### 3. Face Landmarks Overlay (`Shared/UI/FaceLandmarksOverlay.swift`)

Comprehensive SwiftUI visualization system for facial landmarks.

#### FaceLandmarksOverlay
Main overlay view that displays all detected faces:
```swift
FaceLandmarksOverlay(
    faceResults: [FaceDetectionResult],
    imageSize: CGSize,
    viewSize: CGSize,
    isMirrored: Bool,
    showDebugInfo: Bool
)
```

#### Landmark Visualization

**Color coding:**
- 🟢 **Green**: Bounding box, pupils, eye angle line
- 🟡 **Yellow**: Face contour
- 🔵 **Cyan**: Eyes (closed paths)
- 🔵 **Blue**: Eyebrows
- 🟠 **Orange**: Nose
- 🔴 **Red**: Nose crest
- 🩷 **Pink**: Outer lips (closed path)
- 🟣 **Purple**: Inner lips (closed path)
- ⚪ **White**: Median line

**Features:**
- All landmarks drawn as stroked paths
- Pupils highlighted as filled circles (6pt)
- Eye angle line shows alignment
- Bounding box with confidence percentage
- Debug info overlay with roll/yaw/pitch angles

#### LandmarkLegend
Color-coded legend explaining each landmark type:
```swift
LandmarkLegend()
```

Displays in compact format with line/circle samples.

#### Components
- `BoundingBoxView` - Face bounding box with confidence
- `LandmarksView` - All facial landmarks
- `LandmarkPath` - Individual landmark regions
- `LandmarkPoint` - Individual landmark points
- `EyeAngleLine` - Line between pupils showing alignment
- `DebugInfoView` - Angle information overlay

### 4. CameraViewModel Integration (`Features/Camera/CameraViewModel.swift`)

#### Added Properties

```swift
@Published var detectedFaces: [FaceDetectionResult] = []
@Published var showFaceLandmarks = false
@Published var faceDetectionEnabled = true

private let faceDetector = FaceDetector()
```

#### Face Detection Pipeline

1. Subscribes to camera frame publisher
2. Throttles to 100ms (10 FPS detection)
3. Runs detection asynchronously
4. Updates `detectedFaces` on main thread

```swift
cameraSession.framePublisher
    .receive(on: frameProcessingQueue)
    .throttle(for: .milliseconds(100), scheduler: frameProcessingQueue, latest: true)
    .sink { [weak self] pixelBuffer in
        guard let self = self, self.faceDetectionEnabled else { return }
        self.detectFaces(in: pixelBuffer)
    }
    .store(in: &cancellables)
```

#### Orientation Handling

```swift
let orientation: CGImagePropertyOrientation =
    currentCameraPosition == .front ? .leftMirrored : .right
```

- **Front camera**: `.leftMirrored` - handles mirroring + rotation
- **Back camera**: `.right` - handles device rotation

#### Methods

```swift
func toggleFaceLandmarks() // Toggle landmark visualization
func toggleFaceDetection() // Enable/disable face detection
func getImageSize() -> CGSize? // Get current camera resolution
```

### 5. CameraView Integration (`Features/Camera/CameraView.swift`)

#### Face Landmarks Overlay

```swift
GeometryReader { geometry in
    // Camera preview
    CameraPreviewView(viewModel: viewModel)

    // Face landmarks overlay
    if viewModel.showFaceLandmarks,
       !viewModel.detectedFaces.isEmpty,
       let imageSize = viewModel.getImageSize() {
        FaceLandmarksOverlay(
            faceResults: viewModel.detectedFaces,
            imageSize: imageSize,
            viewSize: geometry.size,
            isMirrored: viewModel.currentCameraPosition == .front,
            showDebugInfo: true
        )
    }
}
```

#### UI Controls

**Top bar additions:**
- Face landmarks toggle button (face.smiling icon)
  - White when off, green when on
  - Only visible when face detection enabled
- Face counter badge
  - Shows "X face(s)" when faces detected
  - Green background

**Legend overlay:**
- Displays landmark color legend when landmarks shown
- Positioned in top-right corner

## Usage Examples

### Basic Face Detection

```swift
let faceDetector = FaceDetector()

// Detect faces in pixel buffer
let faces = try await faceDetector.detectFaces(
    in: pixelBuffer,
    orientation: .up
)

for face in faces {
    print("Confidence: \(face.confidence)")
    print("Bounding box: \(face.boundingBox)")

    if let eyeAngle = face.landmarks.eyeAngle() {
        print("Eye angle: \(eyeAngle * 180 / .pi)°")
    }
}
```

### Face Alignment

```swift
// Detect face
let faces = try await faceDetector.detectFaces(in: pixelBuffer)
guard let face = faces.first else { return }

// Align and crop face
let alignedFace = try faceDetector.alignedFace(
    from: pixelBuffer,
    faceResult: face,
    targetSize: CGSize(width: 512, height: 512)
)

// Use aligned face image
let faceImage = alignedFace.image
print("Rotation applied: \(alignedFace.rotationAngle * 180 / .pi)°")
print("Scale factor: \(alignedFace.scaleFactor)")
```

### Custom Landmark Processing

```swift
let landmarks = face.landmarks

// Get specific features
let leftEyePoints = landmarks.leftEye
let rightEyePoints = landmarks.rightEye
let nosePoints = landmarks.nose

// Calculate eye metrics
if let eyeCenter = landmarks.eyeCenter(),
   let eyeDistance = landmarks.eyeDistance() {
    print("Eye center: \(eyeCenter)")
    print("Eye distance: \(eyeDistance)")
}

// Access pupils
if let leftPupil = landmarks.leftPupil,
   let rightPupil = landmarks.rightPupil {
    print("Left pupil: \(leftPupil)")
    print("Right pupil: \(rightPupil)")
}
```

## Performance Characteristics

- **Detection rate**: ~10 FPS (100ms throttle)
- **Processing queue**: Dedicated queue (QoS: userInitiated)
- **No main thread blocking**: All detection async
- **Memory efficient**: Pixel buffers shared, not copied
- **Vision framework**: Hardware-accelerated on supported devices

## Camera Compatibility

✅ **Front Camera**
- TrueDepth camera support
- Wide angle fallback
- Automatic mirroring
- Orientation: `.leftMirrored`

✅ **Back Camera**
- Wide angle camera
- Dual/Triple camera support
- Orientation: `.right`

## File Locations

- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/ModelsKit/FaceDetectionModels.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/VisionKit/FaceDetector.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Shared/UI/FaceLandmarksOverlay.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraViewModel.swift` (updated)
- `/Users/apple/Desktop/Skin App IOS/Tavi/Features/Camera/CameraView.swift` (updated)

## Testing Recommendations

1. ✅ Test with single face in frame
2. ✅ Test with multiple faces (supports multiple)
3. ✅ Test face alignment at various angles
4. ✅ Test with front camera (mirrored)
5. ✅ Test with back camera (not mirrored)
6. ✅ Test landmark visualization accuracy
7. ✅ Test in different lighting conditions
8. ✅ Test with partially obscured faces
9. ✅ Verify eye angle calculation
10. ✅ Test alignment with rotated faces

## Future Enhancements

- Face tracking (assign IDs to faces across frames)
- Face quality assessment (blur, exposure, occlusion)
- Expression detection
- Age/gender estimation (if needed)
- 3D face mesh (ARKit integration)
- Face comparison/recognition
