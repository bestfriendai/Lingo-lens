//
//  AppConstants.swift
//  Lingo lens
//
//  Created by Code Review on 10/14/25.
//

import Foundation
import CoreGraphics

/// Centralized constants for the Lingo Lens application
/// Eliminates magic numbers and makes configuration changes easier
struct AppConstants {
    
    // MARK: - AR Configuration
    
    struct AR {
        /// Minimum size (width or height) for object detection region
        static let minimumDetectionSize: CGFloat = 10
        
        /// Interval between object detection runs (in seconds)
        static let detectionInterval: TimeInterval = 0.5
        
        /// Interval for frame throttling (in seconds)
        static let frameThrottleInterval: TimeInterval = 0.5
        
        /// Confidence threshold for object detection (0.0 - 1.0)
        static let confidenceThreshold: Float = 0.5
        
        /// Number of frames required for AR session stability
        static let requiredFramesForStability = 10
        
        /// Maximum time to wait in limited tracking state (in seconds)
        static let maxLimitedStateWaitTime: TimeInterval = 3.0
    }
    
    // MARK: - Translation Configuration
    
    struct Translation {
        /// Maximum number of cached translations
        static let maxCacheSize = 50
        
        /// Maximum text length for translation (in characters)
        static let maxTextLength = 5000
        
        /// Minimum interval between translation requests (in seconds)
        static let rateLimit: TimeInterval = 0.5
        
        /// Timeout for translation requests (in seconds)
        static let requestTimeout: TimeInterval = 30.0
    }
    
    // MARK: - UI Configuration
    
    struct UI {
        /// Standard animation duration (in seconds)
        static let animationDuration: TimeInterval = 0.3
        
        /// Delay before haptic feedback (in seconds)
        static let hapticFeedbackDelay: TimeInterval = 0.1
        
        /// Maximum number of visible messages in chat
        static let messageMaxVisible = 100
        
        /// Corner radius for annotation capsules
        static let annotationCornerRadius: CGFloat = 50
        
        /// Delay before showing error alerts (in seconds)
        static let errorAlertDelay: TimeInterval = 0.5
    }
    
    // MARK: - Audio Configuration
    
    struct Audio {
        /// Speech synthesis rate (0.0 - 1.0)
        static let speechRate: Float = 0.9
        
        /// Pitch multiplier for speech (0.5 - 2.0)
        static let pitchMultiplier: Float = 1.0
        
        /// Volume for speech output (0.0 - 1.0)
        static let volume: Float = 1.0
    }
    
    // MARK: - Performance Configuration
    
    struct Performance {
        /// Batch size for Core Data fetch requests
        static let batchFetchSize = 20
        
        /// Maximum number of cached images for ML model
        static let imageCacheSize = 10
        
        /// Interval for logging frame processing (in seconds)
        static let frameLoggingInterval: TimeInterval = 1.0
    }
    
    // MARK: - Validation
    
    struct Validation {
        /// Minimum text length for translation
        static let minTextLength = 1
        
        /// Maximum text length for translation
        static let maxTextLength = 5000
        
        /// Allowed character sets for translation input
        static var allowedCharacters: CharacterSet {
            CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(.punctuationCharacters)
        }
    }
}

