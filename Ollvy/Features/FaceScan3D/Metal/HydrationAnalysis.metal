//
//  HydrationAnalysis.metal
//  Ollvy
//
//  GPU-accelerated hydration analysis shader
//  Single-pass computation of specularity, texture frequency, and color variance
//

#include <metal_stdlib>
using namespace metal;

// Import shared luminance helpers
#include "AnalyzerCommon.metal"

// MARK: - Constants

/// Adaptive specular threshold multiplier
/// Threshold = skin_brightness * SPECULAR_THRESHOLD_FACTOR
constant float SPECULAR_THRESHOLD_FACTOR = 0.70;

/// Brightness threshold for minimum specular detection
constant float MIN_SPECULAR_BRIGHTNESS = 0.60;  // 153/255 in 0-1 range

// MARK: - Structures

/// Partial results from each threadgroup
struct HydrationPartialResults {
    float specularPixelCount;
    float textureEnergySum;
    float luminanceSum;
    float luminanceSqSum;  // For variance calculation
    float validPixelCount;
};

// MARK: - Main Hydration Analysis Kernel

/// Single-pass hydration analysis with threadgroup reduction
/// Computes specularity, texture frequency, and color variance in parallel
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void analyzeHydration(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device HydrationPartialResults* partialResults [[buffer(0)]],
    constant float& adaptiveThreshold [[buffer(1)]],
    constant uint& threadgroupsPerRow [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupSize [[threads_per_threadgroup]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localSpecularCount[256];
    threadgroup float localTextureEnergy[256];
    threadgroup float localLuminanceSum[256];
    threadgroup float localLuminanceSqSum[256];
    threadgroup float localValidPixels[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    // Initialize local values
    float specularCount = 0.0;
    float textureEnergy = 0.0;
    float luminanceSum = 0.0;
    float luminanceSqSum = 0.0;
    float validPixels = 0.0;

    // Check if this thread is processing a valid pixel
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    if (gid.x < width && gid.y < height) {
        // Read pixel
        float4 color = inputTexture.read(gid);

        float luminance = perceptualLuminance(color.rgb);

        validPixels = 1.0;
        luminanceSum = luminance;
        luminanceSqSum = luminance * luminance;

        // Method 1: Specularity detection
        // Use adaptive threshold based on skin tone
        if (color.r > adaptiveThreshold &&
            color.g > adaptiveThreshold &&
            color.b > adaptiveThreshold) {
            specularCount = 1.0;
        }

        // Method 2: Texture frequency analysis (8-neighbor Laplacian)
        // Only process interior pixels (need 1-pixel border)
        if (gid.x >= 1 && gid.x < width - 1 && gid.y >= 1 && gid.y < height - 1) {
            // FIXED: Use consistent BT.709 luminance for all Laplacian samples
            float center = luminance;
            float top         = perceptualLuminance(inputTexture.read(uint2(gid.x,     gid.y - 1)).rgb);
            float bottom      = perceptualLuminance(inputTexture.read(uint2(gid.x,     gid.y + 1)).rgb);
            float left        = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y    )).rgb);
            float right       = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y    )).rgb);
            float topLeft     = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y - 1)).rgb);
            float topRight    = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y - 1)).rgb);
            float bottomLeft  = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y + 1)).rgb);
            float bottomRight = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y + 1)).rgb);

            // 8-neighbor Laplacian
            float laplacian = 8.0 * center - (top + bottom + left + right +
                                             topLeft + topRight + bottomLeft + bottomRight);

            // FIX: Normalize Laplacian to 0-1 range
            // Raw Laplacian can be up to 8.0 (when center=1, all neighbors=0)
            // Normalizing ensures consistent scale regardless of image content
            // Typical skin texture: 0.01-0.15, high texture: 0.2-0.4
            textureEnergy = abs(laplacian) / 8.0;
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localSpecularCount[tid] = specularCount;
    localTextureEnergy[tid] = textureEnergy;
    localLuminanceSum[tid] = luminanceSum;
    localLuminanceSqSum[tid] = luminanceSqSum;
    localValidPixels[tid] = validPixels;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    // Reduce 256 threads -> 1 value per threadgroup
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localSpecularCount[tid] += localSpecularCount[tid + stride];
            localTextureEnergy[tid] += localTextureEnergy[tid + stride];
            localLuminanceSum[tid] += localLuminanceSum[tid + stride];
            localLuminanceSqSum[tid] += localLuminanceSqSum[tid + stride];
            localValidPixels[tid] += localValidPixels[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes threadgroup result
    if (tid == 0) {
        partialResults[threadgroupIndex].specularPixelCount = localSpecularCount[0];
        partialResults[threadgroupIndex].textureEnergySum = localTextureEnergy[0];
        partialResults[threadgroupIndex].luminanceSum = localLuminanceSum[0];
        partialResults[threadgroupIndex].luminanceSqSum = localLuminanceSqSum[0];
        partialResults[threadgroupIndex].validPixelCount = localValidPixels[0];
    }
}

// MARK: - Adaptive Threshold Calculation Kernel

/// Calculate skin-tone adaptive specular threshold
/// Samples center region to determine average skin brightness
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void calculateAdaptiveThreshold(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device float* averageBrightness [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads
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

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localBrightnessSum[tid] += localBrightnessSum[tid + stride];
            localPixelCount[tid] += localPixelCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 computes average and writes result
    if (tid == 0) {
        float avgBrightness = localBrightnessSum[0] / max(localPixelCount[0], 1.0);

        // Adaptive threshold: 70% of max possible brightness for this skin tone
        // Darker skin: lower absolute brightness, but same relative threshold
        float maxPossible = min(1.0, avgBrightness * 1.5);
        float threshold = max(MIN_SPECULAR_BRIGHTNESS, min(0.86, maxPossible * SPECULAR_THRESHOLD_FACTOR));

        averageBrightness[0] = threshold;
    }
}

// MARK: - Regional Analysis Kernel

/// Analyze hydration in specific face region
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void analyzeRegionalHydration(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device HydrationPartialResults* partialResults [[buffer(0)]],
    constant float4& regionBounds [[buffer(1)]],  // (minX, maxX, minY, maxY) normalized 0-1
    constant float& adaptiveThreshold [[buffer(2)]],
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localSpecularCount[256];
    threadgroup float localTextureEnergy[256];
    threadgroup float localValidPixels[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    float specularCount = 0.0;
    float textureEnergy = 0.0;
    float validPixels = 0.0;

    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Convert normalized region bounds to pixel coordinates
    uint regionMinX = uint(regionBounds.x * float(width));
    uint regionMaxX = uint(regionBounds.y * float(width));
    uint regionMinY = uint(regionBounds.z * float(height));
    uint regionMaxY = uint(regionBounds.w * float(height));

    // Check if this pixel is within the region
    if (gid.x >= regionMinX && gid.x < regionMaxX &&
        gid.y >= regionMinY && gid.y < regionMaxY) {

        float4 color = inputTexture.read(gid);
        float luminance = perceptualLuminance(color.rgb);

        // FIX: Skip black/near-black pixels (texture background)
        float avgBrightness = (color.r + color.g + color.b) / 3.0;
        if (avgBrightness < 0.05) {
            validPixels = 0.0;
            // Don't contribute to any metrics
        } else {
            validPixels = 1.0;

            // Specularity detection
            if (color.r > adaptiveThreshold &&
                color.g > adaptiveThreshold &&
                color.b > adaptiveThreshold) {
                specularCount = 1.0;
            }

            // Texture analysis (with bounds check for Laplacian)
            if (gid.x >= regionMinX + 1 && gid.x < regionMaxX - 1 &&
                gid.y >= regionMinY + 1 && gid.y < regionMaxY - 1) {

                // FIXED: Use consistent BT.709 luminance for all Laplacian samples
                float center = luminance;
                float top         = perceptualLuminance(inputTexture.read(uint2(gid.x,     gid.y - 1)).rgb);
                float bottom      = perceptualLuminance(inputTexture.read(uint2(gid.x,     gid.y + 1)).rgb);
                float left        = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y    )).rgb);
                float right       = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y    )).rgb);
                float topLeft     = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y - 1)).rgb);
                float topRight    = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y - 1)).rgb);
                float bottomLeft  = perceptualLuminance(inputTexture.read(uint2(gid.x - 1, gid.y + 1)).rgb);
                float bottomRight = perceptualLuminance(inputTexture.read(uint2(gid.x + 1, gid.y + 1)).rgb);

                // 8-neighbor Laplacian (consistent with main analysis)
                float laplacian = 8.0 * center - (top + bottom + left + right +
                                                 topLeft + topRight + bottomLeft + bottomRight);

                // FIX: Normalize Laplacian to 0-1 range (consistent with main kernel)
                textureEnergy = abs(laplacian) / 8.0;
            }
        }  // End of else block (valid non-black pixel)
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localSpecularCount[tid] = specularCount;
    localTextureEnergy[tid] = textureEnergy;
    localValidPixels[tid] = validPixels;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localSpecularCount[tid] += localSpecularCount[tid + stride];
            localTextureEnergy[tid] += localTextureEnergy[tid + stride];
            localValidPixels[tid] += localValidPixels[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes result
    if (tid == 0) {
        partialResults[threadgroupIndex].specularPixelCount = localSpecularCount[0];
        partialResults[threadgroupIndex].textureEnergySum = localTextureEnergy[0];
        partialResults[threadgroupIndex].validPixelCount = localValidPixels[0];
        partialResults[threadgroupIndex].luminanceSum = 0.0;  // Not used for regional
        partialResults[threadgroupIndex].luminanceSqSum = 0.0;  // Not used for regional
    }
}
