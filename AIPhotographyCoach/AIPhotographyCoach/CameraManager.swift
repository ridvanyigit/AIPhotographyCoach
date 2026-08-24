import Foundation
import AVFoundation
import SwiftUI

// NSObject ve AVCaptureVideoDataOutputSampleBufferDelegate ekledik (Kameradan gelen kareleri dinlemek için)
@Observable
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var isAuthorized: Bool = false
    let session = AVCaptureSession()
    
    // Görüntü karelerini (frame) dışarı aktaracağımız özellik
    var onFrameAvailable: ((CVPixelBuffer) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput() // Yeni: Görüntü çıkışı
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
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
            
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
            }
            
            // YENİ: Video çıkışını ayarla ve kareleri al
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                // Kareleri işlemek için ayrı bir thread (kuyruk) oluşturuyoruz (UI donmasın diye)
                let videoQueue = DispatchQueue(label: "com.ridvanyigit.VideoQueue")
                self.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    // YENİ: Kameradan her yeni kare (frame) geldiğinde bu fonksiyon otomatik tetiklenir
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Gelen veriyi işlenebilir piksel formatına (CVPixelBuffer) çevir ve dışarıya fırlat
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameAvailable?(pixelBuffer)
    }
}