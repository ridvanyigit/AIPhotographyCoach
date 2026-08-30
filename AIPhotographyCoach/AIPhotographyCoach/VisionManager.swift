import Foundation
import Vision
import SwiftUI
import UIKit
import CoreImage

@Observable
class VisionManager {
    var detectedFaces: [CGRect] = []
    var smoothedFaceBox: CGRect? = nil
    var faceLandmarks: [FaceLandmarkData] = []
    var isFrontCamera: Bool = true

    // Sampled a few times a second from the same frame/face used for pose tracking
    // (see analyzeLighting below), so the light-source compass always matches what
    // was actually detected — nil until the first real sample comes in.
    var lightingAnalysis: LightingAnalysis? = nil

    private let smoothingFactor: CGFloat = 0.25 // Reduces jitter in the tracked face box

    // Eye-aspect-ratio thresholds used to turn the raw eye contour into a 0...1 openness value
    private let eyeClosedRatio: CGFloat = 0.08
    private let eyeOpenRatio: CGFloat = 0.35

    // Lighting analysis involves a small GPU render, so it's throttled to roughly
    // 5 samples/sec (every 6th frame at ~30fps) instead of running on every frame.
    private let lightingContext = CIContext(options: [.workingColorSpace: NSNull()])
    private var lightingFrameCounter = 0
    private let lightingSampleInterval = 6

    private func getVisionOrientation() -> CGImagePropertyOrientation {
        return isFrontCamera ? .leftMirrored : .right
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  error == nil, !results.isEmpty else {
                DispatchQueue.main.async { self?.resetState() }
                return
            }

            // If more than one face is in frame, coach the largest/closest one —
            // that's almost always the person holding the phone.
            let primaryFace = results.max { lhs, rhs in
                (lhs.boundingBox.width * lhs.boundingBox.height) < (rhs.boundingBox.width * rhs.boundingBox.height)
            } ?? results[0]

            let data = self.analyze(face: primaryFace, totalFaces: results.count)

            // Sample ambient light around the SAME face, in the SAME frame, so the
            // reading is never a stale mismatch with what's on screen.
            self.lightingFrameCounter += 1
            var lightingResult: LightingAnalysis? = nil
            if self.lightingFrameCounter % self.lightingSampleInterval == 0 {
                lightingResult = self.analyzeLighting(pixelBuffer: pixelBuffer, faceBoundingBox: primaryFace.boundingBox)
            }

            DispatchQueue.main.async {
                self.detectedFaces = [primaryFace.boundingBox]
                self.faceLandmarks = [data]
                if let lightingResult = lightingResult {
                    self.lightingAnalysis = lightingResult
                }

                // Smooth the tracked box so the on-screen guide doesn't jitter frame to frame
                if let current = self.smoothedFaceBox {
                    self.smoothedFaceBox = CGRect(
                        x: current.origin.x * (1 - self.smoothingFactor) + primaryFace.boundingBox.origin.x * self.smoothingFactor,
                        y: current.origin.y * (1 - self.smoothingFactor) + primaryFace.boundingBox.origin.y * self.smoothingFactor,
                        width: current.size.width * (1 - self.smoothingFactor) + primaryFace.boundingBox.size.width * self.smoothingFactor,
                        height: current.size.height * (1 - self.smoothingFactor) + primaryFace.boundingBox.size.height * self.smoothingFactor
                    )
                } else {
                    self.smoothedFaceBox = primaryFace.boundingBox
                }
            }
        }

        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: getVisionOrientation(), options: [:])
        try? handler.perform([request])
    }

    private func resetState() {
        detectedFaces = []
        faceLandmarks = []
        smoothedFaceBox = nil
        lightingAnalysis = nil
    }

    // Renders the face region of the current frame, oriented exactly the way Vision
    // saw it, down to a tiny grid to read out brightness/evenness/contrast cheaply.
    private func analyzeLighting(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> LightingAnalysis? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(getVisionOrientation())
        return LightingAnalyzer.analyze(ciImage: ciImage, faceBoundingBox: faceBoundingBox, context: lightingContext)
    }

    // MARK: - Landmark Analysis

    private func analyze(face: VNFaceObservation, totalFaces: Int) -> FaceLandmarkData {
        let landmarks = face.landmarks
        let yaw = face.yaw?.doubleValue ?? 0.0
        let pitch = face.pitch?.doubleValue ?? 0.0

        let isLooking = evaluateLensGaze(landmarks: landmarks)
        let (leftOpenness, rightOpenness) = evaluateEyeOpenness(landmarks: landmarks)
        let roll = evaluateFaceRoll(landmarks: landmarks) ?? (face.roll?.doubleValue ?? 0.0) * (180.0 / .pi)
        let mouthOpenness = evaluateMouthOpenness(landmarks: landmarks)
        let (isSmiling, smileIntensity) = evaluateSmile(landmarks: landmarks)
        let symmetry = evaluateSymmetry(landmarks: landmarks)

        return FaceLandmarkData(
            boundingBox: face.boundingBox,
            faceYaw: yaw,
            facePitch: pitch,
            faceRollDegrees: roll,
            isLookingAtLens: isLooking,
            leftEyeOpenness: leftOpenness,
            rightEyeOpenness: rightOpenness,
            isSmiling: isSmiling,
            smileIntensity: smileIntensity,
            mouthOpenness: mouthOpenness,
            symmetryScore: symmetry,
            totalFacesDetected: totalFaces
        )
    }

    // Checks whether the pupils are vertically centered in the eyes (looking at the lens)
    // rather than down at the screen — the single biggest thing that separates an amateur
    // selfie from one that looks intentional.
    private func evaluateLensGaze(landmarks: VNFaceLandmarks2D?) -> Bool {
        guard let leftPupil = landmarks?.leftPupil?.normalizedPoints.first,
              let rightPupil = landmarks?.rightPupil?.normalizedPoints.first,
              let leftEye = landmarks?.leftEye?.normalizedPoints,
              let rightEye = landmarks?.rightEye?.normalizedPoints,
              !leftEye.isEmpty, !rightEye.isEmpty else { return true }

        let leftCenterY = leftEye.map { $0.y }.reduce(0, +) / CGFloat(leftEye.count)
        let rightCenterY = rightEye.map { $0.y }.reduce(0, +) / CGFloat(rightEye.count)

        let leftDiff = leftPupil.y - leftCenterY
        let rightDiff = rightPupil.y - rightCenterY

        // Generous tolerance so we don't nag the user over natural micro-movements
        return leftDiff > -0.06 && rightDiff > -0.06
    }

    // Eye-aspect-ratio style blink detection: contour height / width collapses toward
    // zero as the eyelid closes, independent of face size or distance from camera.
    private func evaluateEyeOpenness(landmarks: VNFaceLandmarks2D?) -> (left: Double, right: Double) {
        func openness(for region: VNFaceLandmarkRegion2D?) -> Double {
            guard let points = region?.normalizedPoints, points.count >= 4 else { return 1.0 }
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 1.0 }
            let width = max(maxX - minX, 0.0001)
            let height = maxY - minY
            let ratio = height / width
            let normalized = (ratio - eyeClosedRatio) / (eyeOpenRatio - eyeClosedRatio)
            return Double(min(max(normalized, 0.0), 1.0))
        }
        return (openness(for: landmarks?.leftEye), openness(for: landmarks?.rightEye))
    }

    // In-plane head roll derived from the eye line, which reflects how tilted the
    // face actually looks in the final photo — more reliable than device roll alone
    // for people who naturally hold their head at an angle.
    private func evaluateFaceRoll(landmarks: VNFaceLandmarks2D?) -> Double? {
        guard let leftEye = landmarks?.leftEye?.normalizedPoints, !leftEye.isEmpty,
              let rightEye = landmarks?.rightEye?.normalizedPoints, !rightEye.isEmpty else { return nil }

        let leftCenter = CGPoint(
            x: leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count),
            y: leftEye.map { $0.y }.reduce(0, +) / CGFloat(leftEye.count)
        )
        let rightCenter = CGPoint(
            x: rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count),
            y: rightEye.map { $0.y }.reduce(0, +) / CGFloat(rightEye.count)
        )

        let angle = atan2(rightCenter.y - leftCenter.y, rightCenter.x - leftCenter.x)
        return Double(angle) * (180.0 / .pi)
    }

    // Mouth cavity height relative to its width — near zero for a closed mouth,
    // rising as the jaw drops open.
    private func evaluateMouthOpenness(landmarks: VNFaceLandmarks2D?) -> Double {
        guard let points = landmarks?.innerLips?.normalizedPoints, points.count >= 4 else { return 0.0 }
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 0.0 }
        let width = max(maxX - minX, 0.0001)
        let height = maxY - minY
        return Double(min(max(height / width, 0.0), 1.0))
    }

    private func evaluateSmile(landmarks: VNFaceLandmarks2D?) -> (isSmiling: Bool, intensity: Double) {
        guard let outerLips = landmarks?.outerLips?.normalizedPoints, outerLips.count > 6 else { return (false, 0.0) }
        let left = outerLips[0]
        let right = outerLips[outerLips.count / 2]
        let width = abs(right.x - left.x)
        let intensity = Double(min(max((width - 0.32) / (0.55 - 0.32), 0.0), 1.0))
        return (width > 0.4, intensity)
    }

    // How centered the nose is between the eyes horizontally — a quick proxy for
    // whether the face is squared to the camera rather than turned to one side.
    private func evaluateSymmetry(landmarks: VNFaceLandmarks2D?) -> Double {
        guard let nose = landmarks?.nose?.normalizedPoints, !nose.isEmpty,
              let leftEye = landmarks?.leftEye?.normalizedPoints, !leftEye.isEmpty,
              let rightEye = landmarks?.rightEye?.normalizedPoints, !rightEye.isEmpty else { return 1.0 }

        let noseX = nose.map { $0.x }.reduce(0, +) / CGFloat(nose.count)
        let leftEyeX = leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count)
        let rightEyeX = rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count)
        let midEyesX = (leftEyeX + rightEyeX) / 2.0

        let deviation = abs(noseX - midEyesX)
        return Double(min(max(1.0 - (deviation * 6.0), 0.0), 1.0))
    }
}
