import Foundation
import CoreGraphics

// MARK: - Rich Face Analysis Data Model
// Captures everything Vision extracts from a single video frame: face geometry,
// gaze, eye openness (for blink detection), mouth state, and in-plane head roll.
struct FaceLandmarkData: Identifiable {
    let id = UUID()

    // Core geometry (normalized Vision coordinates, 0...1)
    let boundingBox: CGRect

    // Head orientation reported by Vision (radians)
    let faceYaw: Double
    let facePitch: Double

    // In-plane roll of the face itself, derived from the eye line.
    // This is more accurate for "level selfie" feedback than device roll alone,
    // because it reflects how tilted the face actually looks in the photo.
    let faceRollDegrees: Double

    // Gaze & eyes
    let isLookingAtLens: Bool
    let leftEyeOpenness: Double   // 0 (closed) ... 1 (fully open)
    let rightEyeOpenness: Double
    var averageEyeOpenness: Double { (leftEyeOpenness + rightEyeOpenness) / 2.0 }
    // Loosened on purpose: only flags an obvious, fully-closed blink. Eye-openness
    // estimation from 2D landmarks is inherently noisy, and a jumpy threshold here was
    // one of the reasons the "perfect" state was nearly impossible to reach.
    var eyesClosed: Bool { averageEyeOpenness < 0.10 }

    // Mouth / expression
    let isSmiling: Bool
    let smileIntensity: Double    // 0...1
    let mouthOpenness: Double     // 0 (closed) ... 1 (wide open)

    // Framing quality
    let symmetryScore: Double     // 0 (very asymmetric) ... 1 (perfectly centered face)

    // How many faces Vision found in this frame. The coach always guides based on
    // the largest/most-centered face, but a count > 1 lets the UI warn about photobombers.
    let totalFacesDetected: Int
}

// MARK: - Ambient Lighting Classification
// Derived from the live exposure metadata in CameraManager (EXIF brightness value).
enum LightingCondition: Equatable {
    case tooDark
    case good
    case tooBright
}

// MARK: - Device Stability
// Derived from the gyroscope rotation rate in MotionManager. Distinguishes a
// deliberate hand-hold from a shaky frame that would blur the photo.
struct StabilityInfo: Equatable {
    let isStable: Bool
    let angularVelocity: Double // rad/s, smoothed
}

// MARK: - Selfie Coaching States
// Graded so the user always knows how close they are, not just pass/fail. Only the
// face itself decides the state — never the phone's physical orientation — so this
// works the same whether the phone is held upright, tilted, low, high, or while
// lying down. Auto-capture only ever fires on `.perfect`.
enum SelfieState: Equatable {
    case searching        // No face found yet
    case fitIntoMask      // Face needs to be centered/resized, or turned too far away
    case eyesClosed       // Blink detected, don't capture
    case good             // Roughly on target — fine for a manual shot
    case veryGood         // Close to dead-center — almost there
    case perfect          // Dead-center — this is what auto-capture waits for

    var message: String {
        switch self {
        case .searching: return "Align your face in frame"
        case .fitIntoMask: return "Center your face here 👤"
        case .eyesClosed: return "Open your eyes 👀"
        case .good: return "Good"
        case .veryGood: return "Very Good"
        case .perfect: return "Perfect ✨"
        }
    }

    var systemIcon: String {
        switch self {
        case .searching: return "person.fill.viewfinder"
        case .fitIntoMask: return "person.crop.circle.dashed"
        case .eyesClosed: return "eye.slash.fill"
        case .good: return "hand.thumbsup"
        case .veryGood: return "hand.thumbsup.fill"
        case .perfect: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Selfie Pose
// The full result of evaluating a single frame: which coaching state applies, plus
// the exact roll/vertical deviation used to place the on-screen guide dot — so the
// message shown to the user and the dot's position always agree with each other.
struct SelfiePose {
    let state: SelfieState
    let rollDegrees: Double        // horizontal axis of the guide dot — face tilt
    let verticalDegrees: Double    // vertical axis of the guide dot — head angle AND
                                    // where the phone is physically aimed, combined
    let hasFace: Bool
}

// MARK: - Capture Quality Score
// A composite 0...100 score computed at the moment of capture, plus the
// per-category breakdown that produced it. Shown to the user after the shot
// so the app feels like an actual photography coach, not a black box.
struct CaptureQuality {
    let overallScore: Int
    let framingScore: Int
    let lightingScore: Int
    let sharpnessScore: Int
    let eyesScore: Int

    static let placeholder = CaptureQuality(overallScore: 0, framingScore: 0, lightingScore: 0, sharpnessScore: 0, eyesScore: 0)
}
