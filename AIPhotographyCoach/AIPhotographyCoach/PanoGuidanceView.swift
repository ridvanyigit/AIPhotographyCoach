import SwiftUI

// MARK: - Apple Panorama Kılavuz Hattı ve Canlı Hız Takipçisi
struct PanoGuidanceView: View {
    let mode: PanoMode
    @Binding var direction: PanoDirection
    let pitchDeviation: Double
    let angularVelocity: Double
    
    // Hız Eşiği (1.3 rad/s üzeri çok hızlıdır)
    private var isSpeedTooFast: Bool {
        angularVelocity > 1.3
    }
    
    // Canlı Durum ve Hız Bildirimi
    private var speedWarningText: String {
        if isSpeedTooFast {
            return "SLOW DOWN 🐢"
        } else if abs(pitchDeviation) > 4.5 {
            return pitchDeviation > 0 ? "TILT DOWN ⇣" : "TILT UP ⇡"
        } else {
            return direction == .leftToRight ? "PAN RIGHT ➔" : "PAN LEFT ⬅️"
        }
    }
    
    private var statusColor: Color {
        if isSpeedTooFast { return .red }
        if abs(pitchDeviation) > 4.5 { return .orange }
        return .yellow
    }
    
    var body: some View {
        if mode == .vertorama {
            // DİKEY PANORAMA (VERTORAMA) KILAVUZU
            VStack(spacing: 8) {
                Text(speedWarningText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                
                ZStack(alignment: .bottom) {
                    // Dikey Lazer Çizgisi
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.2), Color.yellow.opacity(0.8), Color.yellow.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 200)
                    
                    // Yukarı Doğru Kılavuz Oku
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(statusColor, lineWidth: 1.8))
                            .shadow(color: statusColor.opacity(0.5), radius: 6)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(statusColor)
                    }
                }
            }
            .frame(height: 260)
        } else {
            // YATAY PANORAMA (WIDE GROUP / ULTRA WIDE) KILAVUZU
            VStack(spacing: 8) {
                // Canlı Hız & Denge Durum Rozeti
                Text(speedWarningText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .shadow(color: statusColor.opacity(0.5), radius: 6)
                    .animation(.easeInOut(duration: 0.2), value: speedWarningText)
                
                ZStack(alignment: direction == .leftToRight ? .leading : .trailing) {
                    // 1. Sarı Kılavuz Lazer Hattı
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.15), Color.yellow.opacity(0.85), Color.yellow.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 280, height: 2)
                        .shadow(color: Color.yellow.opacity(0.6), radius: 4)
                    
                    // 2. Kayan Yön Oku (Tıklayınca Yön Değişir: Sol ➔ Sağ / Sağ ➔ Sol)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            direction = (direction == .leftToRight ? .rightToLeft : .leftToRight)
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 48, height: 38)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(statusColor, lineWidth: 1.8)
                                )
                                .shadow(color: statusColor.opacity(0.6), radius: 6)
                            
                            Image(systemName: direction == .leftToRight ? "arrow.right" : "arrow.left")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(statusColor)
                        }
                    }
                    // Kullanıcı yukarı/aşağı eğildiğinde ok hattan saparak uyarır
                    .offset(y: CGFloat(pitchDeviation * 1.6))
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: pitchDeviation)
                }
                .frame(width: 280, height: 50)
            }
        }
    }
}
