import SwiftUI

struct CoachingBadgeView: View {
    let framingAdvice: FramingAdvice
    let poseAdvice: PoseAdvice
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
            Text(messageText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(isPerfect ? .black : .white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isPerfect ? Color.yellow : Color.black.opacity(0.6))
        .cornerRadius(30)
        .shadow(color: isPerfect ? Color.yellow.opacity(0.5) : Color.black.opacity(0.3), radius: 10, y: 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: framingAdvice)
    }
    
    private var isPerfect: Bool {
        return framingAdvice == .perfect && (poseAdvice == .good || poseAdvice == .none)
    }
    
    // Priorities: 1. Framing, 2. Pose
    private var messageText: String {
        if framingAdvice != .perfect {
            switch framingAdvice {
            case .searching: return "Searching Subject..."
            case .moveCloser: return "Move Closer"
            case .moveBack: return "Move Back"
            case .turnCameraLeft: return "Turn Left"
            case .turnCameraRight: return "Turn Right"
            default: return ""
            }
        } else {
            switch poseAdvice {
            case .faceCamera: return "Look at Camera"
            case .levelShoulders: return "Level Shoulders"
            default: return "Perfect Composition"
            }
        }
    }
    
    private var iconName: String {
        if framingAdvice != .perfect {
            switch framingAdvice {
            case .searching: return "viewfinder"
            case .moveCloser: return "plus.magnifyingglass"
            case .moveBack: return "minus.magnifyingglass"
            case .turnCameraLeft: return "arrow.left"
            case .turnCameraRight: return "arrow.right"
            default: return ""
            }
        } else {
            switch poseAdvice {
            case .faceCamera: return "eyes"
            case .levelShoulders: return "figure.stand"
            default: return "star.fill"
            }
        }
    }
}