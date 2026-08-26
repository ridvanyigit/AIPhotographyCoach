import SwiftUI
import AVFoundation

// MARK: - Kamera Ana Kategorileri
enum CameraCategory: String, CaseIterable {
    case photo = "PHOTO"
    case human = "HUMAN"
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
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
    
    @State private var capturedImage: UIImage? = nil
    @State private var isAnimatingCapturedImage: Bool = false
    
    @State private var lastSavedImage: UIImage? = nil
    @State private var isShowingPreview: Bool = false
    
    // ZOOM STATE
    @State private var selectedZoom: Double = 1.0
    
    // KUSURSUZ APPLE GLASS MOD SEÇİCİ STATE'LERİ
    @State private var currentCategory: CameraCategory = .photo
    @State private var selectedModeIndex: Int = 0
    @State private var isDraggingMode: Bool = false
    @State private var showCategoryMenu: Bool = false
    
    // PORTRE IŞIĞI VE DİNAMİK SİDEBAR AYARLARI
    @State private var selectedPortraitLighting: PortraitLightingMode = .natural
    @State private var studioBoost: Double = 0.5
    @State private var spotlightRadius: Double = 180.0
    @State private var highKeyExposure: Double = 0.8
    
    // HIZLI AYAR ÇEKMECESİ STATE'LERİ
    @State private var isQuickSettingsOpen: Bool = false
    @State private var flashSetting: String = "Auto"
    @State private var isLivePhoto: Bool = true
    @State private var timerSetting: Int = 0
    @State private var exposureValue: Double = 0.0
    @State private var selectedFilter: String = "Original"
    @State private var aspectRatio: String = "4:3"
    @State private var nightMode: String = "Auto"
    @State private var apertureValue: String = "f/2.8"
    @State private var isPoseAIOpen: Bool = true
    
    // Zamanlayıcı Geri Sayım State'leri
    @State private var countdownRemaining: Int = 0
    @State private var isCountingDown: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    
    // SIDEBAR & DİŞLİ ÇARK
    @State private var isSidebarOpen: Bool = false
    @State private var gearAngle: Double = 0.0
    
    // Pinch Zoom
    @State private var baseZoomOnPinch: Double = 1.0
    
    var activeModes: [String] {
        activeModesFor(currentCategory)
    }
    
    var isPortraitMode: Bool {
        currentCategory == .human && activeModes[selectedModeIndex] == "PORTRAIT"
    }
    
    // Filtre GPU Değerleri
    private var filterSaturation: Double {
        if isPortraitMode {
            if selectedPortraitLighting == .stageMono || selectedPortraitLighting == .highKeyMono { return 0.0 }
            if selectedPortraitLighting == .contour { return 1.15 }
        }
        switch selectedFilter {
        case "Vivid": return 1.35
        case "Warm": return 1.1
        default: return 1.0
        }
    }
    
    private var filterContrast: Double {
        if isPortraitMode {
            if selectedPortraitLighting == .highKeyMono { return 1.4 }
            if selectedPortraitLighting == .contour || selectedPortraitLighting == .stageMono { return 1.25 }
        }
        switch selectedFilter {
        case "Vivid": return 1.06
        case "Mono": return 1.1
        case "Noir": return 1.35
        default: return 1.0
        }
    }
    
    private var filterBrightness: Double {
        if isPortraitMode && selectedPortraitLighting == .highKeyMono { return 0.1 }
        switch selectedFilter {
        case "Noir": return -0.04
        default: return 0.0
        }
    }
    
    private var filterGrayscale: Double {
        if isPortraitMode && (selectedPortraitLighting == .stageMono || selectedPortraitLighting == .highKeyMono) { return 1.0 }
        switch selectedFilter {
        case "Mono", "Noir": return 1.0
        default: return 0.0
        }
    }
    
    private var filterColorMultiply: Color {
        switch selectedFilter {
        case "Warm": return Color(red: 1.05, green: 0.98, blue: 0.92)
        default: return .white
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if cameraManager.isAuthorized {
                    // 1. KAMERA ÖNİZLEMESİ + GPU FİLTRELERİ + PINCH ZOOM
                    CameraPreviewView(session: cameraManager.session)
                        .saturation(filterSaturation)
                        .contrast(filterContrast)
                        .brightness(filterBrightness)
                        .grayscale(filterGrayscale)
                        .colorMultiply(filterColorMultiply)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            if isQuickSettingsOpen {
                                withAnimation(.spring()) { isQuickSettingsOpen = false }
                            } else if showCategoryMenu {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCategoryMenu = false }
                            } else if isSidebarOpen {
                                withAnimation(.spring()) { isSidebarOpen = false }
                            } else if isCountingDown {
                                cancelTimer()
                            } else {
                                handleTapToFocus(location: location, size: geometry.size)
                            }
                        }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    guard cameraManager.currentPosition == .back else { return }
                                    let newZoom = baseZoomOnPinch * Double(value)
                                    let clamped = max(0.5, min(newZoom, 5.0))
                                    selectedZoom = clamped
                                    cameraManager.setZoom(clamped)
                                }
                                .onEnded { _ in
                                    baseZoomOnPinch = selectedZoom
                                }
                        )
                    
                    // 2. PORTRE IŞIĞI CANLI SHADER KATMANI
                    portraitLightingLiveOverlay
                        .ignoresSafeArea()
                    
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
                    
                    // 3. ÜST ROZETLER (Tamamen Temiz & Sade Arayüz)
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
                    
                    // 4. SAĞ YAN MENÜ: DİNAMİK SİDEBAR
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
                                .onAppear {
                                    withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                                        gearAngle = 360.0
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.trailing, 20)
                    }
                    
                    // 5. ALT KONTROL PANELİ
                    VStack(spacing: 0) {
                        Spacer()
                        
                        if isQuickSettingsOpen {
                            quickSettingsDrawer
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(.bottom, 10)
                        }
                        
                        // PORTRE MODUNDA APPLE DİREKSİYON / IŞIK ÇARKI
                        if isPortraitMode {
                            PortraitLightingDialView(selectedMode: $selectedPortraitLighting)
                                .padding(.bottom, 10)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                                .onChange(of: selectedPortraitLighting) { _, newLight in
                                    cameraManager.portraitLighting = newLight
                                }
                        } else if cameraManager.currentPosition == .back {
                            // ZOOM BUTONLARI
                            HStack(spacing: 12) {
                                ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { zoom in
                                    let isSelected = (selectedZoom == zoom)
                                    Button(action: {
                                        withAnimation { selectedZoom = zoom }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        cameraManager.setZoom(zoom)
                                    }) {
                                        Text(isSelected ? "\(zoom == 0.5 ? "0.5" : String(format: "%.0f", zoom))x" : (zoom == 0.5 ? "0.5" : String(format: "%.0f", zoom)))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? .yellow : .white)
                                            .frame(width: 42, height: 42)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2))
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                            .transition(.opacity)
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isQuickSettingsOpen.toggle()
                            }
                        }) {
                            Image(systemName: isQuickSettingsOpen ? "chevron.down" : "chevron.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 32, height: 18)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        .padding(.bottom, 15)
                        
                        ShutterButtonView(action: takePhoto)
                            .padding(.bottom, 20)
                        
                        // ZSTACK: Sabit Butonlar ve Sihirli Cam Seçici
                        ZStack(alignment: .center) {
                            
                            AppleGlassModePicker(
                                modes: activeModes,
                                selectedIndex: $selectedModeIndex,
                                isDragging: $isDraggingMode,
                                showCategoryMenu: $showCategoryMenu,
                                onModeChanged: { newMode in
                                    handleModeChange(mode: newMode)
                                }
                            )
                            .zIndex(1)
                            
                            HStack {
                                Button(action: { if lastSavedImage != nil { isShowingPreview = true } }) {
                                    Group {
                                        if let image = lastSavedImage {
                                            Image(uiImage: image).resizable().scaledToFill()
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    cameraManager.switchCamera()
                                    selectedZoom = 1.0 
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 30)
                            .opacity(isDraggingMode ? 0 : 1.0)
                            .scaleEffect(isDraggingMode ? 0.8 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDraggingMode)
                            .zIndex(2)
                        }
                        .padding(.bottom, 30)
                        .overlay(alignment: .bottom) {
                            if showCategoryMenu {
                                categoryMenuOverlay
                            }
                        }
                    }
                    
                    if isCountingDown {
                        ZStack {
                            Color.black.opacity(0.35).ignoresSafeArea()
                            Text("\(countdownRemaining)")
                                .font(.system(size: 110, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                                .shadow(color: .black.opacity(0.8), radius: 12)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.4), value: countdownRemaining)
                        }
                        .allowsHitTesting(true)
                        .onTapGesture { cancelTimer() }
                    }
                    
                    Color.white
                        .opacity(flashOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .scaleEffect(isAnimatingCapturedImage ? 0.1 : 1.0)
                            .offset(
                                x: isAnimatingCapturedImage ? -(geometry.size.width / 2.5) : 0,
                                y: isAnimatingCapturedImage ? (geometry.size.height / 2.2) : 0
                            )
                            .opacity(isAnimatingCapturedImage ? 0.0 : 1.0)
                            .cornerRadius(isAnimatingCapturedImage ? 100 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash.fill").font(.system(size: 60)).foregroundColor(.red)
                        Text("Camera Access Required").font(.headline).foregroundColor(.white)
                        Text("Please enable camera access in settings.").multilineTextAlignment(.center).foregroundColor(.gray).padding()
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingPreview) {
                if let imageToView = lastSavedImage {
                    FullScreenImageView(image: imageToView, onDelete: { lastSavedImage = nil })
                }
            }
            .onChange(of: isShowingPreview) { _, isPresented in
                if isPresented { cameraManager.stopSession(); motionManager.stopUpdates() } 
                else if scenePhase == .active { cameraManager.startSession(); motionManager.startUpdates() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if !isShowingPreview && cameraManager.isAuthorized { cameraManager.startSession(); motionManager.startUpdates() }
                } else { cameraManager.stopSession(); motionManager.stopUpdates() }
            }
            .onAppear {
                cameraManager.checkPermission()
                motionManager.startUpdates()
                cameraManager.onPhotoCaptured = { image in triggerPhotoAnimation(with: image) }
                cameraManager.onFrameAvailable = { pixelBuffer in visionManager.processFrame(pixelBuffer) }
            }
            .onDisappear {
                cameraManager.stopSession()
                motionManager.stopUpdates()
            }
            .onChange(of: isPoseAIOpen) { _, newValue in
                visionManager.isPoseAIEnabled = newValue
            }
            .onChange(of: isPortraitMode) { _, active in
                cameraManager.isPortraitActive = active
                cameraManager.portraitLighting = selectedPortraitLighting
            }
            .onChange(of: visionManager.framingAdvice) { _, _ in triggerVoiceCoach() }
            .onChange(of: visionManager.poseAdvice) { _, _ in triggerVoiceCoach() }
            .onChange(of: motionManager.currentRollState) { _, _ in triggerVoiceCoach() }
            .onChange(of: motionManager.currentPitchState) { _, _ in triggerVoiceCoach() }
        }
    }
    
    // MARK: - PORTRE IŞIKLARI CANLI SHADER KATMANI
    @ViewBuilder
    private var portraitLightingLiveOverlay: some View {
        if isPortraitMode {
            switch selectedPortraitLighting {
            case .natural:
                EmptyView()
            case .studio:
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.12), Color.clear]),
                    center: .center,
                    startRadius: 40,
                    endRadius: 280
                )
                .allowsHitTesting(false)
            case .contour:
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.55)]),
                    center: .center,
                    startRadius: 160,
                    endRadius: 400
                )
                .allowsHitTesting(false)
            case .stage, .stageMono:
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.88)]),
                    center: .center,
                    startRadius: spotlightRadius,
                    endRadius: spotlightRadius + 140
                )
                .allowsHitTesting(false)
            case .highKeyMono:
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.92)]),
                    center: .center,
                    startRadius: spotlightRadius + 20,
                    endRadius: spotlightRadius + 180
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - SEÇİLİ PORTRE IŞIĞINA GÖRE DİNAMİK SİDEBAR İÇERİĞİ
    @ViewBuilder
    private var dynamicSidebarContent: some View {
        VStack(spacing: 20) {
            // 1. AUTO CAPTURE BUTONU
            Button(action: { withAnimation { isAutoCaptureEnabled.toggle() } }) {
                VStack(spacing: 4) {
                    Image(systemName: isAutoCaptureEnabled ? "a.circle.fill" : "a.circle")
                        .font(.system(size: 24, weight: .light))
                    Text("Auto")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(isAutoCaptureEnabled ? .yellow : .white)
            }
            
            // 2. IŞIK MODUNA ÖZEL DİNAMİK BUTONLAR
            if isPortraitMode {
                Divider().background(Color.white.opacity(0.2)).frame(width: 36)
                
                switch selectedPortraitLighting {
                case .natural:
                    // Diyafram (f) Kontrolü (Artık Sadece Sidebar'da)
                    Button(action: { cycleAperture(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "f.cursive.circle.fill")
                                .font(.system(size: 22))
                            Text(apertureValue)
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.yellow)
                    }
                    // Pose AI Kontrolü
                    Button(action: { isPoseAIOpen.toggle(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        VStack(spacing: 4) {
                            Image(systemName: isPoseAIOpen ? "figure.stand" : "figure.stand.line.dotted.figure.stand")
                                .font(.system(size: 22))
                            Text("Pose")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(isPoseAIOpen ? .yellow : .white)
                    }
                    
                case .studio:
                    // Stüdyo Işık Güçlendirici
                    Button(action: {
                        studioBoost = (studioBoost == 0.5 ? 1.0 : 0.5)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 22))
                            Text(studioBoost == 1.0 ? "Boost" : "Soft")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.yellow)
                    }
                    
                case .contour:
                    // Kontur Derinlik Tonu
                    Button(action: {
                        exposureValue = (exposureValue == 0.0 ? -0.7 : 0.0)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "circle.righthalf.filled")
                                .font(.system(size: 22))
                            Text("Drama")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(exposureValue != 0.0 ? .yellow : .white)
                    }
                    
                case .stage, .stageMono:
                    // Sahne Spot Işığı Çapı
                    Button(action: {
                        spotlightRadius = (spotlightRadius == 180.0 ? 120.0 : (spotlightRadius == 120.0 ? 220.0 : 180.0))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "scope")
                                .font(.system(size: 22))
                            Text(spotlightRadius == 120.0 ? "Tight" : (spotlightRadius == 220.0 ? "Wide" : "Mid"))
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.yellow)
                    }
                    
                case .highKeyMono:
                    // High-Key Parlaklık
                    Button(action: {
                        highKeyExposure = (highKeyExposure == 0.8 ? 1.4 : 0.8)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 22))
                            Text(highKeyExposure == 1.4 ? "High" : "Norm")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.yellow)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 25)
        .frame(width: 64, height: 320)
        .background(Color.black.opacity(0.25))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, x: -5, y: 0)
    }
    
    // MARK: - Kategori Menüsü Overlay
    private var categoryMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCategoryMenu = false
                    }
                }
            
            categoryMenuView
                .offset(y: -150)
        }
        .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
        .zIndex(100)
    }
    
    private var categoryMenuView: some View {
        VStack(spacing: 0) {
            ForEach(CameraCategory.allCases, id: \.self) { category in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        currentCategory = category
                        selectedModeIndex = 0
                        showCategoryMenu = false
                    }
                    handleModeChange(mode: activeModesFor(category)[0])
                }) {
                    HStack {
                        Text(category.rawValue)
                            .font(.system(size: 16, weight: currentCategory == category ? .semibold : .regular, design: .rounded))
                            .foregroundColor(currentCategory == category ? .yellow : .white)
                        
                        Spacer()
                        
                        if currentCategory == category {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                if category != CameraCategory.allCases.last {
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 16)
                }
            }
        }
        .frame(width: 220)
        .background(Color.black.opacity(0.15))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
    
    private func handleModeChange(mode: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard cameraManager.currentPosition == .back else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if mode == "PORTRAIT" {
                selectedZoom = 2.0
                cameraManager.setZoom(2.0)
            } else if mode == "MACRO" {
                selectedZoom = 0.5
                cameraManager.setZoom(0.5)
            } else {
                selectedZoom = 1.0
                cameraManager.setZoom(1.0)
            }
        }
    }
    
    private func activeModesFor(_ cat: CameraCategory) -> [String] {
        switch cat {
        case .photo: return ["PHOTO", "PRO RAW", "MACRO", "ACTION"]
        case .human: return ["HUMAN", "PORTRAIT", "SPATIAL 3D", "PANO", "FULL BODY", "BEAUTY AI"]
        }
    }
    
    private var isHumanCategorySelected: Bool {
        return currentCategory == .human
    }
    
    private var quickSettingsDrawer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if !isHumanCategorySelected {
                    drawerButton(icon: flashIcon, label: "Flash: \(flashSetting)") { cycleFlash() }
                    drawerButton(icon: isLivePhoto ? "livephoto.play" : "livephoto.slash", label: "Live: \(isLivePhoto ? "On" : "Off")", isYellow: isLivePhoto) { isLivePhoto.toggle() }
                    drawerButton(icon: "timer", label: timerSetting == 0 ? "Timer: Off" : "\(timerSetting)s", isYellow: timerSetting > 0) { cycleTimer() }
                    drawerButton(icon: "aspectratio", label: aspectRatio) { cycleAspectRatio() }
                    drawerButton(icon: "moon.stars.fill", label: "Night: \(nightMode)", isYellow: nightMode != "Off") { nightMode = (nightMode == "Auto" ? "On" : (nightMode == "On" ? "Off" : "Auto")) }
                    drawerButton(icon: "camera.filters", label: selectedFilter, isYellow: selectedFilter != "Original") { cycleFilter() }
                } else {
                    drawerButton(icon: "f.cursive.circle", label: "Aperture: \(apertureValue)", isYellow: true) { cycleAperture() }
                    drawerButton(icon: isPoseAIOpen ? "figure.stand" : "figure.stand.line.dotted.figure.stand", label: "Pose AI: \(isPoseAIOpen ? "On" : "Off")", isYellow: isPoseAIOpen) { isPoseAIOpen.toggle() }
                    drawerButton(icon: "timer", label: timerSetting == 0 ? "Timer: Off" : "\(timerSetting)s", isYellow: timerSetting > 0) { cycleTimer() }
                    drawerButton(icon: "camera.filters", label: selectedFilter, isYellow: selectedFilter != "Original") { cycleFilter() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.35))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        .padding(.horizontal, 16)
    }
    
    private func drawerButton(icon: String, label: String, isYellow: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold))
                Text(label).font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(isYellow ? .yellow : .white)
            .frame(minWidth: 60)
            .padding(.vertical, 4)
        }
    }
    
    private var flashIcon: String {
        switch flashSetting {
        case "On": return "bolt.fill"
        case "Off": return "bolt.slash.fill"
        default: return "bolt.badge.a.fill"
        }
    }
    private func cycleFlash() { if flashSetting == "Auto" { flashSetting = "On" } else if flashSetting == "On" { flashSetting = "Off" } else { flashSetting = "Auto" } }
    private func cycleTimer() { if timerSetting == 0 { timerSetting = 3 } else if timerSetting == 3 { timerSetting = 10 } else { timerSetting = 0 } }
    private func cycleAspectRatio() { if aspectRatio == "4:3" { aspectRatio = "16:9" } else if aspectRatio == "16:9" { aspectRatio = "1:1" } else { aspectRatio = "4:3" } }
    private func cycleAperture() {
        let values = ["f/1.4", "f/2.0", "f/2.8", "f/4.0", "f/5.6", "f/8.0"]
        if let idx = values.firstIndex(of: apertureValue) { apertureValue = values[(idx + 1) % values.count] }
    }
    private func cycleFilter() {
        let filters = ["Original", "Vivid", "Warm", "Mono", "Noir"]
        if let idx = filters.firstIndex(of: selectedFilter) { selectedFilter = filters[(idx + 1) % filters.count] }
    }
    
    private func triggerVoiceCoach() {
        voiceCoach.provideGuidance(framing: visionManager.framingAdvice, pose: visionManager.poseAdvice, roll: motionManager.currentRollState, pitch: motionManager.currentPitchState)
        checkAutoCapture()
    }
    
    private func takePhoto() {
        guard !isCountingDown else { return }
        
        if timerSetting > 0 {
            isCountingDown = true
            countdownRemaining = timerSetting
            
            timerTask = Task { @MainActor in
                while countdownRemaining > 0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    countdownRemaining -= 1
                }
                isCountingDown = false
                executePhotoCapture()
            }
        } else {
            executePhotoCapture()
        }
    }
    
    private func cancelTimer() {
        timerTask?.cancel()
        isCountingDown = false
        countdownRemaining = 0
    }
    
    private func executePhotoCapture() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 }
        }
        cameraManager.selectedFilter = selectedFilter
        cameraManager.capturePhoto()
    }
    
    private func triggerPhotoAnimation(with image: UIImage) {
        capturedImage = image
        isAnimatingCapturedImage = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isAnimatingCapturedImage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                lastSavedImage = image
                capturedImage = nil
            }
        }
    }
    
    private func checkAutoCapture() {
        guard isAutoCaptureEnabled && !isCountingDown else { return }
        let isTiltPerfect = (motionManager.currentRollState == .aligned && motionManager.currentPitchState == .aligned)
        let isFramingPerfect = visionManager.detectedFaces.isEmpty ? true : (visionManager.framingAdvice == .perfect)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showFocusRect = false } }
        cameraManager.focusAndExpose(at: location, screenWidth: size.width, screenHeight: size.height)
    }
}

// MARK: - APPLE STANDARTLARINDA SİHİRLİ CAM MOD SEÇİCİ
struct AppleGlassModePicker: View {
    let modes: [String]
    @Binding var selectedIndex: Int
    @Binding var isDragging: Bool
    @Binding var showCategoryMenu: Bool
    var onModeChanged: (String) -> Void
    
    @State private var dragOffset: CGFloat = 0
    let itemWidth: CGFloat = 110
    
    var currentOffset: CGFloat {
        (CGFloat(modes.count - 1) / 2.0 - CGFloat(selectedIndex)) * itemWidth + dragOffset
    }
    
    var body: some View {
        ZStack {
            // KATMAN 1: ARKA PLAN YAZILARI
            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(isDragging ? 0.6 : (i == selectedIndex ? 0.0 : 0.4))
                        .frame(width: itemWidth)
                }
            }
            .fixedSize()
            .offset(x: currentOffset)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )

            // KATMAN 2: CAM KAPSÜL
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .frame(width: 120, height: 44)

            // KATMAN 3: SARI YAZI
            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.yellow)
                        .frame(width: itemWidth)
                }
            }
            .fixedSize()
            .offset(x: currentOffset)
            .mask(Capsule().frame(width: 120, height: 44))
        }
        .frame(width: 300, height: 44)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { val in
                    if !isDragging {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isDragging = true
                        }
                    }
                    dragOffset = val.translation.width * 0.75
                }
                .onEnded { val in
                    let movement = val.translation.width + val.predictedEndTranslation.width * 0.2
                    let indexShift = -Int(round(movement / itemWidth))
                    let newIndex = min(max(selectedIndex + indexShift, 0), modes.count - 1)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedIndex = newIndex
                        dragOffset = 0
                        isDragging = false
                    }
                    onModeChanged(modes[newIndex])
                }
        )
        .onTapGesture {
            let currentMode = modes[selectedIndex]
            if currentMode == "PHOTO" || currentMode == "HUMAN" {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCategoryMenu = true
                }
            }
        }
    }
}