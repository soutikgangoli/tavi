# Scoring Engine Implementation

This document describes the scoring system that converts raw metrics (0-1) to interpretable percentage scores (0-100%).

## Overview

The ScoringEngine provides a user-friendly interpretation layer on top of raw metrics by:
- Converting 0-1 normalized metrics to 0-100% scores
- Using linear ramps with configurable thresholds
- Applying clamped bounds to ensure valid ranges
- Providing letter grades (A-F) for easy interpretation
- Supporting composite scoring with weighted combinations

## Components

### 1. Data Models (`ScoringModels.swift`)

#### ScoreSummary

Complete scoring summary for all ROIs:

```swift
public struct ScoreSummary {
    let roiScores: [ROIType: ROIScores]     // Per-ROI scores
    let averageScores: ROIScores             // Average across ROIs
    let overallScore: Double                 // Overall score (0-100%)
    let timestamp: Date

    var grade: ScoreGrade                    // A-F grade
}
```

#### ROIScores

Individual scores for a single ROI (all 0-100%):

```swift
public struct ROIScores {
    let sharpnessScore: Double          // 0-100%, higher = sharper
    let textureScore: Double            // 0-100%, higher = smoother
    let pigmentationScore: Double       // 0-100%, higher = more even
    let moistureScore: Double           // 0-100%, ~60% is ideal
    let roiType: ROIType?

    var compositeScore: Double          // Weighted average
    var grade: ScoreGrade               // A-F grade
}
```

**Composite Score Formula:**
```swift
composite = sharpness * 0.35 +
            texture * 0.25 +
            pigmentation * 0.25 +
            moisture * 0.15
```

#### ScoreGrade

Letter grades with score ranges:

| Grade | Range | Description |
|-------|-------|-------------|
| A (Excellent) | 90-100% | Outstanding skin quality |
| B (Good) | 70-89% | Good quality, minor improvements |
| C (Fair) | 50-69% | Moderate quality, targeted care recommended |
| D (Poor) | 30-49% | Below average, skincare attention needed |
| F (Very Poor) | 0-29% | Significant concerns, professional consultation |

```swift
public enum ScoreGrade: String {
    case excellent = "A"    // 90-100%
    case good = "B"         // 70-89%
    case fair = "C"         // 50-69%
    case poor = "D"         // 30-49%
    case veryPoor = "F"     // 0-29%
}
```

#### ScoringConstants

Configurable thresholds for metric-to-score conversion:

```swift
public struct ScoringConstants {
    // Sharpness (blur score → 0-100%)
    let sharpnessMin: Double = 0.3      // Maps to 0%
    let sharpnessMax: Double = 0.9      // Maps to 100%

    // Texture (texture energy → 0-100%, inverted)
    let textureMin: Double = 0.1        // Maps to 100%
    let textureMax: Double = 0.7        // Maps to 0%

    // Pigmentation (LAB variance → 0-100%, inverted)
    let pigmentationMin: Double = 0.1   // Maps to 100%
    let pigmentationMax: Double = 0.6   // Maps to 0%

    // Moisture (moisture index → 0-100%, peak at ideal)
    let moistureIdeal: Double = 0.6     // Maps to 100%
    let moistureTolerance: Double = 0.15

    // Discoloration (discoloration index → 0-100%, inverted)
    let discolorationMin: Double = 0.1  // Maps to 100%
    let discolorationMax: Double = 0.6  // Maps to 0%

    // Composite weights
    let compositeWeights: CompositeWeights

    // Overall weights
    let overallROIWeight: Double = 0.75
    let overallDiscolorationWeight: Double = 0.25
}
```

**Presets:**
- `.default` - Standard scoring
- `.strict` - Harder to achieve high scores
- `.lenient` - Easier to achieve high scores

### 2. Scoring Engine (`ScoringEngine.swift`)

Main scoring computation class.

#### Initialization

```swift
let engine = ScoringEngine(constants: .default)
```

#### Main Scoring Method

```swift
func computeScores(from metrics: MetricsResult) -> ScoreSummary
```

**Process:**
1. For each ROI:
   - Score sharpness (linear ramp)
   - Score texture (inverted ramp)
   - Score pigmentation (inverted ramp)
   - Score moisture (peak ramp)
2. Compute average scores across ROIs
3. Score discoloration (inverted ramp)
4. Compute overall score (weighted combination)

### 3. Ramp Functions

All ramp functions convert 0-1 input to 0-100% output with clamping.

#### Linear Ramp

Maps [min, max] → [0%, 100%] with linear interpolation:

```swift
func linearRamp(value: Double, min: Double, max: Double) -> Double {
    let normalized = (value - min) / (max - min)
    let clamped = clamp(normalized, min: 0.0, max: 1.0)
    return clamped * 100.0
}
```

**Behavior:**
- `value < min` → 0%
- `value > max` → 100%
- `value in [min, max]` → linear interpolation

**Example (Sharpness):**
```
min = 0.3, max = 0.9

blur_score = 0.2  → score = 0%    (below min)
blur_score = 0.3  → score = 0%    (at min)
blur_score = 0.6  → score = 50%   (halfway)
blur_score = 0.9  → score = 100%  (at max)
blur_score = 1.0  → score = 100%  (above max, clamped)
```

#### Inverted Linear Ramp

Maps [min, max] → [100%, 0%] with inverted linear interpolation:

```swift
func invertedLinearRamp(value: Double, min: Double, max: Double) -> Double {
    let normalized = (value - min) / (max - min)
    let clamped = clamp(normalized, min: 0.0, max: 1.0)
    return (1.0 - clamped) * 100.0
}
```

**Behavior:**
- `value < min` → 100%
- `value > max` → 0%
- `value in [min, max]` → inverted linear interpolation

**Example (Texture):**
```
min = 0.1, max = 0.7

texture_energy = 0.05 → score = 100%  (below min, very smooth)
texture_energy = 0.1  → score = 100%  (at min)
texture_energy = 0.4  → score = 50%   (halfway)
texture_energy = 0.7  → score = 0%    (at max, very rough)
texture_energy = 0.9  → score = 0%    (above max, clamped)
```

#### Peak Ramp

Maximum score at ideal value, decreases away from ideal:

```swift
func peakRamp(
    value: Double,
    ideal: Double,
    tolerance: Double,
    min: Double,
    max: Double
) -> Double
```

**Behavior:**
- `value == ideal` → 100%
- `value within tolerance` → 90-100% (linear decline within tolerance)
- `value outside tolerance` → 0-90% (linear decline to bounds)
- `value outside [min, max]` → 0%

**Example (Moisture):**
```
ideal = 0.6, tolerance = 0.15, min = 0.0, max = 1.0

moisture = 0.6   → score = 100%  (ideal)
moisture = 0.55  → score = 97%   (within tolerance)
moisture = 0.75  → score = 97%   (within tolerance)
moisture = 0.3   → score = 45%   (below tolerance)
moisture = 0.9   → score = 45%   (above tolerance)
moisture = 0.0   → score = 0%    (at min)
moisture = 1.0   → score = 0%    (at max)
```

**Zones:**
1. **Peak zone** (ideal ± tolerance): 90-100%
2. **Decline zone** (tolerance to bounds): 0-90%
3. **Out of bounds** (< min or > max): 0%

### 4. Individual Metric Scoring

#### Sharpness Score

```swift
func scoreSharpness(_ blurScore: Double) -> Double
```

- **Input**: Blur score (0-1), higher = sharper
- **Output**: Sharpness score (0-100%)
- **Ramp**: Linear (0.3 → 0.9)
- **Interpretation**: Higher score = sharper image

**Thresholds:**
- 0-30%: Very blurry
- 30-50%: Blurry
- 50-70%: Acceptable
- 70-90%: Sharp
- 90-100%: Very sharp

#### Texture Score

```swift
func scoreTexture(_ textureEnergy: Double) -> Double
```

- **Input**: Texture energy (0-1), higher = rougher
- **Output**: Texture score (0-100%)
- **Ramp**: Inverted linear (0.1 → 0.7)
- **Interpretation**: Higher score = smoother skin

**Thresholds:**
- 0-30%: Very rough
- 30-50%: Rough
- 50-70%: Moderate
- 70-90%: Smooth
- 90-100%: Very smooth

#### Pigmentation Score

```swift
func scorePigmentation(_ labVariance: Double) -> Double
```

- **Input**: LAB variance (0-1), higher = more uneven
- **Output**: Pigmentation score (0-100%)
- **Ramp**: Inverted linear (0.1 → 0.6)
- **Interpretation**: Higher score = more even pigmentation

**Thresholds:**
- 0-30%: Very uneven
- 30-50%: Uneven
- 50-70%: Moderate
- 70-90%: Even
- 90-100%: Very even

#### Moisture Score

```swift
func scoreMoisture(_ moistureIndex: Double) -> Double
```

- **Input**: Moisture index (0-1)
- **Output**: Moisture score (0-100%)
- **Ramp**: Peak (ideal = 0.6, tolerance = 0.15)
- **Interpretation**: ~60% score is ideal (normal moisture)

**Interpretation:**
- 0-20%: Very dry or very oily
- 20-40%: Dry or oily
- 40-60%: Slightly dry or slightly oily
- 60-80%: Normal to optimal (ideal)
- 80-100%: Optimal (ideal ± tolerance)

#### Discoloration Score

```swift
func scoreDiscoloration(_ discolorationIndex: Double) -> Double
```

- **Input**: Discoloration index (0-1), higher = more variation
- **Output**: Discoloration score (0-100%)
- **Ramp**: Inverted linear (0.1 → 0.6)
- **Interpretation**: Higher score = more uniform skin tone

**Thresholds:**
- 0-30%: Significant discoloration
- 30-50%: Moderate discoloration
- 50-70%: Slight variation
- 70-90%: Uniform
- 90-100%: Very uniform

### 5. Overall Scoring

```swift
overallScore = averageCompositeScore * 0.75 +
               discolorationScore * 0.25
```

**Weights:**
- **75%**: Average composite score (combines all per-ROI metrics)
- **25%**: Discoloration score (uniformity across face)

## Usage Examples

### Basic Usage

```swift
// After computing metrics
let metrics: MetricsResult = ...

// Create scoring engine
let engine = ScoringEngine()

// Compute scores
let scores = engine.computeScores(from: metrics)

print("Overall Score: \(scores.overallScore)%")
print("Grade: \(scores.grade.rawValue)")

// Access individual scores
for (roiType, roiScores) in scores.roiScores {
    print("\n\(roiType.displayName):")
    print("  Composite: \(roiScores.compositeScore)%")
    print("  Sharpness: \(roiScores.sharpnessScore)%")
    print("  Texture: \(roiScores.textureScore)%")
    print("  Pigmentation: \(roiScores.pigmentationScore)%")
    print("  Moisture: \(roiScores.moistureScore)%")
}
```

### Using Presets

```swift
// Strict scoring
let strictEngine = ScoringEngine(constants: .strict)
let strictScores = strictEngine.computeScores(from: metrics)

// Lenient scoring
let lenientEngine = ScoringEngine(constants: .lenient)
let lenientScores = lenientEngine.computeScores(from: metrics)

// Compare
print("Strict: \(strictScores.overallScore)%")
print("Default: \(scores.overallScore)%")
print("Lenient: \(lenientScores.overallScore)%")
```

### Custom Configuration

```swift
let customConstants = ScoringConstants(
    sharpnessMin: 0.4,      // Stricter blur requirement
    sharpnessMax: 0.95,
    textureMin: 0.05,
    textureMax: 0.65,
    pigmentationMin: 0.08,
    pigmentationMax: 0.55,
    moistureIdeal: 0.65,    // Different ideal moisture
    moistureTolerance: 0.1,
    discolorationMin: 0.08,
    discolorationMax: 0.55
)

let customEngine = ScoringEngine(constants: customConstants)
```

### Convenience Extensions

```swift
// Direct scoring from metrics
let scores = metrics.scores()

// Direct scoring from ROI metrics
let roiMetrics: ROIMetrics = ...
let roiScores = roiMetrics.scores()
```

### Score Interpretation

```swift
let interpretation = engine.interpretScore(scores.overallScore)
print(interpretation)

// Get detailed breakdown
let breakdown = engine.scoringBreakdown(for: metrics)
print(breakdown)
```

### Tracking Changes Over Time

```swift
let previousScores: ScoreSummary = ...
let currentScores: ScoreSummary = ...

let change = ScoreChange(current: currentScores, previous: previousScores)

print("Overall change: \(change.overallChange) points")
print("Interpretation: \(change.interpretation)")

let metricChanges = change.averageScoreChanges()
print("Sharpness change: \(metricChanges.sharpness) points")
print("Texture change: \(metricChanges.texture) points")
print("Pigmentation change: \(metricChanges.pigmentation) points")
print("Moisture change: \(metricChanges.moisture) points")
```

## Score Interpretation Guide

### Overall Score Ranges

| Score | Grade | Interpretation | Action |
|-------|-------|----------------|--------|
| 90-100% | A | Excellent skin quality | Maintain current routine |
| 70-89% | B | Good quality | Minor adjustments possible |
| 50-69% | C | Fair quality | Consider targeted care |
| 30-49% | D | Poor quality | Skincare attention needed |
| 0-29% | F | Very poor | Professional consultation recommended |

### Individual Metric Interpretation

**Sharpness:**
- **90-100%**: Excellent focus, crisp details
- **70-89%**: Good focus, minor blur
- **50-69%**: Acceptable but could be sharper
- **30-49%**: Blurry, recapture recommended
- **0-29%**: Very blurry, unusable

**Texture:**
- **90-100%**: Very smooth skin, minimal pores
- **70-89%**: Smooth skin, small pores
- **50-69%**: Moderate texture, visible pores
- **30-49%**: Rough texture, prominent pores
- **0-29%**: Very rough, significant pore visibility

**Pigmentation:**
- **90-100%**: Very even tone, no spots
- **70-89%**: Even tone, minimal variation
- **50-69%**: Moderate variation, some spots
- **30-49%**: Uneven tone, visible spots
- **0-29%**: Significant discoloration

**Moisture:**
- **80-100%**: Optimal (at ideal ± tolerance)
- **60-79%**: Normal, slightly dry or oily
- **40-59%**: Dry or oily, care recommended
- **20-39%**: Very dry or very oily
- **0-19%**: Extreme dryness or oiliness

## Configuration Guidelines

### Choosing Thresholds

**Sharpness (min, max):**
- Higher min/max = stricter requirements for high scores
- Lower min/max = more lenient scoring
- Typical range: (0.2-0.4, 0.85-0.95)

**Texture (min, max):**
- Lower min = more lenient (smoother skin = 100%)
- Higher max = includes rougher textures
- Typical range: (0.05-0.15, 0.6-0.8)

**Pigmentation (min, max):**
- Lower min = stricter evenness requirement
- Higher max = more tolerant of variation
- Typical range: (0.05-0.15, 0.5-0.7)

**Moisture (ideal, tolerance):**
- Ideal: target moisture level (typically 0.5-0.7)
- Tolerance: acceptable deviation (0.1-0.2)
- Narrower tolerance = stricter scoring

### Weight Adjustment

**Composite Weights:**
```swift
// Prioritize sharpness
CompositeWeights(
    sharpness: 0.50,
    texture: 0.20,
    pigmentation: 0.20,
    moisture: 0.10
)

// Balanced
CompositeWeights(
    sharpness: 0.35,
    texture: 0.25,
    pigmentation: 0.25,
    moisture: 0.15
)

// Prioritize appearance
CompositeWeights(
    sharpness: 0.25,
    texture: 0.30,
    pigmentation: 0.30,
    moisture: 0.15
)
```

**Overall Weights:**
```swift
// More weight on ROI quality
overallROIWeight: 0.80
overallDiscolorationWeight: 0.20

// More weight on uniformity
overallROIWeight: 0.60
overallDiscolorationWeight: 0.40
```

## File Locations

- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/MetricsKit/ScoringModels.swift`
- `/Users/apple/Desktop/Skin App IOS/Tavi/Core/MetricsKit/ScoringEngine.swift`

## Integration Points

### CameraViewModel

```swift
@Published var lastScoreSummary: ScoreSummary?
private let scoringEngine = ScoringEngine(constants: .default)

func computeMetrics(for roiImages: [ExtractedROIImage]) async {
    let metrics = try await metricsComputer.computeMetrics(for: roiImages)
    let scores = scoringEngine.computeScores(from: metrics)
    lastScoreSummary = scores
}
```

### UI Components

- **ScoreSummaryView.swift** - Displays all scores with visual bars and grades
- **MetricsResultView.swift** - "View Analysis Scores" button
- **CaptureResultView.swift** - Passes scores through to views

## Future Enhancements

- Percentile-based grading (relative to population)
- Confidence intervals for scores
- Score trends over time with visualization
- Personalized baseline scores
- Adaptive thresholds based on skin type
- Score explanations with actionable insights
- Export scores as reports
- Historical score tracking
- Recommendations based on low scores
