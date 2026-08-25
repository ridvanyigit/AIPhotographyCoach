import Foundation

enum GuidanceState {
    case unknown
    case tiltLeft
    case tiltRight
    case aligned
}

struct GuidanceEngine {
    // Increased threshold for a much better user experience (easier to hit the sweet spot)
    private let alignmentThreshold: Double = 2.5 
    
    func evaluate(roll: Double) -> GuidanceState {
        if abs(roll) <= alignmentThreshold {
            return .aligned
        } else if roll > 0 {
            return .tiltLeft
        } else {
            return .tiltRight
        }
    }
}