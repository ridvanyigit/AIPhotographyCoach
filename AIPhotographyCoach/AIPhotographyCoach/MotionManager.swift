import Foundation
import CoreMotion
import SwiftUI
import UIKit

@Observable
class MotionManager {
    private let motionManager = CMMotionManager()
    private let guidanceEngine = GuidanceEngine()
    
    var smoothedRoll: Double = 0.0
    var smoothedPitchDeviation: Double = 0.0
    
    var currentRollState: RollState = .unknown
    var currentPitchState: PitchState = .unknown
    
    private let filterFactor: Double = 0.08
    private var isFirstUpdate = true
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var wasFullyAlignedBefore = false
    
    init() {
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
            
            let rawRoll = motion.attitude.roll * (180.0 / .pi)
            let rawPitch = motion.attitude.pitch * (180.0 / .pi)
            
            var currentRoll: Double = 0.0
            var currentPitch: Double = 0.0
            
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                currentRoll = rawPitch
                currentPitch = -rawRoll
            case .landscapeRight:
                currentRoll = -rawPitch
                currentPitch = rawRoll
            case .portraitUpsideDown:
                currentRoll = -rawRoll
                currentPitch = -rawPitch
            default:
                currentRoll = rawRoll
                currentPitch = rawPitch
            }
            
            // PITCH TARGET LOGIC: Snap to the nearest 90 degrees (0 for flat, 90 for upright)
            let targetPitch = round(currentPitch / 90.0) * 90.0
            let pitchDeviation = currentPitch - targetPitch
            
            DispatchQueue.main.async {
                if self.isFirstUpdate {
                    self.smoothedRoll = currentRoll
                    self.smoothedPitchDeviation = pitchDeviation
                    self.isFirstUpdate = false
                } else {
                    self.smoothedRoll = (currentRoll * self.filterFactor) + (self.smoothedRoll * (1.0 - self.filterFactor))
                    self.smoothedPitchDeviation = (pitchDeviation * self.filterFactor) + (self.smoothedPitchDeviation * (1.0 - self.filterFactor))
                }
                
                let result = self.guidanceEngine.evaluate(roll: self.smoothedRoll, pitchDeviation: self.smoothedPitchDeviation)
                self.currentRollState = result.roll
                self.currentPitchState = result.pitch
                
                let isFullyAligned = (result.roll == .aligned && result.pitch == .aligned)
                
                if isFullyAligned && !self.wasFullyAlignedBefore {
                    self.hapticGenerator.impactOccurred()
                    self.wasFullyAlignedBefore = true
                } else if !isFullyAligned {
                    self.wasFullyAlignedBefore = false
                }
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isFirstUpdate = true
        wasFullyAlignedBefore = false
    }
}