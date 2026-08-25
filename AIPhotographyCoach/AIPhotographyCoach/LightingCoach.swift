import Foundation

enum LightingCondition {
    case calculating
    case tooDark
    case tooBright
    case optimal
}

// Tamamen matematiksel ışık karar motorumuz
struct LightingCoach {
    func evaluate(brightness: Double) -> LightingCondition {
        // Brightness değeri 0 ise henüz kamera ölçüm yapmamış demektir
        if brightness == 0.0 {
            return .calculating
        }
        
        if brightness < -1.0 {
            return .tooDark // Çok Karanlık
        } else if brightness > 6.0 {
            return .tooBright // Güneşe karşı veya aşırı parlak
        } else {
            return .optimal // Işık harika
        }
    }
}
