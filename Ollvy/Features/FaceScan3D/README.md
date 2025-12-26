# FaceScan3D Module

Real-time 3D face scanning using ARKit TrueDepth camera with full mesh geometry access, automatic calibration, guided multi-pose capture, advanced mesh merging, and **production-ready texture mapping with export to industry-standard 3D formats**.

## Features

### Core Scanning
- ✅ Real-time face tracking with ARKit
- ✅ TrueDepth camera support (ARFaceTrackingConfiguration)
- ✅ Light estimation enabled
- ✅ Live deforming face mesh display using ARSCNView
- ✅ Full geometry access (vertices, indices, normals, UVs)
- ✅ Blend shape coefficients

### Calibration & Capture
- ✅ **Automatic calibration** (lighting, distance, stability)
- ✅ **Step-by-step guidance** (5 pose capture workflow)
- ✅ **Multi-angle capture** (automatic mesh capture at each pose)
- ✅ **Mesh merging & stitching** (align, merge vertices, average normals)
- ✅ **Countdown timer** for stable capture

### Texture Mapping (NEW)
- ✅ **RGB texture capture** from TrueDepth/RGB camera
- ✅ **Quality analysis** (focus sharpness, exposure detection)
- ✅ **Albedo estimation** with Lambertian correction (lighting removal)
- ✅ **UV unification** (blend multiple samples into single atlas)
- ✅ **Texture baking** (2048x2048 albedo-like texture)
- ✅ **Inpainting** (fill small gaps automatically)

### Export & Sharing
- ✅ **OBJ + MTL + PNG** export (Blender, Maya, 3ds Max compatible)
- ✅ **glTF 2.0 + PNG** export (web, game engines, PBR materials)
- ✅ **USDZ** export (iOS native, AR Quick Look)
- ✅ **Metadata JSON** (device info, lighting stats, quality metrics)
- ✅ **ZIP export** for easy sharing
- ✅ **3D preview** with SceneKit (interactive rotation, wireframe mode)

### Developer Experience
- ✅ SwiftUI-ready view wrapper
- ✅ Complete async/await API
- ✅ Comprehensive documentation

## Requirements

- iPhone X or later (TrueDepth camera)
- iOS 14.0+
- ARKit framework

## Basic Usage

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        FaceScan3DView(
            showDebug: true,
            showMesh: true,
            meshColor: .white,
            wireframeMode: false,
            showCalibration: true, // Enable calibration & guidance
            onGeometryUpdate: { geometry in
                print("Vertices: \(geometry.vertexCount)")
                print("Triangles: \(geometry.triangleCount)")
            },
            onCaptureComplete: { capturedPoses in
                print("Captured \(capturedPoses.count) poses!")
            }
        )
    }
}
```

## Calibration & Guidance System

### Automatic Calibration

Before scanning begins, the system automatically checks:

1. **Lighting Condition**
   - Too Dark (< 300 lux)
   - Too Bright (> 2500 lux)
   - Good (300-2500 lux)

2. **Distance Check**
   - Too Close (< 25cm)
   - Too Far (> 70cm)
   - Good (25-70cm)

3. **Stability Check**
   - Moving (> 1cm movement)
   - Stable (< 1cm movement)

Only when all conditions are "Good" can the user start the guided capture.

### Guided Multi-Pose Capture

The system guides users through 5 poses:

1. **Look Straight** - Face centered (< 5° rotation)
2. **Turn Left** - 15-35° yaw left
3. **Turn Right** - 15-35° yaw right
4. **Look Up** - 10-25° pitch up
5. **Look Down** - 10-25° pitch down

Each pose includes:
- Clear instruction message
- Visual progress indicators
- 3-second countdown when pose is correct
- Haptic feedback on capture
- Automatic advancement to next pose

### User Experience Flow

```
1. User opens FaceScan3DView
   ↓
2. System shows calibration status (lighting, distance, stability)
   ↓
3. When calibrated, "Start Scanning" button appears
   ↓
4. User taps button → guidance begins
   ↓
5. System shows "Please look straight at the camera"
   ↓
6. When pose is correct → 3-second countdown
   ↓
7. Capture! → Move to next pose
   ↓
8. Repeat for all 5 poses
   ↓
9. "Scan Complete!" message
   ↓
10. onCaptureComplete callback with all pose data
```

## Advanced Usage

### Access Captured Pose Data

```swift
FaceScan3DView { capturedPoses in
    // Access each captured pose
    for (step, poseData) in capturedPoses {
        print("Step: \(step.shortName)")
        print("Yaw: \(poseData.yaw)°")
        print("Pitch: \(poseData.pitch)°")
        print("Roll: \(poseData.roll)°")
        print("Vertices: \(poseData.geometry.vertexCount)")

        // Export this pose to OBJ
        let obj = exportPoseToOBJ(poseData.geometry)
        saveToDisk(obj, filename: "face_\(step.shortName).obj")
    }
}
```

### Manual Calibration Control

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// Check calibration status
if viewModel.calibrationState.isCalibrated {
    print("Ready to scan!")
}

// Check individual conditions
print("Lighting: \(viewModel.calibrationState.lighting.message)")
print("Distance: \(viewModel.calibrationState.distance.message)")
print("Stability: \(viewModel.calibrationState.stability.message)")

// Manual guidance control
viewModel.startGuidance()
viewModel.stopGuidance()
viewModel.resetCalibration()
```

### Custom Calibration Thresholds

Modify `CalibrationState.swift` to adjust thresholds:

```swift
// Lighting (in CalibrationState.updateLighting)
if intensity < 300 {  // Adjust minimum
    lighting = .tooDark
} else if intensity > 2500 {  // Adjust maximum
    lighting = .tooBright
}

// Distance (in CalibrationState.updateDistance)
if distance < 0.25 {  // Adjust minimum (meters)
    self.distance = .tooClose
} else if distance > 0.70 {  // Adjust maximum
    self.distance = .tooFar
}

// Stability (in CalibrationState.updateStability)
let stabilityThreshold: Float = 0.01  // Adjust threshold (meters)
```

### Access Geometry Data

```swift
FaceScan3DView { geometry in
    // Access vertex positions
    for vertex in geometry.vertices {
        print("Vertex: \(vertex.x), \(vertex.y), \(vertex.z)")
    }

    // Access triangle indices
    for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
        let i0 = geometry.triangleIndices[i]
        let i1 = geometry.triangleIndices[i + 1]
        let i2 = geometry.triangleIndices[i + 2]
        print("Triangle: \(i0), \(i1), \(i2)")
    }

    // Access normals
    for normal in geometry.normals {
        print("Normal: \(normal)")
    }
}
```

### Custom ViewModel

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// Access data
if let geometry = viewModel.currentGeometry {
    print("Vertex count: \(geometry.vertexCount)")
}

if let light = viewModel.lightEstimation {
    print("Ambient intensity: \(light.ambientIntensity)")
    print("Color temperature: \(light.ambientColorTemperature)K")
}

if let blendShapes = viewModel.blendShapes {
    print("Eye blink left: \(blendShapes.eyeBlinkLeft)")
    print("Jaw open: \(blendShapes.jawOpen)")
}
```

### Export to OBJ

```swift
@StateObject var viewModel = FaceScan3DViewModel()

if let objString = viewModel.exportToOBJ() {
    // Save or share the OBJ file
    try? objString.write(to: fileURL, atomically: true, encoding: .utf8)
}
```

## Architecture

### Models
- `FaceMeshGeometry` - Complete mesh data (vertices, indices, normals, UVs)
- `LightEstimation` - Ambient and directional light data
- `FaceBlendShapes` - 52 blend shape coefficients

### ViewModels
- `FaceScan3DViewModel` - Observable object managing ARKit session state

### Views
- `FaceScan3DView` - SwiftUI wrapper for easy integration
- `ARFaceTrackingViewController` - UIKit controller managing ARSCNView
- `FaceScan3DDemoView` - Example implementation

## Geometry Data

Each `FaceMeshGeometry` contains:

- **vertices**: Array of 3D positions (SIMD3<Float>)
- **triangleIndices**: Triangle connectivity (Int32)
- **normals**: Per-vertex normals (SIMD3<Float>)
- **textureCoordinates**: UV coordinates (SIMD2<Float>)
- **transform**: 4x4 transform matrix
- **timestamp**: Capture time

Typical mesh contains ~1,200 vertices and ~2,300 triangles.

## Performance

- Runs at 60 FPS on iPhone 12 Pro and later
- ~30 FPS on iPhone X/XS
- Geometry updates every frame
- Light estimation updates in real-time

## Privacy

Requires camera permission. Info.plist must include:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for 3D face scanning</string>
```

## Multi-Capture API

### Start Sequence

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// Start capture sequence
viewModel.startCaptureSequence()
```

### Manual Capture (Optional)

```swift
// Capture current frame
if viewModel.captureStep() {
    print("Captured!")
}
```

### Finalize and Merge

```swift
Task {
    if let merged = await viewModel.finalizeCapture() {
        print("Vertices: \(merged.vertices.count)")
        print("Triangles: \(merged.triangleIndices.count / 3)")
    }
}
```

### Export

```swift
// Export as JSON
let jsonData = try viewModel.exportMergedMesh(format: .json)

// Export as Binary
let binaryData = try viewModel.exportMergedMesh(format: .binary)

// Export as OBJ
let objData = try viewModel.exportMergedMesh(format: .obj)

// Save to file
let url = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first!.appendingPathComponent("face_scan.obj")

try objData.write(to: url)
```

## Texture Mapping & Export (NEW)

### Complete Textured Scan Workflow

```swift
import SwiftUI

struct TexturedFaceScanView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @State private var showPreview = false
    @State private var showExportOptions = false

    var body: some View {
        ZStack {
            FaceScan3DView(
                showCalibration: true,
                onCaptureComplete: { _ in
                    Task { await processCapture() }
                }
            )
            .environmentObject(viewModel)

            if viewModel.isBaking {
                ProgressView("Baking texture...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showPreview) {
            if let result = viewModel.bakeResult,
               let metadata = viewModel.generateMetadata() {
                FullMeshPreviewView(
                    bakeResult: result,
                    metadata: metadata
                )
            }
        }
    }

    func processCapture() async {
        // 1. Finalize mesh merging
        await viewModel.finalizeCapture()

        // 2. Bake unified texture (automatic albedo correction)
        let result = await viewModel.bakeTextureFromSequence()

        if result != nil {
            print("✅ Texture baked: \(result!.textureWidth)x\(result!.textureHeight)")
            print("   Coverage: \(Int(result!.coveragePercentage * 100))%")
            showPreview = true
        }
    }
}
```

### Export to 3D Formats

```swift
// Generate metadata
guard let metadata = viewModel.generateMetadata(),
      let result = viewModel.bakeResult else {
    return
}

// Export as OBJ + MTL + PNG (for Blender, Maya)
do {
    let objURL = try viewModel.exportOBJ(
        unifiedMesh: result.unifiedMesh,
        texture: result.albedoTexture,
        metadata: metadata
    )
    print("Exported to: \(objURL.path)")
} catch {
    print("Export failed: \(error)")
}

// Export as glTF 2.0 (for web, game engines)
let gltfURL = try viewModel.exportGLTF(
    unifiedMesh: result.unifiedMesh,
    texture: result.albedoTexture,
    metadata: metadata
)

// Export as USDZ (for iOS AR Quick Look)
let usdzURL = try viewModel.exportUSDZ(
    unifiedMesh: result.unifiedMesh,
    texture: result.albedoTexture,
    metadata: metadata
)
```

### 3D Preview with Export

```swift
// Built-in preview view with export options
if let result = viewModel.bakeResult,
   let metadata = viewModel.generateMetadata() {
    FullMeshPreviewView(
        bakeResult: result,
        metadata: metadata
    )
}

// Features:
// - Interactive 3D rotation
// - Wireframe mode toggle
// - Export to OBJ/glTF/USDZ
// - Share as ZIP
```

### Share Export Folder

```swift
// Create and share ZIP of entire export
let exportDir = /* directory from export */
let zipURL = try ExportManager.zipExportDirectory(exportDir)

// Present share sheet
ExportResultView(exportURL: exportDir)
```

### Texture Quality Metrics

```swift
if let result = viewModel.bakeResult {
    print("Texture size: \(result.textureWidth)x\(result.textureHeight)")
    print("Samples used: \(result.sampleCount)")
    print("Avg sharpness: \(result.averageSharpness)")
    print("UV coverage: \(Int(result.coveragePercentage * 100))%")
    print("Processing time: \(result.processingTime)s")
}

if let metadata = viewModel.generateMetadata() {
    print("\nCapture stats:")
    print("Lighting: \(metadata.avgAmbientIntensity) lumens")
    print("Distance: \(metadata.avgDistance)m")
    print("Sharpness: \(metadata.avgFocusSharpness)")
    print("Exposure: \(metadata.avgExposureScore)")
}
```

### Quality Guards

Texture capture automatically filters bad samples:
- **Focus check:** Laplacian variance > 100 (sharpness)
- **Exposure check:** 0.2 < brightness < 0.8
- **Preference:** Front-facing poses (|yaw| < 15°, |pitch| < 10°)

### Export Files Structure

Each export creates a timestamped folder:

```
FaceScan_1698765432/
├── face_scan_1698765432.obj        # Geometry
├── face_scan_1698765432.mtl        # Material
├── face_scan_1698765432.png        # Albedo texture (2048x2048)
└── face_scan_1698765432_metadata.json  # Scan metadata
```

Or for glTF:

```
FaceScan_1698765432/
├── face_scan_1698765432.gltf       # Scene JSON
├── face_scan_1698765432.bin        # Binary geometry
├── face_scan_1698765432.png        # Texture
└── face_scan_1698765432_metadata.json
```

### Performance

- Texture capture: < 5ms per frame (no tracking impact)
- Quality analysis: ~10-20ms per sample
- Texture baking: ~2-5 seconds (5 samples, 2048x2048)
- Export OBJ: ~50ms
- Export glTF: ~100ms
- Export USDZ: ~200-500ms

## See Also

- [Texture Mapping Guide](TEXTURE_MAPPING_GUIDE.md) - **Complete texture capture, albedo estimation, and export documentation**

- [Multi-Capture Guide](MULTI_CAPTURE_GUIDE.md) - Complete multi-angle capture documentation
- [Calibration Guide](CALIBRATION_GUIDE.md) - Calibration and guidance system
- [Usage Examples](USAGE_EXAMPLE.swift) - Code examples
- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [ARFaceTrackingConfiguration](https://developer.apple.com/documentation/arkit/arfacetrackingconfiguration)
- [ARSCNView](https://developer.apple.com/documentation/arkit/arscnview)
