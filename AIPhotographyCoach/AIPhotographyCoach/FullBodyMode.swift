import SwiftUI

// MARK: - Boydan / Tüm Vücut Çekim Modları
enum FullBodyMode: String, CaseIterable, Identifiable {
    case fashion = "FASHION"
    case modelPose = "MODEL POSE"
    case lowAngle = "LOW ANGLE"
    case fitness = "FITNESS"
    case casualStreet = "CASUAL STREET"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .fashion: return "figure.stand.dress"
        case .modelPose: return "figure.walk"
        case .lowAngle: return "arrow.up.and.line.horizontal.and.arrow.down"
        case .fitness: return "figure.arms.open"
        case .casualStreet: return "figure.walk.motion"
        }
    }
}