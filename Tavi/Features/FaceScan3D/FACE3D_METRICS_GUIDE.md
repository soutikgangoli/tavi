# 3D Face Metrics Guide

Complete guide to computing and visualizing 3D skin metrics from unified face meshes and albedo textures.

## Overview

The 3D Face Metrics system analyzes skin characteristics from the unified 3D mesh and baked albedo texture, computing per-region and global metrics for roughness, pigmentation, and luminance.

## Features

- ✅ UV-based ROI system (5 regions: Forehead, Cheeks, Nose, Chin)
- ✅ Roughness proxy from texture high-frequency analysis
- ✅ Pigmentation variance in CIELAB color space
- ✅ Per-ROI and global metrics
- ✅ Heatmap visualizations
- ✅ Interactive results view

## Architecture

```
UnifiedMesh + AlbedoTexture
         ↓
   ROIMaskGenerator (UV-based masks)
         ↓
   ROITextureSampler (Extract pixels per ROI)
         ↓
   ┌──────────────┬──────────────┐
   │              │              │
RoughnessAnalyzer PigmentationAnalyzer
(high-pass)      (CIELAB variance)
   │              │              │
   └──────────────┴──────────────┘
              ↓
     Face3DMetricsAnalyzer
              ↓
      Face3DMetrics
   (per-ROI + global)
              ↓
    MetricsVisualizer
         (heatmaps)
```

## 1. ROI System (UV-Based)

### Face Regions

Five regions defined using canonical ARSCNFaceGeometry UV coordinates:

| ROI | UV Bounds | Coverage |
|-----|-----------|----------|
| Forehead | U: 0.3-0.7, V: 0.7-0.95 | Upper face |
| Left Cheek | U: 0.15-0.45, V: 0.35-0.65 | Left mid-face |
| Right Cheek | U: 0.55-0.85, V: 0.35-0.65 | Right mid-face |
| Nose Bridge | U: 0.4-0.6, V: 0.45-0.7 | Central face |
| Chin | U: 0.35-0.65, V: 0.1-0.35 | Lower face |

### API

```swift
let maskGenerator = ROIMaskGenerator()

// Generate masks from mesh UV coordinates
let masks = maskGenerator.generateROIMasks(
    from: unifiedMesh.textureCoordinates.map { $0.toSIMD() },
    topology: unifiedMesh.triangleIndices
)

// Each mask contains:
// - vertexIndices: Vertices in this ROI
// - triangleIndices: Triangles in this ROI
// - pixelMask: 2D boolean array (texture space)
```

### Texture Sampling

```swift
// Sample texture within ROI mask
let sample = ROITextureSampler.sampleROITexture(
    albedoTexture,
    mask: masks[.forehead]!
)

// Sample contains:
// - pixels: [SIMD3<Float>] RGB colors
// - uvCoordinates: [SIMD2<Float>]
// - pixelCount: Int
```

## 2. Roughness Proxy (Micro-Texture)

Since mesh normals (~1.2k vertices) are too coarse to capture skin pores, we use high-frequency texture energy as a proxy for surface roughness.

### Method: High-Pass Filtering

```
1. Convert RGB to luminance (Y = 0.299R + 0.587G + 0.114B)
2. Apply Gaussian blur (low-pass filter)
3. Compute high-pass: highpass = original - blurred
4. Calculate energy: mean(abs(highpass)) / mean(luminance)
5. Normalize to 0-1 range
```

### API

```swift
let analyzer = RoughnessAnalyzer()

// Compute roughness proxy for ROI sample
let roughness = analyzer.computeRoughnessProxy(sample)

// Returns 0-1 score:
// 0.0 = smooth (no high-frequency detail)
// 1.0 = rough (high texture variation)
```

### Alternative: Laplacian Variance

```swift
// More sensitive to fine details
let roughness = analyzer.computeRoughnessLaplacian(sample)
```

### Configuration

```swift
var config = RoughnessAnalyzer.Configuration()
config.filterRadius = 3           // Pixels for blur
config.normalizationFactor = 10.0 // Scale energy to 0-1

let analyzer = RoughnessAnalyzer(configuration: config)
```

### Interpretation

| Score | Interpretation |
|-------|---------------|
| 0.0 - 0.3 | Smooth, even texture |
| 0.3 - 0.6 | Moderate texture variation |
| 0.6 - 1.0 | Rough, high texture detail |

## 3. Pigmentation Variance (CIELAB)

Analyzes color variation in perceptually-uniform CIELAB space, focusing on A* (green-red) and B* (blue-yellow) channels to detect pigmentation irregularities.

### Method: CIELAB Variance

```
1. Convert sRGB → linear RGB → XYZ → CIELAB
2. Extract A* and B* channels
3. Compute variance for each channel
4. Combine: variance = σ²(A*) × 0.5 + σ²(B*) × 0.5
5. Normalize: index = √variance / 100
```

### API

```swift
let analyzer = PigmentationAnalyzer()

// Compute pigmentation index for ROI sample
let pigmentation = analyzer.computePigmentationIndex(sample)

// Returns 0-1 score:
// 0.0 = uniform pigmentation
// 1.0 = high variation (spots, patches)
```

### Additional Metrics

```swift
// Standard deviation in LAB space (L*, A*, B*)
let stdDev = analyzer.computeLABStandardDeviation(sample)
// Returns SIMD3<Float> with σ for each channel

// Average CIELAB lightness (L*, 0-100)
let lightness = analyzer.computeAverageLightness(sample)
```

### Configuration

```swift
var config = PigmentationAnalyzer.Configuration()
config.varianceNormalization = 100.0  // Scale variance to 0-1
config.aChannelWeight = 0.5           // A* channel weight
config.bChannelWeight = 0.5           // B* channel weight

let analyzer = PigmentationAnalyzer(configuration: config)
```

### Interpretation

| Score | Interpretation |
|-------|---------------|
| 0.0 - 0.3 | Uniform, even skin tone |
| 0.3 - 0.6 | Moderate color variation |
| 0.6 - 1.0 | High pigmentation irregularity |

## 4. Complete Workflow

### Step 1: Compute Metrics

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// After baking texture
await viewModel.bakeTextureFromSequence()

// Compute 3D metrics
let metrics = await viewModel.compute3DMetrics()

if let metrics = metrics {
    print("Global roughness: \(metrics.globalRoughnessProxy)")
    print("Global pigmentation: \(metrics.globalPigmentationIndex)")

    // Per-ROI metrics
    for (roi, roiMetrics) in metrics.roiMetrics {
        print("\(roi.displayName):")
        print("  Roughness: \(roiMetrics.roughnessProxy)")
        print("  Pigmentation: \(roiMetrics.pigmentationIndex)")
        print("  Pixels: \(roiMetrics.pixelCount)")
    }
}
```

### Step 2: Generate Visualizations

```swift
// Visualizations are generated automatically
let roughnessViz = viewModel.getVisualization(for: .roughness)
let pigmentationViz = viewModel.getVisualization(for: .pigmentation)

// Access heatmap images
if let heatmap = roughnessViz?.heatmapImage {
    // Display or save heatmap
}
```

### Step 3: Display Results

```swift
// Use built-in results view
Face3DMetricsResultsView(viewModel: viewModel)

// Features:
// - Global metrics cards
// - Metric type picker (Roughness, Pigmentation, Luminance, Lightness)
// - Interactive heatmap
// - Per-ROI breakdown
// - Export to JSON
```

## Data Structures

### Face3DMetrics

```swift
struct Face3DMetrics {
    let roiMetrics: [FaceROI: ROIMetrics]

    // Global metrics (weighted by pixel count)
    let globalRoughnessProxy: Float
    let globalPigmentationIndex: Float
    let globalAverageLuminance: Float

    // Mesh statistics
    let vertexCount: Int
    let triangleCount: Int
    let textureResolution: CGSize

    // Processing metadata
    let timestamp: TimeInterval
    let processingTime: TimeInterval
}
```

### ROIMetrics

```swift
struct ROIMetrics {
    let roi: FaceROI
    let roughnessProxy: Float         // 0-1
    let pigmentationIndex: Float      // 0-1
    let pixelCount: Int               // Pixels analyzed
    let averageLuminance: Float       // 0-1
    let averageLightness: Float       // CIELAB L* (0-100)
}
```

### MetricVisualization

```swift
struct MetricVisualization {
    let heatmapImage: UIImage?        // Color-coded metric overlay
    let roiBoundaries: [FaceROI: UIBezierPath]
    let legendColors: [Float: UIColor]
}
```

## Visualization

### Heatmap Generation

```swift
let visualizer = MetricsVisualizer()

let viz = visualizer.generateVisualization(
    for: metrics,
    type: .roughness
)

// Color mapping:
// 0.0 (low) → Green
// 0.5 (med) → Yellow
// 1.0 (high) → Red
```

### Custom Colors

```swift
var config = MetricsVisualizer.Configuration()
config.lowValueColor = .blue
config.midValueColor = .white
config.highValueColor = .red
config.overlayAlpha = 0.7

let visualizer = MetricsVisualizer(configuration: config)
```

## Performance

**Processing Time:**
- ROI mask generation: ~50ms (2048x2048 texture)
- Texture sampling: ~100ms (all ROIs)
- Roughness analysis: ~200ms per ROI
- Pigmentation analysis: ~150ms per ROI
- Total metrics computation: **~1-2 seconds**

**Memory:**
- ROI masks: ~20MB (2048x2048 resolution)
- Texture samples: ~5MB per ROI
- Peak memory: ~100MB

All processing runs on background thread - no UI blocking.

## Usage Examples

### Basic Analysis

```swift
// Complete workflow
@StateObject var viewModel = FaceScan3DViewModel()

// 1. Scan
viewModel.startCaptureSequence()

// 2. Finalize + bake
await viewModel.finalizeCapture()
await viewModel.bakeTextureFromSequence()

// 3. Compute 3D metrics
let metrics = await viewModel.compute3DMetrics()

// 4. Display results
Face3DMetricsResultsView(viewModel: viewModel)
```

### Access Specific ROI

```swift
if let foreheadMetrics = viewModel.getMetrics(for: .forehead) {
    print("Forehead roughness: \(foreheadMetrics.roughnessProxy)")
    print("Forehead pigmentation: \(foreheadMetrics.pigmentationIndex)")
}
```

### Export Metrics

```swift
if let metrics = viewModel.face3DMetrics {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let jsonData = try encoder.encode(metrics)

    // Save to file
    let url = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("metrics.json")

    try jsonData.write(to: url)
}
```

### Generate Custom Visualization

```swift
let visualizer = MetricsVisualizer()

// Generate heatmap for pigmentation
let viz = visualizer.generateVisualization(
    for: metrics,
    type: .pigmentation
)

if let heatmap = viz.heatmapImage {
    // Save or display heatmap
    let data = heatmap.pngData()
    try data?.write(to: fileURL)
}
```

## Advanced Configuration

### Custom ROI Bounds

Edit `FaceROI.uvBounds` in Face3DMetrics.swift:

```swift
case .forehead:
    return UVBounds(minU: 0.3, maxU: 0.7, minV: 0.7, maxV: 0.95)
```

### Adjust Roughness Sensitivity

```swift
var config = RoughnessAnalyzer.Configuration()
config.filterRadius = 5              // Larger = smoother
config.normalizationFactor = 15.0    // Higher = more sensitive

let analyzer = RoughnessAnalyzer(configuration: config)
```

### Adjust Pigmentation Weights

```swift
var config = PigmentationAnalyzer.Configuration()
config.aChannelWeight = 0.6  // Emphasize red-green axis
config.bChannelWeight = 0.4  // De-emphasize blue-yellow axis
```

## Troubleshooting

### Low Coverage / Missing ROIs

**Problem:** Some ROIs have 0 pixels

**Causes:**
- UV bounds don't match actual mesh UV layout
- Texture resolution too low
- ROI completely outside face

**Solutions:**
- Check ARSCNFaceGeometry UV layout
- Increase texture resolution (2048+)
- Adjust ROI bounds in FaceROI enum

### All Roughness Values Near Zero

**Problem:** Roughness proxy always ~0

**Causes:**
- Texture too smooth (over-blurred)
- Normalization factor too high
- Low-resolution texture

**Solutions:**
- Check albedo texture quality
- Reduce `normalizationFactor` (try 5.0)
- Increase texture resolution

### Pigmentation Values Too High

**Problem:** All pigmentation indices near 1.0

**Causes:**
- CIELAB conversion artifacts
- Lighting not fully removed
- Variance normalization too aggressive

**Solutions:**
- Verify albedo correction worked
- Increase `varianceNormalization` (try 200.0)
- Check for texture noise

### Slow Processing

**Problem:** Metrics take > 5 seconds

**Causes:**
- High texture resolution (4096x4096)
- Debug mode (not optimized)
- Many ROIs or large samples

**Solutions:**
- Reduce texture resolution to 2048
- Build in Release mode
- Reduce ROI coverage

## Technical Details

### UV Coordinate Convention

ARSCNFaceGeometry uses **top-left origin** UV coordinates:
- U: 0 (left) → 1 (right)
- V: 0 (top) → 1 (bottom)

Note: When rendering, V is often flipped (bottom = 0).

### CIELAB Conversion

sRGB → XYZ → CIELAB pipeline:

1. **sRGB to Linear RGB:**
   ```
   if (sRGB <= 0.04045):
       linear = sRGB / 12.92
   else:
       linear = ((sRGB + 0.055) / 1.055)^2.4
   ```

2. **Linear RGB to XYZ (D65):**
   ```
   X = 0.4124R + 0.3576G + 0.1805B
   Y = 0.2126R + 0.7152G + 0.0722B
   Z = 0.0193R + 0.1192G + 0.9505B
   ```

3. **XYZ to CIELAB:**
   ```
   L* = 116 × f(Y/Yn) - 16
   A* = 500 × (f(X/Xn) - f(Y/Yn))
   B* = 200 × (f(Y/Yn) - f(Z/Zn))

   where f(t) = t^(1/3) if t > (6/29)^3
                else (t / (3×(6/29)^2)) + 4/29
   ```

### High-Pass Filter

Unsharp mask approach:
```
highpass = original - gaussian_blur(original)
```

Gaussian blur approximated with box filter (radius = 3px default).

## 4. Discoloration / Unevenness (Cross-ROI)

Analyzes skin tone uniformity across different face regions by computing variance in LAB color space between ROIs.

### Method: Inter-ROI LAB Variance

```
1. Compute mean LAB color for each ROI
2. Extract L* and A* values from each ROI
3. Compute variance across ROIs:
   - L* variance (lightness uniformity)
   - A* variance (green-red uniformity)
4. Weighted combination:
   variance = σ²(L*) × 0.6 + σ²(A*) × 0.4
5. Normalize: index = √variance / 50.0
```

### API

```swift
let analyzer = DiscolorationAnalyzer()

// Compute LAB mean for each ROI
var roiMeans: [FaceROI: DiscolorationAnalyzer.LABMean] = [:]
for (roi, sample) in roiSamples {
    roiMeans[roi] = analyzer.computeLABMean(sample)
}

// Compute discoloration index (cross-ROI variance)
let discolorationIndex = analyzer.computeDiscolorationIndex(roiMeans)

// Returns 0-1 score:
// 0.0 = uniform tone across face
// 1.0 = high unevenness between regions
```

### Configuration

```swift
var config = DiscolorationAnalyzer.Configuration()
config.lightnessWeight = 0.6    // L* channel weight
config.aChannelWeight = 0.4     // A* channel weight
config.varianceNormalization = 50.0

let analyzer = DiscolorationAnalyzer(configuration: config)
```

### Interpretation

| Score | Interpretation |
|-------|----------------|
| 0.0 - 0.03 | Very uniform skin tone |
| 0.03 - 0.06 | Minor unevenness |
| 0.06 - 0.1 | Noticeable discoloration |
| 0.1+ | Significant uneven tone |

## 5. Specular / Oiliness Proxy

Detects specular highlights (shininess/oiliness) from raw RGB texture using adaptive brightness thresholding.

### Method: Adaptive Percentile Threshold

```
1. Convert ROI pixels to luminance (Y = 0.2126R + 0.7152G + 0.0722B)
2. Compute adaptive threshold using 95th percentile
3. Apply minimum absolute threshold (0.7) to avoid false positives
4. Count bright pixels above threshold
5. Compute ratio = brightPixels / totalPixels
6. Clamp to maximum (0.3)
```

### API

```swift
let analyzer = SpecularAnalyzer()

// Compute specular proxy from raw RGB texture
// NOTE: Use original frames BEFORE albedo correction
let specularProxy = analyzer.computeSpecularProxy(rawSample)

// Returns 0-1 score:
// 0.0 = matte finish (no specular highlights)
// 1.0 = very oily (many specular highlights)
```

### Alternative Methods

```swift
// Method 1: Chromatic contrast
// Detects achromatic (white/gray) highlights
let specular = analyzer.computeSpecularProxyChromatic(rawSample)

// Method 2: Saturation threshold
// Detects low-saturation bright pixels
let specular = analyzer.computeSpecularProxySaturation(rawSample)
```

### Configuration

```swift
var config = SpecularAnalyzer.Configuration()
config.brightnessPercentile = 0.95       // 95th percentile
config.minimumBrightnessThreshold = 0.7  // Absolute minimum
config.maximumSpecularRatio = 0.3        // Clamp upper bound

let analyzer = SpecularAnalyzer(configuration: config)
```

### Interpretation

| Score | Interpretation |
|-------|----------------|
| 0.0 - 0.05 | Matte finish, no oiliness |
| 0.05 - 0.1 | Slight shine |
| 0.1 - 0.2 | Moderate oiliness |
| 0.2+ | Very oily skin |

## 6. Score Mapping (0-10 Scale)

Maps raw metric values (0-1 range) to user-friendly 0-10 scores with configurable thresholds.

### Scoring System

All scores use inverted mapping: **lower raw value = higher score** (better skin quality).

### API

```swift
let scoring = Scoring3D()

// Map individual metrics to scores
let roughnessScore = scoring.mapRoughnessScore(roughnessProxy)
let pigmentationScore = scoring.mapPigmentationScore(pigmentationIndex)
let discolorationScore = scoring.mapDiscolorationScore(discolorationIndex)
let specularScore = scoring.mapSpecularScore(specularProxy)

// Compute overall composite score (weighted average)
let overallScore = scoring.computeOverallScore(
    roughnessScore: roughnessScore,
    pigmentationScore: pigmentationScore,
    discolorationScore: discolorationScore,
    specularScore: specularScore
)

// Get textual interpretation
let interpretation = scoring.interpretScore(overallScore)
// Returns: "Excellent", "Very Good", "Good", "Fair", "Poor", "Very Poor"
```

### Default Thresholds

| Metric | Low Threshold → Score | High Threshold → Score |
|--------|----------------------|------------------------|
| Roughness | 0.10 → 2.0/10 | 0.35 → 9.0/10 |
| Pigmentation | 0.03 → 2.0/10 | 0.15 → 9.0/10 |
| Discoloration | 0.01 → 2.0/10 | 0.06 → 9.0/10 |
| Specular | 0.02 → 2.0/10 | 0.12 → 9.0/10 |

### Linear Interpolation

Values between thresholds are linearly interpolated:

```
If value <= lowThreshold:   score = 10.0 (best)
If value >= highThreshold:  score = 2.0 (worst)
Otherwise:                  score = linear interpolation
```

### Composite Score Weights

```swift
Overall Score =
    0.25 × RoughnessScore +
    0.30 × PigmentationScore +
    0.25 × DiscolorationScore +
    0.20 × SpecularScore (if available)
```

### Configuration

```swift
var config = Scoring3D.Configuration()

// Customize roughness thresholds
config.roughnessLowThreshold = 0.08   // More sensitive
config.roughnessHighThreshold = 0.40  // Less strict

// Customize score range
config.minimumScore = 0.0
config.maximumScore = 10.0
config.lowScoreValue = 1.0   // Worst score
config.highScoreValue = 10.0 // Best score

let scoring = Scoring3D(configuration: config)
```

### Score Interpretation

| Score | Interpretation | Color |
|-------|----------------|-------|
| 9.0 - 10.0 | Excellent | Green |
| 7.0 - 9.0 | Very Good | Light Green |
| 5.0 - 7.0 | Good | Yellow |
| 3.0 - 5.0 | Fair | Orange |
| 1.0 - 3.0 | Poor | Red |
| 0.0 - 1.0 | Very Poor | Dark Red |

## Complete Workflow (Extended)

### Step 1: Compute All Metrics

```swift
@StateObject var viewModel = FaceScan3DViewModel()

// After baking texture
await viewModel.bakeTextureFromSequence()

// Compute 3D metrics (includes scoring automatically)
let metrics = await viewModel.compute3DMetrics()

if let metrics = metrics {
    // Global scores (0-10 range)
    print("Overall Score: \(metrics.overallScore)/10 (\(metrics.scoreInterpretation))")
    print("Smoothness: \(metrics.globalRoughnessScore)/10")
    print("Even Pigmentation: \(metrics.globalPigmentationScore)/10")
    print("Uniform Tone: \(metrics.globalDiscolorationScore)/10")

    if let specularScore = metrics.globalSpecularScore {
        print("Matte Finish: \(specularScore)/10")
    }

    // Global raw metrics (0-1 range)
    print("\nRaw Metrics:")
    print("Roughness: \(metrics.globalRoughnessProxy)")
    print("Pigmentation: \(metrics.globalPigmentationIndex)")
    print("Discoloration: \(metrics.globalDiscolorationIndex)")

    // Per-ROI metrics
    for (roi, roiMetrics) in metrics.roiMetrics {
        print("\n\(roi.displayName):")
        print("  Smoothness Score: \(roiMetrics.roughnessScore)/10")
        print("  Pigmentation Score: \(roiMetrics.pigmentationScore)/10")
        print("  Raw Roughness: \(roiMetrics.roughnessProxy)")
        print("  Raw Pigmentation: \(roiMetrics.pigmentationIndex)")
    }
}
```

### Step 2: Display Results with Scores

```swift
// Use built-in results view (shows scores prominently)
Face3DMetricsResultsView(viewModel: viewModel)

// Features:
// - Overall score (large, prominent display)
// - Individual metric scores (0-10 scale)
// - Color-coded score visualization
// - Raw metrics available in expandable rows
// - Per-ROI score breakdown
```

### Step 3: Enable Specular Analysis (Optional)

```swift
// Configure analyzer to compute specular metrics
var analyzerConfig = Face3DMetricsAnalyzer.Configuration()
analyzerConfig.computeSpecular = true

let analyzer = Face3DMetricsAnalyzer(configuration: analyzerConfig)

// NOTE: Specular analysis requires raw RGB frames
// Ensure you capture frames before albedo correction
```

## Updated Data Structures

### ROIMetrics (Extended)

```swift
struct ROIMetrics {
    // Raw metrics (0-1 range)
    let roughnessProxy: Float
    let pigmentationIndex: Float
    let specularProxy: Float?
    let averageLuminance: Float
    let averageLightness: Float
    let averageAChannel: Float
    let averageBChannel: Float

    // Scores (0-10 range)
    let roughnessScore: Float
    let pigmentationScore: Float
    let specularScore: Float?

    let pixelCount: Int
}
```

### Face3DMetrics (Extended)

```swift
struct Face3DMetrics {
    let roiMetrics: [FaceROI: ROIMetrics]

    // Global raw metrics (0-1 range)
    let globalRoughnessProxy: Float
    let globalPigmentationIndex: Float
    let globalDiscolorationIndex: Float
    let globalSpecularProxy: Float?
    let globalAverageLuminance: Float

    // Global scores (0-10 range)
    let globalRoughnessScore: Float
    let globalPigmentationScore: Float
    let globalDiscolorationScore: Float
    let globalSpecularScore: Float?
    let overallScore: Float
    let scoreInterpretation: String

    // Mesh statistics
    let vertexCount: Int
    let triangleCount: Int
    let textureResolution: CGSize

    // Metadata
    let timestamp: TimeInterval
    let processingTime: TimeInterval
}
```

## Performance (Updated)

**Processing Time:**
- ROI mask generation: ~50ms
- Texture sampling: ~100ms (all ROIs)
- Roughness analysis: ~200ms per ROI
- Pigmentation analysis: ~150ms per ROI
- Discoloration analysis: ~50ms (cross-ROI)
- Specular analysis: ~100ms per ROI (if enabled)
- Score mapping: ~1ms
- **Total: ~1.5-2.5 seconds** (without specular) or **~2.5-3.5 seconds** (with specular)

**Memory:**
- Peak memory: ~120MB (with all metrics)

## Troubleshooting (Extended)

### Discoloration Always Near Zero

**Problem:** Discoloration index always very low (~0.0)

**Causes:**
- All ROIs have similar skin tone (expected for uniform skin)
- Variance normalization too high
- Too few ROIs

**Solutions:**
- Verify ROI LAB means differ across regions
- Reduce `varianceNormalization` (try 30.0)
- Check if this is actually good skin (uniform tone is positive)

### Specular Values Always Zero

**Problem:** Specular proxy always 0.0

**Causes:**
- Using albedo-corrected texture instead of raw RGB
- Brightness percentile too aggressive
- No actual specular highlights in scene

**Solutions:**
- Ensure you're using raw RGB frames (before albedo correction)
- Lower `brightnessPercentile` (try 0.90)
- Reduce `minimumBrightnessThreshold` (try 0.6)
- Verify lighting setup captures specular highlights

### Scores Don't Match Expectations

**Problem:** Scores seem inverted or incorrect

**Causes:**
- Threshold misconfiguration
- Raw metrics out of expected range

**Solutions:**
- Review threshold configuration in Scoring3D
- Log raw metric values vs scores
- Adjust thresholds to match your data distribution

## See Also

- [TEXTURE_MAPPING_GUIDE.md](TEXTURE_MAPPING_GUIDE.md) - Texture capture and baking
- [MULTI_CAPTURE_GUIDE.md](MULTI_CAPTURE_GUIDE.md) - Multi-angle mesh capture
- [README.md](README.md) - FaceScan3D module overview
