import SwiftUI

struct GuidanceView: View {
    let tilt: Double
    let state: GuidanceState
    let hasFace: Bool
    
    // Magnetic Snap: Eğer cihaz hizalıysa çizgiyi sıfır derecede kilitler
    private var displayTilt: Double {
        return state == .aligned ? 0.0 : tilt
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // MINIMALIST CROSSHAIR (Şeffaf Koordinat Sistemi)
            ZStack {
                // Merkezdeki sabit şeffaf artı işareti (Cross)
                Group {
                    Rectangle().frame(width: 40, height: 1)
                    Rectangle().frame(width: 1, height: 40)
                }
                .foregroundColor(Color.white.opacity(0.3))
                
                // Dönen dinamik terazi çizgileri (Sağ ve sol kollar)
                HStack(spacing: 60) {
                    Rectangle().frame(width: 40, height: 2)
                    Rectangle().frame(width: 40, height: 2)
                }
                .foregroundColor(state == .aligned ? .green : .white.opacity(0.8))
                .shadow(color: state == .aligned ? .green : .clear, radius: 4)
                // Manyetik dönüş uyguluyoruz
                .rotationEffect(.degrees(-displayTilt))
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: displayTilt)
            }
            .frame(height: 100)
            
            Spacer()
            
            // ENGLISH INSTRUCTIONS
            Text(instructionText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(state == .aligned ? .green : .white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .padding(.bottom, 60)
                .animation(.easeInOut, value: state)
        }
        .allowsHitTesting(false)
    }
    
    private var instructionText: String {
        switch state {
        case .aligned:
            return hasFace ? "Perfect! Take Photo 📸" : "Level! Shoot 📸"
        case .tiltLeft:
            return "Tilt Left ⤺"
        case .tiltRight:
            return "⤻ Tilt Right"
        case .unknown:
            return "Calculating..."
        }
    }
}