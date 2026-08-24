import SwiftUI

struct ContentView: View {
    // CameraManager'ı View'a bağlıyoruz
    @State private var cameraManager = CameraManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: cameraManager.isAuthorized ? "camera.fill" : "camera.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(cameraManager.isAuthorized ? .green : .red)
            
            Text(cameraManager.isAuthorized ? "Kamera İzni Alındı ✅" : "Kamera İzni Bekleniyor ❌")
                .font(.headline)
            
            if !cameraManager.isAuthorized {
                Text("Lütfen uygulamanın çalışması için kamera izni verin.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        // Ekran ilk açıldığında izni kontrol et
        .onAppear {
            cameraManager.checkPermission()
        }
    }
}

#Preview {
    ContentView()
}