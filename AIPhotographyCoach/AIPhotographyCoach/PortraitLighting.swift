import SwiftUI

// MARK: - Apple 6 Temel Portre Işığı Modu
enum PortraitLightingMode: String, CaseIterable, Identifiable {
    case natural = "NATURAL LIGHT"
    case studio = "STUDIO LIGHT"
    case contour = "CONTOUR LIGHT"
    case stage = "STAGE LIGHT"
    case stageMono = "STAGE MONO"
    case highKeyMono = "HIGH-KEY MONO"
    
    var id: String { rawValue }
    
    var shortTitle: String {
        switch self {
        case .natural: return "Natural"
        case .studio: return "Studio"
        case .contour: return "Contour"
        case .stage: return "Stage"
        case .stageMono: return "Stage Mono"
        case .highKeyMono: return "High-Key"
        }
    }
    
    var iconName: String {
        switch self {
        case .natural: return "cube"
        case .studio: return "cube.fill"
        case .contour: return "circle.lefthalf.filled"
        case .stage: return "circle.fill"
        case .stageMono: return "moon.fill"
        case .highKeyMono: return "sun.max.circle.fill"
        }
    }
}
