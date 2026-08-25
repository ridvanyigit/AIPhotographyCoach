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
    // NEW: States for the Photo Capture Animation
    @State private var capturedImage: UIImage? = nil
    @State private var isAnimatingCapturedImage: Bool = false
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
                        CoachingBadgeView(framingAdvice: visionManager.framingAdvice, poseAdvice: visionManager.poseAdvice)
                            .padding(.top, 20)
                        LightingBadgeView(condition: lightingCoach.evaluate(brightness: cameraManager.currentBrightness))
                        Spacer()
                    }
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
                    // SCREEN FLASH EFFECT
                    Color.white
                        .opacity(flashOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    // NEW: CAPTURED PHOTO ANIMATION LAYER
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            // Animation steps: Scale down, move down, fade out, add rounded corners
                            .scaleEffect(isAnimatingCapturedImage ? 0.3 : 1.0)
                            .offset(y: isAnimatingCapturedImage ? geometry.size.height / 1.5 : 0)
                            .opacity(isAnimatingCapturedImage ? 0.0 : 1.0)
                            .cornerRadius(isAnimatingCapturedImage ? 60 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
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
                // Set up photo capture listener
                cameraManager.onPhotoCaptured = { image in
                    triggerPhotoAnimation(with: image)
                }
                cameraManager.onFrameAvailable = { pixelBuffer in
                    visionManager.processFrame(pixelBuffer)
                }
            }
            .onDisappear {
                motionManager.stopUpdates()
            }
            .onChange(of: visionManager.framingAdvice) { _, _ in
                triggerVoiceCoach()
            }
            .onChange(of: visionManager.poseAdvice) { _, _ in
                triggerVoiceCoach()
            }
            .onChange(of: motionManager.currentRollState) { _, _ in
                triggerVoiceCoach()
            }
            .onChange(of: motionManager.currentPitchState) { _, _ in
                triggerVoiceCoach()
            }
        }
    }
    // MARK: - Actions
    private func takePhoto() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // 1. Initial White Flash
        withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 }
        }
        // 2. Capture the actual photo
        cameraManager.capturePhoto()
    }
    // NEW: Animation Trigger Function
    private func triggerPhotoAnimation(with image: UIImage) {
        // Set the image initially full screen
        capturedImage = image
        isAnimatingCapturedImage = false
        // Slightly delay the start of the slide-down animation so user registers the photo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimatingCapturedImage = true
            }
            // Clean up memory after animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                capturedImage = nil
            }
        }
    }
    private func triggerVoiceCoach() {
        voiceCoach.provideGuidance(
            framing: visionManager.framingAdvice,
            pose: visionManager.poseAdvice,
            roll: motionManager.currentRollState,
            pitch: motionManager.currentPitchState
        )
       checkAutoCapture()
    }
    private func checkAutoCapture() {
        guard isAutoCaptureEnabled else { return }
        let isTiltPerfect = (motionManager.currentRollState == .aligned && motionManager.currentPitchState == .aligned)
        let isFramingPerfect = visionManager.detectedFaces.isEmpty ? true : (visionManager.framingAdvice == .perfect)
        // STRICT POSE RULE: Do not auto-capture if the person is looking away or shoulders are very tilted
        let isPosePerfect = (visionManager.poseAdvice == .good || visionManager.poseAdvice == .none)
        if isTiltPerfect && isFramingPerfect && isPosePerfect {
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