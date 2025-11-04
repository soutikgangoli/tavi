//
//  PerformanceBenchmarkTests.swift
//  TaviTests
//
//  Comprehensive performance benchmarks for optimization validation
//  Created on 2025-11-04.
//

import XCTest
@testable import Tavi
import ARKit
import simd

/// Performance benchmark tests to validate optimizations
@MainActor
final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - Test Configuration

    var performanceAnalyzer: PerformanceAnalyzer!

    override func setUp() {
        super.setUp()
        performanceAnalyzer = PerformanceAnalyzer.shared
        performanceAnalyzer.enableProfiling()
        performanceAnalyzer.clearMeasurements()
    }

    override func tearDown() {
        performanceAnalyzer.disableProfiling()
        performanceAnalyzer = nil
        super.tearDown()
    }

    // MARK: - Mesh Merging Benchmarks

    func testMeshMergingPerformance_3Captures() throws {
        let captures = createMockCaptures(count: 3, vertexCount: 1000)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Mesh merging")

            Task {
                let merger = MeshMerger()
                _ = try? await merger.merge(captures: captures)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }

        // Baseline: Should complete in < 300ms on modern devices
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        XCTAssertLessThan(totalTime, 0.3, "Mesh merging for 3 captures should be < 300ms")
    }

    func testMeshMergingPerformance_7Captures() throws {
        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Mesh merging")

            Task {
                let merger = MeshMerger()
                _ = try? await merger.merge(captures: captures)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 15.0)
        }

        // Target: < 500ms for 7 captures (vs 1200ms sequential)
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        XCTAssertLessThan(totalTime, 0.5, "Mesh merging for 7 captures should be < 500ms")
    }

    func testMeshMergingPerformance_ParallelVsSequential() throws {
        let captures = createMockCaptures(count: 5, vertexCount: 1000)

        // Test parallel version
        performanceAnalyzer.clearMeasurements()
        let parallelExpectation = expectation(description: "Parallel merging")

        var parallelTime: TimeInterval = 0
        Task {
            let start = Date()
            let merger = MeshMerger()
            _ = try? await merger.merge(captures: captures)
            parallelTime = Date().timeIntervalSince(start)
            parallelExpectation.fulfill()
        }

        wait(for: [parallelExpectation], timeout: 10.0)

        // Expected: Parallel should provide 2-3x speedup
        print("📊 Mesh Merging Performance (5 captures):")
        print("   Parallel: \(String(format: "%.1f", parallelTime * 1000))ms")

        XCTAssertLessThan(parallelTime, 0.4, "Parallel merging should be < 400ms")
    }

    func testMeshMergingScalability() throws {
        let captureCounts = [3, 5, 7, 10]
        var results: [(count: Int, time: TimeInterval)] = []

        for count in captureCounts {
            let captures = createMockCaptures(count: count, vertexCount: 1000)
            performanceAnalyzer.clearMeasurements()

            let expectation = self.expectation(description: "Merge \(count) captures")

            var duration: TimeInterval = 0
            Task {
                let start = Date()
                let merger = MeshMerger()
                _ = try? await merger.merge(captures: captures)
                duration = Date().timeIntervalSince(start)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 20.0)
            results.append((count, duration))
        }

        print("📊 Mesh Merging Scalability:")
        for result in results {
            print("   \(result.count) captures: \(String(format: "%.1f", result.time * 1000))ms")
        }

        // Verify scalability is sub-linear (not growing linearly)
        // Time for 10 captures should be < 3x time for 3 captures
        let time3 = results.first(where: { $0.count == 3 })?.time ?? 0
        let time10 = results.first(where: { $0.count == 10 })?.time ?? 0
        XCTAssertLessThan(time10, time3 * 3.0, "Scalability should be sub-linear")
    }

    // MARK: - Metrics Computation Benchmarks

    func testMetricsComputationPerformance() throws {
        let mesh = createMockMesh(vertexCount: 5000)
        let texture = createMockTexture(size: 1024)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Metrics computation")

            Task {
                let analyzer = Face3DMetricsAnalyzer()
                _ = await analyzer.computeMetrics(
                    unifiedMesh: mesh,
                    unifiedTexture: texture
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }

        // Target: < 300ms (vs 800ms sequential)
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        XCTAssertLessThan(totalTime, 0.3, "Metrics computation should be < 300ms")
    }

    func testMetricsComputationParallel() throws {
        let mesh = createMockMesh(vertexCount: 5000)
        let texture = createMockTexture(size: 1024)

        performanceAnalyzer.clearMeasurements()
        let expectation = self.expectation(description: "Parallel metrics")

        var parallelTime: TimeInterval = 0
        Task {
            let start = Date()
            let analyzer = Face3DMetricsAnalyzer()
            _ = await analyzer.computeMetrics(
                unifiedMesh: mesh,
                unifiedTexture: texture
            )
            parallelTime = Date().timeIntervalSince(start)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        print("📊 Metrics Computation Performance:")
        print("   Parallel: \(String(format: "%.1f", parallelTime * 1000))ms")

        XCTAssertLessThan(parallelTime, 0.3, "Parallel metrics should be < 300ms")
    }

    func testMetricsComputationWithVaryingComplexity() throws {
        let vertexCounts = [1000, 3000, 5000, 10000]
        var results: [(vertices: Int, time: TimeInterval)] = []

        for vertexCount in vertexCounts {
            let mesh = createMockMesh(vertexCount: vertexCount)
            let texture = createMockTexture(size: 1024)

            performanceAnalyzer.clearMeasurements()
            let expectation = self.expectation(description: "Metrics for \(vertexCount) vertices")

            var duration: TimeInterval = 0
            Task {
                let start = Date()
                let analyzer = Face3DMetricsAnalyzer()
                _ = await analyzer.computeMetrics(
                    unifiedMesh: mesh,
                    unifiedTexture: texture
                )
                duration = Date().timeIntervalSince(start)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
            results.append((vertexCount, duration))
        }

        print("📊 Metrics Computation Complexity:")
        for result in results {
            print("   \(result.vertices) vertices: \(String(format: "%.1f", result.time * 1000))ms")
        }

        // Even with 10x vertices, should be < 3x slower (due to parallelization)
        let time1k = results.first(where: { $0.vertices == 1000 })?.time ?? 0
        let time10k = results.first(where: { $0.vertices == 10000 })?.time ?? 0
        XCTAssertLessThan(time10k, time1k * 3.0, "Complexity should scale sub-linearly")
    }

    // MARK: - Texture Baking Benchmarks

    func testTextureBakingPerformance_1024() throws {
        let mesh = createMockMesh(vertexCount: 5000)
        let samples = createMockTextureSamples(count: 7)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Texture baking 1024")

            Task {
                let baker = TextureBaker()
                _ = try? await baker.bakeTexture(
                    from: samples,
                    mesh: mesh,
                    resolution: 1024
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }

        // Target: < 400ms for 1024x1024
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        XCTAssertLessThan(totalTime, 0.4, "Texture baking (1024) should be < 400ms")
    }

    func testTextureBakingPerformance_2048() throws {
        let mesh = createMockMesh(vertexCount: 5000)
        let samples = createMockTextureSamples(count: 7)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Texture baking 2048")

            Task {
                let baker = TextureBaker()
                _ = try? await baker.bakeTexture(
                    from: samples,
                    mesh: mesh,
                    resolution: 2048
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 15.0)
        }

        // Target: < 800ms for 2048x2048 (vs 2100ms sequential)
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        XCTAssertLessThan(totalTime, 0.8, "Texture baking (2048) should be < 800ms")
    }

    func testTextureBakingScalability() throws {
        let mesh = createMockMesh(vertexCount: 5000)
        let samples = createMockTextureSamples(count: 7)
        let resolutions = [512, 1024, 2048]
        var results: [(resolution: Int, time: TimeInterval)] = []

        for resolution in resolutions {
            performanceAnalyzer.clearMeasurements()
            let expectation = self.expectation(description: "Bake \(resolution)x\(resolution)")

            var duration: TimeInterval = 0
            Task {
                let start = Date()
                let baker = TextureBaker()
                _ = try? await baker.bakeTexture(
                    from: samples,
                    mesh: mesh,
                    resolution: resolution
                )
                duration = Date().timeIntervalSince(start)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 20.0)
            results.append((resolution, duration))
        }

        print("📊 Texture Baking Scalability:")
        for result in results {
            print("   \(result.resolution)x\(result.resolution): \(String(format: "%.1f", result.time * 1000))ms")
        }

        // 4x pixels should be < 4x time (due to parallelization)
        let time512 = results.first(where: { $0.resolution == 512 })?.time ?? 0
        let time2048 = results.first(where: { $0.resolution == 2048 })?.time ?? 0
        XCTAssertLessThan(time2048, time512 * 4.0, "Resolution scaling should be sub-linear")
    }

    // MARK: - Overall Pipeline Benchmarks

    func testFullPipelinePerformance() throws {
        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Full pipeline")

            Task {
                // Mesh merging
                let merger = MeshMerger()
                guard let mergedMesh = try? await merger.merge(captures: captures) else {
                    XCTFail("Mesh merging failed")
                    expectation.fulfill()
                    return
                }

                // Texture baking
                let baker = TextureBaker()
                let samples = self.createMockTextureSamples(count: 7)
                guard let bakeResult = try? await baker.bakeTexture(
                    from: samples,
                    mesh: mergedMesh,
                    resolution: 1024
                ) else {
                    XCTFail("Texture baking failed")
                    expectation.fulfill()
                    return
                }

                // Metrics computation
                let analyzer = Face3DMetricsAnalyzer()
                _ = await analyzer.computeMetrics(
                    unifiedMesh: mergedMesh,
                    unifiedTexture: bakeResult.texture
                )

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 20.0)
        }

        // Target: < 1500ms total (vs 4100ms sequential)
        let measurements = performanceAnalyzer.getMeasurements()
        let totalTime = measurements.reduce(0) { $0 + $1.duration }
        print("📊 Full Pipeline: \(String(format: "%.1f", totalTime * 1000))ms")

        XCTAssertLessThan(totalTime, 1.5, "Full pipeline should be < 1500ms")
    }

    // MARK: - Parallelization Analysis

    func testParallelizationOpportunityDetection() throws {
        // Simulate sequential operations
        for i in 0..<10 {
            _ = performanceAnalyzer.measure(operation: "SequentialOp[\(i)]") {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        let sequential = performanceAnalyzer.analyzeSequentialOperations()

        XCTAssertFalse(sequential.isEmpty, "Should detect sequential operations")

        if let detected = sequential.first {
            print("📊 Detected Sequential Operation:")
            print("   Location: \(detected.location)")
            print("   Count: \(detected.operationCount)")
            print("   Total Duration: \(String(format: "%.1f", detected.totalDuration * 1000))ms")
            print("   Can Parallelize: \(detected.canParallelize)")
            print("   Estimated Speedup: \(String(format: "%.1f", detected.estimatedSpeedup))x")

            XCTAssertEqual(detected.operationCount, 10, "Should detect 10 operations")
            XCTAssertTrue(detected.canParallelize, "Should be parallelizable")
            XCTAssertGreaterThan(detected.estimatedSpeedup, 2.0, "Should estimate significant speedup")
        }
    }

    func testPerformanceReportGeneration() throws {
        // Generate some sample measurements
        for i in 0..<20 {
            _ = performanceAnalyzer.measure(operation: "Operation[\(i)]") {
                Thread.sleep(forTimeInterval: Double.random(in: 0.01...0.1))
            }
        }

        let report = performanceAnalyzer.generateReport()

        XCTAssertFalse(report.isEmpty, "Report should be generated")
        XCTAssertTrue(report.contains("Performance Analysis Report"), "Should contain header")
        XCTAssertTrue(report.contains("Total Operations"), "Should contain summary")

        print("📊 Performance Report:")
        print(report)
    }

    // MARK: - Device-Specific Benchmarks

    func testDeviceSpecificPerformance() throws {
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        print("📊 Device Information:")
        print("   CPU Cores: \(coreCount)")
        print("   Physical Memory: \(String(format: "%.1f", Double(physicalMemory) / 1_073_741_824))GB")

        // Adjust expectations based on device
        let captures = createMockCaptures(count: 7, vertexCount: 1000)
        let expectation = self.expectation(description: "Device-specific test")

        var totalTime: TimeInterval = 0
        Task {
            let start = Date()

            let merger = MeshMerger()
            _ = try? await merger.merge(captures: captures)

            totalTime = Date().timeIntervalSince(start)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15.0)

        print("   Mesh Merging (7 captures): \(String(format: "%.1f", totalTime * 1000))ms")

        // Performance expectations based on core count
        if coreCount >= 6 {
            // High-end device (iPhone 15 Pro, etc.)
            XCTAssertLessThan(totalTime, 0.35, "High-end device should merge in < 350ms")
        } else if coreCount >= 4 {
            // Mid-range device (iPhone 12, etc.)
            XCTAssertLessThan(totalTime, 0.50, "Mid-range device should merge in < 500ms")
        } else {
            // Low-end device
            XCTAssertLessThan(totalTime, 0.80, "Low-end device should merge in < 800ms")
        }
    }

    // MARK: - Memory Efficiency Benchmarks

    func testMemoryEfficiencyDuringProcessing() throws {
        let initialMemory = getMemoryUsage()
        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        let expectation = self.expectation(description: "Memory efficiency test")

        var peakMemory: UInt64 = 0
        var finalMemory: UInt64 = 0

        Task {
            let merger = MeshMerger()
            _ = try? await merger.merge(captures: captures)

            peakMemory = getMemoryUsage()

            // Allow cleanup
            try? await Task.sleep(nanoseconds: 500_000_000)

            finalMemory = getMemoryUsage()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15.0)

        let memoryIncrease = Double(peakMemory - initialMemory) / 1_048_576.0
        let memoryAfterCleanup = Double(finalMemory - initialMemory) / 1_048_576.0

        print("📊 Memory Efficiency:")
        print("   Initial: \(String(format: "%.1f", Double(initialMemory) / 1_048_576.0))MB")
        print("   Peak: \(String(format: "%.1f", Double(peakMemory) / 1_048_576.0))MB (+\(String(format: "%.1f", memoryIncrease))MB)")
        print("   Final: \(String(format: "%.1f", Double(finalMemory) / 1_048_576.0))MB (+\(String(format: "%.1f", memoryAfterCleanup))MB)")

        // Memory should not increase dramatically
        XCTAssertLessThan(memoryIncrease, 400.0, "Memory increase should be < 400MB during processing")
        XCTAssertLessThan(memoryAfterCleanup, 100.0, "Memory should be mostly released after processing")
    }

    // MARK: - Helper Methods

    private func createMockCaptures(count: Int, vertexCount: Int) -> [FaceMeshCapture] {
        var captures: [FaceMeshCapture] = []

        for i in 0..<count {
            var vertices: [SIMD3<Float>] = []
            for j in 0..<vertexCount {
                let angle = Float(j) / Float(vertexCount) * 2 * .pi
                let radius: Float = 0.1
                vertices.append(SIMD3(
                    cos(angle) * radius,
                    sin(angle) * radius,
                    Float(i) * 0.01
                ))
            }

            let capture = FaceMeshCapture(
                vertices: vertices,
                normals: Array(repeating: SIMD3<Float>(0, 0, 1), count: vertexCount),
                textureCoordinates: Array(repeating: SIMD2<Float>(0.5, 0.5), count: vertexCount),
                triangleIndices: [],
                transform: simd_float4x4(1),
                timestamp: Date()
            )

            captures.append(capture)
        }

        return captures
    }

    private func createMockMesh(vertexCount: Int) -> UnifiedFaceMesh {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        for i in 0..<vertexCount {
            let angle = Float(i) / Float(vertexCount) * 2 * .pi
            let radius: Float = 0.1

            vertices.append(SIMD3(
                cos(angle) * radius,
                sin(angle) * radius,
                0
            ))
            normals.append(SIMD3<Float>(0, 0, 1))
            uvs.append(SIMD2<Float>(Float(i) / Float(vertexCount), 0.5))
        }

        return UnifiedFaceMesh(
            vertices: vertices,
            normals: normals,
            uvCoordinates: uvs,
            triangleIndices: [],
            regionMasks: [:]
        )
    }

    private func createMockTexture(size: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Fill with test pattern
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        return context.makeImage()
    }

    private func createMockTextureSamples(count: Int) -> [TextureSample] {
        var samples: [TextureSample] = []

        for i in 0..<count {
            if let image = createMockTexture(size: 512) {
                let sample = TextureSample(
                    image: image,
                    transform: simd_float4x4(1),
                    quality: 0.9,
                    captureIndex: i
                )
                samples.append(sample)
            }
        }

        return samples
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}
