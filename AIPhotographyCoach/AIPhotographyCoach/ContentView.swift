import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. KATMAN: Arka planda tam ekran kamera
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Kamera İzni Bekleniyor")
                        .foregroundColor(.white)
                }
            }
            
            // 2. KATMAN: Yapay Zeka Fotoğraf Koçu Arayüzü (Modern Overlay)
            // Sadece kamera izni varsa ve sensör verisi okunuyorsa göster
            if cameraManager.isAuthorized {
                GuidanceView(roll: motionManager.smoothedRoll, state: motionManager.currentState)
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            motionManager.startUpdates()
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }
}
