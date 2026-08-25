import SwiftUI

struct CoachingBadgeView: View {
    let advice: FramingAdvice
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
            Text(messageText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(advice == .perfect ? .black : .white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(advice == .perfect ? Color.yellow : Color.black.opacity(0.6))
        .cornerRadius(30)
        .shadow(color: advice == .perfect ? Color.yellow.opacity(0.5) : Color.black.opacity(0.3), radius: 10, y: 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: advice)
    }
    
    private var messageText: String {
        switch advice {
        case .searching: return "Searching Subject..."
        case .perfect: return "Perfect Framing"
        case .moveCloser: return "Move Closer"
        case .moveBack: return "Move Back"
        case .turnCameraLeft: return "Turn Left"
        case .turnCameraRight: return "Turn Right"
        }
    }
    
    private var iconName: String {
        switch advice {
        case .searching: return "viewfinder"
        case .perfect: return "star.fill"
        case .moveCloser: return "plus.magnifyingglass"
        case .moveBack: return "minus.magnifyingglass"
        case .turnCameraLeft: return "arrow.left"
        case .turnCameraRight: return "arrow.right"
        }
    }
}