import Foundation

// MARK: - Boydan Çekim İskelet ve Altın Oran Uyum Durumları
enum BodyFitState: String, CaseIterable {
    case searching = "Searching Subject..."
    case moveCloser = "Move Closer 🔍"
    case stepBack = "Step Back 👣"
    case perfectFit = "Perfect Fit ✨"
}
