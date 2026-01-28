//
//  GlowAnalysis.metal
//  Ollvy
//
//  GPU-accelerated glow and radiance analysis shader
//  Computes LAB lightness (L*), specular highlights, and skin uniformity
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

/// Specular highlight relative multiplier above baseline skin brightness
constant float SPECULAR_RELATIVE_MULTIPLIER = 1.25;

/// Maximum absolute specular threshold (never exceed even if multiplier would)
constant float SPECULAR_MAX_THRESHOLD = 0.95;

// MARK: - Structures

/// Partial results from each threadgroup
struct GlowPartialResults {
    float lightnessSum;        // Sum of L* values (0-100 range)
    float specularPixelCount;  // Count of bright specular pixels
    float uniformitySum;       // Sum of local uniformity values
    float validPixelCount;     // Total pixels processed
};

// MARK: - Helper Functions

/// Convert sRGB to Linear RGB
inline float3 sRGBToLinear(float3 srgb) {
    float3 linear;
    for (int i = 0; i < 3; i++) {
        if (srgb[i] <= 0.04045) {
            linear[i] = srgb[i] / 12.92;
        } else {
            linear[i] = pow((srgb[i] + 0.055) / 1.055, 2.4);
        }
    }
    return linear;
}

/// Convert Linear RGB to XYZ color space (D65 illuminant)
inline float3 linearRGBToXYZ(float3 linear) {
    float3 xyz;
    xyz.x = 0.4124564 * linear.r + 0.3575761 * linear.g + 0.1804375 * linear.b;
    xyz.y = 0.2126729 * linear.r + 0.7151522 * linear.g + 0.0721750 * linear.b;
    xyz.z = 0.0193339 * linear.r + 0.1191920 * linear.g + 0.9503041 * linear.b;
    return xyz;
}

/// LAB transformation function - converts normalized XYZ component to LAB space
inline float glowLabTransformFunction(float t) {
    const float delta = 6.0 / 29.0;
    const float delta3 = delta * delta * delta;  // 0.008856
    if (t > delta3) {
        return pow(t, 1.0/3.0);
    } else {
        return (t / (3.0 * delta * delta)) + (4.0 / 29.0);
    }
}

/// Convert XYZ to LAB color space
inline float3 xyzToLAB(float3 xyz) {
    // D65 reference white point
    const float3 refWhite = float3(0.95047, 1.00000, 1.08883);

    // Normalize by reference white
    float3 normalized = xyz / refWhite;

    // Apply LAB transformation function
    float fx = glowLabTransformFunction(normalized.x);
    float fy = glowLabTransformFunction(normalized.y);
    float fz = glowLabTransformFunction(normalized.z);

    // Calculate L*a*b* values
    float L = 116.0 * fy - 16.0;  // L* (lightness): 0-100
    float a = 500.0 * (fx - fy);   // a* (green-red)
    float b = 200.0 * (fy - fz);   // b* (blue-yellow)

    return float3(L, a, b);
}

/// Convert sRGB directly to LAB L* (lightness)
/// Returns L* value in range 0-100
inline float computeLStar(float3 srgb) {
    float3 linear = sRGBToLinear(srgb);
    float3 xyz = linearRGBToXYZ(linear);
    float3 lab = xyzToLAB(xyz);
    return lab.x;  // L* component
}

/// Calculate local uniformity around a pixel
/// Returns 1.0 - (average deviation from neighbors)
inline float calculateUniformity(
    texture2d<float, access::read> texture,
    uint2 gid
) {
    uint width = texture.get_width();
    uint height = texture.get_height();

    // Need border for 3x3 window
    if (gid.x < 1 || gid.x >= width - 1 ||
        gid.y < 1 || gid.y >= height - 1) {
        return 1.0;  // Assume perfect uniformity at borders
    }

    // Read center pixel brightness
    float4 centerColor = texture.read(gid);
    float centerBrightness = (centerColor.r + centerColor.g + centerColor.b) / 3.0;

    // Calculate average deviation from 8 neighbors
    float totalDeviation = 0.0;
    int neighborCount = 0;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;  // Skip center

            uint2 neighborPos = uint2(gid.x + dx, gid.y + dy);
            float4 neighborColor = texture.read(neighborPos);
            float neighborBrightness = (neighborColor.r + neighborColor.g + neighborColor.b) / 3.0;

            totalDeviation += abs(centerBrightness - neighborBrightness);
            neighborCount++;
        }
    }

    float avgDeviation = totalDeviation / float(neighborCount);

    // Return uniformity: 1.0 = perfectly uniform, 0.0 = maximum variation
    return 1.0 - clamp(avgDeviation * 4.0, 0.0, 1.0);  // Scale deviation to 0-1
}

// MARK: - Baseline Brightness Calculation

/// Calculate baseline skin brightness from center region
/// Used for relative specular threshold
/// FIXED: Now uses partial results per threadgroup to avoid race conditions
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void calculateBaselineBrightness(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device float* partialBrightness [[buffer(0)]],    // One per threadgroup
    device float* partialCounts [[buffer(1)]],        // One per threadgroup
    constant uint& threadgroupsPerRow [[buffer(2)]],  // For linear indexing
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localBrightnessSum[256];
    threadgroup float localPixelCount[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    float brightnessSum = 0.0;
    float pixelCount = 0.0;

    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Sample center region (50% of image)
    uint centerX = width / 2;
    uint centerY = height / 2;
    uint sampleRadius = min(width, height) / 4;

    uint minX = centerX - sampleRadius;
    uint maxX = centerX + sampleRadius;
    uint minY = centerY - sampleRadius;
    uint maxY = centerY + sampleRadius;

    if (gid.x >= minX && gid.x < maxX && gid.y >= minY && gid.y < maxY) {
        float4 color = inputTexture.read(gid);
        float brightness = (color.r + color.g + color.b) / 3.0;
        brightnessSum = brightness;
        pixelCount = 1.0;
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localBrightnessSum[tid] = brightnessSum;
    localPixelCount[tid] = pixelCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction within threadgroup
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localBrightnessSum[tid] += localBrightnessSum[tid + stride];
            localPixelCount[tid] += localPixelCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes threadgroup partial results to global memory
    // CPU will aggregate all partial results
    if (tid == 0) {
        partialBrightness[threadgroupIndex] = localBrightnessSum[0];
        partialCounts[threadgroupIndex] = localPixelCount[0];
    }
}

// MARK: - Main Glow Analysis Kernel

/// Comprehensive glow analysis with threadgroup reduction
/// Computes LAB L* lightness, specular highlights, and skin uniformity
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
/// The Swift code MUST dispatch with threadsPerThreadgroup = MTLSize(16, 16, 1)
kernel void analyzeGlow(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device GlowPartialResults* partialResults [[buffer(0)]],
    constant float& baselineBrightness [[buffer(1)]],
    constant uint& threadgroupsPerRow [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    // Swift code MUST dispatch with exactly 256 threads per threadgroup
    // Using smaller arrays causes out-of-bounds; larger wastes shared memory
    threadgroup float localLightness[256];
    threadgroup float localSpecular[256];
    threadgroup float localUniformity[256];
    threadgroup float localValidPixels[256];

    // Safety check: bail out if thread index exceeds array bounds
    // This prevents crashes if dispatch configuration is wrong
    if (threadIndexInGroup >= 256) {
        return;
    }

    // Initialize local values
    float lightnessValue = 0.0;
    float specularCount = 0.0;
    float uniformityValue = 0.0;
    float validPixels = 0.0;

    // Check if this thread is processing a valid pixel
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    if (gid.x < width && gid.y < height) {
        // Read pixel color
        float4 color = inputTexture.read(gid);

        // FIX: Skip black/near-black pixels which are likely texture background
        // Skin texture maps often have black borders/padding that would drag down averages
        // Threshold: brightness < 0.05 (RGB average < 13/255)
        float brightness = (color.r + color.g + color.b) / 3.0;
        if (brightness < 0.05) {
            // Don't count this pixel - it's background
            validPixels = 0.0;
        } else {
            validPixels = 1.0;

            // METRIC 1: LAB Lightness (L*)
            // Perceptually uniform measure of brightness (0-100)
            lightnessValue = computeLStar(color.rgb);

            // METRIC 2: Specular Highlight Detection
            // Detect bright highlights using relative threshold
            // Threshold = baseline * multiplier, capped at maximum
            float specularThreshold = min(
                SPECULAR_MAX_THRESHOLD,
                baselineBrightness * SPECULAR_RELATIVE_MULTIPLIER
            );

            if (brightness > specularThreshold) {
                specularCount = 1.0;
            }

            // METRIC 3: Skin Uniformity
            // Measure how consistent the skin tone is across local neighborhood
            uniformityValue = calculateUniformity(inputTexture, gid);
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localLightness[tid] = lightnessValue;
    localSpecular[tid] = specularCount;
    localUniformity[tid] = uniformityValue;
    localValidPixels[tid] = validPixels;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    // Reduce 256 threads -> 1 value per threadgroup
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localLightness[tid] += localLightness[tid + stride];
            localSpecular[tid] += localSpecular[tid + stride];
            localUniformity[tid] += localUniformity[tid + stride];
            localValidPixels[tid] += localValidPixels[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes threadgroup result to global memory
    if (tid == 0) {
        partialResults[threadgroupIndex].lightnessSum = localLightness[0];
        partialResults[threadgroupIndex].specularPixelCount = localSpecular[0];
        partialResults[threadgroupIndex].uniformitySum = localUniformity[0];
        partialResults[threadgroupIndex].validPixelCount = localValidPixels[0];
    }
}

// MARK: - Regional Glow Analysis

/// Analyze glow metrics for specific face region
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void analyzeRegionalGlow(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device GlowPartialResults* partialResults [[buffer(0)]],
    constant float4& regionBounds [[buffer(1)]],  // (minU, maxU, minV, maxV) normalized 0-1
    constant float& baselineBrightness [[buffer(2)]],
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localLightness[256];
    threadgroup float localSpecular[256];
    threadgroup float localUniformity[256];
    threadgroup float localValidPixels[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    float lightnessValue = 0.0;
    float specularCount = 0.0;
    float uniformityValue = 0.0;
    float validPixels = 0.0;

    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Convert normalized UV bounds to pixel coordinates
    uint regionMinX = uint(regionBounds.x * float(width));
    uint regionMaxX = uint(regionBounds.y * float(width));
    uint regionMinY = uint(regionBounds.z * float(height));
    uint regionMaxY = uint(regionBounds.w * float(height));

    // Check if this pixel is within the region
    if (gid.x >= regionMinX && gid.x < regionMaxX &&
        gid.y >= regionMinY && gid.y < regionMaxY) {

        float4 color = inputTexture.read(gid);
        validPixels = 1.0;

        // LAB lightness
        lightnessValue = computeLStar(color.rgb);

        // Specular detection
        float specularThreshold = min(
            SPECULAR_MAX_THRESHOLD,
            baselineBrightness * SPECULAR_RELATIVE_MULTIPLIER
        );

        float brightness = (color.r + color.g + color.b) / 3.0;
        if (brightness > specularThreshold) {
            specularCount = 1.0;
        }

        // Uniformity (only if within region borders for 3x3 window)
        if (gid.x >= regionMinX + 1 && gid.x < regionMaxX - 1 &&
            gid.y >= regionMinY + 1 && gid.y < regionMaxY - 1) {
            uniformityValue = calculateUniformity(inputTexture, gid);
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localLightness[tid] = lightnessValue;
    localSpecular[tid] = specularCount;
    localUniformity[tid] = uniformityValue;
    localValidPixels[tid] = validPixels;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localLightness[tid] += localLightness[tid + stride];
            localSpecular[tid] += localSpecular[tid + stride];
            localUniformity[tid] += localUniformity[tid + stride];
            localValidPixels[tid] += localValidPixels[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes result
    if (tid == 0) {
        partialResults[threadgroupIndex].lightnessSum = localLightness[0];
        partialResults[threadgroupIndex].specularPixelCount = localSpecular[0];
        partialResults[threadgroupIndex].uniformitySum = localUniformity[0];
        partialResults[threadgroupIndex].validPixelCount = localValidPixels[0];
    }
}
