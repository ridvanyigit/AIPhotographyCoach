import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager()
    private let lightingCoach = LightingCoach()
    @State private var voiceCoach = VoiceCoachManager()
    
    @State private var flashOpacity: Double = 0.0
    @State private var isAutoCaptureEnabled: Bool = false
    @State private var lastCaptureTime: Date = Date.distantPast
    
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusRect: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            handleTapToFocus(location: location, size: geometry.size)
                        }
                    
                    CompositionGridView()
                        .ignoresSafeArea()
                    
                    FaceDetectionView(faces: visionManager.detectedFaces)
                        .ignoresSafeArea()
                    
                    if showFocusRect, let point = focusPoint {
                        Rectangle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(width: 60, height: 60)
                            .shadow(color: .yellow.opacity(0.5), radius: 4)
                            .position(point)
                            .scaleEffect(showFocusRect ? 1.0 : 1.2)
                            .animation(.spring(), value: showFocusRect)
                    }
                    
                    VStack(spacing: 12) {
                        CoachingBadgeView(advice: visionManager.framingAdvice)
                            .padding(.top, 20)
                        LightingBadgeView(condition: lightingCoach.evaluate(brightness: cameraManager.currentBrightness))
                        Spacer()
                    }
                    
                    // UPDATED: Passing both Roll and Pitch deviations and states
                    GuidanceView(
                        roll: motionManager.smoothedRoll,
                        pitchDeviation: motionManager.smoothedPitchDeviation,
                        rollState: motionManager.currentRollState,
                        pitchState: motionManager.currentPitchState,
                        hasFace: !visionManager.detectedFaces.isEmpty
                    )
                    
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                withAnimation { isAutoCaptureEnabled.toggle() }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: isAutoCaptureEnabled ? "a.circle.fill" : "a.circle")
                                        .font(.system(size: 28))
                                    Text("Auto")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(isAutoCaptureEnabled ? .yellow : .white)
                                .shadow(color: .black.opacity(0.8), radius: 2)
                            }
                            .padding(.leading, 40)
                            
                            Spacer()
                            ShutterButtonView(action: takePhoto)
                            Spacer()
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                cameraManager.switchCamera()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 40)
                        }
                        .padding(.bottom, 40)
                    }
                    
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
                voiceCoach.provideGuidance(framing: newAdvice, roll: motionManager.currentRollState, pitch: motionManager.currentPitchState)
                checkAutoCapture()
            }
            .onChange(of: motionManager.currentRollState) { _, _ in
                voiceCoach.provideGuidance(framing: visionManager.framingAdvice, roll: motionManager.currentRollState, pitch: motionManager.currentPitchState)
                checkAutoCapture()
            }
            .onChange(of: motionManager.currentPitchState) { _, _ in
                voiceCoach.provideGuidance(framing: visionManager.framingAdvice, roll: motionManager.currentRollState, pitch: motionManager.currentPitchState)
                checkAutoCapture()
            }
        }
    }
    
    // MARK: - Actions
    
    private func takePhoto() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 }
        }
        cameraManager.capturePhoto()
    }
    
    private func checkAutoCapture() {
        guard isAutoCaptureEnabled else { return }
        
        // STRICT RULE: Both Roll AND Pitch must be perfect!
        let isTiltPerfect = (motionManager.currentRollState == .aligned && motionManager.currentPitchState == .aligned)
        let isFramingPerfect = visionManager.detectedFaces.isEmpty ? true : (visionManager.framingAdvice == .perfect)
        
        if isTiltPerfect && isFramingPerfect {
            let now = Date()
            if now.timeIntervalSince(lastCaptureTime) > 3.0 {
                lastCaptureTime = now
                takePhoto()
            }
        }
    }
    
    private func handleTapToFocus(location: CGPoint, size: CGSize) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        focusPoint = location
        showFocusRect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showFocusRect = false }
        }
        cameraManager.focusAndExpose(at: location, screenWidth: size.width, screenHeight: size.height)
    }
}