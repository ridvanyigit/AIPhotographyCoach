import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var cameraManager = CameraManager()
    @State private var visionManager = VisionManager()
    @State private var motionManager = MotionManager()
    @State private var voiceCoach = VoiceCoachManager()
    private let selfieCoach = SelfieCoach()

    // UI state
    @State private var isVoiceCoachMuted: Bool = true // Off by default
    @State private var isAutoCaptureEnabled: Bool = false // Off by default
    @State private var flashOpacity: Double = 0.0
    @State private var capturedImage: UIImage? = nil
    @State private var lastSavedImage: UIImage? = nil
    @State private var lastCaptureQuality: CaptureQuality? = nil
    @State private var pendingCaptureQuality: CaptureQuality? = nil
    @State private var isShowingPreview: Bool = false
    @State private var isAnimatingCapturedImage: Bool = false
    @State private var lastCaptureTime: Date = Date.distantPast
    @State private var previousScreenBrightness: CGFloat? = nil

    // Auto-lock progress (0.0 -> 1.0)
    @State private var autoLockProgress: Double = 0.0

    // Sidebar & settings
    @State private var isSidebarOpen: Bool = false
    @State private var timerSeconds: Int = 0
    @State private var showGrid: Bool = false
    @State private var selfieFilter: SelfieFilter = .none
    @State private var aspectRatio: SelfieAspectRatio = .full
    @State private var flashMode: FlashMode = .off

    // Lighting mode, selected from the swipeable carousel above the shutter
    @State private var selfieLightingMode: SelfieLightingMode = .natural
    @State private var lightingDragOffset: CGFloat = 0

    // Countdown
    @State private var isCountingDown: Bool = false
    @State private var countdownRemaining: Int = 0
    @State private var timerTask: Task<Void, Never>? = nil

    private var currentFace: FaceLandmarkData? { visionManager.faceLandmarks.first }

    private var currentStability: StabilityInfo {
        StabilityInfo(isStable: motionManager.isStable, angularVelocity: motionManager.smoothedAngularVelocity)
    }

    // Face-only evaluation — the phone's physical orientation never factors in.
    // Auto-capture only ever fires when this resolves to `.perfect`.
    private var currentPose: SelfiePose {
        selfieCoach.evaluate(face: currentFace)
    }

    // Light-source evaluation — only meaningful once the pose is already perfect,
    // but computed here regardless so the badge/compass can react immediately.
    private var currentLighting: LightingGuidance {
        selfieCoach.evaluateLighting(visionManager.lightingAnalysis)
    }

    // Auto-capture requires BOTH the pose and the light source to be dead-on —
    // manual shooting is unaffected and always available.
    private var isReadyForAutoCapture: Bool {
        currentPose.state == .perfect && currentLighting.state == .perfect
    }

    private var currentQuality: CaptureQuality {
        selfieCoach.computeQuality(face: currentFace, lightingGuidance: currentLighting, stability: currentStability)
    }

    // Live approximation of the selected filter, applied directly to the camera preview
    private var previewSaturation: Double {
        switch selfieFilter {
        case .vivid: return 1.35
        case .mono: return 0.0
        default: return 1.0
        }
    }

    private var previewContrast: Double {
        selfieFilter == .vivid ? 1.08 : 1.0
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
                    FullScreenImageView(image: imageToView, quality: lastCaptureQuality, onDelete: { lastSavedImage = nil; lastCaptureQuality = nil })
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
            // 1. Camera preview, with the selected filter approximated live
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
                .saturation(previewSaturation)
                .contrast(previewContrast)

            // 2. Warm/cool filter tint (approximated live; the final photo gets the
            // precise Core Image version instead)
            if selfieFilter == .warm {
                Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.10)
                    .blendMode(.overlay).ignoresSafeArea().allowsHitTesting(false)
            } else if selfieFilter == .cool {
                Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.10)
                    .blendMode(.overlay).ignoresSafeArea().allowsHitTesting(false)
            }

            // 3. Selfie lighting mode: soft colored screen glow acting as fill light
            if selfieLightingMode.isActive {
                RoundedRectangle(cornerRadius: 32)
                    .stroke(selfieLightingMode.glowColor.opacity(selfieLightingMode.glowOpacity), lineWidth: selfieLightingMode.glowLineWidth)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: selfieLightingMode)
            }

            // 4. Realistic phone-shaped orientation guide — driven entirely by the
            // FACE, never by the phone's physical tilt. The guide phone itself
            // tilts/shifts to mirror the current deviation; it settles upright and
            // glows once Perfect (dead-center) is eligible for auto-capture.
            SelfieGuidanceView(
                state: currentPose.state,
                hasFace: currentPose.hasFace,
                rollDegrees: currentPose.rollDegrees,
                verticalDegrees: currentPose.verticalDegrees,
                showGrid: showGrid
            )
            .ignoresSafeArea()

            // 5. Coaching header: quality score, coaching text, sidebar toggle, tips —
            // all aligned in the same top row
            VStack(spacing: 10) {
                ZStack {
                    coachingBadge

                    HStack {
                        qualityScoreBadge
                        Spacer()
                        multipleFacesBadge
                        sidebarToggleButton
                    }
                }
                .padding(.horizontal, 16)

                lightingTipBanner

                Spacer()
            }
            .padding(.top, 15)

            // 6. Lighting carousel, shutter & auto-lock ring
            bottomControlsLayer

            // 7. Flash & capture animations
            captureAnimationsLayer(geometry: geometry)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSidebarOpen {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isSidebarOpen = false }
            }
        }
    }

    // Plain (non-ViewBuilder) computation of what the badge should show. Kept
    // outside the @ViewBuilder body below because ordinary if/else assignment
    // statements aren't valid inside a ViewBuilder context (only view-producing
    // expressions are), which is what caused the "Type '()' cannot conform to
    // 'View'" build error here.
    private var coachingContent: (icon: String, text: String, isFullyPerfect: Bool, showsWarmTint: Bool) {
        let pose = currentPose
        let lighting = currentLighting
        let isPoseReady = pose.state == .perfect
        let isFullyPerfect = isPoseReady && lighting.state == .perfect

        // Two-stage coaching: nail the pose first, then — once it's dead-center —
        // switch over to guiding the light source instead.
        let icon: String
        let text: String
        if !isPoseReady {
            icon = pose.state.systemIcon
            text = pose.state.message
        } else if lighting.state != .perfect {
            icon = "light.max"
            text = lighting.hint ?? lighting.state.message
        } else {
            icon = "checkmark.circle.fill"
            text = "Perfect ✨"
        }

        let showsWarmTint = (pose.state == .veryGood) || (isPoseReady && lighting.state == .veryGood)

        return (icon, text, isFullyPerfect, showsWarmTint)
    }

    @ViewBuilder private var coachingBadge: some View {
        let content = coachingContent

        HStack(spacing: 8) {
            Image(systemName: content.icon)
                .font(.system(size: 15, weight: .bold))
            Text(content.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundColor(content.isFullyPerfect ? .black : .white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background {
            if content.isFullyPerfect {
                Capsule().fill(Color.yellow)
            } else {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(content.showsWarmTint ? Color.yellow.opacity(0.22) : Color.clear))
            }
        }
        .overlay(Capsule().stroke(content.isFullyPerfect ? Color.clear : Color.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: content.isFullyPerfect ? Color.yellow.opacity(0.6) : Color.black.opacity(0.25), radius: 10, y: 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: content.text)
    }

    // Live 0...100 AI quality score, shown whenever a face is being tracked.
    @ViewBuilder private var qualityScoreBadge: some View {
        if currentFace != nil {
            let quality = currentQuality
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 12, weight: .bold))
                Text("\(quality.overallScore)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundColor(scoreColor(for: quality.overallScore))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: quality.overallScore)
        }
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 85...: return .yellow
        case 60..<85: return .white
        default: return .white.opacity(0.55)
        }
    }

    // Non-blocking warning if a second/third face wanders into frame
    @ViewBuilder private var multipleFacesBadge: some View {
        if (currentFace?.totalFacesDetected ?? 1) > 1 {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                Text("Multiple faces")
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity)
        }
    }

    // Actionable low-light hint: one tap switches straight to Studio lighting mode.
    // Driven directly by the camera's own exposure reading, independent of the
    // coaching state, so it can show up any time a face is present and it's dark.
    @ViewBuilder private var lightingTipBanner: some View {
        if currentFace != nil && cameraManager.lightingCondition == .tooDark && selfieLightingMode != .studio {
            Button(action: {
                withAnimation(.spring()) { selfieLightingMode = .studio }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.max.fill")
                    Text("Tap to enable Studio Light")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.yellow, in: Capsule())
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cameraManager.lightingCondition)
        }
    }

    // MARK: - Sidebar (top-right, aligned with the coaching header)
    @ViewBuilder private var sidebarToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isSidebarOpen.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isSidebarOpen ? .yellow : .white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        }
        .overlay(alignment: .top) {
            if isSidebarOpen {
                VStack(spacing: 18) {
                    sidebarButton(icon: "timer", label: timerSeconds == 0 ? "Off" : "\(timerSeconds)s", color: timerSeconds > 0 ? .yellow : .white) {
                        timerSeconds = timerSeconds == 0 ? 3 : (timerSeconds == 3 ? 10 : 0)
                    }
                    sidebarButton(icon: showGrid ? "grid" : "grid.circle", label: "Grid", color: showGrid ? .yellow : .white.opacity(0.5)) {
                        showGrid.toggle()
                    }
                    sidebarButton(icon: selfieFilter.icon, label: selfieFilter.displayName, color: selfieFilter == .none ? .white.opacity(0.5) : .yellow) {
                        cycleFilter()
                    }
                    sidebarButton(icon: aspectRatio.icon, label: aspectRatio.displayName, color: aspectRatio == .full ? .white.opacity(0.5) : .yellow) {
                        cycleAspectRatio()
                    }
                    sidebarButton(icon: flashMode.icon, label: flashMode.displayName, color: flashMode == .off ? .white.opacity(0.5) : .yellow) {
                        cycleFlashMode()
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                .offset(y: 50)
                .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
            }
        }
    }

    private func sidebarButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            .frame(width: 40)
        }
    }

    // MARK: - Settings cycling
    private func cycleFilter() {
        let all = SelfieFilter.allCases
        let idx = all.firstIndex(of: selfieFilter) ?? 0
        selfieFilter = all[(idx + 1) % all.count]
    }

    private func cycleAspectRatio() {
        let all = SelfieAspectRatio.allCases
        let idx = all.firstIndex(of: aspectRatio) ?? 0
        aspectRatio = all[(idx + 1) % all.count]
    }

    private func cycleFlashMode() {
        let all = FlashMode.allCases
        let idx = all.firstIndex(of: flashMode) ?? 0
        flashMode = all[(idx + 1) % all.count]
    }

    @ViewBuilder private var bottomControlsLayer: some View {
        VStack {
            Spacer()

            // Selfie lighting mode: a swipeable, steering-wheel style carousel —
            // icons only, no background shapes, selected mode always centered
            lightingModeCarousel

            // Shutter & auto-lock progress ring
            ZStack {
                ShutterButtonView(action: startCaptureFlow)

                // Circular auto-lock progress ring (Apple-style)
                if isAutoCaptureEnabled && autoLockProgress > 0.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(autoLockProgress))
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.08), value: autoLockProgress)
                }

                HStack {
                    // LEFT: Voice coach toggle
                    Button(action: {
                        withAnimation(.spring()) {
                            isVoiceCoachMuted.toggle()
                            if isVoiceCoachMuted { voiceCoach.stop() }
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(!isVoiceCoachMuted ? Color.yellow : Color.white.opacity(0.3), lineWidth: !isVoiceCoachMuted ? 2 : 1))

                            VStack(spacing: 2) {
                                Image(systemName: !isVoiceCoachMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(!isVoiceCoachMuted ? "VOICE" : "MUTED")
                                    .font(.system(size: 7, weight: .black, design: .rounded))
                            }
                            .foregroundColor(!isVoiceCoachMuted ? .yellow : .white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 30)

                    Spacer()

                    // RIGHT: Auto-capture toggle
                    Button(action: {
                        withAnimation(.spring()) {
                            isAutoCaptureEnabled.toggle()
                            if !isAutoCaptureEnabled { autoLockProgress = 0.0 }
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(isAutoCaptureEnabled ? Color.yellow : Color.white.opacity(0.3), lineWidth: isAutoCaptureEnabled ? 2 : 1))

                            VStack(spacing: 2) {
                                Image(systemName: isAutoCaptureEnabled ? "a.circle.fill" : "a.circle")
                                    .font(.system(size: 18, weight: .bold))
                                Text("AUTO")
                                    .font(.system(size: 7, weight: .black, design: .rounded))
                            }
                            .foregroundColor(isAutoCaptureEnabled ? .yellow : .white.opacity(0.85))
                        }
                    }
                    .padding(.trailing, 30)
                }
                .frame(width: 320)
            }
            .padding(.bottom, 20)

            // Gallery preview & camera flip
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
                    visionManager.isFrontCamera = (cameraManager.currentPosition == .front)
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
            .padding(.bottom, 30)
        }
    }

    // Steering-wheel style lighting mode picker: icons only, no background shapes,
    // arranged along a shallow downward-curving arc (peak at the selected item, like
    // looking up at the top rim of a wheel) so the selected mode sits highest/closest
    // and neighbors dip down on either side. Drag left/right to change modes, with a
    // live, finger-tracking scale/fade.
    @ViewBuilder private var lightingModeCarousel: some View {
        let modes = SelfieLightingMode.allCases
        let dragSensitivity: CGFloat = 54       // px of drag per one item
        let anglePerItem: Double = 22.0 * (.pi / 180.0)
        let arcRadius: CGFloat = 150
        let selectedIndex = modes.firstIndex(of: selfieLightingMode) ?? 0

        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let baselineY: CGFloat = 24

            ZStack {
                ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                    let distance = CGFloat(index - selectedIndex) + (lightingDragOffset / dragSensitivity)
                    let isSelected = abs(distance) < 0.5
                    let proximity = max(0, 1 - abs(distance) * 0.6)
                    let angle = Double(distance) * anglePerItem
                    let xOffset = arcRadius * CGFloat(sin(angle))
                    let yOffset = arcRadius * CGFloat(1 - cos(angle)) // dips downward off-center

                    VStack(spacing: 3) {
                        Image(systemName: mode.icon)
                            .font(.system(size: isSelected ? 22 : 16, weight: .semibold))
                        if isSelected {
                            Text(mode.displayName)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .transition(.opacity)
                        }
                    }
                    .foregroundColor(isSelected ? .yellow : .white.opacity(max(0.2, proximity)))
                    .scaleEffect(isSelected ? 1.15 : max(0.8, proximity))
                    .position(x: centerX + xOffset, y: baselineY + yOffset)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        lightingDragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 24
                        var newIndex = selectedIndex
                        if value.translation.width < -threshold {
                            newIndex = min(newIndex + 1, modes.count - 1)
                        } else if value.translation.width > threshold {
                            newIndex = max(newIndex - 1, 0)
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selfieLightingMode = modes[newIndex]
                            lightingDragOffset = 0
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
        }
        .frame(height: 92)
        .padding(.horizontal, 40)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: lightingDragOffset)
    }

    @ViewBuilder private func captureAnimationsLayer(geometry: GeometryProxy) -> some View {
        if isCountingDown {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                Text("\(countdownRemaining)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.7), radius: 10)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 0.3), value: countdownRemaining)
            }
            .allowsHitTesting(true)
            .onTapGesture { cancelCountdown() }
        }

        Color.white.opacity(flashOpacity).ignoresSafeArea().allowsHitTesting(false)

        if let image = capturedImage {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .scaleEffect(isAnimatingCapturedImage ? 0.1 : 1.0)
                .offset(
                    x: isAnimatingCapturedImage ? -(geometry.size.width / 2.5) : 0,
                    y: isAnimatingCapturedImage ? (geometry.size.height / 2.2) : 0
                )
                .opacity(isAnimatingCapturedImage ? 0.0 : 1.0)
                .cornerRadius(isAnimatingCapturedImage ? 100 : 0)
                .ignoresSafeArea().allowsHitTesting(false)
        }
    }

    @ViewBuilder private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash.fill").font(.system(size: 60)).foregroundColor(.red)
            Text("Camera Access Required").font(.headline).foregroundColor(.white)
        }
    }

    // MARK: - Lifecycle & Auto-Lock Engine
    private func handleOnAppear() {
        cameraManager.checkPermission()
        visionManager.isFrontCamera = (cameraManager.currentPosition == .front)
        motionManager.startUpdates()
        cameraManager.onPhotoCaptured = { image in triggerPhotoAnimation(with: image) }
        cameraManager.onFrameAvailable = { pixelBuffer in
            visionManager.processFrame(pixelBuffer)
            DispatchQueue.main.async {
                let pose = self.currentPose
                let lighting = self.currentLighting
                if !isVoiceCoachMuted && !self.isCountingDown {
                    self.voiceCoach.provideGuidance(
                        poseState: pose.state,
                        lightingHint: pose.state == .perfect ? lighting.hint : nil
                    )
                }
                self.handleAutoLockCapture(isReady: self.isReadyForAutoCapture)
            }
        }
    }

    private func handleOnDisappear() {
        cameraManager.stopSession()
        motionManager.stopUpdates()
        voiceCoach.stop()
    }

    private func handlePreviewChange(_ isPresented: Bool) {
        if isPresented {
            cameraManager.stopSession(); motionManager.stopUpdates(); voiceCoach.stop()
        } else if scenePhase == .active {
            cameraManager.startSession(); motionManager.startUpdates()
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if !isShowingPreview && cameraManager.isAuthorized {
                cameraManager.startSession(); motionManager.startUpdates()
            }
        } else {
            cameraManager.stopSession(); motionManager.stopUpdates(); voiceCoach.stop()
        }
    }

    // Auto-capture engine: fills a progress ring once BOTH the pose AND the light
    // source are perfect, then fires quickly — but requires a couple of consecutive
    // good frames (not just one lucky noisy sample) before it commits, so a shaky
    // near-miss can't slip through and get auto-captured as "Perfect".
    private func handleAutoLockCapture(isReady: Bool) {
        guard isAutoCaptureEnabled && !isCountingDown else {
            autoLockProgress = 0.0
            return
        }

        if isReady {
            let now = Date()
            guard now.timeIntervalSince(lastCaptureTime) > 1.8 else { return }

            if autoLockProgress < 1.0 {
                autoLockProgress += 0.4
                if autoLockProgress >= 1.0 {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    lastCaptureTime = now
                    autoLockProgress = 0.0
                    startCaptureFlow()
                }
            }
        } else {
            autoLockProgress = max(0.0, autoLockProgress - 0.12)
        }
    }

    private func startCaptureFlow() {
        guard !isCountingDown else { return }
        if timerSeconds > 0 {
            isCountingDown = true
            countdownRemaining = timerSeconds
            timerTask = Task { @MainActor in
                while countdownRemaining > 0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    countdownRemaining -= 1
                }
                isCountingDown = false
                executeCapture()
            }
        } else {
            executeCapture()
        }
    }

    private func cancelCountdown() {
        timerTask?.cancel()
        isCountingDown = false
        countdownRemaining = 0
        autoLockProgress = 0.0
    }

    private func executeCapture() {
        // Snapshot the quality metrics at the moment of capture so we can show the
        // user genuine feedback on the resulting photo, not a generic label.
        pendingCaptureQuality = selfieCoach.computeQuality(face: currentFace, lightingGuidance: currentLighting, stability: currentStability)

        let shouldFireFlash = flashMode == .on || (flashMode == .auto && cameraManager.lightingCondition == .tooDark)

        if shouldFireFlash {
            // Simulate a front-camera flash the way Apple's own Camera app does: briefly
            // max out screen brightness to act as a light source, give the sensor a beat
            // to adjust exposure, then fire the shutter.
            previousScreenBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            withAnimation(.easeIn(duration: 0.15)) { flashOpacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                fireShutter()
            }
        } else {
            withAnimation(.linear(duration: 0.1)) { flashOpacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 }
            }
            fireShutter()
        }
    }

    private func fireShutter() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        cameraManager.capturePhoto()
    }

    private func triggerPhotoAnimation(with rawImage: UIImage) {
        // Apply the selected creative filter and aspect-ratio crop, then save
        // immediately — the user never needs to hold their pose after the shutter
        // fires, the photo is already processed and on its way to the library.
        let processedImage = SelfieImageProcessor.process(rawImage, filter: selfieFilter, aspect: aspectRatio)
        UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)

        if let previousBrightness = previousScreenBrightness {
            UIScreen.main.brightness = previousBrightness
            previousScreenBrightness = nil
        }
        withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0.0 }

        capturedImage = processedImage
        isAnimatingCapturedImage = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isAnimatingCapturedImage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                lastSavedImage = processedImage
                lastCaptureQuality = pendingCaptureQuality
                capturedImage = nil
            }
        }
    }
}
