import Foundation
import CoreMotion

@Observable
class MotionManager {
    private let motionManager = CMMotionManager()

    // Smoothed magnitude of the device's angular velocity (rad/s). This is the ONLY
    // signal we take from the gyroscope, used purely as a hand-shake indicator for the
    // post-capture quality score. It never judges how "level" a selfie is — that
    // judgment comes entirely from the face itself (see SelfieCoach), because a phone
    // can be held upright, tilted, low, high, or even while lying down and still take
    // a perfectly good selfie. Device gravity has nothing to do with a good photo.
    var smoothedAngularVelocity: Double = 0.0
    var isStable: Bool { smoothedAngularVelocity < stabilityThreshold }

    private let motionFilterFactor: Double = 0.2
    private let stabilityThreshold: Double = 0.5
    private var isFirstUpdate = true

    func startUpdates() {
        guard motionManager.isGyroAvailable else { return }
        motionManager.gyroUpdateInterval = 1.0 / 60.0
        let queue = OperationQueue()

        motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
            guard let data = data, error == nil, let self = self else { return }

            let rotation = data.rotationRate
            let angularMagnitude = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)

            DispatchQueue.main.async {
                if self.isFirstUpdate {
                    self.smoothedAngularVelocity = angularMagnitude
                    self.isFirstUpdate = false
                } else {
                    self.smoothedAngularVelocity = (angularMagnitude * self.motionFilterFactor) + (self.smoothedAngularVelocity * (1.0 - self.motionFilterFactor))
                }
            }
        }
    }

    func stopUpdates() {
        motionManager.stopGyroUpdates()
        isFirstUpdate = true
        smoothedAngularVelocity = 0.0
    }
}
