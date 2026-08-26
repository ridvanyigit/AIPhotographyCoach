import SwiftUI

// MARK: - Spatial 3D (Uzamsal Derinlik) Modları
enum Spatial3DMode: String, CaseIterable, Identifiable {
    case immersive = "IMMERSIVE 3D"
    case focusedDepth = "FOCUSED DEPTH"
    case holoMesh = "HOLO MESH"
    case anaglyph = "ANAGLYPH 3D"
    case visionPro = "VISION PRO"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .immersive: return "cube.transparent"
        case .focusedDepth: return "square.3.layers.3d"
        case .holoMesh: return "point.3.filled.connected.trianglepath.dotted"
        case .anaglyph: return "eyeglasses"
        case .visionPro: return "visionpro"
        }
    }
}
