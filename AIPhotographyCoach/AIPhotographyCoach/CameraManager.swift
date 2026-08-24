import Foundation
import AVFoundation
import SwiftUI

@Observable
class CameraManager {
    var isAuthorized: Bool = false
    
    // Kameranın ana yöneticisi
    let session = AVCaptureSession()
    
    // Kamerayı başlatırken ana ekranı (UI) dondurmamak için arka plan kuyruğu oluşturuyoruz
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    
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
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }
    
    // Kamerayı yapılandıran ana fonksiyon
    private func setupCamera() {
        // İşlemleri arka plan kuyruğuna atıyoruz
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. İşlem oturumunu başlatmaya hazırlan
            self.session.beginConfiguration()
            
            // Yüksek çözünürlük yerine performansı (ve düşük gecikmeyi) artırmak için 1080p seçiyoruz
            self.session.sessionPreset = .hd1920x1080
            
            // 2. Fiziksel cihazı bul (Arka geniş açı kamera)
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Hata: Arka kamera bulunamadı veya erişilemedi.")
                return
            }
            
            // 3. Cihazı oturuma bağla
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
            }
            
            // 4. Konfigürasyonu bitir
            self.session.commitConfiguration()
            
            // 5. Kamerayı çalıştır
            self.session.startRunning()
        }
    }
}