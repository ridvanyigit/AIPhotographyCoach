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
    
    // NEW: Callback to send the captured image back to the UI for animation
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    var currentBrightness: Double = 0.0
    var currentPosition: AVCaptureDevice.Position = .back
    
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: isAuthorized = true; setupCamera()
        case .notDetermined: requestPermission()
        default: isAuthorized = false
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted { self?.setupCamera() }
            }
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1920x1080
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
            
            if self.session.canAddInput(videoDeviceInput) { self.session.addInput(videoDeviceInput) }
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                let videoQueue = DispatchQueue(label: "com.ridvanyigit.VideoQueue")
                self.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            self.session.removeInput(currentInput)
            
            self.currentPosition = self.currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(newInput) { self.session.addInput(newInput) } 
            else { self.session.addInput(currentInput) }
            
            self.session.commitConfiguration()
        }
    }
    
    func focusAndExpose(at point: CGPoint, screenWidth: CGFloat, screenHeight: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition) else { return }
            
            let focusX = point.y / screenHeight
            let focusY = 1.0 - (point.x / screenWidth)
            let sensorPoint = CGPoint(x: focusX, y: focusY)
            
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = sensorPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = sensorPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus error: \(error)")
            }
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if let photoConnection = photoOutput.connection(with: .video) {
            photoConnection.videoOrientation = currentVideoOrientation()
            if currentPosition == .front && photoConnection.isVideoMirroringSupported {
                photoConnection.isVideoMirrored = true
            }
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
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
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        
        // Save to iOS Album
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Send image back to UI for the slick animation on the Main Thread
        DispatchQueue.main.async {
            self.onPhotoCaptured?(image)
        }
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            onFrameAvailable?(pixelBuffer)
        }
        if let metadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
           let exifData = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let brightness = exifData[kCGImagePropertyExifBrightnessValue as String] as? Double {
            DispatchQueue.main.async { self.currentBrightness = brightness }
        }
    }
}