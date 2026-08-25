import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager()
    
    private let lightingCoach = LightingCoach()
    @State private var voiceCoach = VoiceCoachManager() // YENİ: Ses Asistanı
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
                CompositionGridView()
                    .ignoresSafeArea()
                
                FaceDetectionView(faces: visionManager.detectedFaces)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    CoachingBadgeView(advice: visionManager.framingAdvice)
                        .padding(.top, 20)
                    
                    LightingBadgeView(condition: lightingCoach.evaluate(brightness: cameraManager.currentBrightness))
                    
                    Spacer()
                }
                
                GuidanceView(
                    tilt: motionManager.smoothedTilt,
                    state: motionManager.currentState,
                    hasFace: !visionManager.detectedFaces.isEmpty
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "video.slash.fill").font(.system(size: 60)).foregroundColor(.red)
                    Text("Camera Access Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Please enable camera access in settings to use the AI Photography Coach.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
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
        // YENİ: Ekrandaki kompozisyon veya eğim değiştiğinde Sesli Asistanı uyar
        .onChange(of: visionManager.framingAdvice) { _, newAdvice in
            voiceCoach.provideGuidance(framing: newAdvice, tilt: motionManager.currentState)
        }
        .onChange(of: motionManager.currentState) { _, newTilt in
            voiceCoach.provideGuidance(framing: visionManager.framingAdvice, tilt: newTilt)
        }
    }
}