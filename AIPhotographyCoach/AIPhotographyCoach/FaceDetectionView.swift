import SwiftUI
import Vision

struct FaceDetectionView: View {
    let faces: [CGRect] // Vision'dan gelen oransal (0.0 - 1.0) yüz koordinatları
    
    var body: some View {
        GeometryReader { geometry in
            // Ekranda kaç yüz varsa hepsi için bir kutu çiz
            ForEach(0..<faces.count, id: \.self) { index in
                let boundingBox = faces[index]
                
                // Oransal koordinatları, cihazın gerçek ekran boyutuna (pixels/points) çevir
                let width = boundingBox.width * geometry.size.width
                let height = boundingBox.height * geometry.size.height
                let x = boundingBox.minX * geometry.size.width
                
                // Vision'da (0,0) sol-alt köşedir. SwiftUI'da ise sol-üst köşedir. Y eksenini ters çeviriyoruz:
                let y = (1 - boundingBox.minY - boundingBox.height) * geometry.size.height
                
                // Yüzü içine alacak sarı kutu
                Rectangle()
                    .path(in: CGRect(x: x, y: y, width: width, height: height))
                    .stroke(Color.yellow, lineWidth: 2)
                    // Kutunun köşelerine şık bir parıltı (AI hissiyatı) ekleyelim
                    .shadow(color: .yellow, radius: 4)
            }
        }
    }
}
