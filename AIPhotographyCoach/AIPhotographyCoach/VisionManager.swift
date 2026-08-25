import Foundation
import Vision
import SwiftUI
import UIKit

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    var framingAdvice: FramingAdvice = .searching
    
    // NEW: Body pose state
    var poseAdvice: PoseAdvice = .none 
    
    private let framingCoach = PhotographyCoach()
    private let poseCoach = PoseCoach() // NEW
    
    private func getVisionOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // 1. Request for Face Rectangles
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            DispatchQueue.main.async {
                self?.detectedFaces = results.map { $0.boundingBox }
                if let self = self {
                    self.framingAdvice = self.framingCoach.evaluateFraming(faces: self.detectedFaces)
                }
            }
        }
        
        // 2. NEW: Request for Human Body Pose
        let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let results = request.results as? [VNHumanBodyPoseObservation], let firstPose = results.first else {
                DispatchQueue.main.async { self?.poseAdvice = .none }
                return
            }
            DispatchQueue.main.async {
                self?.poseAdvice = self?.poseCoach.evaluatePose(observation: firstPose) ?? .none
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        // Run both AI models simultaneously
        try? handler.perform([faceRequest, poseRequest])
    }
}