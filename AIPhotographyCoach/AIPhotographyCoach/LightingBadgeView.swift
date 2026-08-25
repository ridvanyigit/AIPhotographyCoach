import SwiftUI

struct LightingBadgeView: View {
    let condition: LightingCondition
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(20)
        .shadow(color: backgroundColor.opacity(0.5), radius: 5, y: 3)
        .animation(.easeInOut, value: condition)
    }
    
    private var message: String {
        switch condition {
        case .calculating: return "Measuring Light..."
        case .tooDark: return "Too Dark"
        case .tooBright: return "Backlight / Too Bright"
        case .optimal: return "Good Light"
        }
    }
    
    private var iconName: String {
        switch condition {
        case .calculating: return "sun.min.fill"
        case .tooDark: return "moon.fill"
        case .tooBright: return "sun.max.fill"
        case .optimal: return "sun.and.horizon.fill"
        }
    }
    
    private var backgroundColor: Color {
        switch condition {
        case .calculating: return Color.black.opacity(0.5)
        case .tooDark: return Color.blue.opacity(0.8)
        case .tooBright: return Color.orange.opacity(0.9)
        case .optimal: return Color.green.opacity(0.8)
        }
    }
}