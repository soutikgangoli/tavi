# Analyzer Optimization Plan & Current State

## Executive Summary

The face scan analysis pipeline was hanging for 2+ minutes due to CPU-bound analyzers processing 4096x4096 textures (16.7M pixels) with multiple passes. Temporary fix applied: downsampling to 1024x1024. This document outlines the proper GPU migration plan for clinical-grade accuracy.

---

## Current State of Analyzers

### Performance Status

| Analyzer | Execution | Resolution | Status | Clinical Impact |
|----------|-----------|------------|--------|-----------------|
| RoughnessAnalyzer | **GPU (Metal)** | Full res | ✅ Optimized | High accuracy |
| HydrationEstimator | CPU | 1024x1024* | ⚠️ Downsampled | Reduced precision |
| GlowAnalyzer | CPU | 1024x1024* | ⚠️ Downsampled | Reduced precision |
| PoreAnalyzer | CPU | 1024x1024* | ⚠️ Downsampled | Reduced precision |
| AcneAnalyzer | CPU | 1024x1024* | ⚠️ Downsampled | Reduced precision |
| RednessAnalyzer | CPU | 1024x1024* | ⚠️ Downsampled | Reduced precision |
| RegionalAnalyzers | CPU | 1024x1024* | ⚠️ Downsampled | Minor impact |
| TopologyAnalyzer | CPU | N/A (mesh) | ✅ OK | Full accuracy |
| VolumeAnalyzer | CPU | N/A (mesh) | ✅ OK | Full accuracy |

*Downsampling applied as temporary fix - reduces 16.7M pixels to 1M pixels (16x reduction)

### Clinical Accuracy Concerns

**Current Issues with Downsampling:**

1. **Pore Detection** - Small pores (< 3 pixels at full res) may be missed at 1024x1024
2. **Acne Detection** - Small blemishes may merge or disappear
3. **Fine Texture Analysis** - High-frequency skin texture details lost
4. **Specular Highlights** - Small reflection points averaged out

**Metrics Most Affected:**
- Pore count and size distribution
- Small blemish detection
- Fine wrinkle detection
- Micro-texture roughness

**Metrics Less Affected:**
- Overall color/pigmentation (statistical)
- Redness levels (statistical)
- Hydration estimation (statistical)
- Regional brightness comparisons

---

## Critical GPU Implementation Patterns

### Parallel Reduction Strategy

**Problem:** Direct atomic operations from 16.7M threads cause severe contention:
```metal
// BAD - Will bottleneck performance
atomic_fetch_add(&result->sum, value);  // 16.7M threads competing
```

**Solution:** Hierarchical reduction using threadgroup memory:
```metal
// GOOD - Two-stage reduction
kernel void reduceWithThreadgroups(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialSums [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]],
    uint groupSize [[threads_per_threadgroup]]
) {
    // Stage 1: Each thread computes its value
    float4 pixel = texture.read(gid);
    float value = computeMetric(pixel);

    // Stage 2: Reduce within threadgroup using shared memory
    threadgroup float localSums[256];
    localSums[tid] = value;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction within threadgroup
    for (uint stride = groupSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localSums[tid] += localSums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Stage 3: Write one value per threadgroup
    if (tid == 0) {
        partialSums[groupId] = localSums[0];
    }
}

// Final reduction on CPU (small array) or second GPU pass
```

**Performance Impact:**
- Without reduction: ~500ms (contention)
- With threadgroup reduction: ~5ms

### Proper Laplacian Kernel (8-Neighbor)

For accurate skin texture analysis, use the full 8-neighbor Laplacian:
```metal
float computeLaplacian8(texture2d<float, access::read> tex, uint2 gid) {
    float center = luminance(tex.read(gid));

    // 8 neighbors
    float top       = luminance(tex.read(gid + uint2(0, -1)));
    float bottom    = luminance(tex.read(gid + uint2(0,  1)));
    float left      = luminance(tex.read(gid + uint2(-1, 0)));
    float right     = luminance(tex.read(gid + uint2( 1, 0)));
    float topLeft   = luminance(tex.read(gid + uint2(-1, -1)));
    float topRight  = luminance(tex.read(gid + uint2( 1, -1)));
    float botLeft   = luminance(tex.read(gid + uint2(-1,  1)));
    float botRight  = luminance(tex.read(gid + uint2( 1,  1)));

    // 8-neighbor Laplacian: center weight = 8
    return 8.0 * center - (top + bottom + left + right + topLeft + topRight + botLeft + botRight);
}
```

### Proper RGB to LAB Conversion

The L* channel requires proper color space conversion:
```metal
// Helper: Apply gamma correction (sRGB to linear)
float3 srgbToLinear(float3 srgb) {
    float3 linear;
    for (int i = 0; i < 3; i++) {
        float c = srgb[i];
        linear[i] = (c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
    }
    return linear;
}

// Helper: Linear RGB to XYZ (D65 illuminant)
float3 linearRgbToXyz(float3 rgb) {
    float3x3 matrix = float3x3(
        float3(0.4124564, 0.3575761, 0.1804375),
        float3(0.2126729, 0.7151522, 0.0721750),
        float3(0.0193339, 0.1191920, 0.9503041)
    );
    return matrix * rgb;
}

// Helper: XYZ to LAB
float xyzToLabComponent(float t) {
    const float delta = 6.0 / 29.0;
    const float delta3 = delta * delta * delta;
    return (t > delta3) ? pow(t, 1.0/3.0) : (t / (3.0 * delta * delta)) + (4.0/29.0);
}

float computeLStar(float3 srgb) {
    // D65 reference white
    const float3 refWhite = float3(0.95047, 1.0, 1.08883);

    float3 linear = srgbToLinear(srgb);
    float3 xyz = linearRgbToXyz(linear);

    float fy = xyzToLabComponent(xyz.y / refWhite.y);
    float lStar = 116.0 * fy - 16.0;

    return lStar;
}
```

**Simplified Alternative (if full LAB not needed):**
```metal
// Perceptual luminance (not L*, but fast and reasonable)
float perceptualLuminance(float3 rgb) {
    return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}
```

---

## Device Compatibility

### Minimum Requirements

| Feature | Minimum | Recommended |
|---------|---------|-------------|
| Metal Family | Apple 3 (A9+) | Apple 5 (A12+) |
| iOS Version | 14.0 | 15.0+ |
| Texture Size | 4096x4096 | 8192x8192 |
| Threadgroup Memory | 16KB | 32KB |

### Capability Checks

```swift
func checkGPUCapabilities() -> Bool {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return false
    }

    // Check Metal family support
    guard device.supportsFamily(.apple3) else {
        Logger.warning("Device does not support Apple 3 GPU family")
        return false
    }

    // Check max texture size
    let maxTextureSize = device.supportsFamily(.apple3) ? 16384 : 8192
    guard maxTextureSize >= 4096 else {
        return false
    }

    // Check threadgroup memory (need at least 16KB for reduction)
    let maxThreadgroupMemory = device.maxThreadgroupMemoryLength
    guard maxThreadgroupMemory >= 16384 else {
        return false
    }

    return true
}
```

### Fallback Strategy

```swift
func analyzeTexture(_ texture: MTLTexture) async -> AnalysisResult {
    if MetalCapabilities.shared.supportsGPUAnalysis {
        return await gpuAnalyze(texture)
    } else {
        // Fall back to CPU with downsampling
        Logger.info("GPU not available, using CPU fallback")
        return await cpuAnalyzeDownsampled(texture)
    }
}
```

---

## Memory Management

### Texture Pooling

Reuse textures to avoid allocation overhead:
```swift
class TexturePool {
    private var available: [MTLTexture] = []
    private let device: MTLDevice
    private let maxPoolSize = 4

    func acquire(width: Int, height: Int, format: MTLPixelFormat) -> MTLTexture {
        // Check pool for compatible texture
        if let index = available.firstIndex(where: {
            $0.width == width && $0.height == height && $0.pixelFormat == format
        }) {
            return available.remove(at: index)
        }

        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        return device.makeTexture(descriptor: descriptor)!
    }

    func release(_ texture: MTLTexture) {
        if available.count < maxPoolSize {
            available.append(texture)
        }
        // Else: texture will be deallocated
    }
}
```

### Buffer Management

```swift
class AnalysisBufferManager {
    // Reusable result buffers
    private var resultBuffer: MTLBuffer?
    private var partialSumsBuffer: MTLBuffer?

    func getResultBuffer(device: MTLDevice, size: Int) -> MTLBuffer {
        if let buffer = resultBuffer, buffer.length >= size {
            return buffer
        }
        resultBuffer = device.makeBuffer(length: size, options: .storageModeShared)
        return resultBuffer!
    }

    func getPartialSumsBuffer(device: MTLDevice, threadgroupCount: Int) -> MTLBuffer {
        let size = threadgroupCount * MemoryLayout<Float>.stride
        if let buffer = partialSumsBuffer, buffer.length >= size {
            return buffer
        }
        partialSumsBuffer = device.makeBuffer(length: size, options: .storageModeShared)
        return partialSumsBuffer!
    }
}
```

### Pipeline State Caching

Create pipeline states once at initialization:
```swift
class MetalAnalyzerBase {
    private var pipelineStates: [String: MTLComputePipelineState] = [:]

    func loadPipeline(named functionName: String) throws -> MTLComputePipelineState {
        if let cached = pipelineStates[functionName] {
            return cached
        }

        guard let function = library.makeFunction(name: functionName) else {
            throw AnalyzerError.functionNotFound(functionName)
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        pipelineStates[functionName] = pipeline
        return pipeline
    }
}
```

---

## Error Handling

### GPU Error Recovery

```swift
enum GPUAnalysisError: Error {
    case deviceNotAvailable
    case pipelineCreationFailed(String)
    case commandBufferFailed(MTLCommandBufferError)
    case timeout
    case insufficientMemory
}

func executeGPUAnalysis(commandBuffer: MTLCommandBuffer) async throws -> AnalysisResult {
    return try await withCheckedThrowingContinuation { continuation in
        commandBuffer.addCompletedHandler { buffer in
            if let error = buffer.error {
                // Log detailed error info
                Logger.error("GPU command buffer failed: \(error)")

                // Attempt recovery or fallback
                continuation.resume(throwing: GPUAnalysisError.commandBufferFailed(
                    error as! MTLCommandBufferError
                ))
            } else {
                let result = self.readResultsFromBuffer()
                continuation.resume(returning: result)
            }
        }

        commandBuffer.commit()
    }
}

func analyzeWithFallback(_ texture: MTLTexture) async -> AnalysisResult {
    do {
        return try await executeGPUAnalysis(texture)
    } catch {
        Logger.warning("GPU analysis failed, falling back to CPU: \(error)")
        return await cpuAnalyzeDownsampled(texture)
    }
}
```

### Timeout Protection

```swift
func analyzeWithTimeout(_ texture: MTLTexture, timeout: TimeInterval = 5.0) async throws -> AnalysisResult {
    return try await withThrowingTaskGroup(of: AnalysisResult.self) { group in
        group.addTask {
            try await self.gpuAnalyze(texture)
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw GPUAnalysisError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

---

## GPU Migration Plan

### Priority 1: HydrationEstimator (Highest Impact)

**Current CPU Operations:**
```
Method 1: analyzeSpecularity() - Full texture scan for bright pixels
Method 2: analyzeTextureFrequency() - Laplacian filter (convolution)
Method 3: analyzeColorVariance() - Statistical variance calculation
+ 6 regional scans
Total: ~9 full texture passes = 150M pixel operations
```

**GPU Implementation:**
```metal
// Single-pass analysis with threadgroup reduction
kernel void analyzeHydration(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialSpecular [[buffer(0)]],
    device float* partialLaplacian [[buffer(1)]],
    device float* partialVariance [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= texture.get_width() || gid.y >= texture.get_height()) return;

    float4 pixel = texture.read(gid);

    // Metric 1: Specularity
    float brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
    float specular = brightness > 0.85 ? 1.0 : 0.0;

    // Metric 2: Texture frequency (8-neighbor Laplacian)
    float laplacian = abs(computeLaplacian8(texture, gid));

    // Metric 3: Color variance component
    float mean = brightness;
    float variance = (pixel.r - mean) * (pixel.r - mean) +
                     (pixel.g - mean) * (pixel.g - mean) +
                     (pixel.b - mean) * (pixel.b - mean);

    // Threadgroup reduction
    threadgroup float localSpecular[256];
    threadgroup float localLaplacian[256];
    threadgroup float localVariance[256];

    localSpecular[tid] = specular;
    localLaplacian[tid] = laplacian;
    localVariance[tid] = variance;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint s = 128; s > 0; s >>= 1) {
        if (tid < s) {
            localSpecular[tid] += localSpecular[tid + s];
            localLaplacian[tid] += localLaplacian[tid + s];
            localVariance[tid] += localVariance[tid + s];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSpecular[groupId] = localSpecular[0];
        partialLaplacian[groupId] = localLaplacian[0];
        partialVariance[groupId] = localVariance[0];
    }
}
```

---

### Priority 2: PoreAnalyzer

**Current CPU Operations:**
```
- High-frequency energy detection (Laplacian convolution)
- Local minima detection for pore centers
- Size classification per detected pore
```

**GPU Implementation:**
```metal
// Pass 1: Laplacian convolution with 8-neighbor kernel
kernel void computePoreLaplacian(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x == 0 || gid.y == 0 ||
        gid.x >= input.get_width() - 1 || gid.y >= input.get_height() - 1) {
        output.write(float4(0), gid);
        return;
    }

    float laplacian = computeLaplacian8(input, gid);
    output.write(float4(laplacian, 0, 0, 1), gid);
}

// Pass 2: Local minima detection (pore centers are dark spots)
kernel void detectPoreMinima(
    texture2d<float, access::read> laplacianMap [[texture(0)]],
    device atomic_uint* poreCount [[buffer(0)]],
    device PoreLocation* poreLocations [[buffer(1)]],
    constant uint& maxPores [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float center = laplacianMap.read(gid).r;

    // Skip if not a significant response
    if (center < 0.1) return;

    // Check if local maximum (high Laplacian = pore edge)
    bool isLocalMax = true;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            float neighbor = laplacianMap.read(gid + uint2(dx, dy)).r;
            if (neighbor >= center) {
                isLocalMax = false;
                break;
            }
        }
        if (!isLocalMax) break;
    }

    if (isLocalMax) {
        uint index = atomic_fetch_add_explicit(poreCount, 1, memory_order_relaxed);
        if (index < maxPores) {
            poreLocations[index] = PoreLocation{gid.x, gid.y, center};
        }
    }
}
```

---

### Priority 3: RednessAnalyzer

**GPU Implementation:**
```metal
kernel void analyzeRedness(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialRedness [[buffer(0)]],
    device float* partialInflamed [[buffer(1)]],
    constant float& threshold [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]]
) {
    if (gid.x >= texture.get_width() || gid.y >= texture.get_height()) return;

    float4 pixel = texture.read(gid);

    // Redness index: how much redder than other channels
    // Normalized to skin tone
    float rednessIndex = pixel.r - (pixel.g + pixel.b) / 2.0;

    // Inflammation detection with adaptive threshold
    float isInflamed = rednessIndex > threshold ? 1.0 : 0.0;

    // Threadgroup reduction
    threadgroup float localRedness[256];
    threadgroup float localInflamed[256];

    localRedness[tid] = max(0.0, rednessIndex);
    localInflamed[tid] = isInflamed;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint s = 128; s > 0; s >>= 1) {
        if (tid < s) {
            localRedness[tid] += localRedness[tid + s];
            localInflamed[tid] += localInflamed[tid + s];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialRedness[groupId] = localRedness[0];
        partialInflamed[groupId] = localInflamed[0];
    }
}
```

---

### Priority 4: GlowAnalyzer

**GPU Implementation:**
```metal
kernel void analyzeGlow(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialLightness [[buffer(0)]],
    device float* partialSpecular [[buffer(1)]],
    device float* partialUniformity [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]]
) {
    if (gid.x >= texture.get_width() || gid.y >= texture.get_height()) return;

    float4 rgb = texture.read(gid);

    // Proper L* calculation (or use simplified luminance)
    float lStar = computeLStar(rgb.rgb);

    // Specular detection (bright highlights)
    float brightness = (rgb.r + rgb.g + rgb.b) / 3.0;
    float isSpecular = brightness > 0.85 ? 1.0 : 0.0;

    // For uniformity: compute local deviation
    float localMean = sampleNeighborhoodMean(texture, gid, 3);
    float deviation = abs(brightness - localMean);

    // Threadgroup reduction
    threadgroup float localL[256];
    threadgroup float localS[256];
    threadgroup float localU[256];

    localL[tid] = lStar;
    localS[tid] = isSpecular;
    localU[tid] = deviation;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint s = 128; s > 0; s >>= 1) {
        if (tid < s) {
            localL[tid] += localL[tid + s];
            localS[tid] += localS[tid + s];
            localU[tid] += localU[tid + s];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialLightness[groupId] = localL[0];
        partialSpecular[groupId] = localS[0];
        partialUniformity[groupId] = localU[0];
    }
}
```

---

### Priority 5: AcneAnalyzer (Hybrid GPU/CPU)

**GPU Part - Darkness Detection:**
```metal
kernel void detectDarknessVariations(
    texture2d<float, access::read> texture [[texture(0)]],
    texture2d<float, access::write> darknessMap [[texture(1)]],
    constant int& sampleRadius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= texture.get_width() || gid.y >= texture.get_height()) return;

    float4 pixel = texture.read(gid);
    float centerLum = perceptualLuminance(pixel.rgb);

    // Sample neighborhood average
    float sum = 0.0;
    int count = 0;
    for (int dy = -sampleRadius; dy <= sampleRadius; dy++) {
        for (int dx = -sampleRadius; dx <= sampleRadius; dx++) {
            if (dx == 0 && dy == 0) continue;
            uint2 samplePos = uint2(
                clamp(int(gid.x) + dx, 0, int(texture.get_width()) - 1),
                clamp(int(gid.y) + dy, 0, int(texture.get_height()) - 1)
            );
            sum += perceptualLuminance(texture.read(samplePos).rgb);
            count++;
        }
    }
    float neighborhoodAvg = sum / float(count);

    // Darkness relative to surroundings (positive = darker than neighbors)
    float darkness = neighborhoodAvg - centerLum;

    darknessMap.write(float4(darkness, centerLum, neighborhoodAvg, 1.0), gid);
}
```

**CPU Part - Blemish Classification:**
- Connected component analysis on darkness map
- Size and shape classification
- Severity scoring based on darkness intensity and size

---

## Implementation Roadmap

### Phase 1: Infrastructure
- [ ] Create `MetalAnalyzerBase` class with shared GPU utilities
- [ ] Implement threadgroup reduction helpers
- [ ] Add texture pool and buffer management
- [ ] Create pipeline state caching system
- [ ] Add device capability checks and fallback logic

### Phase 2: HydrationEstimator GPU
- [ ] Write `HydrationAnalysis.metal` shader with reduction
- [ ] Implement Swift wrapper with buffer management
- [ ] Validate results against CPU baseline (±3% tolerance)
- [ ] Remove downsampling, use full resolution
- [ ] Add timeout protection

### Phase 3: PoreAnalyzer GPU
- [ ] Write `PoreDetection.metal` with 8-neighbor Laplacian
- [ ] Implement local maxima detection pass
- [ ] Validate pore count accuracy (±5% tolerance)
- [ ] Handle edge cases at texture boundaries

### Phase 4: RednessAnalyzer GPU
- [ ] Write `RednessAnalysis.metal` shader
- [ ] Implement per-pixel redness with reduction
- [ ] Validate inflammation detection (±2% tolerance)
- [ ] Test across Fitzpatrick skin types I-VI

### Phase 5: GlowAnalyzer GPU
- [ ] Write `GlowAnalysis.metal` shader
- [ ] Implement proper L* or documented luminance alternative
- [ ] Validate lightness measurements (±2% tolerance)
- [ ] Add uniformity calculation

### Phase 6: AcneAnalyzer Hybrid
- [ ] Write `DarknessDetection.metal` shader
- [ ] Keep connected component analysis on CPU
- [ ] Validate blemish detection accuracy (±5% tolerance)

---

## Clinical Accuracy Validation

### Test Protocol

For each GPU-migrated analyzer:

1. **Baseline Capture**
   - Run CPU version at full resolution (no downsampling)
   - Record all metrics for 10 test images

2. **GPU Validation**
   - Run GPU version on same 10 images
   - Compare metrics: should be within tolerance of CPU baseline

3. **Edge Cases**
   - Very dark skin (Fitzpatrick V-VI)
   - Very light skin (Fitzpatrick I-II)
   - High specular lighting
   - Low light conditions

### Acceptance Criteria

| Metric | Tolerance |
|--------|-----------|
| Pore count | ±5% |
| Blemish count | ±5% |
| Redness score | ±2% |
| Hydration score | ±3% |
| Glow/radiance score | ±2% |

---

## Files to Modify

### New Metal Shader Files
```
Tavi/Features/FaceScan3D/Metal/
├── AnalyzerCommon.metal      (shared functions: Laplacian, LAB, reduction)
├── HydrationAnalysis.metal
├── PoreDetection.metal
├── RednessAnalysis.metal
├── GlowAnalysis.metal
└── DarknessDetection.metal
```

### New Swift Infrastructure
```
Tavi/Features/FaceScan3D/Metal/
├── MetalAnalyzerBase.swift   (base class with shared utilities)
├── TexturePool.swift         (texture memory management)
└── MetalCapabilities.swift   (device checks and fallback)
```

### Existing Files to Update
```
Tavi/Features/FaceScan3D/Metrics/
├── HydrationEstimator.swift    → Add Metal code path
├── PoreAnalyzer.swift          → Add Metal code path
├── RednessAnalyzer.swift       → Add Metal code path
├── GlowAnalyzer.swift          → Add Metal code path
└── AcneAnalyzer.swift          → Add Metal code path (partial)
```

---

## Temporary Downsampling Status

**Files with downsampling applied (to be removed after GPU migration):**

1. `HydrationEstimator.swift` - Line 60-84, Line 103-108
2. `GlowAnalyzer.swift` - Line 24-48, Line 82-89
3. `PoreAnalyzer.swift` - Line 97-116, Line 130-140
4. `AcneAnalyzer.swift` - Line 71-90, Line 117-127
5. `RednessAnalyzer.swift` - Line 57-76, Line 104-114
6. `RegionalAnalyzers.swift` - Line 83-102, Line 112-118

**Downsampling function to remove from each:**
```swift
private func downsample(_ image: CGImage, maxSize: Int? = nil) -> CGImage? {
    // This entire function should be removed after GPU migration
}
```

---

## Summary

**Current State:** Analyzers working but with reduced precision due to 1024x1024 downsampling
**Target State:** Full 4096x4096 resolution with GPU acceleration, clinical-grade accuracy
**Priority:** HydrationEstimator → PoreAnalyzer → RednessAnalyzer → GlowAnalyzer → AcneAnalyzer

### Key Technical Requirements
1. Use threadgroup reduction (not direct atomics) for all aggregations
2. Use 8-neighbor Laplacian for texture analysis
3. Use proper LAB conversion or document the simplification
4. Implement device capability checks with CPU fallback
5. Pool textures and cache pipeline states for memory efficiency
6. Add timeout protection for GPU operations
