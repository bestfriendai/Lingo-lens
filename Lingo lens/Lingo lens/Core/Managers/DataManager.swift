//
//  DataManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 3/13/25.
//

import Foundation
import SwiftUI

/// Manager for handling user defaults data storage across the app
/// Keeps track of user preferences, settings, and states that need to persist between app launches
/// Now supports dependency injection instead of singleton pattern
class DataManager: DataPersisting {
    
    // MARK: - Initialization
    
    /// Initialize DataManager with optional custom UserDefaults (useful for testing)
    /// - Parameter userDefaults: Custom UserDefaults instance, defaults to standard
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // Private user defaults instance
    private let userDefaults: UserDefaults
    
    // MARK: - Keys
    
    // Collection of UserDefaults keys to avoid typos and inconsistencies
    private enum Keys {
        static let selectedLanguageCode = "selectedLanguageCode"
        static let colorSchemeOption = "colorSchemeOption"
        static let neverShowLabelRemovalWarning = "neverShowLabelRemovalWarning"
        static let annotationScale = "annotationScale"
        static let launchCount = "launchCount"
        static let isFirstLaunch = "isFirstLaunch"
        static let didFinishOnBoarding = "didFinishOnBoarding"
        static let neverAskForRating = "neverAskForRating"
        static let ratingPromptShown = "ratingPromptShown"
        static let initialLaunchDate = "initialLaunchDate"
        static let didDismissInstructions = "didDismissInstructions"
    }
    
    // MARK: - App Launch Tracking
    
    /// Tracks application launch events and initializes first-time user preferences
    /// - Sets up initial user defaults on first launch including storing the launch date
    /// - Increments the launch counter for returning users
    /// - Should be called during app initialization in the app delegate or scene delegate
    func trackAppLaunch() {
        
        // Initialize user preference for settings bundle
        userDefaults.register(defaults: [
            "developer_name": "Abhyas Mall"
        ])
        
        // Check if this is the first launch
        let isFirstLaunch = userDefaults.object(forKey: Keys.isFirstLaunch) == nil
        
        if isFirstLaunch {
            print("📱 First app launch detected")
            
            // This is the first launch ever
            userDefaults.set(false, forKey: Keys.isFirstLaunch)
            userDefaults.set(1, forKey: Keys.launchCount)
            
            // Set initial state for onboarding - false means onboarding hasn't been completed yet
            userDefaults.set(false, forKey: Keys.didFinishOnBoarding)
            
            // Set initial state for showing instructions - false signifies that user has not yet
            // seen the instructions sheet
            userDefaults.set(false, forKey: Keys.didDismissInstructions)
            
            // Save the initial launch date
            saveInitialLaunchDate()
            
            // For logging - to check if we successfully wrote the initial launch date
            let _ = getInitialLaunchDate()
            
        } else {
            
            // Increment launch counter
            let currentCount = userDefaults.integer(forKey: Keys.launchCount)
            userDefaults.set(currentCount + 1, forKey: Keys.launchCount)
            
            print("📱 App launch #\(currentCount + 1)")
        }
    }
    
    /// Saves the initial launch date to UserDefaults
    /// Called when the app is launched for the first time
    func saveInitialLaunchDate() {
        let currentDate = Date()
        userDefaults.set(currentDate, forKey: Keys.initialLaunchDate)
    }

    /// Retrieves the initial launch date from UserDefaults
    /// - Returns: Date when the app was first launched, or nil if not available
    func getInitialLaunchDate() -> Date? {
        return userDefaults.object(forKey: Keys.initialLaunchDate) as? Date
    }
    
    /// Checks if this is the first time the app has been launched
    /// - Returns: True if this is the first launch after installation
    func isFirstLaunch() -> Bool {
        return userDefaults.integer(forKey: Keys.launchCount) <= 1
    }

    /// Gets the current launch count
    /// - Returns: Number of times the app has been launched
    func getLaunchCount() -> Int {
        return userDefaults.integer(forKey: Keys.launchCount)
    }

    /// Marks onboarding as complete in UserDefaults
    /// Called when user completes the onboarding process
    func finishOnBoarding() {
        userDefaults.set(true, forKey: Keys.didFinishOnBoarding)
    }

    /// Checks if user has completed the onboarding process
    /// Returns true if onboarding was completed, false if it still needs to be shown
    func didFinishOnBoarding() -> Bool {
        return userDefaults.bool(forKey: Keys.didFinishOnBoarding)
    }

    /// Checks if the user has previously dismissed the instructions screen
    /// Returns true if instructions were dismissed, false if they should be shown
    func hasDismissedInstructions() -> Bool {
        return userDefaults.bool(forKey: Keys.didDismissInstructions)
    }

    /// Marks instructions as dismissed in UserDefaults
    /// Called when user closes the instructions screen
    func dismissedInstructions() {
        userDefaults.set(true, forKey: Keys.didDismissInstructions)
    }
    
    /// Checks if app should show rating prompt on 3rd launch
    func shouldShowRatingPrompt() -> Bool {
        // If user chose "Don't Ask Again", never show prompt
        if userDefaults.bool(forKey: Keys.neverAskForRating) {
            return false
        }

        // If prompt has already been shown, don't show again
        if userDefaults.bool(forKey: Keys.ratingPromptShown) {
            return false
        }

        // Show on exactly the 3rd launch
        return getLaunchCount() == 3
    }

    /// Marks that rating prompt has been shown
    func markRatingPromptAsShown() {
        userDefaults.set(true, forKey: Keys.ratingPromptShown)
    }

    /// Sets preference to never show rating prompt again
    func setNeverAskForRating() {
        userDefaults.set(true, forKey: Keys.neverAskForRating)
    }
    
    // MARK: - Language Settings
    
    /// Saves the user's selected translation language code
    /// Called when user changes their target language
    func saveSelectedLanguageCode(_ code: String) {
        userDefaults.set(code, forKey: Keys.selectedLanguageCode)
    }

    /// Gets the user's previously selected language code
    /// Returns nil if no language has been selected before
    func getSelectedLanguageCode() -> String? {
        return userDefaults.string(forKey: Keys.selectedLanguageCode)
    }
    
    // MARK: - Appearance Settings
    
    /// Saves the user's chosen app theme (light/dark/system)
    /// Raw integer value from AppearanceManager.ColorSchemeOption
    func saveColorSchemeOption(_ option: Int) {
        userDefaults.set(option, forKey: Keys.colorSchemeOption)
    }

    /// Gets the user's app theme preference
    /// Returns the raw int value that maps to AppearanceManager.ColorSchemeOption
    func getColorSchemeOption() -> Int {
        return userDefaults.integer(forKey: Keys.colorSchemeOption)
    }
    
    // MARK: - UI Preferences
    
    /// Saves whether to show the label removal warning
    /// Used to remember "don't show again" preference for alerts
    func saveNeverShowLabelRemovalWarning(_ value: Bool) {
        userDefaults.set(value, forKey: Keys.neverShowLabelRemovalWarning)
    }

    /// Checks if we should hide the label removal warning
    /// Returns true if user selected "don't show again"
    func getNeverShowLabelRemovalWarning() -> Bool {
        return userDefaults.bool(forKey: Keys.neverShowLabelRemovalWarning)
    }

    /// Saves the user's preferred annotation size
    /// Scale factor where 1.0 is default size
    func saveAnnotationScale(_ scale: CGFloat) {
        userDefaults.set(Float(scale), forKey: Keys.annotationScale)
    }

    /// Gets the saved annotation scale factor
    /// Returns 1.0 (default size) if nothing saved previously
    func getAnnotationScale() -> CGFloat {
        let scale = userDefaults.float(forKey: Keys.annotationScale)
        return scale > 0 ? CGFloat(scale) : 1.0
    }
}
