import SwiftUI
import MapKit

// A properly organized photo-info panel — everything a curious user would actually
// want to know about one selfie, grouped into clear sections, without drowning them
// in raw EXIF noise. Falls back gracefully section by section when a given piece of
// data isn't available (e.g. no location permission, or a legacy photo with no
// PhotoMetadata at all).
struct PhotoInfoSheet: View {
    let image: UIImage
    let metadata: PhotoMetadata?
    var onReplace: ((UIImage, PhotoMetadata) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Guarantees the sheet always has *something* to show, even for a photo that
    // somehow arrived with no captured metadata.
    private var resolvedMetadata: PhotoMetadata {
        metadata ?? PhotoMetadata(
            captureDate: Date(),
            location: nil,
            locationLabel: nil,
            pixelWidth: image.cgImage?.width ?? Int(image.size.width),
            pixelHeight: image.cgImage?.height ?? Int(image.size.height),
            fileSizeBytes: image.jpegData(compressionQuality: 0.95)?.count ?? 0,
            iso: nil,
            exposureDurationSeconds: nil,
            apertureFNumber: nil,
            focalLength35mm: nil,
            flashFired: false,
            cameraPosition: "Front Camera",
            filterUsed: .none,
            aspectRatioUsed: .full,
            lightingModeUsed: .natural,
            quality: nil
        )
    }

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                if let quality = resolvedMetadata.quality {
                    aiAnalysisSection(quality)
                }
                cameraSection
                fileSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Photo Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Overview (date + location)

    @ViewBuilder private var overviewSection: some View {
        let m = resolvedMetadata
        Section {
            infoRow(label: "Date", value: m.captureDate.formatted(date: .abbreviated, time: .shortened))

            if let location = m.location {
                if let label = m.locationLabel {
                    infoRow(label: "Location", value: label)
                } else {
                    infoRow(label: "Location", value: "Locating…")
                }

                Map(initialPosition: .region(
                    MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                )) {
                    Marker("", coordinate: location.coordinate)
                }
                .frame(height: 140)
                .listRowInsets(EdgeInsets())
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - AI Analysis (our own differentiator — nobody else's Info panel has this)

    @ViewBuilder private func aiAnalysisSection(_ quality: CaptureQuality) -> some View {
        let m = resolvedMetadata
        Section("AI Analysis") {
            infoRow(label: "Overall Score", value: "\(quality.overallScore)/100")
            infoRow(label: "Framing", value: "\(quality.framingScore)/100")
            infoRow(label: "Lighting", value: "\(quality.lightingScore)/100")
            infoRow(label: "Sharpness", value: "\(quality.sharpnessScore)/100")
            infoRow(label: "Eyes", value: "\(quality.eyesScore)/100")
            infoRow(label: "Filter", value: m.filterUsed.displayName)
            infoRow(label: "Aspect Ratio", value: m.aspectRatioUsed.displayName)
            infoRow(label: "Lighting Mode", value: m.lightingModeUsed.displayName)
        }
    }

    // MARK: - Camera settings

    @ViewBuilder private var cameraSection: some View {
        let m = resolvedMetadata
        Section("Camera") {
            infoRow(label: "Camera", value: m.cameraPosition)
            if let iso = m.iso {
                infoRow(label: "ISO", value: "\(Int(iso))")
            }
            if let exposure = m.exposureDurationSeconds {
                infoRow(label: "Shutter Speed", value: formatShutterSpeed(exposure))
            }
            if let aperture = m.apertureFNumber {
                infoRow(label: "Aperture", value: String(format: "f/%.1f", aperture))
            }
            if let focal = m.focalLength35mm {
                infoRow(label: "Focal Length", value: "\(Int(focal))mm equiv.")
            }
            infoRow(label: "Flash", value: m.flashFired ? "On" : "Off")
        }
    }

    // MARK: - File

    @ViewBuilder private var fileSection: some View {
        let m = resolvedMetadata
        Section("File") {
            infoRow(label: "Dimensions", value: "\(m.pixelWidth) × \(m.pixelHeight)")
            infoRow(label: "File Size", value: formatFileSize(m.fileSizeBytes))
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private func formatShutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        }
        let denominator = Int((1.0 / seconds).rounded())
        return "1/\(denominator)s"
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
