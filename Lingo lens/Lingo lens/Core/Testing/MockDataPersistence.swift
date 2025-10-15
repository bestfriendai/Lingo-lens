//
//  MockDataPersistence.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import CoreGraphics

/// Mock implementation of DataPersisting for unit testing
final class MockDataPersistence: DataPersisting {
    
    // MARK: - Storage
    
    private var storage: [String: Any] = [:]
    
    // MARK: - App Launch Tracking
    
    func trackAppLaunch() {
        let count = getLaunchCount()
        storage["launchCount"] = count + 1
        
        if count == 0 {
            storage["initialLaunchDate"] = Date()
        }
    }
    
    func isFirstLaunch() -> Bool {
        return getLaunchCount() <= 1
    }
    
    func getLaunchCount() -> Int {
        return storage["launchCount"] as? Int ?? 0
    }
    
    func getInitialLaunchDate() -> Date? {
        return storage["initialLaunchDate"] as? Date
    }
    
    // MARK: - Onboarding
    
    func finishOnBoarding() {
        storage["didFinishOnBoarding"] = true
    }
    
    func didFinishOnBoarding() -> Bool {
        return storage["didFinishOnBoarding"] as? Bool ?? false
    }
    
    func hasDismissedInstructions() -> Bool {
        return storage["didDismissInstructions"] as? Bool ?? false
    }
    
    func dismissedInstructions() {
        storage["didDismissInstructions"] = true
    }
    
    // MARK: - Rating Prompt
    
    func shouldShowRatingPrompt() -> Bool {
        if storage["neverAskForRating"] as? Bool == true {
            return false
        }
        if storage["ratingPromptShown"] as? Bool == true {
            return false
        }
        return getLaunchCount() == 3
    }
    
    func markRatingPromptAsShown() {
        storage["ratingPromptShown"] = true
    }
    
    func setNeverAskForRating() {
        storage["neverAskForRating"] = true
    }
    
    // MARK: - Language Settings
    
    func saveSelectedLanguageCode(_ code: String) {
        storage["selectedLanguageCode"] = code
    }
    
    func getSelectedLanguageCode() -> String? {
        return storage["selectedLanguageCode"] as? String
    }
    
    // MARK: - Appearance Settings
    
    func saveColorSchemeOption(_ option: Int) {
        storage["colorSchemeOption"] = option
    }
    
    func getColorSchemeOption() -> Int {
        return storage["colorSchemeOption"] as? Int ?? 0
    }
    
    // MARK: - UI Preferences
    
    func saveNeverShowLabelRemovalWarning(_ value: Bool) {
        storage["neverShowLabelRemovalWarning"] = value
    }
    
    func getNeverShowLabelRemovalWarning() -> Bool {
        return storage["neverShowLabelRemovalWarning"] as? Bool ?? false
    }
    
    func saveAnnotationScale(_ scale: CGFloat) {
        storage["annotationScale"] = scale
    }
    
    func getAnnotationScale() -> CGFloat {
        return storage["annotationScale"] as? CGFloat ?? 1.0
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        storage.removeAll()
    }
}
