//
//  DataPersisting.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import CoreGraphics

/// Protocol defining data persistence capabilities
/// Enables dependency injection and testing with mock implementations
protocol DataPersisting {
    
    // MARK: - App Launch Tracking
    
    /// Tracks application launch events
    func trackAppLaunch()
    
    /// Checks if this is the first launch
    func isFirstLaunch() -> Bool
    
    /// Gets the current launch count
    func getLaunchCount() -> Int
    
    /// Gets the initial launch date
    func getInitialLaunchDate() -> Date?
    
    // MARK: - Onboarding
    
    /// Marks onboarding as complete
    func finishOnBoarding()
    
    /// Checks if user has completed onboarding
    func didFinishOnBoarding() -> Bool
    
    /// Checks if user has dismissed instructions
    func hasDismissedInstructions() -> Bool
    
    /// Marks instructions as dismissed
    func dismissedInstructions()
    
    // MARK: - Rating Prompt
    
    /// Checks if app should show rating prompt
    func shouldShowRatingPrompt() -> Bool
    
    /// Marks that rating prompt has been shown
    func markRatingPromptAsShown()
    
    /// Sets preference to never show rating prompt again
    func setNeverAskForRating()
    
    // MARK: - Language Settings
    
    /// Saves the user's selected language code
    func saveSelectedLanguageCode(_ code: String)
    
    /// Gets the user's selected language code
    func getSelectedLanguageCode() -> String?
    
    // MARK: - Appearance Settings
    
    /// Saves the user's color scheme preference
    func saveColorSchemeOption(_ option: Int)
    
    /// Gets the user's color scheme preference
    func getColorSchemeOption() -> Int
    
    // MARK: - UI Preferences
    
    /// Saves whether to show label removal warning
    func saveNeverShowLabelRemovalWarning(_ value: Bool)
    
    /// Gets whether to show label removal warning
    func getNeverShowLabelRemovalWarning() -> Bool
    
    /// Saves the annotation scale
    func saveAnnotationScale(_ scale: CGFloat)
    
    /// Gets the annotation scale
    func getAnnotationScale() -> CGFloat
}

// Make DataManager conform to the protocol
extension DataManager: DataPersisting {}
