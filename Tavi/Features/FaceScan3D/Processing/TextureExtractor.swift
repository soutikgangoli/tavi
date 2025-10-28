//
//  TextureExtractor.swift
//  Tavi
//
//  Extract high-resolution texture from ARKit captures
//  ARKit provides both 3D geometry AND high-res 2D camera texture
//

import ARKit
import UIKit
import AVFoundation

/// Extracted texture data
struct ExtractedTexture {
    let fullResolutionImage: UIImage
    let faceRegionImage: UIImage
    let textureCoordinates: [SIMD2<Float>]
    let resolution: CGSize
    let captureTimestamp: TimeInterval
}

/// High-resolution texture extractor from ARKit
class TextureExtractor {

    // MARK: - Public API

    /// Extract texture from AR frame and face geometry
    func extractTexture(
        from frame: ARFrame,
        faceAnchor: ARFaceAnchor,
        geometry: ARFaceGeometry
    ) -> ExtractedTexture? {

        // Get camera image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply display transform
        let displayTransform = frame.displayTransform(for: .portrait, viewportSize: ciImage.extent.size)
        let transformedImage = ciImage.transformed(by: displayTransform)

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        let fullResImage = UIImage(cgImage: cgImage)

        // Extract face region using bounding box
        let faceRegion = extractFaceRegion(
            image: transformedImage,
            faceAnchor: faceAnchor,
            frame: frame
        )

        let faceRegionUIImage: UIImage
        if let faceRegion = faceRegion,
           let faceRegionCG = context.createCGImage(faceRegion, from: faceRegion.extent) {
            faceRegionUIImage = UIImage(cgImage: faceRegionCG)
        } else {
            faceRegionUIImage = fullResImage
        }

        // Get texture coordinates
        let texCoords = Array(geometry.textureCoordinates)

        return ExtractedTexture(
            fullResolutionImage: fullResImage,
            faceRegionImage: faceRegionUIImage,
            textureCoordinates: texCoords,
            resolution: fullResImage.size,
            captureTimestamp: frame.timestamp
        )
    }

    /// Extract face region using 2D projection
    private func extractFaceRegion(
        image: CIImage,
        faceAnchor: ARFaceAnchor,
        frame: ARFrame
    ) -> CIImage? {

        // Calculate bounding box of face in 2D
        let geometry = faceAnchor.geometry
        let transform = faceAnchor.transform

        // Project vertices to 2D
        let camera = frame.camera
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity

        for vertex in geometry.vertices {
            // Transform to world space
            let worldPos = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
            let worldPos3 = SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z)

            // Project to screen space
            let screenPos = camera.projectPoint(
                worldPos3,
                orientation: .portrait,
                viewportSize: image.extent.size
            )

            minX = min(minX, screenPos.x)
            maxX = max(maxX, screenPos.x)
            minY = min(minY, screenPos.y)
            maxY = max(maxY, screenPos.y)
        }

        // Add padding (10%)
        let padding: CGFloat = 0.1
        let width = maxX - minX
        let height = maxY - minY
        let paddedMinX = minX - width * padding
        let paddedMaxX = maxX + width * padding
        let paddedMinY = minY - height * padding
        let paddedMaxY = maxY + height * padding

        // Crop image
        let cropRect = CGRect(
            x: paddedMinX,
            y: paddedMinY,
            width: paddedMaxX - paddedMinX,
            height: paddedMaxY - paddedMinY
        )

        // Ensure crop rect is within image bounds
        let clampedRect = cropRect.intersection(image.extent)
        guard !clampedRect.isEmpty else { return nil }

        return image.cropped(to: clampedRect)
    }

    /// Sample texture at UV coordinates
    func sampleTexture(
        image: UIImage,
        at uv: SIMD2<Float>
    ) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Convert UV (0-1) to pixel coordinates
        let x = Int(uv.x * Float(width))
        let y = Int(uv.y * Float(height))

        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        // Sample pixel
        let pixelData = cgImage.dataProvider?.data
        guard let data = pixelData else { return nil }
        let dataPtr = CFDataGetBytePtr(data)
        guard let ptr = dataPtr else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let pixelInfo = bytesPerRow * y + x * bytesPerPixel

        let r = CGFloat(ptr[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(ptr[pixelInfo + 1]) / CGFloat(255.0)
        let b = CGFloat(ptr[pixelInfo + 2]) / CGFloat(255.0)
        let a = CGFloat(ptr[pixelInfo + 3]) / CGFloat(255.0)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    /// Extract texture for specific ROI
    func extractROITexture(
        texture: ExtractedTexture,
        roiVertices: [Int],
        geometry: FaceMeshGeometry
    ) -> UIImage? {

        // Get bounding box of ROI in UV space
        var minU: Float = .infinity
        var maxU: Float = -.infinity
        var minV: Float = .infinity
        var maxV: Float = -.infinity

        for vertexIndex in roiVertices {
            let uv = texture.textureCoordinates[vertexIndex]
            minU = min(minU, uv.x)
            maxU = max(maxU, uv.x)
            minV = min(minV, uv.y)
            maxV = max(maxV, uv.y)
        }

        // Convert to pixel coordinates
        let width = texture.fullResolutionImage.size.width
        let height = texture.fullResolutionImage.size.height

        let cropRect = CGRect(
            x: CGFloat(minU) * CGFloat(width),
            y: CGFloat(minV) * CGFloat(height),
            width: CGFloat(maxU - minU) * CGFloat(width),
            height: CGFloat(maxV - minV) * CGFloat(height)
        )

        // Crop image
        guard let cgImage = texture.fullResolutionImage.cgImage,
              let croppedCG = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCG)
    }
}
