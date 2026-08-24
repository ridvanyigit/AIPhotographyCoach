import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager() // Yeni: Görüntü işleme yöneticimiz
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                // 1. KATMAN: Gerçek zamanlı kamera
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // 2. KATMAN: Yüz algılama kutuları (Kameranın hemen üstünde)
                FaceDetectionView(faces: visionManager.detectedFaces)
                    .ignoresSafeArea()
                
                // 3. KATMAN: Oryantasyon (Eğim) asistanımız (En üstte)
                GuidanceView(roll: motionManager.smoothedRoll, state: motionManager.currentState)
            } else {
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60)).foregroundColor(.red)
                    Text("Kamera İzni Bekleniyor").foregroundColor(.white)
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            motionManager.startUpdates()
            
            // KAMERADAN GELEN HER BİR KAREYİ, VISION (YAPAY ZEKA) MOTORUNA GÖNDER!
            cameraManager.onFrameAvailable = { pixelBuffer in
                visionManager.processFrame(pixelBuffer)
            }
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }
}
