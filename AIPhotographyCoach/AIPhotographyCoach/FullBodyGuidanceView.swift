import SwiftUI

// MARK: - Boydan Çekim Canlı Kılavuzları ve Dinamik İskelet Uyumu
struct FullBodyGuidanceView: View {
    let mode: FullBodyMode
    let pitchDeviation: Double
    let hasFace: Bool
    let isGuideEnabled: Bool
    let bodyFitState: BodyFitState
    
    // Low-Angle boy uzatma açısı (-2° ile -8° arası)
    private var isLowAngleOptimal: Bool {
        pitchDeviation >= -8.0 && pitchDeviation <= -2.0
    }
    
    private var angleStatusText: String {
        if bodyFitState == .stepBack {
            return "STEP BACK (FEET/HEAD OUT) 👣"
        } else if bodyFitState == .moveCloser {
            return "MOVE CLOSER (FILL FRAME) 🔍"
        } else if bodyFitState == .perfectFit {
            return "GOLDEN RATIO: PERFECT FIT ✨"
        }
        
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
        if bodyFitState == .perfectFit {
            return .green
        } else if bodyFitState == .stepBack {
            return .orange
        } else if bodyFitState == .moveCloser {
            return .yellow
        }
        
        if mode == .lowAngle {
            return isLowAngleOptimal ? .green : .yellow
        } else {
            return abs(pitchDeviation) <= 4.0 ? .green : .yellow
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isGuideEnabled {
                    // 1. ÜST TEPE HAVA PAYI
                    VStack {
                        HStack {
                            Text("HEADROOM (15%)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.15))
                                .background(.ultraThinMaterial.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        Rectangle()
                            .fill(bodyFitState == .perfectFit ? Color.green : Color.white.opacity(0.65))
                            .frame(height: 1.2)
                            .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.25), value: bodyFitState)
                        
                        Spacer()
                    }
                    .padding(.top, 95)
                    
                    // 2. MODA MODU: 8-BAŞ ORANLARI (SOL KENAR)
                    if mode == .fashion {
                        HStack {
                            VStack(spacing: 26) {
                                ForEach(1..<8) { num in
                                    HStack(spacing: 4) {
                                        Text("\(num)H")
                                            .font(.system(size: 8.5, weight: num == 4 ? .heavy : .bold, design: .monospaced))
                                            .foregroundColor(num == 4 ? .yellow : .white)
                                            .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.15))
                                            .background(.ultraThinMaterial.opacity(0.2))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(num == 4 ? Color.yellow.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 0.5))
                                        
                                        Rectangle()
                                            .fill(num == 4 ? Color.yellow : Color.white.opacity(0.85))
                                            .frame(width: num == 4 ? 10 : 6, height: 1.2)
                                            .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                                    }
                                }
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                        }
                    }
                    
                    // 3. FITNESS MODU: DİKEY SİMETRİ LAZERİ
                    if mode == .fitness {
                        VStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, Color.yellow.opacity(0.85), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 1.5, height: geo.size.height * 0.45)
                                .shadow(color: .black.opacity(0.8), radius: 2)
                        }
                    }
                    
                    // 4. ALT AYAK TABAN ÇİZGİSİ
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(bodyFitState == .perfectFit ? Color.green : Color.white.opacity(0.65))
                            .frame(height: 1.2)
                            .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.25), value: bodyFitState)
                        
                        HStack {
                            Text("FEET BASELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.15))
                                .background(.ultraThinMaterial.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 220)
                }
                
                // 5. GÜVENLİ ALANDA AÇI & YÜKSEKLİK ROZETİ
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 11, weight: .bold))
                        
                        Text(angleStatusText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.15))
                    .background(.ultraThinMaterial.opacity(0.2))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(statusColor.opacity(0.45), lineWidth: 0.8))
                    .shadow(color: statusColor.opacity(0.25), radius: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: angleStatusText)
                    .padding(.top, 140)
                    
                    Spacer()
                }
            }
            .allowsHitTesting(false)
        }
    }
}