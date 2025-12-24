//
//  TextureProcessing.metal
//  Tavi
//
//  Metal compute shaders for GPU-accelerated texture processing
//  Created on 2025-11-04.
//

#include <metal_stdlib>
using namespace metal;

// Import shared luminance helpers
#include "AnalyzerCommon.metal"

// MARK: - Texture Blending Shader

/// Blend multiple texture samples with weighted accumulation
/// This kernel processes texture atlas creation in parallel on GPU
///
/// FIX: Changed from using alpha as weight to using explicit per-sample weights
/// passed via buffer. This ensures camera images (which have alpha=1.0) are
/// properly weighted based on quality metrics.
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
    constant uint& sampleCount [[buffer(0)]],
    // Per-sample weights array (max 8 samples supported)
    constant float* sampleWeights [[buffer(1)]]
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
    for (uint i = 0; i < sampleCount && i < 8; i++) {
        // Sample texture from array
        float4 color = inputTextures.sample(textureSampler, uv, i);

        // Get the quality-based weight for this sample
        float sampleWeight = sampleWeights[i];

        // Calculate pixel validity based on brightness, not alpha
        // Camera images have alpha=1.0, so we check if the pixel has actual content
        float brightness = (color.r + color.g + color.b) / 3.0;

        // Only include non-black pixels (brightness > 0.02 threshold for noise)
        if (brightness > 0.02) {
            // Combine sample quality weight with pixel validity
            float weight = sampleWeight;

            accumulatedColor += float4(color.rgb * weight, weight);
            accumulatedWeight += weight;
        }
    }

    // Normalize by total weight
    float4 outputColor = float4(0.0, 0.0, 0.0, 0.0);
    if (accumulatedWeight > 0.0) {
        outputColor = float4(accumulatedColor.rgb / accumulatedWeight, 1.0);
    }

    // Write output
    outputTexture.write(outputColor, gid);
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

    float luminance = perceptualLuminance(color.rgb);

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

    float luminance = perceptualLuminance(accumulatedColor.rgb);

    // Write luminance output
    outputTexture.write(float4(luminance, luminance, luminance, accumulatedColor.a), gid);
}
