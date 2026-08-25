import Foundation
import AVFoundation
import SwiftUI
import CoreMedia // Metadata okumak için gerekli
import ImageIO   // EXIF sözlüğünü okumak için gerekli

@Observable
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var isAuthorized: Bool = false
    let session = AVCaptureSession()
    var onFrameAvailable: ((CVPixelBuffer) -> Void)?
    
    // YENİ: Anlık parlaklık değerini arayüze sunacağımız değişken
    var currentBrightness: Double = 0.0
    
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    
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
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // 1. Görüntü karesini Vision (Yüz bulma) için dışarı at
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            onFrameAvailable?(pixelBuffer)
        }
        
        // 2. YENİ: Donanımdan gelen EXIF Işık Metadata'sını oku
        if let metadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
           let exifData = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let brightness = exifData[kCGImagePropertyExifBrightnessValue as String] as? Double {
            
            // UI Güncellemesi
            DispatchQueue.main.async {
                self.currentBrightness = brightness
            }
        }
    }
}
