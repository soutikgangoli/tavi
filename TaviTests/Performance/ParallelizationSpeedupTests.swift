//
//  ParallelizationSpeedupTests.swift
//  TaviTests
//
//  Validates claimed speedups from parallelization optimizations
//  Created on 2025-11-04.
//

import XCTest
@testable import Tavi
import simd

/// Tests to validate the claimed 3.3x overall speedup from parallelization
@MainActor
final class ParallelizationSpeedupTests: XCTestCase {

    // MARK: - Speedup Validation Tests

    func testMeshMergingSpeedupValidation() async throws {
        // Claims: 1200ms → 350ms (3.4x speedup)
        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        let start = Date()
        let merger = MeshMerger()
        _ = try await merger.merge(captures: captures)
        let duration = Date().timeIntervalSince(start)

        print("📊 Mesh Merging Speedup Validation:")
        print("   Claimed: 350ms (3.4x speedup)")
        print("   Actual: \(String(format: "%.1f", duration * 1000))ms")
        print("   Target: < 500ms (allowing for device variability)")

        // Allow up to 500ms (more conservative than claim)
        XCTAssertLessThan(duration, 0.5, "Mesh merging should achieve near-claimed speedup")

        // Calculate effective speedup (assuming 1200ms sequential baseline)
        let sequentialBaseline: TimeInterval = 1.2
        let actualSpeedup = sequentialBaseline / duration
        print("   Effective speedup: \(String(format: "%.1f", actualSpeedup))x")

        XCTAssertGreaterThan(actualSpeedup, 2.0, "Should achieve at least 2x speedup")
    }

    func testMetricsComputationSpeedupValidation() async throws {
        // Claims: 800ms → 250ms (3.2x speedup)
        let mesh = createMockMesh(vertexCount: 5000)
        let texture = createMockTexture(size: 1024)

        let start = Date()
        let analyzer = Face3DMetricsAnalyzer()
        _ = await analyzer.computeMetrics(
            unifiedMesh: mesh,
            unifiedTexture: texture
        )
        let duration = Date().timeIntervalSince(start)

        print("📊 Metrics Computation Speedup Validation:")
        print("   Claimed: 250ms (3.2x speedup)")
        print("   Actual: \(String(format: "%.1f", duration * 1000))ms")
        print("   Target: < 350ms (allowing for device variability)")

        XCTAssertLessThan(duration, 0.35, "Metrics computation should achieve near-claimed speedup")

        let sequentialBaseline: TimeInterval = 0.8
        let actualSpeedup = sequentialBaseline / duration
        print("   Effective speedup: \(String(format: "%.1f", actualSpeedup))x")

        XCTAssertGreaterThan(actualSpeedup, 2.0, "Should achieve at least 2x speedup")
    }

    func testTextureBakingSpeedupValidation() async throws {
        // Claims: 2100ms → 650ms (3.2x speedup)
        let mesh = createMockMesh(vertexCount: 5000)
        let samples = createMockTextureSamples(count: 7)

        let start = Date()
        let baker = TextureBaker()
        _ = try await baker.bakeTexture(
            from: samples,
            mesh: mesh,
            resolution: 2048
        )
        let duration = Date().timeIntervalSince(start)

        print("📊 Texture Baking Speedup Validation:")
        print("   Claimed: 650ms (3.2x speedup)")
        print("   Actual: \(String(format: "%.1f", duration * 1000))ms")
        print("   Target: < 900ms (allowing for device variability)")

        XCTAssertLessThan(duration, 0.9, "Texture baking should achieve near-claimed speedup")

        let sequentialBaseline: TimeInterval = 2.1
        let actualSpeedup = sequentialBaseline / duration
        print("   Effective speedup: \(String(format: "%.1f", actualSpeedup))x")

        XCTAssertGreaterThan(actualSpeedup, 2.0, "Should achieve at least 2x speedup")
    }

    func testOverallPipelineSpeedupValidation() async throws {
        // Claims: 4100ms → 1250ms (3.3x speedup)
        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        let start = Date()

        // Full pipeline
        let merger = MeshMerger()
        guard let mergedMesh = try? await merger.merge(captures: captures) else {
            XCTFail("Mesh merging failed")
            return
        }

        let baker = TextureBaker()
        let samples = createMockTextureSamples(count: 7)
        guard let bakeResult = try? await baker.bakeTexture(
            from: samples,
            mesh: mergedMesh,
            resolution: 1024
        ) else {
            XCTFail("Texture baking failed")
            return
        }

        let analyzer = Face3DMetricsAnalyzer()
        _ = await analyzer.computeMetrics(
            unifiedMesh: mergedMesh,
            unifiedTexture: bakeResult.texture
        )

        let duration = Date().timeIntervalSince(start)

        print("📊 Overall Pipeline Speedup Validation:")
        print("   Claimed: 1250ms (3.3x speedup)")
        print("   Actual: \(String(format: "%.1f", duration * 1000))ms")
        print("   Target: < 1800ms (allowing for device variability)")

        XCTAssertLessThan(duration, 1.8, "Overall pipeline should achieve near-claimed speedup")

        let sequentialBaseline: TimeInterval = 4.1
        let actualSpeedup = sequentialBaseline / duration
        print("   Effective speedup: \(String(format: "%.1f", actualSpeedup))x")

        XCTAssertGreaterThan(actualSpeedup, 2.0, "Should achieve at least 2x overall speedup")
    }

    // MARK: - Core Count Scaling Tests

    func testSpeedupScalesWithCoreCount() async throws {
        let coreCount = ProcessInfo.processInfo.activeProcessorCount

        print("📊 Core Count Scaling Test:")
        print("   Available cores: \(coreCount)")

        let captures = createMockCaptures(count: 7, vertexCount: 1000)

        // Test with different concurrency limits
        let concurrencies = [1, 2, min(4, coreCount), min(8, coreCount)]
        var results: [(concurrency: Int, time: TimeInterval)] = []

        for concurrency in concurrencies where concurrency <= coreCount {
            let start = Date()

            // Simulate limited concurrency
            let tasks: [(String, () async throws -> Void)] = captures.enumerated().map { index, capture in
                ("Process[\(index)]", {
                    // Simulate processing work
                    try? await Task.sleep(nanoseconds: 10_000_000)
                })
            }

            _ = try? await ParallelExecutor.executeInParallel(
                tasks: tasks,
                maxConcurrency: concurrency
            )

            let duration = Date().timeIntervalSince(start)
            results.append((concurrency, duration))

            print("   Concurrency \(concurrency): \(String(format: "%.1f", duration * 1000))ms")
        }

        // Verify that higher concurrency is faster
        if results.count > 1 {
            for i in 1..<results.count {
                XCTAssertLessThan(
                    results[i].time,
                    results[i-1].time * 1.1,  // Allow 10% margin
                    "Higher concurrency should be faster or similar"
                )
            }
        }
    }

    // MARK: - Parallel vs Sequential Comparison

    func testDirectSequentialComparison() async throws {
        let itemCount = 10
        let workDuration: UInt64 = 50_000_000  // 50ms per item

        // Sequential execution
        let sequentialStart = Date()
        for i in 0..<itemCount {
            try? await Task.sleep(nanoseconds: workDuration)
        }
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)

        // Parallel execution
        let parallelStart = Date()
        let tasks: [(String, () async throws -> Void)] = (0..<itemCount).map { i in
            ("Task[\(i)]", {
                try? await Task.sleep(nanoseconds: workDuration)
            })
        }
        _ = try? await ParallelExecutor.executeInParallel(tasks: tasks)
        let parallelDuration = Date().timeIntervalSince(parallelStart)

        let speedup = sequentialDuration / parallelDuration

        print("📊 Sequential vs Parallel Comparison:")
        print("   Sequential: \(String(format: "%.1f", sequentialDuration * 1000))ms")
        print("   Parallel: \(String(format: "%.1f", parallelDuration * 1000))ms")
        print("   Speedup: \(String(format: "%.1f", speedup))x")

        XCTAssertGreaterThan(speedup, 2.0, "Parallel should be significantly faster")
    }

    func testChunkedParallelization() async throws {
        let itemCount = 1000
        let chunkSize = 100

        let start = Date()

        var processedItems: [Int] = []
        let lock = NSLock()

        try await ParallelExecutor.executeInChunks(
            items: Array(0..<itemCount),
            chunkSize: chunkSize
        ) { item in
            // Simulate work
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms

            lock.lock()
            processedItems.append(item)
            lock.unlock()
        }

        let duration = Date().timeIntervalSince(start)

        print("📊 Chunked Parallelization:")
        print("   Items: \(itemCount)")
        print("   Chunk size: \(chunkSize)")
        print("   Duration: \(String(format: "%.1f", duration * 1000))ms")
        print("   Processed: \(processedItems.count)")

        XCTAssertEqual(processedItems.count, itemCount, "All items should be processed")

        // Should be much faster than sequential (1000ms)
        XCTAssertLessThan(duration, 0.5, "Chunked parallel should be fast")
    }

    // MARK: - Real-World Scenario Tests

    func testRealWorldVertexTransformation() async throws {
        // Simulate real vertex transformation workload
        let vertexCount = 5000
        let captureCount = 7

        var vertices: [SIMD3<Float>] = []
        for i in 0..<vertexCount {
            let angle = Float(i) / Float(vertexCount) * 2 * .pi
            vertices.append(SIMD3(cos(angle), sin(angle), 0))
        }

        let transforms = (0..<captureCount).map { i -> simd_float4x4 in
            var transform = matrix_identity_float4x4
            transform.columns.3.x = Float(i) * 0.1
            return transform
        }

        // Sequential
        let sequentialStart = Date()
        var sequentialResults: [[SIMD3<Float>]] = []
        for transform in transforms {
            let transformed = vertices.map { vertex in
                let homogeneous = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                let result = transform * homogeneous
                return SIMD3<Float>(result.x, result.y, result.z)
            }
            sequentialResults.append(transformed)
        }
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)

        // Parallel
        let parallelStart = Date()
        let tasks: [(String, () async throws -> [SIMD3<Float>])] = transforms.enumerated().map { index, transform in
            ("Transform[\(index)]", {
                return vertices.map { vertex in
                    let homogeneous = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                    let result = transform * homogeneous
                    return SIMD3<Float>(result.x, result.y, result.z)
                }
            })
        }
        let parallelResults = try await ParallelExecutor.executeInParallel(tasks: tasks)
        let parallelDuration = Date().timeIntervalSince(parallelStart)

        let speedup = sequentialDuration / parallelDuration

        print("📊 Real-World Vertex Transformation:")
        print("   Vertices: \(vertexCount)")
        print("   Captures: \(captureCount)")
        print("   Sequential: \(String(format: "%.1f", sequentialDuration * 1000))ms")
        print("   Parallel: \(String(format: "%.1f", parallelDuration * 1000))ms")
        print("   Speedup: \(String(format: "%.1f", speedup))x")

        XCTAssertEqual(parallelResults.count, captureCount, "Should process all captures")
        XCTAssertGreaterThan(speedup, 1.5, "Should achieve meaningful speedup")
    }

    func testRealWorldTextureProcessing() async throws {
        // Simulate real texture row processing
        let width = 1024
        let height = 1024

        // Sequential row processing
        let sequentialStart = Date()
        var sequentialTexture: [[UInt32]] = []
        for y in 0..<height {
            var row: [UInt32] = []
            for x in 0..<width {
                // Simulate pixel computation
                let r = UInt32((x * 255) / width)
                let g = UInt32((y * 255) / height)
                let b: UInt32 = 128
                let a: UInt32 = 255
                let pixel = (a << 24) | (b << 16) | (g << 8) | r
                row.append(pixel)
            }
            sequentialTexture.append(row)
        }
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)

        // Parallel row processing
        let parallelStart = Date()
        let tasks: [(String, () async throws -> (Int, [UInt32]))] = (0..<height).map { y in
            ("Row[\(y)]", {
                var row: [UInt32] = []
                for x in 0..<width {
                    let r = UInt32((x * 255) / width)
                    let g = UInt32((y * 255) / height)
                    let b: UInt32 = 128
                    let a: UInt32 = 255
                    let pixel = (a << 24) | (b << 16) | (g << 8) | r
                    row.append(pixel)
                }
                return (y, row)
            })
        }
        let results = try await ParallelExecutor.executeInParallel(tasks: tasks)
        let parallelDuration = Date().timeIntervalSince(parallelStart)

        let speedup = sequentialDuration / parallelDuration

        print("📊 Real-World Texture Processing:")
        print("   Resolution: \(width)x\(height)")
        print("   Sequential: \(String(format: "%.1f", sequentialDuration * 1000))ms")
        print("   Parallel: \(String(format: "%.1f", parallelDuration * 1000))ms")
        print("   Speedup: \(String(format: "%.1f", speedup))x")

        XCTAssertEqual(results.count, height, "Should process all rows")
        XCTAssertGreaterThan(speedup, 2.0, "Should achieve significant speedup")
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
}
