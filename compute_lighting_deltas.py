#!/usr/bin/env python3
"""
Manual computation of expected lighting quality deltas
Simulates the analyzer and scorer behavior to predict test results
"""

import math

def map_pigmentation_score(index, lighting_quality=None):
    """
    Maps pigmentation index to score (0-100)
    Mimics Scoring3D.mapPigmentationScore()
    """
    low_threshold = 0.02
    high_threshold = 0.25

    # Apply threshold expansion for poor lighting
    if lighting_quality is not None and lighting_quality < 0.7:
        quality_deficit = 0.7 - lighting_quality
        expansion_factor = 1.0 + (quality_deficit * 0.7)
        effective_high = high_threshold * expansion_factor
    else:
        effective_high = high_threshold

    # Clamp index
    clamped_index = max(0.0, min(1.0, index))

    # Linear interpolation
    if clamped_index <= low_threshold:
        return 100.0
    elif clamped_index >= effective_high:
        return 0.0
    else:
        normalized = (clamped_index - low_threshold) / (effective_high - low_threshold)
        score = 100.0 - (normalized * 100.0)
        return max(0.0, min(100.0, score))

def estimate_gradient_variance():
    """
    Estimate variance for gradient field (brightness 0.6 to 1.0)
    Base color: (0.7, 0.5, 0.4)
    """
    # Simplified estimate: brightness gradient will create variance in all LAB channels
    # For a 40% brightness gradient, expect moderate variance increase
    # This is a rough approximation - actual RGB->LAB conversion needed for precision

    # Assuming gradient creates variance roughly proportional to brightness range
    # brightness_range = 0.4 (0.6 to 1.0)
    # Empirical estimate for medium skin tone:
    estimated_variance = 25.0  # This is a rough guess
    index = math.sqrt(estimated_variance) / 100.0
    return index

def estimate_shadow_variance():
    """
    Estimate variance for shadow field (33% pixels at 50% brightness)
    Creates bimodal distribution
    """
    # Bimodal distribution creates higher variance
    # Empirical estimate:
    estimated_variance = 100.0  # Higher due to sharp transition
    index = math.sqrt(estimated_variance) / 100.0
    return index

def main():
    print("=" * 80)
    print("LIGHTING QUALITY THRESHOLD EXPANSION ANALYSIS")
    print("=" * 80)

    # Test scenarios
    lighting_qualities = [
        (0.8, "good"),
        (0.5, "medium"),
        (0.3, "poor"),
        (0.0, "worst")
    ]

    # Scenario 1: Uniform field (very low variance)
    print("\n1. UNIFORM FIELD (baseline - no natural variance)")
    print("-" * 80)
    uniform_index = 0.001  # Near zero variance
    print(f"Estimated index: {uniform_index:.4f}")
    print(f"\nScores by lighting quality:")

    uniform_scores = []
    for quality, label in lighting_qualities:
        score = map_pigmentation_score(uniform_index, quality)
        uniform_scores.append(score)
        print(f"  {label:8} (quality={quality:.1f}): score={score:5.1f}")

    print(f"\nDeltas from baseline (quality=0.8):")
    for i in range(1, len(uniform_scores)):
        delta = uniform_scores[i] - uniform_scores[0]
        print(f"  {lighting_qualities[i][1]:8} (quality={lighting_qualities[i][0]:.1f}): {delta:+5.1f} points")

    # Scenario 2: Gradient field
    print("\n\n2. GRADIENT FIELD (40% brightness variation)")
    print("-" * 80)
    gradient_index = estimate_gradient_variance()
    print(f"Estimated index: {gradient_index:.4f}")
    print(f"\nScores by lighting quality:")

    gradient_scores = []
    for quality, label in lighting_qualities:
        score = map_pigmentation_score(gradient_index, quality)
        gradient_scores.append(score)
        expansion = 1.0 + ((0.7 - quality) * 0.7) if quality < 0.7 else 1.0
        eff_high = 0.25 * expansion
        print(f"  {label:8} (quality={quality:.1f}): score={score:5.1f}  [threshold: {eff_high:.4f}]")

    print(f"\nDeltas from baseline (quality=0.8):")
    for i in range(1, len(gradient_scores)):
        delta = gradient_scores[i] - gradient_scores[0]
        print(f"  {lighting_qualities[i][1]:8} (quality={lighting_qualities[i][0]:.1f}): {delta:+5.1f} points")

    # Scenario 3: Shadow field
    print("\n\n3. SHADOW FIELD (33% pixels at 50% brightness)")
    print("-" * 80)
    shadow_index = estimate_shadow_variance()
    print(f"Estimated index: {shadow_index:.4f}")
    print(f"\nScores by lighting quality:")

    shadow_scores = []
    for quality, label in lighting_qualities:
        score = map_pigmentation_score(shadow_index, quality)
        shadow_scores.append(score)
        expansion = 1.0 + ((0.7 - quality) * 0.7) if quality < 0.7 else 1.0
        eff_high = 0.25 * expansion
        print(f"  {label:8} (quality={quality:.1f}): score={score:5.1f}  [threshold: {eff_high:.4f}]")

    print(f"\nDeltas from baseline (quality=0.8):")
    for i in range(1, len(shadow_scores)):
        delta = shadow_scores[i] - shadow_scores[0]
        print(f"  {lighting_qualities[i][1]:8} (quality={lighting_qualities[i][0]:.1f}): {delta:+5.1f} points")

    # Analysis
    print("\n\n" + "=" * 80)
    print("THRESHOLD EXPANSION ANALYSIS")
    print("=" * 80)

    max_gradient_delta = abs(gradient_scores[-1] - gradient_scores[0])
    max_shadow_delta = abs(shadow_scores[-1] - shadow_scores[0])

    print(f"\nMaximum score deltas (worst quality vs baseline):")
    print(f"  Gradient field: {gradient_scores[-1] - gradient_scores[0]:+5.1f} points")
    print(f"  Shadow field:   {shadow_scores[-1] - shadow_scores[0]:+5.1f} points")

    print(f"\nThreshold expansion factors:")
    for quality, label in lighting_qualities:
        if quality < 0.7:
            expansion = 1.0 + ((0.7 - quality) * 0.7)
            print(f"  {label:8} (quality={quality:.1f}): {expansion:.3f}x (threshold: {0.25 * expansion:.4f})")

    print(f"\n\nRECOMMENDATION:")
    if max_gradient_delta < 15 and max_shadow_delta < 20:
        print("✅ KEEP expansion factor at 0.7")
        print("   Deltas are within acceptable range (<15 points for gradient, <20 for shadows)")
        print("   Threshold expansion provides reasonable leniency without hiding poor scans")
    else:
        print("⚠️  REDUCE expansion factor to 0.4")
        print(f"   Gradient delta ({max_gradient_delta:.1f}) or shadow delta ({max_shadow_delta:.1f}) too high")
        print("   Threshold expansion may be hiding poor lighting quality")

        # Recompute with reduced factor
        print("\n   With expansion factor 0.4:")
        reduced_gradient_scores = []
        for quality, label in lighting_qualities:
            expansion = 1.0 + ((0.7 - quality) * 0.4) if quality < 0.7 else 1.0
            eff_high = 0.25 * expansion
            # Recompute score
            if gradient_index <= 0.02:
                score = 100.0
            elif gradient_index >= eff_high:
                score = 0.0
            else:
                normalized = (gradient_index - 0.02) / (eff_high - 0.02)
                score = 100.0 - (normalized * 100.0)
            reduced_gradient_scores.append(score)

        reduced_delta = reduced_gradient_scores[-1] - reduced_gradient_scores[0]
        print(f"   Gradient delta: {reduced_delta:+5.1f} points (vs {max_gradient_delta:+5.1f} with 0.7)")

if __name__ == "__main__":
    main()
