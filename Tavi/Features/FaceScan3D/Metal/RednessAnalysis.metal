//
//  RednessAnalysis.metal
//  Tavi
//
//  GPU-accelerated redness and inflammation analysis shader
//  Detects redness index and inflammation using red channel analysis
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Main Redness Analysis Kernel

/// Parallel redness analysis with threadgroup reduction
/// Computes redness index (R - (G+B)/2) and inflammation detection
kernel void analyzeRedness(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialRedness [[buffer(0)]],
    device float* partialInflamed [[buffer(1)]],
    constant float& threshold [[buffer(2)]],
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // Threadgroup shared memory (256 threads max)
    threadgroup float localRedness[256];
    threadgroup float localInflamed[256];

    // Initialize local values
    float rednessValue = 0.0;
    float inflamedValue = 0.0;

    // Check if this thread is processing a valid pixel
    uint width = texture.get_width();
    uint height = texture.get_height();

    if (gid.x < width && gid.y < height) {
        // Read pixel
        float4 pixel = texture.read(gid);

        // Calculate redness index: R - (G + B) / 2
        // Higher values indicate more redness
        float rednessIndex = pixel.r - (pixel.g + pixel.b) / 2.0;

        // Only accumulate positive redness (ignore non-red pixels)
        if (rednessIndex > 0.0) {
            rednessValue = rednessIndex;

            // Inflammation detection: redness above threshold
            if (rednessIndex > threshold) {
                inflamedValue = 1.0;
            }
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localRedness[tid] = rednessValue;
    localInflamed[tid] = inflamedValue;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    // Reduce 256 threads -> 1 value per threadgroup
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localRedness[tid] += localRedness[tid + stride];
            localInflamed[tid] += localInflamed[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes threadgroup result
    if (tid == 0) {
        partialRedness[threadgroupIndex] = localRedness[0];
        partialInflamed[threadgroupIndex] = localInflamed[0];
    }
}

// MARK: - Baseline Skin Tone Calculation Kernel

/// Calculate baseline skin tone from center region
/// Used for adaptive redness detection
kernel void calculateBaselineSkinTone(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* baselineRGB [[buffer(0)]],  // 3 floats: [R, G, B]
    uint2 gid [[thread_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Threadgroup shared memory
    threadgroup float localR[256];
    threadgroup float localG[256];
    threadgroup float localB[256];
    threadgroup float localCount[256];

    float rSum = 0.0;
    float gSum = 0.0;
    float bSum = 0.0;
    float count = 0.0;

    uint width = texture.get_width();
    uint height = texture.get_height();

    // Sample center region (avoid edges, hair)
    uint centerX = width / 2;
    uint centerY = height / 2;
    uint sampleRadius = min(width, height) / 4;

    uint minX = centerX - sampleRadius;
    uint maxX = centerX + sampleRadius;
    uint minY = centerY - sampleRadius;
    uint maxY = centerY + sampleRadius;

    if (gid.x >= minX && gid.x < maxX && gid.y >= minY && gid.y < maxY) {
        float4 pixel = texture.read(gid);
        rSum = pixel.r;
        gSum = pixel.g;
        bSum = pixel.b;
        count = 1.0;
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localR[tid] = rSum;
    localG[tid] = gSum;
    localB[tid] = bSum;
    localCount[tid] = count;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localR[tid] += localR[tid + stride];
            localG[tid] += localG[tid + stride];
            localB[tid] += localB[tid + stride];
            localCount[tid] += localCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 computes average and writes result
    if (tid == 0) {
        float totalCount = max(localCount[0], 1.0);
        baselineRGB[0] = localR[0] / totalCount;  // Average R
        baselineRGB[1] = localG[0] / totalCount;  // Average G
        baselineRGB[2] = localB[0] / totalCount;  // Average B
    }
}

// MARK: - Regional Redness Analysis Kernel

/// Analyze redness in specific face region
kernel void analyzeRegionalRedness(
    texture2d<float, access::read> texture [[texture(0)]],
    device float* partialRedness [[buffer(0)]],
    device float* partialPixelCount [[buffer(1)]],
    constant float4& regionBounds [[buffer(2)]],  // (minX, maxX, minY, maxY) normalized 0-1
    constant uint& threadgroupsPerRow [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 threadgroupPos [[threadgroup_position_in_grid]],
    uint threadIndexInGroup [[thread_index_in_threadgroup]]
) {
    // Calculate linear threadgroup index from 2D position
    uint threadgroupIndex = threadgroupPos.y * threadgroupsPerRow + threadgroupPos.x;

    // Threadgroup shared memory
    threadgroup float localRedness[256];
    threadgroup float localPixelCount[256];

    float rednessValue = 0.0;
    float pixelCount = 0.0;

    uint width = texture.get_width();
    uint height = texture.get_height();

    // Convert normalized region bounds to pixel coordinates
    uint regionMinX = uint(regionBounds.x * float(width));
    uint regionMaxX = uint(regionBounds.y * float(width));
    uint regionMinY = uint(regionBounds.z * float(height));
    uint regionMaxY = uint(regionBounds.w * float(height));

    // Check if this pixel is within the region
    if (gid.x >= regionMinX && gid.x < regionMaxX &&
        gid.y >= regionMinY && gid.y < regionMaxY) {

        float4 pixel = texture.read(gid);

        // Calculate redness index
        float rednessIndex = pixel.r - (pixel.g + pixel.b) / 2.0;

        if (rednessIndex > 0.0) {
            rednessValue = rednessIndex;
            pixelCount = 1.0;
        }
    }

    // Store in threadgroup memory
    uint tid = threadIndexInGroup;
    localRedness[tid] = rednessValue;
    localPixelCount[tid] = pixelCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            localRedness[tid] += localRedness[tid + stride];
            localPixelCount[tid] += localPixelCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes result
    if (tid == 0) {
        partialRedness[threadgroupIndex] = localRedness[0];
        partialPixelCount[threadgroupIndex] = localPixelCount[0];
    }
}
