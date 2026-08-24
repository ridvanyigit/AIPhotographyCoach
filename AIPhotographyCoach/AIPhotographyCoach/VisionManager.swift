import Foundation
import Vision // Apple'ın Bilgisayarlı Görü (Computer Vision) kütüphanesi
import SwiftUI

@Observable
class VisionManager {
    // Ekranda bulunan yüzlerin koordinat listesi
    var detectedFaces: [CGRect] = []
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // 1. Ne aradığımızı tanımlıyoruz (Yüz Dikdörtgenleri)
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            
            // Vision sonuçları arka planda üretir, UI güncellemeleri Main Thread'de olmalı
            DispatchQueue.main.async {
                // Bulunan tüm yüzlerin Bounding Box (Kapsama Kutusu) koordinatlarını al
                self?.detectedFaces = results.map { $0.boundingBox }
            }
        }
        
        // 2. Görüntüyü Vision'a veriyoruz.
        // iPhone kamerası fiziksel olarak yan yattığı için (Landscape Right) doğru yönü belirtmeliyiz (.right)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Vision Error: \(error.localizedDescription)")
        }
    }
}
