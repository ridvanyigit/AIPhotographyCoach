import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// Applies the selected creative filter and aspect-ratio crop to a freshly captured
// selfie before it's saved to the photo library. Kept separate from CameraManager so
// capture and post-processing stay independently testable.
enum SelfieImageProcessor {

    private static let context = CIContext()

    static func process(_ image: UIImage, filter: SelfieFilter, aspect: SelfieAspectRatio) -> UIImage {
        let normalized = normalizedOrientation(image)
        let filtered = applyFilter(filter, to: normalized)
        let cropped = applyAspect(aspect, to: filtered)
        return cropped
    }

    // Bakes the image's EXIF orientation into its pixel buffer so later Core Image
    // and CGImage cropping operate in the same coordinate space the user sees.
    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func applyFilter(_ filter: SelfieFilter, to image: UIImage) -> UIImage {
        guard filter != .none, let ciImage = CIImage(image: image) else { return image }

        var output = ciImage

        switch filter {
        case .none:
            return image

        case .vivid:
            let controls = CIFilter.colorControls()
            controls.inputImage = output
            controls.saturation = 1.4
            controls.contrast = 1.08
            output = controls.outputImage ?? output

        case .warm:
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 5800, y: 0)
            temperature.targetNeutral = CIVector(x: 4600, y: 0)
            output = temperature.outputImage ?? output

        case .cool:
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 5800, y: 0)
            temperature.targetNeutral = CIVector(x: 7200, y: 0)
            output = temperature.outputImage ?? output

        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = output
            output = mono.outputImage ?? output
        }

        guard let cgImage = context.createCGImage(output, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private static func applyAspect(_ aspect: SelfieAspectRatio, to image: UIImage) -> UIImage {
        guard let targetRatio = aspect.ratio, let cgImage = image.cgImage else { return image }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let currentRatio = width / height

        let cropRect: CGRect
        if currentRatio > targetRatio {
            // Source is wider than the target — trim the sides
            let newWidth = height * targetRatio
            let x = (width - newWidth) / 2.0
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: height)
        } else {
            // Source is taller than the target — trim top & bottom
            let newHeight = width / targetRatio
            let y = (height - newHeight) / 2.0
            cropRect = CGRect(x: 0, y: y, width: width, height: newHeight)
        }

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
    }
}
