//
//  TextureProcessing.metal
//  Tavi
//
//  Metal compute shaders for GPU-accelerated texture processing
//  Created on 2025-11-04.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Texture Blending Shader

/// Blend multiple texture samples with weighted accumulation
/// This kernel processes texture atlas creation in parallel on GPU
kernel void blendTextureSamples(
    // Output texture (accumulator)
    texture2d<float, access::write> outputTexture [[texture(0)]],
    // Input texture samples (array)
    texture2d_array<float, access::sample> inputTextures [[texture(1)]],
    // Weight texture (same size as output)
    texture2d<float, access::write> weightTexture [[texture(2)]],
    // Thread position
    uint2 gid [[thread_position_in_grid]],
    // Sample count
    constant uint& sampleCount [[buffer(0)]]
) {
    // Check bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Texture sampler (linear interpolation)
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Accumulate weighted samples
    float4 accumulatedColor = float4(0.0);
    float accumulatedWeight = 0.0;

    // Compute UV coordinates for this pixel
    float2 uv = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());

    // Sample all input textures
    for (uint i = 0; i < sampleCount; i++) {
        // Sample texture from array
        float4 color = inputTextures.sample(textureSampler, uv, i);

        // Check if this pixel has valid data (alpha > 0)
        float weight = color.a;

        if (weight > 0.0) {
            accumulatedColor += color * weight;
            accumulatedWeight += weight;
        }
    }

    // Normalize by total weight
    if (accumulatedWeight > 0.0) {
        accumulatedColor /= accumulatedWeight;
    }

    // Write output
    outputTexture.write(accumulatedColor, gid);
    weightTexture.write(float4(accumulatedWeight, 0, 0, 1), gid);
}

// MARK: - Color Space Conversion Shader

/// Convert RGBA to luminance (grayscale) in single pass
kernel void rgbaToLuminance(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Check bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read RGB pixel
    float4 color = inputTexture.read(gid);

    // Standard luminance conversion: Y = 0.299R + 0.587G + 0.114B
    float luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;

    // Write grayscale (Y, Y, Y, A)
    outputTexture.write(float4(luminance, luminance, luminance, color.a), gid);
}

// MARK: - Combined Blur + Luminance Shader (Optimized Fusion)

/// Apply Gaussian blur AND convert to luminance in single pass
/// This fused operation saves a full texture read/write cycle
kernel void gaussianBlurAndLuminance(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& sigma [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Check bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Compute Gaussian kernel size from sigma
    int radius = int(ceil(2.0 * sigma));
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    float4 accumulatedColor = float4(0.0);
    float accumulatedWeight = 0.0;

    // Gaussian blur kernel
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            // Compute Gaussian weight
            float distance = sqrt(float(dx * dx + dy * dy));
            float weight = exp(-(distance * distance) / (2.0 * sigma * sigma));

            // Sample texture at offset
            float2 uv = (float2(gid) + float2(dx, dy)) * texelSize;
            float4 color = inputTexture.sample(textureSampler, uv);

            accumulatedColor += color * weight;
            accumulatedWeight += weight;
        }
    }

    // Normalize
    accumulatedColor /= accumulatedWeight;

    // Convert to luminance
    float luminance = 0.299 * accumulatedColor.r + 0.587 * accumulatedColor.g + 0.114 * accumulatedColor.b;

    // Write luminance output
    outputTexture.write(float4(luminance, luminance, luminance, accumulatedColor.a), gid);
}
