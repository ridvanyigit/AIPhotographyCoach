import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Photo Filter Presets
// A curated set of photographic looks that goes beyond what iPhone's own Photos
// app offers in one place: the same 9 signature Photos looks (Vivid, Vivid Warm,
// Vivid Cool, Dramatic, Dramatic Warm, Dramatic Cool, Mono, Silvertone, Noir),
// Apple's own classic CIPhotoEffect presets that aren't in the current Photos
// filter picker (Chrome, Fade, Instant, Process, Transfer), and three original
// looks built specifically for flattering selfie skin tones and light (Golden
// Hour, Soft Glow, Cool Tone). Traditional color/tone grading only — background
// or generative work belongs in AI Edit, not here.
enum PhotoFilterPreset: String, CaseIterable, Identifiable {
    case original
    case vivid, vividWarm, vividCool
    case dramatic, dramaticWarm, dramaticCool
    case mono, silvertone, noir
    case chrome, fade, instant, process, transfer
    case goldenHour, softGlow, coolTone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .vivid: return "Vivid"
        case .vividWarm: return "Vivid Warm"
        case .vividCool: return "Vivid Cool"
        case .dramatic: return "Dramatic"
        case .dramaticWarm: return "Dramatic Warm"
        case .dramaticCool: return "Dramatic Cool"
        case .mono: return "Mono"
        case .silvertone: return "Silvertone"
        case .noir: return "Noir"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        case .instant: return "Instant"
        case .process: return "Process"
        case .transfer: return "Transfer"
        case .goldenHour: return "Golden Hour"
        case .softGlow: return "Soft Glow"
        case .coolTone: return "Cool Tone"
        }
    }

    func apply(to input: CIImage) -> CIImage {
        switch self {
        case .original:
            return input

        case .vivid:
            return Self.colorControls(input, saturation: 1.35, brightness: 0.02, contrast: 1.08)

        case .vividWarm:
            let v = Self.colorControls(input, saturation: 1.35, brightness: 0.02, contrast: 1.08)
            return Self.temperatureTint(v, targetTemp: 5000)

        case .vividCool:
            let v = Self.colorControls(input, saturation: 1.35, brightness: 0.02, contrast: 1.08)
            return Self.temperatureTint(v, targetTemp: 8000)

        case .dramatic:
            return Self.dramaticBase(input)

        case .dramaticWarm:
            return Self.temperatureTint(Self.dramaticBase(input), targetTemp: 5200)

        case .dramaticCool:
            return Self.temperatureTint(Self.dramaticBase(input), targetTemp: 7800)

        case .mono:
            let f = CIFilter.photoEffectMono(); f.inputImage = input; return f.outputImage ?? input
        case .silvertone:
            let f = CIFilter.photoEffectTonal(); f.inputImage = input; return f.outputImage ?? input
        case .noir:
            let f = CIFilter.photoEffectNoir(); f.inputImage = input; return f.outputImage ?? input
        case .chrome:
            let f = CIFilter.photoEffectChrome(); f.inputImage = input; return f.outputImage ?? input
        case .fade:
            let f = CIFilter.photoEffectFade(); f.inputImage = input; return f.outputImage ?? input
        case .instant:
            let f = CIFilter.photoEffectInstant(); f.inputImage = input; return f.outputImage ?? input
        case .process:
            let f = CIFilter.photoEffectProcess(); f.inputImage = input; return f.outputImage ?? input
        case .transfer:
            let f = CIFilter.photoEffectTransfer(); f.inputImage = input; return f.outputImage ?? input

        case .goldenHour:
            let warm = Self.temperatureTint(input, targetTemp: 4500)
            let lifted = Self.highlightShadow(warm, highlight: 1.0, shadow: 0.25)
            return Self.vignette(lifted, intensity: 0.15, radius: 1.8)

        case .softGlow:
            let flat = Self.colorControls(input, saturation: 1.05, brightness: 0.04, contrast: 0.92)
            return Self.bloom(flat, intensity: 0.35, radius: 6)

        case .coolTone:
            let cool = Self.temperatureTint(input, targetTemp: 8500)
            return Self.colorControls(cool, saturation: 1.05, brightness: 0, contrast: 1.1)
        }
    }

    // Deep shadows, punchy highlights, slightly desaturated — the moody, high
    // contrast base every "Dramatic" variant builds on.
    private static func dramaticBase(_ input: CIImage) -> CIImage {
        let hs = Self.highlightShadow(input, highlight: 0.85, shadow: 0.0)
        return Self.colorControls(hs, saturation: 0.92, brightness: -0.02, contrast: 1.25)
    }

    // MARK: - Shared CIFilter building blocks

    static func colorControls(_ input: CIImage, saturation: Double, brightness: Double, contrast: Double) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = input
        f.saturation = Float(saturation)
        f.brightness = Float(brightness)
        f.contrast = Float(contrast)
        return f.outputImage ?? input
    }

    static func temperatureTint(_ input: CIImage, targetTemp: Double, targetTint: Double = 0) -> CIImage {
        let f = CIFilter.temperatureAndTint()
        f.inputImage = input
        f.neutral = CIVector(x: 6500, y: 0)
        f.targetNeutral = CIVector(x: CGFloat(targetTemp), y: CGFloat(targetTint))
        return f.outputImage ?? input
    }

    static func highlightShadow(_ input: CIImage, highlight: Double, shadow: Double) -> CIImage {
        let f = CIFilter.highlightShadowAdjust()
        f.inputImage = input
        f.highlightAmount = Float(highlight)
        f.shadowAmount = Float(shadow)
        return f.outputImage ?? input
    }

    static func vignette(_ input: CIImage, intensity: Double, radius: Double) -> CIImage {
        let f = CIFilter.vignette()
        f.inputImage = input
        f.intensity = Float(intensity)
        f.radius = Float(radius)
        return f.outputImage ?? input
    }

    static func bloom(_ input: CIImage, intensity: Double, radius: Double) -> CIImage {
        let f = CIFilter.bloom()
        f.inputImage = input
        f.intensity = Float(intensity)
        f.radius = Float(radius)
        return f.outputImage ?? input
    }
}

// MARK: - Manual Adjustments
// The fine-grained controls every serious photo editor needs on top of a preset —
// modeled on the same fundamentals Photos' own Light/Color panel exposes.
// Adjustments always apply AFTER the chosen preset, so a preset gives a starting
// look and these fine-tune it.
struct PhotoAdjustments: Equatable {
    var preset: PhotoFilterPreset = .original
    var brightness: Double = 0        // -0.3 ... 0.3
    var contrast: Double = 1.0        // 0.7 ... 1.3
    var saturation: Double = 1.0      // 0 ... 2
    var warmth: Double = 6500         // 4000 ... 9000 (Kelvin)
    var highlights: Double = 1.0      // 0 ... 1
    var shadows: Double = 0.0         // 0 ... 1
    var sharpness: Double = 0.0       // 0 ... 1
    var vignette: Double = 0.0        // 0 ... 1

    static let defaults = PhotoAdjustments()

    var isDefault: Bool { self == .defaults }

    func apply(to input: CIImage) -> CIImage {
        var image = preset.apply(to: input)

        if brightness != 0 || contrast != 1.0 || saturation != 1.0 {
            image = PhotoFilterPreset.colorControls(image, saturation: saturation, brightness: brightness, contrast: contrast)
        }

        if warmth != 6500 {
            image = PhotoFilterPreset.temperatureTint(image, targetTemp: warmth)
        }

        if highlights != 1.0 || shadows != 0.0 {
            image = PhotoFilterPreset.highlightShadow(image, highlight: highlights, shadow: shadows)
        }

        if sharpness > 0 {
            let f = CIFilter.sharpenLuminance()
            f.inputImage = image
            f.sharpness = Float(sharpness * 1.8)
            image = f.outputImage ?? image
        }

        if vignette > 0 {
            image = PhotoFilterPreset.vignette(image, intensity: vignette, radius: 1.8)
        }

        return image
    }
}

// MARK: - Rendering
// Two tiers on purpose: a small, fast preview render for live slider feedback, and
// a full-resolution render used only once, when the edit is actually saved.
enum PhotoFilterRenderer {
    private static let context = CIContext()

    static func renderPreview(_ image: UIImage, adjustments: PhotoAdjustments, maxDimension: CGFloat = 900) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let scale = min(1.0, maxDimension / max(ciImage.extent.width, ciImage.extent.height))
        let scaled = scale < 1.0 ? ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : ciImage
        let output = adjustments.apply(to: scaled)
        guard let outputCGImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }

    static func renderFull(_ image: UIImage, adjustments: PhotoAdjustments) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let output = adjustments.apply(to: ciImage)
        guard let outputCGImage = context.createCGImage(output, from: ciImage.extent) else { return image }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
}
