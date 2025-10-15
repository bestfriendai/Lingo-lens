//
//  ChatTranslatorViewModelTests.swift
//  Lingo lens Tests
//
//  Created by Code Improvement on 10/14/25.
//

import XCTest
import Combine
@testable import Lingo_lens

@MainActor
final class ChatTranslatorViewModelTests: XCTestCase {
    
    var sut: ChatTranslatorViewModel!
    var mockSpeechManager: MockSpeechManager!
    var mockDataPersistence: MockDataPersistence!
    var translationService: TranslationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup mocks
        mockSpeechManager = MockSpeechManager()
        mockDataPersistence = MockDataPersistence()
        translationService = TranslationService()
        cancellables = []
        
        // Inject dependencies
        DIContainer.shared.setSpeechManager(mockSpeechManager)
        DIContainer.shared.setDataPersistence(mockDataPersistence)
        DIContainer.shared.setTranslationService(translationService)
        
        // Create system under test
        sut = DIContainer.shared.makeChatTranslatorViewModel()
    }
    
    override func tearDown() async throws {
        sut = nil
        mockSpeechManager = nil
        mockDataPersistence = nil
        translationService = nil
        cancellables = nil
        
        // Reset DI container
        DIContainer.shared.reset()
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_SetsDefaultLanguages() {
        XCTAssertNotNil(sut.sourceLanguage, "Source language should be set")
        XCTAssertNotNil(sut.targetLanguage, "Target language should be set")
        XCTAssertEqual(sut.messages.count, 0, "Should start with no messages")
        XCTAssertFalse(sut.isTranslating, "Should not be translating initially")
    }
    
    // MARK: - Language Selection Tests
    
    func testSwapLanguages_SwapsSourceAndTarget() {
        // Given
        let originalSource = sut.sourceLanguage
        let originalTarget = sut.targetLanguage
        
        // When
        sut.swapLanguages()
        
        // Then
        XCTAssertEqual(sut.sourceLanguage.locale, originalTarget.locale)
        XCTAssertEqual(sut.targetLanguage.locale, originalSource.locale)
    }
    
    func testUpdateSourceLanguage_UpdatesLanguage() {
        // Given
        let newLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "fr"))
        
        // When
        sut.updateSourceLanguage(newLanguage)
        
        // Then
        XCTAssertEqual(sut.sourceLanguage.locale, newLanguage.locale)
    }
    
    func testUpdateTargetLanguage_UpdatesLanguage() {
        // Given
        let newLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "de"))
        
        // When
        sut.updateTargetLanguage(newLanguage)
        
        // Then
        XCTAssertEqual(sut.targetLanguage.locale, newLanguage.locale)
    }
    
    // MARK: - Input Validation Tests
    
    func testTranslateText_WithEmptyText_DoesNotTranslate() {
        // When
        sut.translateText("")
        
        // Then
        XCTAssertFalse(sut.isTranslating, "Should not start translating")
        XCTAssertNil(sut.pendingTranslation, "Should not create pending translation")
        XCTAssertEqual(sut.messages.count, 0, "Should not add any messages")
    }
    
    func testTranslateText_WithWhitespaceOnly_DoesNotTranslate() {
        // When
        sut.translateText("   \n\t  ")
        
        // Then
        XCTAssertFalse(sut.isTranslating, "Should not start translating")
        XCTAssertNil(sut.pendingTranslation, "Should not create pending translation")
    }
    
    func testTranslateText_WithTextTooLong_ShowsError() {
        // Given
        let longText = String(repeating: "a", count: 5001)
        
        // When
        sut.translateText(longText)
        
        // Then
        XCTAssertFalse(sut.isTranslating, "Should not start translating")
        XCTAssertTrue(sut.showError, "Should show error")
        XCTAssertNotNil(sut.errorMessage, "Should have error message")
    }
    
    func testTranslateText_WithValidText_WhenSessionNotReady_ShowsError() {
        // Given
        sut.isSessionReady = false
        
        // When
        sut.translateText("Hello")
        
        // Then
        XCTAssertFalse(sut.isTranslating, "Should not start translating")
        XCTAssertTrue(sut.showError, "Should show error")
    }
    
    // MARK: - Rate Limiting Tests
    
    func testTranslateText_RapidCalls_PreventsSpam() async {
        // Given
        sut.isSessionReady = true
        
        // When - rapid fire translations
        sut.translateText("First")
        sut.translateText("Second")
        sut.translateText("Third")
        
        // Then - only first one should process
        XCTAssertNotNil(sut.pendingTranslation, "Should have pending translation")
        XCTAssertEqual(sut.pendingTranslation?.text, "First", "Should only process first request")
    }
    
    // MARK: - Message Management Tests
    
    func testClearMessages_RemovesAllMessages() {
        // Given
        sut.isSessionReady = true
        let message = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        sut.messages = [message]
        
        // When
        sut.clearMessages()
        
        // Then
        XCTAssertEqual(sut.messages.count, 0, "Should remove all messages")
    }
    
    func testDeleteMessage_RemovesSpecificMessage() {
        // Given
        let message1 = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        let message2 = ChatMessage(
            originalText: "Goodbye",
            translatedText: "Adiós",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        sut.messages = [message1, message2]
        
        // When
        sut.deleteMessage(message1)
        
        // Then
        XCTAssertEqual(sut.messages.count, 1, "Should have one message left")
        XCTAssertEqual(sut.messages.first?.id, message2.id, "Should keep the correct message")
    }
    
    // MARK: - Speech Tests
    
    func testSpeakOriginalText_CallsSpeechManager() {
        // Given
        let message = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        
        // When
        sut.speakOriginalText(of: message)
        
        // Then
        XCTAssertTrue(mockSpeechManager.speakCalled, "Should call speak on speech manager")
        XCTAssertEqual(mockSpeechManager.lastSpokenText, "Hello", "Should speak original text")
    }
    
    func testSpeakTranslatedText_CallsSpeechManager() {
        // Given
        let message = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        
        // When
        sut.speakTranslatedText(of: message)
        
        // Then
        XCTAssertTrue(mockSpeechManager.speakCalled, "Should call speak on speech manager")
        XCTAssertEqual(mockSpeechManager.lastSpokenText, "Hola", "Should speak translated text")
    }
    
    // MARK: - Translation Session Tests
    
    func testUpdateTranslationSession_ResetsSessionReady() {
        // Given
        sut.isSessionReady = true
        
        // When
        sut.updateTranslationSession()
        
        // Then
        XCTAssertFalse(sut.isSessionReady, "Should reset session ready state")
        XCTAssertNotNil(sut.translationConfiguration, "Should create new configuration")
    }
    
    func testMarkSessionReady_SetsSessionReady() {
        // Given
        sut.isSessionReady = false
        
        // When
        sut.markSessionReady()
        
        // Then
        XCTAssertTrue(sut.isSessionReady, "Should mark session as ready")
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleTranslationError_SessionNotReady_ShowsCorrectError() {
        // When
        sut.handleTranslationError(.sessionNotReady)
        
        // Then
        XCTAssertTrue(sut.showError, "Should show error")
        XCTAssertNotNil(sut.errorMessage, "Should have error message")
        XCTAssertTrue(sut.errorMessage?.contains("not ready") ?? false, "Should mention session not ready")
    }
    
    func testHandleTranslationError_Timeout_ShowsCorrectError() {
        // When
        sut.handleTranslationError(.timeout)
        
        // Then
        XCTAssertTrue(sut.showError, "Should show error")
        XCTAssertTrue(sut.errorMessage?.contains("too long") ?? false, "Should mention timeout")
    }
    
    func testHandleTranslationError_NetworkError_ShowsCorrectError() {
        // When
        sut.handleTranslationError(.networkError)
        
        // Then
        XCTAssertTrue(sut.showError, "Should show error")
        XCTAssertTrue(sut.errorMessage?.contains("internet") ?? false, "Should mention internet")
    }
}
