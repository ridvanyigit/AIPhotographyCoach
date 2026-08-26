import Foundation
import Vision
import SwiftUI
import UIKit

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    var framingAdvice: FramingAdvice = .searching
    var poseAdvice: PoseAdvice = .none 
    
    // YENİ: Pose AI Açık / Kapalı Kontrolü
    var isPoseAIEnabled: Bool = true
    
    private let framingCoach = PhotographyCoach()
    private let poseCoach = PoseCoach()
    
    private func getVisionOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // 1. Yüz Algılama İsteği (Her zaman çalışır)
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            DispatchQueue.main.async {
                self?.detectedFaces = results.map { $0.boundingBox }
                if let self = self {
                    self.framingAdvice = self.framingCoach.evaluateFraming(faces: self.detectedFaces)
                }
            }
        }
        
        var requests: [VNRequest] = [faceRequest]
        
        // 2. İnsan Pozisyonu İsteği (Sadece Pose AI açıksa çalışır — Pil tasarrufu)
        if isPoseAIEnabled {
            let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
                guard let results = request.results as? [VNHumanBodyPoseObservation], let firstPose = results.first else {
                    DispatchQueue.main.async { self?.poseAdvice = .none }
                    return
                }
                DispatchQueue.main.async {
                    self?.poseAdvice = self?.poseCoach.evaluatePose(observation: firstPose) ?? .none
                }
            }
            requests.append(poseRequest)
        } else {
            DispatchQueue.main.async {
                self.poseAdvice = .none
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        try? handler.perform(requests)
    }
}