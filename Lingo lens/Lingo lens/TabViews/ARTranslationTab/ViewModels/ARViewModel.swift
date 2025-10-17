//
//  ARViewModel.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI
import ARKit
import SceneKit
import Translation

/// Central view model that manages all AR translation features
/// Controls object detection state, annotations, and camera session
/// @MainActor ensures all UI updates happen on the main thread (Swift 6 concurrency)
@MainActor
class ARViewModel: ObservableObject {
    
    // Tracks whether the AR session is active or paused
    enum ARSessionState {
        case active
        case paused
    }
    
    // MARK: - Published States

    // Current state of the AR session (active/paused)
    @Published var sessionState: ARSessionState = .active

    // Controls whether object detection is currently running
    @Published var isDetectionActive = false

    // Name of object currently detected within the ROI
    @Published var detectedObjectName: String = ""

    // Controls automatic full-frame word translation mode (enabled by default - restaurant menu use case)
    @Published var isWordTranslationMode = true

    // Controls manual object detection mode using the detection box
    @Published var isObjectDetectionMode = false

    // Use 2D overlays (Google Translate-style, FAST) vs 3D AR anchors (persistent, SLOW)
    @Published var use2DOverlays = true

    // Currently detected text phrases from full frame scan
    @Published var detectedWords: [DetectedWord] = []

    // Automatically translated text for current detected phrase
    @Published var autoTranslatedText: String = ""

    // Current phrase to translate (triggers translation via translationTask)
    @Published var wordToTranslate: String?

    // Translation configuration for phrase translation mode
    @Published var wordTranslationConfiguration: TranslationSession.Configuration?

    // Queue of phrases pending translation
    @Published var pendingWordTranslations: [DetectedWord] = []

    // 2D Translation overlays (Google Translate-style)
    @Published var translationOverlays: [UUID: TranslationOverlay2D] = [:]

    // Adaptive maximum overlays based on device and screen size
    private var maxOverlays: Int {
        // Google Translate-style: Show ALL detected text (no artificial limits)
        // Use higher limits for natural behavior
        let screenHeight = UIScreen.main.bounds.height

        if screenHeight > 800 {
            return 50  // Large screens can handle many overlays
        } else if screenHeight > 700 {
            return 35  // Medium screens
        } else {
            return 25  // Smaller screens
        }
    }
    
    // The yellow box that defines where to look for objects
    @Published var adjustableROI: CGRect = .zero
    
    // Text for currently selected annotation (when tapped)
    @Published var selectedAnnotationText: String?
    
    // Whether to show the annotation detail sheet
    @Published var isShowingAnnotationDetail: Bool = false
    
    // Controls error alert when annotation can't be placed
    @Published var showPlacementError = false
    
    // Tracks if we're currently placing an annotation
    @Published var isAddingAnnotation = false
    
    // Error message when annotation placement fails
    @Published var placementErrorMessage = "Couldn't anchor label on object. Try adjusting your angle or moving closer to help detect a surface."
    
    // Controls delete confirmation alert
    @Published var showDeleteConfirmation = false
    
    // Tracks which annotation is being deleted
    @Published var annotationToDelete: Int? = nil
    
    // Name of the annotation being deleted (shown in alert)
    @Published var annotationNameToDelete: String = ""
    
    // Tracks whether deletion is in progress
    @Published var isDeletingAnnotation = false
    
    // Tracks if AR is setting up
    @Published var isARSessionLoading: Bool = true
    
    // Current user-facing message explaining AR session status
    @Published var loadingMessage: String = "Setting up AR session..."
    
    // Currently selected language for translations
    // Persists to UserDefaults when changed
    @Published var selectedLanguage: AvailableLanguage {
        didSet {
            dataPersistence.saveSelectedLanguageCode(selectedLanguage.shortName())
        }
    }
    
    // Scale factor for annotation size
    // Persists to UserDefaults when changed
    @Published var annotationScale: CGFloat {
        didSet {
            dataPersistence.saveAnnotationScale(annotationScale)
            updateAllAnnotationScales()
        }
    }

    // MARK: - Properties
    
    // Dependencies
    private let dataPersistence: any DataPersisting
    private let translationService: any TranslationServicing
    
    // Reference to AR scene view (set by ARViewContainer)
    weak var sceneView: ARSCNView?

    // Manual object detection annotations (placed using "Add" button)
    // Contains the node, original text, and world position
    var annotationNodes: [(node: SCNNode, originalText: String, worldPos: SIMD3<Float>)] = []

    // Automatic word translation nodes (AR-anchored translations for restaurant menu use case)
    // Maps word ID to its translation node for efficient updates
    var wordTranslationNodes: [UUID: SCNNode] = [:]
    
    
    // MARK: - Initialization
    
    // Default to Spanish as initial language
    init(dataPersistence: any DataPersisting, translationService: any TranslationServicing) {
        self.dataPersistence = dataPersistence
        self.translationService = translationService
        
        // Initialize with default values
        let initialScale = dataPersistence.getAnnotationScale()
        let initialLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES"))
        
        self.selectedLanguage = initialLanguage
        self.annotationScale = initialScale
        
        // Try to load saved language
        if let savedLanguageCode = dataPersistence.getSelectedLanguageCode(),
           let savedLanguage = translationService.availableLanguages.first(where: { $0.shortName() == savedLanguageCode }) {
            self.selectedLanguage = savedLanguage
        }
    }
    
    // MARK: - Class Methods
    
    /// Loads the previously selected language from UserDefaults
    /// Called when app starts or when available languages change
    func updateSelectedLanguageFromUserDefaults(availableLanguages: [AvailableLanguage]) {
        let savedLanguageCode = dataPersistence.getSelectedLanguageCode()
    
        if let savedCode = savedLanguageCode,
           let savedLanguage = availableLanguages.first(where: { $0.shortName() == savedCode }) {
            
            // Use previously saved language if available
            self.selectedLanguage = savedLanguage
        } else if !availableLanguages.isEmpty {
            
            // Default to first available language if saved one isn't available
            self.selectedLanguage = availableLanguages.first!
            dataPersistence.saveSelectedLanguageCode(selectedLanguage.shortName())
        }
    }

    /// Shows delete confirmation alert for an annotation
    /// Formats object name for display in the alert
    func showDeleteAnnotationAlert(index: Int, objectName: String) {
        annotationToDelete = index
        
        // Truncate long names with ellipsis
        if objectName.count > 15 {
            let endIndex = objectName.index(objectName.startIndex, offsetBy: 12)
            annotationNameToDelete = String(objectName[..<endIndex]) + "..."
        } else {
            annotationNameToDelete = objectName
        }
        showDeleteConfirmation = true
    }

    /// Removes an annotation from the AR scene
    /// Called when user confirms deletion
    func deleteAnnotation() {
        guard let index = annotationToDelete, index < annotationNodes.count else {
            print("⚠️ Invalid annotation index for deletion: \(String(describing: annotationToDelete))")
            return
        }
        
        print("🗑️ Deleting annotation at index \(index)")
        isDeletingAnnotation = true
        
        // Small delay to show deletion is happening
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard let self = self else { return }
            
            // Get the annotation and remove from scene
            let (node, _, _) = self.annotationNodes[index]
            print("🗑️ Removing annotation from scene")
            node.removeFromParentNode()
            
            // Remove from our tracking array
            self.annotationNodes.remove(at: index)
            print("✅ Annotation deleted successfully - \(self.annotationNodes.count) annotations remaining")
            
            // Reset state
            self.isDeletingAnnotation = false
            self.annotationToDelete = nil
            self.showDeleteConfirmation = false
        }
    }
    
    // MARK: - Annotation Management

    /// Updates the size of all annotations when scale slider changes
    private func updateAllAnnotationScales() {
        for (node, _, _) in annotationNodes {
            node.scale = SCNVector3(annotationScale, annotationScale, annotationScale)
        }
    }

    /// Pauses the AR session and stops object detection
    func pauseARSession() {
        isDetectionActive = false
        detectedObjectName = ""

        if let sceneView = sceneView {
            sceneView.session.pause()
            sessionState = .paused
        }
    }

    /// Restarts the AR session with fresh configuration
    /// Resets tracking and anchors for a clean state
    func resumeARSession() {
        guard let sceneView = sceneView else { return }

        // Don't resume if already active
        guard sessionState != .active else {
            #if DEBUG
            print("⚠️ AR session already active - skipping resume")
            #endif
            return
        }

        // Prevent multiple resume calls
        guard !isARSessionLoading else {
            #if DEBUG
            print("⚠️ AR session already resuming - skipping")
            #endif
            return
        }

        // Reset AR loading state
        isARSessionLoading = true

        // Ensure session is properly paused first
        if sessionState != .paused {
            sceneView.session.pause()
            sessionState = .paused
        }

        // Small delay before restarting for better stability (non-blocking)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard let self = self else { return }
            guard let sceneView = self.sceneView else { return }

            // Double check we're still supposed to resume
            guard self.isARSessionLoading else { return }

            sceneView.backgroundColor = .black

            // Configure AR with optimized settings for device
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]

            // Lighter configuration for better performance
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                // Use mesh only if device has LiDAR
                configuration.sceneReconstruction = .mesh
            } else {
                // Disable environment texturing on older devices for performance
                configuration.environmentTexturing = .none
            }

            // Less aggressive reset for smoother experience
            // Don't reset tracking if we're just coming back from tab switch
            let runOptions: ARSession.RunOptions = [.removeExistingAnchors]

            // Run session without UI transition to avoid conflicts
            sceneView.session.run(configuration, options: runOptions)

            self.sessionState = .active
        }
    }
    
    /// Adds a new annotation at the center of the detection box
    /// Uses raycasting to find a plane to anchor it to
    func addAnnotation() {
        
        // Prevent multiple simultaneous adds
        guard !isAddingAnnotation else {
            print("⚠️ Already adding an annotation - ignoring request")
            return
        }
        
        // Only add if we have a valid object name
        guard !detectedObjectName.isEmpty,
              !detectedObjectName.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("⚠️ Cannot add annotation - no object detected")
            return
        }
        
        // Make sure AR is ready
        guard let sceneView = sceneView,
              sceneView.session.currentFrame != nil else { return }
        
        print("➕ Adding annotation for object: \"\(detectedObjectName)\"")
        isAddingAnnotation = true
        
        // Use center of the yellow box as placement point
        let roiCenter = CGPoint(x: adjustableROI.midX, y: adjustableROI.midY)
        print("📍 Attempting to place annotation at screen position: \(roiCenter)")
        
        // Try to find a plane at that point using raycasting
        if let query = sceneView.raycastQuery(from: roiCenter, allowing: .estimatedPlane, alignment: .any) {
            let results = sceneView.session.raycast(query)
            if let result = results.first {
                // Double-check object name is still valid
                guard !self.detectedObjectName.isEmpty else {
                    self.isAddingAnnotation = false
                    return
                }
                
                // Create annotation and add to scene
                let annotationNode = self.createCapsuleAnnotation(with: self.detectedObjectName)
                annotationNode.simdTransform = result.worldTransform
                annotationNode.scale = SCNVector3(self.annotationScale, self.annotationScale, self.annotationScale)
                
                // Store world position for later reference
                let worldPos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                           result.worldTransform.columns.3.y,
                                           result.worldTransform.columns.3.z)
                self.annotationNodes.append((annotationNode, self.detectedObjectName, worldPos))
                sceneView.scene.rootNode.addChildNode(annotationNode)
                
                // Reset state after a short delay
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self?.isAddingAnnotation = false
                }
            } else {
                
                // No plane found - show placement error
                Task { [weak self] in
                    self?.isAddingAnnotation = false
                    
                    if !(self?.showPlacementError ?? true) {
                        self?.showPlacementError = true
                        
                        // Hide error after 4 seconds
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                            self?.showPlacementError = false
                        }
                    }
                }
            }
        } else {
            // Couldn't create raycast query
            Task { [weak self] in
                self?.isAddingAnnotation = false
            }
        }
    }
    
    /// Removes all manual object detection annotations from the scene
    func resetAnnotations() {
        for (node, _, _) in annotationNodes {
            node.removeFromParentNode()
        }
        annotationNodes.removeAll()
    }

    /// Removes all word translation nodes from the scene
    func clearWordTranslations() {
        for (_, node) in wordTranslationNodes {
            node.removeFromParentNode()
        }
        wordTranslationNodes.removeAll()
        detectedWords.removeAll()
        translationOverlays.removeAll()
        pendingWordTranslations.removeAll()
    }

    /// Manages persistent overlays - removes stale and enforces limits
    /// PERSISTENT MODE: Overlays removed when:
    /// 1. Not seen for 3 seconds (stale)
    /// 2. Maximum overlay count exceeded (remove oldest first)
    /// 3. User explicitly clears translations
    /// 4. User leaves AR Translation tab
    func cleanupStaleOverlays() {
        var removedCount = 0
        
        let staleOverlays = translationOverlays.filter { $0.value.isStale }
        for (key, _) in staleOverlays {
            translationOverlays.removeValue(forKey: key)
            removedCount += 1
        }
        
        if removedCount > 0 {
            print("🧹 Removed \(removedCount) stale overlays")
        }

        if translationOverlays.count > maxOverlays {
            let sortedOverlays = translationOverlays.sorted { $0.value.lastSeenTime < $1.value.lastSeenTime }
            let toRemove = sortedOverlays.prefix(translationOverlays.count - maxOverlays)
            for (key, _) in toRemove {
                translationOverlays.removeValue(forKey: key)
            }
            print("🧹 Removed \(toRemove.count) old overlays to maintain max of \(maxOverlays)")
        }
    }



    /// Adds or updates a word translation node in AR space
    /// - Parameters:
    ///   - word: The detected word with its bounding box
    ///   - translation: The translated text
    ///   - screenPoint: The center point of the word on screen
    func addWordTranslation(word: DetectedWord, translation: String, at screenPoint: CGPoint) {
        guard let sceneView = sceneView else { return }

        // Try to find a plane at the word's screen position using raycasting
        if let query = sceneView.raycastQuery(from: screenPoint, allowing: .estimatedPlane, alignment: .any) {
            let results = sceneView.session.raycast(query)
            if let result = results.first {
                // Create or update translation node
                let translationNode = createWordTranslationNode(originalText: word.text, translatedText: translation)
                translationNode.simdTransform = result.worldTransform

                // Add to scene
                sceneView.scene.rootNode.addChildNode(translationNode)

                // Store in dictionary
                wordTranslationNodes[word.id] = translationNode

                print("✅ Added word translation: \"\(word.text)\" → \"\(translation)\" at screen position \(screenPoint)")
            } else {
                print("⚠️ Could not find AR plane for word: \(word.text) at \(screenPoint)")
            }
        }
    }

    /// Creates a simple AR node for word translation
    /// - Parameters:
    ///   - originalText: The original detected word
    ///   - translatedText: The translation to display
    /// - Returns: SCNNode with translation text
    private func createWordTranslationNode(originalText: String, translatedText: String) -> SCNNode {
        // Create text geometry
        let text = SCNText(string: translatedText, extrusionDepth: 0.5)
        text.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.specular.contents = UIColor.white
        text.firstMaterial?.isDoubleSided = true

        // Add black outline for better visibility
        text.firstMaterial?.multiply.contents = UIColor.white
        text.chamferRadius = 0.2

        // Create text node
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.002, 0.002, 0.002) // Small scale for AR

        // Center the text
        let (min, max) = textNode.boundingBox
        let dx = (max.x - min.x) / 2.0
        let dy = (max.y - min.y) / 2.0
        textNode.pivot = SCNMatrix4MakeTranslation(min.x + dx, min.y + dy, 0)

        // Container node
        let containerNode = SCNNode()
        containerNode.name = "wordTranslation_\(originalText)"
        containerNode.addChildNode(textNode)

        // Make text always face the camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y, .Z]
        containerNode.constraints = [billboard]

        return containerNode
    }
    
    // MARK: - Annotation Visuals

    /// Creates a capsule-shaped annotation with text
    /// Uses SpriteKit for text rendering inside SceneKit
    private func createCapsuleAnnotation(with text: String) -> SCNNode {
        let validatedText = text.isEmpty ? "Unknown Object" : text

        // Size calculations based on text length
        let baseWidth: CGFloat = 0.18
        let extraWidthPerChar: CGFloat = 0.005
        let maxTextWidth: CGFloat = 0.40
        let minTextWidth: CGFloat = 0.18
        let planeHeight: CGFloat = 0.09
        
        // Adjust width based on text length with min/max constraints
        let textCount = CGFloat(validatedText.count)
        let planeWidth = min(max(baseWidth + textCount * extraWidthPerChar, minTextWidth),
                             maxTextWidth)
        
        // Create a plane with rounded corners
        let plane = SCNPlane(width: planeWidth, height: planeHeight)
        plane.cornerRadius = 0.015
        
        // Use SpriteKit scene for the plane's contents
        plane.firstMaterial?.diffuse.contents = makeCapsuleSKScene(with: validatedText, width: planeWidth, height: planeHeight)
        plane.firstMaterial?.isDoubleSided = true
        
        // Create node hierarchy
        let planeNode = SCNNode(geometry: plane)
        planeNode.name = "annotationPlane"
        planeNode.categoryBitMask = 1

        let containerNode = SCNNode()
        containerNode.name = "annotationContainer"
        containerNode.categoryBitMask = 1
        
        // Position the plane slightly above the anchor point
        containerNode.addChildNode(planeNode)
        planeNode.position = SCNVector3(0, 0.04, 0)
        containerNode.eulerAngles.x = -Float.pi / 2
        
        // Apply user's preferred scale
        containerNode.scale = SCNVector3(annotationScale, annotationScale, annotationScale)
        
        // Make annotation always face the camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y, .Z]
        containerNode.constraints = [billboard]
        
        return containerNode
    }
    
    /// Creates a 2D SpriteKit scene for the annotation's visual appearance
    /// Handles text layout, background capsule, and styling
    private func makeCapsuleSKScene(with text: String, width: CGFloat, height: CGFloat) -> SKScene {
        let sceneSize = CGSize(width: 400, height: 140)
        let scene = SKScene(size: sceneSize)
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        
        // Create white capsule background
        let bgRect = CGRect(origin: .zero, size: sceneSize)
        let background = SKShapeNode(rect: bgRect, cornerRadius: 50)
        background.fillColor = .white
        background.strokeColor = .clear
        scene.addChild(background)
        
        // Container for text elements with flipped Y-axis
        let containerNode = SKNode()
        containerNode.setScale(1.0)
        containerNode.yScale = -1
        scene.addChild(containerNode)
        
        // Add chevron icon to indicate tappable
        let chevron = SKLabelNode(fontNamed: "Helvetica-Bold")
        chevron.text = "›"
        chevron.fontSize = 36
        chevron.fontColor = .gray
        chevron.verticalAlignmentMode = .center
        chevron.horizontalAlignmentMode = .center
        chevron.position = CGPoint(x: sceneSize.width - 40, y: -sceneSize.height / 2)
        containerNode.addChild(chevron)
        
        // Process text into lines that fit the capsule
        let processedLines = processTextIntoLines(text, maxCharsPerLine: 20)
        let lineHeight: CGFloat = 40
        let totalTextHeight = CGFloat(processedLines.count) * lineHeight
        let startY = (sceneSize.height + totalTextHeight) / 2 - lineHeight / 2
        
        // Add each line of text
        for (i, line) in processedLines.enumerated() {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = line
            label.fontSize = 32
            label.fontColor = .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            
            let yPosition = startY - (CGFloat(i) * lineHeight)
            label.position = CGPoint(
                x: (sceneSize.width - 40) / 2,
                y: -yPosition
            )
            containerNode.addChild(label)
        }
        
        return scene
    }
    
    /// Handles text wrapping for annotation labels
    /// Splits text into lines and adds ellipsis for overflow
    /// Uses actual visual width instead of character count for accurate wrapping
    private func processTextIntoLines(_ text: String, maxCharsPerLine: Int) -> [String] {
        var lines = [String]()
        var words = text.split(separator: " ").map(String.init)
        var currentLine = ""

        let ellipsis = "..."

        // Define font and max width for visual measurements
        let font = UIFont(name: "Helvetica-Bold", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .bold)
        let maxVisualWidth: CGFloat = 320.0 // Approximate max width for capsule

        // Helper function to measure visual width of text
        func visualWidth(_ str: String) -> CGFloat {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (str as NSString).size(withAttributes: attributes)
            return size.width
        }

        // Process words into lines with max 2 lines total
        while !words.isEmpty && lines.count < 2 {
            let word = words[0]
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word

            if visualWidth(testLine) <= maxVisualWidth {

                // Word fits on current line
                currentLine = testLine
                words.removeFirst()
            } else {

                // Word doesn't fit - handle overflow
                if lines.count == 1 {

                    // On second line - add ellipsis and stop
                    if !currentLine.isEmpty {
                        currentLine = currentLine.trimmingCharacters(in: .whitespaces)

                        // Truncate until it fits with ellipsis
                        while visualWidth(currentLine + ellipsis) > maxVisualWidth && !currentLine.isEmpty {
                            currentLine = String(currentLine.dropLast())
                        }
                        currentLine += ellipsis
                    }
                    break
                } else {

                    // On first line - start new line or truncate
                    if !currentLine.isEmpty {
                        lines.append(currentLine)
                        currentLine = ""
                    } else {
                        // Single word too long - truncate it
                        var truncatedWord = word
                        while visualWidth(truncatedWord) > maxVisualWidth && !truncatedWord.isEmpty {
                            truncatedWord = String(truncatedWord.dropLast())
                        }
                        currentLine = truncatedWord
                        words.removeFirst()
                    }
                }
            }
        }

        // Add final line if not empty
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        // Add ellipsis to last line if we have more words
        if !words.isEmpty && lines.count <= 2 {
            let lastIndex = lines.count - 1
            var lastLine = lines[lastIndex]

            // Truncate until it fits with ellipsis
            while visualWidth(lastLine + ellipsis) > maxVisualWidth && !lastLine.isEmpty {
                lastLine = String(lastLine.dropLast())
            }
            lastLine += ellipsis
            lines[lastIndex] = lastLine
        }

        // Reverse order because SpriteKit's coordinate system is different
        return lines.reversed()
    }
}

// MARK: - 2D Translation Overlay Model

/// Represents a 2D translation overlay for Google Translate-style fast translation
struct TranslationOverlay2D: Identifiable {
    let id: UUID
    let originalWord: String
    let translatedText: String
    var screenPosition: CGPoint
    let boundingBox: CGRect
    var lastSeenTime: Date
    var updateCount: Int = 0

    let isSingleWord: Bool
    let wordCount: Int
    let originalSize: CGSize
    let calculatedFontSize: CGFloat
    var worldPosition: SIMD3<Float>?

    var fontSize: CGFloat {
        return calculatedFontSize
    }

    /// Returns true if this overlay is stale (not seen recently)
    /// PERSISTENT MODE: Overlays stay visible much longer for stable translation experience
    /// Overlays only disappear after extended time without re-detection (like Google Translate)
    var isStale: Bool {
        let staleThreshold: TimeInterval = 3.0
        return Date().timeIntervalSince(lastSeenTime) > staleThreshold
    }

    /// Updates position directly without any smoothing or collision detection
    /// Overlays MUST appear exactly over the detected text positions
    mutating func updatePosition(_ newPosition: CGPoint) {
        self.lastSeenTime = Date()
        
        // Direct position update - no smoothing, no collision avoidance
        // This ensures overlays stay exactly over the detected text
        self.screenPosition = newPosition
        updateCount += 1
    }


}

