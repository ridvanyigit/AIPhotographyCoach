import SwiftUI

struct GuidanceView: View {
    let tilt: Double
    let state: GuidanceState
    let hasFace: Bool // Yeni: Ekranda insan var mı?
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                Rectangle().fill(Color.white.opacity(0.3)).frame(width: 250, height: 2)
                Circle().stroke(Color.white.opacity(0.5), lineWidth: 2).frame(width: 40, height: 40)
                Rectangle()
                    .fill(state == .aligned ? Color.green : Color.white)
                    .frame(width: 200, height: 4)
                    .animation(.linear(duration: 0.1), value: tilt)
                    .rotationEffect(.degrees(-tilt))
                    .shadow(color: state == .aligned ? .green : .clear, radius: 5)
            }
            .frame(height: 200)
            
            Spacer()
            
            Text(instructionText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(state == .aligned ? .green : .white)
                // Metnin arkasına siyah gölge veriyoruz ki parlak yerlerde de okunsun
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .padding(.bottom, 60)
                .animation(.easeInOut, value: state)
        }
    }
    
    // Yüz algılama durumuna göre dinamik Fotoğrafçılık Koçu tavsiyeleri
    private var instructionText: String {
        switch state {
        case .aligned:
            return hasFace ? "Mükemmel! Portreyi Çek 📸" : "Harika! Çekim Yap 📸"
        case .tiltLeft:
            return "Sola Eğ ⤺"
        case .tiltRight:
            return "⤻ Sağa Eğ"
        case .unknown:
            return "Hesaplanıyor..."
        }
    }
}
