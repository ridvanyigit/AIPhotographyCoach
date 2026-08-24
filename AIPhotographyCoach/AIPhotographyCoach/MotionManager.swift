import Foundation
import CoreMotion // Apple'ın sensör framework'ü
import SwiftUI

@Observable
class MotionManager {
    // Apple'ın sensör füzyonunu yapan ana nesnesi
    private let motionManager = CMMotionManager()
    
    // UI'da göstereceğimiz okunabilir değerler
    var pitch: Double = 0.0
    var roll: Double = 0.0
    var isAvailable: Bool = false
    
    func startUpdates() {
        // Cihazda sensör donanımı var mı/müsait mi kontrolü
        guard motionManager.isDeviceMotionAvailable else {
            print("Hata: Cihaz sensörleri kullanılamıyor.")
            isAvailable = false
            return
        }
        
        isAvailable = true
        
        // Saniyede 60 kez veri alacağız (60Hz) - Akıcı ve düşük gecikmeli olması için
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        // Sensör verilerini okumak için arka planda çalışan bir işlem kuyruğu (kasıntı yapmasın diye)
        let queue = OperationQueue()
        
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            // Eğer veri yoksa veya hata varsa çık
            guard let motion = motion, error == nil else { return }
            
            // UI (Arayüz) güncellemeleri mutlaka Main Thread (Ana İşlemci Kuyruğu) üzerinde yapılmalıdır.
            DispatchQueue.main.async {
                // motion.attitude: Sensör füzyonundan çıkmış, filtrelenmiş net yönelim verisidir.
                // Sensör radyan (pi) olarak veri verir, biz bunu dereceye çeviriyoruz ( * 180 / pi)
                self?.pitch = motion.attitude.pitch * (180.0 / .pi)
                self?.roll = motion.attitude.roll * (180.0 / .pi)
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
