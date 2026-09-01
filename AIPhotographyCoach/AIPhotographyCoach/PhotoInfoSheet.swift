import SwiftUI
import MapKit
import Photos

// A properly organized photo-info panel — everything a curious user would actually
// want to know about one selfie, grouped into clear sections, without drowning them
// in raw EXIF noise. Falls back gracefully section by section when a given piece of
// data isn't available (e.g. no location permission, or a legacy photo with no
// PhotoMetadata at all).
struct PhotoInfoSheet: View {
    let image: UIImage
    let metadata: PhotoMetadata?

    @Environment(\.dismiss) private var dismiss

    // File-size reduction state, kept local to the sheet since it's just a preview/
    // export tool and doesn't need to persist anywhere else.
    @State private var compressionQuality: Double = 0.7
    @State private var estimatedCompressedSize: Int = 0
    @State private var isSavingCompressed: Bool = false
    @State private var didSaveCompressed: Bool = false

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
            compressionRow(originalSize: m.fileSizeBytes)
        }
    }

    // Lets someone shrink the file straight from the info panel: drag to preview the
    // resulting size, then save it as a separate copy in Photos — the original is
    // never touched or overwritten.
    @ViewBuilder private func compressionRow(originalSize: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reduce File Size").foregroundStyle(.secondary)
                Spacer()
                Text(formatFileSize(estimatedCompressedSize))
                    .font(.subheadline.monospacedDigit())
                if let percent = reductionPercentText(original: originalSize) {
                    Text(percent)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green, in: Capsule())
                }
            }

            Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.05) { editing in
                if editing {
                    didSaveCompressed = false
                } else {
                    updateEstimatedSize()
                }
            }

            if reductionIsMeaningful(originalSize) {
                Button(action: saveCompressedCopy) {
                    HStack(spacing: 6) {
                        if isSavingCompressed {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: didSaveCompressed ? "checkmark.circle.fill" : "square.and.arrow.down")
                        }
                        Text(didSaveCompressed ? "Saved to Photos" : "Save Compressed Copy")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .disabled(isSavingCompressed || didSaveCompressed)
            }
        }
        .padding(.vertical, 4)
        .task { updateEstimatedSize() }
    }

    private func reductionIsMeaningful(_ originalSize: Int) -> Bool {
        originalSize > 0 && estimatedCompressedSize < Int(Double(originalSize) * 0.95)
    }

    private func reductionPercentText(original: Int) -> String? {
        guard reductionIsMeaningful(original) else { return nil }
        let percent = Int(((Double(original) - Double(estimatedCompressedSize)) / Double(original)) * 100)
        return "-\(percent)%"
    }

    private func updateEstimatedSize() {
        estimatedCompressedSize = image.jpegData(compressionQuality: compressionQuality)?.count ?? resolvedMetadata.fileSizeBytes
    }

    // Saved as a brand-new asset rather than replacing the original, so nobody can
    // accidentally lose their full-quality selfie by dragging a slider too far.
    private func saveCompressedCopy() {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return }
        isSavingCompressed = true
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(.photo, data: data, options: nil)
        }, completionHandler: { success, _ in
            DispatchQueue.main.async {
                isSavingCompressed = false
                didSaveCompressed = success
            }
        })
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
