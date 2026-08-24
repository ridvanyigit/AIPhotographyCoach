import Foundation
import AVFoundation // Kamera ve medya donanımları için Apple framework'ü
import SwiftUI

// @Observable makrosu, bu sınıfın içindeki veriler değiştiğinde UI'ın otomatik güncellenmesini sağlar. (iOS 17+ özelliği)
@Observable
class CameraManager {
    // İznin durumunu arayüze bildireceğimiz değişken
    var isAuthorized: Bool = false
    
    // İzin durumunu kontrol eden fonksiyon
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // Zaten izin verilmiş
            isAuthorized = true
        case .notDetermined:
            // Kullanıcıya henüz sorulmamış, izin isteyelim
            requestPermission()
        case .denied, .restricted:
            // Kullanıcı reddetmiş veya ebeveyn kontrolü kısıtlamış
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    // İlk defa izin isteyen özel (private) fonksiyon
    private func requestPermission() {
        // İzin işlemi asenkrondur (kullanıcının ne zaman 'Evet' diyeceğini bilemeyiz)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            // UI güncellemeleri her zaman Main Thread (Ana İşlemci Kuyruğu) üzerinde yapılmalıdır.
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }
}
