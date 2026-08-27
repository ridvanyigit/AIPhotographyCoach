import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var cameraManager = CameraManager()
    @State private var motionManager = MotionManager()
    @State private var visionManager = VisionManager()
    private let lightingCoach = LightingCoach()
    @State private var voiceCoach = VoiceCoachManager()
    
    @State private var flashOpacity: Double = 0.0
    @State private var isAutoCaptureEnabled: Bool = false
    @State private var isVoiceCoachMuted: Bool = false // YENİ: Sesli Asistan Sessiz Durumu
    @State private var lastCaptureTime: Date = Date.distantPast
    
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusRect: Bool = false
    
    @State private var capturedImage: UIImage? = nil
    @State private var isAnimatingCapturedImage: Bool = false
    
    @State private var lastSavedImage: UIImage? = nil
    @State private var isShowingPreview: Bool = false
    
    @State private var selectedZoom: Double = 1.0
    
    var activeModes: [String] { ["PORTRAIT", "RUNWAY", "FULL BODY", "BEAUTY AI", "GROUP PANO", "SPATIAL 3D"] }
    @State private var selectedModeIndex: Int = 0
    @State private var isDraggingMode: Bool = false
    
    @State private var selectedPortraitLighting: PortraitLightingMode = .natural
    @State private var studioBoost: Double = 0.5
    @State private var spotlightRadius: Double = 180.0
    @State private var highKeyExposure: Double = 0.8
    
    @State private var selectedSpatial3DMode: Spatial3DMode = .immersive
    @State private var parallaxIntensity: String = "Mid"
    @State private var isHoloMeshEnabled: Bool = true
    
    @State private var selectedPanoMode: PanoMode = .wideGroup
    @State private var panoDirection: PanoDirection = .leftToRight
    
    @State private var selectedFullBodyMode: FullBodyMode = .fashion
    @State private var isHeadFootGuideEnabled: Bool = true
    @State private var isOutfitPopEnabled: Bool = true
    
    @State private var selectedBeautyAIMode: BeautyAIMode = .naturalGlow
    @State private var glowWarmth: String = "Golden"
    @State private var glowBoost: String = "Soft"
    @State private var skinSmoothValue: Double = 50.0
    @State private var showSmoothSlider: Bool = false
    @State private var skinTextureMode: String = "Natural"
    @State private var eyeBrightenMode: String = "Sparkle"
    @State private var darkCircleMode: String = "Max"
    @State private var skinTonePalette: String = "Peach"
    @State private var proRetouchPreset: String = "Editorial"
    
    @State private var flashSetting: String = "Auto"
    @State private var timerSetting: Int = 0
    @State private var exposureValue: Double = 0.0
    @State private var selectedFilter: String = "Original"
    @State private var apertureValue: String = "f/2.8"
    @State private var isPoseAIOpen: Bool = true
    
    @State private var countdownRemaining: Int = 0
    @State private var isCountingDown: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    
    @State private var isSidebarOpen: Bool = false
    @State private var gearAngle: Double = 0.0
    @State private var baseZoomOnPinch: Double = 1.0
    
    var isPortraitMode: Bool { activeModes[selectedModeIndex] == "PORTRAIT" }
    var isRunwayMode: Bool { activeModes[selectedModeIndex] == "RUNWAY" }
    var isFullBodyMode: Bool { activeModes[selectedModeIndex] == "FULL BODY" }
    var isBeautyAIMode: Bool { activeModes[selectedModeIndex] == "BEAUTY AI" }
    var isPanoMode: Bool { activeModes[selectedModeIndex] == "GROUP PANO" }
    var isSpatial3DMode: Bool { activeModes[selectedModeIndex] == "SPATIAL 3D" }
    
    var currentModeAccentColor: Color { .yellow }
    
    private var currentParallaxOffset: CGFloat { switch parallaxIntensity { case "Low": return 2.5; case "High": return 9.0; default: return 5.0 } }
    private var currentParallaxOpacity: Double { switch parallaxIntensity { case "Low": return 0.09; case "High": return 0.22; default: return 0.15 } }
    
    private var filterSaturation: Double {
        if isPortraitMode {
            if selectedPortraitLighting == .stageMono || selectedPortraitLighting == .highKeyMono { return 0.0 }
            if selectedPortraitLighting == .contour { return 1.15 }
        } else if isSpatial3DMode && selectedSpatial3DMode == .holoMesh { return 1.25 }
        else if isFullBodyMode && isOutfitPopEnabled { return 1.28 }
        else if isBeautyAIMode { return (selectedBeautyAIMode == .facialTone && skinTonePalette == "Rosy") ? 1.22 : 1.12 }
        switch selectedFilter { case "Vivid": return 1.35; case "Warm": return 1.1; default: return 1.0 }
    }
    
    private var filterContrast: Double {
        if isPortraitMode {
            if selectedPortraitLighting == .highKeyMono { return 1.4 }
            if selectedPortraitLighting == .contour || selectedPortraitLighting == .stageMono { return 1.25 }
        } else if isSpatial3DMode && selectedSpatial3DMode == .holoMesh { return 1.15 }
        else if isFullBodyMode && selectedFullBodyMode == .fitness { return 1.25 }
        else if isBeautyAIMode { return selectedBeautyAIMode == .eyeBrighten ? 1.10 : 1.04 }
        switch selectedFilter { case "Vivid": return 1.06; case "Mono": return 1.1; case "Noir": return 1.35; default: return 1.0 }
    }
    
    private var filterBrightness: Double {
        if isPortraitMode && selectedPortraitLighting == .highKeyMono { return 0.1 }
        if isBeautyAIMode { return selectedBeautyAIMode == .naturalGlow ? 0.05 : 0.03 }
        switch selectedFilter { case "Noir": return -0.04; default: return 0.0 }
    }
    
    private var filterGrayscale: Double {
        if isPortraitMode && (selectedPortraitLighting == .stageMono || selectedPortraitLighting == .highKeyMono) { return 1.0 }
        switch selectedFilter { case "Mono", "Noir": return 1.0; default: return 0.0 }
    }
    
    private var filterColorMultiply: Color {
        if isSpatial3DMode && selectedSpatial3DMode == .holoMesh { return Color(red: 0.88, green: 1.0, blue: 1.0) }
        else if isBeautyAIMode {
            switch skinTonePalette {
            case "Bronze": return Color(red: 1.06, green: 0.96, blue: 0.88)
            case "Porcelain": return Color(red: 0.98, green: 0.99, blue: 1.05)
            case "Rosy": return Color(red: 1.05, green: 0.94, blue: 0.96)
            default: return Color(red: 1.04, green: 0.96, blue: 0.94)
            }
        }
        switch selectedFilter { case "Warm": return Color(red: 1.05, green: 0.98, blue: 0.92); default: return .white }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if cameraManager.isAuthorized {
                    mainCameraView(geometry: geometry)
                } else {
                    cameraDeniedView
                }
            }
            .fullScreenCover(isPresented: $isShowingPreview) {
                if let imageToView = lastSavedImage {
                    FullScreenImageView(image: imageToView, onDelete: { lastSavedImage = nil })
                }
            }
            .onAppear(perform: handleOnAppear)
            .onDisappear(perform: handleOnDisappear)
            .onChange(of: isShowingPreview) { _, isPresented in handlePreviewChange(isPresented) }
            .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
        }
    }
    
    @ViewBuilder private func mainCameraView(geometry: GeometryProxy) -> some View {
        ZStack {
            cameraPreviewLayer(geometry: geometry)
            
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { location in
                    if isSidebarOpen { withAnimation(.spring()) { isSidebarOpen = false } }
                    else if showSmoothSlider { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { showSmoothSlider = false } }
                    else if isCountingDown { cancelTimer() }
                    else { handleTapToFocus(location: location, size: geometry.size) }
                }
            
            Group {
                portraitLightingLiveOverlay.ignoresSafeArea()
                spatial3DLiveOverlay.ignoresSafeArea()
                spatialMeshLiveOverlay.ignoresSafeArea()
                beautyAILiveOverlay.ignoresSafeArea()
                
                if visionManager.framingAdvice != .perfect {
                    CompositionGridView().ignoresSafeArea().transition(.opacity).animation(.easeInOut(duration: 0.5), value: visionManager.framingAdvice)
                }
                FaceDetectionView(landmarks: visionManager.faceLandmarks).ignoresSafeArea()
                focusRectLayer
            }
            
            topBadgesLayer
            guidanceLayer
            
            sidebarLayer
            bottomControlsLayer
            
            captureAnimationsLayer(geometry: geometry)
        }
    }
    
    @ViewBuilder private func cameraPreviewLayer(geometry: GeometryProxy) -> some View {
        CameraPreviewView(session: cameraManager.session)
            .saturation(filterSaturation)
            .contrast(filterContrast)
            .brightness(filterBrightness)
            .grayscale(filterGrayscale)
            .colorMultiply(filterColorMultiply)
            .ignoresSafeArea()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        guard cameraManager.currentPosition == .back else { return }
                        let newZoom = baseZoomOnPinch * Double(value)
                        let clamped = max(0.5, min(newZoom, 5.0))
                        selectedZoom = clamped
                        cameraManager.setZoom(clamped)
                    }
                    .onEnded { _ in baseZoomOnPinch = selectedZoom }
            )
    }
    
    @ViewBuilder private var focusRectLayer: some View {
        if showFocusRect, let point = focusPoint {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 60, height: 60)
                .shadow(color: .yellow.opacity(0.5), radius: 4)
                .position(point)
                .scaleEffect(showFocusRect ? 1.0 : 1.2)
                .animation(.spring(), value: showFocusRect)
        }
    }
    
    @ViewBuilder private var topBadgesLayer: some View {
        VStack(spacing: 10) {
            CoachingBadgeView(framingAdvice: visionManager.framingAdvice, poseAdvice: visionManager.poseAdvice)
                .padding(.top, 20)
            
            if isSpatial3DMode {
                spatialDistanceBadge.transition(.scale.combined(with: .opacity))
            } else {
                LightingBadgeView(condition: lightingCoach.evaluate(brightness: cameraManager.currentBrightness))
            }
            Spacer()
        }
    }
    
    @ViewBuilder private var guidanceLayer: some View {
        let isPhoneTilted = motionManager.currentRollState != .aligned || motionManager.currentPitchState != .aligned
        
        Group {
            if isPanoMode {
                PanoGuidanceView(
                    mode: selectedPanoMode, direction: $panoDirection,
                    pitchDeviation: motionManager.smoothedPitchDeviation, angularVelocity: motionManager.currentAngularVelocity
                ).transition(.scale.combined(with: .opacity))
            } else if isFullBodyMode {
                FullBodyGuidanceView(
                    mode: selectedFullBodyMode,
                    pitchDeviation: motionManager.smoothedPitchDeviation,
                    hasFace: !visionManager.detectedFaces.isEmpty,
                    isGuideEnabled: isHeadFootGuideEnabled,
                    bodyFitState: visionManager.bodyFitState
                ).transition(.scale.combined(with: .opacity))
            } else if isPhoneTilted {
                GuidanceView(
                    roll: motionManager.smoothedRoll, pitchDeviation: motionManager.smoothedPitchDeviation,
                    rollState: motionManager.currentRollState, pitchState: motionManager.currentPitchState,
                    hasFace: !visionManager.detectedFaces.isEmpty
                ).transition(.opacity).animation(.easeInOut(duration: 0.3), value: isPhoneTilted)
            }
        }
    }
    
    @ViewBuilder private var sidebarLayer: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    if isSidebarOpen {
                        dynamicSidebarContent
                            .padding(.bottom, 60)
                            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    }
                    
                    Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isSidebarOpen.toggle() } }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 32))
                            .foregroundColor(isSidebarOpen ? .yellow : .white.opacity(0.9))
                            .shadow(color: .black.opacity(0.6), radius: 4)
                            .rotationEffect(.degrees(gearAngle))
                    }
                    .padding(.bottom, 10)
                    .onAppear { withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) { gearAngle = 360.0 } }
                }
                Spacer()
            }
            .padding(.trailing, 20)
        }
    }
    
    @ViewBuilder private var bottomControlsLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if showSmoothSlider && isBeautyAIMode && selectedBeautyAIMode == .smoothSkin {
                smoothSkinSliderOverlay.transition(.move(edge: .bottom).combined(with: .opacity)).padding(.bottom, 10)
            }
            
            dialControlsGroup
            
            Spacer().frame(height: 15)
            
            shutterAndAutoGroup
            
            modePickerGroup
        }
    }
    
    @ViewBuilder private var dialControlsGroup: some View {
        Group {
            if isPortraitMode { PortraitLightingDialView(selectedMode: $selectedPortraitLighting).padding(.bottom, 10).onChange(of: selectedPortraitLighting) { _, newLight in cameraManager.portraitLighting = newLight } }
            else if isSpatial3DMode { Spatial3DDialView(selectedMode: $selectedSpatial3DMode).padding(.bottom, 10).onChange(of: selectedSpatial3DMode) { _, newSpatial in cameraManager.spatial3DMode = newSpatial } }
            else if isPanoMode { PanoDialView(selectedMode: $selectedPanoMode).padding(.bottom, 10) }
            else if isFullBodyMode { FullBodyDialView(selectedMode: $selectedFullBodyMode).padding(.bottom, 10) }
            else if isBeautyAIMode {
                BeautyAIDialView(selectedMode: $selectedBeautyAIMode).padding(.bottom, 10)
                    .onChange(of: selectedBeautyAIMode) { _, newBeauty in
                        cameraManager.beautyAIMode = newBeauty
                        if newBeauty != .smoothSkin { showSmoothSlider = false }
                    }
            } else if cameraManager.currentPosition == .back {
                HStack(spacing: 12) {
                    ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { zoom in
                        let isSelected = (selectedZoom == zoom)
                        Button(action: { withAnimation { selectedZoom = zoom }; UIImpactFeedbackGenerator(style: .light).impactOccurred(); cameraManager.setZoom(zoom) }) {
                            Text(isSelected ? "\(zoom == 0.5 ? "0.5" : String(format: "%.0f", zoom))x" : (zoom == 0.5 ? "0.5" : String(format: "%.0f", zoom))).font(.system(size: 13, weight: .bold)).foregroundColor(isSelected ? .yellow : .white).frame(width: 42, height: 42).background(Color.black.opacity(0.6)).clipShape(Circle()).overlay(Circle().stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2))
                        }
                    }
                }.padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - DEKLANŞÖR & SESLİ ASİSTAN MUTE & AUTO BUTONLARI (KUSURSUZ SİMETRİ)
    @ViewBuilder private var shutterAndAutoGroup: some View {
        ZStack {
            ShutterButtonView(action: takePhoto)
            
            HStack {
                // SOL: SESLİ ASİSTAN SUSTURMA BUTONU (MUTE / UNMUTE)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isVoiceCoachMuted.toggle()
                        if isVoiceCoachMuted {
                            voiceCoach.stop()
                        }
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(!isVoiceCoachMuted ? Color.yellow : Color.white.opacity(0.3), lineWidth: !isVoiceCoachMuted ? 2 : 1)
                            )
                            .shadow(color: !isVoiceCoachMuted ? Color.yellow.opacity(0.6) : Color.clear, radius: 8)
                        
                        VStack(spacing: 2) {
                            Image(systemName: !isVoiceCoachMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(!isVoiceCoachMuted ? "VOICE" : "MUTED")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                        }
                        .foregroundColor(!isVoiceCoachMuted ? .yellow : .white.opacity(0.6))
                    }
                }
                .padding(.leading, 24)
                
                Spacer()
                
                // SAĞ: OTO-ÇEKİM BUTONU (AUTO A)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isAutoCaptureEnabled.toggle() }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(isAutoCaptureEnabled ? Color.yellow : Color.white.opacity(0.3), lineWidth: isAutoCaptureEnabled ? 2 : 1))
                            .shadow(color: isAutoCaptureEnabled ? Color.yellow.opacity(0.6) : Color.clear, radius: 8)
                        
                        VStack(spacing: 2) {
                            Image(systemName: isAutoCaptureEnabled ? "a.circle.fill" : "a.circle")
                                .font(.system(size: 18, weight: .bold))
                            Text("AUTO")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                        }
                        .foregroundColor(isAutoCaptureEnabled ? .yellow : .white.opacity(0.85))
                    }
                }
                .padding(.trailing, 24)
            }
            .frame(width: 320)
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder private var modePickerGroup: some View {
        ZStack(alignment: .center) {
            AppleGlassModePicker(
                modes: activeModes, selectedIndex: $selectedModeIndex, isDragging: $isDraggingMode,
                onModeChanged: { newMode in handleModeChange(mode: newMode) }
            ).zIndex(1)
            
            HStack {
                Button(action: { if lastSavedImage != nil { isShowingPreview = true } }) {
                    Group { if let image = lastSavedImage { Image(uiImage: image).resizable().scaledToFill() } else { Color.gray.opacity(0.3) } }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5))
                }
                Spacer()
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); cameraManager.switchCamera(); selectedZoom = 1.0 }) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20, weight: .bold)).foregroundColor(.white).frame(width: 44, height: 44).background(Color.black.opacity(0.4)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 30).opacity(isDraggingMode ? 0 : 1.0).scaleEffect(isDraggingMode ? 0.8 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDraggingMode).zIndex(2)
        }.padding(.bottom, 30)
    }
    
    @ViewBuilder private func captureAnimationsLayer(geometry: GeometryProxy) -> some View {
        if isCountingDown {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                Text("\(countdownRemaining)").font(.system(size: 110, weight: .black, design: .rounded)).foregroundColor(.yellow).shadow(color: .black.opacity(0.8), radius: 12).scaleEffect(1.2).animation(.easeInOut(duration: 0.4), value: countdownRemaining)
            }.allowsHitTesting(true).onTapGesture { cancelTimer() }
        }
        
        Color.white.opacity(flashOpacity).ignoresSafeArea().allowsHitTesting(false)
        
        if let image = capturedImage {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .scaleEffect(isAnimatingCapturedImage ? 0.1 : 1.0)
                .offset(x: isAnimatingCapturedImage ? -(geometry.size.width / 2.5) : 0, y: isAnimatingCapturedImage ? (geometry.size.height / 2.2) : 0)
                .opacity(isAnimatingCapturedImage ? 0.0 : 1.0)
                .cornerRadius(isAnimatingCapturedImage ? 100 : 0)
                .ignoresSafeArea().allowsHitTesting(false)
        }
    }
    
    @ViewBuilder private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash.fill").font(.system(size: 60)).foregroundColor(.red)
            Text("Camera Access Required").font(.headline).foregroundColor(.white)
            Text("Please enable camera access in settings.").multilineTextAlignment(.center).foregroundColor(.gray).padding()
        }
    }
    
    @ViewBuilder private var dynamicSidebarContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                Group {
                    if isBeautyAIMode { beautyAISidebarGroup }
                    else if isFullBodyMode { fullBodySidebarGroup }
                    else if isPanoMode { panoSidebarGroup }
                    else if isSpatial3DMode { spatial3DSidebarGroup }
                    else if isPortraitMode || isRunwayMode { portraitSidebarGroup }
                }
                
                Divider().background(Color.white.opacity(0.3)).padding(.horizontal, 10)
                
                generalSidebarGroup
            }
            .padding(.vertical, 25)
        }
        .frame(width: 64, height: 480)
        .background(Color.black.opacity(0.25))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, x: -5, y: 0)
    }
    
    @ViewBuilder private var beautyAISidebarGroup: some View {
        switch selectedBeautyAIMode {
        case .naturalGlow:
            sidebarButton(icon: "sparkles", label: glowWarmth, color: .white) { cycleGlowWarmth() }
            sidebarButton(icon: "sun.max.fill", label: glowBoost, color: .white) { glowBoost = (glowBoost == "Soft" ? "Vivid" : "Soft") }
        case .smoothSkin:
            sidebarButton(icon: "face.smiling.fill", label: "\(Int(skinSmoothValue))%", color: showSmoothSlider ? .yellow : .white) { showSmoothSlider.toggle() }
            sidebarButton(icon: "circle.dotted", label: skinTextureMode, color: .white) { skinTextureMode = (skinTextureMode == "Natural" ? "Silk" : "Natural") }
        case .eyeBrighten:
            sidebarButton(icon: "eyes", label: eyeBrightenMode, color: .white) { cycleEyeBrighten() }
            sidebarButton(icon: "moon.fill", label: darkCircleMode, color: .white) { darkCircleMode = (darkCircleMode == "Max" ? "Light" : "Max") }
        case .facialTone:
            sidebarButton(icon: "paintpalette.fill", label: skinTonePalette, color: .white) { cycleSkinTone() }
        case .proRetouch:
            sidebarButton(icon: "wand.and.rays", label: proRetouchPreset, color: .white) { cycleProRetouch() }
        }
        sidebarButton(icon: isPoseAIOpen ? "face.smiling.fill" : "face.smiling", label: isPoseAIOpen ? "Face AI" : "Off", color: isPoseAIOpen ? .yellow : .white.opacity(0.6)) { togglePoseAI() }
    }
    
    @ViewBuilder private var fullBodySidebarGroup: some View {
        sidebarButton(icon: isHeadFootGuideEnabled ? "square.topthird.inset.filled" : "square.dashed", label: isHeadFootGuideEnabled ? "Guide" : "Clean", color: isHeadFootGuideEnabled ? .yellow : .white.opacity(0.6)) { isHeadFootGuideEnabled.toggle() }
        if selectedFullBodyMode == .fashion { sidebarButton(icon: isOutfitPopEnabled ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack", label: isOutfitPopEnabled ? "Pop On" : "Pop Off", color: isOutfitPopEnabled ? .yellow : .white.opacity(0.6)) { isOutfitPopEnabled.toggle() } }
        sidebarButton(icon: isPoseAIOpen ? "figure.stand" : "figure.stand.line.dotted.figure.stand", label: "Pose AI", color: isPoseAIOpen ? .yellow : .white.opacity(0.6)) { togglePoseAI() }
    }
    
    @ViewBuilder private var panoSidebarGroup: some View {
        sidebarButton(icon: panoDirection == .leftToRight ? "arrow.right.circle.fill" : "arrow.left.circle.fill", label: panoDirection == .leftToRight ? "L ➔ R" : "R ➔ L", color: .yellow) { panoDirection = (panoDirection == .leftToRight ? .rightToLeft : .leftToRight) }
        sidebarButton(icon: selectedPanoMode == .vertorama ? "arrow.up.and.down.square.fill" : "pano.fill", label: selectedPanoMode == .vertorama ? "Vert" : "Hori", color: .yellow) { selectedPanoMode = (selectedPanoMode == .vertorama ? .wideGroup : .vertorama) }
    }
    
    @ViewBuilder private var spatial3DSidebarGroup: some View {
        sidebarButton(icon: "square.3.layers.3d.down.right", label: parallaxIntensity, color: .white) { cycleParallax() }
        sidebarButton(icon: isHoloMeshEnabled ? "cube.transparent.fill" : "cube.transparent", label: isHoloMeshEnabled ? "Mesh" : "Clean", color: isHoloMeshEnabled ? .yellow : .white.opacity(0.6)) { isHoloMeshEnabled.toggle() }
    }
    
    @ViewBuilder private var portraitSidebarGroup: some View {
        sidebarButton(icon: "f.cursive.circle.fill", label: apertureValue, color: .yellow) { cycleAperture() }
        sidebarButton(icon: isPoseAIOpen ? "figure.stand" : "figure.stand.line.dotted.figure.stand", label: "Pose", color: isPoseAIOpen ? .yellow : .white) { togglePoseAI() }
        if isPortraitMode {
            switch selectedPortraitLighting {
            case .natural: EmptyView()
            case .studio: sidebarButton(icon: "sun.max.fill", label: studioBoost == 1.0 ? "Boost" : "Soft", color: .yellow) { studioBoost = (studioBoost == 0.5 ? 1.0 : 0.5) }
            case .contour: sidebarButton(icon: "circle.righthalf.filled", label: "Drama", color: exposureValue != 0.0 ? .yellow : .white) { exposureValue = (exposureValue == 0.0 ? -0.7 : 0.0) }
            case .stage, .stageMono: sidebarButton(icon: "scope", label: spotlightRadius == 120.0 ? "Tight" : (spotlightRadius == 220.0 ? "Wide" : "Mid"), color: .yellow) { spotlightRadius = (spotlightRadius == 180.0 ? 120.0 : (spotlightRadius == 120.0 ? 220.0 : 180.0)) }
            case .highKeyMono: sidebarButton(icon: "sparkle", label: highKeyExposure == 1.4 ? "High" : "Norm", color: .yellow) { highKeyExposure = (highKeyExposure == 0.8 ? 1.4 : 0.8) }
            }
        }
    }
    
    @ViewBuilder private var generalSidebarGroup: some View {
        sidebarButton(icon: "timer", label: timerSetting == 0 ? "Off" : "\(timerSetting)s", color: timerSetting > 0 ? .yellow : .white) { cycleTimer() }
        sidebarButton(icon: flashSetting == "On" ? "bolt.fill" : (flashSetting == "Auto" ? "bolt.badge.a.fill" : "bolt.slash.fill"), label: flashSetting, color: flashSetting != "Off" ? .yellow : .white) { cycleFlash() }
        sidebarButton(icon: "camera.filters", label: selectedFilter == "Original" ? "Filter" : selectedFilter, color: selectedFilter != "Original" ? .yellow : .white) { cycleFilter() }
    }
    
    private func sidebarButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.spring()) { action() }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 22)); Text(label).font(.system(size: 9, weight: .bold)) }.foregroundColor(color)
        }
    }
    
    private var smoothSkinSliderOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "face.smiling.fill").font(.system(size: 13, weight: .bold))
                Text("SKIN SMOOTHNESS: \(Int(skinSmoothValue))%").font(.system(size: 11, weight: .black, design: .monospaced))
                Spacer()
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { skinSmoothValue = 50.0; cameraManager.beautyIntensity = 0.5 }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }) {
                    Text("RESET (50%)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.7)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.white.opacity(0.15)).clipShape(Capsule())
                }
            }.foregroundColor(.white)
            HStack(spacing: 12) {
                Text("0%").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5))
                Slider(value: $skinSmoothValue, in: 0...100, step: 1).tint(.white)
                    .onChange(of: skinSmoothValue) { _, val in
                        cameraManager.beautyIntensity = val / 100.0
                    }
                Text("100%").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5))
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).frame(width: 320).background(Color.black.opacity(0.45)).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1)).shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
    
    @ViewBuilder private var beautyAILiveOverlay: some View {
        if isBeautyAIMode, let face = visionManager.detectedFaces.first {
            GeometryReader { geo in
                let w = face.width * geo.size.width; let h = face.height * geo.size.height; let x = face.minX * geo.size.width; let y = (1 - face.minY - face.height) * geo.size.height
                ZStack(alignment: .topLeading) {
                    if selectedBeautyAIMode == .naturalGlow { RadialGradient(gradient: Gradient(colors: [Color.white.opacity(glowBoost == "Vivid" ? 0.22 : 0.12), Color.clear]), center: .center, startRadius: 20, endRadius: w * 0.9).frame(width: w * 1.5, height: h * 1.5).position(x: x + w/2, y: y + h/2) }
                    if selectedBeautyAIMode == .eyeBrighten { HStack(spacing: w * 0.22) { Circle().stroke(Color.white, lineWidth: 1.5).frame(width: w * 0.18, height: w * 0.18).overlay(Circle().fill(Color.white.opacity(0.3))); Circle().stroke(Color.white, lineWidth: 1.5).frame(width: w * 0.18, height: w * 0.18).overlay(Circle().fill(Color.white.opacity(0.3))) }.position(x: x + w/2, y: y + h * 0.36) }
                    RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 1.2).frame(width: w, height: h).position(x: x + w/2, y: y + h/2)
                        .overlay( HStack(spacing: 3) { Image(systemName: selectedBeautyAIMode.iconName).font(.system(size: 8)); Text(selectedBeautyAIMode == .smoothSkin ? "SMOOTH \(Int(skinSmoothValue))%" : selectedBeautyAIMode.rawValue).font(.system(size: 8, weight: .bold, design: .monospaced)) }.foregroundColor(.black).padding(.horizontal, 6).padding(.vertical, 2).background(Color.white).cornerRadius(4).position(x: x + w/2, y: y - 12) )
                }
            }.allowsHitTesting(false).transition(.opacity)
        }
    }
    
    @ViewBuilder private var spatial3DLiveOverlay: some View {
        if isSpatial3DMode {
            switch selectedSpatial3DMode {
            case .anaglyph: ZStack { Color.red.opacity(currentParallaxOpacity).blendMode(.screen).offset(x: -currentParallaxOffset, y: 0); Color.cyan.opacity(currentParallaxOpacity).blendMode(.screen).offset(x: currentParallaxOffset, y: 0) }.allowsHitTesting(false).animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentParallaxOffset)
            case .visionPro: RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 2).padding(24).shadow(color: .white.opacity(0.4), radius: 15).allowsHitTesting(false)
            case .focusedDepth: RadialGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.45)]), center: .center, startRadius: 150, endRadius: 360).allowsHitTesting(false)
            default: EmptyView()
            }
        }
    }
    
    @ViewBuilder private var spatialMeshLiveOverlay: some View {
        if isSpatial3DMode && isHoloMeshEnabled {
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<visionManager.detectedFaces.count, id: \.self) { idx in
                        let face = visionManager.detectedFaces[idx]
                        let w = face.width * geo.size.width; let h = face.height * geo.size.height; let x = face.minX * geo.size.width; let y = (1 - face.minY - face.height) * geo.size.height
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            Rectangle().fill(LinearGradient(colors: [.clear, Color.white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 2).offset(y: h * 0.45)
                            Path { p in p.move(to: CGPoint(x: 0, y: 14)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 14, y: 0)); p.move(to: CGPoint(x: w - 14, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: 14)); p.move(to: CGPoint(x: 0, y: h - 14)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 14, y: h)); p.move(to: CGPoint(x: w - 14, y: h)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w, y: h - 14)) }.stroke(Color.white, lineWidth: 2.5)
                            HStack(spacing: 3) { Image(systemName: "cube.transparent.fill").font(.system(size: 8)); Text("3D DEPTH: \(parallaxIntensity.uppercased())").font(.system(size: 8, weight: .bold, design: .monospaced)) }.foregroundColor(.black).padding(.horizontal, 6).padding(.vertical, 2).background(Color.white).cornerRadius(4).offset(x: 4, y: -20)
                        }.frame(width: w, height: h).position(x: x + w/2, y: y + h/2)
                    }
                    if visionManager.detectedFaces.isEmpty {
                        VStack { Spacer(); HStack(spacing: 10) { Image(systemName: "point.3.filled.connected.trianglepath.dotted").font(.system(size: 13)); Text("3D MESH SCANNING: \(parallaxIntensity.uppercased())").font(.system(size: 9, weight: .bold, design: .monospaced)) }.foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color.black.opacity(0.5)).clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1)).padding(.bottom, 220) }
                    }
                }
            }.allowsHitTesting(false).transition(.opacity)
        }
    }
    
    private var spatialDistanceBadge: some View {
        HStack(spacing: 6) { Image(systemName: "cube.transparent").font(.system(size: 11, weight: .bold)); Text(distanceText).font(.system(size: 11, weight: .bold, design: .rounded)) }
        .padding(.horizontal, 12).padding(.vertical, 6).background(distanceColor.opacity(0.85)).background(.ultraThinMaterial).foregroundColor(.white).clipShape(Capsule()).shadow(color: distanceColor.opacity(0.5), radius: 6).animation(.spring(response: 0.3, dampingFraction: 0.7), value: distanceText)
    }
    
    private var distanceText: String { guard let face = visionManager.detectedFaces.first else { return "3D Depth: Searching..." }; let w = face.width; if w > 0.38 { return "3D: Step Back (Too Close)" } else if w < 0.14 { return "3D: Move Closer (Too Far)" } else { return "1.8m — Optimal 3D Range ✨" } }
    private var distanceColor: Color { guard let face = visionManager.detectedFaces.first else { return Color.black.opacity(0.5) }; let w = face.width; if w >= 0.14 && w <= 0.38 { return Color.white.opacity(0.3) } else { return Color.orange } }
    
    @ViewBuilder private var portraitLightingLiveOverlay: some View {
        if isPortraitMode {
            switch selectedPortraitLighting {
            case .natural: EmptyView()
            case .studio: RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.12), Color.clear]), center: .center, startRadius: 40, endRadius: 280).allowsHitTesting(false)
            case .contour: RadialGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.55)]), center: .center, startRadius: 160, endRadius: 400).allowsHitTesting(false)
            case .stage, .stageMono: RadialGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.88)]), center: .center, startRadius: spotlightRadius, endRadius: spotlightRadius + 140).allowsHitTesting(false)
            case .highKeyMono: RadialGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.92)]), center: .center, startRadius: spotlightRadius + 20, endRadius: spotlightRadius + 180).allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - İŞLEVSEL AKSİYONLAR VE YAŞAM DÖNGÜSÜ
    private func handleOnAppear() {
        cameraManager.checkPermission()
        motionManager.startUpdates()
        cameraManager.onPhotoCaptured = { image in triggerPhotoAnimation(with: image) }
        cameraManager.onFrameAvailable = { pixelBuffer in
            visionManager.processFrame(pixelBuffer)
            DispatchQueue.main.async { self.triggerVoiceCoach() }
        }
    }
    
    private func handleOnDisappear() {
        cameraManager.stopSession()
        motionManager.stopUpdates()
    }
    
    private func handlePreviewChange(_ isPresented: Bool) {
        if isPresented { cameraManager.stopSession(); motionManager.stopUpdates() }
        else if scenePhase == .active { cameraManager.startSession(); motionManager.startUpdates() }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if !isShowingPreview && cameraManager.isAuthorized { cameraManager.startSession(); motionManager.startUpdates() }
        } else { cameraManager.stopSession(); motionManager.stopUpdates() }
    }
    
    private func handleModeChange(mode: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        cameraManager.isPortraitActive = (mode == "PORTRAIT")
        cameraManager.isSpatial3DActive = (mode == "SPATIAL 3D")
        cameraManager.isBeautyAIActive = (mode == "BEAUTY AI")
        
        if mode == "PORTRAIT" {
            cameraManager.portraitLighting = selectedPortraitLighting
        } else if mode == "SPATIAL 3D" {
            cameraManager.spatial3DMode = selectedSpatial3DMode
            cameraManager.parallaxIntensity = parallaxIntensity
        } else if mode == "BEAUTY AI" {
            cameraManager.beautyAIMode = selectedBeautyAIMode
            cameraManager.skinTonePalette = skinTonePalette
            cameraManager.beautyIntensity = skinSmoothValue / 100.0
        }
        
        guard cameraManager.currentPosition == .back else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if mode == "PORTRAIT" { selectedZoom = 2.0; cameraManager.setZoom(2.0) }
            else { selectedZoom = 1.0; cameraManager.setZoom(1.0) }
        }
    }
    
    private func togglePoseAI() {
        isPoseAIOpen.toggle()
        visionManager.isPoseAIEnabled = isPoseAIOpen
    }
    
    private func cycleSkinTone() {
        let values = ["Peach", "Bronze", "Porcelain", "Rosy"]
        if let idx = values.firstIndex(of: skinTonePalette) {
            skinTonePalette = values[(idx + 1) % values.count]
            cameraManager.skinTonePalette = skinTonePalette
        }
    }
    
    private func cycleParallax() {
        let levels = ["Low", "Mid", "High"]
        if let idx = levels.firstIndex(of: parallaxIntensity) {
            parallaxIntensity = levels[(idx + 1) % levels.count]
            cameraManager.parallaxIntensity = parallaxIntensity
        }
    }
    
    private func cycleFlash() { if flashSetting == "Auto" { flashSetting = "On" } else if flashSetting == "On" { flashSetting = "Off" } else { flashSetting = "Auto" } }
    private func cycleTimer() { if timerSetting == 0 { timerSetting = 3 } else if timerSetting == 3 { timerSetting = 10 } else { timerSetting = 0 } }
    private func cycleAperture() { let values = ["f/1.4", "f/2.0", "f/2.8", "f/4.0", "f/5.6", "f/8.0"]; if let idx = values.firstIndex(of: apertureValue) { apertureValue = values[(idx + 1) % values.count] } }
    private func cyclePortraitLighting() { let modes = PortraitLightingMode.allCases; if let idx = modes.firstIndex(of: selectedPortraitLighting) { selectedPortraitLighting = modes[(idx + 1) % modes.count]; cameraManager.portraitLighting = selectedPortraitLighting } }
    private func cycleFilter() { let filters = ["Original", "Vivid", "Warm", "Mono", "Noir"]; if let idx = filters.firstIndex(of: selectedFilter) { selectedFilter = filters[(idx + 1) % filters.count] } }
    private func cycleGlowWarmth() { let values = ["Golden", "Pearl", "Rose"]; if let idx = values.firstIndex(of: glowWarmth) { glowWarmth = values[(idx + 1) % values.count] } }
    private func cycleEyeBrighten() { let values = ["Sparkle", "Vivid", "Deep"]; if let idx = values.firstIndex(of: eyeBrightenMode) { eyeBrightenMode = values[(idx + 1) % values.count] } }
    private func cycleProRetouch() { let values = ["Editorial", "Red Carpet", "Glamour"]; if let idx = values.firstIndex(of: proRetouchPreset) { proRetouchPreset = values[(idx + 1) % values.count] } }
    
    // YENİ: Sesli Asistan Mute Kontrolü
    private func triggerVoiceCoach() {
        if !isVoiceCoachMuted {
            voiceCoach.provideGuidance(
                framing: visionManager.framingAdvice,
                pose: visionManager.poseAdvice,
                roll: motionManager.currentRollState,
                pitch: motionManager.currentPitchState
            )
        }
        checkAutoCapture()
    }
    
    private func takePhoto() {
        guard !isCountingDown else { return }
        if timerSetting > 0 {
            isCountingDown = true; countdownRemaining = timerSetting
            timerTask = Task { @MainActor in
                while countdownRemaining > 0 { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); try? await Task.sleep(nanoseconds: 1_000_000_000); if Task.isCancelled { return }; countdownRemaining -= 1 }
                isCountingDown = false; executePhotoCapture()
            }
        } else { executePhotoCapture() }
    }
    
    private func cancelTimer() { timerTask?.cancel(); isCountingDown = false; countdownRemaining = 0 }
    
    private func executePhotoCapture() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 } }
        cameraManager.selectedFilter = selectedFilter; cameraManager.capturePhoto()
    }
    
    private func triggerPhotoAnimation(with image: UIImage) {
        capturedImage = image; isAnimatingCapturedImage = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isAnimatingCapturedImage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { lastSavedImage = image; capturedImage = nil }
        }
    }
    
    private func checkAutoCapture() {
        guard isAutoCaptureEnabled && !isCountingDown else { return }
        let isTiltPerfect = (motionManager.currentRollState == .aligned && motionManager.currentPitchState == .aligned)
        let isFramingPerfect = visionManager.detectedFaces.isEmpty ? true : (visionManager.framingAdvice == .perfect)
        let isPosePerfect = (visionManager.poseAdvice == .good || visionManager.poseAdvice == .none)
        let isFullBodyPerfect = isFullBodyMode ? (visionManager.bodyFitState == .perfectFit) : true
        
        if isTiltPerfect && isFramingPerfect && isPosePerfect && isFullBodyPerfect {
            let now = Date()
            if now.timeIntervalSince(lastCaptureTime) > 3.0 {
                lastCaptureTime = now
                takePhoto()
            }
        }
    }
    
    private func handleTapToFocus(location: CGPoint, size: CGSize) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        focusPoint = location; showFocusRect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showFocusRect = false } }
        cameraManager.focusAndExpose(at: location, screenWidth: size.width, screenHeight: size.height)
    }
}

// MARK: - TEMİZLENMİŞ SİHİRLİ CAM MOD SEÇİCİ
struct AppleGlassModePicker: View {
    let modes: [String]
    @Binding var selectedIndex: Int
    @Binding var isDragging: Bool
    var onModeChanged: (String) -> Void
    
    @State private var dragOffset: CGFloat = 0
    let itemWidth: CGFloat = 110
    
    var currentOffset: CGFloat { (CGFloat(modes.count - 1) / 2.0 - CGFloat(selectedIndex)) * itemWidth + dragOffset }
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(isDragging ? (i == selectedIndex ? 0.0 : 0.6) : 0.0)
                        .frame(width: itemWidth)
                }
            }
            .fixedSize().offset(x: currentOffset)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .black, location: 0.15), .init(color: .black, location: 0.85), .init(color: .clear, location: 1.0)], startPoint: .leading, endPoint: .trailing))

            Capsule().fill(.ultraThinMaterial).opacity(0.85).overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)).shadow(color: .black.opacity(0.2), radius: 8, y: 4).frame(width: 120, height: 44)

            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.yellow)
                        .frame(width: itemWidth)
                }
            }
            .fixedSize().offset(x: currentOffset).mask(Capsule().frame(width: 120, height: 44))
        }
        .frame(width: 300, height: 44)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { val in
                    if !isDragging { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isDragging = true } }
                    dragOffset = val.translation.width * 0.75
                }
                .onEnded { val in
                    let movement = val.translation.width + val.predictedEndTranslation.width * 0.2
                    let indexShift = -Int(round(movement / itemWidth))
                    let newIndex = min(max(selectedIndex + indexShift, 0), modes.count - 1)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedIndex = newIndex; dragOffset = 0; isDragging = false
                    }
                    onModeChanged(modes[newIndex])
                }
        )
    }
}