# Lighting Normalization Design Document

## Executive Summary

This document specifies a robust approach to minimize score drift across lighting types (tube light, warm bulb, CFL, daylight) while maintaining scientific honesty about limitations.

**Core Strategy:**
1. **Lock camera settings** during capture (exposure, white balance, focus)
2. **Enforce capture protocol** with real-time quality feedback
3. **Chromatic adaptation** to D65 before LAB conversion (Bradford transform)
4. **Gate lighting-sensitive metrics** with confidence scoring
5. **Transparent UI** that shows quality scores and suppresses unreliable metrics

---

## 1. Metric Classification by Lighting Sensitivity

### Category A: Normalizable (High Confidence After Chromatic Adaptation)

| Metric | Sensitivity | Normalization Strategy | Expected Stability |
|--------|-------------|------------------------|-------------------|
| **Pigmentation** | Moderate | D65 chromatic adaptation → LAB variance | ±5% across illuminants |
| **Discoloration** | Moderate | D65 chromatic adaptation → LAB variance | ±5% across illuminants |
| **Texture/Roughness** | Low | Ratio-based (high-freq/mean), no color | ±3% across illuminants |
| **Pores** | Low | Texture-based, contrast-normalized | ±3% across illuminants |

**Rationale**: These metrics use color variance or texture ratios, which are relatively stable after chromatic adaptation removes color cast.

### Category B: Lighting-Dependent (Must Gate with Quality/Confidence)

| Metric | Sensitivity | Why Unfixable | Gating Strategy |
|--------|-------------|---------------|-----------------|
| **Specular/Oiliness** | Very High | Requires specific highlight angles | Gate if lighting uniformity < 0.7 |
| **Hydration** | High | Proxy via moisture inference | Already low confidence (50-70%) |
| **Acne (3D bumps)** | High | Needs shadow gradients to detect relief | Gate if lighting uniformity < 0.6 |
| **Wrinkles/Fine Lines** | Very High | Shadow-dependent depth perception | Gate if lighting uniformity < 0.6 |

**Rationale**: These metrics fundamentally depend on lighting geometry (highlight positions, shadow directions) which cannot be normalized post-capture.

### Category C: Moderately Sensitive (Normalize + Confidence Penalty)

| Metric | Sensitivity | Strategy | Confidence Adjustment |
|--------|-------------|----------|----------------------|
| **Smoothness** | Moderate | Texture contrast + exposure normalization | -10% if exposure < 0.6 or > 0.9 |
| **Redness** | Moderate | D65 adaptation + A* channel threshold | -15% if color cast > 0.1 |

**Rationale**: Can be partially normalized but still affected by lighting quality. Report with reduced confidence.

---

## 2. Lighting Normalization Pipeline

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  CAPTURE STAGE (AVFoundation)                               │
│  - Lock exposure at 50% gray target                         │
│  - Lock white balance (fixed gains or auto-lock)            │
│  - Lock focus at face distance (~40cm)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  QUALITY ASSESSMENT (GPU - Metal)                           │
│  - Exposure score (histogram analysis)                      │
│  - Clipping detection (% saturated pixels)                  │
│  - Color cast estimation (gray world vs neutral)            │
│  - Lighting uniformity (gradient magnitude)                 │
│  - Sharpness (edge energy)                                  │
│  → Overall scan quality: 0-1                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  CHROMATIC ADAPTATION (GPU - Metal)                         │
│  - Estimate scene illuminant (gray world + reference)       │
│  - sRGB → linear RGB                                        │
│  - Bradford transform: source illuminant → D65              │
│  - linear RGB → sRGB                                        │
│  → Color-normalized texture                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  ANALYSIS STAGE (Existing Pipeline)                         │
│  - PigmentationAnalyzer (uses D65-normalized LAB)           │
│  - DiscolorationAnalyzer (uses D65-normalized LAB)          │
│  - RoughnessAnalyzer (unaffected - uses luminance ratios)  │
│  - SpecularAnalyzer (gated by quality.uniformity)           │
│  → Per-metric indices + confidence scores                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  SCORING + CONFIDENCE (CPU - Scoring3D)                     │
│  - Map indices to scores (existing logic)                   │
│  - Compute per-metric confidence based on scan quality      │
│  - Gate metrics below confidence threshold (0.5)            │
│  → Final scores with confidence levels                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 Chromatic Adaptation to D65 (Bradford Transform)

**Where to implement**: GPU (Metal shader) - runs before texture sampling

**Algorithm**:
```
1. Estimate scene illuminant XYZ (gray world assumption or reference patch)
2. Convert sRGB pixel to linear RGB
3. Apply Bradford adaptation matrix: source → D65
4. Convert back to sRGB
5. Feed normalized texture to analyzers
```

**Bradford Transform**:
```
M_Bradford = [ 0.8951  0.2664 -0.1614 ]
             [-0.7502  1.7135  0.0367 ]
             [ 0.0389 -0.0685  1.0296 ]

Adaptation:
  LMS_src = M_Bradford × XYZ_src_illuminant
  LMS_D65 = M_Bradford × XYZ_D65
  LMS_pixel_src = M_Bradford × XYZ_pixel

  LMS_pixel_adapted = LMS_pixel_src × (LMS_D65 / LMS_src)  [component-wise]

  XYZ_adapted = M_Bradford^-1 × LMS_pixel_adapted
```

**Simplified for sRGB workflow**:
```metal
// In linear RGB space:
vec3 adapt_to_D65(vec3 linear_rgb, vec3 src_illuminant_XYZ) {
    // Source illuminant LMS
    vec3 src_LMS = M_Bradford * src_illuminant_XYZ;

    // D65 LMS
    vec3 D65_XYZ = vec3(0.95047, 1.00000, 1.08883);
    vec3 D65_LMS = M_Bradford * D65_XYZ;

    // Adaptation gain
    vec3 gain = D65_LMS / src_LMS;

    // Transform pixel to LMS, scale, transform back
    vec3 pixel_XYZ = sRGB_to_XYZ(linear_rgb);
    vec3 pixel_LMS = M_Bradford * pixel_XYZ;
    vec3 adapted_LMS = pixel_LMS * gain;
    vec3 adapted_XYZ = M_Bradford_inv * adapted_LMS;

    return XYZ_to_sRGB(adapted_XYZ);
}
```

**Illuminant Estimation**:
- **Gray World Assumption**: Average RGB of face region should be neutral gray
- **Reference Patch**: If user holds color calibration card, use known patch
- **Hybrid**: Combine gray world with skin tone prior (skin should be in narrow hue range)

---

## 3. Scan Quality Scoring Function

### 3.1 Component Scores (Each 0-1)

#### A. Exposure Score
```swift
func computeExposureScore(_ histogram: [Float]) -> Float {
    // Histogram: 256 bins, normalized to [0, 1]

    // Target: mean luminance around 0.4-0.6 (40-60% gray)
    let meanLuminance = weightedMean(histogram)
    let exposureDeviation = abs(meanLuminance - 0.5)

    // Penalty for under/over exposure
    let exposureScore = max(0, 1.0 - (exposureDeviation * 3.0))

    return exposureScore
}
```

**Thresholds**:
- Mean luminance 0.45-0.55: score = 1.0 (excellent)
- Mean luminance 0.30-0.70: score = 0.5-1.0 (acceptable)
- Mean luminance < 0.30 or > 0.70: score < 0.5 (poor)

#### B. Clipping Score
```swift
func computeClippingScore(_ pixels: [SIMD3<Float>]) -> Float {
    var clippedPixels = 0

    for pixel in pixels {
        // Check if any channel is clipped (>0.95 or <0.05)
        if pixel.x > 0.95 || pixel.y > 0.95 || pixel.z > 0.95 ||
           pixel.x < 0.05 || pixel.y < 0.05 || pixel.z < 0.05 {
            clippedPixels += 1
        }
    }

    let clippingRatio = Float(clippedPixels) / Float(pixels.count)

    // Penalty for clipping
    return max(0, 1.0 - (clippingRatio * 20.0))
}
```

**Thresholds**:
- < 1% clipped pixels: score = 1.0 (excellent)
- 1-5% clipped: score = 0.8-1.0 (acceptable)
- > 5% clipped: score < 0.8 (poor)

#### C. Color Cast Score
```swift
func computeColorCastScore(_ pixels: [SIMD3<Float>]) -> Float {
    // Compute mean RGB
    var rSum: Float = 0, gSum: Float = 0, bSum: Float = 0
    for pixel in pixels {
        rSum += pixel.x
        gSum += pixel.y
        bSum += pixel.z
    }

    let count = Float(pixels.count)
    let meanR = rSum / count
    let meanG = gSum / count
    let meanB = bSum / count

    // Expected for neutral skin: slight red/yellow bias
    // Compute deviation from expected skin chromaticity
    let skinExpected = SIMD3<Float>(0.65, 0.55, 0.45)  // Warm neutral

    let castMagnitude = length(SIMD3<Float>(meanR, meanG, meanB) - skinExpected)

    // Penalty for strong color cast
    return max(0, 1.0 - (castMagnitude * 3.0))
}
```

**Thresholds**:
- Cast < 0.1: score = 1.0 (neutral)
- Cast 0.1-0.2: score = 0.7-1.0 (slight cast, acceptable)
- Cast > 0.2: score < 0.7 (strong cast, poor)

#### D. Lighting Uniformity Score
```swift
func computeUniformityScore(_ pixels: [SIMD3<Float>], width: Int, height: Int) -> Float {
    // Compute luminance gradient magnitude
    var gradientMagnitudes: [Float] = []

    for y in 1..<(height-1) {
        for x in 1..<(width-1) {
            let idx = y * width + x
            let center = Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx])

            // Sobel gradient
            let gx = (Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx+1]) -
                      Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx-1])) / 2.0
            let gy = (Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx+width]) -
                      Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx-width])) / 2.0

            let gradMag = sqrt(gx*gx + gy*gy)
            gradientMagnitudes.append(gradMag)
        }
    }

    // Mean gradient indicates shadow/lighting non-uniformity
    let meanGradient = gradientMagnitudes.reduce(0, +) / Float(gradientMagnitudes.count)

    // High gradient = shadows/harsh lighting
    return max(0, 1.0 - (meanGradient * 10.0))
}
```

**Thresholds**:
- Mean gradient < 0.05: score = 1.0 (uniform)
- Mean gradient 0.05-0.10: score = 0.7-1.0 (moderate shadows)
- Mean gradient > 0.10: score < 0.7 (harsh shadows)

#### E. Sharpness Score
```swift
func computeSharpnessScore(_ pixels: [SIMD3<Float>], width: Int, height: Int) -> Float {
    // Laplacian edge energy (higher = sharper)
    var edgeEnergy: Float = 0

    for y in 1..<(height-1) {
        for x in 1..<(width-1) {
            let idx = y * width + x
            let center = Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx])

            // Laplacian kernel
            let laplacian = abs(
                4 * center -
                Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx-1]) -
                Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx+1]) -
                Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx-width]) -
                Luminance.bt709LuminanceSRGB01(rgb01: pixels[idx+width])
            )

            edgeEnergy += laplacian
        }
    }

    let meanEdgeEnergy = edgeEnergy / Float((width-2) * (height-2))

    // Map to 0-1 (empirical range: 0.05-0.20 for good sharpness)
    let sharpnessScore = min(1.0, meanEdgeEnergy / 0.15)

    return sharpnessScore
}
```

**Thresholds**:
- Edge energy > 0.15: score = 1.0 (sharp)
- Edge energy 0.08-0.15: score = 0.5-1.0 (acceptable)
- Edge energy < 0.08: score < 0.5 (blurry)

### 3.2 Overall Scan Quality Score

```swift
struct ScanQualityMetrics {
    let exposure: Float       // 0-1
    let clipping: Float       // 0-1
    let colorCast: Float      // 0-1
    let uniformity: Float     // 0-1
    let sharpness: Float      // 0-1

    // Weighted composite (higher weights for critical factors)
    var overall: Float {
        return exposure * 0.25 +
               clipping * 0.20 +
               colorCast * 0.15 +
               uniformity * 0.25 +
               sharpness * 0.15
    }

    var isAcceptable: Bool {
        // All components above minimum AND overall > 0.6
        return exposure > 0.5 &&
               clipping > 0.7 &&
               colorCast > 0.5 &&
               uniformity > 0.5 &&
               sharpness > 0.5 &&
               overall > 0.6
    }
}
```

**Quality Tiers**:
- **Excellent** (overall > 0.85): All metrics high confidence
- **Good** (overall 0.70-0.85): Most metrics high confidence, some moderate
- **Acceptable** (overall 0.60-0.70): Reduced confidence, some metrics gated
- **Poor** (overall < 0.60): Require rescan, most metrics unreliable

---

## 4. UI Confidence Reflection

### 4.1 Per-Metric Confidence Computation

```swift
func computeMetricConfidence(
    metric: SkinMetric,
    scanQuality: ScanQualityMetrics
) -> Float {

    switch metric {
    case .pigmentation, .discoloration:
        // Requires good color cast and exposure
        return min(scanQuality.colorCast, scanQuality.exposure)

    case .texture, .roughness, .pores:
        // Requires sharpness and uniformity
        return min(scanQuality.sharpness, scanQuality.uniformity)

    case .specular, .oiliness:
        // Very sensitive to lighting uniformity
        return scanQuality.uniformity > 0.7 ? scanQuality.uniformity : 0.0

    case .acne, .wrinkles:
        // Requires uniform lighting and sharpness
        return scanQuality.uniformity > 0.6 ?
               min(scanQuality.uniformity, scanQuality.sharpness) : 0.0

    case .hydration:
        // Already low confidence proxy
        return 0.6 * scanQuality.overall

    case .smoothness:
        // Moderate sensitivity
        return scanQuality.overall * 0.85

    default:
        return scanQuality.overall
    }
}
```

### 4.2 UI Display Rules

**Confidence Thresholds**:
```swift
enum ConfidenceLevel {
    case high       // > 0.75 - Show normally
    case moderate   // 0.50-0.75 - Show with warning icon
    case low        // 0.25-0.50 - Gray out, show "?"
    case unreliable // < 0.25 - Hide completely
}

func displayStrategy(confidence: Float) -> ConfidenceLevel {
    if confidence > 0.75 { return .high }
    else if confidence > 0.50 { return .moderate }
    else if confidence > 0.25 { return .low }
    else { return .unreliable }
}
```

**UI Implementation**:
```swift
struct MetricCardView: View {
    let metric: SkinMetric
    let score: Float
    let confidence: Float

    var body: some View {
        let level = displayStrategy(confidence: confidence)

        switch level {
        case .high:
            // Normal display
            MetricCard(title: metric.name, score: score, opacity: 1.0)

        case .moderate:
            // Show with warning
            MetricCard(title: metric.name, score: score, opacity: 0.85)
                .overlay(WarningBadge(text: "Moderate confidence"))

        case .low:
            // Grayed out with question mark
            MetricCard(title: metric.name, score: "?", opacity: 0.5)
                .overlay(InfoIcon(text: "Poor lighting quality"))

        case .unreliable:
            // Hide completely
            EmptyView()
        }
    }
}
```

**Scan Quality Indicator (Live Feedback)**:
```swift
struct ScanQualityIndicator: View {
    let quality: ScanQualityMetrics

    var color: Color {
        if quality.overall > 0.85 { return .green }
        else if quality.overall > 0.70 { return .yellow }
        else if quality.overall > 0.60 { return .orange }
        else { return .red }
    }

    var message: String {
        if quality.exposure < 0.5 { return "Adjust brightness" }
        else if quality.clipping < 0.7 { return "Too bright - avoid direct light" }
        else if quality.colorCast < 0.5 { return "Strong color cast detected" }
        else if quality.uniformity < 0.5 { return "Shadows detected - use diffuse light" }
        else if quality.sharpness < 0.5 { return "Hold steady" }
        else if quality.overall < 0.6 { return "Lighting quality low" }
        else if quality.overall < 0.85 { return "Lighting OK - can improve" }
        else { return "Excellent lighting!" }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)

            Text(message)
                .font(.subheadline)

            Text("\(Int(quality.overall * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

---

## 5. Implementation Code

### 5.1 Lock Camera Settings During Capture

```swift
// File: Tavi/Features/FaceScan3D/Camera/CameraController.swift

extension CameraController {

    /// Lock camera settings for consistent capture
    /// Call this when user is ready to scan
    func lockCameraSettings() throws {
        guard let device = captureDevice else {
            throw CameraError.deviceUnavailable
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // 1. Lock Exposure
        if device.isExposureModeSupported(.locked) {
            // First, let exposure converge to target
            device.exposureMode = .continuousAutoExposure

            // Wait for stable exposure (in practice, monitor with KVO)
            // Then lock current exposure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let device = self.captureDevice else { return }

                try? device.lockForConfiguration()
                device.exposureMode = .locked
                device.unlockForConfiguration()

                print("✅ Exposure locked at: \(device.exposureDuration), ISO: \(device.iso)")
            }
        } else {
            // Fallback: use custom exposure if supported
            if device.isExposureModeSupported(.custom) {
                let targetDuration = CMTime(value: 1, timescale: 60) // 1/60s
                let targetISO: Float = 200

                device.setExposureModeCustom(
                    duration: targetDuration,
                    iso: targetISO,
                    completionHandler: { _ in
                        print("✅ Custom exposure set: 1/60s, ISO 200")
                    }
                )
            }
        }

        // 2. Lock White Balance
        if device.isWhiteBalanceModeSupported(.locked) {
            // Option A: Lock current auto white balance
            device.whiteBalanceMode = .continuousAutoWhiteBalance

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let device = self.captureDevice else { return }

                try? device.lockForConfiguration()
                device.whiteBalanceMode = .locked
                device.unlockForConfiguration()

                print("✅ White balance locked at: \(device.deviceWhiteBalanceGains)")
            }
        } else {
            // Option B: Set fixed white balance gains (D65 approximation)
            let d65Gains = AVCaptureDevice.WhiteBalanceGains(
                redGain: 1.8,    // Typical for D65
                greenGain: 1.0,
                blueGain: 1.6
            )

            device.setWhiteBalanceModeLocked(
                with: d65Gains,
                completionHandler: { _ in
                    print("✅ White balance locked to D65 approximation")
                }
            )
        }

        // 3. Lock Focus
        if device.isFocusModeSupported(.locked) {
            // Set focus to ~40cm (typical face distance)
            if device.isLockingFocusWithCustomLensPositionSupported {
                // Lens position 0.0 = infinity, 1.0 = minimum focus
                // ~0.15-0.25 is typically 40-50cm for iPhone
                let focusPosition: Float = 0.20

                device.setFocusModeLocked(
                    lensPosition: focusPosition,
                    completionHandler: { _ in
                        print("✅ Focus locked at position \(focusPosition) (~40cm)")
                    }
                )
            } else {
                // Fallback: auto-focus then lock
                device.focusMode = .continuousAutoFocus

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, let device = self.captureDevice else { return }

                    try? device.lockForConfiguration()
                    device.focusMode = .locked
                    device.unlockForConfiguration()

                    print("✅ Focus locked at: \(device.lensPosition)")
                }
            }
        }

        // 4. Disable Video Stabilization (reduces processing artifacts)
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .off
                print("✅ Video stabilization disabled")
            }
        }

        print("🔒 Camera settings locked for consistent capture")
    }

    /// Unlock camera settings after scan
    func unlockCameraSettings() {
        guard let device = captureDevice else { return }

        try? device.lockForConfiguration()

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        device.unlockForConfiguration()

        print("🔓 Camera settings unlocked")
    }
}
```

### 5.2 Chromatic Adaptation (Bradford Transform) - Metal Shader

```metal
// File: Tavi/Features/FaceScan3D/Shaders/ChromaticAdaptation.metal

#include <metal_stdlib>
using namespace metal;

constant float3x3 M_Bradford = float3x3(
    float3( 0.8951,  0.2664, -0.1614),
    float3(-0.7502,  1.7135,  0.0367),
    float3( 0.0389, -0.0685,  1.0296)
);

constant float3x3 M_Bradford_inv = float3x3(
    float3( 0.9869929, -0.1470543,  0.1599627),
    float3( 0.4323053,  0.5183603,  0.0492912),
    float3(-0.0085287,  0.0400428,  0.9684867)
);

// sRGB to XYZ (D65 illuminant)
constant float3x3 sRGB_to_XYZ = float3x3(
    float3(0.4124564, 0.3575761, 0.1804375),
    float3(0.2126729, 0.7151522, 0.0721750),
    float3(0.0193339, 0.1191920, 0.9503041)
);

// XYZ to sRGB
constant float3x3 XYZ_to_sRGB = float3x3(
    float3( 3.2404542, -1.5371385, -0.4985314),
    float3(-0.9692660,  1.8760108,  0.0415560),
    float3( 0.0556434, -0.2040259,  1.0572252)
);

/// sRGB gamma decode (to linear)
float srgb_to_linear(float srgb) {
    if (srgb <= 0.04045) {
        return srgb / 12.92;
    } else {
        return pow((srgb + 0.055) / 1.055, 2.4);
    }
}

/// sRGB gamma encode (from linear)
float linear_to_srgb(float linear) {
    if (linear <= 0.0031308) {
        return linear * 12.92;
    } else {
        return 1.055 * pow(linear, 1.0/2.4) - 0.055;
    }
}

float3 srgb_to_linear_rgb(float3 srgb) {
    return float3(
        srgb_to_linear(srgb.r),
        srgb_to_linear(srgb.g),
        srgb_to_linear(srgb.b)
    );
}

float3 linear_to_srgb_rgb(float3 linear) {
    return float3(
        linear_to_srgb(linear.r),
        linear_to_srgb(linear.g),
        linear_to_srgb(linear.b)
    );
}

/// Bradford chromatic adaptation: source illuminant → D65
float3 adapt_to_D65(float3 linear_rgb, float3 src_illuminant_XYZ) {
    // D65 white point
    constant float3 D65_XYZ = float3(0.95047, 1.00000, 1.08883);

    // Convert RGB to XYZ
    float3 pixel_XYZ = sRGB_to_XYZ * linear_rgb;

    // Transform to LMS
    float3 src_LMS = M_Bradford * src_illuminant_XYZ;
    float3 D65_LMS = M_Bradford * D65_XYZ;
    float3 pixel_LMS = M_Bradford * pixel_XYZ;

    // Apply chromatic adaptation (component-wise scaling)
    float3 gain = D65_LMS / src_LMS;
    float3 adapted_LMS = pixel_LMS * gain;

    // Transform back to XYZ
    float3 adapted_XYZ = M_Bradford_inv * adapted_LMS;

    // Convert to linear RGB
    float3 adapted_linear = XYZ_to_sRGB * adapted_XYZ;

    // Clamp to valid range
    return clamp(adapted_linear, 0.0, 1.0);
}

/// Estimate scene illuminant from gray world assumption
kernel void estimate_illuminant(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device float3* illuminantXYZ [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Sample center region (avoid edges which may be shadowed)
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    uint startX = width / 4;
    uint startY = height / 4;
    uint endX = 3 * width / 4;
    uint endY = 3 * height / 4;

    // Accumulate RGB
    float3 sum_rgb = float3(0.0);
    uint count = 0;

    for (uint y = startY; y < endY; y += 4) {
        for (uint x = startX; x < endX; x += 4) {
            float4 pixel = inputTexture.read(uint2(x, y));
            sum_rgb += pixel.rgb;
            count++;
        }
    }

    // Mean RGB (gray world assumption: scene average is gray)
    float3 mean_rgb = sum_rgb / float(count);

    // Convert to linear RGB
    float3 linear_rgb = srgb_to_linear_rgb(mean_rgb);

    // Convert to XYZ (this is the estimated illuminant)
    float3 estimated_XYZ = sRGB_to_XYZ * linear_rgb;

    // Normalize to Y=1.0 (standard illuminant representation)
    estimated_XYZ /= estimated_XYZ.y;

    if (gid.x == 0 && gid.y == 0) {
        *illuminantXYZ = estimated_XYZ;
    }
}

/// Apply chromatic adaptation to entire texture
kernel void apply_chromatic_adaptation(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float3& src_illuminant_XYZ [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read pixel
    float4 pixel = inputTexture.read(gid);

    // Convert to linear RGB
    float3 linear_rgb = srgb_to_linear_rgb(pixel.rgb);

    // Apply Bradford adaptation to D65
    float3 adapted_linear = adapt_to_D65(linear_rgb, src_illuminant_XYZ);

    // Convert back to sRGB
    float3 adapted_srgb = linear_to_srgb_rgb(adapted_linear);

    // Write output
    outputTexture.write(float4(adapted_srgb, pixel.a), gid);
}
```

### 5.3 Chromatic Adaptation - CPU Wrapper

```swift
// File: Tavi/Features/FaceScan3D/Utilities/ChromaticAdaptation.swift

import Metal
import MetalKit
import simd

public class ChromaticAdaptation {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let estimateIlluminantPipeline: MTLComputePipelineState
    private let adaptPipeline: MTLComputePipelineState

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotFound
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw MetalError.queueCreationFailed
        }
        self.commandQueue = queue

        // Load shaders
        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryNotFound
        }

        guard let estimateFunction = library.makeFunction(name: "estimate_illuminant"),
              let adaptFunction = library.makeFunction(name: "apply_chromatic_adaptation") else {
            throw MetalError.functionNotFound
        }

        self.estimateIlluminantPipeline = try device.makeComputePipelineState(function: estimateFunction)
        self.adaptPipeline = try device.makeComputePipelineState(function: adaptFunction)
    }

    /// Estimate scene illuminant from texture
    public func estimateIlluminant(from texture: MTLTexture) -> SIMD3<Float>? {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        // Create buffer for result
        let illuminantBuffer = device.makeBuffer(
            length: MemoryLayout<SIMD3<Float>>.stride,
            options: .storageModeShared
        )

        encoder.setComputePipelineState(estimateIlluminantPipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(illuminantBuffer, offset: 0, index: 0)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read result
        guard let buffer = illuminantBuffer else { return nil }
        let pointer = buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
        return pointer.pointee
    }

    /// Apply chromatic adaptation to D65
    public func adaptToD65(
        input: MTLTexture,
        output: MTLTexture,
        sourceIlluminant: SIMD3<Float>
    ) -> Bool {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }

        // Create buffer for illuminant
        var illuminant = sourceIlluminant
        let illuminantBuffer = device.makeBuffer(
            bytes: &illuminant,
            length: MemoryLayout<SIMD3<Float>>.stride,
            options: .storageModeShared
        )

        encoder.setComputePipelineState(adaptPipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBuffer(illuminantBuffer, offset: 0, index: 0)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return true
    }

    /// Full pipeline: estimate illuminant and adapt
    public func normalizeToD65(texture: MTLTexture) -> MTLTexture? {
        // Step 1: Estimate illuminant
        guard let sourceIlluminant = estimateIlluminant(from: texture) else {
            AppLogger.rendering.error("Failed to estimate illuminant")
            return nil
        }

        AppLogger.rendering.debug("Estimated illuminant XYZ: \(sourceIlluminant)")

        // Step 2: Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        // Step 3: Apply adaptation
        guard adaptToD65(input: texture, output: outputTexture, sourceIlluminant: sourceIlluminant) else {
            return nil
        }

        return outputTexture
    }
}
```

### 5.4 Tests: Illuminant Simulation and Score Stability

```swift
// File: TaviTests/ChromaticAdaptationTests.swift

import XCTest
import simd
@testable import Tavi

final class ChromaticAdaptationTests: XCTestCase {

    // MARK: - Illuminant Definitions

    /// Standard illuminants (CIE XYZ, normalized to Y=1.0)
    enum Illuminant {
        static let D65 = SIMD3<Float>(0.95047, 1.00000, 1.08883)  // Daylight 6500K
        static let A = SIMD3<Float>(1.09850, 1.00000, 0.35585)    // Tungsten 2856K
        static let F2 = SIMD3<Float>(0.99186, 1.00000, 0.67393)   // Cool white fluorescent
        static let F11 = SIMD3<Float>(1.00962, 1.00000, 0.64350)  // Narrow-band white LED

        static var all: [(name: String, xyz: SIMD3<Float>)] {
            return [
                ("D65 (Daylight)", D65),
                ("A (Tungsten)", A),
                ("F2 (CFL)", F2),
                ("F11 (LED)", F11)
            ]
        }
    }

    // MARK: - Color Simulation

    /// Simulate how a skin color appears under different illuminants
    func simulateSkinUnderIlluminant(
        skinRGB_D65: SIMD3<Float>,
        targetIlluminant: SIMD3<Float>
    ) -> SIMD3<Float> {
        // This simulates camera capture under non-D65 lighting
        // In reality, the camera captures the color as it appears under that light

        // Convert skin color to XYZ (assuming it was measured under D65)
        let linear = sRGBToLinear(skinRGB_D65)
        let xyz = rgbToXYZ(linear)

        // Apply inverse adaptation: D65 → target illuminant
        let adapted = bradfordAdapt(xyz: xyz, from: Illuminant.D65, to: targetIlluminant)

        // Convert back to sRGB (this is what camera sees)
        let adaptedLinear = xyzToRGB(adapted)
        return linearToSRGB(adaptedLinear)
    }

    // MARK: - Bradford Transform Helpers

    func bradfordAdapt(xyz: SIMD3<Float>, from srcIlluminant: SIMD3<Float>, to dstIlluminant: SIMD3<Float>) -> SIMD3<Float> {
        let M_Bradford = simd_float3x3(
            SIMD3<Float>( 0.8951,  0.2664, -0.1614),
            SIMD3<Float>(-0.7502,  1.7135,  0.0367),
            SIMD3<Float>( 0.0389, -0.0685,  1.0296)
        )

        let M_Bradford_inv = simd_float3x3(
            SIMD3<Float>( 0.9869929, -0.1470543,  0.1599627),
            SIMD3<Float>( 0.4323053,  0.5183603,  0.0492912),
            SIMD3<Float>(-0.0085287,  0.0400428,  0.9684867)
        )

        let src_LMS = M_Bradford * srcIlluminant
        let dst_LMS = M_Bradford * dstIlluminant
        let pixel_LMS = M_Bradford * xyz

        let gain = dst_LMS / src_LMS
        let adapted_LMS = pixel_LMS * gain

        return M_Bradford_inv * adapted_LMS
    }

    func sRGBToLinear(_ srgb: SIMD3<Float>) -> SIMD3<Float> {
        func decode(_ c: Float) -> Float {
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return SIMD3<Float>(decode(srgb.x), decode(srgb.y), decode(srgb.z))
    }

    func linearToSRGB(_ linear: SIMD3<Float>) -> SIMD3<Float> {
        func encode(_ c: Float) -> Float {
            return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0/2.4) - 0.055
        }
        return SIMD3<Float>(encode(linear.x), encode(linear.y), encode(linear.z))
    }

    func rgbToXYZ(_ linear: SIMD3<Float>) -> SIMD3<Float> {
        let M = simd_float3x3(
            SIMD3<Float>(0.4124564, 0.3575761, 0.1804375),
            SIMD3<Float>(0.2126729, 0.7151522, 0.0721750),
            SIMD3<Float>(0.0193339, 0.1191920, 0.9503041)
        )
        return M * linear
    }

    func xyzToRGB(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
        let M = simd_float3x3(
            SIMD3<Float>( 3.2404542, -1.5371385, -0.4985314),
            SIMD3<Float>(-0.9692660,  1.8760108,  0.0415560),
            SIMD3<Float>( 0.0556434, -0.2040259,  1.0572252)
        )
        return M * xyz
    }

    // MARK: - Test: Score Stability Across Illuminants

    /// Test that pigmentation scores remain stable after chromatic adaptation
    func testPigmentationScoreStabilityAcrossIlluminants() {
        let analyzer = PigmentationAnalyzer()
        let scorer = Scoring3D()

        // Reference skin color under D65 (medium Indian skin tone)
        let skinColors_D65: [SIMD3<Float>] = [
            SIMD3<Float>(0.70, 0.50, 0.40),  // Base tone
            SIMD3<Float>(0.72, 0.52, 0.42),  // Slight variation
            SIMD3<Float>(0.68, 0.48, 0.38),  // Slight variation
            SIMD3<Float>(0.71, 0.51, 0.41),  // Slight variation
        ]

        // Create ROI sample under D65
        let d65Pixels = Array(repeating: skinColors_D65, count: 250).flatMap { $0 }
        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: d65Pixels.count)
        let d65Sample = ROITextureSample(
            roi: .forehead,
            pixels: d65Pixels,
            uvCoordinates: uvs,
            width: 50,
            height: 20
        )

        // Compute baseline index and score under D65
        let d65Index = analyzer.computePigmentationIndex(d65Sample, lightingQuality: 1.0, skinTone: .medium)
        let d65Score = scorer.mapPigmentationScore(d65Index, lightingQuality: 1.0)

        print("\n📊 Pigmentation Score Stability Test")
        print("=" * 80)
        print("Reference (D65): index=\(String(format: "%.4f", d65Index)), score=\(String(format: "%.1f", d65Score))")
        print("")

        var scores: [(illuminant: String, index: Float, score: Float, delta: Float)] = []

        // Test each illuminant
        for (name, illuminantXYZ) in Illuminant.all {
            // Simulate how skin appears under this illuminant
            let simulatedPixels = skinColors_D65.map { skinColor in
                simulateSkinUnderIlluminant(skinRGB_D65: skinColor, targetIlluminant: illuminantXYZ)
            }
            let repeatedPixels = Array(repeating: simulatedPixels, count: 250).flatMap { $0 }

            // Create sample
            let sample = ROITextureSample(
                roi: .forehead,
                pixels: repeatedPixels,
                uvCoordinates: uvs,
                width: 50,
                height: 20
            )

            // BEFORE chromatic adaptation
            let rawIndex = analyzer.computePigmentationIndex(sample, lightingQuality: 1.0, skinTone: .medium)
            let rawScore = scorer.mapPigmentationScore(rawIndex, lightingQuality: 1.0)
            let rawDelta = rawScore - d65Score

            // AFTER chromatic adaptation (simulate by adapting pixels to D65)
            let adaptedPixels = repeatedPixels.map { pixel in
                let linear = sRGBToLinear(pixel)
                let xyz = rgbToXYZ(linear)
                let adaptedXYZ = bradfordAdapt(xyz: xyz, from: illuminantXYZ, to: Illuminant.D65)
                let adaptedLinear = xyzToRGB(adaptedXYZ)
                return linearToSRGB(adaptedLinear)
            }

            let adaptedSample = ROITextureSample(
                roi: .forehead,
                pixels: adaptedPixels,
                uvCoordinates: uvs,
                width: 50,
                height: 20
            )

            let adaptedIndex = analyzer.computePigmentationIndex(adaptedSample, lightingQuality: 1.0, skinTone: .medium)
            let adaptedScore = scorer.mapPigmentationScore(adaptedIndex, lightingQuality: 1.0)
            let adaptedDelta = adaptedScore - d65Score

            print("\(name):")
            print("  BEFORE adaptation: index=\(String(format: "%.4f", rawIndex)), score=\(String(format: "%.1f", rawScore)), delta=\(String(format: "%+.1f", rawDelta))")
            print("  AFTER adaptation:  index=\(String(format: "%.4f", adaptedIndex)), score=\(String(format: "%.1f", adaptedScore)), delta=\(String(format: "%+.1f", adaptedDelta))")

            scores.append((name, adaptedIndex, adaptedScore, adaptedDelta))
        }

        print("\n📈 Summary:")
        print("Illuminant               | Index  | Score | Delta from D65")
        print("------------------------|--------|-------|---------------")
        for (name, index, score, delta) in scores {
            print(String(format: "%-23s | %.4f | %5.1f | %+5.1f", name, index, score, delta))
        }

        // Verify stability: deltas should be within ±5 points after adaptation
        for (name, _, _, delta) in scores {
            XCTAssertLessThan(abs(delta), 5.0, "\(name) score delta exceeds ±5 points after chromatic adaptation")
        }

        print("\n✅ Score stability validated: all illuminants within ±5 points after chromatic adaptation")
    }

    /// Test that texture metrics (roughness) are already stable without chromatic adaptation
    func testTextureScoreStabilityAcrossIlluminants() {
        let analyzer = RoughnessAnalyzer()

        // Create texture pattern (varying luminance, consistent chromaticity)
        var texturePixels: [SIMD3<Float>] = []
        let baseColor = SIMD3<Float>(0.70, 0.50, 0.40)

        for y in 0..<20 {
            for x in 0..<50 {
                // Add high-frequency variation
                let variation = sin(Float(x) * 0.5) * 0.1 + cos(Float(y) * 0.3) * 0.05
                let pixel = baseColor * (1.0 + variation)
                texturePixels.append(pixel)
            }
        }

        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: texturePixels.count)
        let d65Sample = ROITextureSample(
            roi: .forehead,
            pixels: texturePixels,
            uvCoordinates: uvs,
            width: 50,
            height: 20
        )

        let d65Roughness = analyzer.computeRoughnessProxy(d65Sample)

        print("\n📊 Texture Roughness Stability Test")
        print("=" * 80)
        print("Reference (D65): roughness=\(String(format: "%.4f", d65Roughness))")
        print("")

        // Test each illuminant
        for (name, illuminantXYZ) in Illuminant.all {
            let simulatedPixels = texturePixels.map { pixel in
                simulateSkinUnderIlluminant(skinRGB_D65: pixel, targetIlluminant: illuminantXYZ)
            }

            let sample = ROITextureSample(
                roi: .forehead,
                pixels: simulatedPixels,
                uvCoordinates: uvs,
                width: 50,
                height: 20
            )

            let roughness = analyzer.computeRoughnessProxy(sample)
            let delta = roughness - d65Roughness

            print("\(name): roughness=\(String(format: "%.4f", roughness)), delta=\(String(format: "%+.4f", delta))")

            // Roughness should be stable within ±3% (it's ratio-based)
            XCTAssertLessThan(abs(delta), 0.03, "\(name) roughness delta exceeds ±0.03")
        }

        print("\n✅ Roughness stability validated: all illuminants within ±3% (no adaptation needed)")
    }
}
```

---

## 6. What Cannot Be Made Invariant

### 6.1 Fundamental Limitations

| Metric | Why Invariant is Impossible | Impact | Mitigation |
|--------|----------------------------|--------|------------|
| **Specular/Oiliness** | Depends on light source position and viewer angle (Fresnel reflection) | High | **Gate**: Hide if uniformity < 0.7 |
| **Acne 3D Relief** | Requires shadow gradients to perceive depth | High | **Gate**: Hide if uniformity < 0.6 |
| **Wrinkles/Fine Lines** | Shadow-dependent depth cues | High | **Gate**: Hide if uniformity < 0.6 |
| **Pore Depth** | Partial shadow in pore openings enhances detection | Moderate | **Reduce confidence** by 20% if uniformity < 0.7 |
| **Redness (Erythema)** | A* channel sensitive to color temperature even after adaptation | Moderate | **Reduce confidence** by 15% if color cast > 0.1 |

### 6.2 User Messaging

**In-App Explanations**:

```swift
struct MetricLimitationsView: View {
    let metric: SkinMetric

    var limitationText: String {
        switch metric {
        case .specular, .oiliness:
            return """
            Shine detection requires consistent lighting direction.
            For best results, use diffuse lighting (avoid direct sunlight or desk lamps).
            """

        case .acne, .wrinkles:
            return """
            3D texture detection uses subtle shadows to detect skin relief.
            Harsh or uneven lighting may affect accuracy. Ensure uniform, diffuse lighting.
            """

        case .pores:
            return """
            Pore detection works best with moderate, uniform lighting.
            Very bright or very dim lighting may reduce detection accuracy.
            """

        case .redness:
            return """
            Redness analysis compensates for lighting color, but extreme warm/cool tones
            may affect accuracy. Natural daylight or neutral LED lighting recommended.
            """

        default:
            return """
            This metric has been normalized for consistent results across lighting conditions.
            """
        }
    }
}
```

**Capture Instructions**:

```swift
struct CaptureInstructionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("For Best Results:")
                .font(.headline)

            InstructionRow(icon: "💡", text: "Use diffuse lighting (window light, soft LED)")
            InstructionRow(icon: "❌", text: "Avoid direct sunlight or desk lamps")
            InstructionRow(icon: "📏", text: "Hold phone 40cm (arm's length) from face")
            InstructionRow(icon: "🎯", text: "Ensure face is evenly lit (no shadows)")
            InstructionRow(icon: "🔒", text: "Hold steady for 2-3 seconds")

            Divider()

            Text("What We Measure:")
                .font(.headline)

            Text("✅ Pigmentation, texture, pores (lighting-normalized)")
                .font(.caption)
            Text("⚠️ Oiliness, wrinkles (require good lighting quality)")
                .font(.caption)
        }
    }
}
```

**Score Card Disclaimers**:

```swift
struct ScoreCardView: View {
    let metric: SkinMetric
    let score: Float
    let confidence: Float

    var disclaimerText: String? {
        if confidence < 0.75 {
            switch metric {
            case .specular, .oiliness:
                return "Low confidence due to uneven lighting. Results may vary."
            case .acne, .wrinkles:
                return "Limited visibility due to lighting quality. Consider rescanning."
            default:
                return "Moderate confidence. Lighting quality affects this metric."
            }
        }
        return nil
    }
}
```

---

## 7. Implementation Roadmap

### Phase 1: Camera Locking (1-2 days)
- [ ] Implement `lockCameraSettings()` in CameraController
- [ ] Test exposure/WB locking on multiple iPhone models
- [ ] Verify settings remain locked during capture session

### Phase 2: Scan Quality Scoring (2-3 days)
- [ ] Implement 5 quality component scorers (exposure, clipping, cast, uniformity, sharpness)
- [ ] Create `ScanQualityMetrics` struct with overall score
- [ ] Add real-time quality indicator to capture UI
- [ ] Test quality scoring with synthetic images

### Phase 3: Chromatic Adaptation (3-4 days)
- [ ] Implement Bradford transform Metal shaders
- [ ] Create `ChromaticAdaptation` wrapper class
- [ ] Integrate into texture pipeline (before ROI sampling)
- [ ] Write unit tests with multiple illuminants

### Phase 4: Confidence Gating (2-3 days)
- [ ] Implement per-metric confidence computation
- [ ] Update UI to show/hide/gray metrics based on confidence
- [ ] Add metric limitation explanations
- [ ] Test UI with low-quality scans

### Phase 5: Validation Testing (3-5 days)
- [ ] Capture test dataset under 4 illuminants (daylight, tungsten, CFL, LED)
- [ ] Measure score deltas before/after chromatic adaptation
- [ ] Validate ±5% stability for pigmentation/discoloration
- [ ] Document remaining variability in gated metrics

**Total Estimated Time**: 11-17 days (2-3.5 weeks)

---

## Summary

This design provides a **scientifically honest** approach to lighting normalization:

1. **Normalizable metrics** (pigmentation, discoloration, texture) get chromatic adaptation → ±5% stability
2. **Lighting-sensitive metrics** (specular, acne, wrinkles) are gated with confidence thresholds → hidden when unreliable
3. **Scan quality scoring** provides real-time feedback → users capture better scans
4. **Camera locking** ensures consistency → reduces intra-session variability
5. **Transparent UI** shows confidence → users understand limitations

**Key Trade-offs**:
- ✅ Honest about what cannot be normalized (geometry-dependent metrics)
- ✅ Provides tools for users to capture quality scans (real-time feedback)
- ✅ Maintains scientific integrity (no false claims of invariance)
- ⚠️ Some metrics may be unavailable in poor lighting (acceptable trade-off for accuracy)
