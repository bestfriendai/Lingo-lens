//
//  TranslationService.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import Foundation
import Translation
import SwiftUI

/// Manages language selection, availability, and translation requests
/// Acts as the central coordinator for all translation features
/// @MainActor ensures all UI updates happen on the main thread (Swift 6 concurrency)
@MainActor
class TranslationService: ObservableObject, TranslationServicing {
    
    // Currently translated text from latest translation request
    @Published var translatedText = ""
    
    // List of languages supported by the iOS translation system
    @Published var availableLanguages: [AvailableLanguage] = []
    
    // Tracks if we're still loading the initial language list
    @Published var isInitialLoading = true

    // Fixed source language (English) for all translations
    let sourceLanguage = Locale.Language(languageCode: "en")

    // Track if languages have been loaded
    private var hasLoadedLanguages = false

    // MARK: - Setup

    init() {
        // Defer language loading to improve app launch time
        // Languages will be loaded when first needed
        SecureLogger.log("TranslationService initialized (lazy loading)", level: .info)
    }

    /// Load languages if not already loaded
    func loadLanguagesIfNeeded() {
        guard !hasLoadedLanguages else { return }
        hasLoadedLanguages = true
        getSupportedLanguages()
    }
    
    // MARK: - Language Management

    
    /// Checks if a specific language has been downloaded for offline use
    /// - Parameter language: The language to check
    /// - Returns: True if language is downloaded, false otherwise
    func isLanguageDownloaded(language: AvailableLanguage) async -> Bool {
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: sourceLanguage,
            to: language.locale
        )

        // Check the download status from the system
        switch status {

        case .installed:
            // Language is downloaded and ready to use
            return true

        case .supported, .unsupported:
            // Language is either supported but not downloaded,
            // or not supported at all
            return false

        @unknown default:
            // Handle any future Apple-added statuses
            return false
        }
    }
    
    /// Fetches available languages from iOS translation system
    /// Populates the availableLanguages array with all supported translation languages
    func getSupportedLanguages() {
        SecureLogger.log("Loading supported languages", level: .info)
        isInitialLoading = true

        // Run language loading in background
        Task { @MainActor in

            // Get all languages supported by the device
            let supportedLanguages = await LanguageAvailability().supportedLanguages
            SecureLogger.log("Found \(supportedLanguages.count) supported languages", level: .info)

            // Filter out English (since it's our source language)
            // and create our own AvailableLanguage objects
            availableLanguages = supportedLanguages
                .filter { $0.languageCode != "en" }
                .map { AvailableLanguage(locale: $0) }
                .sorted()

            SecureLogger.log("Filtered to \(availableLanguages.count) available languages", level: .info)
            isInitialLoading = false
        }
    }
    
    // MARK: - Translation

    /// Performs translation using iOS system services
    /// - Parameters:
    ///   - text: The text to translate
    ///   - session: Active translation session for the target language
    @MainActor
    func translate(text: String, using session: TranslationSession) async throws {
        // Use the Apple Translation framework to translate the text
        let response = try await session.translate(text)

        // Update our published property with the result
        translatedText = response.targetText
    }
    
    // MARK: - TranslationServicing Protocol
    
    /// Translates text from source to target language
    /// - Parameters:
    ///   - text: Text to translate
    ///   - source: Source language
    ///   - target: Target language
    /// - Returns: Translated text
    func translate(text: String, from source: AvailableLanguage, to target: AvailableLanguage) async throws -> String {
        // Create a temporary translation session
        let session = try await TranslationSession(installedSource: source.locale, target: target.locale)
        
        // Perform the translation
        let response = try await session.translate(text)
        return response.targetText
    }
}
