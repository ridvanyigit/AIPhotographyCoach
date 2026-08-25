import SwiftUI

struct GuidanceView: View {
    let roll: Double
    let pitchDeviation: Double
    let rollState: RollState
    let pitchState: PitchState
    let hasFace: Bool
    
    private var displayRoll: Double { return rollState == .aligned ? 0.0 : roll }
    private var displayPitchOffset: CGFloat { return pitchState == .aligned ? 0.0 : CGFloat(pitchDeviation * 2.0) }
    
    private var rollColor: Color {
        if rollState == .aligned { return .green }
        else if abs(roll) <= 8.0 { return .yellow }
        else { return .red }
    }
    
    private var pitchColor: Color {
        if pitchState == .aligned { return .green }
        else if abs(pitchDeviation) <= 8.0 { return .yellow }
        else { return .red }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                Rectangle()
                    .frame(width: 2, height: 40)
                    .foregroundColor(pitchColor)
                    .shadow(color: pitchColor.opacity(0.8), radius: 4)
                
                HStack(spacing: 60) {
                    Rectangle().frame(width: 40, height: 2)
                    Rectangle().frame(width: 40, height: 2)
                }
                .foregroundColor(rollColor)
                .shadow(color: rollColor.opacity(0.8), radius: 4)
                .offset(y: displayPitchOffset)
                .rotationEffect(.degrees(-displayRoll))
                // SLOWER ANIMATION: response increased to 0.5 (was 0.2)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayRoll)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayPitchOffset)
            }
            .frame(height: 100)
            
            Spacer()
            
            Text(instructionText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(isFullyAligned ? .green : .white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .padding(.bottom, 140)
                .animation(.easeInOut, value: rollState)
                .animation(.easeInOut, value: pitchState)
        }
        .allowsHitTesting(false)
    }
    
    private var isFullyAligned: Bool { return rollState == .aligned && pitchState == .aligned }
    
    private var instructionText: String {
        if rollState == .tiltLeft { return "Tilt Left ⤺" }
        if rollState == .tiltRight { return "⤻ Tilt Right" }
        if pitchState == .tiltUp { return "Tilt Up ⇡" }
        if pitchState == .tiltDown { return "Tilt Down ⇣" }
        if isFullyAligned { return hasFace ? "Perfect! Take Photo 📸" : "Level! Shoot 📸" }
        return "Calculating..."
    }
}