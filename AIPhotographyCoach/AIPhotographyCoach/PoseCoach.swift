import Foundation
import Vision

enum PoseAdvice {
    case none
    case good
    case levelShoulders
    case faceCamera
}

// YENİ: Boydan Çekim İskelet Uyumu Durumları
enum BodyFitState {
    case searching
    case stepBack
    case moveCloser
    case adjustTilt
    case perfectFit
}

struct PoseCoach {
    func evaluatePose(observation: VNHumanBodyPoseObservation) -> PoseAdvice {
        // 1. Kameraya Bakış Kontrolü
        if let nose = try? observation.recognizedPoint(.nose),
           let leftEar = try? observation.recognizedPoint(.leftEar),
           let rightEar = try? observation.recognizedPoint(.rightEar) {
            if nose.confidence > 0.5 {
                if leftEar.confidence < 0.2 || rightEar.confidence < 0.2 {
                    return .faceCamera
                }
            }
        }
        
        // 2. Omuz Düzlüğü Kontrolü
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
    
    // YENİ: Baş ve Ayakları Altın Oran Şablonuna Göre Canlı Değerlendirme
    func evaluateBodyFit(observation: VNHumanBodyPoseObservation) -> BodyFitState {
        let nose = (try? observation.recognizedPoint(.nose))?.confidence ?? 0 > 0.3 ? (try? observation.recognizedPoint(.nose)) : nil
        let leftAnkle = (try? observation.recognizedPoint(.leftAnkle))?.confidence ?? 0 > 0.3 ? (try? observation.recognizedPoint(.leftAnkle)) : nil
        let rightAnkle = (try? observation.recognizedPoint(.rightAnkle))?.confidence ?? 0 > 0.3 ? (try? observation.recognizedPoint(.rightAnkle)) : nil
        
        guard let headPoint = nose else { return .searching }
        
        let feetY: CGFloat
        if let l = leftAnkle, let r = rightAnkle {
            feetY = min(l.location.y, r.location.y)
        } else if let l = leftAnkle {
            feetY = l.location.y
        } else if let r = rightAnkle {
            feetY = r.location.y
        } else {
            // Ayak bilekleri görünmüyorsa kişi kadraja sığmamıştır (çok yakındır)
            return .stepBack
        }
        
        let headTopY = headPoint.location.y + 0.07 // Baş tepesi tahmini
        let personHeight = headTopY - feetY
        
        if personHeight < 0.45 {
            return .moveCloser // Kişi ekranın %45'inden küçük kalmış (çok uzak)
        } else if headTopY > 0.95 || feetY < 0.08 {
            return .stepBack // Baş tavana veya ayaklar tabana taşmış
        } else if headTopY >= 0.76 && headTopY <= 0.94 && feetY >= 0.12 && feetY <= 0.30 {
            return .perfectFit // Baş ve ayaklar şablona tam oturdu!
        } else {
            return .adjustTilt
        }
    }
}