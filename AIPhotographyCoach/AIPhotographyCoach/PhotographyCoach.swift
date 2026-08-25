import Foundation
import CoreGraphics

// Koçun verebileceği tavsiyeler
enum FramingAdvice {
    case searching
    case perfect
    case moveCloser
    case moveBack
    case turnCameraLeft
    case turnCameraRight
}

struct PhotographyCoach {
    // Vision framework'ü ekranı 0.0 ile 1.0 arasında oranlar.
    // 0.0 sol köşe, 1.0 sağ köşe, 0.5 tam merkezdir.
    
    func evaluateFraming(faces: [CGRect]) -> FramingAdvice {
        // İlk bulunan yüzü (ana objeyi) hedef alıyoruz
        guard let primaryFace = faces.first else { return .searching }
        
        let centerX = primaryFace.midX
        let faceWidth = primaryFace.width
        
        // 1. UZAKLIK KONTROLÜ (Yüzün ekrandaki genişliğine göre)
        if faceWidth < 0.08 {
            return .moveCloser // Yüz çok küçük, %8'den az yer kaplıyor
        }
        if faceWidth > 0.45 {
            return .moveBack // Yüz çok büyük, %45'ten fazla yer kaplıyor
        }
        
        // 2. MERKEZLEME KONTROLÜ (Üçler Kuralının orta sütununa oturtma)
        // Eğer yüz 0.35'ten küçükse soldadır (Kamerayı sola çevirirsek obje ortaya gelir)
        if centerX < 0.35 {
            return .turnCameraLeft
        }
        // Eğer yüz 0.65'ten büyükse sağdadır
        if centerX > 0.65 {
            return .turnCameraRight
        }
        
        // Hem uzaklık hem konum iyiyse mükemmel kadraj!
        return .perfect
    }
}
