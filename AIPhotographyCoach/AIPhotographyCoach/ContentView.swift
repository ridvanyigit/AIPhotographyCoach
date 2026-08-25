import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager()
    
    private let lightingCoach = LightingCoach()
    @State private var voiceCoach = VoiceCoachManager()
    
    // NEW: Flash effect state
    @State private var flashOpacity: Double = 0.0
    
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
                
                // TOP UI PANEL
                VStack(spacing: 12) {
                    CoachingBadgeView(advice: visionManager.framingAdvice)
                        .padding(.top, 20)
                    LightingBadgeView(condition: lightingCoach.evaluate(brightness: cameraManager.currentBrightness))
                    Spacer()
                }
                
                // CROSSHAIR / LEVELER
                GuidanceView(
                    tilt: motionManager.smoothedTilt,
                    state: motionManager.currentState,
                    hasFace: !visionManager.detectedFaces.isEmpty
                )
                
                // BOTTOM UI PANEL (SHUTTER BUTTON)
                VStack {
                    Spacer()
                    ShutterButtonView(action: takePhoto)
                        .padding(.bottom, 40)
                }
                
                // NEW: SCREEN FLASH EFFECT
                // Flashes white when a photo is taken
                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
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
        .onChange(of: visionManager.framingAdvice) { _, newAdvice in
            voiceCoach.provideGuidance(framing: newAdvice, tilt: motionManager.currentState)
        }
        .onChange(of: motionManager.currentState) { _, newTilt in
            voiceCoach.provideGuidance(framing: visionManager.framingAdvice, tilt: newTilt)
        }
    }
    
    // MARK: - Actions
    
    private func takePhoto() {
        // Trigger haptic feedback for the button press
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Trigger screen flash animation
        withAnimation(.linear(duration: 0.1)) {
            flashOpacity = 1.0
        }
        
        // Fade out the flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                flashOpacity = 0.0
            }
        }
        
        // Tell the camera manager to actually capture the photo
        cameraManager.capturePhoto()
    }
}