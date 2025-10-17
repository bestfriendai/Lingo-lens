//
//  ARTranslationView.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI
import ARKit
import AVFoundation
import Translation

/// Main view for AR translation feature
/// Manages camera permission, AR session, detection box, and child views
struct ARTranslationView: View {
    
    // Tracks app state changes (foreground/background)
    @Environment(\.scenePhase) private var scenePhase
    
    // Main view model that handles AR state and logic
    @ObservedObject var arViewModel: ARViewModel
    
    // View model for expanding/collapsing settings panel
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Manages camera permission requests and state
    @StateObject private var cameraPermissionManager = CameraPermissionManager()
    
    // Tracks previous screen size for adjusting ROI on rotation
    @State private var previousSize: CGSize = .zero
    
    // Controls visibility of instructions sheet
    @State private var showInstructions = false
    
    // Prevents redundant AR session resumes
    @State private var alreadyResumedARSession = false
    
    // Controls alert about label reset when tab changes
    @State private var showAlertAboutReset = false
    
    // Tracks if view is currently visible
    @State private var isViewActive = false
    
    // Remembers user preference to not show reset warning
    @State private var neverShowAlertAboutReset = false

    // For handling device orientation changes
    @State private var currentOrientation = UIDevice.current.orientation
    
    @State private var orientationObserver: NSObjectProtocol? = nil

    // To show rating alert on 3rd launch
    // if instructions sheet needs to be presented
    // then we set it to false so that the instructions
    // sheet is not dismissed because of the alert
    @State private var showRatingAlert = false

    // Flag to track if UserDefaults have been loaded
    @State private var hasLoadedPreferences = false

    // Timer for cleaning up stale 2D overlays
    @State private var cleanupTimer: Timer? = nil

    // Access to translation service
    @EnvironmentObject var translationService: TranslationService

    var body: some View {
        NavigationStack {
            Group {
                if cameraPermissionManager.showPermissionAlert {
                    
                    // Show permission view if camera access not granted
                    CameraPermissionView(
                        openSettings: {
                            cameraPermissionManager.openAppSettings()
                        }
                    )
                } else {
                    ZStack {
                        mainARView
                            .withARErrorHandling()
                        
                        // Loading state while AR session initializes
                        if arViewModel.isARSessionLoading {
                            Color.black
                                .opacity(0.9)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.3)
                                    .tint(.white)
                                
                                Text(arViewModel.loadingMessage)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 4)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !cameraPermissionManager.showPermissionAlert {

                    // Clear translations button (leading side)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            SecureLogger.log("Clear translations button pressed", level: .info)
                            arViewModel.clearWordTranslations()
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15))
                                .foregroundColor(arViewModel.translationOverlays.isEmpty ? .gray : .red)
                                .accessibilityLabel("Clear Translations")
                                .accessibilityHint("Remove all translation overlays from screen")
                        }
                        .disabled(arViewModel.translationOverlays.isEmpty)
                    }

                    ToolbarItem(placement: .topBarTrailing) {

                        // Info button to show instructions
                        Button(action: {
                            SecureLogger.log("Translation info button pressed", level: .info)
                            arViewModel.isDetectionActive = false
                            arViewModel.detectedObjectName = ""
                            showInstructions = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .accessibilityLabel("Instructions")
                                .accessibilityHint("Learn how to use the Translate Feature")
                        }
                        .disabled(showInstructions)
                    }
                }
            }
        }
    
        .onAppear {
            isViewActive = true

            // Load preferences only once
            if !hasLoadedPreferences {
                neverShowAlertAboutReset = DataManager.shared.getNeverShowLabelRemovalWarning()
                if !DataManager.shared.hasDismissedInstructions() {
                    showRatingAlert = false
                } else {
                    showRatingAlert = DataManager.shared.shouldShowRatingPrompt()
                }
                hasLoadedPreferences = true
            }

            cameraPermissionManager.startChecking()

            // Setup AR session if permission is granted
            if !cameraPermissionManager.showPermissionAlert {
                DispatchQueue.main.async {
                    arViewModel.resetAnnotations()
                    arViewModel.resumeARSession()
                    alreadyResumedARSession = true

                    // Automatically start word translation mode after AR session loads
                    startWordTranslationAfterDelay()
                }
            }

            setupOrientationObserver()

            // Start cleanup timer for 2D overlays
            startCleanupTimer()
        }

        // Observe camera permission changes
        .onChange(of: cameraPermissionManager.showPermissionAlert) { oldValue, newValue in
            
            // When permission changes from denied to granted
            if oldValue == true && newValue == false {
                
                DispatchQueue.main.async {
                    arViewModel.resetAnnotations()
                    arViewModel.resumeARSession()
                    alreadyResumedARSession = true
                }
            }
        }
        
        // Handle app state changes (background/foreground)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                
                // Resume AR session when app becomes active
                if isViewActive {
                    
                    if !cameraPermissionManager.isCheckingActive {
                        cameraPermissionManager.startChecking()
                    }
                    
                    if !alreadyResumedARSession {
                        if !cameraPermissionManager.showPermissionAlert {
                            arViewModel.resetAnnotations()
                            arViewModel.resumeARSession()
                        }
                    }
                }
                
            case .background:
                
                if isViewActive {
                    cameraPermissionManager.stopChecking()
                    
                    // Pause AR session when app goes to background
                    arViewModel.pauseARSession()
                    arViewModel.resetAnnotations()
                    alreadyResumedARSession = false
                    
                    // Show reset warning unless disabled
                    if !neverShowAlertAboutReset {
                        showAlertAboutReset = true
                    }
                }
                
            default:
                break
            }
        }
        .onDisappear {
            cameraPermissionManager.stopChecking()

            // Clean up when view disappears
            isViewActive = false
            arViewModel.pauseARSession()
            arViewModel.resetAnnotations()

            // PERSISTENT MODE: Clear all translation overlays when leaving AR tab
            // This ensures overlays don't persist across different AR sessions
            arViewModel.clearWordTranslations()

            // Show reset warning unless disabled
            if !neverShowAlertAboutReset {
                showAlertAboutReset = true
            }

            // Remove orientation observer properly
            if let token = orientationObserver {
                NotificationCenter.default.removeObserver(token)
                orientationObserver = nil
            }

            // Stop cleanup timer
            stopCleanupTimer()
        }
    }
    
    /// Main AR view that contains camera feed, detection UI, and controls
    private var mainARView: some View {
        ZStack {

            // AR camera view container
            ARViewContainer(arViewModel: arViewModel)

            // 2D Translation overlays (Google Translate-style fast mode)
            if arViewModel.use2DOverlays && arViewModel.isWordTranslationMode {
                translationOverlaysView
            }

            // Detection box overlay (only shown during manual object detection mode)
            if arViewModel.isDetectionActive && arViewModel.isObjectDetectionMode {
                boundingBoxView
                    .transition(.scale.combined(with: .opacity))
            }
            
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    if arViewModel.isDetectionActive && arViewModel.isObjectDetectionMode {
                        DetectionLabel(detectedObjectName: arViewModel.detectedObjectName)
                            .transition(.scale.combined(with: .opacity))
                    }

                    if arViewModel.isWordTranslationMode && !arViewModel.isObjectDetectionMode {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Live Translation")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    if arViewModel.showPlacementError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Text(arViewModel.placementErrorMessage)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.85))
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                        .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(.top, 16)
                .animation(.easeInOut(duration: 0.3), value: arViewModel.isDetectionActive)
                .animation(.easeInOut(duration: 0.3), value: arViewModel.isWordTranslationMode)
                .animation(.easeInOut(duration: 0.3), value: arViewModel.showPlacementError)

                Spacer()

                ControlBar(
                    arViewModel: arViewModel,
                    settingsViewModel: settingsViewModel
                )
                .padding(.bottom, 16)
            }
            
            // Overlay when deleting an annotation
            if arViewModel.isDeletingAnnotation {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.1)
                            .tint(.white)
                        Text("Removing label...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
                    )
                }
                .transition(.opacity)
                .zIndex(100)
            }
            
            // Settings panel (slides up from bottom)
            if settingsViewModel.isExpanded {
                SettingsPanel(
                    arViewModel: arViewModel,
                    settingsViewModel: settingsViewModel
                )
            }
        }
        
        .onAppear {
            withAnimation {
                if !DataManager.shared.hasDismissedInstructions() {
                    showInstructions = true
                }
            }
        }
        
        // Instructions sheet
        .sheet(isPresented: $showInstructions) {
            InstructionsView(ratingAlert: $showRatingAlert)
        }
        
        // Alert for rating the app
        .alert("Enjoying Lingo Lens?", isPresented: $showRatingAlert) {
            
            // Rate now button - takes user to App Store
            Button("Rate Now") {
                
                DataManager.shared.markRatingPromptAsShown()
                
                // Open App Store - replace with your app ID
                if let url = URL(string: "https://apps.apple.com/") {
                    UIApplication.shared.open(url)
                }
            }
            
            // Later button - just dismisses for now
            Button("Later") {
                DataManager.shared.markRatingPromptAsShown()
            }
            
            // Don't ask again button
            Button("Don't Ask Again", role: .cancel) {
                DataManager.shared.setNeverAskForRating()
                DataManager.shared.markRatingPromptAsShown()
            }
        } message: {
            Text("If you enjoy using our app, would you mind taking a moment to rate it? It won't take more than a minute. Thanks for your support!")
        }
        
        // Alert about label removal when leaving tab
        .alert("Label Removal Warning", isPresented: $showAlertAboutReset) {
            Button("Ok") {}
            Button("Don't Warn Again", role: .cancel) {
                DataManager.shared.saveNeverShowLabelRemovalWarning(true)
                neverShowAlertAboutReset = true
            }
        } message: {
            Text("Whenever you leave the Translate tab, all labels will be removed from the objects in the real world.")
        }
        
        // Alert to confirm annotation deletion
        .alert("Remove Label", isPresented: $arViewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                arViewModel.annotationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                arViewModel.deleteAnnotation()
            }
        } message: {
            Text("Remove the \"\(arViewModel.annotationNameToDelete)\" label?")
        }
        
        // Smooth animation for error messages
        .animation(.easeInOut, value: arViewModel.showPlacementError)
        
        // Annotation detail sheet (shows translation)
        .sheet(isPresented: $arViewModel.isShowingAnnotationDetail) {
            if let originalText = arViewModel.selectedAnnotationText {
                AnnotationDetailView(
                    originalText: originalText,
                    targetLanguage: arViewModel.selectedLanguage
                )
                .environmentObject(translationService)
            }
        }

        // Translation task for automatic word translation
        .background(wordTranslationBackground)
    }

    /// Background view that handles batch word translation via translationTask
    private var wordTranslationBackground: some View {
        Group {
            if let config = arViewModel.wordTranslationConfiguration {
                Text("")
                    .translationTask(config) { session in
                        // Process translations for pending words
                        for await pendingWords in arViewModel.$pendingWordTranslations.values {
                            guard !pendingWords.isEmpty else { continue }

                            print("🔄 Translating \(pendingWords.count) phrases...")

                            // Translate each word
                            for word in pendingWords {
                                                var shouldTranslate = true

                                                await MainActor.run {
                                                    guard let sceneView = arViewModel.sceneView else { return }

                                                    let newPosition = convertVisionToScreen(
                                                        boundingBox: word.boundingBox,
                                                        sceneView: sceneView
                                                    )

                                                    let wordLowercased = word.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                                                    if let existingEntry = arViewModel.translationOverlays.first(where: { _, overlay in
                                                        let existingText = overlay.originalWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                                        return existingText == wordLowercased
                                                    }) {
                                                        var updatedOverlay = existingEntry.value
                                                        updatedOverlay.updatePosition(newPosition)
                                                        updatedOverlay.lastSeenTime = Date()
                                                        arViewModel.translationOverlays[existingEntry.key] = updatedOverlay
                                                        shouldTranslate = false
                                                    }
                                                }

                                                if !shouldTranslate {
                                                    continue
                                                }

                                do {
                                    let response = try await session.translate(word.text)
                                    let translation = response.targetText

                                    await MainActor.run {
                                        guard let sceneView = arViewModel.sceneView else { return }

                                        if arViewModel.use2DOverlays {
                                            // GOOGLE TRANSLATE MODE: Simple 2D overlays with direct position mapping
                                            // No 3D anchoring needed - just map Vision coordinates to screen coordinates
                                            let screenPosition = convertVisionToScreen(
                                                boundingBox: word.boundingBox,
                                                sceneView: sceneView
                                            )

                                            // Calculate overlay size from original text bounding box
                                            let overlaySize = calculateOverlaySize(
                                                boundingBox: word.boundingBox,
                                                sceneView: sceneView
                                            )

                                            // Calculate font size to match original text height
                                            let fontSize = calculateFontSize(
                                                for: overlaySize.height,
                                                text: translation
                                            )

                                            // Create simple 2D overlay (no 3D world position needed)
                                            var overlay = TranslationOverlay2D(
                                                id: word.id,
                                                originalWord: word.text,
                                                translatedText: translation,
                                                screenPosition: screenPosition,
                                                boundingBox: word.boundingBox,
                                                lastSeenTime: Date(),
                                                isSingleWord: word.isSingleWord,
                                                wordCount: word.wordCount,
                                                originalSize: overlaySize,
                                                calculatedFontSize: fontSize,
                                                worldPosition: nil  // Not needed for Google Translate-style
                                            )

                                            overlay.updatePosition(screenPosition)
                                            arViewModel.translationOverlays[word.id] = overlay
                                            let typeLabel = word.isSingleWord ? "WORD" : "PHRASE(\(word.wordCount))"
                                            print("✅ Overlay [\(typeLabel)]: \(word.text) → \(translation) | Size: \(overlaySize) | Font: \(fontSize)pt")
                                        } else {
                                            // SLOW MODE: 3D AR anchors (persistent)
                                            let screenWidth = sceneView.bounds.width
                                            let screenHeight = sceneView.bounds.height

                                            let screenX = word.boundingBox.midX * screenWidth
                                            let screenY = (1.0 - word.boundingBox.midY) * screenHeight

                                            let screenPoint = CGPoint(x: screenX, y: screenY)

                                            arViewModel.addWordTranslation(
                                                word: word,
                                                translation: translation,
                                                at: screenPoint
                                            )
                                            print("✅ 3D Anchor: \(word.text) → \(translation)")
                                        }
                                    }
                                } catch {
                                    print("❌ Translation failed for '\(word.text)': \(error.localizedDescription)")
                                }
                            }

                            // Clear pending translations
                            await MainActor.run {
                                arViewModel.pendingWordTranslations.removeAll()
                            }
                        }
                    }
            }
        }
        .hidden()
    }

    /// View that renders 2D translation overlays (Google Translate-style)
    private var translationOverlaysView: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(arViewModel.translationOverlays.values), id: \.id) { overlay in
                    let halfWidth = overlay.originalSize.width / 2
                    let halfHeight = overlay.originalSize.height / 2
                    let margin: CGFloat = 10
                    
                    let isInBounds = overlay.screenPosition.x - halfWidth > -margin &&
                                    overlay.screenPosition.x + halfWidth < geometry.size.width + margin &&
                                    overlay.screenPosition.y - halfHeight > -margin &&
                                    overlay.screenPosition.y + halfHeight < geometry.size.height + margin

                    if !overlay.isStale && isInBounds {
                        Text(overlay.translatedText)
                            .font(.system(size: overlay.fontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(width: max(overlay.originalSize.width, 40), 
                                   height: max(overlay.originalSize.height, 20))
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.97))
                                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                                    )
                            )
                            .position(overlay.screenPosition)
                            .transition(.opacity)
                            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: overlay.screenPosition)
                            .id(overlay.id)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    /// Converts Vision framework normalized coordinates to screen coordinates
    /// Accounts for ARSCNView's camera feed scaling and orientation
    private func convertVisionToScreen(boundingBox: CGRect, sceneView: ARSCNView) -> CGPoint {
        let screenWidth = sceneView.bounds.width
        let screenHeight = sceneView.bounds.height

        let orientation: UIInterfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait

        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let isPortraitUpsideDown = orientation == .portraitUpsideDown

        if isLandscape {
            if orientation == .landscapeRight {
                let screenX = boundingBox.midY * screenWidth
                let screenY = (1.0 - boundingBox.midX) * screenHeight
                return CGPoint(x: screenX, y: screenY)
            } else {
                let screenX = (1.0 - boundingBox.midY) * screenWidth
                let screenY = boundingBox.midX * screenHeight
                return CGPoint(x: screenX, y: screenY)
            }
        } else {
            if isPortraitUpsideDown {
                let screenX = (1.0 - boundingBox.midX) * screenWidth
                let screenY = boundingBox.midY * screenHeight
                return CGPoint(x: screenX, y: screenY)
            } else {
                let screenX = boundingBox.midX * screenWidth
                let screenY = (1.0 - boundingBox.midY) * screenHeight
                return CGPoint(x: screenX, y: screenY)
            }
        }
    }

    /// Calculates overlay size from Vision bounding box to match original text size
    /// This ensures translated text appears at the same size as the original detected text
    private func calculateOverlaySize(boundingBox: CGRect, sceneView: ARSCNView) -> CGSize {
        let screenWidth = sceneView.bounds.width
        let screenHeight = sceneView.bounds.height

        let orientation: UIInterfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait

        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight

        let rawWidth: CGFloat
        let rawHeight: CGFloat

        if isLandscape {
            rawWidth = boundingBox.height * screenWidth
            rawHeight = boundingBox.width * screenHeight
        } else {
            rawWidth = boundingBox.width * screenWidth
            rawHeight = boundingBox.height * screenHeight
        }

        let minWidth: CGFloat = 40
        let minHeight: CGFloat = 20
        let maxWidth = screenWidth * 0.8
        let maxHeight = screenHeight * 0.15

        let finalWidth = max(minWidth, min(rawWidth * 1.1, maxWidth))
        let finalHeight = max(minHeight, min(rawHeight * 1.15, maxHeight))

        return CGSize(width: finalWidth, height: finalHeight)
    }

    /// Calculates font size to match the original text height
    /// Uses the original text height to determine appropriate font size for translated text
    private func calculateFontSize(for originalHeight: CGFloat, text: String) -> CGFloat {
        let baseFontSize = originalHeight * 0.65
        
        let screenHeight = UIScreen.main.bounds.height
        let minFontSize: CGFloat = screenHeight > 700 ? 12 : 10
        let maxFontSize: CGFloat = screenHeight > 800 ? 48 : 38
        
        var fontSize = max(minFontSize, min(baseFontSize, maxFontSize))
        
        if text.count > 15 {
            fontSize *= 0.9
        } else if text.count > 25 {
            fontSize *= 0.8
        }
        
        return fontSize
    }

    /// View that handles the draggable detection box
    private var boundingBoxView: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .onAppear {
                        
                        if arViewModel.adjustableROI == .zero {
                            let boxSize: CGFloat = 200
                            let margin: CGFloat = 16

                            let maxBoxWidth = min(boxSize, geo.size.width - (2 * margin))
                            let maxBoxHeight = min(boxSize, geo.size.height - (2 * margin))
                            
                            arViewModel.adjustableROI = CGRect(
                                x: (geo.size.width - maxBoxWidth) / 2,
                                y: (geo.size.height - maxBoxHeight) / 2,
                                width: maxBoxWidth,
                                height: maxBoxHeight
                            )
                        }
                        previousSize = geo.size
                    }
                    .onChange(of: geo.size) { oldSize, newSize in
                        guard abs(oldSize.width - newSize.width) > 1 || abs(oldSize.height - newSize.height) > 1 else {
                            return
                        }

                        let adjustedROI = arViewModel.adjustableROI.resizedAndClamped(from: oldSize, to: newSize)
                        let constrainedROI = enforceMarginConstraints(adjustedROI, in: newSize)
                        
                        arViewModel.adjustableROI = constrainedROI
                        
                        previousSize = newSize
                    }
                
                AdjustableBoundingBox(
                    roi: $arViewModel.adjustableROI,
                    containerSize: geo.size
                )
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                arViewModel.isDetectionActive = false
                                arViewModel.isObjectDetectionMode = false
                                arViewModel.detectedObjectName = ""
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                        .accessibilityLabel("Close detection box")
                        .accessibilityHint("Exits object detection mode")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    /// Sets up observer for device orientation changes
    /// Adjusts detection box when orientation changes
    private func setupOrientationObserver() {
        // Remove any existing observer first
        if let token = orientationObserver {
            NotificationCenter.default.removeObserver(token)
            orientationObserver = nil
        }

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak arViewModel] _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isValidInterfaceOrientation && newOrientation != currentOrientation {
                currentOrientation = newOrientation

                Task { @MainActor in
                    guard let arViewModel = arViewModel, let sceneView = arViewModel.sceneView else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let oldContainerSize = previousSize
                        let newContainerSize = sceneView.bounds.size

                        // Only adjust if size changed significantly
                        guard abs(oldContainerSize.width - newContainerSize.width) > 1 ||
                              abs(oldContainerSize.height - newContainerSize.height) > 1 else {
                            return
                        }

                        let margin: CGFloat = 16

                        // Preserve ROI aspect ratio and relative center within margins
                        let currentROI = arViewModel.adjustableROI

                        let maxWidth = newContainerSize.width - (2 * margin)
                        let maxHeight = newContainerSize.height - (2 * margin)

                        // Compute original aspect safely
                        let aspect = max(currentROI.width, 1) / max(currentROI.height, 1)

                        // Maintain relative center inside margin-constrained area
                        let denomW = max(oldContainerSize.width - 2 * margin, 1)
                        let denomH = max(oldContainerSize.height - 2 * margin, 1)
                        let relativeX = (currentROI.midX - margin) / denomW
                        let relativeY = (currentROI.midY - margin) / denomH

                        // Fit preserving aspect
                        var newWidth = min(currentROI.width, maxWidth)
                        var newHeight = newWidth / aspect
                        if newHeight > maxHeight {
                            newHeight = maxHeight
                            newWidth = newHeight * aspect
                        }

                        // Compute new center using relative coordinates
                        let newMidX = margin + (relativeX * (newContainerSize.width - 2 * margin))
                        let newMidY = margin + (relativeY * (newContainerSize.height - 2 * margin))

                        var newROI = CGRect(
                            x: newMidX - (newWidth / 2),
                            y: newMidY - (newHeight / 2),
                            width: newWidth,
                            height: newHeight
                        )

                        // Ensure box stays within screen margins
                        newROI = enforceMarginConstraints(newROI, in: newContainerSize)

                        arViewModel.adjustableROI = newROI
                        previousSize = newContainerSize
                    }
                }
            }
        }
    }
    
    /// Ensures detection box stays within screen margins
    /// Enforces minimum size and maximum boundaries
    private func enforceMarginConstraints(_ rect: CGRect, in containerSize: CGSize) -> CGRect {
        let margin: CGFloat = 16
        let minBoxSize: CGFloat = 100

        var newRect = rect

        // Enforce minimum and maximum width
        newRect.size.width = max(minBoxSize, min(newRect.size.width, containerSize.width - (2 * margin)))
        newRect.size.height = max(minBoxSize, min(newRect.size.height, containerSize.height - (2 * margin)))

        // Enforce margin constraints for origin
        newRect.origin.x = max(margin, min(newRect.origin.x, containerSize.width - newRect.size.width - margin))
        newRect.origin.y = max(margin, min(newRect.origin.y, containerSize.height - newRect.size.height - margin))

        return newRect
    }

    /// Automatically starts word translation mode after AR session is ready
    private func startWordTranslationAfterDelay() {
        // Wait for AR session to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard self.arViewModel.isWordTranslationMode else { return }
            guard !self.arViewModel.isARSessionLoading else {
                // If still loading, try again
                self.startWordTranslationAfterDelay()
                return
            }

            print("🚀 Auto-starting word translation mode for restaurant menu use case")

            // Check if language is downloaded
            Task {
                let isDownloaded = await self.translationService.isLanguageDownloaded(
                    language: self.arViewModel.selectedLanguage
                )

                await MainActor.run {
                    if isDownloaded {
                        // Prepare translation configuration for word translation
                        self.arViewModel.wordTranslationConfiguration = TranslationSession.Configuration(
                            source: self.translationService.sourceLanguage,
                            target: self.arViewModel.selectedLanguage.locale
                        )

                        print("✅ Word translation mode started successfully")
                    } else {
                        print("⚠️ Language not downloaded - user needs to download manually")
                        // Keep mode on but translations won't work until language is downloaded
                    }
                }
            }
        }
    }

    /// Starts periodic cleanup of stale 2D overlays
    private func startCleanupTimer() {
        // Persistent mode: Clean up less frequently since overlays last longer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak arViewModel] _ in
            Task { @MainActor in
                arViewModel?.cleanupStaleOverlays()
            }
        }
    }

    /// Stops the cleanup timer
    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}

#Preview("Normal State") {
    let mockTranslationService = TranslationService()
    mockTranslationService.availableLanguages = [
        AvailableLanguage(locale: .init(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: .init(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: .init(languageCode: "de", region: "DE"))
    ]
    
    let arVM = ARViewModel()
    
    return ARTranslationView(arViewModel: arVM)
        .environmentObject(mockTranslationService)
        .environmentObject(AppearanceManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Active Detection") {
    let mockTranslationService = TranslationService()
    mockTranslationService.availableLanguages = [
        AvailableLanguage(locale: .init(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: .init(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: .init(languageCode: "de", region: "DE"))
    ]
    
    let arVM = ARViewModel()
    arVM.isDetectionActive = true
    arVM.detectedObjectName = "Coffee Cup"
    arVM.adjustableROI = CGRect(x: 100, y: 100, width: 200, height: 200)
    
    return ARTranslationView(arViewModel: arVM)
        .environmentObject(mockTranslationService)
        .environmentObject(AppearanceManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Settings Expanded") {
    let mockTranslationService = TranslationService()
    mockTranslationService.availableLanguages = [
        AvailableLanguage(locale: .init(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: .init(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: .init(languageCode: "de", region: "DE"))
    ]
    
    let arVM = ARViewModel()
    let settingsVM = SettingsViewModel()
    settingsVM.isExpanded = true
    
    return ARTranslationView(arViewModel: arVM)
        .environmentObject(mockTranslationService)
        .environmentObject(AppearanceManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

