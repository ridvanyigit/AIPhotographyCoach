import Foundation
import AVFoundation
import SwiftUI
import CoreMedia
import ImageIO
import UIKit // To save image to photo library

@Observable
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    var isAuthorized: Bool = false
    let session = AVCaptureSession()
    var onFrameAvailable: ((CVPixelBuffer) -> Void)?
    var currentBrightness: Double = 0.0
    
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // NEW: High resolution photo output engine
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
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
            
            if self.session.canAddInput(videoDeviceInput) { self.session.addInput(videoDeviceInput) }
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                let videoQueue = DispatchQueue(label: "com.ridvanyigit.VideoQueue")
                self.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            }
            
            // NEW: Add photo output to the session
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                // Enable high resolution capture
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    // YENİ: Deklanşöre basıldığında çağrılacak fonksiyon
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        // Apple'ın kendi donanımsal deklanşör sesi otomatik çalacaktır.
        
        // Cihazın dönüş yönünü fotoğrafa işliyoruz
        if let photoConnection = photoOutput.connection(with: .video) {
            photoConnection.videoOrientation = currentVideoOrientation()
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // Fiziksel cihazın yatay/dikey yönünü kameranın diline çevirir
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeRight: return .landscapeLeft // Sensor logic is inverse
        case .landscapeLeft: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
    
    // YENİ: Fotoğraf işlendiğinde çağrılan Apple Delegate fonksiyonu
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        // Save the image directly to the iOS Photos App
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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