import Foundation
import AVFoundation
import SwiftUI
import CoreMedia
import ImageIO
import UIKit

@Observable
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    var isAuthorized: Bool = false
    let session = AVCaptureSession()

    var onFrameAvailable: ((CVPixelBuffer) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?

    // Raw EXIF brightness value (BV) from the live video stream, smoothed to avoid flicker
    var currentBrightness: Double = 0.0
    // Simple three-way classification derived from currentBrightness, consumed directly
    // by SelfieCoach so exposure becomes part of the live coaching loop.
    var lightingCondition: LightingCondition = .good

    // Defaults to the front camera since this app is selfie-first
    var currentPosition: AVCaptureDevice.Position = .front

    private let sessionQueue = DispatchQueue(label: "com.aiphotocoach.CameraSessionQueue", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    // Brightness smoothing + classification thresholds (heuristic EXIF BV ranges).
    // Lighting is advisory only now (shown as a tip, never blocks capture), so these
    // lean toward not crying wolf rather than being scientifically precise.
    private let brightnessFilterFactor: Double = 0.25
    private let darkThreshold: Double = -2.5
    private let brightThreshold: Double = 10.0

    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()

            // We want the highest usable resolution for a selfie
            self.session.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
            }

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                // Analyze video frames on a background queue to keep the UI smooth
                let videoQueue = DispatchQueue(label: "com.aiphotocoach.VideoQueue", qos: .userInitiated)
                self.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true // Drop stale frames to save battery
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }

            // Tune autofocus/exposure specifically for close-range front-camera use
            do {
                try videoDevice.lockForConfiguration()
                if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                    videoDevice.focusMode = .continuousAutoFocus
                }
                if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                    videoDevice.exposureMode = .continuousAutoExposure
                }
                videoDevice.unlockForConfiguration()
            } catch {
                print("Camera config error: \(error)")
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality // Best available quality

        if let photoConnection = photoOutput.connection(with: .video) {
            photoConnection.videoOrientation = currentVideoOrientation()
            // Mirror the output for the front camera to match what the user saw in preview
            // (standard Apple Camera app behavior)
            if currentPosition == .front && photoConnection.isVideoMirroringSupported {
                photoConnection.isVideoMirrored = true
            }
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Camera Switching
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()

            // Remove the current input
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            self.session.removeInput(currentInput)

            // Flip position
            self.currentPosition = self.currentPosition == .back ? .front : .back

            // Bring in the new device
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                // Restore the previous camera if the switch failed
                self.session.addInput(currentInput)
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
            } else {
                self.session.addInput(currentInput)
            }

            // Re-apply focus/exposure settings to the newly active camera
            do {
                try newDevice.lockForConfiguration()
                if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                    newDevice.focusMode = .continuousAutoFocus
                }
                if newDevice.isExposureModeSupported(.continuousAutoExposure) {
                    newDevice.exposureMode = .continuousAutoExposure
                }
                newDevice.unlockForConfiguration()
            } catch {
                print("Camera switch config error: \(error)")
            }

            self.session.commitConfiguration()
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }

        // Hand the raw image back to the UI layer. Saving to the photo library happens
        // after ContentView applies the selected filter/aspect crop, so we never save
        // an unprocessed frame the user didn't actually choose.
        DispatchQueue.main.async { self.onPhotoCaptured?(image) }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            onFrameAvailable?(pixelBuffer)
        }

        // Read the live exposure metadata (EXIF) to drive the lighting coach
        if let metadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
           let exifData = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let brightness = exifData[kCGImagePropertyExifBrightnessValue as String] as? Double {
            DispatchQueue.main.async {
                self.updateLighting(with: brightness)
            }
        }
    }

    private func updateLighting(with rawBrightness: Double) {
        // Low-pass filter so a single noisy frame doesn't flip the coaching state
        currentBrightness = (rawBrightness * brightnessFilterFactor) + (currentBrightness * (1.0 - brightnessFilterFactor))

        if currentBrightness < darkThreshold {
            lightingCondition = .tooDark
        } else if currentBrightness > brightThreshold {
            lightingCondition = .tooBright
        } else {
            lightingCondition = .good
        }
    }
}
