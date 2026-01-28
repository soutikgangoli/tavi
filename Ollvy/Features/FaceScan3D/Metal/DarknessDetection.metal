//
//  DarknessDetection.metal
//  Ollvy
//
//  GPU-accelerated darkness detection for acne analysis
//  Hybrid approach: GPU for darkness map generation, CPU for connected component analysis
//
//  Method: Local darkness variation detection
//  - GPU detects pixels darker than their neighborhood (potential blemishes)
//  - CPU performs flood-fill to group connected dark regions
//  - Works fairly across all skin tones (Fitzpatrick I-VI)
//

#include <metal_stdlib>
using namespace metal;

// Import shared luminance helpers
#include "AnalyzerCommon.h"

// MARK: - Constants

/// Minimum darkness difference to consider as potential blemish
/// Adaptive per-pixel based on neighborhood statistics
constant float MIN_DARKNESS_THRESHOLD = 0.02;  // 2% darker than surroundings

// MARK: - Main Darkness Detection Kernel

/// Detect local darkness variations (potential blemishes)
///
/// Algorithm:
/// 1. For each pixel, compute its luminance (perceptual brightness)
/// 2. Sample neighborhood average luminance (excluding center)
/// 3. Compute darkness = neighborhoodAvg - centerLum
/// 4. Positive darkness = pixel is darker than surroundings = potential blemish
///
/// Output: Darkness map where higher values = more likely to be blemish
kernel void detectDarknessVariations(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> darknessMap [[texture(1)]],
    constant int& sampleRadius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    // Read center pixel
    float4 centerColor = inputTexture.read(gid);

    float centerLum = perceptualLuminance(centerColor.rgb);

    // Border handling: cannot compute darkness for edge pixels
    // Need sampleRadius pixels on all sides
    if (gid.x < uint(sampleRadius) || gid.x >= width - uint(sampleRadius) ||
        gid.y < uint(sampleRadius) || gid.y >= height - uint(sampleRadius)) {
        // Write zero darkness for border pixels
        darknessMap.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }

    // Sample neighborhood (circular region, excluding center)
    float neighborhoodSum = 0.0;
    int neighborCount = 0;

    // Iterate over square region, but weight by distance
    for (int dy = -sampleRadius; dy <= sampleRadius; dy++) {
        for (int dx = -sampleRadius; dx <= sampleRadius; dx++) {
            // Skip center pixel
            if (dx == 0 && dy == 0) {
                continue;
            }

            // Only sample within circular region (distance < radius)
            float distSq = float(dx * dx + dy * dy);
            float radiusSq = float(sampleRadius * sampleRadius);

            if (distSq <= radiusSq) {
                uint2 samplePos = uint2(int(gid.x) + dx, int(gid.y) + dy);
                float4 sampleColor = inputTexture.read(samplePos);
                float sampleLum = perceptualLuminance(sampleColor.rgb);

                neighborhoodSum += sampleLum;
                neighborCount++;
            }
        }
    }

    // Calculate average neighborhood luminance
    float neighborhoodAvg = (neighborCount > 0) ? (neighborhoodSum / float(neighborCount)) : centerLum;

    // Darkness = how much darker this pixel is compared to neighbors
    // Positive = darker than surroundings (potential blemish)
    // Negative = brighter than surroundings (not a blemish)
    float darkness = neighborhoodAvg - centerLum;

    // Clamp to [0, 1] range (only keep positive darkness)
    darkness = clamp(darkness, 0.0, 1.0);

    // Write to darkness map (R channel = darkness value)
    // G, B channels unused (set to 0)
    // A channel = 1.0 (fully opaque)
    darknessMap.write(float4(darkness, 0.0, 0.0, 1.0), gid);
}

// MARK: - Darkness Statistics Kernel

/// Compute statistics over darkness map (mean, variance, threshold estimation)
/// Uses threadgroup reduction for efficient parallel computation
///
/// This kernel helps determine adaptive thresholds for blemish classification
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void analyzeDarknessStats(
    texture2d<float, access::read> darknessMap [[texture(0)]],
    device float* partialSums [[buffer(0)]],
    device float* partialCounts [[buffer(1)]],
    constant float& minThreshold [[buffer(2)]],
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]]
) {
    // Calculate linear threadgroup index from 2D position
    // CRITICAL: Must use uint2 threadgroupPos (not uint threadgroupIndex)
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localDarknessSum[256];
    threadgroup float localPixelCount[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    // Initialize local values
    float darknessSum = 0.0;
    float pixelCount = 0.0;

    // Read darkness value for this pixel
    uint width = darknessMap.get_width();
    uint height = darknessMap.get_height();

    if (gid.x < width && gid.y < height) {
        float4 darknessPixel = darknessMap.read(gid);
        float darkness = darknessPixel.r;  // R channel stores darkness

        // Only count pixels above minimum threshold (ignore noise)
        if (darkness >= minThreshold) {
            darknessSum = darkness;
            pixelCount = 1.0;
        }
    }

    // Store in threadgroup shared memory
    uint tid = threadIndexInGroup;
    localDarknessSum[tid] = darknessSum;
    localPixelCount[tid] = pixelCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    // Reduces 256 threads -> 1 aggregate value per threadgroup
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localDarknessSum[tid] += localDarknessSum[tid + stride];
            localPixelCount[tid] += localPixelCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes threadgroup partial results to device memory
    if (tid == 0) {
        partialSums[threadgroupIndex] = localDarknessSum[0];
        partialCounts[threadgroupIndex] = localPixelCount[0];
    }
}

// MARK: - Adaptive Threshold Estimation Kernel

/// Calculate skin-tone adaptive darkness threshold
/// Samples center face region to determine baseline darkness distribution
///
/// Algorithm:
/// 1. Sample center 50% of image (most likely pure skin, no blemishes)
/// 2. Compute average darkness in this region
/// 3. Calculate adaptive threshold = mean + k*stddev
/// 4. This adapts to different skin tones automatically
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void calculateAdaptiveDarknessThreshold(
    texture2d<float, access::read> darknessMap [[texture(0)]],
    device float* threshold [[buffer(0)]],
    constant float& percentile [[buffer(1)]],  // e.g., 0.90 for 90th percentile
    uint2 gid [[thread_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads
    threadgroup float localDarknessSum[256];
    threadgroup float localDarknessSqSum[256];
    threadgroup float localPixelCount[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    float darknessSum = 0.0;
    float darknessSqSum = 0.0;
    float pixelCount = 0.0;

    uint width = darknessMap.get_width();
    uint height = darknessMap.get_height();

    // Sample center region (50% of image dimensions)
    uint centerX = width / 2;
    uint centerY = height / 2;
    uint sampleRadius = min(width, height) / 4;

    uint minX = centerX - sampleRadius;
    uint maxX = centerX + sampleRadius;
    uint minY = centerY - sampleRadius;
    uint maxY = centerY + sampleRadius;

    if (gid.x >= minX && gid.x < maxX && gid.y >= minY && gid.y < maxY) {
        float4 darknessPixel = darknessMap.read(gid);
        float darkness = darknessPixel.r;

        darknessSum = darkness;
        darknessSqSum = darkness * darkness;
        pixelCount = 1.0;
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localDarknessSum[tid] = darknessSum;
    localDarknessSqSum[tid] = darknessSqSum;
    localPixelCount[tid] = pixelCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localDarknessSum[tid] += localDarknessSum[tid + stride];
            localDarknessSqSum[tid] += localDarknessSqSum[tid + stride];
            localPixelCount[tid] += localPixelCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 computes statistics and adaptive threshold
    if (tid == 0) {
        float totalPixels = max(localPixelCount[0], 1.0);
        float mean = localDarknessSum[0] / totalPixels;
        float meanSq = localDarknessSqSum[0] / totalPixels;
        float variance = max(0.0, meanSq - mean * mean);
        float stddev = sqrt(variance);

        // Adaptive threshold: mean + k*stddev
        // Higher k = stricter (fewer false positives)
        // Lower k = more sensitive (more detections)
        // Use percentile to determine k (assuming normal distribution)
        // For 90th percentile: k ≈ 1.28
        // For 95th percentile: k ≈ 1.65
        float k = 1.65;  // 95th percentile

        float adaptiveThreshold = mean + k * stddev;

        // Ensure minimum threshold (avoid detecting noise)
        adaptiveThreshold = max(MIN_DARKNESS_THRESHOLD, adaptiveThreshold);

        threshold[0] = adaptiveThreshold;
    }
}

// MARK: - Downsampled Darkness Map Generation

/// Generate downsampled darkness map for faster CPU processing
/// Uses max pooling to preserve small dark spots
///
/// Algorithm:
/// 1. Each output pixel samples a NxN region from input
/// 2. Take maximum darkness value (preserves small blemishes)
/// 3. This reduces data transfer CPU<->GPU and speeds up flood-fill
kernel void downsampleDarknessMap(
    texture2d<float, access::read> inputDarknessMap [[texture(0)]],
    texture2d<float, access::write> outputDarknessMap [[texture(1)]],
    constant int& downscaleFactor [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint outputWidth = outputDarknessMap.get_width();
    uint outputHeight = outputDarknessMap.get_height();

    if (gid.x >= outputWidth || gid.y >= outputHeight) {
        return;
    }

    // Map output pixel to input region
    uint inputX = gid.x * uint(downscaleFactor);
    uint inputY = gid.y * uint(downscaleFactor);

    // Max pooling over downscaleFactor x downscaleFactor region
    float maxDarkness = 0.0;

    for (int dy = 0; dy < downscaleFactor; dy++) {
        for (int dx = 0; dx < downscaleFactor; dx++) {
            uint2 inputPos = uint2(inputX + uint(dx), inputY + uint(dy));

            // Bounds check
            if (inputPos.x < inputDarknessMap.get_width() &&
                inputPos.y < inputDarknessMap.get_height()) {
                float4 darknessPixel = inputDarknessMap.read(inputPos);
                float darkness = darknessPixel.r;
                maxDarkness = max(maxDarkness, darkness);
            }
        }
    }

    // Write max darkness to output
    outputDarknessMap.write(float4(maxDarkness, 0.0, 0.0, 1.0), gid);
}

// MARK: - Visualization Kernel (Debug/UI)

/// Generate color-coded visualization of darkness map for debugging/UI
/// Maps darkness values to color gradient: blue (low) -> red (high)
kernel void visualizeDarknessMap(
    texture2d<float, access::read> darknessMap [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& visualizationScale [[buffer(0)]],  // Scale factor for visibility
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = darknessMap.get_width();
    uint height = darknessMap.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    float4 darknessPixel = darknessMap.read(gid);
    float darkness = darknessPixel.r * visualizationScale;

    // Clamp to [0, 1]
    darkness = clamp(darkness, 0.0, 1.0);

    // Color gradient: blue -> cyan -> green -> yellow -> red
    // Blue = low darkness (normal skin)
    // Red = high darkness (potential blemish)
    float3 color;

    if (darkness < 0.25) {
        // Blue to cyan
        float t = darkness / 0.25;
        color = float3(0.0, t, 1.0);
    } else if (darkness < 0.5) {
        // Cyan to green
        float t = (darkness - 0.25) / 0.25;
        color = float3(0.0, 1.0, 1.0 - t);
    } else if (darkness < 0.75) {
        // Green to yellow
        float t = (darkness - 0.5) / 0.25;
        color = float3(t, 1.0, 0.0);
    } else {
        // Yellow to red
        float t = (darkness - 0.75) / 0.25;
        color = float3(1.0, 1.0 - t, 0.0);
    }

    outputTexture.write(float4(color, 1.0), gid);
}
