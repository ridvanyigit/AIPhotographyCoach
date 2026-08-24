import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Arka planı her zaman siyah yapalım ki modern görünsün
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                // İzin varsa kamerayı tüm ekranda göster
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                // İzin yoksa uyarıyı göster
                VStack(spacing: 20) {
                    Image(systemName: "video.slash.fill") // Hatalı ikonu düzelttik
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Kamera İzni Bekleniyor")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Lütfen ayarlardan uygulamanın kameraya erişmesine izin verin.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
    }
}

#Preview {
    ContentView()
}
