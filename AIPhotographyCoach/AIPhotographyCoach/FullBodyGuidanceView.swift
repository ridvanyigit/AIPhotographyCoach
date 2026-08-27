import SwiftUI

struct FullBodyGuidanceView: View {
    let mode: FullBodyMode
    let pitchDeviation: Double
    let hasFace: Bool
    let isGuideEnabled: Bool
    let bodyFitState: BodyFitState // YENİ: Canlı İskelet Uyumu
    
    private var isLowAngleOptimal: Bool {
        pitchDeviation >= -8.0 && pitchDeviation <= -2.0
    }
    
    // Canlı Yapay Zekâ Yönlendirme Metni
    private var guidanceText: String {
        switch bodyFitState {
        case .searching:
            return "SEARCHING FULL BODY..."
        case .stepBack:
            return "STEP BACK (FEET / HEAD CUT OFF) 👣"
        case .moveCloser:
            return "MOVE CLOSER (FILL THE FRAME) 🔍"
        case .adjustTilt:
            if mode == .lowAngle {
                return isLowAngleOptimal ? "PERFECT ANGLE (-5°) ✨" : (pitchDeviation > -2.0 ? "TILT UP SLIGHTLY ⇡" : "TILT DOWN ⇣")
            } else {
                return abs(pitchDeviation) <= 4.0 ? "LEVEL CAMERA ✨" : "ALIGN CAMERA TO WAIST ⬇️"
            }
        case .perfectFit:
            return "GOLDEN RATIO: PERFECT FIT ✨"
        }
    }
    
    // Çizgi ve Rozet Renkleri
    private var activeLineColor: Color {
        switch bodyFitState {
        case .perfectFit: return .green
        case .stepBack: return .orange
        case .moveCloser: return .yellow
        default: return .white.opacity(0.65)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isGuideEnabled {
                    // 1. DİNAMİK TEPE HAVA PAYI ÇİZGİSİ
                    VStack {
                        HStack {
                            Text("HEADROOM (15%)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(bodyFitState == .perfectFit ? .green : .white)
                                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.15))
                                .background(.ultraThinMaterial.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(bodyFitState == .perfectFit ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 0.5))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        Rectangle()
                            .fill(activeLineColor)
                            .frame(height: bodyFitState == .perfectFit ? 2 : 1)
                            .shadow(color: bodyFitState == .perfectFit ? Color.green.opacity(0.8) : Color.black.opacity(0.8), radius: bodyFitState == .perfectFit ? 4 : 2, y: 1)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.25), value: bodyFitState)
                        
                        Spacer()
                    }
                    .padding(.top, 95)
                    
                    // 2. MODA MODU: 8-BAŞ ORANLARI
                    if mode == .fashion {
                        HStack {
                            VStack(spacing: 26) {
                                ForEach(1..<8) { num in
                                    HStack(spacing: 4) {
                                        Text("\(num)H")
                                            .font(.system(size: 8.5, weight: num == 4 ? .heavy : .bold, design: .monospaced))
                                            .foregroundColor(bodyFitState == .perfectFit ? .green : (num == 4 ? .yellow : .white))
                                            .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.15))
                                            .background(.ultraThinMaterial.opacity(0.2))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(num == 4 ? Color.yellow.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 0.5))
                                        
                                        Rectangle()
                                            .fill(bodyFitState == .perfectFit ? Color.green : (num == 4 ? Color.yellow : Color.white.opacity(0.85)))
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
                                .fill(LinearGradient(colors: [.clear, (bodyFitState == .perfectFit ? Color.green : Color.yellow).opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
                                .frame(width: 1.5, height: geo.size.height * 0.45)
                                .shadow(color: .black.opacity(0.8), radius: 2)
                        }
                    }
                    
                    // 4. DİNAMİK AYAK TABAN ÇİZGİSİ
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(activeLineColor)
                            .frame(height: bodyFitState == .perfectFit ? 2.5 : 1.2)
                            .shadow(color: bodyFitState == .perfectFit ? Color.green.opacity(0.8) : Color.black.opacity(0.8), radius: bodyFitState == .perfectFit ? 4 : 2, y: 1)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.25), value: bodyFitState)
                        
                        HStack {
                            Text("FEET BASELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(bodyFitState == .perfectFit ? .green : .white)
                                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.15))
                                .background(.ultraThinMaterial.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(bodyFitState == .perfectFit ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 0.5))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 220)
                }
                
                // 5. GÜVENLİ ALANDA CANLI DURUM VE YÖNLENDİRME ROZETİ
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: bodyFitState == .perfectFit ? "star.fill" : mode.iconName)
                            .font(.system(size: 11, weight: .bold))
                        
                        Text(guidanceText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.25))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .foregroundColor(bodyFitState == .perfectFit ? .green : (bodyFitState == .stepBack ? .orange : .yellow))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke((bodyFitState == .perfectFit ? Color.green : Color.yellow).opacity(0.5), lineWidth: 0.8))
                    .shadow(color: (bodyFitState == .perfectFit ? Color.green : Color.yellow).opacity(0.3), radius: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: guidanceText)
                    .padding(.top, 140)
                    
                    Spacer()
                }
            }
            .allowsHitTesting(false)
        }
    }
}