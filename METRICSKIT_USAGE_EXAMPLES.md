# MetricsKit Usage Examples

Complete examples demonstrating MetricsKit integration and usage patterns.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Individual Metrics](#individual-metrics)
3. [Custom Configuration](#custom-configuration)
4. [Complete Workflow](#complete-workflow)
5. [UI Integration](#ui-integration)
6. [Error Handling](#error-handling)
7. [Performance Optimization](#performance-optimization)
8. [Interpretation Guide](#interpretation-guide)

## Basic Usage

### Compute All Metrics After Capture

```swift
import Foundation

// After successful multi-frame capture
let captureResult: CaptureResult = ...

// Initialize metrics computer
let metricsComputer = MetricsComputer()

// Compute all metrics
do {
    let metrics = try metricsComputer.computeMetrics(for: captureResult.roiImages)

    print("Overall Quality Score: \(metrics.overallQualityScore)")
    print("Discoloration Index: \(metrics.discolorationIndex)")

    // Access individual ROI metrics
    for (roiType, roiMetrics) in metrics.roiMetrics {
        print("\n\(roiType.displayName):")
        print("  Quality: \(roiMetrics.qualityScore)")
        print("  Blur: \(roiMetrics.blurScore)")
        print("  Texture: \(roiMetrics.textureEnergy)")
        print("  LAB Variance: \(roiMetrics.labVariance)")
        print("  Moisture: \(roiMetrics.moistureProxy.moistureIndex)")
    }

} catch {
    print("Metrics computation failed: \(error)")
}
```

### Quick Quality Check

```swift
// Quick check if capture is good quality
func isGoodQuality(metrics: MetricsResult) -> Bool {
    guard let avgMetrics = metrics.averageMetrics else { return false }

    // Check blur (should be sharp)
    guard avgMetrics.blurScore > 0.5 else {
        print("⚠️ Image too blurry - recapture recommended")
        return false
    }

    // Check overall quality
    if metrics.overallQualityScore > 0.7 {
        print("✅ Excellent quality")
        return true
    } else if metrics.overallQualityScore > 0.5 {
        print("ℹ️ Acceptable quality")
        return true
    } else {
        print("⚠️ Poor quality - recapture recommended")
        return false
    }
}
```

## Individual Metrics

### Blur Score Only

```swift
let computer = MetricsComputer()

// From CGImage
let roiImage: CGImage = ...
let blurScore = try computer.computeBlurScore(image: roiImage)

print("Blur Score: \(String(format: "%.2f", blurScore))")

if blurScore > 0.7 {
    print("Very sharp")
} else if blurScore > 0.5 {
    print("Sharp")
} else if blurScore > 0.3 {
    print("Slightly blurry")
} else {
    print("Very blurry")
}
```

### Texture Energy Analysis

```swift
let computer = MetricsComputer()

// Analyze skin texture
let textureEnergy = try computer.computeTextureEnergy(imageROI: roiImage)

print("Texture Energy: \(String(format: "%.2f", textureEnergy))")

// Lower is smoother
if textureEnergy < 0.2 {
    print("Very smooth skin")
} else if textureEnergy < 0.5 {
    print("Moderate texture")
} else {
    print("Rough texture - visible pores")
}
```

### LAB Variance (Pigmentation)

```swift
let computer = MetricsComputer()

// Analyze pigmentation evenness
let labVariance = try computer.computeLABVariance(imageROI: roiImage)

print("Pigmentation Variance: \(String(format: "%.2f", labVariance))")

if labVariance < 0.2 {
    print("Very even pigmentation")
} else if labVariance < 0.4 {
    print("Slightly uneven")
} else if labVariance < 0.6 {
    print("Moderate variation (spots/blemishes)")
} else {
    print("Significant discoloration")
}
```

### Moisture Proxy

```swift
let computer = MetricsComputer()

// Analyze moisture indicators
let moisture = try computer.computeMoistureProxy(imageROI: roiImage)

print("Specular Ratio: \(String(format: "%.1f%%", moisture.specularRatio * 100))")
print("Smoothness: \(String(format: "%.1f%%", moisture.smoothnessLowFreq * 100))")
print("Moisture Index: \(String(format: "%.1f%%", moisture.moistureIndex * 100))")

if moisture.moistureIndex < 0.3 {
    print("Dry skin indicators")
} else if moisture.moistureIndex < 0.7 {
    print("Normal moisture")
} else {
    print("High moisture / oily")
}
```

### Discoloration Analysis

```swift
let computer = MetricsComputer()

// Compare skin tone across face regions
let roiImages: [ExtractedROIImage] = captureResult.roiImages
let discoloration = try computer.computeDiscolorationIndex(roiImages: roiImages)

print("Discoloration Index: \(String(format: "%.2f", discoloration))")

if discoloration < 0.3 {
    print("Very uniform skin tone")
} else if discoloration < 0.6 {
    print("Moderate variation")
} else {
    print("Significant tone differences across face")
}
```

## Custom Configuration

### Sensitivity Adjustment

```swift
// Create custom configuration
let customConfig = MetricsConfiguration(
    // More lenient blur thresholds
    minBlur: 30.0,      // Lower bound (very blurry)
    maxBlur: 250.0,     // Upper bound (very sharp)

    // Texture energy range
    minTextureEnergy: 0.005,
    maxTextureEnergy: 0.6,

    // LAB variance range
    minLABVariance: 0.0,
    maxLABVariance: 60.0,

    // More sensitive specular detection
    specularThreshold: 200,  // Lower = more sensitive

    // Larger smoothing kernel
    smoothnessKernelSize: 21  // 21x21 box filter
)

let computer = MetricsComputer(configuration: customConfig)
```

### Application-Specific Presets

```swift
extension MetricsConfiguration {
    /// High sensitivity for clinical analysis
    static let clinical = MetricsConfiguration(
        minBlur: 80.0,
        maxBlur: 300.0,
        minTextureEnergy: 0.02,
        maxTextureEnergy: 0.7,
        minLABVariance: 0.0,
        maxLABVariance: 40.0,
        specularThreshold: 230,
        smoothnessKernelSize: 11
    )

    /// Lower sensitivity for consumer app
    static let consumer = MetricsConfiguration(
        minBlur: 30.0,
        maxBlur: 180.0,
        minTextureEnergy: 0.01,
        maxTextureEnergy: 0.5,
        minLABVariance: 0.0,
        maxLABVariance: 60.0,
        specularThreshold: 210,
        smoothnessKernelSize: 17
    )
}

// Usage
let clinicalComputer = MetricsComputer(configuration: .clinical)
let consumerComputer = MetricsComputer(configuration: .consumer)
```

## Complete Workflow

### End-to-End Analysis

```swift
@MainActor
class SkinAnalysisCoordinator {
    private let captureController = CaptureController()
    private let metricsComputer = MetricsComputer()

    func performAnalysis(
        frameProvider: @escaping () async -> CVPixelBuffer?
    ) async throws -> (CaptureResult, MetricsResult) {

        // Step 1: Capture multi-frame image
        print("Starting capture...")
        let captureResult = try await captureController.startCapture(
            frameProvider: frameProvider
        )
        print("✅ Captured \(captureResult.sharpFramesUsed) sharp frames")

        // Step 2: Compute metrics
        print("Computing metrics...")
        let metrics = try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { throw MetricsError.insufficientROIs }
            return try self.metricsComputer.computeMetrics(for: captureResult.roiImages)
        }.value
        print("✅ Metrics computed")

        // Step 3: Validate quality
        try validateQuality(metrics: metrics)

        return (captureResult, metrics)
    }

    private func validateQuality(metrics: MetricsResult) throws {
        guard let avgMetrics = metrics.averageMetrics else {
            throw AnalysisError.noMetrics
        }

        // Check blur
        if avgMetrics.blurScore < 0.4 {
            throw AnalysisError.tooBlurry(score: avgMetrics.blurScore)
        }

        // Check overall quality
        if metrics.overallQualityScore < 0.3 {
            throw AnalysisError.poorQuality(score: metrics.overallQualityScore)
        }
    }
}

enum AnalysisError: Error, LocalizedError {
    case noMetrics
    case tooBlurry(score: Double)
    case poorQuality(score: Double)

    var errorDescription: String? {
        switch self {
        case .noMetrics:
            return "No metrics available"
        case .tooBlurry(let score):
            return "Image too blurry (score: \(String(format: "%.2f", score)))"
        case .poorQuality(let score):
            return "Poor image quality (score: \(String(format: "%.2f", score)))"
        }
    }
}
```

### Batch Processing

```swift
func analyzeMultipleCaptures(
    captureResults: [CaptureResult]
) async throws -> [MetricsResult] {
    let computer = MetricsComputer()
    var allMetrics: [MetricsResult] = []

    for (index, result) in captureResults.enumerated() {
        print("Processing capture \(index + 1)/\(captureResults.count)...")

        let metrics = try await Task.detached {
            try computer.computeMetrics(for: result.roiImages)
        }.value

        allMetrics.append(metrics)
    }

    return allMetrics
}
```

## UI Integration

### SwiftUI ViewModel Integration

```swift
@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var captureResult: CaptureResult?
    @Published var metricsResult: MetricsResult?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    private let metricsComputer = MetricsComputer()

    func analyzeCapture(_ result: CaptureResult) async {
        isAnalyzing = true
        errorMessage = nil

        do {
            let metrics = try await Task.detached { [weak self] in
                try self?.metricsComputer.computeMetrics(for: result.roiImages)
            }.value

            guard let metrics = metrics else { return }

            self.captureResult = result
            self.metricsResult = metrics

        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }
}
```

### SwiftUI View

```swift
struct AnalysisView: View {
    @StateObject private var viewModel = AnalysisViewModel()
    let captureResult: CaptureResult

    var body: some View {
        VStack {
            if viewModel.isAnalyzing {
                ProgressView("Analyzing...")
            } else if let metrics = viewModel.metricsResult {
                MetricsResultView(
                    metrics: metrics,
                    isPresented: .constant(true)
                )
            }
        }
        .task {
            await viewModel.analyzeCapture(captureResult)
        }
    }
}
```

## Error Handling

### Comprehensive Error Handling

```swift
func safeMetricsComputation(
    roiImages: [ExtractedROIImage]
) async -> Result<MetricsResult, Error> {
    let computer = MetricsComputer()

    do {
        // Validate inputs
        guard !roiImages.isEmpty else {
            throw MetricsError.insufficientROIs
        }

        // Ensure valid images
        for roiImage in roiImages {
            guard roiImage.image.width > 0 && roiImage.image.height > 0 else {
                throw MetricsError.invalidImageDimensions
            }
        }

        // Compute metrics
        let metrics = try await Task.detached {
            try computer.computeMetrics(for: roiImages)
        }.value

        return .success(metrics)

    } catch let error as MetricsError {
        // Handle known errors
        print("Metrics error: \(error.localizedDescription)")
        return .failure(error)

    } catch {
        // Handle unknown errors
        print("Unexpected error: \(error)")
        return .failure(error)
    }
}

// Usage
let result = await safeMetricsComputation(roiImages: roiImages)

switch result {
case .success(let metrics):
    print("Quality score: \(metrics.overallQualityScore)")

case .failure(let error):
    print("Failed: \(error.localizedDescription)")
}
```

## Performance Optimization

### Parallel Processing

```swift
func parallelMetricsComputation(
    roiImages: [ExtractedROIImage]
) async throws -> MetricsResult {
    let computer = MetricsComputer()

    // Process on background queue
    return try await Task.detached(priority: .userInitiated) {
        try computer.computeMetrics(for: roiImages)
    }.value
}
```

### Caching Results

```swift
actor MetricsCache {
    private var cache: [String: MetricsResult] = [:]

    func get(for key: String) -> MetricsResult? {
        return cache[key]
    }

    func set(_ metrics: MetricsResult, for key: String) {
        cache[key] = metrics
    }

    func clear() {
        cache.removeAll()
    }
}

class CachingMetricsComputer {
    private let computer = MetricsComputer()
    private let cache = MetricsCache()

    func computeMetrics(
        for roiImages: [ExtractedROIImage],
        cacheKey: String? = nil
    ) async throws -> MetricsResult {

        // Check cache
        if let key = cacheKey,
           let cached = await cache.get(for: key) {
            print("Using cached metrics")
            return cached
        }

        // Compute
        let metrics = try computer.computeMetrics(for: roiImages)

        // Cache result
        if let key = cacheKey {
            await cache.set(metrics, for: key)
        }

        return metrics
    }
}
```

## Interpretation Guide

### Quality Score Interpretation

```swift
func interpretQualityScore(_ score: Double) -> (level: String, description: String, color: Color) {
    switch score {
    case 0.8...1.0:
        return ("Excellent", "Superior image quality with sharp focus and even skin tone", .green)
    case 0.6..<0.8:
        return ("Good", "High quality image suitable for detailed analysis", .green)
    case 0.4..<0.6:
        return ("Fair", "Acceptable quality but may benefit from recapture", .orange)
    case 0.2..<0.4:
        return ("Poor", "Low quality - recapture recommended", .orange)
    default:
        return ("Very Poor", "Unsuitable for analysis - recapture required", .red)
    }
}

// Usage
let interpretation = interpretQualityScore(metrics.overallQualityScore)
print("\(interpretation.level): \(interpretation.description)")
```

### ROI-Specific Analysis

```swift
func analyzeROI(_ roiType: ROIType, metrics: ROIMetrics) -> [String] {
    var insights: [String] = []

    // Blur check
    if metrics.blurScore < 0.5 {
        insights.append("⚠️ Blurry image in \(roiType.displayName)")
    }

    // Texture analysis
    if metrics.textureEnergy > 0.6 {
        insights.append("ℹ️ Rough texture detected (visible pores)")
    } else if metrics.textureEnergy < 0.2 {
        insights.append("✨ Very smooth skin texture")
    }

    // Pigmentation
    if metrics.labVariance > 0.5 {
        insights.append("ℹ️ Uneven pigmentation (spots/blemishes)")
    } else if metrics.labVariance < 0.2 {
        insights.append("✨ Even skin tone")
    }

    // Moisture
    let moisture = metrics.moistureProxy.moistureIndex
    if moisture < 0.3 {
        insights.append("💧 Dry skin indicators")
    } else if moisture > 0.7 {
        insights.append("💦 High moisture / oily skin")
    }

    return insights
}

// Usage
for (roiType, roiMetrics) in metrics.roiMetrics {
    print("\n\(roiType.displayName):")
    let insights = analyzeROI(roiType, metrics: roiMetrics)
    insights.forEach { print("  \($0)") }
}
```

### Trend Analysis

```swift
struct MetricsTrend {
    let current: MetricsResult
    let previous: MetricsResult

    func qualityChange() -> Double {
        return current.overallQualityScore - previous.overallQualityScore
    }

    func interpretation() -> String {
        let change = qualityChange()

        if abs(change) < 0.05 {
            return "No significant change"
        } else if change > 0 {
            return "Improved by \(String(format: "%.1f%%", change * 100))"
        } else {
            return "Decreased by \(String(format: "%.1f%%", abs(change) * 100))"
        }
    }

    func roiChanges() -> [ROIType: Double] {
        var changes: [ROIType: Double] = [:]

        for roiType in ROIType.allCases {
            if let currentROI = current.roiMetrics[roiType],
               let previousROI = previous.roiMetrics[roiType] {
                changes[roiType] = currentROI.qualityScore - previousROI.qualityScore
            }
        }

        return changes
    }
}

// Usage
let trend = MetricsTrend(current: newMetrics, previous: oldMetrics)
print("Overall: \(trend.interpretation())")

for (roiType, change) in trend.roiChanges() {
    if abs(change) > 0.05 {
        let direction = change > 0 ? "↑" : "↓"
        print("\(roiType.displayName): \(direction) \(String(format: "%.1f%%", abs(change) * 100))")
    }
}
```

### Export for Analysis

```swift
extension MetricsResult {
    func toCSV() -> String {
        var csv = "ROI,Quality,Blur,Texture,LAB Variance,Moisture,Specular,Smoothness\n"

        for (roiType, metrics) in roiMetrics.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            csv += "\(roiType.displayName),"
            csv += "\(String(format: "%.3f", metrics.qualityScore)),"
            csv += "\(String(format: "%.3f", metrics.blurScore)),"
            csv += "\(String(format: "%.3f", metrics.textureEnergy)),"
            csv += "\(String(format: "%.3f", metrics.labVariance)),"
            csv += "\(String(format: "%.3f", metrics.moistureProxy.moistureIndex)),"
            csv += "\(String(format: "%.3f", metrics.moistureProxy.specularRatio)),"
            csv += "\(String(format: "%.3f", metrics.moistureProxy.smoothnessLowFreq))\n"
        }

        csv += "\nOverall Quality,\(String(format: "%.3f", overallQualityScore))\n"
        csv += "Discoloration Index,\(String(format: "%.3f", discolorationIndex))\n"

        return csv
    }

    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(self)
    }
}
```

## Best Practices

### 1. Always Validate Input
```swift
guard !roiImages.isEmpty else {
    throw MetricsError.insufficientROIs
}
```

### 2. Use Background Processing
```swift
let metrics = try await Task.detached(priority: .userInitiated) {
    try computer.computeMetrics(for: roiImages)
}.value
```

### 3. Handle Errors Gracefully
```swift
do {
    let metrics = try computer.computeMetrics(for: roiImages)
} catch {
    // Provide user-friendly error message
    showError("Unable to analyze image. Please try again.")
}
```

### 4. Provide User Feedback
```swift
// Show progress
isAnalyzing = true

// Compute
let metrics = try await computeMetrics()

// Update UI
isAnalyzing = false
showResults(metrics)
```

### 5. Consider Lighting Conditions
```swift
// Check if image was captured with calibration
if captureResult.wasCalibrated {
    // More reliable metrics
    let metrics = try computer.computeMetrics(for: roiImages)
} else {
    // May need adjusted interpretation
    print("⚠️ Captured without calibration - metrics may be less reliable")
}
```
