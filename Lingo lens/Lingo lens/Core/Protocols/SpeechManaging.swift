//
//  SpeechManaging.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import Combine
import Speech

/// Protocol defining speech synthesis capabilities
/// Enables dependency injection and testing with mock implementations
/// @MainActor ensures speech operations happen on main thread (Swift 6 concurrency)
@MainActor
protocol SpeechManaging: AnyObject, ObservableObject {
    
    /// Publisher for loading state
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Publisher for speaking state
    var isSpeakingPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Current loading state
    var isLoading: Bool { get }
    
    /// Current speaking state
    var isSpeaking: Bool { get }
    
    /// Prepares the audio session for speech playback
    func prepareAudioSession()
    
    /// Speaks the provided text in the specified language
    /// - Parameters:
    ///   - text: The text to speak
    ///   - languageCode: The language code (e.g., "en-US" or "es-ES")
    func speak(text: String, languageCode: String)
    
    /// Stops any ongoing speech immediately
    func stopSpeaking()
    
    /// Deactivates the audio session when not needed
    func deactivateAudioSession()
}

/// Protocol defining speech recognition capabilities
protocol SpeechRecognizing: AnyObject, ObservableObject {
    
    /// Current authorization status for speech recognition
    var authorizationStatus: SpeechRecognitionAuthorizationStatus { get }
    
    /// Currently recognized text
    var recognizedText: String { get }
    
    /// Requests authorization for speech recognition
    /// - Parameter completion: Called with authorization result
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    
    /// Sets the language for speech recognition
    /// - Parameter languageCode: The language code to use
    func setLanguage(_ languageCode: String)
    
    /// Starts recording and recognizing speech
    /// - Throws: SpeechRecognitionError if recording cannot start
    func startRecording() throws
    
    /// Stops recording and recognition
    func stopRecording()
    
    /// Clears the recognized text
    func clearText()
}

/// Speech recognition authorization status
typealias SpeechRecognitionAuthorizationStatus = SFSpeechRecognizerAuthorizationStatus

/// Protocol for managing error display and handling
/// Protocol for error management
/// @MainActor ensures error UI updates happen on main thread (Swift 6 concurrency)
@MainActor
protocol ErrorManaging: AnyObject, ObservableObject {
    /// Shows an error alert with an optional retry action
    /// - Parameters:
    ///   - message: The error message to display
    ///   - retryAction: Optional closure that will execute if user taps "Try Again"
    func showError(message: String, retryAction: (() -> Void)?)
    
    /// Publisher for error alert state
    var showErrorAlert: Bool { get }
    
    /// Current error message
    var errorMessage: String { get }
    
    /// Optional retry action
    var retryAction: (() -> Void)? { get }
}

/// Protocol for managing appearance settings
/// Protocol for appearance management
/// @MainActor ensures UI updates happen on main thread (Swift 6 concurrency)
@MainActor
protocol AppearanceManaging: AnyObject {
    /// Current color scheme option
    var colorSchemeOption: AppearanceManager.ColorSchemeOption { get set }
    
    /// Publisher for color scheme changes
    var colorSchemeOptionPublisher: AnyPublisher<AppearanceManager.ColorSchemeOption, Never> { get }
}

/// Protocol for translation service
/// @MainActor ensures translation operations happen on main thread (Swift 6 concurrency)
@MainActor
protocol TranslationServicing: AnyObject {
    /// Available languages for translation
    var availableLanguages: [AvailableLanguage] { get }
    
    /// Translates text from source to target language
    /// - Parameters:
    ///   - text: Text to translate
    ///   - source: Source language
    ///   - target: Target language
    /// - Returns: Translated text
    @available(iOS 26.0, *)
    func translate(text: String, from source: AvailableLanguage, to target: AvailableLanguage) async throws -> String
}
