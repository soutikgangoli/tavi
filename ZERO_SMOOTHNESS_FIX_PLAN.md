# Zero Smoothness Score - Fix Plan

**Date**: 2025-11-05
**Status**: Ready to implement
**Estimated Time**: 4-6 hours

---

## Fix Priority Matrix

| Issue | Impact | Effort | Priority | Blocks |
|-------|--------|--------|----------|--------|
| Metal GPU texture conversion | CRITICAL | Medium | **P0** | Smoothness scoring |
| Testing mode / capture count | CRITICAL | Low | **P0** | Mesh quality, wrinkles |
| ARKit mesh scaling validation | HIGH | Low | **P1** | Wrinkle depth accuracy |
| Texture sharpness threshold | MEDIUM | Low | **P2** | Texture quality |
| Core Data context | LOW | Medium | **P3** | Persistence only |

---

## P0 Fixes (CRITICAL - Must Fix Immediately)

### Fix #1: Metal GPU Texture Conversion 🚨

**Problem**: CGImage creation fails because `TextureSample.pixels` contains sparse ROI data, not a full 4096×4096 raster.

**File**: `Tavi/Features/FaceScan3D/Utilities/RoughnessAnalyzer.swift`

**Current Code** (lines ~210-280):
```swift
// ❌ Assumes sample.pixels is a full 4096×4096 image
let bytesPerRow = sample.width * 4
let dataProvider = CGDataProvider(data: Data(bytes: sample.pixels, count: sample.pixels.count * 4) as CFData)
let cgImage = CGImage(...)  // Fails - bytesPerRow doesn't match data size
```

**Solution A: Reconstruct Full Raster from ROI Mask** (Recommended):
```swift
func createFullRasterFromSample(_ sample: TextureSample) -> [UInt8]? {
    guard let mask = sample.mask else { return nil }

    let fullWidth = sample.width
    let fullHeight = sample.height
    let totalPixels = fullWidth * fullHeight
    var fullRaster = [UInt8](repeating: 0, count: totalPixels * 4)

    var roiPixelIndex = 0
    for y in 0..<fullHeight {
        for x in 0..<fullWidth {
            let fullIndex = (y * fullWidth + x) * 4
            let maskIndex = y * fullWidth + x

            if maskIndex < mask.count && mask[maskIndex] > 0 {
                // ROI pixel - copy from sample.pixels
                if roiPixelIndex < sample.pixels.count {
                    fullRaster[fullIndex + 0] = sample.pixels[roiPixelIndex]     // R
                    fullRaster[fullIndex + 1] = sample.pixels[roiPixelIndex + 1] // G
                    fullRaster[fullIndex + 2] = sample.pixels[roiPixelIndex + 2] // B
                    fullRaster[fullIndex + 3] = 255                              // A
                    roiPixelIndex += 3
                }
            }
            // else: Leave as black (0,0,0,0) for non-ROI areas
        }
    }

    return fullRaster
}

// Then use fullRaster for CGImage creation
if let fullRaster = createFullRasterFromSample(sample) {
    let dataProvider = CGDataProvider(data: Data(fullRaster) as CFData)
    // ... create CGImage as before
}
```

**Solution B: Use Metal Texture Directly** (Alternative):
```swift
// Skip CGImage entirely - work with Metal textures from the start
func analyzeRoughnessWithMetal(sample: TextureSample) -> Float? {
    // 1. Create Metal texture from sample.pixels + mask
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: sample.width,
        height: sample.height,
        mipmapped: false
    )

    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
        return nil
    }

    // 2. Upload pixels using mask to determine placement
    var fullRaster = createFullRasterFromSample(sample)
    texture.replace(
        region: MTLRegionMake2D(0, 0, sample.width, sample.height),
        mipmapLevel: 0,
        withBytes: &fullRaster,
        bytesPerRow: sample.width * 4
    )

    // 3. Proceed with Metal blur pipeline
    // ... rest of Metal processing
}
```

**Testing Strategy**:
1. Add logging to verify CGImage creation succeeds
2. Compare Metal GPU vs CPU results on same input
3. Verify roughness proxy returns to 0.08-0.25 range

**Expected Outcome**:
- Metal GPU path succeeds (no fallback)
- Roughness proxy: 0.94 → 0.15 (6x improvement)
- Smoothness score: 0 → 85 (correct)

---

### Fix #2: Disable Testing Mode / Increase Capture Count 🚨

**Problem**: Testing mode captures only 1 texture sample, resulting in poor mesh quality and blurry textures.

**Files**:
1. `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`
2. `Tavi/Features/FaceScan3D/Managers/CaptureSequenceManager.swift`

**Current Code** (FaceScan3DViewModel.swift, line ~1200):
```swift
🧪 TESTING MODE: Completing scan after first capture
```

**Solution**:
```swift
// 1. Find and remove/comment out testing mode shortcut
// Search for: "TESTING MODE" or early completion logic

// 2. Ensure proper capture requirements
let requiredTextureSteps: [CaptureStep] = [.center, .left, .right]
let requiredFramesPerStep = 3
let minimumSharpnessThreshold: Float = 150.0  // Increase from current

// 3. Add validation before completing scan
func canCompleteScan() -> Bool {
    guard textureSamples.count >= 3 else {
        AppLogger.capture.warning("Insufficient texture samples: \(textureSamples.count)/3")
        return false
    }

    let avgSharpness = textureSamples.map(\.sharpness).reduce(0, +) / Float(textureSamples.count)
    guard avgSharpness >= 150.0 else {
        AppLogger.capture.warning("Texture too blurry: sharpness=\(avgSharpness)")
        return false
    }

    return true
}
```

**Testing Strategy**:
1. Run scan - verify 3 texture samples captured (center, left, right)
2. Check logs for mesh merge with 9-15 frames (not just 3)
3. Verify topology score improves from 32/100 to 80+/100

**Expected Outcome**:
- Texture samples: 1 → 3
- Mesh captures: 3 → 9-15
- Topology score: 32 → 80+
- Mesh manifold: false → true
- Wrinkle depth: 2.6mm → 0.5-0.8mm (realistic)

---

## P1 Fixes (HIGH Priority)

### Fix #3: ARKit Mesh Scaling Validation

**Problem**: Wrinkle depths are 3x deeper than expected (2.6mm vs <1mm). Possible unit conversion issue.

**File**: `Tavi/Features/FaceScan3D/Metrics/WrinkleAnalyzer.swift`

**Investigation Steps**:
```swift
// Add diagnostic logging to verify ARKit vertex positions are in meters
func analyzeWrinkles(mesh: ARFaceGeometry, transform: simd_float4x4) -> WrinkleAnalysis {
    let vertices = mesh.vertices

    // DIAGNOSTIC: Check vertex coordinate scale
    let vertexDistances = (0..<vertices.count).map { i in
        simd_length(vertices[i])
    }
    let avgDistance = vertexDistances.reduce(0, +) / Float(vertices.count)
    let maxDistance = vertexDistances.max() ?? 0

    AppLogger.mesh.debug("🔍 ARKit Vertex Diagnostics:")
    AppLogger.mesh.debug("   Average distance from origin: \(avgDistance)m")
    AppLogger.mesh.debug("   Max distance from origin: \(maxDistance)m")
    AppLogger.mesh.debug("   Expected for face: ~0.08-0.12m (8-12cm)")

    if avgDistance > 0.5 || avgDistance < 0.05 {
        AppLogger.mesh.warning("⚠️ Suspicious vertex scale - check if units are meters")
    }

    // ... rest of wrinkle analysis
}
```

**Potential Fixes**:

**Option A: Vertices are in millimeters (not meters)**:
```swift
// Convert all vertex positions to meters
let verticesInMeters = vertices.map { vertex in
    SIMD3<Float>(vertex.x / 1000.0, vertex.y / 1000.0, vertex.z / 1000.0)
}
```

**Option B: Curvature calculation is off by constant factor**:
```swift
// Add calibration factor based on known face dimensions
let curvatureCalibrationFactor: Float = 0.33  // Empirically determined
let adjustedDepth = rawDepth * curvatureCalibrationFactor
```

**Testing Strategy**:
1. Print vertex coordinate ranges
2. Compare to ARKit documentation (should be meters)
3. Manually measure known facial feature (e.g., nose bridge width) and compare to vertex distance

**Expected Outcome**:
- Wrinkle depths: 2.6mm → 0.5-0.8mm
- Wrinkle score: 28/100 → 75/100
- Firmness: 17/100 → 75/100

---

## P2 Fixes (MEDIUM Priority)

### Fix #4: Texture Sharpness Threshold

**Problem**: Texture with sharpness=113 is marked as blurry but scan continues.

**File**: `Tavi/Features/FaceScan3D/Utilities/TextureCapture.swift`

**Current Behavior**:
```
✅ TextureCapture: Captured sample - sharpness: 113.486275
Texture quality: Texture too blurry - retake scan
⚠️ Texture too blurry - retake scan
[Scan continues anyway]
```

**Solution**:
```swift
// 1. Increase sharpness threshold
let minimumSharpnessThreshold: Float = 150.0  // Was: 100.0

// 2. Enforce threshold before accepting sample
func captureTextureSample(frame: ARFrame, step: CaptureStep) -> TextureSample? {
    let sample = createSample(from: frame)

    guard sample.sharpness >= minimumSharpnessThreshold else {
        AppLogger.capture.warning("❌ Rejected texture sample: sharpness \(sample.sharpness) < \(minimumSharpnessThreshold)")

        // Provide user feedback
        scanState.feedbackMessage = "Hold still - image is blurry (sharpness: \(Int(sample.sharpness))/150)"
        return nil  // Don't add to samples
    }

    AppLogger.capture.info("✅ Accepted texture sample: sharpness \(sample.sharpness)")
    return sample
}

// 3. Add UI feedback for sharpness
struct CaptureQualityIndicator: View {
    let sharpness: Float

    var body: some View {
        VStack {
            Text("Image Quality")
            ProgressView(value: Double(sharpness), total: 200.0)
            Text("\(Int(sharpness))/200")
                .foregroundColor(sharpness >= 150 ? .green : .red)
        }
    }
}
```

**Expected Outcome**:
- Rejected samples: 0 → 1-3 (retries until sharp)
- Average sharpness: 113 → 160+
- Texture quality warning: Gone

---

## P3 Fixes (LOW Priority - Not Blocking)

### Fix #5: Core Data Context Availability

**Problem**: Core Data context not available in async processing tasks.

**File**: `Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift`

**Current Workaround**: JSON fallback storage works fine.

**Proper Fix** (if needed):
```swift
// Pass viewContext explicitly to processing tasks
func startProcessing() async {
    let context = PersistenceController.shared.container.viewContext

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            await self.processMetrics(context: context)
        }
    }
}

func processMetrics(context: NSManagedObjectContext) async {
    // Use context for Core Data operations
    await context.perform {
        let session = ScanSession(context: context)
        // ... save
    }
}
```

**Priority**: LOW - Current fallback works fine, this is just cleanup.

---

## Implementation Order

### Phase 1: Critical Fixes (Day 1)
1. ✅ Fix Metal GPU texture conversion (Fix #1)
2. ✅ Disable testing mode (Fix #2)
3. ✅ Test scan - verify improvements

**Success Criteria**:
- Metal GPU path succeeds (no "falling back to CPU")
- 3 texture samples captured
- Smoothness score > 60/100

### Phase 2: Wrinkle Depth Fix (Day 1-2)
4. ✅ Add ARKit vertex diagnostics (Fix #3)
5. ✅ Determine if scaling issue exists
6. ✅ Apply calibration fix
7. ✅ Test scan - verify wrinkle depths <1mm

**Success Criteria**:
- Wrinkle depths: <1.0mm for young skin
- Firmness score: >60/100

### Phase 3: Polish (Day 2)
8. ✅ Increase sharpness threshold (Fix #4)
9. ✅ Add UI quality feedback
10. ⚠️ (Optional) Fix Core Data context (Fix #5)

**Success Criteria**:
- All texture samples >150 sharpness
- No quality warnings

---

## Testing Protocol

### Before Fixes:
```
✅ BASELINE TEST
Run scan, record:
- Smoothness: ____ / 100
- Firmness: ____ / 100
- Roughness Proxy: ____
- Wrinkle Depth: ____ mm
- Metal GPU: Success / Failed
- Texture Samples: ____
- Mesh Topology Score: ____ / 100
```

### After Fix #1 (Metal GPU):
```
✅ TEST 1: Metal GPU Fix
Expected:
- Metal GPU: Success ✅
- Roughness Proxy: 0.08-0.25 (was 0.94)
- Smoothness: 60-85 (was 0)
Actual:
- Metal GPU: ______
- Roughness Proxy: ______
- Smoothness: ______ / 100
```

### After Fix #2 (Testing Mode):
```
✅ TEST 2: Full Capture Sequence
Expected:
- Texture Samples: 3 (was 1)
- Mesh Captures: 9-15 (was 3)
- Topology Score: 80+ (was 32)
- Wrinkle Depth: 0.5-0.8mm (was 2.6mm)
Actual:
- Texture Samples: ______
- Mesh Captures: ______
- Topology Score: ______ / 100
- Wrinkle Depth: ______ mm
```

### After Fix #3 (Mesh Scaling):
```
✅ TEST 3: Wrinkle Depth Calibration
Expected:
- Wrinkle Depth: <1.0mm
- Wrinkle Score: 70-85
- Firmness: 70-85
Actual:
- Wrinkle Depth: ______ mm
- Wrinkle Score: ______ / 100
- Firmness: ______ / 100
```

### Final Validation:
```
✅ FINAL TEST: End-to-End
For young, healthy skin:
Expected Scores:
- Smoothness: 70-85 ✅
- Firmness: 70-85 ✅
- Evenness: 60-80 ✅
- Clarity: 65-80 ✅
- Overall: 70-85 ✅

Actual Scores:
- Smoothness: ______ / 100
- Firmness: ______ / 100
- Evenness: ______ / 100
- Clarity: ______ / 100
- Overall: ______ / 100
```

---

## Rollback Plan

If fixes cause regressions:

1. **Metal GPU Fix**: Revert to CPU fallback (current behavior)
2. **Testing Mode**: Re-enable for quick testing
3. **Mesh Scaling**: Remove calibration factor

All changes are isolated to specific files and can be reverted independently.

---

## Success Metrics

**Before Fixes**:
- Smoothness: 0/100 ❌
- Firmness: 17/100 ❌
- Roughness: 0.94 (6x too high) ❌
- Wrinkles: 2.6mm deep (3x too deep) ❌

**After Fixes**:
- Smoothness: 70-85/100 ✅
- Firmness: 70-85/100 ✅
- Roughness: 0.08-0.25 ✅
- Wrinkles: <1.0mm deep ✅

---

## Estimated Time

| Phase | Tasks | Time |
|-------|-------|------|
| Fix #1: Metal GPU | Solution A implementation + testing | 2-3 hours |
| Fix #2: Testing Mode | Remove testing shortcut + validation | 30 min |
| Fix #3: Mesh Scaling | Diagnostics + calibration | 1-2 hours |
| Fix #4: Sharpness | Threshold + UI feedback | 1 hour |
| Testing | 4 test cycles | 1-2 hours |
| **Total** | | **5-8 hours** |

---

## Open Questions

1. **Metal GPU Fix**: Should we use Solution A (reconstruct raster) or Solution B (Metal-native)?
   - **Recommendation**: Solution A is simpler and lower risk.

2. **Testing Mode**: Where is the testing mode shortcut? Need to search codebase.
   - Search terms: "TESTING MODE", "testing", "scan_completed_after_first"

3. **Mesh Scaling**: Are ARKit vertices guaranteed to be in meters?
   - **Action**: Check ARKit documentation + add diagnostic logging.

4. **Texture Sharpness**: What algorithm computes sharpness? Is threshold of 150 reasonable?
   - **Action**: Review TextureCapture.swift implementation.

---

## Next Steps

1. User approval of this plan
2. Begin Phase 1 implementation
3. Test after each fix
4. Document results

**Ready to proceed?**
