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
    @State private var showCategoryMenu: Bool = false // Şeffaf Menü Kontrolü
    
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
    @State private var studioLight: String = "Natural"
    
    // SIDEBAR & DİŞLİ ÇARK
    @State private var isSidebarOpen: Bool = false
    @State private var gearAngle: Double = 0.0
    
    // Pinch Zoom
    @State private var baseZoomOnPinch: Double = 1.0
    
    // Kategoriye Göre Aktif Olan Alt Modlar
    // NOT: Tek kaynaktan besleniyor — activeModesFor(_:) fonksiyonuyla senkronizasyon sorunu kalmadı.
    var activeModes: [String] {
        activeModesFor(currentCategory)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if cameraManager.isAuthorized {
                    // 1. KAMERA ÖNİZLEMESİ + PINCH TO ZOOM
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            if isQuickSettingsOpen {
                                withAnimation(.spring()) { isQuickSettingsOpen = false }
                            } else if isSidebarOpen {
                                withAnimation(.spring()) { isSidebarOpen = false }
                            } else {
                                // NOT: showCategoryMenu artık kendi tam ekran overlay'i
                                // üzerinden kapanıyor (bkz. categoryMenuOverlay), o yüzden
                                // burada ayrıca ele almaya gerek yok.
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
                    
                    // 2. SAĞ YAN MENÜ (Sidebar) VE SABİT DİŞLİ ÇARK
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            ZStack(alignment: .bottom) {
                                if isSidebarOpen {
                                    VStack(spacing: 20) {
                                        Button(action: {
                                            withAnimation { isAutoCaptureEnabled.toggle() }
                                        }) {
                                            VStack(spacing: 6) {
                                                Image(systemName: isAutoCaptureEnabled ? "a.circle.fill" : "a.circle")
                                                    .font(.system(size: 26, weight: .light))
                                                Text("Auto")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .foregroundColor(isAutoCaptureEnabled ? .yellow : .white)
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 30)
                                    .frame(width: 64, height: 280)
                                    .background(Color.black.opacity(0.25))
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: -5, y: 0)
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
                    
                    // 3. ALT KONTROL PANELİ
                    VStack(spacing: 0) {
                        Spacer()
                        
                        if isQuickSettingsOpen {
                            quickSettingsDrawer
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(.bottom, 10)
                        }
                        
                        if cameraManager.currentPosition == .back {
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
                        
                        // ZSTACK: Sabit Butonlar ve Mod Seçici Kapsül
                        // (Kategori menüsü artık burada DEĞİL — .overlay ile dışarıdan bindiriliyor,
                        // böylece bu ZStack'in layout boyutunu asla etkilemiyor ve hiçbir öğe kaymıyor.)
                        ZStack(alignment: .center) {
                            
                            // LAYER 1: AppleGlassModePicker
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
                            
                            // LAYER 2: Sabit Butonlar (Galeri ve Ön Kamera)
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
                        // LAYER 3: GENİŞ, ŞEFFAF, YERİNDEN OYNATMAYAN APPLE KATEGORİ MENÜSÜ
                        // .overlay -> base view'ın (yukarıdaki ZStack'in) layout boyutunu
                        // ASLA etkilemez. Bu yüzden shutter, zoom butonları, galeri/ön kamera
                        // ikonları menü açılınca kesinlikle yerinden oynamaz.
                        .overlay(alignment: .bottom) {
                            if showCategoryMenu {
                                categoryMenuOverlay
                            }
                        }
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
            .onChange(of: visionManager.framingAdvice) { _, _ in triggerVoiceCoach() }
            .onChange(of: visionManager.poseAdvice) { _, _ in triggerVoiceCoach() }
            .onChange(of: motionManager.currentRollState) { _, _ in triggerVoiceCoach() }
            .onChange(of: motionManager.currentPitchState) { _, _ in triggerVoiceCoach() }
        }
    }
    
    // MARK: - Kategori Menüsü Overlay
    
    /// Tam ekranı kaplayan, neredeyse görünmez bir "dokun-kapat" katmanı + ortada duran cam menü.
    /// Overlay olarak eklendiği için altındaki hiçbir layout'u itmez/kaydırmaz.
    private var categoryMenuOverlay: some View {
        ZStack {
            // Menü dışına dokununca kapansın (Apple/Control Center standardı)
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCategoryMenu = false
                    }
                }
            
            categoryMenuView
                .offset(y: -150) // Mod seçici kapsülünün üzerinde havada durması için
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
                    .contentShape(Rectangle()) // Tüm satırı tıklanabilir yapar
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
                    drawerButton(icon: "camera.filters", label: selectedFilter) { cycleFilter() }
                } else {
                    drawerButton(icon: "f.cursive.circle", label: "Aperture: \(apertureValue)", isYellow: true) { cycleAperture() }
                    drawerButton(icon: "lightbulb.fill", label: studioLight, isYellow: studioLight != "Natural") { cycleStudioLight() }
                    drawerButton(icon: "figure.stand", label: "Pose AI: \(isPoseAIOpen ? "On" : "Off")", isYellow: isPoseAIOpen) { isPoseAIOpen.toggle() }
                    drawerButton(icon: "timer", label: timerSetting == 0 ? "Timer: Off" : "\(timerSetting)s", isYellow: timerSetting > 0) { cycleTimer() }
                    drawerButton(icon: "camera.filters", label: selectedFilter) { cycleFilter() }
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
    private func cycleAperture() { let values = ["f/1.4", "f/2.0", "f/2.8", "f/4.0", "f/8.0"]; if let idx = values.firstIndex(of: apertureValue) { apertureValue = values[(idx + 1) % values.count] } }
    private func cycleStudioLight() { let lights = ["Natural", "Studio", "Contour", "Stage"]; if let idx = lights.firstIndex(of: studioLight) { studioLight = lights[(idx + 1) % lights.count] } }
    private func cycleFilter() { let filters = ["Original", "Vivid", "Warm", "Mono", "Noir"]; if let idx = filters.firstIndex(of: selectedFilter) { selectedFilter = filters[(idx + 1) % filters.count] } }
    
    private func triggerVoiceCoach() {
        voiceCoach.provideGuidance(framing: visionManager.framingAdvice, pose: visionManager.poseAdvice, roll: motionManager.currentRollState, pitch: motionManager.currentPitchState)
        checkAutoCapture()
    }
    
    private func takePhoto() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 } }
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
        guard isAutoCaptureEnabled else { return }
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
            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .bold, design: .rounded))
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

            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .frame(width: 120, height: 44)

            HStack(spacing: 0) {
                ForEach(0..<modes.count, id: \.self) { i in
                    Text(modes[i])
                        .font(.system(size: 15, weight: .black, design: .rounded))
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