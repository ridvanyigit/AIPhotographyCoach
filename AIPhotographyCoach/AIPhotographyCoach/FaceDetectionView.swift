import SwiftUI
import Vision

struct FaceDetectionView: View {
    let landmarks: [FaceLandmarkData]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(landmarks) { face in
                let box = face.boundingBox
                let w = box.width * geometry.size.width
                let h = box.height * geometry.size.height
                let x = box.minX * geometry.size.width
                let y = (1.0 - box.minY - box.height) * geometry.size.height
                
                ZStack {
                    // 1. ZARİF KÖŞE PARANTEZLERİ (Kaba Kutu Yerine)
                    FaceCornerBrackets(width: w, height: h)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: w, height: h)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .position(x: x + w/2, y: y + h/2)
                    
                    // 2. GÖZBEBEĞİ ODAK TAKİP NOKTALARI
                    if let leftPupil = face.leftPupil {
                        let pupilX = x + (leftPupil.x * w)
                        let pupilY = y + ((1.0 - leftPupil.y) * h)
                        
                        Circle()
                            .fill(Color.yellow.opacity(0.9))
                            .frame(width: 4, height: 4)
                            .shadow(color: .yellow.opacity(0.8), radius: 4)
                            .position(x: pupilX, y: pupilY)
                    }
                    
                    if let rightPupil = face.rightPupil {
                        let pupilX = x + (rightPupil.x * w)
                        let pupilY = y + ((1.0 - rightPupil.y) * h)
                        
                        Circle()
                            .fill(Color.yellow.opacity(0.9))
                            .frame(width: 4, height: 4)
                            .shadow(color: .yellow.opacity(0.8), radius: 4)
                            .position(x: pupilX, y: pupilY)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Minimalist Apple Köşe Çizimi
struct FaceCornerBrackets: Shape {
    let width: CGFloat
    let height: CGFloat
    private let len: CGFloat = 10
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Sol Üst
        path.move(to: CGPoint(x: 0, y: len))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: len, y: 0))
        
        // Sağ Üst
        path.move(to: CGPoint(x: width - len, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: len))
        
        // Sol Alt
        path.move(to: CGPoint(x: 0, y: height - len))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: len, y: height))
        
        // Sağ Alt
        path.move(to: CGPoint(x: width - len, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: height - len))
        
        return path
    }
}