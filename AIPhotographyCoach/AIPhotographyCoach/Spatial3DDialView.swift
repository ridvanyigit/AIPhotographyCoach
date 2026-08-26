import SwiftUI

// MARK: - Apple Spatial 3D Seçim Çarkı (1:1 Direksiyon Kavis Fiziği)
struct Spatial3DDialView: View {
    @Binding var selectedMode: Spatial3DMode
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Int = 0
    
    private let itemWidth: CGFloat = 72
    private let containerWidth: CGFloat = 300
    private let feedback = UISelectionFeedbackGenerator()
    
    private var allModes: [Spatial3DMode] {
        Spatial3DMode.allCases
    }
    
    private var selectedIndex: Int {
        allModes.firstIndex(of: selectedMode) ?? 0
    }
    
    private var currentVirtualCenter: CGFloat {
        if isDragging {
            return CGFloat(dragStartIndex) - (dragOffset / itemWidth)
        } else {
            return CGFloat(selectedIndex)
        }
    }
    
    private var liveTitleIndex: Int {
        let idx = Int(round(currentVirtualCenter))
        return min(max(idx, 0), allModes.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 1. CANLI GÜNCELLENEN 3D BAŞLIK
            Text(allModes[liveTitleIndex].rawValue)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.cyan) // 3D uzamsal his için camgöbeği/cyan tonu
                .shadow(color: .cyan.opacity(0.8), radius: 4)
                .animation(.easeInOut(duration: 0.15), value: liveTitleIndex)
            
            // 2. KAVİSLİ 3D DİREKSİYON TEKERLEĞİ
            ZStack {
                ForEach(0..<allModes.count, id: \.self) { i in
                    let mode = allModes[i]
                    let offsetFromCenter = CGFloat(i) - currentVirtualCenter
                    let isFocused = abs(offsetFromCenter) < 0.5
                    
                    let x = offsetFromCenter * itemWidth
                    let y = pow(abs(offsetFromCenter), 1.75) * 6.5
                    let rotation = Double(offsetFromCenter) * 10.0
                    let scale = isFocused ? 1.18 : max(0.72, 1.0 - abs(offsetFromCenter) * 0.14)
                    let opacity = isFocused ? 1.0 : max(0.25, 0.85 - abs(offsetFromCenter) * 0.28)
                    
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isFocused ? Color.cyan : Color.white.opacity(0.25),
                                        lineWidth: isFocused ? 2.0 : 1.0
                                    )
                            )
                            .shadow(color: isFocused ? Color.cyan.opacity(0.6) : Color.clear, radius: 8)
                        
                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: isFocused ? .bold : .regular))
                            .foregroundColor(isFocused ? .cyan : .white.opacity(0.75))
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotationEffect(.degrees(rotation))
                    .offset(x: x, y: y)
                }
            }
            .frame(width: containerWidth, height: 56)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        if !isDragging {
                            isDragging = true
                            dragStartIndex = selectedIndex
                            feedback.prepare()
                        }
                        
                        dragOffset = val.translation.width
                        
                        let currentCandidate = liveTitleIndex
                        if currentCandidate != selectedIndex && allModes[currentCandidate] != selectedMode {
                            feedback.selectionChanged()
                            selectedMode = allModes[currentCandidate]
                        }
                    }
                    .onEnded { val in
                        let translation = val.translation.width
                        
                        if abs(translation) < 6 {
                            let tapPositionX = val.location.x
                            let shift = round((tapPositionX - (containerWidth / 2.0)) / itemWidth)
                            let targetIdx = min(max(selectedIndex + Int(shift), 0), allModes.count - 1)
                            
                            feedback.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedMode = allModes[targetIdx]
                                dragOffset = 0
                                isDragging = false
                                dragStartIndex = targetIdx
                            }
                        } else {
                            let velocity = val.predictedEndTranslation.width * 0.28
                            let totalMove = translation + velocity
                            let finalCenter = CGFloat(dragStartIndex) - (totalMove / itemWidth)
                            let targetIdx = min(max(Int(round(finalCenter)), 0), allModes.count - 1)
                            
                            feedback.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedMode = allModes[targetIdx]
                                dragOffset = 0
                                isDragging = false
                                dragStartIndex = targetIdx
                            }
                        }
                    }
            )
        }
        .onAppear {
            feedback.prepare()
        }
    }
}
