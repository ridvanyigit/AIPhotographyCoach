import SwiftUI

struct GuidanceView: View {
    let roll: Double
    let pitchDeviation: Double
    let rollState: RollState
    let pitchState: PitchState
    let hasFace: Bool
    
    private var displayRoll: Double { return rollState == .aligned ? 0.0 : roll }
    private var displayPitchOffset: CGFloat { return pitchState == .aligned ? 0.0 : CGFloat(pitchDeviation * 2.0) }
    
    // YATAY ÇİZGİLER (ROLL) RENK MANTIĞI:
    private var rollColor: Color {
        if rollState == .aligned { return .green }
        else if abs(roll) <= 8.0 { return .yellow }
        else { return .red }
    }
    
    // DİKEY ÇİZGİ (PITCH) DÜZELTİLMİŞ RENK MANTIĞI:
    private var pitchColor: Color {
        if pitchState == .aligned { return .green }
        else if abs(pitchDeviation) <= 8.0 { return .yellow }
        else { return .red }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Merkez Sabit Referans Noktaları
                HStack(spacing: 60) {
                    Circle().frame(width: 4, height: 4).foregroundColor(.white.opacity(0.4))
                    Circle().frame(width: 4, height: 4).foregroundColor(.white.opacity(0.4))
                }
                
                // Hareketli Sade ve Profesyonel Çizgiler (Amatör oklar tamamen kaldırıldı)
                ZStack {
                    // Dikey Çizgi (Pitch) - Açısına göre Kırmızı / Sarı / Yeşil
                    Rectangle()
                        .frame(width: 2, height: 40)
                        .foregroundColor(pitchColor)
                        .shadow(color: pitchColor.opacity(0.8), radius: 4)
                    
                    // Yatay Çizgiler (Roll) - Açısına göre Kırmızı / Sarı / Yeşil
                    HStack(spacing: 60) {
                        Rectangle()
                            .frame(width: 40, height: 2)
                        Rectangle()
                            .frame(width: 40, height: 2)
                    }
                    .foregroundColor(rollColor)
                    .shadow(color: rollColor.opacity(0.8), radius: 4)
                }
                .offset(y: displayPitchOffset)
                .rotationEffect(.degrees(-displayRoll))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayRoll)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayPitchOffset)
            }
            .frame(height: 100)
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
}