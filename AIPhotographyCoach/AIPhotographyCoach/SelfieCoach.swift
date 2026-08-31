import Foundation
import CoreGraphics

// Central decision engine: turns Vision's read of the user's face into a single,
// graded coaching pose. Deliberately face-only — how the phone is physically held
// (upright, tilted, low, high, walking, lying down) never factors in on its own;
// only how the face actually looks in the frame matters, exactly like a
// photographer judges a shot, not a spirit level.
struct SelfieCoach {

    // Shared "distance from perfect" tuning, also read by SelfieGuidanceView so the
    // guide phone drawn on screen always matches the thresholds used here. Tuned to
    // sit in the middle: forgiving enough that normal handheld use can reach it, but
    // tight enough that a genuinely bad pose never reads as "Perfect".
    static let maxTravelDegrees: Double = 30.0
    static let perfectRatio: Double = 0.22   // auto-capture fires here
    static let veryGoodRatio: Double = 0.5

    func evaluate(face: FaceLandmarkData?) -> SelfiePose {
        guard let face = face else {
            return SelfiePose(state: .searching, rollDegrees: 0, verticalDegrees: 0, hasFace: false)
        }

        // Coarse framing gate: is the face a sensible size and roughly on-screen at
        // all, and facing the camera? This has to pass before fine pose grading
        // (Good / Very Good / Perfect) applies. Bounds are loose on purpose.
        let faceBox = face.boundingBox
        let faceArea = faceBox.width * faceBox.height
        let isSizeGood = faceArea >= 0.05 && faceArea <= 0.55
        let isRoughlyOnScreen = faceBox.midX >= 0.15 && faceBox.midX <= 0.85
            && faceBox.midY >= 0.15 && faceBox.midY <= 0.85
        let isYawOK = abs(face.faceYaw) <= 0.45

        if !isSizeGood || !isRoughlyOnScreen || !isYawOK {
            return SelfiePose(state: .fitIntoMask, rollDegrees: face.faceRollDegrees, verticalDegrees: 0, hasFace: true)
        }

        if face.eyesClosed {
            return SelfiePose(state: .eyesClosed, rollDegrees: face.faceRollDegrees, verticalDegrees: 0, hasFace: true)
        }

        // Fine pose: how far is the face from dead-center? This combines the head's
        // own tilt (roll) and, on the vertical axis, BOTH the head's angle (pitch)
        // AND where the phone is physically aimed (the face's vertical position in
        // frame) — so tilting the phone and simply moving it up/down are both
        // reflected, not just rotation.
        let idealMidY: Double = 0.5
        // Vision's Y axis increases upward. A face sitting higher in frame than
        // ideal contributes a positive value here, same sign convention as pitch.
        let framingVerticalDegrees = (idealMidY - Double(faceBox.midY)) * 90.0
        let verticalDegrees = (face.facePitch * 180.0 / .pi) + framingVerticalDegrees

        let normalizedDistance = sqrt(
            pow(face.faceRollDegrees / Self.maxTravelDegrees, 2) +
            pow(verticalDegrees / Self.maxTravelDegrees, 2)
        )

        let state: SelfieState
        if normalizedDistance > 1.0 {
            state = .fitIntoMask
        } else if normalizedDistance <= Self.perfectRatio {
            state = .perfect
        } else if normalizedDistance <= Self.veryGoodRatio {
            state = .veryGood
        } else {
            state = .good
        }

        return SelfiePose(state: state, rollDegrees: face.faceRollDegrees, verticalDegrees: verticalDegrees, hasFace: true)
    }

    // MARK: - Light Source Guidance
    // Grades a raw LightingAnalysis sample the same way pose is graded, and produces
    // one concrete, prioritized hint an amateur can actually act on. Auto-capture
    // requires this to reach `.perfect` too, not just the pose.
    func evaluateLighting(_ analysis: LightingAnalysis?) -> LightingGuidance {
        guard let analysis = analysis else { return .unknown }

        let idealBrightness = 0.55
        let brightnessTolerance = 0.28
        let brightnessDeviation = abs(analysis.brightness - idealBrightness) / brightnessTolerance

        let evennessDeviation = sqrt(pow(analysis.horizontalBias, 2) + pow(analysis.verticalBias, 2))

        let contrastComfortable = 0.4
        let contrastDeviation = max(0, analysis.contrast - contrastComfortable) / (1 - contrastComfortable)

        let combined = (brightnessDeviation * 0.4) + (evennessDeviation * 0.4) + (contrastDeviation * 0.2)

        let state: LightingGuidanceState
        if combined <= 0.3 {
            state = .perfect
        } else if combined <= 0.6 {
            state = .veryGood
        } else if combined <= 1.1 {
            state = .good
        } else {
            state = .needsWork
        }

        var hint: String? = nil
        if analysis.brightness < idealBrightness - brightnessTolerance {
            hint = "Face a brighter light source"
        } else if analysis.brightness > idealBrightness + brightnessTolerance {
            hint = "Too bright — step back from the light"
        } else if abs(analysis.horizontalBias) > 0.3 {
            hint = analysis.horizontalBias > 0 ? "Move the light to your left" : "Move the light to your right"
        } else if analysis.verticalBias > 0.3 {
            hint = "Light is too high — lower it toward eye level"
        } else if analysis.verticalBias < -0.3 {
            hint = "Light is too low — raise it toward eye level"
        } else if analysis.contrast > contrastComfortable {
            hint = "Soften harsh shadows — face the light more directly"
        }

        return LightingGuidance(state: state, horizontalBias: analysis.horizontalBias, verticalBias: analysis.verticalBias, hint: hint)
    }

    // Composite 0...100 quality score shown after a shot, with a per-category
    // breakdown. Lighting and hand stability are informative here even though they
    // don't gate capture — the score still tells the user honestly how good the
    // conditions were.
    func computeQuality(face: FaceLandmarkData?, lightingGuidance: LightingGuidance, stability: StabilityInfo) -> CaptureQuality {
        guard let face = face else { return .placeholder }

        let faceBox = face.boundingBox
        let idealArea = 0.20
        let sizeDelta = abs(Double(faceBox.width * faceBox.height) - idealArea) / idealArea
        let centerDelta = abs(Double(faceBox.midX) - 0.5) * 2.0
        let framingRaw = 1.0 - min(sizeDelta * 0.6 + centerDelta, 1.0)
        let framingScore = clampScore(framingRaw * 0.6 + face.symmetryScore * 0.4)

        let lightingScore: Int
        switch lightingGuidance.state {
        case .perfect: lightingScore = 100
        case .veryGood: lightingScore = 82
        case .good: lightingScore = 60
        case .needsWork: lightingScore = 35
        case .unknown: lightingScore = 50
        }

        let sharpnessRaw = 1.0 - min(stability.angularVelocity / 0.8, 1.0)
        let sharpnessScore = clampScore(sharpnessRaw)

        let eyesRaw = face.isLookingAtLens ? face.averageEyeOpenness : face.averageEyeOpenness * 0.75
        let eyesScore = clampScore(eyesRaw)

        // A genuine smile is a small bonus on top of the four hard metrics rather than
        // its own category — a great technical shot with a flat expression should still
        // score well, a smiling one just edges it out.
        let smileBonus = Int((face.smileIntensity * 4.0).rounded())

        let baseOverall = (framingScore + lightingScore + sharpnessScore + eyesScore) / 4
        let overall = min(baseOverall + smileBonus, 100)

        return CaptureQuality(
            overallScore: overall,
            framingScore: framingScore,
            lightingScore: lightingScore,
            sharpnessScore: sharpnessScore,
            eyesScore: eyesScore
        )
    }

    private func clampScore(_ value: Double) -> Int {
        Int((min(max(value, 0.0), 1.0) * 100).rounded())
    }
}
