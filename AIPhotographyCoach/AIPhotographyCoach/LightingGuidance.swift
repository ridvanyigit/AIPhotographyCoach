import Foundation

// MARK: - Light Source Guidance
// Turns a raw LightingAnalysis sample into the same three-tier grading the pose
// compass uses (Good / Very Good / Perfect), plus one concrete, prioritized hint —
// telling an amateur exactly what to physically do ("move the light to your left")
// instead of just flagging that something's off.
enum LightingGuidanceState: Equatable {
    case unknown       // no sample yet (no face, or first frames after launch)
    case needsWork      // light is poorly placed, too dark/bright, or too harsh
    case good
    case veryGood
    case perfect

    var message: String {
        switch self {
        case .unknown: return "Reading the light…"
        case .needsWork: return "Adjust your light source"
        case .good: return "Light: Good"
        case .veryGood: return "Light: Very Good"
        case .perfect: return "Light: Perfect"
        }
    }
}

struct LightingGuidance {
    let state: LightingGuidanceState
    let horizontalBias: Double  // for the light compass dot's horizontal position
    let verticalBias: Double    // for the light compass dot's vertical position
    let hint: String?           // single most important actionable tip, or nil once perfect

    static let unknown = LightingGuidance(state: .unknown, horizontalBias: 0, verticalBias: 0, hint: nil)
}
