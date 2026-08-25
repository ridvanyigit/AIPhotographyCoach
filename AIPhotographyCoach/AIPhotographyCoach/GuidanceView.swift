import SwiftUI

struct GuidanceView: View {
    let tilt: Double
    let state: GuidanceState
    let hasFace: Bool
    
    // Magnetic Snap Logic
    private var displayTilt: Double {
        return state == .aligned ? 0.0 : tilt
    }
    
    // 3-Color Traffic Light System (Green, Yellow, Red)
    private var dynamicColor: Color {
        if state == .aligned {
            return .green
        } else if abs(tilt) <= 8.0 {
            // Not perfect, but acceptable/close (Yellow)
            return .yellow
        } else {
            // Bad angle (Red)
            return .red
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // MINIMALIST CROSSHAIR
            ZStack {
                // Fixed transparent center cross
                Group {
                    Rectangle().frame(width: 40, height: 1)
                    Rectangle().frame(width: 1, height: 40)
                }
                .foregroundColor(Color.white.opacity(0.3))
                
                // Rotating arms with dynamic color
                HStack(spacing: 60) {
                    Rectangle().frame(width: 40, height: 2)
                    Rectangle().frame(width: 40, height: 2)
                }
                .foregroundColor(dynamicColor)
                .shadow(color: dynamicColor.opacity(0.8), radius: 4)
                .rotationEffect(.degrees(-displayTilt))
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: displayTilt)
            }
            .frame(height: 100)
            
            Spacer()
            
            Text(instructionText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(dynamicColor)
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