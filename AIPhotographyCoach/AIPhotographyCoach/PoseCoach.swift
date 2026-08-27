import Foundation
import Vision

enum PoseAdvice {
    case none
    case good
    case levelShoulders
    case faceCamera
}

struct PoseCoach {
    // 1. İskelet Poz Analizi
    func evaluatePose(observation: VNHumanBodyPoseObservation) -> PoseAdvice {
        if let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
           let rightShoulder = try? observation.recognizedPoint(.rightShoulder) {
            if leftShoulder.confidence > 0.5 && rightShoulder.confidence > 0.5 {
                let yDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
                if yDiff > 0.08 {
                    return .levelShoulders
                }
            }
        }
        return .good
    }
    
    // 2. Yüz Hatları ve Gözbebeği Analizi (Doğrudan Kameraya Bakış Kontrolü)
    func evaluateFaceGaze(landmarks: VNFaceLandmarks2D?) -> Bool {
        guard let landmarks = landmarks,
              let leftPupil = landmarks.leftPupil?.normalizedPoints.first,
              let rightPupil = landmarks.rightPupil?.normalizedPoints.first,
              let leftEye = landmarks.leftEye?.normalizedPoints,
              let rightEye = landmarks.rightEye?.normalizedPoints,
              !leftEye.isEmpty, !rightEye.isEmpty else {
            return true // Veri yoksa kullanıcıyı engelleme
        }
        
        // Gözlerin yatay merkezini bul
        let leftEyeCenterX = leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count)
        let rightEyeCenterX = rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count)
        
        // Gözbebeği merkezden çok fazla sağa/sola kaymışsa (Yan bakış)
        let leftPupilOffset = abs(leftPupil.x - leftEyeCenterX)
        let rightPupilOffset = abs(rightPupil.x - rightEyeCenterX)
        
        return leftPupilOffset < 0.18 && rightPupilOffset < 0.18
    }
}