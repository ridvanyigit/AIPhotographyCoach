import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // SwiftUI tarafında bir güncelleme olursa burası çalışır, şu an boş kalabilir.
    }
}

// Apple'ın standart kamera katmanını çizebilmek için gereken özel UIView sınıfı
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    // EKRAN DÖNDÜĞÜNDE VEYA BOYUT DEĞİŞTİRDİĞİNDE OTOMATİK ÇALIŞIR
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Kameranın yönlendirme (orientation) ayarlarını destekleyip desteklemediğini kontrol et
        guard let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported else { return }
        
        // Mevcut ekranın (UIWindowScene) yönelimini al
        if let windowScene = window?.windowScene {
            // Ekran ne yöne döndüyse, kamera bağlantısını (connection) da o yöne çevir
            switch windowScene.interfaceOrientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}
