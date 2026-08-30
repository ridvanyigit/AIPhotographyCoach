import SwiftUI

struct SelfieGuidanceView: View {
    let state: SelfieState
    let hasFace: Bool
    let rollDegrees: Double         // face's own tilt, not the device's
    let verticalDegrees: Double     // head angle + physical phone height, combined
    let lightGuidance: LightingGuidance
    let showGrid: Bool

    private var isPerfect: Bool { state == .perfect }

    private var compassAccent: Color {
        switch state {
        case .perfect: return .yellow
        case .veryGood: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .good: return .white
        case .eyesClosed: return Color(red: 1.0, green: 0.45, blue: 0.4)
        default: return hasFace ? .white.opacity(0.85) : .white.opacity(0.3)
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

                // Small, elegant orientation compass, driven entirely by how the FACE
                // looks in frame — never by the phone's physical tilt relative to
                // gravity. Three concentric rings show Good / Very Good / Perfect;
                // auto-capture only ever fires once the dot reaches the innermost one.
                OrientationCompassView(
                    hasFace: hasFace,
                    rollDegrees: rollDegrees,
                    verticalDegrees: verticalDegrees,
                    accent: compassAccent,
                    state: state
                )
                .frame(width: 108, height: 108)
                .position(x: w / 2, y: h * 0.42)

                // Light-source satellite compass. Only revealed once the pose itself
                // is dead-center — no point asking someone to fix their lighting while
                // they're still framing their face. Auto-capture needs both perfect.
                if state == .perfect {
                    LightCompassView(guidance: lightGuidance)
                        .position(x: w / 2, y: h * 0.42 + 78)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Orientation Compass
// A compact spirit-level style indicator, but leveled against the subject's face
// rather than the horizon: a dot drifts inside three concentric rings based on how
// tilted/off-center the face appears. Crossing the outer ring means "good enough to
// shoot manually", the middle ring means "very good", and only the tiny center zone
// means "perfect" — which is the only time auto-capture fires. Directional cues
// (rotate clockwise/counterclockwise, tilt up/down) only appear when a correction is
// genuinely needed, and everything stays neutral/dim until a face is actually found.
private struct OrientationCompassView: View {
    let hasFace: Bool
    let rollDegrees: Double
    let verticalDegrees: Double
    let accent: Color
    let state: SelfieState

    private let ringDiameter: CGFloat = 108
    private let dotDiameter: CGFloat = 12
    private var veryGoodDiameter: CGFloat { ringDiameter * CGFloat(SelfieCoach.veryGoodRatio) }
    private var perfectDiameter: CGFloat { max(ringDiameter * CGFloat(SelfieCoach.perfectRatio), 16) }

    private var dotOffset: CGSize {
        guard hasFace else { return .zero }
        let radius = (ringDiameter - dotDiameter) / 2
        let travel = SelfieCoach.maxTravelDegrees
        let x = CGFloat(min(max(rollDegrees / travel, -1.0), 1.0)) * radius
        let y = CGFloat(min(max(-verticalDegrees / travel, -1.0), 1.0)) * radius
        return CGSize(width: x, height: y)
    }

    private var needsClockwiseRotation: Bool { hasFace && rollDegrees < -12.0 }
    private var needsCounterClockwiseRotation: Bool { hasFace && rollDegrees > 12.0 }
    private var needsTiltUp: Bool { hasFace && verticalDegrees > 18.0 }
    private var needsTiltDown: Bool { hasFace && verticalDegrees < -18.0 }

    var body: some View {
        ZStack {
            // Outer ring — "Good" boundary
            Circle()
                .stroke(Color.white.opacity(hasFace ? 0.35 : 0.16), lineWidth: 1.2)

            // Middle ring — "Very Good" boundary
            Circle()
                .stroke(accent.opacity(hasFace ? 0.4 : 0.12), lineWidth: 1.2)
                .frame(width: veryGoodDiameter, height: veryGoodDiameter)

            // Innermost ring — "Perfect" zone, the only place auto-capture fires
            Circle()
                .stroke(accent.opacity(state == .perfect ? 0.95 : (hasFace ? 0.5 : 0.14)), lineWidth: 1.4)
                .frame(width: perfectDiameter, height: perfectDiameter)

            // Minimal N/E/S/W reference ticks
            ForEach([0, 90, 180, 270], id: \.self) { degree in
                Rectangle()
                    .fill(Color.white.opacity(hasFace ? 0.22 : 0.08))
                    .frame(width: 1, height: 5)
                    .offset(y: -(ringDiameter / 2) + 2)
                    .rotationEffect(.degrees(Double(degree)))
            }

            // Rotation correction cue (face roll)
            if needsCounterClockwiseRotation {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: -(ringDiameter / 2) - 15)
                    .transition(.opacity)
            } else if needsClockwiseRotation {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: -(ringDiameter / 2) - 15)
                    .transition(.opacity)
            }

            // Tilt/move correction cue (combined head angle + phone height)
            if needsTiltUp {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: (ringDiameter / 2) + 13)
                    .transition(.opacity)
            } else if needsTiltDown {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                    .offset(y: (ringDiameter / 2) + 13)
                    .transition(.opacity)
            }

            // Soft glow only in the true perfect state
            if state == .perfect {
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 8)
                    .frame(width: perfectDiameter, height: perfectDiameter)
                    .blur(radius: 6)
            }

            // The moving level dot — only shown once a face is actually found, so an
            // empty frame (sky, ceiling, wall) can never look "ready".
            if hasFace {
                Circle()
                    .fill(accent)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .shadow(color: accent.opacity(state == .perfect ? 0.8 : 0.0), radius: state == .perfect ? 6 : 0)
                    .offset(dotOffset)
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .animation(.easeOut(duration: 0.15), value: rollDegrees)
        .animation(.easeOut(duration: 0.15), value: verticalDegrees)
        .animation(.easeOut(duration: 0.2), value: state)
        .animation(.easeOut(duration: 0.2), value: hasFace)
    }
}

// MARK: - Light Source Compass
// A smaller satellite compass using the exact same visual language as the pose
// compass above it, but grading the DIRECTION AND QUALITY OF LIGHT instead of head
// position. A sun icon drifts toward center as the light becomes even, bright
// enough, and soft enough — reaching the innermost ring is what "Light: Perfect"
// means, and is required (together with the pose) for auto-capture to fire.
private struct LightCompassView: View {
    let guidance: LightingGuidance

    private let ringDiameter: CGFloat = 64
    private let dotDiameter: CGFloat = 16
    private var veryGoodDiameter: CGFloat { ringDiameter * CGFloat(SelfieCoach.veryGoodRatio) }
    private var perfectDiameter: CGFloat { max(ringDiameter * CGFloat(SelfieCoach.perfectRatio), 14) }

    private var accent: Color {
        switch guidance.state {
        case .perfect: return .yellow
        case .veryGood: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .good: return .white
        case .needsWork, .unknown: return .white.opacity(0.5)
        }
    }

    private var dotOffset: CGSize {
        let radius = (ringDiameter - dotDiameter) / 2
        let x = CGFloat(min(max(guidance.horizontalBias, -1.0), 1.0)) * radius
        let y = CGFloat(min(max(-guidance.verticalBias, -1.0), 1.0)) * radius
        return CGSize(width: x, height: y)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)

            Circle()
                .stroke(accent.opacity(0.4), lineWidth: 1)
                .frame(width: veryGoodDiameter, height: veryGoodDiameter)

            Circle()
                .stroke(accent.opacity(guidance.state == .perfect ? 0.95 : 0.4), lineWidth: 1.2)
                .frame(width: perfectDiameter, height: perfectDiameter)

            if guidance.state == .perfect {
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 6)
                    .frame(width: perfectDiameter, height: perfectDiameter)
                    .blur(radius: 5)
            }

            Image(systemName: "sun.max.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accent)
                .shadow(color: accent.opacity(guidance.state == .perfect ? 0.8 : 0.0), radius: guidance.state == .perfect ? 5 : 0)
                .offset(dotOffset)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .animation(.easeOut(duration: 0.2), value: guidance.horizontalBias)
        .animation(.easeOut(duration: 0.2), value: guidance.verticalBias)
        .animation(.easeOut(duration: 0.2), value: guidance.state)
    }
}
