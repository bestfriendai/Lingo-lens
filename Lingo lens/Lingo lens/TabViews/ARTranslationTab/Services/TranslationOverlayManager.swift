//
//  TranslationOverlayManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI
import ARKit
import SceneKit

/// Manages translation overlay creation and positioning
/// Handles both 2D overlays and 3D AR-anchored translations
@MainActor
class TranslationOverlayManager: ObservableObject {
    
    // MARK: - Published States
    
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
    
    // Use 2D overlays (Google Translate-style, FAST) vs 3D AR anchors (persistent, SLOW)
    @Published var use2DOverlays = true
    
    // MARK: - Properties
    
    // Reference to AR scene view (set by ARViewContainer)
    weak var sceneView: ARSCNView?
    
    // Automatic word translation nodes (AR-anchored translations for restaurant menu use case)
    // Maps word ID to its translation node for efficient updates
    var wordTranslationNodes: [UUID: SCNNode] = [:]
    
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
    
    // MARK: - Initialization
    
    init() {
        // Default initialization
    }
    
    // MARK: - Overlay Management
    
    /// Sets the scene view reference
    /// - Parameter sceneView: The ARSCNView to use for overlay placement
    func setSceneView(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
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
    
    /// Updates detected words array
    /// - Parameter words: New array of detected words
    func updateDetectedWords(_ words: [DetectedWord]) {
        self.detectedWords = words
    }
    
    /// Updates the auto-translated text
    /// - Parameter translation: The translated text to display
    func updateAutoTranslatedText(_ translation: String) {
        self.autoTranslatedText = translation
    }
    
    /// Sets the word to translate
    /// - Parameter word: The word to translate
    func setWordToTranslate(_ word: String?) {
        self.wordToTranslate = word
    }
    
    /// Updates the translation configuration
    /// - Parameter configuration: The new translation configuration
    func updateTranslationConfiguration(_ configuration: TranslationSession.Configuration?) {
        self.wordTranslationConfiguration = configuration
    }
    
    /// Adds a word to the pending translations queue
    /// - Parameter word: The word to add to the queue
    func addPendingWordTranslation(_ word: DetectedWord) {
        pendingWordTranslations.append(word)
    }
    
    /// Removes a word from the pending translations queue
    /// - Parameter wordId: The ID of the word to remove
    func removePendingWordTranslation(withId wordId: UUID) {
        pendingWordTranslations.removeAll { $0.id == wordId }
    }
    
    /// Updates or creates a 2D translation overlay
    /// - Parameters:
    ///   - overlay: The overlay to update or create
    ///   - position: The new screen position
    func updateTranslationOverlay(_ overlay: TranslationOverlay2D, at position: CGPoint) {
        var updatedOverlay = overlay
        updatedOverlay.updatePosition(position)
        translationOverlays[overlay.id] = updatedOverlay
    }
    
    /// Removes a specific translation overlay
    /// - Parameter overlayId: The ID of the overlay to remove
    func removeTranslationOverlay(withId overlayId: UUID) {
        translationOverlays.removeValue(forKey: overlayId)
    }
    
    /// Clears all translation overlays
    func clearAllTranslationOverlays() {
        translationOverlays.removeAll()
    }
}