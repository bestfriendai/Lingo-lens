//
//  SpeechManaging.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import Combine

/// Protocol defining speech synthesis capabilities
/// Enables dependency injection and testing with mock implementations
/// @MainActor ensures speech operations happen on main thread (Swift 6 concurrency)
@MainActor
protocol SpeechManaging: AnyObject {
    
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
protocol SpeechRecognizing: AnyObject {
    
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
enum SpeechRecognitionAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
}
