//
//  MockSpeechManager.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import Combine

/// Mock implementation of SpeechManaging for unit testing
final class MockSpeechManager: SpeechManaging {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var isSpeaking: Bool = false
    
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    var isSpeakingPublisher: AnyPublisher<Bool, Never> {
        $isSpeaking.eraseToAnyPublisher()
    }
    
    // MARK: - Test Properties
    
    var prepareAudioSessionCalled = false
    var speakCalled = false
    var stopSpeakingCalled = false
    var deactivateAudioSessionCalled = false
    
    var lastSpokenText: String?
    var lastLanguageCode: String?
    
    var shouldFailSpeech = false
    var speakDelay: TimeInterval = 0.1
    
    // MARK: - SpeechManaging Implementation
    
    func prepareAudioSession() {
        prepareAudioSessionCalled = true
    }
    
    func speak(text: String, languageCode: String) {
        speakCalled = true
        lastSpokenText = text
        lastLanguageCode = languageCode
        
        if shouldFailSpeech {
            return
        }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speakDelay) { [weak self] in
            self?.isLoading = false
            self?.isSpeaking = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isSpeaking = false
            }
        }
    }
    
    func stopSpeaking() {
        stopSpeakingCalled = true
        isLoading = false
        isSpeaking = false
    }
    
    func deactivateAudioSession() {
        deactivateAudioSessionCalled = true
        stopSpeaking()
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        prepareAudioSessionCalled = false
        speakCalled = false
        stopSpeakingCalled = false
        deactivateAudioSessionCalled = false
        lastSpokenText = nil
        lastLanguageCode = nil
        shouldFailSpeech = false
        isLoading = false
        isSpeaking = false
    }
}
