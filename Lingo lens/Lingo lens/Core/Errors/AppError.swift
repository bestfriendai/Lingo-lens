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
        case .sessionNotReady: return "translation.not_ready".localized()
        case .timeout: return "translation.timeout".localized()
        case .textTooLong: return "translation.text_too_long".localized()
        case .networkError: return "translation.network_error".localized()
        case .invalidLanguage: return "translation.invalid_language".localized()
        case .unknown: return "translation.error".localized()
        }
    }
    
    var message: String {
        switch self {
        case .sessionNotReady:
            return "translation.session_not_ready".localized()
        case .timeout:
            return "translation.timeout_message".localized()
        case .textTooLong:
            return "translation.text_too_long_message".localized()
        case .networkError:
            return "translation.network_error_message".localized()
        case .invalidLanguage:
            return "translation.invalid_language_message".localized()
        case .unknown(let msg):
            return "translation.unknown_error".localized(arguments: msg)
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
        case .sessionFailed: return "ar.session_error".localized()
        case .trackingLost: return "ar.tracking_lost".localized()
        case .insufficientFeatures: return "ar.poor_environment".localized()
        case .objectDetectionFailed: return "ar.detection_failed".localized()
        case .modelLoadFailed: return "ar.model_error".localized()
        case .imageProcessingFailed: return "ar.processing_failed".localized()
        }
    }
    
    var message: String {
        switch self {
        case .sessionFailed(let reason):
            return "ar.session_failed".localized(arguments: reason)
        case .trackingLost:
            return "ar.tracking_lost_message".localized()
        case .insufficientFeatures:
            return "ar.insufficient_features".localized()
        case .objectDetectionFailed:
            return "ar.object_detection_failed".localized()
        case .modelLoadFailed:
            return "ar.model_load_failed".localized()
        case .imageProcessingFailed:
            return "ar.image_processing_failed".localized()
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
        case .recognitionNotAuthorized: return "speech.permission_needed".localized()
        case .recognitionFailed: return "speech.recognition_failed".localized()
        case .synthesisNoVoices: return "speech.no_voices".localized()
        case .synthesisFailed: return "speech.playback_failed".localized()
        case .audioSessionFailed: return "speech.audio_error".localized()
        }
    }
    
    var message: String {
        switch self {
        case .recognitionNotAuthorized:
            return "speech.recognition_not_authorized".localized()
        case .recognitionFailed(let reason):
            return "speech.recognition_failed_message".localized(arguments: reason)
        case .synthesisNoVoices:
            return "speech.synthesis_no_voices".localized()
        case .synthesisFailed(let reason):
            return "speech.synthesis_failed".localized(arguments: reason)
        case .audioSessionFailed:
            return "speech.audio_session_failed".localized()
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
        case .saveFailure: return "persistence.save_failed".localized()
        case .fetchFailure: return "persistence.load_failed".localized()
        case .deleteFailure: return "persistence.delete_failed".localized()
        case .storeLoadFailure: return "persistence.database_error".localized()
        }
    }
    
    var message: String {
        switch self {
        case .saveFailure(let reason):
            return "persistence.save_failure".localized(arguments: reason)
        case .fetchFailure(let reason):
            return "persistence.fetch_failure".localized(arguments: reason)
        case .deleteFailure(let reason):
            return "persistence.delete_failure".localized(arguments: reason)
        case .storeLoadFailure(let reason):
            return "persistence.store_load_failure".localized(arguments: reason)
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
