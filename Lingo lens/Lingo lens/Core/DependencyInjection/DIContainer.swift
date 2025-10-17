//
//  DIContainer.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import Combine

/// Dependency Injection Container for managing app dependencies
/// Provides centralized dependency management and enables testing with mock implementations
/// @MainActor ensures all UI-related dependencies are created on the main thread (Swift 6 concurrency)
@MainActor
final class DIContainer: ObservableObject {

    // MARK: - Shared Instance

    static let shared = DIContainer()

    // MARK: - Core Dependencies

    private(set) var speechManager: any SpeechManaging
    private(set) var dataPersistence: any DataPersisting
    private(set) var translationService: TranslationServicing
    private(set) var appearanceManager: AppearanceManaging
    private(set) var persistenceController: PersistenceController

    // AR-specific dependencies
    private(set) var objectDetectionManager: ObjectDetecting
    private(set) var speechRecognitionManager: SpeechRecognitionManager

    // Error managers
    private(set) var coreDataErrorManager: any ErrorManaging
    private(set) var arErrorManager: any ErrorManaging
    private(set) var speechErrorManager: any ErrorManaging

    // MARK: - Initialization

    private init() {
        // Create instances instead of using singletons
        self.dataPersistence = DataManager()
        self.translationService = TranslationService()
        self.appearanceManager = AppearanceManager(dataPersistence: dataPersistence)
        self.persistenceController = PersistenceController.shared
        self.coreDataErrorManager = CoreDataErrorManager()
        self.arErrorManager = ARErrorManager()
        self.speechErrorManager = SpeechErrorManager()
        self.speechManager = SpeechManager(errorManager: speechErrorManager)
        self.objectDetectionManager = ObjectDetectionManager(errorManager: arErrorManager)
        self.speechRecognitionManager = SpeechRecognitionManager()
    }

    // MARK: - Factory Methods

    /// Creates a new ChatTranslatorViewModel with injected dependencies
    @MainActor
    func makeChatTranslatorViewModel() -> ChatTranslatorViewModel {
        return ChatTranslatorViewModel(
            translationService: translationService,
            speechManager: speechManager,
            speechRecognitionManager: speechRecognitionManager
        )
    }

    /// Creates a new ARViewModel with injected dependencies
    @MainActor
    func makeARViewModel() -> ARViewModel {
        return ARViewModel(
            dataPersistence: dataPersistence,
            translationService: translationService
        )
    }

    /// Creates a new ARCoordinator with injected dependencies
    @MainActor
    func makeARCoordinator(arViewModel: ARViewModel) -> ARCoordinator {
        return ARCoordinator(
            arViewModel: arViewModel, 
            objectDetectionManager: objectDetectionManager,
            errorManager: arErrorManager
        )
    }
    
    /// Creates a new SettingsViewModel with injected dependencies
    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            dataPersistence: dataPersistence,
            appearanceManager: appearanceManager
        )
    }

    // MARK: - Test Support

    /// Replaces the speech manager with a test implementation
    /// - Parameter manager: Mock speech manager for testing
    func setSpeechManager(_ manager: any SpeechManaging) {
        self.speechManager = manager
    }

    /// Replaces the data persistence with a test implementation
    /// - Parameter persistence: Mock data persistence for testing
    func setDataPersistence(_ persistence: any DataPersisting) {
        self.dataPersistence = persistence
    }

    /// Replaces the translation service with a test implementation
    /// - Parameter service: Mock translation service for testing
    func setTranslationService(_ service: TranslationService) {
        self.translationService = service
    }

    /// Replaces the object detection manager with a test implementation
    /// - Parameter manager: Mock object detection manager for testing
    func setObjectDetectionManager(_ manager: ObjectDetectionManager) {
        self.objectDetectionManager = manager
    }

    /// Resets all dependencies to their default implementations
    /// Useful for cleaning up after tests
    func reset() {
        self.dataPersistence = DataManager()
        self.translationService = TranslationService()
        self.appearanceManager = AppearanceManager(dataPersistence: dataPersistence)
        self.persistenceController = PersistenceController.shared
        self.coreDataErrorManager = CoreDataErrorManager()
        self.arErrorManager = ARErrorManager()
        self.speechErrorManager = SpeechErrorManager()
        self.speechManager = SpeechManager(errorManager: speechErrorManager)
        self.objectDetectionManager = ObjectDetectionManager(errorManager: arErrorManager)
        self.speechRecognitionManager = SpeechRecognitionManager()
    }
}
