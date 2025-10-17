//
//  ARSessionManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI
import ARKit

/// Manages AR session lifecycle and tracking state
/// Handles session configuration, pausing, resuming, and loading states
@MainActor
class ARSessionManager: ObservableObject {
    
    // MARK: - Published States
    
    // Current state of the AR session (active/paused)
    @Published var sessionState: ARViewModel.ARSessionState = .active
    
    // Tracks if AR is setting up
    @Published var isARSessionLoading: Bool = true
    
    // Current user-facing message explaining AR session status
    @Published var loadingMessage: String = "Setting up AR session..."
    
    // MARK: - Properties
    
    // Reference to AR scene view (set by ARViewContainer)
    weak var sceneView: ARSCNView?
    
    // MARK: - Session Management
    
    /// Pauses the AR session and stops object detection
    func pauseARSession() {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
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
    
    /// Sets the scene view reference
    /// - Parameter sceneView: The ARSCNView to manage
    func setSceneView(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
    }
    
    /// Updates the loading message
    /// - Parameter message: The new loading message to display
    func updateLoadingMessage(_ message: String) {
        self.loadingMessage = message
    }
    
    /// Marks AR session setup as complete
    func finishLoading() {
        self.isARSessionLoading = false
        self.loadingMessage = ""
    }
}