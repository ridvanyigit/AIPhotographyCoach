import SwiftUI

// MARK: - Selfie Lighting Mode
// A front-camera-only take on Apple's Portrait Lighting picker: instead of relying
// on depth data (which the front TrueDepth camera doesn't expose through the
// standard photo pipeline the same way Portrait mode does), each mode drives the
// screen itself as a soft, colored fill light around the subject.
enum SelfieLightingMode: String, CaseIterable, Identifiable {
    case natural
    case soft
    case studio
    case warm
    case cool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .soft: return "Soft"
        case .studio: return "Studio"
        case .warm: return "Warm"
        case .cool: return "Cool"
        }
    }

    var icon: String {
        switch self {
        case .natural: return "sun.min"
        case .soft: return "circle.lefthalf.filled"
        case .studio: return "lightbulb.max.fill"
        case .warm: return "flame.fill"
        case .cool: return "snowflake"
        }
    }

    var isActive: Bool { self != .natural }

    // Screen-border glow color used as a continuous, soft fill light
    var glowColor: Color {
        switch self {
        case .natural: return .clear
        case .soft: return .white
        case .studio: return .white
        case .warm: return Color(red: 1.0, green: 0.78, blue: 0.5)
        case .cool: return Color(red: 0.65, green: 0.82, blue: 1.0)
        }
    }

    var glowOpacity: Double {
        switch self {
        case .natural: return 0.0
        case .soft: return 0.5
        case .studio: return 0.9
        case .warm: return 0.75
        case .cool: return 0.75
        }
    }

    var glowLineWidth: CGFloat {
        switch self {
        case .natural: return 0
        case .soft: return 22
        case .studio: return 40
        case .warm, .cool: return 32
        }
    }
}

// MARK: - Selfie Filter
// Creative color grading, applied live (approximated with SwiftUI color modifiers on
// the preview) and precisely (via Core Image) on the final captured photo.
enum SelfieFilter: String, CaseIterable, Identifiable {
    case none
    case vivid
    case warm
    case cool
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Original"
        case .vivid: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .mono: return "Mono"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .vivid: return "sparkles"
        case .warm: return "thermometer.sun"
        case .cool: return "thermometer.snowflake"
        case .mono: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Selfie Aspect Ratio
// Controls the final crop of the captured photo. `ratio` is width / height;
// `nil` keeps the camera's native capture ratio untouched.
enum SelfieAspectRatio: String, CaseIterable, Identifiable {
    case full
    case square
    case portrait
    case story

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full"
        case .square: return "1:1"
        case .portrait: return "4:5"
        case .story: return "9:16"
        }
    }

    var icon: String {
        switch self {
        case .full: return "rectangle.portrait"
        case .square: return "square"
        case .portrait: return "rectangle.ratio.4.to.5"
        case .story: return "rectangle.portrait.fill"
        }
    }

    var ratio: CGFloat? {
        switch self {
        case .full: return nil
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        }
    }
}

// MARK: - Flash Mode
// The front camera has no physical flash, so "flash" here means briefly maxing out
// screen brightness right before the shutter fires — the same trick Apple's own
// Camera app uses for front-facing flash.
enum FlashMode: String, CaseIterable, Identifiable {
    case off
    case on
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
        case .auto: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a"
        }
    }
}
