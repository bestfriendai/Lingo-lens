//
//  DIContainer.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation

/// Dependency Injection Container for managing app dependencies
/// Provides centralized dependency management and enables testing with mock implementations
final class DIContainer: ObservableObject {

    // MARK: - Shared Instance

    static let shared = DIContainer()

    // MARK: - Core Dependencies

    private(set) lazy var speechManager: SpeechManaging = SpeechManager.shared
    private(set) lazy var dataPersistence: DataPersisting = DataManager.shared
    private(set) lazy var translationService: TranslationService = TranslationService()
    private(set) lazy var appearanceManager: AppearanceManager = AppearanceManager()
    private(set) lazy var persistenceController: PersistenceController = PersistenceController.shared

    // AR-specific dependencies
    private(set) lazy var objectDetectionManager: ObjectDetectionManager = ObjectDetectionManager()

    // Error managers
    private(set) lazy var coreDataErrorManager: CoreDataErrorManager = CoreDataErrorManager.shared
    private(set) lazy var arErrorManager: ARErrorManager = ARErrorManager.shared
    private(set) lazy var speechErrorManager: SpeechErrorManager = SpeechErrorManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Factory Methods

    /// Creates a new ChatTranslatorViewModel with injected dependencies
    @MainActor
    func makeChatTranslatorViewModel() -> ChatTranslatorViewModel {
        return ChatTranslatorViewModel(translationService: translationService)
    }

    /// Creates a new ARViewModel with injected dependencies
    @MainActor
    func makeARViewModel() -> ARViewModel {
        return ARViewModel()
    }

    /// Creates a new ARCoordinator with injected dependencies
    @MainActor
    func makeARCoordinator(arViewModel: ARViewModel) -> ARCoordinator {
        return ARCoordinator(arViewModel: arViewModel, objectDetectionManager: objectDetectionManager)
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

    /// Replaces the object detection manager with a test implementation
    /// - Parameter manager: Mock object detection manager for testing
    func setObjectDetectionManager(_ manager: ObjectDetectionManager) {
        self.objectDetectionManager = manager
    }

    /// Resets all dependencies to their default implementations
    /// Useful for cleaning up after tests
    func reset() {
        speechManager = SpeechManager.shared
        dataPersistence = DataManager.shared
        translationService = TranslationService()
        appearanceManager = AppearanceManager()
        persistenceController = PersistenceController.shared
        objectDetectionManager = ObjectDetectionManager()
    }
}
