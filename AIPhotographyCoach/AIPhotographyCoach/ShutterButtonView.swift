import SwiftUI

struct ShutterButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                // Inner button
                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
            }
        }
        // Button press animation (Makes it feel tactile)
        .buttonStyle(PlainButtonStyle())
        .opacity(0.9)
    }
}
