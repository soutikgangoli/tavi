# Technical Requirements Specification for Tavi FaceScan3D
## Complete Parameter Documentation for All Analyzers and Tools

**Document Version:** 1.0
**Last Updated:** 2025-01-06
**Purpose:** Comprehensive technical specifications for minimum requirements, thresholds, and parameters required for accurate operation of all FaceScan3D analyzers and tools.

---

## Table of Contents
1. [Environmental Requirements](#environmental-requirements)
2. [Hardware Requirements](#hardware-requirements)
3. [Calibration Requirements](#calibration-requirements)
4. [Mesh Quality Requirements](#mesh-quality-requirements)
5. [Texture Quality Requirements](#texture-quality-requirements)
6. [Analyzer-Specific Requirements](#analyzer-specific-requirements)
7. [Performance & Optimization](#performance--optimization)
8. [Clinical Accuracy Standards](#clinical-accuracy-standards)

---

## 1. Environmental Requirements

### 1.1 Lighting Requirements

#### Ambient Lighting Levels (ARKit lumens)
- **Minimum Acceptable:** 600 lumens (below = too dark, scan blocked)
- **Optimal Range:** 800-1800 lumens (best quality, no warnings)
- **Minimum Optimal:** 800 lumens (warnings below this)
- **Maximum Optimal:** 1800 lumens (warnings above this)
- **Maximum Acceptable:** 2000 lumens (above = too bright, scan blocked)

**Source:** `ScanConfiguration.swift:120-131`

#### Lighting Quality Metrics
- **Brightness Range:** 0.0-1.0 normalized scale
  - **Too Dark:** < 0.20 average brightness with poor contrast (< 0.10)
  - **Suboptimal Dark:** 0.20-0.55 brightness OR contrast < 0.15
  - **Optimal:** 0.55-0.75 brightness with good contrast (≥ 0.15)
  - **Suboptimal Bright:** 0.75-0.85 brightness OR overexposure > 5%
  - **Too Bright:** > 0.85 brightness OR overexposure > 10%

- **Dynamic Range (Skin-Tone Independent):**
  - **Minimum Acceptable:** 0.30 (30% difference between darkest and brightest pixels)
  - **Optimal:** > 0.40
  - **Purpose:** Ensures facial features are visible regardless of skin tone

- **Contrast/Texture Visibility:**
  - **Minimum Acceptable:** 0.15 standard deviation in brightness
  - **Purpose:** Required to detect fine skin texture and pigmentation

- **Overexposure Limits:**
  - **Warning Threshold:** > 5% of pixels at 95%+ brightness
  - **Block Threshold:** > 10% of pixels at 95%+ brightness
  - **Purpose:** Prevents blown-out highlights that hide skin defects

- **Underexposure Limits:**
  - **Block Threshold:** > 20% of pixels at < 5% brightness
  - **Purpose:** Prevents pure black regions with no recoverable detail

**Source:** `EdgeCaseDetector.swift:246-375`

#### Lighting Consistency During Scan
- **Maximum Lighting Change:** 30% deviation from baseline
- **Maximum Color Temperature Change:** 15% deviation from baseline
- **Validation Interval:** Every 15 frames (~0.25s at 60fps)

**Source:** `ScanConfiguration.swift:17-21`, `CalibrationManager.swift:375-406`

#### Color Temperature
- **Detection Range:** 2000K - 10000K
- **Adaptive Target by Skin Tone:**
  - Very Light/Light: 6000K (standard daylight)
  - Medium/Medium-Dark: 5800K (preserve golden undertones)
  - Dark/Very Dark: 5600K (preserve warmth)
- **Normalization Threshold:** Only normalize if difference > 500K

**Source:** `Face3DMetricsAnalyzer.swift:237-267`

---

### 1.2 Distance Requirements

#### Face-to-Camera Distance (meters)
- **Absolute Minimum:** 0.20m (closer = distortion and cutoff)
- **Acceptable Close:** 0.25-0.30m (slight distortion possible)
- **Optimal Range:** 0.30-0.50m (best quality for skin analysis)
- **Acceptable Far:** 0.50-0.60m (reduced detail)
- **Maximum Usable:** 0.70m (beyond = insufficient detail)

**Clinical Context:**
- **30-50cm optimal:** Balances field of view with skin detail resolution
- **Below 25cm:** Face extends beyond camera frame, perspective distortion
- **Above 60cm:** Insufficient pixel density for pore/wrinkle analysis

**Source:** `ScanConfiguration.swift:133-156`

---

### 1.3 Stability Requirements

#### Movement Threshold
- **Maximum Movement:** 0.03m (3cm) between frames
- **Measurement:** Euclidean distance of face anchor transform
- **Frame Rate:** Evaluated at 60fps
- **Purpose:** Prevents motion blur and mesh artifacts

**Calculation:**
```swift
movement = sqrt(dx² + dy² + dz²)
stable = movement < 0.03m
```

**Source:** `ScanConfiguration.swift:207`, `CalibrationManager.swift:364-373`

---

### 1.4 Head Pose Requirements

#### Center Position (Look Straight)
- **Yaw (Left/Right Turn):** ±5° maximum
- **Pitch (Up/Down Tilt):** ±5° maximum
- **Roll (Side Tilt):** ±8° maximum
- **Purpose:** Establishes baseline for 3D reconstruction

#### Turn Left Pose
- **Yaw Range:** +15° to +35°
- **Pitch Tolerance:** ±15°
- **Roll Tolerance:** ±8°

#### Turn Right Pose
- **Yaw Range:** -15° to -35°
- **Pitch Tolerance:** ±15°
- **Roll Tolerance:** ±8°

#### Look Up Pose
- **Pitch Range:** +10° to +22°
- **Yaw Tolerance:** ±15°
- **Roll Tolerance:** ±8°

#### Look Down Pose
- **Pitch Range:** -12° to -25°
- **Yaw Tolerance:** ±15°
- **Roll Tolerance:** ±8°

**Clinical Rationale:** These ranges ensure:
1. Complete facial coverage (5 poses = ~270° horizontal coverage)
2. Minimal self-occlusion (chin, nose don't block cheeks)
3. Accurate 3D reconstruction (sufficient parallax for depth)

**Source:** `ScanConfiguration.swift:158-203`, `CalibrationState.swift:176-218`

---

## 2. Hardware Requirements

### 2.1 Device Capabilities
- **TrueDepth Camera:** Required (iPhone X or later, iPad Pro 2018+)
- **ARKit Version:** ARKit 4.0+ (iOS 13.0+)
- **Face Tracking:** ARFaceTrackingConfiguration support
- **Metal GPU:** Required for texture processing
- **Memory:** Minimum 3GB RAM recommended

### 2.2 Camera Specifications
- **Resolution:** 1920×1440 minimum (ARFrame captured image)
- **Frame Rate:** 60fps for smooth tracking
- **Depth Sensing:** Active structured light (TrueDepth)
- **Face Mesh:** ~1,220 vertices standard ARKit mesh

**Source:** Various implementation files

---

## 3. Calibration Requirements

### 3.1 Pre-Scan Validation

#### Face Detection
- **Tracked Status:** ARFaceAnchor.isTracked = true
- **Face Confidence:** High tracking quality (good lighting + visibility)
- **Minimum Face Size:** 30% of frame
- **Maximum Face Size:** 75% of frame

**Source:** `ScanConfiguration.swift:106-114`, `CalibrationManager.swift:62-78`

#### Expression Requirements (Neutral Expression)
- **Jaw Open:** ≤ 0.15 (15% blend shape value)
- **Eye Blink:** ≤ 0.20 (eyes open)
- **Smile:** ≤ 0.25 (relaxed to slight - adjusted for "look down" false positives)
- **Mouth Pucker:** ≤ 0.20
- **Cheek Puff:** ≤ 0.20
- **Eye Wide:** ≤ 0.30
- **Eye Squint:** ≤ 0.30 (skipped during "look down")
- **Brow Up (Inner):** ≤ 0.30
- **Brow Down (Outer):** ≤ 0.30

**Purpose:** Neutral expression ensures:
1. Consistent mesh topology across all scans
2. Accurate wrinkle depth (not exaggerated by expression)
3. Proper skin texture capture (not stretched/compressed)

**Source:** `ScanConfiguration.swift:30-55`, `CalibrationManager.swift:408-480`

---

### 3.2 Image Quality Validation

#### Exposure
- **Ideal Exposure:** 0.5 (normalized 0-1 scale)
- **Maximum Deviation:** ±0.3
- **Acceptable Range:** 0.20-0.80
- **Underexposure Threshold:** < 0.25
- **Overexposure Threshold:** > 0.75

**Skin-Tone Adaptive Adjustment:**
- If dynamic range > 0.30 and brightness < 0.40:
  - Likely darker skin in good lighting
  - Adjust exposure score: 0.45 + (rawBrightness - 0.20) × 0.5

**Source:** `ScanConfiguration.swift:325-330`, `ImageQualityAnalyzer.swift:108-158`

#### Sharpness (Focus Quality)
- **Method:** Laplacian variance
- **Minimum Acceptable:** 150.0 variance units
- **Typical Range:** 0-500 (higher = sharper)
- **Purpose:** Blurry textures cause incorrect roughness/smoothness measurements

**Rationale:** Increased from 100 to 150 after real-world testing showed TrueDepth can achieve this with proper focus. Clinical skin analysis requires sharp texture capture.

**Source:** `ImageQualityAnalyzer.swift:21-24`, `ImageQualityAnalyzer.swift:42-98`

---

## 4. Mesh Quality Requirements

### 4.1 Geometry Specifications

#### Vertex Count
- **ARKit Standard Mesh:** ~1,220 vertices
- **Expected After Processing:** ~6,000-10,000 vertices (5 poses merged)
- **Streaming Threshold:** 50,000 vertices (switch to streaming merger)

#### Triangle Count
- **Per Pose:** ~2,304 triangles
- **Expected Final Mesh:** ~11,500-15,000 triangles
- **Purpose:** Sufficient detail for sub-millimeter analysis

**Source:** `ScanConfiguration.swift:305-308`

#### Mesh Topology Requirements
- **Manifold Geometry:** Preferred (no non-manifold edges)
- **Watertight:** Preferred (no holes in mesh)
- **Vertex Normals:** Required for all vertices
- **Texture Coordinates:** Required (0-1 UV space)

**Source:** `MeshTopologyAnalyzer.swift` (referenced in Face3DMetricsAnalyzer)

---

### 4.2 Mesh Processing Parameters

#### Smoothing
- **Iterations:** 3 passes
- **Normal Smoothing Strength:** 0.5
- **Purpose:** Reduce ARKit mesh noise while preserving features

#### Wrinkle Depth Scaling
- **Scaling Factor:** 0.00002 (20 micrometers)
- **Expected Range:** 15-25 micrometers
- **⚠️ Status:** UNVALIDATED - needs ground truth calibration
- **Impact:** Critical for wrinkle/roughness accuracy

**Source:** `ScanConfiguration.swift:211-229`

---

## 5. Texture Quality Requirements

### 5.1 Resolution

#### Standard Resolution
- **Width:** 2048 pixels
- **Height:** 2048 pixels
- **Purpose:** Balances quality and performance

#### High Resolution (Optional)
- **Width:** 4096 pixels
- **Height:** 4096 pixels
- **Use Case:** When user enables high-res in settings
- **Memory Impact:** ~64MB per texture (RGBA 32-bit)

**Source:** `ScanConfiguration.swift:238-320`

---

### 5.2 Texture Quality Validation

#### Minimum ROI Pixel Coverage
Each region of interest (ROI) must have sufficient pixel coverage:

**Key Facial Regions:**
- **Forehead:** Minimum 500 pixels
- **Left Cheek:** Minimum 500 pixels
- **Right Cheek:** Minimum 500 pixels
- **Nose:** Minimum 300 pixels
- **Chin:** Minimum 400 pixels
- **Left Under-Eye:** Minimum 200 pixels
- **Right Under-Eye:** Minimum 200 pixels

**Confidence Levels:**
- **High:** > Minimum required
- **Medium:** 50-100% of minimum
- **Low:** < 50% of minimum (excluded from global metrics)

**Source:** `TextureQualityValidator.swift` (referenced in Face3DMetricsAnalyzer.swift:145-155)

---

## 6. Analyzer-Specific Requirements

### 6.1 Roughness Analyzer

**Input Requirements:**
- **Geometry:** FaceMeshGeometry with vertex normals
- **Purpose:** Analyzes surface texture micro-variations

**Processing:**
- **Method:** Normal vector variance analysis
- **Downsampling:** Internal optimization (preserves accuracy)
- **Output Range:** 0.0-1.0 (0 = smooth, 1 = very rough)

**Quality Thresholds:**
- **Excellent (Score 85-100):** Roughness < 0.08
- **Good (Score 70-84):** Roughness 0.08-0.15
- **Fair (Score 40-69):** Roughness 0.15-0.30
- **Poor (Score 0-39):** Roughness > 0.30

**Source:** `RoughnessAnalyzer.swift` (referenced), `Scoring3D.swift` (scoring logic)

---

### 6.2 Pigmentation Analyzer

**Input Requirements:**
- **Texture:** ROI pixel samples (CIELAB color space)
- **Minimum Pixels per ROI:** 500 for reliable statistics

**Metrics:**
- **Color Space:** CIELAB (perceptually uniform)
- **Channel Analysis:** A* (green-red) and B* (blue-yellow) variance
- **Normalization Factor:** 100.0 (may need skin-tone tuning)

**Lighting Quality Correction:**
- Adapts thresholds based on lighting quality score
- Prevents false positives from shadows/uneven lighting

**Output Range:** 0.0-1.0 (0 = perfectly even, 1 = very uneven)

**Clinical Considerations:**
- **Indian/Asian Skin:** Naturally higher B* (yellow) variance
- **Recommendation:** Consider skin-tone-specific normalization

**Source:** `PigmentationAnalyzer.swift` (referenced), `Face3DMetricsAnalyzer.swift:588-590`

---

### 6.3 Discoloration Analyzer

**Input Requirements:**
- **ROI LAB Means:** Average L*, A*, B* for each facial region
- **Minimum ROIs:** 5 regions for cross-ROI variance

**Method:**
- **Inter-ROI Variance:** Compares color consistency across face
- **Good:** Uniform color across all regions
- **Poor:** Significant color differences (patches, spots)

**Lighting Quality Awareness:**
- Adjusts thresholds to account for shadows/uneven lighting
- Prevents false positives from environmental factors

**Output Range:** 0.0-1.0 (0 = uniform, 1 = patchy)

**Source:** `DiscolorationAnalyzer.swift` (referenced), `Face3DMetricsAnalyzer.swift:693-703`

---

### 6.4 Redness Analyzer

**Input Requirements:**
- **Texture:** Full face albedo texture (UIImage)
- **Color Space:** RGB → derived redness metric

**Method:**
- **Baseline Calculation:** Average redness across face
- **Relative Redness:** redness - baseline (detects localized inflammation)

**⚠️ Known Limitation (Dark Skin):**
- Current algorithm: `redness = R - (G+B)/2`
- **Issue:** On Fitzpatrick IV-VI, inflammation appears as darkening (not redness)
- **Status:** Needs skin-tone-aware darkness detection

**Recommended Enhancement:**
```swift
if skinTone == .dark || skinTone == .mediumDark {
    // Inflammation = localized darkening
    let darkness = 1.0 - (r + g + b) / 3.0
    let relativeDarkness = darkness - baselineDarkness
}
```

**Source:** `RednessAnalyzer.swift` (referenced), `CLINICAL_ACCURACY_REVIEW.md:48-82`

---

### 6.5 Acne Analyzer

**Input Requirements:**
- **Texture:** Full face albedo texture
- **Resolution:** Minimum 2048×2048 for accurate blemish detection

**Method:**
- **Adaptive Darkness Detection:** darkness threshold = avgBrightness × 0.70 (30% darker)
- **3D Elevation:** Uses geometry for raised blemish detection
- **Unified Detection:** Works across all skin tones (relative to baseline)

**Thresholds:**
- **Blemish Detection:** 30% darker than surrounding skin (adjustable by skin tone)
- **Recommended for Very Dark Skin:** 25% threshold
- **Purpose:** Avoids false positives from natural texture

**Source:** `AcneAnalyzer.swift` (referenced), `CLINICAL_ACCURACY_REVIEW.md:199-213`

---

### 6.6 Wrinkle Analyzer

**Input Requirements:**
- **Geometry:** FaceMeshGeometry with accurate vertex positions
- **Normals:** Required for depth calculation

**Metrics:**
- **Depth Measurement:** Differential geometry (curvature analysis)
- **Scaling Factor:** 0.00002 (20 micrometers) - ⚠️ UNVALIDATED
- **Classification:**
  - Fine: < 0.5mm depth
  - Moderate: 0.5-1.5mm depth
  - Deep: > 1.5mm depth

**Clinical Context:**
- Used for elasticity estimation (longitudinal tracking)
- Critical for aging analysis
- **Validation Required:** Needs optical profilometer calibration

**Source:** `WrinkleAnalyzer.swift` (referenced), `Face3DMetricsAnalyzer.swift:277-302`

---

### 6.7 Pore Analyzer

**Input Requirements:**
- **Texture:** High-resolution albedo texture (2048+ recommended)
- **Region Focus:** T-zone (nose, forehead, chin)

**Detection Method:**
- **Darkness Spots:** Small dark circular regions
- **Size Range:** 2-10 pixels diameter (maps to ~0.1-0.5mm real pores)
- **Adaptive Thresholding:** Relative to local skin brightness

**Output:**
- **Visibility Score:** 0-100 (higher = more visible pores)
- **Count:** Number of detected pores
- **Average Size:** Pore diameter distribution

**Source:** `PoreAnalyzer.swift` (referenced)

---

### 6.8 Sun Damage Analyzer

**Input Requirements:**
- **Face3DMetrics:** Complete metrics from all analyzers
- **Skin Tone:** Detected from texture (CIELAB L* value)

**Components:**
1. **Pigmentation Health:** Normalized pigmentation score
2. **Photoaging Resistance:** Based on wrinkle depth and roughness
3. **Texture Health:** Skin smoothness and uniformity

**Skin-Tone Normalization:**
- Adaptive thresholds for Fitzpatrick I-VI
- Accounts for natural pigmentation variations
- Prevents false positives on darker skin

**Output:** 0-100 protection score (higher = better sun protection)

**Source:** `SunDamageAnalyzer.swift` (referenced), `Face3DMetricsAnalyzer.swift:500-520`

---

### 6.9 Glow Analyzer

**Input Requirements:**
- **Texture:** Full face albedo
- **Geometry:** Mesh for light interaction analysis
- **Existing Metrics:** Uses specular data if available

**Metrics (Differentiated):**
1. **Glow Score (Health):**
   - Skin tone uniformity
   - Absence of dullness/discoloration
   - Range: 0-100

2. **Radiance Score (Luminosity):**
   - Healthy light reflection (not oiliness)
   - Natural skin luminance
   - Range: 0-100

**Purpose:** Distinguishes healthy glow from oily shine

**Source:** `GlowAnalyzer.swift` (referenced), `Face3DMetricsAnalyzer.swift:523-533`

---

### 6.10 Topology Analyzer

**Input Requirements:**
- **Geometry:** Complete mesh topology
- **Validation:** Manifold and watertight checks

**Metrics:**
- **Manifold Status:** Boolean (true = good topology)
- **Watertight Status:** Boolean (true = no holes)
- **Overall Quality:** 0-100 score
- **Quality Levels:** Excellent, Good, Fair, Poor

**Purpose:** Validates mesh quality for reliable measurements

**Source:** `MeshTopologyAnalyzer.swift` (referenced)

---

## 7. Performance & Optimization

### 7.1 Processing Timeouts

- **Mesh Merge:** 30 seconds
- **Texture Baking:** 30 seconds
- **Metrics Computation:** 150 seconds
  - ROI Processing: ~40s
  - Parallel Analyzers: ~65s
  - Glow/Sun Damage: ~10s
  - Overhead: ~35s
- **Core Data Save:** 10 seconds

**Source:** `ScanConfiguration.swift:249-263`

---

### 7.2 Frame Rate & Quality Checks

- **Analysis Frame Rate:** 30 fps (throttled from 60fps)
- **Quality Check Interval:** Every 15 frames (~0.5s)
- **Countdown Tolerance:** 15 frames (~0.25s grace period)

**Purpose:** Prevents UI lag while maintaining validation accuracy

**Source:** `ScanConfiguration.swift:293-303`

---

### 7.3 Memory Optimization

- **Max Frames in Memory:** 7 frames (5 poses + 2 calibration)
- **Parallel ROI Processing:** 2 concurrent operations maximum
  - Prevents memory spike (5× 4096² Metal textures = 2.5GB)
  - Keeps memory under 1GB
- **Thumbnail Size:** 200×200 pixels
- **Heatmap Size:** 300×300 pixels

**Source:** `ScanConfiguration.swift:359-367`, `Face3DMetricsAnalyzer.swift:180-214`

---

## 8. Clinical Accuracy Standards

### 8.1 Skin Tone Fairness

**Fitzpatrick Scale Support:**
- **Type I-II:** Very Light to Light
- **Type III-IV:** Medium to Medium-Dark (Indian, Asian)
- **Type V-VI:** Dark to Very Dark (African, Dark Indian)

**CIELAB L* Ranges:**
- Very Light: L* > 65
- Light: L* 60-65
- Medium: L* 55-60
- Medium-Dark: L* 50-55 (Indian common range)
- Dark: L* 45-50
- Very Dark: L* < 45

**Source:** `SkinToneNormalizer.swift` (referenced), `CLINICAL_ACCURACY_REVIEW.md:19-44`

---

### 8.2 Metric Normalization

**Purpose:** Ensures fairness across all skin tones

**Normalized Metrics:**
1. **Pigmentation Score:** Skin-tone-specific variance thresholds
2. **Discoloration Score:** Adaptive baseline for natural variation
3. **Sun Damage:** Fitzpatrick-adjusted thresholds

**Non-Normalized (Color-Independent):**
1. **Roughness:** Geometry-based (unaffected by color)
2. **Wrinkle Depth:** 3D measurement (color-independent)
3. **Pore Size:** Texture pattern (works across tones)
4. **Volume:** Geometry-based (unaffected by color)

**Source:** `Face3DMetricsAnalyzer.swift:444-457`, `SkinToneNormalizer.swift`

---

### 8.3 Score Interpretation

**Overall Score Scale (0-100):**
- **Excellent:** 80-100
- **Good:** 60-79
- **Fair:** 40-59
- **Poor:** 0-39

**Component Weights:**
- Roughness: 30%
- Pigmentation: 25%
- Discoloration: 25%
- Specular (if available): 20%

**Clinical Meaning:**
- **"60 means moderate concern for ANY skin tone"**
- Relative scoring (not absolute thresholds)
- Normalized to ensure fairness

**Source:** `ScanConfiguration.swift:369-380`, `Scoring3D.swift` (referenced)

---

## 9. Edge Case Detection Thresholds

### 9.1 Blockers (Scan Prevented)

**Lighting:**
- Too Dark: < 0.20 brightness + contrast < 0.10
- Too Bright: > 0.85 brightness OR > 10% overexposed pixels

**Makeup:**
- Heavy Foundation: Variance < 50 + saturation > 0.3 (if detection enabled)

**Source:** `EdgeCaseDetector.swift:196-213`

---

### 9.2 Warnings (Allowed to Proceed)

**Glasses:**
- Reflection score + edge patterns + tracking issues > 8.0
- Requires multiple indicators to reduce false positives

**Hands:**
- > 25% of lower face vertices abnormally close to camera

**Hair Coverage:**
- Forehead variance > 600 + brightness < 110 + dark pixel ratio > 40%

**Facial Hair:**
- Relative darkness (skin-tone adaptive) + variance > 500

**Hat/Headband:**
- Non-skin color + fabric texture OR crown coverage OR horizontal edge > 0.3

**Earrings:**
- Bilateral bright spots > 5% OR saturation > 0.35

**Source:** `EdgeCaseDetector.swift:99-243`

---

## 10. Validation & Calibration Checklist

### Pre-Scan Validation (All Must Pass)
- [ ] Lighting: 600-2000 lumens
- [ ] Distance: 0.25-0.60m
- [ ] Stability: < 0.03m movement
- [ ] Face Tracked: isTracked = true
- [ ] Expression: Neutral (all blend shapes < thresholds)
- [ ] Pose: Within ±5° for center position
- [ ] No Blockers: Glasses removed, no heavy makeup, good lighting

### Post-Capture Validation
- [ ] 5 Poses Captured: All guidance steps completed
- [ ] Image Quality: Sharpness > 150, exposure 0.2-0.8
- [ ] Mesh Quality: Manifold + watertight topology
- [ ] Texture Resolution: 2048×2048 minimum
- [ ] ROI Coverage: All key regions > minimum pixels
- [ ] Lighting Consistency: < 30% change across poses

---

## 11. Summary Table: Critical Parameters

| Parameter | Minimum | Optimal | Maximum | Units | Purpose |
|-----------|---------|---------|---------|-------|---------|
| **Lighting** | 600 | 800-1800 | 2000 | lumens | Skin detail visibility |
| **Distance** | 0.25 | 0.30-0.50 | 0.60 | meters | FOV vs detail balance |
| **Dynamic Range** | 0.30 | 0.40+ | - | ratio | Feature contrast |
| **Stability** | - | - | 0.03 | meters | Motion blur prevention |
| **Yaw (Center)** | - | - | ±5 | degrees | Baseline pose |
| **Pitch (Center)** | - | - | ±5 | degrees | Baseline pose |
| **Roll** | - | - | ±8 | degrees | Natural tilt tolerance |
| **Sharpness** | 150 | 200+ | - | variance | Texture clarity |
| **Exposure** | 0.20 | 0.50 | 0.80 | 0-1 scale | Image brightness |
| **Overexposure** | - | <5% | 10% | pixel % | Highlight clipping |
| **Texture Resolution** | 2048 | 2048 | 4096 | pixels | Skin detail capture |
| **ROI Pixels (Major)** | 500 | 1000+ | - | pixels | Region confidence |
| **Processing Timeout** | - | - | 150 | seconds | Analysis completion |

---

## 12. Recommendations for Clinical Validation

### High Priority
1. **Wrinkle Depth Calibration:** Validate 20μm scaling factor with optical profilometer
2. **Redness Detection (Dark Skin):** Implement darkness-based inflammation detection
3. **Pigmentation Normalization:** Test on Fitzpatrick III-VI samples
4. **Lighting Thresholds:** Validate skin-tone-independent dynamic range approach

### Medium Priority
4. **Pose Validation:** Relax thresholds slightly for natural movement tolerance
5. **Sharpness Threshold:** Confirm 150 variance is achievable in real-world conditions
6. **Acne Detection (Dark Skin):** Adjust 30% darkness threshold to 25% for very dark skin

### Low Priority
7. **Color Temperature:** Test adaptive targets across skin tones
8. **Edge Case Detection:** Improve glasses/hands detection accuracy (currently conservative)

---

## Document Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-06 | Initial comprehensive specification | Claude (Tavi Analysis) |

---

**End of Document**

*This specification consolidates requirements from ScanConfiguration.swift, CalibrationManager.swift, ValidationManager.swift, CalibrationState.swift, Face3DMetricsAnalyzer.swift, ImageQualityAnalyzer.swift, EdgeCaseDetector.swift, and CLINICAL_ACCURACY_REVIEW.md*
