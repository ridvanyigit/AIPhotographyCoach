import SwiftUI

struct SelfieGuidanceView: View {
    let state: SelfieState
    let hasFace: Bool
    let rollDegrees: Double         // face's own tilt, not the device's
    let verticalDegrees: Double     // head angle + physical phone height, combined
    let showGrid: Bool

    // Traffic-light scheme: green means "shoot now", yellow means "close, keep
    // adjusting", red means "not yet" — and colorless/gray while we simply haven't
    // found a face to grade yet.
    private var accent: Color {
        guard hasFace else { return .white.opacity(0.35) }
        switch state {
        case .perfect: return Color(red: 0.25, green: 0.9, blue: 0.4)
        case .veryGood, .good: return Color.yellow
        case .fitIntoMask, .eyesClosed: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .searching: return .white.opacity(0.35)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack {
                // Optional rule-of-thirds grid
                if showGrid {
                    Path { p in
                        p.move(to: CGPoint(x: w/3, y: 0)); p.addLine(to: CGPoint(x: w/3, y: h))
                        p.move(to: CGPoint(x: 2*w/3, y: 0)); p.addLine(to: CGPoint(x: 2*w/3, y: h))
                        p.move(to: CGPoint(x: 0, y: h/3)); p.addLine(to: CGPoint(x: w, y: h/3))
                        p.move(to: CGPoint(x: 0, y: 2*h/3)); p.addLine(to: CGPoint(x: w, y: 2*h/3))
                    }
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

                // A nearly-transparent little iPhone, tucked to the side so it never
                // sits over the user's own face, that tilts/shifts to mirror exactly
                // how the real phone needs to move. Its outline is the traffic-light
                // color; everything behind it — the camera feed, the face — stays
                // fully visible through it.
                PhoneOrientationView(
                    hasFace: hasFace,
                    rollDegrees: rollDegrees,
                    verticalDegrees: verticalDegrees,
                    accent: accent,
                    state: state
                )
                .frame(width: 140, height: 220)
                .position(x: w - 75, y: h * 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Phone Orientation Guide
// A mostly-transparent vector iPhone outline — a thin colored frame, a faint
// screen outline, a small notch — that acts as a live mirror of the current pose
// deviation: it rolls left/right to match the face's own tilt, shifts up/down and
// tilts in pseudo-3D to match the combined head-angle + framing signal. Because
// it's a frame rather than a filled shape, whatever is behind it (the live camera
// preview, the user's face) stays clearly visible. Straightening it out is a
// completely literal instruction — "make the little phone stand up straight and
// glow green" — rather than an abstract dot-in-a-ring metaphor. It settles
// dead-center-relative, upright, and green only once every check passes, which is
// the only moment auto-capture is eligible to fire. Directional arrows appear only
// when a specific correction is still needed.
private struct PhoneOrientationView: View {
    let hasFace: Bool
    let rollDegrees: Double
    let verticalDegrees: Double
    let accent: Color
    let state: SelfieState

    private let travel = SelfieCoach.maxTravelDegrees
    private let verticalRange: CGFloat = 28
    private let phoneWidth: CGFloat = 68
    private let phoneHeight: CGFloat = 140
    private let cornerRadius: CGFloat = 18

    private var clampedRoll: Double { min(max(rollDegrees, -travel), travel) }
    private var clampedVertical: Double { min(max(verticalDegrees, -travel), travel) }

    private var phoneRotation: Double { hasFace ? clampedRoll : 0 }
    private var phoneVerticalOffset: CGFloat { hasFace ? -CGFloat(clampedVertical / travel) * verticalRange : 0 }
    private var phoneTilt3D: Double { hasFace ? -clampedVertical * 0.5 : 0 }

    private var needsClockwiseRotation: Bool { hasFace && rollDegrees < -12.0 }
    private var needsCounterClockwiseRotation: Bool { hasFace && rollDegrees > 12.0 }
    private var needsTiltUp: Bool { hasFace && verticalDegrees > 18.0 }
    private var needsTiltDown: Bool { hasFace && verticalDegrees < -18.0 }

    var body: some View {
        ZStack {
            // Soft glow once every check passes — the only moment this stops being
            // a plain outline
            if state == .perfect {
                RoundedRectangle(cornerRadius: cornerRadius + 8, style: .continuous)
                    .fill(accent.opacity(0.35))
                    .frame(width: phoneWidth + 26, height: phoneHeight + 26)
                    .blur(radius: 18)
            }

            // Rotation correction cue (face roll)
            if needsCounterClockwiseRotation {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .offset(x: -(phoneWidth / 2 + 24), y: -10)
                    .transition(.opacity)
            } else if needsClockwiseRotation {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .offset(x: phoneWidth / 2 + 24, y: -10)
                    .transition(.opacity)
            }

            // Tilt/move correction cue (combined head angle + phone height)
            if needsTiltUp {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: -(phoneHeight / 2 + 22))
                    .transition(.opacity)
            } else if needsTiltDown {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: (phoneHeight / 2 + 22))
                    .transition(.opacity)
            }

            // The phone itself — almost entirely see-through, just a colored frame
            ZStack {
                // Barely-there body tint so this still reads as a solid object,
                // without meaningfully hiding anything behind it
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.04))

                // The frame itself carries all the color/status information
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent, lineWidth: state == .perfect ? 3.5 : 2.5)

                // Screen outline only — no fill — so the camera feed shows straight through
                RoundedRectangle(cornerRadius: cornerRadius - 6, style: .continuous)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
                    .padding(6)

                // Dynamic-Island-style notch with a front camera dot — the only
                // near-solid element, and small enough not to block anything meaningful
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 24, height: 7)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 3, height: 3)
                            .offset(x: 6)
                    )
                    .offset(y: -phoneHeight / 2 + 15)

                // Faint decorative side buttons
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(accent.opacity(0.55))
                    .frame(width: 2.5, height: 15)
                    .offset(x: -(phoneWidth / 2 + 1.2), y: -phoneHeight / 2 + 38)
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(accent.opacity(0.55))
                    .frame(width: 2.5, height: 21)
                    .offset(x: -(phoneWidth / 2 + 1.2), y: -phoneHeight / 2 + 62)
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(accent.opacity(0.55))
                    .frame(width: 2.5, height: 27)
                    .offset(x: phoneWidth / 2 + 1.2, y: -phoneHeight / 2 + 46)
            }
            .frame(width: phoneWidth, height: phoneHeight)
            .rotationEffect(.degrees(phoneRotation))
            .rotation3DEffect(.degrees(phoneTilt3D), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
            .offset(y: phoneVerticalOffset)
            .opacity(hasFace ? 1.0 : 0.4)
            .shadow(color: accent.opacity(state == .perfect ? 0.7 : 0), radius: 14)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phoneRotation)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phoneVerticalOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phoneTilt3D)
        .animation(.easeOut(duration: 0.2), value: state)
        .animation(.easeOut(duration: 0.2), value: hasFace)
    }
}
