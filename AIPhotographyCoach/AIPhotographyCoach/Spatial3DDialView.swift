import SwiftUI

struct Spatial3DDialView: View {
    @Binding var selectedMode: Spatial3DMode
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Int = 0
    
    private let itemWidth: CGFloat = 72
    private let containerWidth: CGFloat = 300
    private let feedback = UISelectionFeedbackGenerator()
    
    private var allModes: [Spatial3DMode] { Spatial3DMode.allCases }
    private var selectedIndex: Int { allModes.firstIndex(of: selectedMode) ?? 0 }
    
    private var currentVirtualCenter: CGFloat {
        if isDragging { return CGFloat(dragStartIndex) - (dragOffset / itemWidth) }
        else { return CGFloat(selectedIndex) }
    }
    
    private var liveTitleIndex: Int {
        let idx = Int(round(currentVirtualCenter))
        return min(max(idx, 0), allModes.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(allModes[liveTitleIndex].rawValue)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1.2)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.45))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .animation(.easeInOut(duration: 0.15), value: liveTitleIndex)
            
            ZStack {
                ForEach(0..<allModes.count, id: \.self) { i in
                    let mode = allModes[i]
                    let offsetFromCenter = CGFloat(i) - currentVirtualCenter
                    let isFocused = abs(offsetFromCenter) < 0.5
                    
                    let x = offsetFromCenter * itemWidth
                    let y = pow(abs(offsetFromCenter), 1.7) * 7.5
                    let rotation = Double(offsetFromCenter) * 11.0
                    let scale = isFocused ? 1.25 : max(0.8, 1.0 - abs(offsetFromCenter) * 0.15)
                    let opacity = isFocused ? 1.0 : max(0.35, 0.7 - abs(offsetFromCenter) * 0.3)
                    
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isFocused ? Color.white : Color.white.opacity(0.25),
                                        lineWidth: isFocused ? 1.5 : 1.0
                                    )
                            )
                            .shadow(color: isFocused ? Color.white.opacity(0.4) : Color.clear, radius: 6)
                        
                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: isFocused ? .semibold : .regular))
                            .foregroundColor(isFocused ? .white : .white.opacity(0.65))
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotationEffect(.degrees(rotation))
                    .offset(x: x, y: y)
                }
            }
            .frame(width: containerWidth, height: 60)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .black, location: 0.2), .init(color: .black, location: 0.8), .init(color: .clear, location: 1.0)], startPoint: .leading, endPoint: .trailing))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        if !isDragging { isDragging = true; dragStartIndex = selectedIndex; feedback.prepare() }
                        dragOffset = val.translation.width
                        let currentCandidate = liveTitleIndex
                        if currentCandidate != selectedIndex && allModes[currentCandidate] != selectedMode {
                            feedback.selectionChanged(); selectedMode = allModes[currentCandidate]
                        }
                    }
                    .onEnded { val in
                        let translation = val.translation.width
                        if abs(translation) < 6 {
                            let shift = round((val.location.x - (containerWidth / 2.0)) / itemWidth)
                            let targetIdx = min(max(selectedIndex + Int(shift), 0), allModes.count - 1)
                            feedback.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedMode = allModes[targetIdx]; dragOffset = 0; isDragging = false; dragStartIndex = targetIdx }
                        } else {
                            let finalCenter = CGFloat(dragStartIndex) - ((translation + val.predictedEndTranslation.width * 0.28) / itemWidth)
                            let targetIdx = min(max(Int(round(finalCenter)), 0), allModes.count - 1)
                            feedback.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedMode = allModes[targetIdx]; dragOffset = 0; isDragging = false; dragStartIndex = targetIdx }
                        }
                    }
            )
        }
        .onAppear { feedback.prepare() }
    }
}