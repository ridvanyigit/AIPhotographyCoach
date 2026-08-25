import Foundation
import Vision
import SwiftUI
import UIKit // Cihaz yönünü okumak için eklendi

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    
    // Cihazın dönüşüne göre Vision'a doğru okuma yönünü söyler
    private func getVisionOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right // Normal dik (Portrait) tutuş
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            DispatchQueue.main.async {
                self?.detectedFaces = results.map { $0.boundingBox }
            }
        }
        
        // Dinamik yönlendirmeyi ekliyoruz
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        try? handler.perform([request])
    }
}