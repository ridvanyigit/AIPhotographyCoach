import Foundation

enum RollState {
    case unknown
    case tiltLeft
    case tiltRight
    case aligned
}

enum PitchState {
    case unknown
    case tiltUp
    case tiltDown
    case aligned
}

struct OrientationResult {
    let roll: RollState
    let pitch: PitchState
}

struct GuidanceEngine {
    private let rollThreshold: Double = 2.5
    private let pitchThreshold: Double = 2.5 
    
    func evaluate(roll: Double, pitchDeviation: Double) -> OrientationResult {
        // ROLL (Left / Right)
        let rState: RollState
        if abs(roll) <= rollThreshold {
            rState = .aligned
        } else if roll > 0 {
            rState = .tiltLeft
        } else {
            rState = .tiltRight
        }
        
        // PITCH (Up / Down)
        let pState: PitchState
        if abs(pitchDeviation) <= pitchThreshold {
            pState = .aligned
        } else if pitchDeviation > 0 {
            // Positive deviation means camera is looking too far down at the ground
            pState = .tiltUp
        } else {
            // Negative deviation means camera is looking too far up at the sky
            pState = .tiltDown
        }
        
        return OrientationResult(roll: rState, pitch: pState)
    }
}