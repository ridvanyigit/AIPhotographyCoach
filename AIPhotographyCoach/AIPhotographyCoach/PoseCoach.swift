import Foundation
import Vision

enum PoseAdvice {
    case none
    case good
    case levelShoulders
    case faceCamera
}

struct PoseCoach {
    func evaluatePose(observation: VNHumanBodyPoseObservation) -> PoseAdvice {
        
        // 1. Check if the person is facing the camera (using nose and ears)
        if let nose = try? observation.recognizedPoint(.nose),
           let leftEar = try? observation.recognizedPoint(.leftEar),
           let rightEar = try? observation.recognizedPoint(.rightEar) {
            
            if nose.confidence > 0.5 {
                // If nose is highly visible but one ear is hidden, they are looking away sideways
                if leftEar.confidence < 0.2 || rightEar.confidence < 0.2 {
                    return .faceCamera
                }
            }
        }
        
        // 2. Check if shoulders are leveled
        if let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
           let rightShoulder = try? observation.recognizedPoint(.rightShoulder) {
            
            if leftShoulder.confidence > 0.5 && rightShoulder.confidence > 0.5 {
                let yDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
                // If one shoulder is significantly higher than the other (8% of frame)
                if yDiff > 0.08 {
                    return .levelShoulders
                }
            }
        }
        
        return .good
    }
}
