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
    // INCREASED THRESHOLD: From 2.5 to 3.5 to make it much easier to lock into the "Green" state.
    private let rollThreshold: Double = 3.5
    private let pitchThreshold: Double = 3.5 
    
    func evaluate(roll: Double, pitchDeviation: Double) -> OrientationResult {
        let rState: RollState
        if abs(roll) <= rollThreshold { rState = .aligned }
        else if roll > 0 { rState = .tiltLeft }
        else { rState = .tiltRight }
        
        let pState: PitchState
        if abs(pitchDeviation) <= pitchThreshold { pState = .aligned }
        else if pitchDeviation > 0 { pState = .tiltUp }
        else { pState = .tiltDown }
        
        return OrientationResult(roll: rState, pitch: pState)
    }
}