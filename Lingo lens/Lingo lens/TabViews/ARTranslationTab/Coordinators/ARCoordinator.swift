//
//  ARCoordinator.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import ARKit
import SceneKit
import Vision
import SwiftUI

/// Connects AR session events to the ARViewModel
/// Handles camera frames, detects objects, and manages user interactions with AR annotations
@MainActor
class ARCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {

    // Reference to view model that holds AR state
    weak var arViewModel: ARViewModel?

    // Tracks the number of frames with normal tracking to ensure stability
    private var frameCounter = 0

    // Number of consecutive frames with normal tracking required before considering AR session stable
    private let requiredFramesForStability = 10

    // Tracks how long we've been in a limited tracking state
    private var timeInLimitedState: TimeInterval = 0

    // Maximum time to wait in limited tracking state before proceeding anyway (3 seconds)
    private let maxLimitedStateWaitTime: TimeInterval = 3.0

    // Timestamp of the last processed frame for calculating time deltas
    private var lastFrameTimestamp: TimeInterval = 0

    // Object detection logic is handled by separate manager (injected for testability)
    private let objectDetectionManager: ObjectDetecting

    // Text recognition manager for automatic word detection
    private let textRecognitionManager: TextRecognitionManager
    
    // Error manager for handling AR errors
    private let errorManager: any ErrorManaging

    // Frame throttling for performance with thread-safe access
    private let processingLock = NSLock()
    private var _isProcessingFrame = false
    private var isProcessingFrame: Bool {
        get { processingLock.withLock { _isProcessingFrame } }
        set { processingLock.withLock { _isProcessingFrame = newValue } }
    }
    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.2 // Run detection every 0.2 seconds for fast response (optimized)

    // Text recognition throttling with thread-safe access
    private let textProcessingLock = NSLock()
    private var _isProcessingText = false
    private var isProcessingText: Bool {
        get { textProcessingLock.withLock { _isProcessingText } }
        set { textProcessingLock.withLock { _isProcessingText = newValue } }
    }
    private var lastTextRecognitionTime: TimeInterval = 0

    // Adaptive text recognition interval based on device capability
    private var textRecognitionInterval: TimeInterval {
        // Check if device has LiDAR (A12+ devices = iPhone XS and newer)
        let hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

        // MUCH faster intervals for Google Translate-style instant translation
        if hasLiDAR {
            return 0.1  // 10 FPS for newer devices (near real-time)
        } else {
            return 0.2  // 5 FPS for older devices (still responsive)
        }
    }

    // Performance monitoring for adaptive optimization
    private var consecutiveSlowFrames = 0
    private var frameProcessingTimes: [TimeInterval] = []

    /// Initializes coordinator with injected dependencies
    /// - Parameters:
    ///   - arViewModel: The AR view model to coordinate with
    ///   - objectDetectionManager: Detection manager for object detection
    ///   - textRecognitionManager: Text recognition manager
    ///   - errorManager: Error manager for handling AR errors
    init(arViewModel: ARViewModel,
         objectDetectionManager: ObjectDetecting,
         textRecognitionManager: TextRecognitionManager = TextRecognitionManager(),
         errorManager: any ErrorManaging) {
        self.arViewModel = arViewModel
        self.objectDetectionManager = objectDetectionManager
        self.textRecognitionManager = textRecognitionManager
        self.errorManager = errorManager
        super.init()
    }
    
    // MARK: - Frame Processing
    
    /// Processes each camera frame when object detection is active
    /// Takes the camera image, crops it to the user-defined bounding box, then runs object detection
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        // Extract data from frame BEFORE async to avoid retaining frame
        let currentTime = frame.timestamp
        let deltaTime = lastFrameTimestamp > 0 ? currentTime - lastFrameTimestamp : 0
        lastFrameTimestamp = currentTime

        // Extract tracking state immediately to avoid retaining frame
        let currentTrackingState = frame.camera.trackingState

        guard let arViewModel = self.arViewModel else { return }

        if arViewModel.isARSessionLoading {
                // Use extracted tracking state (not frame.camera.trackingState)
                switch currentTrackingState {
                    
                case .notAvailable:
                    
                    // Reset counters when tracking is completely unavailable
                    self.frameCounter = 0
                    self.timeInLimitedState = 0
                    
                case .limited(let reason):
                    
                    // Accumulate time spent in limited tracking state
                    self.timeInLimitedState += deltaTime
                    
                    // Show specific guidance based on the limitation type
                    switch reason {
                    case .initializing:
                        self.updateLoadingMessage("Initializing AR session...")
                    case .excessiveMotion, .insufficientFeatures, .relocalizing:
                        self.updateLoadingMessage("Loading AR session...")
                    @unknown default:
                        self.updateLoadingMessage("Loading...")
                    }
                    
                    // If we've been in limited state too long, proceed anyway with a warning
                    if self.timeInLimitedState >= self.maxLimitedStateWaitTime {
                        print("⏱️ Proceeding with limited tracking after timeout")
                        withAnimation {
                            arViewModel.isARSessionLoading = false
                        }
                        self.updateLoadingMessage("Setting up AR session...")
                        self.timeInLimitedState = 0
                    }
                    
                case .normal:
                    
                    // Count consecutive frames with normal tracking
                    self.frameCounter += 1
                    
                    // Accumulate time spent
                    self.timeInLimitedState += deltaTime
                    
                    // Show encouraging message halfway through stabilization
                    if self.frameCounter == 5 {
                        self.updateLoadingMessage("Getting ready...")
                    }
                    
                    // When we've had enough stable frames, consider AR session ready
                    if self.frameCounter >= self.requiredFramesForStability {
                        withAnimation {
                            arViewModel.isARSessionLoading = false
                        }
                        self.updateLoadingMessage("Setting up AR session...")
                        self.frameCounter = 0
                        self.timeInLimitedState = 0
                    }
                }
            }
            
            // Process frames on main actor to access UI properties safely
            Task { [weak self] in
            guard let self = self else { return }
            
            // Process frames when EITHER object detection OR word translation is active
            guard let arViewModel = self.arViewModel,
                  let sceneView = arViewModel.sceneView,
                  (arViewModel.isDetectionActive || arViewModel.isWordTranslationMode) else { return }

            // Google Translate mode: No need to update overlay positions
            // Overlays are updated when new text is detected, not every frame

            // Get the raw camera image and orientation (needed for both modes)
            let pixelBuffer = frame.capturedImage
            let deviceOrientation = UIDevice.current.orientation
            let exifOrientation = deviceOrientation.exifOrientation
            let screenWidth = sceneView.bounds.width
            let screenHeight = sceneView.bounds.height

            // OBJECT DETECTION MODE - Process detection box area for TEXT
            // NOTE: Using TEXT recognition instead of object detection since ML model was removed
            // This is actually MORE useful - users can point at text and get instant translation!
            if arViewModel.isDetectionActive && arViewModel.isObjectDetectionMode {
                // Skip if already processing or not enough time has passed
                let detectionTime = frame.timestamp
                guard !isProcessingFrame,
                      (detectionTime - lastDetectionTime) >= detectionInterval else {
                    return
                }

                // Mark as processing
                isProcessingFrame = true
                lastDetectionTime = detectionTime

                // Safety timeout
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    guard let self = self else { return }
                    if self.isProcessingFrame {
                        self.isProcessingFrame = false
                    }
                }

                // Convert screen ROI to normalized coordinates
                let roi = arViewModel.adjustableROI
                var nx = roi.origin.x / screenWidth
                var ny = 1.0 - ((roi.origin.y + roi.height) / screenHeight)
                var nw = roi.width  / screenWidth
                var nh = roi.height / screenHeight

                // Clamp to valid range
                if nx < 0 { nx = 0 }
                if ny < 0 { ny = 0 }
                if nx + nw > 1 { nw = 1 - nx }
                if ny + nh > 1 { nh = 1 - ny }

                let normalizedROI = CGRect(x: nx, y: ny, width: nw, height: nh)

                // Process TEXT recognition in ROI (improved - detects text instead of objects)
                Task {
                    await self.processTextInROI(pixelBuffer: pixelBuffer,
                                              exifOrientation: exifOrientation,
                                              normalizedROI: normalizedROI)
                }
            }

            // WORD TRANSLATION MODE - Process full frame for text
            if arViewModel.isWordTranslationMode {
                // Skip if already processing or not enough time has passed
                let textRecognitionTime = frame.timestamp
                guard !isProcessingText,
                      (textRecognitionTime - lastTextRecognitionTime) >= textRecognitionInterval else {
                    return
                }

                // Mark as processing
                isProcessingText = true
                lastTextRecognitionTime = textRecognitionTime

                // Safety timeout
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    guard let self = self else { return }
                    if self.isProcessingText {
                        self.isProcessingText = false
                    }
                }

                // Process full-frame word translation
                Task {
                    await self.processWordTranslation(pixelBuffer: pixelBuffer,
                                                    exifOrientation: exifOrientation,
                                                    screenSize: CGSize(width: screenWidth, height: screenHeight))
                }
            }
        }
    }

    /// Handles AR session errors by showing a user-friendly error message
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ AR session error: \(error.localizedDescription)")

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.arViewModel != nil else { return }

            // Small delay to avoid alert showing too quickly during normal transitions
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            errorManager.showError(
                message: "AR camera session encountered an issue. Please try again.",
                retryAction: { [weak self] in
                    guard let self = self else { return }
                    guard let arViewModel = self.arViewModel else { return }

                    // Try restarting the AR session if user taps retry
                    arViewModel.pauseARSession()

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        arViewModel.resumeARSession()
                    }
                }
            )
        }
    }
    
    /// Helper method that doesn't retain the ARFrame
    /// DEPRECATED: Object detection using ML model (model was removed)
    /// Use processTextInROI instead for text-based detection
    private func processFrameData(pixelBuffer: CVPixelBuffer,
                                 exifOrientation: CGImagePropertyOrientation,
                                 normalizedROI: CGRect) {

        // Safety timeout to prevent stuck detection state
        let detectionStartTime = Date()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            guard let self = self else { return }
            if self.isProcessingFrame && Date().timeIntervalSince(detectionStartTime) >= 1.0 {
                SecureLogger.logError("Detection timeout - resetting isProcessingFrame")
                self.isProcessingFrame = false
            }
        }

        // Send the cropped region to object detection manager
        objectDetectionManager.detectObjectCropped(
            pixelBuffer: pixelBuffer,
            exifOrientation: exifOrientation,
            normalizedROI: normalizedROI
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                guard let arViewModel = self.arViewModel else { return }
                arViewModel.detectedObjectName = result ?? ""
                // Reset processing flag to allow next detection
                self.isProcessingFrame = false
            }
        }
    }

    /// Processes text recognition in the yellow detection box (ROI)
    /// This replaces object detection and is more useful for translation!
    private func processTextInROI(pixelBuffer: CVPixelBuffer,
                                  exifOrientation: CGImagePropertyOrientation,
                                  normalizedROI: CGRect) async {
        // Safety timeout to prevent stuck detection state
        let detectionStartTime = Date()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.isProcessingFrame && Date().timeIntervalSince(detectionStartTime) >= 1.0 {
                SecureLogger.logError("Text recognition timeout - resetting isProcessingFrame")
                self.isProcessingFrame = false
            }
        }

        // Send the ROI to text recognition manager
        await withCheckedContinuation { continuation in
            textRecognitionManager.recognizeTextInROI(
                pixelBuffer: pixelBuffer,
                exifOrientation: exifOrientation,
                normalizedROI: normalizedROI
            ) { [weak self] detectedWords in
                Task { @MainActor in
                    guard let self = self else { 
                        continuation.resume()
                        return 
                    }
                    guard let arViewModel = self.arViewModel else { 
                        continuation.resume()
                        return 
                    }

                    // Combine all detected text into a single string for display
                    let detectedText = detectedWords
                        .map { $0.text }
                        .joined(separator: " ")

                    arViewModel.detectedObjectName = detectedText.isEmpty ? "" : detectedText

                    #if DEBUG
                    if !detectedText.isEmpty {
                        SecureLogger.log("📝 Detected text in ROI: \"\(detectedText)\"", level: .info)
                    }
                    #endif

                    // Reset processing flag to allow next detection
                    self.isProcessingFrame = false
                    continuation.resume()
                }
            }
        }
    }

    /// Processes full-frame word translation for restaurant menu use case
    private func processWordTranslation(pixelBuffer: CVPixelBuffer,
                                       exifOrientation: CGImagePropertyOrientation,
                                       screenSize: CGSize) async {
        // Safety timeout to prevent stuck text recognition state
        let recognitionStartTime = Date()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.isProcessingText && Date().timeIntervalSince(recognitionStartTime) >= 2.0 {
                SecureLogger.logError("Text recognition timeout - resetting isProcessingText")
                self.isProcessingText = false
            }
        }

        // Send the entire frame to text recognition manager
        await withCheckedContinuation { continuation in
            textRecognitionManager.recognizeAllText(
                pixelBuffer: pixelBuffer,
                exifOrientation: exifOrientation
            ) { [weak self] detectedWords in
                Task { @MainActor in
                    guard let self = self else { 
                        continuation.resume()
                        return 
                    }
                    guard let arViewModel = self.arViewModel else { 
                        continuation.resume()
                        return 
                    }

                    // Update detected words
                    arViewModel.detectedWords = detectedWords

                    // Google Translate mode: Process ALL confident text, no artificial limits
                    var seenPhraseTexts = Set<String>()

                    let confidentPhrases = detectedWords
                        .filter { $0.isConfident }
                        .filter { phrase in
                            let lowercased = phrase.text.lowercased()
                            if seenPhraseTexts.contains(lowercased) {
                                return false
                            }
                            seenPhraseTexts.insert(lowercased)
                            return true
                        }
                        .sorted { $0.confidence > $1.confidence }
                    arViewModel.pendingWordTranslations = Array(confidentPhrases)

                    print("📝 Detected \(detectedWords.count) phrases, queuing \(confidentPhrases.count) for translation")

                    // Reset processing flag to allow next recognition
                    self.isProcessingText = false
                    continuation.resume()
                }
            }
        }
    }

    /// Updates the loading message only if it's different from current message
    /// Prevents unnecessary UI updates when message hasn't changed
    private func updateLoadingMessage(_ message: String) {
        guard let arViewModel = self.arViewModel else { return }
        if arViewModel.loadingMessage != message {
            arViewModel.loadingMessage = message
        }
    }
    
    // MARK: - Annotation Interaction

    /// Handles taps on AR annotations
    /// Uses hit-testing to determine which annotation was tapped
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arViewModel = arViewModel,
              let sceneView = arViewModel.sceneView else { return }
        let location = gesture.location(in: sceneView)

        print("👆 Tap detected at screen position: \(location)")

        // Track the closest annotation to handle overlapping annotations
        var closestAnnotation: (distance: CGFloat, text: String)? = nil

        // Check if tap hit any annotation
        for annotation in arViewModel.annotationNodes {
            
            // Get the annotation's plane node (the visual part that can be tapped)
            guard let planeNode = annotation.node.childNode(withName: "annotationPlane", recursively: false),
                  let plane = planeNode.geometry as? SCNPlane,
                  let material = plane.firstMaterial,
                  let skScene = material.diffuse.contents as? SKScene else { continue }

            // Check if tap hit this particular node
            let hitResults = sceneView.hitTest(location, options: [
                .boundingBoxOnly: false,
                .searchMode: SCNHitTestSearchMode.all.rawValue
            ])
            
            guard let hitResult = hitResults.first(where: { $0.node == planeNode }) else { continue }
            
            // Convert hit location to annotation's local coordinate space
            let localPoint = hitResult.localCoordinates
            let normalizedX = (CGFloat(localPoint.x) / CGFloat(plane.width)) + 0.5
            let normalizedY = (CGFloat(localPoint.y) / CGFloat(plane.height)) + 0.5
            
            // Check if tap is inside the capsule shape of the annotation
            let capsuleSize = skScene.size
            let cornerRadius: CGFloat = 50
            let skPoint = CGPoint(x: normalizedX * capsuleSize.width,
                                y: (1 - normalizedY) * capsuleSize.height)
            
            // Create a path representing the annotation's shape
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: capsuleSize),
                                  cornerRadius: cornerRadius)
            
            if path.contains(skPoint) {
                
                // Calculate distance to determine closest annotation if multiple are hit
                let worldPos = planeNode.worldPosition
                let projectedCenter = sceneView.projectPoint(worldPos)
                let center = CGPoint(x: CGFloat(projectedCenter.x), y: CGFloat(projectedCenter.y))
                let dx = center.x - location.x
                let dy = center.y - location.y
                let distance = hypot(dx, dy)
                
                // Keep track of closest annotation
                if closestAnnotation == nil || distance < closestAnnotation!.distance {
                    closestAnnotation = (distance, annotation.originalText)
                }
            }
        }
        
        // Show translation sheet for tapped annotation
        if let closest = closestAnnotation {
            #if DEBUG
            SecureLogger.log("Tapped on annotation", level: .info)
            #endif
            arViewModel.selectedAnnotationText = closest.text
            arViewModel.isShowingAnnotationDetail = true
            arViewModel.isDetectionActive = false
        } else {
            #if DEBUG
            SecureLogger.log("No annotation found at tap location", level: .info)
            #endif
        }

    }
    
    /// Handles long press on annotations to show delete dialog
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let arViewModel = arViewModel,
              let sceneView = arViewModel.sceneView,
              gesture.state == .began else { return }

        let location = gesture.location(in: sceneView)

        print("👇 Long press detected at screen position: \(location)")

        // Track the closest annotation to handle overlapping annotations
        var closestAnnotation: (distance: CGFloat, index: Int, text: String)? = nil

        // Check if long press hit any annotation
        for (index, annotation) in arViewModel.annotationNodes.enumerated() {
            guard let planeNode = annotation.node.childNode(withName: "annotationPlane", recursively: false),
                  let plane = planeNode.geometry as? SCNPlane,
                  let _ = plane.firstMaterial else { continue }
            
            // Check if long press hit this particular node
            let hitResults = sceneView.hitTest(location, options: [
                .boundingBoxOnly: false,
                .searchMode: SCNHitTestSearchMode.all.rawValue
            ])
            
            guard let _ = hitResults.first(where: { $0.node == planeNode }) else { continue }
            
            // Calculate distance to determine closest annotation
            let worldPos = planeNode.worldPosition
            let projectedCenter = sceneView.projectPoint(worldPos)
            let center = CGPoint(x: CGFloat(projectedCenter.x), y: CGFloat(projectedCenter.y))
            let dx = center.x - location.x
            let dy = center.y - location.y
            let distance = hypot(dx, dy)
            
            // Keep track of closest annotation
            if closestAnnotation == nil || distance < closestAnnotation!.distance {
                closestAnnotation = (distance, index, annotation.originalText)
            }
        }
        
        // Show delete confirmation for the annotation
        if let closest = closestAnnotation {
            #if DEBUG
            SecureLogger.log("Long-pressed on annotation at index \(closest.index)", level: .info)
            #endif

            arViewModel.isDetectionActive = false
            arViewModel.detectedObjectName = ""

            let textToShow = closest.text
            arViewModel.showDeleteAnnotationAlert(index: closest.index, objectName: textToShow)
        } else {
            #if DEBUG
            SecureLogger.log("No annotation found at long press location", level: .info)
            #endif
        }
    }

}

