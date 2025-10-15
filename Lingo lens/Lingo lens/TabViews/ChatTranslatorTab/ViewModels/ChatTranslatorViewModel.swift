//
//  ChatTranslatorViewModel.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import Foundation
import SwiftUI
import Translation
import CoreHaptics

/// ViewModel managing chat translator state and translation logic
@MainActor
class ChatTranslatorViewModel: ObservableObject {

    // MARK: - Published Properties

    // List of chat messages
    @Published var messages: [ChatMessage] = []

    // Currently selected source language (user's input language)
    @Published var sourceLanguage: AvailableLanguage {
        didSet {
            speechRecognitionManager.setLanguage(sourceLanguage.shortName())
            updateTranslationSession()
        }
    }

    // Currently selected target language (translation output language)
    @Published var targetLanguage: AvailableLanguage {
        didSet {
            updateTranslationSession()
        }
    }

    // Current text input
    @Published var inputText = ""

    // Loading state for translation
    @Published var isTranslating = false

    // Error message if translation fails
    @Published var errorMessage: String?

    // Show error alert
    @Published var showError = false

    // Configuration for translation session (triggers new session creation)
    @Published var translationConfiguration: TranslationSession.Configuration?

    // Track if user is typing (for future typing indicators)
    @Published var isTyping = false

    // Translation request tracking
    @Published var pendingTranslation: PendingTranslation?
    @Published var isSessionReady = false

    // MARK: - Dependencies

    private let translationService: TranslationService
    private let speechManager = SpeechManager.shared
    private let speechRecognitionManager = SpeechRecognitionManager.shared

    // Translation cache for instant repeated translations (with size limit)
    private var translationCache: [String: String] = [:]
    private let maxCacheSize = 100

    // Debounce timer for typing indicator
    private var typingTimer: Timer?

    // Rate limiting for translation requests
    private var lastTranslationTime: Date?

    // Reusable haptic generators (prepared for better performance)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let hapticsAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // MARK: - Initialization

    init(translationService: TranslationService) {
        self.translationService = translationService

        // Initialize with default languages (English source)
        let englishLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "en", region: "US"))

        // Try to get first available language for target, or use Spanish as fallback
        if let firstLanguage = translationService.availableLanguages.first {
            self.sourceLanguage = englishLanguage
            self.targetLanguage = firstLanguage
        } else {
            // Fallback to Spanish if no languages available yet
            self.sourceLanguage = englishLanguage
            self.targetLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES"))
        }

        SecureLogger.log("ChatTranslatorViewModel initialized", level: .info)

        // Defer haptic preparation to avoid blocking initialization
        Task { @MainActor in
            if hapticsAvailable {
                impactGenerator.prepare()
                selectionGenerator.prepare()
                notificationGenerator.prepare()
            }
        }
    }

    deinit {
        // Clean up timer
        typingTimer?.invalidate()
    }

    // MARK: - Translation Session Management

    /// Updates translation session when languages change
    func updateTranslationSession() {
        isSessionReady = false
        translationConfiguration = TranslationSession.Configuration(
            source: sourceLanguage.locale,
            target: targetLanguage.locale
        )

        // Clear cache when languages change
        translationCache.removeAll()
    }

    /// Marks the translation session as ready (called from view)
    func markSessionReady() {
        isSessionReady = true
    }

    // MARK: - Language Selection

    /// Swaps source and target languages with animation
    func swapLanguages() {
        SecureLogger.log("Swapping languages", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        // Swap with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
        }
    }

    /// Updates source language and speech recognition
    func updateSourceLanguage(_ language: AvailableLanguage) {
        SecureLogger.log("Updating source language", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            selectionGenerator.selectionChanged()
        }

        sourceLanguage = language
    }

    /// Updates target language
    func updateTargetLanguage(_ language: AvailableLanguage) {
        SecureLogger.log("Updating target language", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            selectionGenerator.selectionChanged()
        }

        targetLanguage = language
    }

    // MARK: - Translation

    /// Translates the input text and adds to messages
    func translateText(_ text: String, isFromSpeech: Bool = false) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            SecureLogger.log("Cannot translate empty text", level: .warning)
            return
        }

        // Input validation - check length
        guard trimmedText.count <= AppConstants.Translation.maxTextLength else {
            SecureLogger.log("Text too long for translation", level: .warning)
            errorMessage = "Text is too long. Maximum \(AppConstants.Translation.maxTextLength) characters."
            showError = true
            return
        }

        // Rate limiting - prevent spam
        if let lastTime = lastTranslationTime {
            let timeSinceLastTranslation = Date().timeIntervalSince(lastTime)
            if timeSinceLastTranslation < AppConstants.Translation.rateLimit {
                SecureLogger.log("Translation rate limit exceeded", level: .warning)
                return
            }
        }

        lastTranslationTime = Date()

        // Prevent race conditions - only one translation at a time
        guard !isTranslating else {
            SecureLogger.log("Translation already in progress", level: .warning)
            return
        }

        // Check cache first
        let cacheKey = "\(sourceLanguage.shortName())_\(targetLanguage.shortName())_\(trimmedText)"
        if let cached = translationCache[cacheKey] {
            SecureLogger.log("Using cached translation", level: .info)
            addMessage(original: trimmedText, translated: cached, isFromSpeech: isFromSpeech)
            return
        }

        // Check if session is ready
        guard isSessionReady else {
            SecureLogger.log("Translation session not ready", level: .error)
            handleTranslationError(.sessionNotReady)
            return
        }

        SecureLogger.log("Creating translation request", level: .info)

        // Create pending translation request
        pendingTranslation = PendingTranslation(
            text: trimmedText,
            isFromSpeech: isFromSpeech,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        isTranslating = true
        errorMessage = nil
        showError = false
    }

    /// Called from view when translation completes
    func handleTranslationResult(_ translatedText: String, for request: PendingTranslation) {
        SecureLogger.log("Translation completed successfully", level: .info)

        // Cache the translation with size management
        let cacheKey = "\(request.sourceLanguage.shortName())_\(request.targetLanguage.shortName())_\(request.text)"
        if translationCache.count >= maxCacheSize {
            // Remove oldest entry (first key)
            if let firstKey = translationCache.keys.first {
                translationCache.removeValue(forKey: firstKey)
            }
        }
        translationCache[cacheKey] = translatedText

        // Add message with haptic feedback
        if hapticsAvailable {
            notificationGenerator.notificationOccurred(.success)
        }
        addMessage(original: request.text, translated: translatedText, isFromSpeech: request.isFromSpeech)

        // Clear pending request
        pendingTranslation = nil
        isTranslating = false
    }

    /// Adds a new message with haptic feedback
    private func addMessage(original: String, translated: String, isFromSpeech: Bool) {
        let message = ChatMessage(
            originalText: original,
            translatedText: translated,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isFromSpeech: isFromSpeech
        )

        // Haptic feedback for successful translation using prepared generator
        if hapticsAvailable {
            notificationGenerator.notificationOccurred(.success)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(message)
        }

        // Message pagination - archive old messages if limit exceeded
        if messages.count > AppConstants.UI.messageMaxVisible {
            SecureLogger.log("Archiving old messages to maintain performance", level: .info)
            // Keep only the most recent messages
            messages = Array(messages.suffix(AppConstants.UI.messageMaxVisible))
        }

        // Clear input text
        inputText = ""
    }

    /// Handles translation errors with user-friendly messages
    func handleTranslationError(_ error: TranslationError) {
        // Haptic feedback for error using prepared generator
        if hapticsAvailable {
            notificationGenerator.notificationOccurred(.error)
        }

        switch error {
        case .sessionNotReady:
            errorMessage = "Translation isn't ready yet. Please wait a moment and try again."
        case .timeout:
            errorMessage = "Translation is taking too long. Check your internet connection."
        case .networkError:
            errorMessage = "No internet connection. Please connect and try again."
        case .unknown(let message):
            errorMessage = "Translation failed: \(message)"
        }

        showError = true
    }

    // MARK: - Speech Recognition

    /// Starts speech recognition with better error handling
    func startSpeechRecognition() {
        SecureLogger.log("Starting speech recognition", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        // Check authorization
        if speechRecognitionManager.authorizationStatus != .authorized {
            speechRecognitionManager.requestAuthorization { [weak self] authorized in
                guard let self = self else { return }
                if authorized {
                    self.performSpeechRecognition()
                } else {
                    self.errorMessage = "Microphone access denied. Enable it in Settings to use speech input."
                    self.showError = true
                }
            }
        } else {
            performSpeechRecognition()
        }
    }

    private func performSpeechRecognition() {
        do {
            try speechRecognitionManager.startRecording()
        } catch {
            SecureLogger.logError("Failed to start speech recognition", error: error)
            errorMessage = "Couldn't start recording. Please try again."
            showError = true

            // Error haptic using prepared generator
            if hapticsAvailable {
                notificationGenerator.notificationOccurred(.error)
            }
        }
    }

    /// Stops speech recognition and translates the result
    func stopSpeechRecognition() async {
        SecureLogger.log("Stopping speech recognition", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        speechRecognitionManager.stopRecording()

        // Wait a moment for final text to be processed
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let recognizedText = speechRecognitionManager.recognizedText

        if !recognizedText.isEmpty {
            translateText(recognizedText, isFromSpeech: true)
            speechRecognitionManager.clearText()
        } else {
            SecureLogger.log("No speech recognized", level: .warning)
            // No error - just silent failure for better UX
        }
    }

    // MARK: - Text-to-Speech

    /// Plays audio for original text
    func speakOriginalText(of message: ChatMessage) {
        SecureLogger.log("Speaking original text", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        speechManager.speak(text: message.originalText, languageCode: message.sourceLanguage.shortName())
    }

    /// Plays audio for translated text
    func speakTranslatedText(of message: ChatMessage) {
        SecureLogger.log("Speaking translated text", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        speechManager.speak(text: message.translatedText, languageCode: message.targetLanguage.shortName())
    }

    // MARK: - Message Management

    /// Clears all messages with confirmation
    func clearMessages() {
        SecureLogger.log("Clearing all messages", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            notificationGenerator.notificationOccurred(.warning)
        }

        withAnimation(.easeOut(duration: 0.25)) {
            messages.removeAll()
        }

        // Clear cache too
        translationCache.removeAll()
    }

    /// Deletes a specific message
    func deleteMessage(_ message: ChatMessage) {
        SecureLogger.log("Deleting message", level: .info)

        // Haptic feedback using prepared generator
        if hapticsAvailable {
            impactGenerator.impactOccurred()
        }

        withAnimation(.easeOut(duration: 0.2)) {
            messages.removeAll { $0.id == message.id }
        }
    }

    // MARK: - Typing Indicator

    /// Updates typing state (for future features)
    func userDidType() {
        isTyping = true

        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isTyping = false
            }
        }
    }
}

// MARK: - Pending Translation Model

struct PendingTranslation: Identifiable {
    let id = UUID()
    let text: String
    let isFromSpeech: Bool
    let sourceLanguage: AvailableLanguage
    let targetLanguage: AvailableLanguage
}

// MARK: - Translation Error Types

enum TranslationError: LocalizedError {
    case sessionNotReady
    case timeout
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotReady:
            return "Translation session not ready"
        case .timeout:
            return "Translation timed out"
        case .networkError:
            return "Network connection failed"
        case .unknown(let message):
            return message
        }
    }
}

