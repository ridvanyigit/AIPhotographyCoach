import SwiftUI

// MARK: - Beauty AI (Güzellik Yapay Zekâsı) Modları
enum BeautyAIMode: String, CaseIterable, Identifiable {
    case naturalGlow = "NATURAL GLOW"
    case smoothSkin = "SMOOTH SKIN"
    case eyeBrighten = "EYE BRIGHTEN"
    case facialTone = "FACIAL TONE"
    case proRetouch = "PRO RETOUCH"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .naturalGlow: return "sparkles"
        case .smoothSkin: return "face.smiling"
        case .eyeBrighten: return "eyes"
        case .facialTone: return "sun.max.fill"
        case .proRetouch: return "wand.and.rays"
        }
    }
}
