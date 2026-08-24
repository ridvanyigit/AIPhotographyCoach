import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager() // Yeni sensör yöneticimiz
    
    var body: some View {
        ZStack {
            // 1. KATMAN: Arka plan (Siyah)
            Color.black.ignoresSafeArea()
            
            // 2. KATMAN: Kamera Görüntüsü
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                // İzin yoksa siyah ekranda uyarı göster (Önceki yazdığımız kod)
                VStack(spacing: 20) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Kamera İzni Bekleniyor")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            // 3. KATMAN: Debug Overlay (Sensör verileri kameranın üzerine yazılacak)
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("🛠 DEBUG OVERLAY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        
                        // %0.2f -> Sadece virgülden sonra 2 basamak göster (örnek: -14.23)
                        Text("Roll (Sağ-Sol): \(String(format: "%.2f°", motionManager.roll))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Pitch (Aşağı-Yukarı): \(String(format: "%.2f°", motionManager.pitch))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6)) // Yarı saydam siyah kutu
                    .cornerRadius(10)
                    .padding(.top, 50)
                    .padding(.leading, 20)
                    
                    Spacer() // Kutuyu ekranın sol üstüne itmek için
                }
                Spacer() // Kutuyu ekranın üst kısmında tutmak için
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            motionManager.startUpdates() // Ekran açılınca sensörleri dinlemeye başla
        }
        .onDisappear {
            motionManager.stopUpdates() // Ekran kapanırsa sensörleri durdur (Batarya tasarrufu)
        }
    }
}

#Preview {
    ContentView()
}
