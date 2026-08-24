import SwiftUI
import AVFoundation

// UIKit'in UIView nesnesini SwiftUI'a bağlayan köprü yapısı
struct CameraPreviewView: UIViewRepresentable {
    // İçine CameraManager'ın "session" (oturum) verisini alacak
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill // Ekranı tam kapla (Boşluk bırakma)
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Şimdilik güncellenecek dinamik bir yapı yok
    }
}

// Apple'ın standart kamera katmanını çizebilmek için gereken özel UIView sınıfı
class VideoPreviewView: UIView {
    // Bu View'ın ana katmanı bir AVCaptureVideoPreviewLayer olsun diyoruz
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    // Katmana kolay erişmek için bir yardımcı özellik
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
