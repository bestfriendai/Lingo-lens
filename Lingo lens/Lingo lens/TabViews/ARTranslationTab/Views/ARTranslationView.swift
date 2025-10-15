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
                                .opacity(0.8)
                            
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                
                                Text(arViewModel.loadingMessage)
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                    .padding(.top, 10)
                                    .opacity(0.8)
                            }
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

                    // Automatically start auto-translate mode after AR session loads
                    startAutoTranslateAfterDelay()
                }
            }

            setupOrientationObserver()
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

            // Show reset warning unless disabled
            if !neverShowAlertAboutReset {
                showAlertAboutReset = true
            }

            // Remove orientation observer properly
            if let token = orientationObserver {
                NotificationCenter.default.removeObserver(token)
                orientationObserver = nil
            }
        }
    }
    
    /// Main AR view that contains camera feed, detection UI, and controls
    private var mainARView: some View {
        ZStack {
            
            // AR camera view container
            ARViewContainer(arViewModel: arViewModel)
            
            // Detection box overlay (only shown when detection is active)
            if arViewModel.isDetectionActive {
                boundingBoxView
            }
            
            VStack {

                // Top section - shows detection status
                if arViewModel.isDetectionActive && !arViewModel.isAutoTranslateMode {
                    DetectionLabel(detectedObjectName: arViewModel.detectedObjectName)
                        .padding(.top, 10)
                }

                // Auto-translate overlay
                if arViewModel.isAutoTranslateMode && arViewModel.isDetectionActive {
                    autoTranslateOverlay
                        .padding(.top, 10)
                }

                // Error message when annotation placement fails
                if arViewModel.showPlacementError {
                    Text(arViewModel.placementErrorMessage)
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                        .transition(.opacity)
                        .zIndex(1)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Spacer()
                
                // Bottom control bar
                ControlBar(
                    arViewModel: arViewModel,
                    settingsViewModel: settingsViewModel
                )
            }
            
            // Overlay when deleting an annotation
            if arViewModel.isDeletingAnnotation {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Removing label...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
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
        .background(autoTranslationBackground)
    }

    /// Background view that handles automatic translation via translationTask
    private var autoTranslationBackground: some View {
        Group {
            if let config = arViewModel.autoTranslateConfiguration {
                Text("")
                    .translationTask(config) { session in
                        // Process translations for detected words
                        for await word in arViewModel.$wordToTranslate.values {
                            guard let wordText = word, !wordText.isEmpty else { continue }

                            do {
                                print("🔄 Auto-translating: \(wordText)")
                                let response = try await session.translate(wordText)

                                await MainActor.run {
                                    arViewModel.autoTranslatedText = response.targetText
                                    print("✅ Translation: \(wordText) → \(response.targetText)")
                                }
                            } catch {
                                print("❌ Auto-translation failed: \(error.localizedDescription)")
                                await MainActor.run {
                                    arViewModel.autoTranslatedText = ""
                                }
                            }
                        }
                    }
            }
        }
        .hidden()
    }
    
    /// Overlay showing auto-translated text
    private var autoTranslateOverlay: some View {
        VStack(spacing: 10) {
            // Always show status when auto-translate is active
            if arViewModel.isDetectionActive {
                // Active scanning indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .scaleEffect(1.5)
                        )

                    Text("Scanning...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }

            // Detected words
            if let firstWord = arViewModel.detectedWords.first {
                VStack(spacing: 8) {
                    // Detected word
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.caption)
                        Text(firstWord.text)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.85))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Translation arrow
                    if !arViewModel.autoTranslatedText.isEmpty {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.vertical, 2)

                        // Translated text
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                            Text(arViewModel.autoTranslatedText)
                                .font(.system(size: 32, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: arViewModel.detectedWords.count)
        .animation(.easeInOut(duration: 0.3), value: arViewModel.autoTranslatedText)
    }

    /// View that handles the draggable detection box
    private var boundingBoxView: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    
                    // Initial setup of detection box in center of screen
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
                
                // Handle container size changes (like rotation)
                .onChange(of: geo.size) { oldSize, newSize in
                    guard abs(oldSize.width - newSize.width) > 1 || abs(oldSize.height - newSize.height) > 1 else {
                        return
                    }

                    // Resize and reposition the detection box
                    let adjustedROI = arViewModel.adjustableROI.resizedAndClamped(from: oldSize, to: newSize)
                    let constrainedROI = enforceMarginConstraints(adjustedROI, in: newSize)
                    
                    arViewModel.adjustableROI = constrainedROI
                    
                    previousSize = newSize
                }
            
            // The actual draggable/resizable box
            AdjustableBoundingBox(
                roi: $arViewModel.adjustableROI,
                containerSize: geo.size
            )
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

                if let sceneView = arViewModel?.sceneView {
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
                        let currentROI = arViewModel?.adjustableROI ?? .zero

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

                        arViewModel?.adjustableROI = newROI
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

    /// Automatically starts auto-translate mode after AR session is ready
    private func startAutoTranslateAfterDelay() {
        // Wait for AR session to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard self.arViewModel.isAutoTranslateMode else { return }
            guard !self.arViewModel.isARSessionLoading else {
                // If still loading, try again
                self.startAutoTranslateAfterDelay()
                return
            }

            print("🚀 Auto-starting translation mode")

            // Check if language is downloaded
            Task {
                let isDownloaded = await self.translationService.isLanguageDownloaded(
                    language: self.arViewModel.selectedLanguage
                )

                await MainActor.run {
                    if isDownloaded {
                        // Prepare translation configuration
                        self.arViewModel.autoTranslateConfiguration = TranslationSession.Configuration(
                            source: self.translationService.sourceLanguage,
                            target: self.arViewModel.selectedLanguage.locale
                        )

                        // Initialize ROI in center of screen
                        if let sceneView = self.arViewModel.sceneView {
                            let boxSize: CGFloat = 200
                            self.arViewModel.adjustableROI = CGRect(
                                x: (sceneView.bounds.width - boxSize) / 2,
                                y: (sceneView.bounds.height - boxSize) / 2,
                                width: boxSize,
                                height: boxSize
                            )
                        }

                        // Start detection automatically
                        self.arViewModel.isDetectionActive = true
                        print("✅ Auto-translate started successfully")
                    } else {
                        print("⚠️ Language not downloaded - user needs to download manually")
                        // Keep toggle on but don't start detection yet
                    }
                }
            }
        }
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

