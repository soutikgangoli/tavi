# Texture Mapping and Export Guide

Complete guide to capturing, processing, and exporting textured 3D face meshes with the FaceScan3D module.

## Overview

The texture mapping system captures RGB camera frames during the guided scan, applies lighting correction to estimate albedo (lighting-minimized colors), unifies multiple texture samples into a single UV atlas, and exports the result in industry-standard formats.

## Architecture

```
┌──────────────────────────────────────┐
│   FaceScan3DViewModel                │
│   - Orchestrates capture & baking    │
│   - Manages state                    │
└──────────┬───────────────────────────┘
           │
           ├─────► TextureCapture
           │       - Captures RGB frames
           │       - Quality analysis
           │
           ├─────► ImageQualityAnalyzer
           │       - Focus sharpness (Laplacian)
           │       - Exposure score
           │
           ├─────► AlbedoEstimator
           │       - Lambertian correction
           │       - Lighting removal
           │
           ├─────► TextureBaker
           │       - UV unification
           │       - Sample blending
           │       - Inpainting
           │
           └─────► MeshTextureExporter
                   - OBJ + MTL + PNG
                   - glTF 2.0
                   - USDZ
```

## Workflow

### 1. Automatic Texture Capture

During the guided scan, textures are captured automatically at each pose:

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// Start guided scan (texture capture happens automatically)
viewModel.startCaptureSequence()

// After scan completes, texture samples are stored in:
viewModel.currentSequence?.textureSamples
```

**What happens during capture:**
- RGB frame extracted from ARKit camera feed
- Focus sharpness calculated (Laplacian variance)
- Exposure score computed (0-1, 0.5 = ideal)
- Quality guards applied (blur detection, exposure limits)
- Only high-quality samples are stored

**Quality Thresholds:**
- Minimum sharpness: 100 (Laplacian variance)
- Exposure range: 0.2 - 0.8 (avoid under/overexposure)
- Front-facing preference: |yaw| < 15°, |pitch| < 10°

### 2. Albedo Estimation (Lighting Correction)

Remove lighting effects using Lambertian reflectance model:

```swift
let albedoEstimator = AlbedoEstimator()

// For single pixel
let albedoColor = albedoEstimator.estimateAlbedo(
    color: SIMD3<Float>(r, g, b),
    normal: surfaceNormal,
    lightDirection: lightDir,
    lightIntensity: 1000  // lumens
)

// For entire image (simplified, uniform lighting)
let correctedImage = albedoEstimator.processImage(
    image: sourceImage,
    lightDirection: SIMD3<Float>(0, 1, 0.5),  // Above and forward
    lightIntensity: ambientIntensity
)
```

**Lambertian Correction Formula:**
```
albedo = color / (N · L × intensity)
```

Where:
- `N` = surface normal (normalized)
- `L` = light direction (normalized, pointing TO light)
- `intensity` = ambient light intensity (normalized to 1000 lumens)

**Safety Limits:**
- Minimum dot product: 0.1 (avoid division by near-zero)
- Maximum correction factor: 3.0 (avoid amplifying noise)
- Output clamped to [0, 1] range

### 3. Texture Baking (UV Unification)

Bake unified texture atlas from multiple samples:

```swift
// After finalizing capture and merging mesh
await viewModel.finalizeCapture()

// Bake texture from captured samples
let bakeResult = await viewModel.bakeTextureFromSequence()

if let result = bakeResult {
    print("Texture: \(result.textureWidth)x\(result.textureHeight)")
    print("Coverage: \(result.coveragePercentage * 100)%")
    print("Samples used: \(result.sampleCount)")
}
```

**Baking Process:**

**Step 1: Albedo Correction**
- Apply Lambertian correction to all samples
- Remove lighting hotspots and shadows
- Normalize for consistent appearance

**Step 2: Sample Weighting**
- Sharpness weight: 60% (prefer sharp samples)
- Front-facing weight: 30% (prefer centered poses)
- Exposure weight: 10% (slight preference for well-exposed)

**Step 3: UV Rasterization**
- Project each sample onto canonical UV space
- Accumulate weighted color contributions
- Normalize by total weight per pixel

**Step 4: Inpainting (Optional)**
- Fill small gaps (black/transparent pixels)
- Average colors from neighboring pixels
- Default radius: 3 pixels

**Configuration:**

```swift
var config = TextureBaker.Configuration()
config.textureWidth = 2048
config.textureHeight = 2048
config.sharpnessWeight = 0.6
config.frontFacingWeight = 0.3
config.exposureWeight = 0.1
config.enableInpainting = true
config.inpaintingRadius = 3

let baker = TextureBaker(configuration: config)
```

### 4. Export to 3D Formats

Export textured mesh in multiple formats:

```swift
guard let bakeResult = viewModel.bakeResult,
      let metadata = viewModel.generateMetadata() else {
    return
}

// Export as OBJ + MTL + PNG
do {
    let objURL = try viewModel.exportOBJ(
        unifiedMesh: bakeResult.unifiedMesh,
        texture: bakeResult.albedoTexture,
        metadata: metadata
    )
    print("Exported OBJ: \(objURL)")
} catch {
    print("Export failed: \(error)")
}

// Export as glTF 2.0
let gltfURL = try viewModel.exportGLTF(
    unifiedMesh: bakeResult.unifiedMesh,
    texture: bakeResult.albedoTexture,
    metadata: metadata
)

// Export as USDZ (iOS native)
let usdzURL = try viewModel.exportUSDZ(
    unifiedMesh: bakeResult.unifiedMesh,
    texture: bakeResult.albedoTexture,
    metadata: metadata
)
```

## Export Formats

### OBJ + MTL + PNG

Wavefront OBJ format with material and texture:

**Files created:**
- `face_scan_timestamp.obj` - Geometry (vertices, normals, UVs, faces)
- `face_scan_timestamp.mtl` - Material definition
- `face_scan_timestamp.png` - Albedo texture (2048x2048)
- `face_scan_timestamp_metadata.json` - Capture metadata

**OBJ Structure:**
```obj
# Vertices
v -0.045 0.123 -0.342
v -0.044 0.124 -0.341
...

# Texture coordinates
vt 0.123 0.456
vt 0.124 0.457
...

# Normals
vn 0.123 0.456 0.789
vn 0.124 0.457 0.790
...

# Faces (vertex/texcoord/normal)
f 1/1/1 2/2/2 3/3/3
```

**MTL Structure:**
```mtl
newmtl FaceMaterial
Ka 1.0 1.0 1.0
Kd 1.0 1.0 1.0
Ks 0.0 0.0 0.0
Ns 10.0
map_Kd face_scan_timestamp.png
```

**Compatible with:** Blender, Maya, 3ds Max, MeshLab, etc.

### glTF 2.0 + PNG

Modern 3D format with PBR materials:

**Files created:**
- `face_scan_timestamp.gltf` - JSON scene descriptor
- `face_scan_timestamp.bin` - Binary geometry data
- `face_scan_timestamp.png` - Albedo texture
- `face_scan_timestamp_metadata.json` - Capture metadata

**glTF Structure:**
```json
{
  "asset": { "version": "2.0" },
  "scene": 0,
  "scenes": [{ "nodes": [0] }],
  "nodes": [{ "mesh": 0 }],
  "meshes": [{
    "primitives": [{
      "attributes": {
        "POSITION": 0,
        "NORMAL": 1,
        "TEXCOORD_0": 2
      },
      "indices": 3,
      "material": 0
    }]
  }],
  "materials": [{
    "pbrMetallicRoughness": {
      "baseColorTexture": { "index": 0 },
      "metallicFactor": 0.0,
      "roughnessFactor": 1.0
    }
  }]
}
```

**Features:**
- PBR material (non-metallic skin)
- Efficient binary geometry storage
- Industry-standard format

**Compatible with:** Three.js, Unity, Unreal Engine, Babylon.js, etc.

### USDZ (iOS Native)

Apple's Universal Scene Description format:

**Files created:**
- `face_scan_timestamp.usdz` - Complete scene with embedded texture
- `face_scan_timestamp_metadata.json` - Capture metadata

**Features:**
- Native iOS/macOS support
- AR Quick Look compatible
- Embedded textures (no separate files)
- Optimized for Apple devices

**Compatible with:** AR Quick Look, Reality Composer, Xcode, Blender (with plugin)

## Metadata Export

Complete scan information in JSON:

```json
{
  "scanId": "UUID",
  "timestamp": 1698765432,
  "deviceModel": "iPhone 14 Pro",
  "iOSVersion": "17.0",
  "hasTrueDepth": true,
  "totalPoses": 5,
  "captureSteps": ["Center", "Left", "Right", "Up", "Down"],
  "totalDuration": 23.5,
  "headTransforms": [/* 4x4 matrices */],
  "minAmbientIntensity": 800,
  "maxAmbientIntensity": 1200,
  "avgAmbientIntensity": 1000,
  "avgColorTemperature": 6500,
  "minDistance": 0.35,
  "maxDistance": 0.55,
  "avgDistance": 0.45,
  "calibrationPassed": true,
  "lightingCondition": "good",
  "distanceCondition": "good",
  "avgFocusSharpness": 150.2,
  "avgExposureScore": 0.48,
  "textureCoverage": 0.95,
  "processingTime": 5.2
}
```

## API Reference

### Main API Functions

#### `bakeUnifiedTexture(from:samples:)`

Bake unified texture from mesh and samples:

```swift
func bakeUnifiedTexture(
    from unifiedMesh: MergedFaceMesh,
    samples: [PoseSample]
) async -> TextureBakeResult?
```

**Parameters:**
- `unifiedMesh` - Merged geometry from multi-angle capture
- `samples` - Texture samples (RGB frames) from each pose

**Returns:** `TextureBakeResult` with unified mesh and albedo texture

**Processing time:** ~2-5 seconds for 5 samples

#### `bakeTextureFromSequence()`

Convenience method using current sequence:

```swift
func bakeTextureFromSequence() async -> TextureBakeResult?
```

Automatically uses `mergedMesh` and `currentSequence.textureSamples`

#### `exportOBJ(unifiedMesh:texture:metadata:)`

Export as OBJ + MTL + PNG:

```swift
func exportOBJ(
    unifiedMesh: UnifiedMesh,
    texture: CGImage,
    metadata: FaceScanMetadata
) throws -> URL
```

**Returns:** URL to exported `.obj` file

#### `exportGLTF(unifiedMesh:texture:metadata:)`

Export as glTF 2.0:

```swift
func exportGLTF(
    unifiedMesh: UnifiedMesh,
    texture: CGImage,
    metadata: FaceScanMetadata
) throws -> URL
```

**Returns:** URL to exported `.gltf` file

#### `exportUSDZ(unifiedMesh:texture:metadata:)`

Export as USDZ:

```swift
func exportUSDZ(
    unifiedMesh: UnifiedMesh,
    texture: CGImage,
    metadata: FaceScanMetadata
) throws -> URL
```

**Returns:** URL to exported `.usdz` file

#### `generateMetadata()`

Generate scan metadata from current sequence:

```swift
func generateMetadata() -> FaceScanMetadata?
```

**Returns:** Complete metadata with all statistics

### Data Structures

#### `TextureBakeResult`

```swift
struct TextureBakeResult {
    let unifiedMesh: UnifiedMesh
    let albedoTexture: CGImage
    let textureWidth: Int
    let textureHeight: Int
    let sampleCount: Int
    let averageSharpness: Float
    let coveragePercentage: Float
    let processingTime: TimeInterval
}
```

#### `PoseSample`

```swift
struct PoseSample {
    let step: String
    let textureImageData: Data  // PNG
    let imageWidth: Int
    let imageHeight: Int
    let faceTransform: Matrix4x4
    let yaw, pitch, roll: Float
    let ambientIntensity: CGFloat
    let colorTemperature: CGFloat
    let lightDirection: Vector3?
    let distanceFromCamera: Float
    let focusSharpness: Float
    let exposureScore: Float
    let isFrontFacing: Bool
}
```

#### `FaceScanMetadata`

```swift
struct FaceScanMetadata {
    let deviceModel: String
    let iOSVersion: String
    let hasTrueDepth: Bool
    let totalPoses: Int
    let captureSteps: [String]
    let totalDuration: TimeInterval?
    let headTransforms: [Matrix4x4]
    let minAmbientIntensity: CGFloat
    let maxAmbientIntensity: CGFloat
    let avgAmbientIntensity: CGFloat
    let avgColorTemperature: CGFloat
    let minDistance: Float
    let maxDistance: Float
    let avgDistance: Float
    let calibrationPassed: Bool
    let lightingCondition: String
    let distanceCondition: String
    let avgFocusSharpness: Float
    let avgExposureScore: Float
    let textureCoverage: Float
    let processingTime: TimeInterval
}
```

## Complete Usage Example

```swift
import SwiftUI

struct TexturedFaceScanView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @State private var showPreview = false

    var body: some View {
        ZStack {
            // AR Face tracking view
            FaceScan3DView(
                showCalibration: true,
                onCaptureComplete: { _ in
                    // After capture completes, bake texture
                    Task {
                        await bakeAndPreview()
                    }
                }
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showPreview) {
            if let bakeResult = viewModel.bakeResult,
               let metadata = viewModel.generateMetadata() {
                FullMeshPreviewView(
                    bakeResult: bakeResult,
                    metadata: metadata
                )
            }
        }
    }

    func bakeAndPreview() async {
        // Finalize mesh merging
        await viewModel.finalizeCapture()

        // Bake unified texture
        let result = await viewModel.bakeTextureFromSequence()

        if result != nil {
            showPreview = true
        }
    }
}
```

## Best Practices

### 1. Lighting Conditions

**✅ Good lighting:**
- Soft, diffuse light (300-2500 lumens)
- Avoid direct sunlight or harsh shadows
- Indoor lighting with even distribution
- No strong directional lights

**❌ Avoid:**
- Direct sunlight (causes overexposure)
- Dark rooms (underexposure, poor sharpness)
- Strong side lighting (harsh shadows)
- Colored lights (affects color accuracy)

### 2. Capture Quality

**Maximize sharpness:**
- Hold phone steady
- Wait for autofocus to stabilize
- Ensure proper distance (25-70cm)
- Good lighting enables faster shutter

**Prefer front-facing samples:**
- Front view captures most detail
- Side views may have distortion
- System automatically weights samples

### 3. Texture Resolution

**Recommendations:**
- 1024x1024: Preview, low-memory devices
- 2048x2048: Production quality (default)
- 4096x4096: High-end, if needed

**Trade-offs:**
- Higher resolution = better detail
- Higher resolution = longer baking time
- Higher resolution = larger file sizes

### 4. Export Format Selection

**OBJ + MTL:**
- Widely compatible
- Easy to edit in 3D software
- Good for offline rendering

**glTF 2.0:**
- Modern, efficient
- Best for web/game engines
- PBR material support

**USDZ:**
- iOS/macOS native
- AR Quick Look support
- Best for Apple ecosystem

### 5. Quality Guards

System automatically filters bad samples:
- Blur detection (Laplacian < 100)
- Overexposure (brightness > 0.8)
- Underexposure (brightness < 0.2)

**Ensure quality:**
- Good lighting (most important)
- Steady hands
- Proper distance
- Clean camera lens

## Troubleshooting

### Low texture coverage (<80%)

**Causes:**
- Too many samples rejected (quality issues)
- Poor lighting
- Camera focus problems
- Excessive motion blur

**Solutions:**
- Improve lighting conditions
- Hold phone more steadily
- Clean camera lens
- Increase capture distance slightly

### Dark/light patches in texture

**Causes:**
- Inconsistent lighting across poses
- Albedo correction failed
- Shadow cast on face

**Solutions:**
- Use diffuse, even lighting
- Avoid directional lights
- Re-scan in better conditions

### Blurry texture

**Causes:**
- All samples were slightly out of focus
- Poor quality samples used

**Solutions:**
- Ensure autofocus locks before countdown
- Check `avgFocusSharpness` in metadata
- Lower sharpness threshold (not recommended)

### Export failed

**Causes:**
- No bake result available
- Disk space full
- Permission issues

**Solutions:**
- Call `bakeTextureFromSequence()` first
- Check available storage
- Verify app has file write permissions

### Texture seams visible

**Causes:**
- UV discontinuities
- Insufficient sample overlap
- Inpainting disabled

**Solutions:**
- Enable inpainting (`config.enableInpainting = true`)
- Increase inpainting radius
- Capture more intermediate poses

## Performance

**Texture Capture:**
- Per-frame overhead: <5ms
- Quality analysis: ~10-20ms per sample
- No impact on AR tracking

**Albedo Correction:**
- Simple (uniform): ~50ms per 1024x1024 image
- Per-pixel normals: ~200ms per 1024x1024 image

**Texture Baking:**
- 5 samples, 2048x2048: ~2-5 seconds
- 10 samples, 2048x2048: ~5-10 seconds
- Runs on background thread (no UI blocking)

**Export:**
- OBJ: ~50ms
- glTF: ~100ms (includes binary encoding)
- USDZ: ~200-500ms (Model I/O overhead)

## See Also

- [FaceScan3D README](README.md) - Main module documentation
- [MULTI_CAPTURE_GUIDE](MULTI_CAPTURE_GUIDE.md) - Mesh capture and merging
- [CALIBRATION_GUIDE](CALIBRATION_GUIDE.md) - Calibration system
- [Apple ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [glTF 2.0 Specification](https://www.khronos.org/gltf/)
- [Wavefront OBJ Format](https://en.wikipedia.org/wiki/Wavefront_.obj_file)
