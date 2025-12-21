//
//  AnalyzerCommon.metal
//  Tavi
//
//  Shared Metal functions for skin analysis
//  Common utilities used across all GPU-accelerated analyzers
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Luminance Calculation

/// Perceptual luminance calculation using ITU-R BT.709 standard
/// Y = 0.2126R + 0.7152G + 0.0722B
/// This matches human perception better than simple averaging
inline float perceptualLuminance(float3 rgb) {
    return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

/// Legacy luminance calculation (for compatibility with existing CPU code)
/// Y = 0.299R + 0.587G + 0.114B
inline float legacyLuminance(float3 rgb) {
    return 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
}

// MARK: - Color Space Conversions

/// Convert sRGB to Linear RGB
/// sRGB uses gamma compression, must be linearized for proper color math
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
/// XYZ is a device-independent color space used for accurate color analysis
inline float3 linearRGBToXYZ(float3 linear) {
    // D65 illuminant transformation matrix
    float3 xyz;
    xyz.x = 0.4124564 * linear.r + 0.3575761 * linear.g + 0.1804375 * linear.b;
    xyz.y = 0.2126729 * linear.r + 0.7151522 * linear.g + 0.0721750 * linear.b;
    xyz.z = 0.0193339 * linear.r + 0.1191920 * linear.g + 0.9503041 * linear.b;
    return xyz;
}

/// Convert XYZ to LAB color space
/// LAB transformation function - converts normalized XYZ component to LAB space
/// Uses the standard CIE formula with delta = 6/29
inline float labTransformFunction(float t) {
    const float delta = 6.0 / 29.0;
    const float delta3 = delta * delta * delta;  // 0.008856
    if (t > delta3) {
        return pow(t, 1.0/3.0);
    } else {
        return (t / (3.0 * delta * delta)) + (4.0 / 29.0);
    }
}

/// LAB is perceptually uniform - equal distances in LAB space represent equal perceived color differences
inline float3 xyzToLAB(float3 xyz) {
    // D65 reference white point
    const float3 refWhite = float3(0.95047, 1.00000, 1.08883);

    // Normalize by reference white
    float3 normalized = xyz / refWhite;

    // Apply LAB transformation function
    float fx = labTransformFunction(normalized.x);
    float fy = labTransformFunction(normalized.y);
    float fz = labTransformFunction(normalized.z);

    // Calculate L*a*b* values
    float L = 116.0 * fy - 16.0;  // L* (lightness): 0-100
    float a = 500.0 * (fx - fy);   // a* (green-red): typically -128 to 127
    float b = 200.0 * (fy - fz);   // b* (blue-yellow): typically -128 to 127

    return float3(L, a, b);
}

/// Convert sRGB directly to LAB color space (convenience function)
inline float3 sRGBToLAB(float3 srgb) {
    float3 linear = sRGBToLinear(srgb);
    float3 xyz = linearRGBToXYZ(linear);
    return xyzToLAB(xyz);
}

// MARK: - Texture Analysis Kernels

/// 8-neighbor Laplacian kernel for texture analysis
/// Detects high-frequency texture (roughness, pores, wrinkles)
/// Returns absolute Laplacian response (unsigned edge strength)
inline float laplacian8Neighbor(
    texture2d<float, access::read> inputTexture,
    uint2 gid
) {
    // Check bounds (need 1-pixel border for 3x3 kernel)
    if (gid.x < 1 || gid.x >= inputTexture.get_width() - 1 ||
        gid.y < 1 || gid.y >= inputTexture.get_height() - 1) {
        return 0.0;
    }

    // Read 3x3 neighborhood (using legacy luminance for compatibility)
    float center = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y    )).rgb);
    float top    = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y - 1)).rgb);
    float bottom = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y + 1)).rgb);
    float left   = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y    )).rgb);
    float right  = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y    )).rgb);

    // Diagonal neighbors
    float topLeft     = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y - 1)).rgb);
    float topRight    = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y - 1)).rgb);
    float bottomLeft  = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y + 1)).rgb);
    float bottomRight = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y + 1)).rgb);

    // 8-neighbor Laplacian: 8*center - sum(all neighbors)
    float laplacian = 8.0 * center - (top + bottom + left + right +
                                       topLeft + topRight + bottomLeft + bottomRight);

    return abs(laplacian);
}

/// 4-neighbor Laplacian kernel (simpler, faster alternative)
inline float laplacian4Neighbor(
    texture2d<float, access::read> inputTexture,
    uint2 gid
) {
    // Check bounds
    if (gid.x < 1 || gid.x >= inputTexture.get_width() - 1 ||
        gid.y < 1 || gid.y >= inputTexture.get_height() - 1) {
        return 0.0;
    }

    // Read 3x3 cross (center + 4 neighbors)
    float center = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y    )).rgb);
    float top    = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y - 1)).rgb);
    float bottom = legacyLuminance(inputTexture.read(uint2(gid.x,     gid.y + 1)).rgb);
    float left   = legacyLuminance(inputTexture.read(uint2(gid.x - 1, gid.y    )).rgb);
    float right  = legacyLuminance(inputTexture.read(uint2(gid.x + 1, gid.y    )).rgb);

    // 4-neighbor Laplacian: 4*center - sum(4 neighbors)
    float laplacian = 4.0 * center - (top + bottom + left + right);

    return abs(laplacian);
}

// MARK: - Threadgroup Reduction Utilities

/// Parallel reduction helper for computing sum across threadgroup
/// Uses shared memory to efficiently aggregate values from all threads
/// USAGE:
///   1. Each thread computes its local value
///   2. Call threadgroupSum() with local value and threadgroup memory
///   3. Thread 0 gets the final sum, all other threads get 0
template<typename T>
inline T threadgroupSum(
    T localValue,
    threadgroup T* sharedMemory,
    uint threadIndex,
    uint threadgroupSize
) {
    // Store local value in shared memory
    sharedMemory[threadIndex] = localValue;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    for (uint stride = threadgroupSize / 2; stride > 0; stride >>= 1) {
        if (threadIndex < stride && threadIndex + stride < threadgroupSize) {
            sharedMemory[threadIndex] += sharedMemory[threadIndex + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 has final sum, others have 0
    return (threadIndex == 0) ? sharedMemory[0] : 0;
}

/// Parallel reduction helper for computing max across threadgroup
template<typename T>
inline T threadgroupMax(
    T localValue,
    threadgroup T* sharedMemory,
    uint threadIndex,
    uint threadgroupSize
) {
    // Store local value in shared memory
    sharedMemory[threadIndex] = localValue;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    for (uint stride = threadgroupSize / 2; stride > 0; stride >>= 1) {
        if (threadIndex < stride && threadIndex + stride < threadgroupSize) {
            sharedMemory[threadIndex] = max(sharedMemory[threadIndex],
                                           sharedMemory[threadIndex + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 has final max, others have 0
    return (threadIndex == 0) ? sharedMemory[0] : 0;
}

/// Parallel reduction helper for computing min across threadgroup
template<typename T>
inline T threadgroupMin(
    T localValue,
    threadgroup T* sharedMemory,
    uint threadIndex,
    uint threadgroupSize
) {
    // Store local value in shared memory
    sharedMemory[threadIndex] = localValue;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction (binary tree pattern)
    for (uint stride = threadgroupSize / 2; stride > 0; stride >>= 1) {
        if (threadIndex < stride && threadIndex + stride < threadgroupSize) {
            sharedMemory[threadIndex] = min(sharedMemory[threadIndex],
                                           sharedMemory[threadIndex + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 has final min, others have 0
    return (threadIndex == 0) ? sharedMemory[0] : 0;
}

// MARK: - Utility Functions

/// Clamp value to [0, 1] range
inline float saturate(float x) {
    return clamp(x, 0.0f, 1.0f);
}

/// Check if pixel is within valid texture bounds
inline bool isValidPixel(uint2 gid, uint width, uint height) {
    return gid.x < width && gid.y < height;
}

/// Check if pixel has valid border for kernel operations (1-pixel margin)
inline bool isValidKernelPixel(uint2 gid, uint width, uint height) {
    return gid.x >= 1 && gid.x < width - 1 &&
           gid.y >= 1 && gid.y < height - 1;
}

/// Safe division (returns 0 if denominator is 0)
inline float safeDivide(float numerator, float denominator, float fallback = 0.0) {
    return (denominator != 0.0) ? (numerator / denominator) : fallback;
}
