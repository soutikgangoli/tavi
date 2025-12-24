//
//  MetalLuminanceCoefficientsTest.swift
//  TaviTests
//
//  Guardrail: Prevent inline luminance coefficients outside AnalyzerCommon.metal
//  This test fails if anyone adds 0.299/0.587/0.114 or 0.2126/0.7152/0.0722 inline
//

import XCTest
@testable import Tavi

class MetalLuminanceCoefficientsTest: XCTestCase {

    /// Test that no Metal shader files contain inline luminance coefficients
    /// except for AnalyzerCommon.metal (which defines the helpers) and
    /// GlowAnalysis.metal (which uses XYZ matrix for Lab color space)
    func testNoInlineLuminanceCoefficients() throws {
        // Get Metal shader directory
        let metalDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tavi/Features/FaceScan3D/Metal")

        XCTAssertTrue(FileManager.default.fileExists(atPath: metalDir.path),
                     "Metal shader directory must exist: \(metalDir.path)")

        // Find all .metal files
        let metalFiles = try FileManager.default.contentsOfDirectory(at: metalDir,
                                                                      includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "metal" }

        XCTAssertFalse(metalFiles.isEmpty, "Must find at least one .metal file")

        // Regex patterns for inline luminance coefficients
        let legacyPattern = try NSRegularExpression(pattern: "0\\.299.*0\\.587.*0\\.114")
        let bt709Pattern = try NSRegularExpression(pattern: "0\\.2126.*0\\.7152.*0\\.0722")

        var violations: [String] = []

        for file in metalFiles {
            let fileName = file.lastPathComponent

            // AnalyzerCommon.metal is ALLOWED (defines the helpers)
            if fileName == "AnalyzerCommon.metal" {
                continue
            }

            // Read file content
            let content = try String(contentsOf: file, encoding: .utf8)

            // Remove single-line comments to avoid false positives
            let contentWithoutComments = content.components(separatedBy: "\n").map { line in
                if let commentIndex = line.range(of: "//") {
                    return String(line[..<commentIndex.lowerBound])
                }
                return line
            }.joined(separator: "\n")

            let nsContent = contentWithoutComments as NSString
            let range = NSRange(location: 0, length: nsContent.length)

            // Check for legacy coefficients (0.299, 0.587, 0.114)
            let legacyMatches = legacyPattern.matches(in: contentWithoutComments, range: range)
            if !legacyMatches.isEmpty {
                for match in legacyMatches {
                    let matchedText = nsContent.substring(with: match.range)
                    violations.append("\(fileName): Found legacy coefficients (0.299/0.587/0.114) → \"\(matchedText)\"")
                }
            }

            // Check for BT.709 coefficients (0.2126, 0.7152, 0.0722)
            let bt709Matches = bt709Pattern.matches(in: contentWithoutComments, range: range)
            if !bt709Matches.isEmpty {
                for match in bt709Matches {
                    let matchedText = nsContent.substring(with: match.range)

                    // EXEMPTION: GlowAnalysis.metal uses xyz.y = 0.2126729... for XYZ color space
                    // This is a matrix multiplication, not a luminance calculation
                    if fileName == "GlowAnalysis.metal" && matchedText.contains("xyz.y") {
                        continue  // Skip this legitimate use
                    }

                    violations.append("\(fileName): Found BT.709 coefficients (0.2126/0.7152/0.0722) → \"\(matchedText)\"")
                }
            }
        }

        // Assert no violations
        if !violations.isEmpty {
            let errorMessage = """

            ❌ LUMINANCE COEFFICIENT VIOLATION DETECTED

            Found inline luminance coefficients in Metal shader files.
            All luminance calculations MUST use shared helpers from AnalyzerCommon.metal:

            - Use perceptualLuminance(rgb) for BT.709 (0.2126, 0.7152, 0.0722)
            - Use legacyLuminance(rgb) for legacy (0.299, 0.587, 0.114)

            Violations found:
            \(violations.joined(separator: "\n"))

            WHY THIS MATTERS:
            Inline coefficients caused a critical bug in HydrationAnalysis.metal where
            BT.709 and legacy formulas were mixed in the same Laplacian calculation,
            causing false texture energy on smooth skin (5.2 millipoints for Indian
            skin tones, 3.5 millipoints for darker skin).

            FIX: Replace inline coefficients with helper function calls.
            """

            XCTFail(errorMessage)
        }
    }

    /// Verify that AnalyzerCommon.metal defines both helper functions
    func testAnalyzerCommonDefinesHelpers() throws {
        let commonFile = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tavi/Features/FaceScan3D/Metal/AnalyzerCommon.metal")

        XCTAssertTrue(FileManager.default.fileExists(atPath: commonFile.path),
                     "AnalyzerCommon.metal must exist")

        let content = try String(contentsOf: commonFile, encoding: .utf8)

        XCTAssertTrue(content.contains("inline float perceptualLuminance(float3 rgb)"),
                     "AnalyzerCommon.metal must define perceptualLuminance()")
        XCTAssertTrue(content.contains("inline float legacyLuminance(float3 rgb)"),
                     "AnalyzerCommon.metal must define legacyLuminance()")
        XCTAssertTrue(content.contains("0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b"),
                     "perceptualLuminance() must use BT.709 coefficients")
        XCTAssertTrue(content.contains("0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b"),
                     "legacyLuminance() must use legacy coefficients")
    }
}
