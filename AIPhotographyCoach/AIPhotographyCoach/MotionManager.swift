import Foundation
import CoreMotion
import SwiftUI
import UIKit

@Observable
class MotionManager {
    private let motionManager = CMMotionManager()
    private let guidanceEngine = GuidanceEngine()
    
    var smoothedTilt: Double = 0.0 // Artık roll yerine genel "Tilt (Eğim)" diyoruz
    var currentState: GuidanceState = .unknown
    
    private let filterFactor: Double = 0.2
    private var isFirstUpdate = true
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var wasAlignedBefore = false
    
    init() {
        // Cihazın döndüğünü anlamak için bildirimleri açıyoruz
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        hapticGenerator.prepare()
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        let queue = OperationQueue()
        
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let motion = motion, error == nil, let self = self else { return }
            
            // Sensör verilerini dereceye çevir
            let rollDeg = motion.attitude.roll * (180.0 / .pi)
            let pitchDeg = motion.attitude.pitch * (180.0 / .pi)
            
            // EKRANIN YÖNÜNE GÖRE İLGİLİ EKSENİ (TILT) SEÇİYORUZ
            var currentTilt: Double = 0.0
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                currentTilt = pitchDeg
            case .landscapeRight:
                currentTilt = -pitchDeg
            case .portraitUpsideDown:
                currentTilt = -rollDeg
            default: // Portrait
                currentTilt = rollDeg
            }
            
            DispatchQueue.main.async {
                if self.isFirstUpdate {
                    self.smoothedTilt = currentTilt
                    self.isFirstUpdate = false
                } else {
                    self.smoothedTilt = (currentTilt * self.filterFactor) + (self.smoothedTilt * (1.0 - self.filterFactor))
                }
                
                let newState = self.guidanceEngine.evaluate(roll: self.smoothedTilt)
                self.currentState = newState
                
                if newState == .aligned && !self.wasAlignedBefore {
                    self.hapticGenerator.impactOccurred()
                    self.wasAlignedBefore = true
                } else if newState != .aligned {
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