import SwiftUI

// MARK: - Boydan Çekim İçin Canlı Altın Oran, Tepe/Ayak Kılavuzu ve Açı Koçu
struct FullBodyGuidanceView: View {
    let mode: FullBodyMode
    let pitchDeviation: Double
    let hasFace: Bool
    let isGuideEnabled: Bool
    
    private let violetColor = Color(red: 0.78, green: 0.42, blue: 1.0)
    
    // Low-Angle boy uzatma açısı (-2° ile -8° arası)
    private var isLowAngleOptimal: Bool {
        pitchDeviation >= -8.0 && pitchDeviation <= -2.0
    }
    
    private var angleStatusText: String {
        switch mode {
        case .lowAngle:
            return isLowAngleOptimal ? "IDEAL LOW ANGLE (-5°) ✨" : (pitchDeviation > -2.0 ? "TILT UP SLIGHTLY ⇡ (FOR TALLER LOOK)" : "TILT DOWN SLIGHTLY ⇣")
        case .fashion:
            return abs(pitchDeviation) <= 4.0 ? "PERFECT OUTFIT ALIGNMENT ✨" : (pitchDeviation > 0 ? "LOWER TO WAIST LEVEL ⬇️" : "LEVEL CAMERA ⇡")
        case .modelPose:
            return "MODEL S-CURVE ACTIVE ✨"
        case .fitness:
            return abs(pitchDeviation) <= 3.0 ? "PERFECT SYMMETRY ✨" : "ALIGN BODY CENTER ⚖️"
        case .casualStreet:
            return "NATURAL STREET FLOW ✨"
        }
    }
    
    private var statusColor: Color {
        if mode == .lowAngle {
            return isLowAngleOptimal ? .green : violetColor
        } else {
            return abs(pitchDeviation) <= 4.0 ? .green : violetColor
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isGuideEnabled {
                    // 1. ÜST TEPE HAVA PAYI ÇİZGİSİ (HEADROOM GUIDE - %15)
                    VStack {
                        HStack {
                            Text("HEADROOM (15%)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(violetColor.opacity(0.85))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        Rectangle()
                            .fill(violetColor.opacity(0.35))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    .padding(.top, 95)
                    
                    // 2. MODA MODU: 8-BAŞ ORAN KILAVUZU
                    if mode == .fashion {
                        HStack {
                            Spacer()
                            VStack(spacing: 28) {
                                ForEach(1..<8) { num in
                                    HStack(spacing: 4) {
                                        Text("\(num)H")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(violetColor.opacity(0.6))
                                        Rectangle()
                                            .fill(violetColor.opacity(0.4))
                                            .frame(width: 8, height: 1)
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    
                    // 3. FITNESS MODU: DİKEY SİMETRİ LAZER ÇİZGİSİ
                    if mode == .fitness {
                        VStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, violetColor.opacity(0.6), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 1.5, height: geo.size.height * 0.45)
                        }
                    }
                    
                    // 4. ALT AYAK TABAN ÇİZGİSİ (FOOTLINE GROUNDING)
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(violetColor.opacity(0.45))
                            .frame(height: 1.5)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Spacer()
                            Text("FEET BASELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(violetColor.opacity(0.85))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 220)
                }
                
                // 5. GÜVENLİ ALANDA AÇI & YÜKSEKLİK ROZETİ (ÖRTÜŞME TAMAMEN ÇÖZÜLDÜ - ÜST ORTAYA TAŞINDI)
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 11, weight: .bold))
                        
                        Text(angleStatusText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(statusColor.opacity(0.85))
                    .background(.ultraThinMaterial)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: statusColor.opacity(0.5), radius: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: angleStatusText)
                    .padding(.top, 140) // Kılavuzun hemen altında temiz güvenli alan
                    
                    Spacer()
                }
            }
            .allowsHitTesting(false)
        }
    }
}