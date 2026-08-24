import Foundation

// Uygulamanın bulunabileceği durumlar
enum GuidanceState {
    case unknown
    case tiltLeft
    case tiltRight
    case aligned // Tam hizalı
}

// Saf (Pure) mantık motoru - Sadece veri alır ve karar üretir, UI ile ilgilenmez.
struct GuidanceEngine {
    // Mükemmel hizalama sayılması için kabul edilebilir sapma (Tolerans: 1.5 derece)
    private let alignmentThreshold: Double = 1.5
    
    // Sensör verisini alıp kullanıcıya verilecek komutu belirler
    func evaluate(roll: Double) -> GuidanceState {
        // Eğer cihaz ufuk çizgisine 1.5 dereceden daha yakınsa, mükemmeldir.
        if abs(roll) <= alignmentThreshold {
            return .aligned
        }
        // CoreMotion'da Roll pozitifse cihaz sağa yatıktır -> Kullanıcı sola eğmeli
        else if roll > 0 {
            return .tiltLeft
        }
        // Negatifse cihaz sola yatıktır -> Kullanıcı sağa eğmeli
        else {
            return .tiltRight
        }
    }
}
