//
//  PoreDetection.metal
//  Ollvy
//
//  GPU-accelerated pore detection using Laplacian edge detection
//  Pores appear as local maxima in high-frequency texture response
//

#include <metal_stdlib>
using namespace metal;

// Import shared luminance helpers
#include "AnalyzerCommon.h"

// MARK: - Constants

/// Laplacian threshold for significant pore response
/// Empirically determined from testing across skin tones
constant float PORE_LAPLACIAN_THRESHOLD = 0.1;

// MARK: - Structures

/// Individual pore detection result
/// Layout matches SIMD4<Float> in Swift: (x, y, intensity, size)
/// Metal uint2 = 2 uints = 8 bytes, but we pack as float4 for Swift interop
struct PoreLocationPacked {
    float x;             // Position X (converted from uint)
    float y;             // Position Y (converted from uint)
    float intensity;     // Laplacian response strength
    float size;          // Estimated pore size in pixels
};

/// Partial pore detection results from each threadgroup
struct PorePartialResults {
    float totalPoreCount;
    float totalPoreSize;
    float skinBrightnessSum;
    float validPixelCount;
};

// MARK: - Pass 1: Laplacian Convolution

/// Compute 8-neighbor Laplacian for pore detection
/// High Laplacian response indicates sharp texture changes (pores, wrinkles)
kernel void computePoreLaplacian(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> laplacianMap [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Bounds check - need 1-pixel border for 3x3 kernel
    if (gid.x < 1 || gid.x >= width - 1 || gid.y < 1 || gid.y >= height - 1) {
        if (gid.x < width && gid.y < height) {
            laplacianMap.write(float4(0.0), gid);
        }
        return;
    }

    // Read 3x3 neighborhood using shared legacy luminance helper
    // NOTE: Keeping legacy formula (threshold PORE_LAPLACIAN_THRESHOLD calibrated for it)
    float center      = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y    )).rgb);
    float top         = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y - 1)).rgb);
    float bottom      = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y + 1)).rgb);
    float left        = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y    )).rgb);
    float right       = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y    )).rgb);
    float topLeft     = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y - 1)).rgb);
    float topRight    = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y - 1)).rgb);
    float bottomLeft  = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y + 1)).rgb);
    float bottomRight = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y + 1)).rgb);

    // 8-neighbor Laplacian: 8*center - sum(all neighbors)
    // This emphasizes high-frequency texture components (pores appear as dark spots = local minima in brightness)
    float laplacian = 8.0 * center - (top + bottom + left + right +
                                     topLeft + topRight + bottomLeft + bottomRight);

    // Store absolute Laplacian response
    // Pores show up as peaks in this map
    laplacianMap.write(float4(abs(laplacian)), gid);
}

// MARK: - Pass 2: Local Maxima Detection (Pore Centers)

/// Detect pores as local maxima in Laplacian map
/// Uses adaptive thresholding based on skin brightness
kernel void detectPoreMaxima(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> laplacianMap [[texture(1)]],
    device atomic_uint* poreCount [[buffer(0)]],
    device PoreLocationPacked* poreLocations [[buffer(1)]],
    constant uint& maxPores [[buffer(2)]],
    constant float& adaptiveDarknessThreshold [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = laplacianMap.get_width();
    uint height = laplacianMap.get_height();

    // Need 2-pixel border for 5x5 local maximum search
    if (gid.x < 2 || gid.x >= width - 2 || gid.y < 2 || gid.y >= height - 2) {
        return;
    }

    // Read center Laplacian value
    float centerLaplacian = laplacianMap.read(gid).r;

    // Threshold check - skip weak responses
    if (centerLaplacian < PORE_LAPLACIAN_THRESHOLD) {
        return;
    }

    // Check if this is a local maximum in 3x3 neighborhood
    // Pores appear as peaks in Laplacian response
    bool isLocalMaximum = true;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;

            uint2 neighborPos = uint2(int(gid.x) + dx, int(gid.y) + dy);
            float neighborLaplacian = laplacianMap.read(neighborPos).r;

            // If any neighbor is greater, this is not a local maximum
            if (neighborLaplacian >= centerLaplacian) {
                isLocalMaximum = false;
                break;
            }
        }
        if (!isLocalMaximum) break;
    }

    if (!isLocalMaximum) {
        return;
    }

    // Verify this is actually a dark spot (pore) in original image
    // Check brightness at center
    float4 centerColor = inputTexture.read(gid);
    float centerBrightness = (centerColor.r + centerColor.g + centerColor.b) / 3.0;

    // Pore must be darker than adaptive threshold
    // This prevents false positives from bright specular highlights
    if (centerBrightness >= adaptiveDarknessThreshold) {
        return;
    }

    // Estimate pore size by measuring extent of dark region
    // Count contiguous pixels darker than center + 15%
    float sizeThreshold = min(1.0, centerBrightness * 1.15);
    float poreSize = 1.0;

    // Simple 5x5 region check for size estimation
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            if (dx == 0 && dy == 0) continue;

            uint2 pos = uint2(int(gid.x) + dx, int(gid.y) + dy);
            if (pos.x < width && pos.y < height) {
                float4 color = inputTexture.read(pos);
                float brightness = (color.r + color.g + color.b) / 3.0;

                if (brightness < sizeThreshold) {
                    poreSize += 1.0;
                }
            }
        }
    }

    // Record this pore (atomic increment ensures thread safety)
    uint poreIndex = atomic_fetch_add_explicit(poreCount, 1, memory_order_relaxed);

    // Only store if we haven't exceeded buffer capacity
    if (poreIndex < maxPores) {
        poreLocations[poreIndex].x = float(gid.x);
        poreLocations[poreIndex].y = float(gid.y);
        poreLocations[poreIndex].intensity = centerLaplacian;
        poreLocations[poreIndex].size = poreSize;
    }
}

// MARK: - Pass 3: Calculate Average Skin Brightness

/// Calculate average skin brightness for adaptive thresholding
/// Samples center region to avoid hair/edges
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void calculateSkinBrightness(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    device float* avgBrightness [[buffer(0)]],
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

    // Sample center region (avoid edges and hair)
    uint sampleMinX = width / 3;
    uint sampleMaxX = width * 2 / 3;
    uint sampleMinY = height / 3;
    uint sampleMaxY = height * 2 / 3;

    if (gid.x >= sampleMinX && gid.x < sampleMaxX &&
        gid.y >= sampleMinY && gid.y < sampleMaxY) {
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

    // Thread 0 computes average
    if (tid == 0) {
        float avgBright = localBrightnessSum[0] / max(localPixelCount[0], 1.0);
        avgBrightness[0] = avgBright;
    }
}

// MARK: - Regional Pore Analysis

/// Analyze pores in specific face region
/// Used for regional scoring (forehead, cheeks, nose, chin)
/// NOTE: This kernel REQUIRES exactly 256 threads per threadgroup (16x16)
kernel void analyzeRegionalPores(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> laplacianMap [[texture(1)]],
    device PorePartialResults* partialResults [[buffer(0)]],
    constant float4& regionBounds [[buffer(1)]],  // (minX, maxX, minY, maxY) normalized 0-1
    constant float& adaptiveDarknessThreshold [[buffer(2)]],
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // CRITICAL: Threadgroup shared memory sized for exactly 256 threads (16x16)
    threadgroup float localPoreCount[256];
    threadgroup float localPoreSize[256];
    threadgroup float localValidPixels[256];

    // Safety check: bail out if thread index exceeds array bounds
    if (threadIndexInGroup >= 256) {
        return;
    }

    float poreCount = 0.0;
    float poreSize = 0.0;
    float validPixels = 0.0;

    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Convert normalized region bounds to pixel coordinates
    uint regionMinX = uint(regionBounds.x * float(width));
    uint regionMaxX = uint(regionBounds.y * float(width));
    uint regionMinY = uint(regionBounds.z * float(height));
    uint regionMaxY = uint(regionBounds.w * float(height));

    // Check if pixel is in region (with 2-pixel border for Laplacian)
    if (gid.x >= regionMinX + 2 && gid.x < regionMaxX - 2 &&
        gid.y >= regionMinY + 2 && gid.y < regionMaxY - 2) {

        validPixels = 1.0;

        // Check Laplacian response
        float laplacian = laplacianMap.read(gid).r;

        if (laplacian >= PORE_LAPLACIAN_THRESHOLD) {
            // Check if local maximum
            bool isLocalMaximum = true;

            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;

                    uint2 neighborPos = uint2(int(gid.x) + dx, int(gid.y) + dy);
                    float neighborLaplacian = laplacianMap.read(neighborPos).r;

                    if (neighborLaplacian >= laplacian) {
                        isLocalMaximum = false;
                        break;
                    }
                }
                if (!isLocalMaximum) break;
            }

            if (isLocalMaximum) {
                // Check brightness
                float4 color = inputTexture.read(gid);
                float brightness = (color.r + color.g + color.b) / 3.0;

                if (brightness < adaptiveDarknessThreshold) {
                    poreCount = 1.0;

                    // Estimate size
                    float sizeThreshold = min(1.0, brightness * 1.15);
                    float size = 1.0;

                    for (int dy = -2; dy <= 2; dy++) {
                        for (int dx = -2; dx <= 2; dx++) {
                            if (dx == 0 && dy == 0) continue;

                            uint2 pos = uint2(int(gid.x) + dx, int(gid.y) + dy);
                            if (pos.x >= regionMinX && pos.x < regionMaxX &&
                                pos.y >= regionMinY && pos.y < regionMaxY) {
                                float4 c = inputTexture.read(pos);
                                float b = (c.r + c.g + c.b) / 3.0;
                                if (b < sizeThreshold) {
                                    size += 1.0;
                                }
                            }
                        }
                    }

                    poreSize = size;
                }
            }
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localPoreCount[tid] = poreCount;
    localPoreSize[tid] = poreSize;
    localValidPixels[tid] = validPixels;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localPoreCount[tid] += localPoreCount[tid + stride];
            localPoreSize[tid] += localPoreSize[tid + stride];
            localValidPixels[tid] += localValidPixels[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes result
    if (tid == 0) {
        partialResults[threadgroupIndex].totalPoreCount = localPoreCount[0];
        partialResults[threadgroupIndex].totalPoreSize = localPoreSize[0];
        partialResults[threadgroupIndex].validPixelCount = localValidPixels[0];
    }
}
