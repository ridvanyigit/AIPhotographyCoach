import CoreImage
import CoreGraphics

// MARK: - Ambient Light Reading
// A coarse but cheap read of how light is falling on the face: is it even
// (left/right, top/bottom balanced), how bright, and how harsh (contrast). This is
// what lets the app coach where to actually position a light source, rather than
// just complaining "too dark".
struct LightingAnalysis {
    let horizontalBias: Double // -1 (light from the left) ... +1 (light from the right)
    let verticalBias: Double   // -1 (light from below) ... +1 (light from directly above)
    let contrast: Double       // 0 (flat/soft light) ... 1 (harsh, high-contrast shadows)
    let brightness: Double     // 0 (black) ... 1 (blown out), sampled from the face itself
}

// Samples luminance directly from the live camera frame within the detected face's
// bounding box, using Core Image so the sampling coordinate space always matches
// exactly what Vision used for face detection (both use bottom-left-origin
// normalized coordinates, so no manual axis flipping is needed).
enum LightingAnalyzer {

    // Face region is downsampled to a tiny grid before reading pixels back, so this
    // stays cheap enough to run several times a second without affecting frame rate.
    private static let gridSize = 8

    static func analyze(ciImage: CIImage, faceBoundingBox: CGRect, context: CIContext) -> LightingAnalysis? {
        let extent = ciImage.extent
        guard extent.width > 1, extent.height > 1 else { return nil }

        let faceRect = CGRect(
            x: extent.origin.x + faceBoundingBox.minX * extent.width,
            y: extent.origin.y + faceBoundingBox.minY * extent.height,
            width: faceBoundingBox.width * extent.width,
            height: faceBoundingBox.height * extent.height
        ).intersection(extent)

        guard faceRect.width > 4, faceRect.height > 4 else { return nil }

        let cropped = ciImage.cropped(to: faceRect)
        let scaleX = CGFloat(gridSize) / faceRect.width
        let scaleY = CGFloat(gridSize) / faceRect.height
        let scaled = cropped
            .transformed(by: CGAffineTransform(translationX: -faceRect.origin.x, y: -faceRect.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var pixels = [UInt8](repeating: 0, count: gridSize * gridSize * 4)
        let renderRect = CGRect(x: 0, y: 0, width: gridSize, height: gridSize)

        let rendered: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            context.render(
                scaled,
                toBitmap: baseAddress,
                rowBytes: gridSize * 4,
                bounds: renderRect,
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            return true
        }
        guard rendered else { return nil }

        var luminances = [Double](repeating: 0, count: gridSize * gridSize)
        for i in 0..<(gridSize * gridSize) {
            let r = Double(pixels[i * 4])
            let g = Double(pixels[i * 4 + 1])
            let b = Double(pixels[i * 4 + 2])
            luminances[i] = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        }

        let avgBrightness = luminances.reduce(0, +) / Double(luminances.count)

        // The rendered grid uses Core Image's bottom-left origin: row 0 is the
        // BOTTOM of the face, row (gridSize - 1) is the TOP.
        var leftSum = 0.0, rightSum = 0.0, topSum = 0.0, bottomSum = 0.0
        let half = gridSize / 2
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let value = luminances[row * gridSize + col]
                if col < half { leftSum += value } else { rightSum += value }
                if row < half { bottomSum += value } else { topSum += value }
            }
        }
        let cellsPerHalf = Double(gridSize * gridSize) / 2.0
        let leftAvg = leftSum / cellsPerHalf
        let rightAvg = rightSum / cellsPerHalf
        let topAvg = topSum / cellsPerHalf
        let bottomAvg = bottomSum / cellsPerHalf

        let horizontalBias = clamp((rightAvg - leftAvg) * 3.0, -1, 1)
        let verticalBias = clamp((topAvg - bottomAvg) * 3.0, -1, 1)

        let variance = luminances.reduce(0) { $0 + pow($1 - avgBrightness, 2) } / Double(luminances.count)
        let contrast = clamp(sqrt(variance) * 4.0, 0, 1)

        return LightingAnalysis(horizontalBias: horizontalBias, verticalBias: verticalBias, contrast: contrast, brightness: avgBrightness)
    }

    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(value, lo), hi)
    }
}
