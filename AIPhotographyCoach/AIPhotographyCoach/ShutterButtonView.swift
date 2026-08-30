import SwiftUI

struct ShutterButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(TactileShutterStyle())
        .opacity(0.9)
    }
}

// A real press-down animation, matched to the standard iOS Camera app shutter feel:
// the inner circle shrinks slightly while pressed and springs back on release.
private struct TactileShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
