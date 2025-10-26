//
//  FaceAlignmentExample.swift
//  Tavi
//
//  Example usage of FaceDetector for face alignment
//  Created on 2025-10-27.
//

import Foundation
import CoreVideo
import CoreGraphics
import UIKit

/// Example class demonstrating face detection and alignment
class FaceAlignmentExample {

    private let faceDetector = FaceDetector()

    // MARK: - Example 1: Basic Face Detection

    func example1_detectFaces(in pixelBuffer: CVPixelBuffer) async {
        do {
            // Detect faces in the frame
            let faces = try await faceDetector.detectFaces(
                in: pixelBuffer,
                orientation: .up
            )

            print("Detected \(faces.count) face(s)")

            for (index, face) in faces.enumerated() {
                print("\n--- Face \(index + 1) ---")
                print("Confidence: \(String(format: "%.2f%%", face.confidence * 100))")
                print("Bounding box: \(face.boundingBox)")

                // Print landmark counts
                print("Left eye points: \(face.landmarks.leftEye.count)")
                print("Right eye points: \(face.landmarks.rightEye.count)")
                print("Nose points: \(face.landmarks.nose.count)")
                print("Outer lips points: \(face.landmarks.outerLips.count)")

                // Print head pose if available
                if let roll = face.roll {
                    print("Roll: \(String(format: "%.1f°", roll * 180 / .pi))")
                }
                if let yaw = face.yaw {
                    print("Yaw: \(String(format: "%.1f°", yaw * 180 / .pi))")
                }
                if let pitch = face.pitch {
                    print("Pitch: \(String(format: "%.1f°", pitch * 180 / .pi))")
                }

                // Print eye metrics
                if let eyeAngle = face.landmarks.eyeAngle() {
                    print("Eye angle: \(String(format: "%.1f°", eyeAngle * 180 / .pi))")
                }
                if let eyeDistance = face.landmarks.eyeDistance() {
                    print("Eye distance: \(String(format: "%.2f", eyeDistance))")
                }
            }
        } catch {
            print("Face detection failed: \(error)")
        }
    }

    // MARK: - Example 2: Face Alignment

    func example2_alignFace(in pixelBuffer: CVPixelBuffer) async -> UIImage? {
        do {
            // 1. Detect faces
            let faces = try await faceDetector.detectFaces(in: pixelBuffer)

            guard let face = faces.first else {
                print("No face detected")
                return nil
            }

            // 2. Align the face
            guard let alignedFace = try faceDetector.alignedFace(
                from: pixelBuffer,
                faceResult: face,
                targetSize: CGSize(width: 512, height: 512)
            ) else {
                print("Face alignment failed")
                return nil
            }

            print("Face aligned successfully")
            print("Rotation applied: \(String(format: "%.1f°", alignedFace.rotationAngle * 180 / .pi))")
            print("Scale factor: \(String(format: "%.2f", alignedFace.scaleFactor))")

            // 3. Convert to UIImage
            return UIImage(cgImage: alignedFace.image)

        } catch {
            print("Face alignment error: \(error)")
            return nil
        }
    }

    // MARK: - Example 3: Batch Face Alignment

    func example3_alignAllFaces(in pixelBuffer: CVPixelBuffer) async -> [UIImage] {
        do {
            // Detect all faces
            let faces = try await faceDetector.detectFaces(in: pixelBuffer)

            print("Found \(faces.count) faces, aligning...")

            var alignedImages: [UIImage] = []

            for (index, face) in faces.enumerated() {
                if let alignedFace = try? faceDetector.alignedFace(
                    from: pixelBuffer,
                    faceResult: face,
                    targetSize: CGSize(width: 512, height: 512)
                ) {
                    let image = UIImage(cgImage: alignedFace.image)
                    alignedImages.append(image)
                    print("Aligned face \(index + 1)")
                } else {
                    print("Failed to align face \(index + 1)")
                }
            }

            return alignedImages

        } catch {
            print("Batch alignment error: \(error)")
            return []
        }
    }

    // MARK: - Example 4: Check Face Quality

    func example4_checkFaceQuality(in pixelBuffer: CVPixelBuffer) async -> Bool {
        do {
            let faces = try await faceDetector.detectFaces(in: pixelBuffer)

            guard let face = faces.first else {
                print("No face detected")
                return false
            }

            // Check confidence
            guard face.confidence > 0.8 else {
                print("Low confidence: \(face.confidence)")
                return false
            }

            // Check if face has pupils (better quality)
            guard face.landmarks.leftPupil != nil,
                  face.landmarks.rightPupil != nil else {
                print("Pupils not detected")
                return false
            }

            // Check eye angle (should be relatively level)
            if let eyeAngle = face.landmarks.eyeAngle() {
                let degrees = abs(eyeAngle * 180 / .pi)
                guard degrees < 15 else {
                    print("Face too rotated: \(String(format: "%.1f°", degrees))")
                    return false
                }
            }

            // Check bounding box size (face should be large enough)
            let minSize: CGFloat = 0.2 // At least 20% of frame
            guard face.boundingBox.width > minSize && face.boundingBox.height > minSize else {
                print("Face too small: \(face.boundingBox.size)")
                return false
            }

            print("Face quality check passed ✓")
            return true

        } catch {
            print("Quality check error: \(error)")
            return false
        }
    }

    // MARK: - Example 5: Custom Landmark Processing

    func example5_processLandmarks(_ face: FaceDetectionResult) {
        let landmarks = face.landmarks

        // Calculate eye region statistics
        let leftEyeCenter = averagePoint(landmarks.leftEye)
        let rightEyeCenter = averagePoint(landmarks.rightEye)

        print("Left eye center: \(leftEyeCenter)")
        print("Right eye center: \(rightEyeCenter)")

        // Calculate nose tip (first point of nose crest)
        if let noseTip = landmarks.noseCrest.first {
            print("Nose tip: \(noseTip)")
        }

        // Calculate mouth dimensions
        let mouthWidth = boundingWidth(landmarks.outerLips)
        let mouthHeight = boundingHeight(landmarks.outerLips)
        print("Mouth dimensions: \(mouthWidth) x \(mouthHeight)")

        // Check if mouth is open
        let innerHeight = boundingHeight(landmarks.innerLips)
        let isOpen = innerHeight > 0.01 // Threshold for open mouth
        print("Mouth open: \(isOpen)")

        // Face contour length
        let contourLength = pathLength(landmarks.faceContour)
        print("Face contour length: \(contourLength)")
    }

    // MARK: - Example 6: Save Aligned Face

    func example6_saveAlignedFace(in pixelBuffer: CVPixelBuffer, to url: URL) async -> Bool {
        do {
            let faces = try await faceDetector.detectFaces(in: pixelBuffer)

            guard let face = faces.first,
                  let alignedFace = try faceDetector.alignedFace(
                      from: pixelBuffer,
                      faceResult: face,
                      targetSize: CGSize(width: 1024, height: 1024) // High resolution
                  ) else {
                return false
            }

            // Convert to UIImage
            let image = UIImage(cgImage: alignedFace.image)

            // Save as PNG
            guard let pngData = image.pngData() else {
                return false
            }

            try pngData.write(to: url)
            print("Saved aligned face to: \(url.path)")
            return true

        } catch {
            print("Save error: \(error)")
            return false
        }
    }

    // MARK: - Helper Methods

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func boundingWidth(_ points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        let xs = points.map { $0.x }
        return (xs.max() ?? 0) - (xs.min() ?? 0)
    }

    private func boundingHeight(_ points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        let ys = points.map { $0.y }
        return (ys.max() ?? 0) - (ys.min() ?? 0)
    }

    private func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }

        var length: CGFloat = 0
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            length += sqrt(dx * dx + dy * dy)
        }
        return length
    }
}

// MARK: - Usage in View Model

/*
 // In CameraViewModel
 private let faceAlignmentExample = FaceAlignmentExample()

 func processFace(in pixelBuffer: CVPixelBuffer) async {
     // Example 1: Detect faces
     await faceAlignmentExample.example1_detectFaces(in: pixelBuffer)

     // Example 2: Get aligned face image
     if let alignedImage = await faceAlignmentExample.example2_alignFace(in: pixelBuffer) {
         // Use aligned image
         print("Got aligned face: \(alignedImage.size)")
     }

     // Example 3: Align all faces
     let allAlignedFaces = await faceAlignmentExample.example3_alignAllFaces(in: pixelBuffer)
     print("Aligned \(allAlignedFaces.count) faces")

     // Example 4: Check quality
     let isGoodQuality = await faceAlignmentExample.example4_checkFaceQuality(in: pixelBuffer)
     print("Face quality: \(isGoodQuality ? "Good" : "Poor")")
 }
 */
