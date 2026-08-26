import SwiftUI

// MARK: - Panoramik Çekim Modları
enum PanoMode: String, CaseIterable, Identifiable {
    case wideGroup = "WIDE GROUP"
    case ultraWide = "ULTRA WIDE 180°"
    case vertorama = "VERTORAMA"
    case miniPano = "MINI PANO 60°"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .wideGroup: return "person.3.sequence.fill"
        case .ultraWide: return "pano.fill"
        case .vertorama: return "arrow.up.and.down.square.fill"
        case .miniPano: return "rectangle.portrait.and.arrow.right"
        }
    }
}

// MARK: - Panorama Tarama Yönü
enum PanoDirection: String, CaseIterable {
    case leftToRight = "Left ➔ Right"
    case rightToLeft = "Right ➔ Left"
    
    var iconName: String {
        switch self {
        case .leftToRight: return "arrow.right"
        case .rightToLeft: return "arrow.left"
        }
    }
}
