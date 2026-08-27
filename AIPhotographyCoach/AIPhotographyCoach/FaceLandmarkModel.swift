import Foundation
import CoreGraphics
import Vision

// MARK: - SwiftUI Dostu Yüz Hatları Veri Modeli
struct FaceLandmarkData: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let leftEyePoints: [CGPoint]
    let rightEyePoints: [CGPoint]
    let leftPupil: CGPoint?
    let rightPupil: CGPoint?
    let outerLipsPoints: [CGPoint]
    let faceContourPoints: [CGPoint]
    let isLookingAtCamera: Bool
}
