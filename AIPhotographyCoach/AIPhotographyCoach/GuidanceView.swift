import SwiftUI

struct GuidanceView: View {
    let roll: Double
    let state: GuidanceState
    
    var body: some View {
        VStack {
            Spacer()
            
            // Merkezdeki Grafik Alanı
            ZStack {
                // Arka plandaki sabit referans çizgisi (Şeffaf Beyaz)
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 250, height: 2)
                
                // Merkezdeki sabit hedef dairesi
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                // Dönen Aktif Çizgi (Telefonun eğimine göre tersine döner)
                Rectangle()
                    // Hizalıysa yeşil, değilse beyaz renk alır
                    .fill(state == .aligned ? Color.green : Color.white)
                    .frame(width: 200, height: 4)
                    // Harekete çok yumuşak bir animasyon ekliyoruz
                    .animation(.linear(duration: 0.1), value: roll)
                    // Sensörden gelen açının TERSİNE dönerek gerçek ufku gösterir
                    .rotationEffect(.degrees(-roll))
                    // Hizalandığında hafif parlamasını (Glow) sağlıyoruz
                    .shadow(color: state == .aligned ? .green : .clear, radius: 5)
            }
            .frame(height: 200)
            
            Spacer()
            
            // İnsan Dilinde Yönlendirme Metni (Alt kısımda)
            Text(instructionText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(state == .aligned ? .green : .white)
                .padding(.bottom, 60)
                .animation(.easeInOut, value: state)
        }
    }
    
    // State (Durum) bilgisine göre gösterilecek Türkçe metni belirler
    private var instructionText: String {
        switch state {
        case .aligned: return "Harika! 📸"
        case .tiltLeft: return "Sola Eğ ⤺"
        case .tiltRight: return "⤻ Sağa Eğ"
        case .unknown: return "Hesaplanıyor..."
        }
    }
}
