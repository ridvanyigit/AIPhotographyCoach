import Foundation
import Vision
import SwiftUI
import UIKit

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    var framingAdvice: FramingAdvice = .searching // YENİ: Koçun anlık tavsiyesi
    
    private let coach = PhotographyCoach() // Koç motorunu başlattık
    
    private func getVisionOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 1. Yüzleri güncelle
                self.detectedFaces = results.map { $0.boundingBox }
                // 2. Fotoğrafçılık Koçu'na yüzleri gönderip tavsiye al
                self.framingAdvice = self.coach.evaluateFraming(faces: self.detectedFaces)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        try? handler.perform([request])
    }
}
