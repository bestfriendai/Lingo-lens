//
//  AppError.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation

/// Unified error protocol for app-wide error handling
protocol AppError: LocalizedError {
    /// User-friendly title for the error
    var title: String { get }
    
    /// Detailed error message
    var message: String { get }
    
    /// Optional retry action
    var retryAction: (() -> Void)? { get }
    
    /// Error severity level
    var severity: ErrorSeverity { get }
}

/// Error severity levels
enum ErrorSeverity {
    case low        // User can continue using the app
    case medium     // Feature is degraded but app is usable
    case high       // Critical feature is broken
    case critical   // App cannot function properly
}

// MARK: - Domain-Specific Errors

/// Errors related to translation operations
enum TranslationError: AppError {
    case sessionNotReady
    case timeout
    case textTooLong
    case networkError
    case invalidLanguage
    case unknown(String)
    
    var title: String {
        switch self {
        case .sessionNotReady: return "Not Ready"
        case .timeout: return "Timeout"
        case .textTooLong: return "Text Too Long"
        case .networkError: return "Network Error"
        case .invalidLanguage: return "Invalid Language"
        case .unknown: return "Translation Error"
        }
    }
    
    var message: String {
        switch self {
        case .sessionNotReady:
            return "Translation isn't ready yet. Please wait a moment and try again."
        case .timeout:
            return "Translation is taking too long. Check your internet connection and try again."
        case .textTooLong:
            return "Text is too long. Maximum 5000 characters allowed."
        case .networkError:
            return "No internet connection. Please connect to the internet and try again."
        case .invalidLanguage:
            return "The selected language is not supported. Please choose a different language."
        case .unknown(let msg):
            return "Translation failed: \(msg)"
        }
    }
    
    var retryAction: (() -> Void)? {
        return nil
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .sessionNotReady, .timeout: return .medium
        case .textTooLong, .invalidLanguage: return .low
        case .networkError: return .high
        case .unknown: return .medium
        }
    }
    
    var errorDescription: String? {
        return message
    }
}

/// Errors related to AR operations
enum ARError: AppError {
    case sessionFailed(String)
    case trackingLost
    case insufficientFeatures
    case objectDetectionFailed
    case modelLoadFailed
    case imageProcessingFailed
    
    var title: String {
        switch self {
        case .sessionFailed: return "AR Session Error"
        case .trackingLost: return "Tracking Lost"
        case .insufficientFeatures: return "Poor Environment"
        case .objectDetectionFailed: return "Detection Failed"
        case .modelLoadFailed: return "Model Error"
        case .imageProcessingFailed: return "Processing Failed"
        }
    }
    
    var message: String {
        switch self {
        case .sessionFailed(let reason):
            return "AR session encountered an issue: \(reason). Please try again."
        case .trackingLost:
            return "AR tracking was lost. Move your device slowly and point it at a well-lit area."
        case .insufficientFeatures:
            return "Not enough visual features detected. Point your camera at a textured surface."
        case .objectDetectionFailed:
            return "Could not detect any objects. Try adjusting the detection box or pointing at a different object."
        case .modelLoadFailed:
            return "Could not load the object detection model. The app may not work properly."
        case .imageProcessingFailed:
            return "Image processing failed. Please try again."
        }
    }
    
    var retryAction: (() -> Void)? {
        return nil
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .modelLoadFailed: return .critical
        case .sessionFailed: return .high
        case .trackingLost, .insufficientFeatures: return .medium
        case .objectDetectionFailed, .imageProcessingFailed: return .low
        }
    }
    
    var errorDescription: String? {
        return message
    }
}

/// Errors related to speech operations
enum SpeechError: AppError {
    case recognitionNotAuthorized
    case recognitionFailed(String)
    case synthesisNoVoices
    case synthesisFailed(String)
    case audioSessionFailed
    
    var title: String {
        switch self {
        case .recognitionNotAuthorized: return "Permission Needed"
        case .recognitionFailed: return "Recognition Failed"
        case .synthesisNoVoices: return "No Voices"
        case .synthesisFailed: return "Playback Failed"
        case .audioSessionFailed: return "Audio Error"
        }
    }
    
    var message: String {
        switch self {
        case .recognitionNotAuthorized:
            return "Microphone access denied. Enable it in Settings to use speech input."
        case .recognitionFailed(let reason):
            return "Could not recognize speech: \(reason). Please try again."
        case .synthesisNoVoices:
            return "No speech voices are available for this language."
        case .synthesisFailed(let reason):
            return "Could not play audio: \(reason)"
        case .audioSessionFailed:
            return "Audio system is not available. Please check your device settings."
        }
    }
    
    var retryAction: (() -> Void)? {
        return nil
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .recognitionNotAuthorized: return .high
        case .audioSessionFailed: return .medium
        case .recognitionFailed, .synthesisFailed: return .medium
        case .synthesisNoVoices: return .low
        }
    }
    
    var errorDescription: String? {
        return message
    }
}

/// Errors related to Core Data operations
enum PersistenceError: AppError {
    case saveFailure(String)
    case fetchFailure(String)
    case deleteFailure(String)
    case storeLoadFailure(String)
    
    var title: String {
        switch self {
        case .saveFailure: return "Save Failed"
        case .fetchFailure: return "Load Failed"
        case .deleteFailure: return "Delete Failed"
        case .storeLoadFailure: return "Database Error"
        }
    }
    
    var message: String {
        switch self {
        case .saveFailure(let reason):
            return "Could not save: \(reason)"
        case .fetchFailure(let reason):
            return "Could not load data: \(reason)"
        case .deleteFailure(let reason):
            return "Could not delete: \(reason)"
        case .storeLoadFailure(let reason):
            return "Database failed to load: \(reason). Please restart the app."
        }
    }
    
    var retryAction: (() -> Void)? {
        return nil
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .storeLoadFailure: return .critical
        case .saveFailure, .deleteFailure: return .high
        case .fetchFailure: return .medium
        }
    }
    
    var errorDescription: String? {
        return message
    }
}
