import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // YENİ: Fotoğrafçılık Izgarası
                CompositionGridView()
                    .ignoresSafeArea()
                
                FaceDetectionView(faces: visionManager.detectedFaces)
                    .ignoresSafeArea()
                
                // Ufuk asistanına ekrandaki yüz durumunu (hasFace) aktarıyoruz
                GuidanceView(
                    tilt: motionManager.smoothedTilt,
                    state: motionManager.currentState,
                    hasFace: !visionManager.detectedFaces.isEmpty
                )
            } else {
                VStack {
                    Image(systemName: "video.slash.fill").font(.system(size: 60)).foregroundColor(.red)
                    Text("Kamera İzni Bekleniyor").foregroundColor(.white)
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            motionManager.startUpdates()
            cameraManager.onFrameAvailable = { pixelBuffer in
                visionManager.processFrame(pixelBuffer)
            }
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }
}
