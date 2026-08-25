import SwiftUI

struct CompositionGridView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let w = geometry.size.width
                let h = geometry.size.height
                
                // Dikey Çizgiler
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                
                // Yatay Çizgiler
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            // Çizgileri ince ve yarı saydam yapıyoruz ki kamerayı engellemesin
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
        }
        // Tıklamaları engellememesi için (İleride ekrana dokunup odaklamak için gerekecek)
        .allowsHitTesting(false)
    }
}
