//
//  DIContainer.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation

/// Dependency Injection Container for managing app dependencies
/// Provides centralized dependency management and enables testing with mock implementations
final class DIContainer {
    
    // MARK: - Shared Instance
    
    static let shared = DIContainer()
    
    // MARK: - Dependencies
    
    private(set) lazy var speechManager: SpeechManaging = SpeechManager.shared
    private(set) lazy var dataPersistence: DataPersisting = DataManager.shared
    private(set) lazy var translationService: TranslationService = TranslationService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Factory Methods
    
    /// Creates a new ChatTranslatorViewModel with injected dependencies
    func makeChatTranslatorViewModel() -> ChatTranslatorViewModel {
        return ChatTranslatorViewModel(translationService: translationService)
    }
    
    // MARK: - Test Support
    
    /// Replaces the speech manager with a test implementation
    /// - Parameter manager: Mock speech manager for testing
    func setSpeechManager(_ manager: SpeechManaging) {
        self.speechManager = manager
    }
    
    /// Replaces the data persistence with a test implementation
    /// - Parameter persistence: Mock data persistence for testing
    func setDataPersistence(_ persistence: DataPersisting) {
        self.dataPersistence = persistence
    }
    
    /// Replaces the translation service with a test implementation
    /// - Parameter service: Mock translation service for testing
    func setTranslationService(_ service: TranslationService) {
        self.translationService = service
    }
    
    /// Resets all dependencies to their default implementations
    /// Useful for cleaning up after tests
    func reset() {
        speechManager = SpeechManager.shared
        dataPersistence = DataManager.shared
        translationService = TranslationService()
    }
}
