import Foundation
import CoreLocation
import ImageIO
import UIKit
import AVFoundation

// Everything worth knowing about one captured selfie, gathered from three places:
// the raw EXIF/TIFF metadata AVFoundation hands back at capture time, the device's
// location (if permission was granted), and our own AI analysis (CaptureQuality)
// computed the instant the shutter fired.
struct PhotoMetadata {
    let captureDate: Date
    let location: CLLocation?
    var locationLabel: String?      // filled in asynchronously via reverse geocoding

    var pixelWidth: Int
    var pixelHeight: Int
    var fileSizeBytes: Int

    // The Photos-library identifier for this exact asset, captured right after the
    // initial save completes. Lets the info panel's "reduce file size" tool replace
    // this specific photo in place later, instead of just leaving a duplicate behind.
    var assetLocalIdentifier: String? = nil

    let iso: Double?
    let exposureDurationSeconds: Double?
    let apertureFNumber: Double?
    let focalLength35mm: Double?
    let flashFired: Bool
    let cameraPosition: String

    let filterUsed: SelfieFilter
    let aspectRatioUsed: SelfieAspectRatio
    let lightingModeUsed: SelfieLightingMode
    let quality: CaptureQuality?

    static func build(
        image: UIImage,
        rawMetadata: [String: Any],
        fileSizeBytes: Int,
        location: CLLocation?,
        cameraPosition: AVCaptureDevice.Position,
        filter: SelfieFilter,
        aspect: SelfieAspectRatio,
        lightingMode: SelfieLightingMode,
        quality: CaptureQuality?
    ) -> PhotoMetadata {
        let exif = rawMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = rawMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        let iso = (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Any])?
            .compactMap { $0 as? Double }
            .first
        let exposure = exif?[kCGImagePropertyExifExposureTime as String] as? Double
        let aperture = exif?[kCGImagePropertyExifFNumber as String] as? Double
        let focal35 = exif?[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double
        let flashRaw = exif?[kCGImagePropertyExifFlash as String] as? Int
        let flashFired = ((flashRaw ?? 0) & 0x1) != 0

        let dateString = (exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime as String] as? String)
        let date = parseExifDate(dateString) ?? Date()

        let pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)

        return PhotoMetadata(
            captureDate: date,
            location: location,
            locationLabel: nil,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeBytes: fileSizeBytes,
            iso: iso,
            exposureDurationSeconds: exposure,
            apertureFNumber: aperture,
            focalLength35mm: focal35,
            flashFired: flashFired,
            cameraPosition: cameraPosition == .front ? "Front Camera" : "Back Camera",
            filterUsed: filter,
            aspectRatioUsed: aspect,
            lightingModeUsed: lightingMode,
            quality: quality
        )
    }

    private static func parseExifDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: string)
    }
}
