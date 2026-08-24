import Foundation
import CoreMotion
import SwiftUI
import UIKit // Titreşim (Haptics) için gerekli

@Observable
class MotionManager {
    private let motionManager = CMMotionManager()
    private let guidanceEngine = GuidanceEngine()
    
    // UI'ın okuyacağı son veriler
    var smoothedRoll: Double = 0.0
    var currentState: GuidanceState = .unknown
    
    private let filterFactor: Double = 0.2
    private var isFirstUpdate = true
    
    // Titreşim motoru
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var wasAlignedBefore = false // Sürekli titremeyi engellemek için hafıza
    
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        // Titreşim motorunu uykudan uyandır (Gecikmesiz çalışması için)
        hapticGenerator.prepare()
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        let queue = OperationQueue()
        
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let motion = motion, error == nil, let self = self else { return }
            
            let currentRoll = motion.attitude.roll * (180.0 / .pi)
            
            DispatchQueue.main.async {
                // 1. Filtreleme
                if self.isFirstUpdate {
                    self.smoothedRoll = currentRoll
                    self.isFirstUpdate = false
                } else {
                    self.smoothedRoll = (currentRoll * self.filterFactor) + (self.smoothedRoll * (1.0 - self.filterFactor))
                }
                
                // 2. Karar Motorunu Çalıştır
                let newState = self.guidanceEngine.evaluate(roll: self.smoothedRoll)
                self.currentState = newState
                
                // 3. Titreşim (Haptic) Geri Bildirimi
                if newState == .aligned && !self.wasAlignedBefore {
                    // Cihaz tam düzeltildiği an (sadece ilk girişinde) titret
                    self.hapticGenerator.impactOccurred()
                    self.wasAlignedBefore = true
                } else if newState != .aligned {
                    // Cihaz bozulursa hafızayı sıfırla ki düzeldiğinde tekrar titreyebilsin
                    self.wasAlignedBefore = false
                }
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isFirstUpdate = true
        wasAlignedBefore = false
    }
}
