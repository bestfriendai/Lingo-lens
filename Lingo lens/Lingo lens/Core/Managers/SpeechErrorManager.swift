//
//  SpeechErrorManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 3/13/25.
//

import SwiftUI

/// Handles errors related to speech synthesis throughout the app
/// Shows alert dialogs when pronunciation playback encounters problems
@MainActor
class SpeechErrorManager: ObservableObject, ErrorManaging {
    
    // MARK: - Published Properties

    // Controls whether error alert is visible
    @Published var showErrorAlert = false
    
    // The error message to show to the user
    @Published var errorMessage = ""
    
    // Optional function that runs if user taps "Try Again"
    @Published var retryAction: (() -> Void)? = nil
    
    /// Shows a speech-related error in an alert dialog
    /// - Parameters:
    ///   - message: The error message to show
    ///   - retryAction: Optional retry function if action can be attempted again
    func showError(message: String, retryAction: (() -> Void)? = nil) {
        errorMessage = message
        self.retryAction = retryAction
        showErrorAlert = true
    }
}

/// SwiftUI modifier that adds speech error handling to any view
/// Displays alerts when speech synthesis encounters problems
struct SpeechErrorAlert: ViewModifier {
    
    // Keep track of the error manager's state
    @ObservedObject var errorManager: ErrorManaging
    
    func body(content: Content) -> some View {
        content
            .alert("Speech Error", isPresented: .constant(errorManager.showErrorAlert)) {
                
                // Standard button to dismiss the alert
                Button("OK", role: .cancel) { }
                
                // Only show retry button if a retry action was provided
                if let retry = errorManager.retryAction {
                    Button("Try Again") {
                        retry()
                    }
                }
            } message: {
                Text(errorManager.errorMessage)
            }
    }
}

/// Helper extension to make speech error handling easy to add to any view
extension View {
    func withSpeechErrorHandling(errorManager: ErrorManaging) -> some View {
        self.modifier(SpeechErrorAlert(errorManager: errorManager))
    }
}
