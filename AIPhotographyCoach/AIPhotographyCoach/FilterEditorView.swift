import SwiftUI
import UIKit
import CoreImage

// The Filters editor: a horizontal picker of live-thumbnailed presets plus a
// professional Adjust panel (brightness, contrast, saturation, warmth,
// highlights/shadows, sharpness, vignette), all backed by PhotoFilterEngine.
// Renders a small, fast preview while editing and only does a full-resolution
// render once, when Save is tapped.
struct FilterEditorView: View {
    let originalImage: UIImage
    var onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var adjustments = PhotoAdjustments()
    @State private var previewImage: UIImage
    @State private var thumbnails: [PhotoFilterPreset: UIImage] = [:]
    @State private var activeTab: EditorTab = .filters
    @State private var isSaving = false
    @State private var renderTask: Task<Void, Never>? = nil

    enum EditorTab: String, CaseIterable { case filters = "Filters", adjust = "Adjust" }

    init(originalImage: UIImage, onSave: @escaping (UIImage) -> Void) {
        self.originalImage = originalImage
        self.onSave = onSave
        _previewImage = State(initialValue: originalImage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                Picker("", selection: $activeTab) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)

                Group {
                    if activeTab == .filters {
                        filterPicker
                    } else {
                        adjustPanel
                    }
                }
                .frame(height: 190)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    if !adjustments.isDefault {
                        Button("Reset") {
                            adjustments = .defaults
                            scheduleRender()
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveEdit) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save").fontWeight(.bold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task { generateThumbnails() }
        .onChange(of: adjustments) { _, _ in scheduleRender() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Filters tab

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(PhotoFilterPreset.allCases) { preset in
                    Button(action: {
                        adjustments.preset = preset
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Group {
                                if let thumb = thumbnails[preset] {
                                    Image(uiImage: thumb).resizable().scaledToFill()
                                } else {
                                    Color.gray.opacity(0.25)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(adjustments.preset == preset ? Color.yellow : Color.white.opacity(0.15), lineWidth: adjustments.preset == preset ? 2.5 : 1)
                            )

                            Text(preset.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(adjustments.preset == preset ? .yellow : .white.opacity(0.75))
                                .lineLimit(1)
                                .frame(width: 68)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Adjust tab

    private var adjustPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                adjustSlider(title: "Brightness", value: $adjustments.brightness, range: -0.3...0.3, defaultValue: 0)
                adjustSlider(title: "Contrast", value: $adjustments.contrast, range: 0.7...1.3, defaultValue: 1.0)
                adjustSlider(title: "Saturation", value: $adjustments.saturation, range: 0...2, defaultValue: 1.0)
                adjustSlider(title: "Warmth", value: $adjustments.warmth, range: 4000...9000, defaultValue: 6500)
                adjustSlider(title: "Highlights", value: $adjustments.highlights, range: 0...1, defaultValue: 1.0)
                adjustSlider(title: "Shadows", value: $adjustments.shadows, range: 0...1, defaultValue: 0.0)
                adjustSlider(title: "Sharpness", value: $adjustments.sharpness, range: 0...1, defaultValue: 0.0)
                adjustSlider(title: "Vignette", value: $adjustments.vignette, range: 0...1, defaultValue: 0.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func adjustSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, defaultValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                if value.wrappedValue != defaultValue {
                    Button("Reset") { value.wrappedValue = defaultValue }
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            Slider(value: value, in: range)
                .tint(.yellow)
        }
    }

    // MARK: - Rendering

    private func generateThumbnails() {
        guard let cgImage = originalImage.cgImage else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let side: CGFloat = 90
        let shortEdge = min(ciImage.extent.width, ciImage.extent.height)
        let scale = side / shortEdge
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cropRect = CGRect(
            x: (scaled.extent.width - side) / 2,
            y: (scaled.extent.height - side) / 2,
            width: side,
            height: side
        ).intersection(scaled.extent)
        let square = scaled.cropped(to: cropRect)

        DispatchQueue.global(qos: .userInitiated).async {
            let context = CIContext()
            var results: [PhotoFilterPreset: UIImage] = [:]
            for preset in PhotoFilterPreset.allCases {
                let filtered = preset.apply(to: square)
                if let outputCGImage = context.createCGImage(filtered, from: square.extent) {
                    results[preset] = UIImage(cgImage: outputCGImage)
                }
            }
            DispatchQueue.main.async {
                self.thumbnails = results
            }
        }
    }

    // Debounced so rapid slider drags don't queue up dozens of renders — only the
    // most recent adjustment state ever gets rendered.
    private func scheduleRender() {
        renderTask?.cancel()
        let currentAdjustments = adjustments
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 45_000_000)
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) {
                PhotoFilterRenderer.renderPreview(originalImage, adjustments: currentAdjustments)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run { previewImage = result }
        }
    }

    private func saveEdit() {
        isSaving = true
        let currentAdjustments = adjustments
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                PhotoFilterRenderer.renderFull(originalImage, adjustments: currentAdjustments)
            }.value
            await MainActor.run {
                isSaving = false
                onSave(result)
                dismiss()
            }
        }
    }
}
