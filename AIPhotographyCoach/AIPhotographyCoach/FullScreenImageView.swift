import SwiftUI
import UIKit

struct FullScreenImageView: View {
    let image: UIImage
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var showControls: Bool = true
    @State private var showShareSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 1. GARANTİLİ VE SAĞLAM ZOOM GÖRÜNTÜLEYİCİ
            ZoomableScrollView(
                image: image,
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls.toggle()
                    }
                }
            )
            .ignoresSafeArea()

            // 2. ÜST VE ALT KONTROL PANELLERİ
            if showControls {
                VStack {
                    // ÜST BAR: Geri Dönüş ve AI Rozeti
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Camera")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 5)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("AI Ready")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // ALT BAR: Eylemler ve Silme Butonu
                    HStack(spacing: 28) {
                        // 1. Paylaşım
                        Button(action: { showShareSheet = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("Share")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                        }
                        
                        // 2. AI Sihirli İyileştirme
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 22))
                                    .foregroundColor(.yellow)
                                Text("AI Edit")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        // 3. AI Filtreler
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 20))
                                Text("Filters")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                        }
                        
                        // 4. Detay
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 20))
                                Text("Info")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                        }
                        
                        // 5. YENİ: SİLME BUTONU (TRASH)
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                Text("Delete")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    .padding(.bottom, 30)
                }
                .transition(.opacity)
            }
        }
        // Silme Onay Penceresi (Apple Standart ActionSheet / ConfirmationDialog)
        .confirmationDialog("Delete Photo", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This photo will be removed from your preview.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [image])
        }
    }
}

// MARK: - Özel UIScrollView Alt Sınıfı (Layout ve Çizim Garantili)
struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void

    func makeUIView(context: Context) -> CenteringScrollView {
        let view = CenteringScrollView(image: image)
        view.onSingleTap = onSingleTap
        return view
    }

    func updateUIView(_ uiView: CenteringScrollView, context: Context) {
        uiView.updateImage(image)
    }
}

class CenteringScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    var onSingleTap: (() -> Void)?

    init(image: UIImage) {
        super.init(frame: .zero)
        self.delegate = self
        self.minimumZoomScale = 1.0
        self.maximumZoomScale = 5.0
        self.bouncesZoom = true
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.backgroundColor = .clear

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateImage(_ image: UIImage) {
        imageView.image = image
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ekran çizildiği anda görselin tam boyutunu hesaplayıp ekrana yerleştirir
        if zoomScale == 1.0 {
            imageView.frame = bounds
        } else {
            centerImage()
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    private func centerImage() {
        let boundsSize = bounds.size
        var frameToCenter = imageView.frame

        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.0 {
            setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoomRect = CGRect(
                x: point.x - (bounds.size.width / 5.0),
                y: point.y - (bounds.size.height / 5.0),
                width: bounds.size.width / 2.5,
                height: bounds.size.height / 2.5
            )
            zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        onSingleTap?()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}