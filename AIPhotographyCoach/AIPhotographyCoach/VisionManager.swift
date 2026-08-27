import Foundation
import Vision
import SwiftUI
import UIKit

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    var faceLandmarks: [FaceLandmarkData] = []
    var framingAdvice: FramingAdvice = .searching
    var poseAdvice: PoseAdvice = .none 
    var bodyFitState: BodyFitState = .searching
    
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
        // 1. Gelişmiş Yüz ve Yüz Hatları Algılama İsteği (Face Landmarks)
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], error == nil else { return }
            
            var landmarkDataList: [FaceLandmarkData] = []
            var faceRects: [CGRect] = []
            
            for face in results {
                faceRects.append(face.boundingBox)
                
                let isGazeDirect = self?.poseCoach.evaluateFaceGaze(landmarks: face.landmarks) ?? true
                
                let data = FaceLandmarkData(
                    boundingBox: face.boundingBox,
                    leftEyePoints: face.landmarks?.leftEye?.normalizedPoints ?? [],
                    rightEyePoints: face.landmarks?.rightEye?.normalizedPoints ?? [],
                    leftPupil: face.landmarks?.leftPupil?.normalizedPoints.first,
                    rightPupil: face.landmarks?.rightPupil?.normalizedPoints.first,
                    outerLipsPoints: face.landmarks?.outerLips?.normalizedPoints ?? [],
                    faceContourPoints: face.landmarks?.faceContour?.normalizedPoints ?? [],
                    isLookingAtCamera: isGazeDirect
                )
                landmarkDataList.append(data)
            }
            
            DispatchQueue.main.async {
                self?.detectedFaces = faceRects
                self?.faceLandmarks = landmarkDataList
                if let self = self {
                    self.framingAdvice = self.framingCoach.evaluateFraming(faces: self.detectedFaces)
                    
                    // Eğer model yana bakıyorsa tavsiyeyi güncelle
                    if let firstFace = landmarkDataList.first, !firstFace.isLookingAtCamera {
                        self.poseAdvice = .faceCamera
                    }
                }
            }
        }
        
        var requests: [VNRequest] = [faceLandmarksRequest]
        
        // 2. İnsan Vücut İskeleti ve Boydan Çekim İsteği
        if isPoseAIEnabled {
            let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
                guard let results = request.results as? [VNHumanBodyPoseObservation], let firstPose = results.first else {
                    DispatchQueue.main.async {
                        self?.poseAdvice = .none
                        self?.bodyFitState = .searching
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if self?.poseAdvice != .faceCamera {
                        self?.poseAdvice = self?.poseCoach.evaluatePose(observation: firstPose) ?? .none
                    }
                    self?.evaluateBodyFit(observation: firstPose)
                }
            }
            requests.append(poseRequest)
        } else {
            DispatchQueue.main.async {
                self.poseAdvice = .none
                self.bodyFitState = .searching
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        try? handler.perform(requests)
    }
    
    private func evaluateBodyFit(observation: VNHumanBodyPoseObservation) {
        guard let nose = try? observation.recognizedPoint(.nose),
              let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle),
              nose.confidence > 0.3 else {
            bodyFitState = .searching
            return
        }
        
        let headY = nose.location.y
        let ankleY: CGFloat
        if leftAnkle.confidence > 0.3 && rightAnkle.confidence > 0.3 {
            ankleY = (leftAnkle.location.y + rightAnkle.location.y) / 2.0
        } else if leftAnkle.confidence > 0.3 {
            ankleY = leftAnkle.location.y
        } else if rightAnkle.confidence > 0.3 {
            ankleY = rightAnkle.location.y
        } else {
            bodyFitState = .moveCloser
            return
        }
        
        let targetHeadMin: CGFloat = 0.78
        let targetHeadMax: CGFloat = 0.94
        let targetFeetMin: CGFloat = 0.08
        let targetFeetMax: CGFloat = 0.28
        
        let isHeadAligned = (headY >= targetHeadMin && headY <= targetHeadMax)
        let isFeetAligned = (ankleY >= targetFeetMin && ankleY <= targetFeetMax)
        
        if isHeadAligned && isFeetAligned {
            bodyFitState = .perfectFit
        } else if headY > targetHeadMax || ankleY < targetFeetMin {
            bodyFitState = .stepBack
        } else if headY < targetHeadMin && ankleY > targetFeetMax {
            bodyFitState = .moveCloser
        } else {
            bodyFitState = .searching
        }
    }
}