import SwiftUI

// MARK: - Apple Portre Işığı Seçim Çarkı (1:1 Canlı Direksiyon Fiziği)
struct PortraitLightingDialView: View {
    @Binding var selectedMode: PortraitLightingMode
    
    // Sürükleme ve Takip State'leri
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Int = 0
    
    private let itemWidth: CGFloat = 72 // Modlar arası kavis mesafesi
    private let containerWidth: CGFloat = 300 // Dokunma alanı genişliği
    private let feedback = UISelectionFeedbackGenerator()
    
    private var allModes: [PortraitLightingMode] {
        PortraitLightingMode.allCases
    }
    
    private var selectedIndex: Int {
        allModes.firstIndex(of: selectedMode) ?? 0
    }
    
    // Parmağın hareketine göre anlık merkez konumu (0.0 ms gecikme)
    private var currentVirtualCenter: CGFloat {
        if isDragging {
            return CGFloat(dragStartIndex) - (dragOffset / itemWidth)
        } else {
            return CGFloat(selectedIndex)
        }
    }
    
    // Üstteki başlığın parmak hareket ederken anında güncellenmesi
    private var liveTitleIndex: Int {
        let idx = Int(round(currentVirtualCenter))
        return min(max(idx, 0), allModes.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 1. CANLI GÜNCELLENEN BAŞLIK
            Text(allModes[liveTitleIndex].rawValue)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.8), radius: 3)
                .animation(.easeInOut(duration: 0.1), value: liveTitleIndex)
            
            // 2. KAVİSLİ DİREKSİYON TEKERLEĞİ (1:1 PARMAK TAKİBİ)
            ZStack {
                ForEach(0..<allModes.count, id: \.self) { i in
                    let mode = allModes[i]
                    let offsetFromCenter = CGFloat(i) - currentVirtualCenter
                    let isFocused = abs(offsetFromCenter) < 0.5
                    
                    // Direksiyon Kavis Geometrisi:
                    let x = offsetFromCenter * itemWidth
                    let y = pow(abs(offsetFromCenter), 1.7) * 7.5 // Dairesel yay derinliği
                    let rotation = Double(offsetFromCenter) * 11.0 // Açısal dönme eğimi
                    let scale = isFocused ? 1.18 : max(0.72, 1.0 - abs(offsetFromCenter) * 0.14)
                    let opacity = isFocused ? 1.0 : max(0.25, 0.85 - abs(offsetFromCenter) * 0.28)
                    
                    // İkon Çizimi (Buton yerine saf View — Dokunma çakışmasını tamamen çözer)
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isFocused ? Color.yellow : Color.white.opacity(0.3),
                                        lineWidth: isFocused ? 2.0 : 1.0
                                    )
                            )
                            .shadow(color: isFocused ? Color.yellow.opacity(0.6) : Color.clear, radius: 8)
                        
                        Image(systemName: mode.iconName)
                            .font(.system(size: 19, weight: isFocused ? .bold : .regular))
                            .foregroundColor(isFocused ? .yellow : .white.opacity(0.75))
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotationEffect(.degrees(rotation))
                    .offset(x: x, y: y)
                }
            }
            .frame(width: containerWidth, height: 60)
            // Kenarlarda eriyerek kaybolma efekti (Apple Native Mask)
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
            .contentShape(Rectangle()) // Tüm alanda parmak hareketini yakalar
            // KUSURSUZ 1:1 CANLI TAKİP GESTURE MOTORU
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        if !isDragging {
                            isDragging = true
                            dragStartIndex = selectedIndex
                            feedback.prepare()
                        }
                        
                        // Parmağın canlı hareketi (Gecikmesiz 1:1 akış)
                        dragOffset = val.translation.width
                        
                        // Her yeni modun üzerinden geçildiğinde canlı tıkırtı ve ışık güncellemesi
                        let currentCandidate = liveTitleIndex
                        if currentCandidate != selectedIndex && allModes[currentCandidate] != selectedMode {
                            feedback.selectionChanged()
                            selectedMode = allModes[currentCandidate]
                        }
                    }
                    .onEnded { val in
                        let translation = val.translation.width
                        
                        // 1. TIKLAMA / DOKUNMA DURUMU (Eğer parmak kaydırılmadan tıklandıysa)
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
                        } 
                        // 2. KAYDIRMA VE MOMENTUM DURUMU (Fırlatma Hızı Hesabı)
                        else {
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