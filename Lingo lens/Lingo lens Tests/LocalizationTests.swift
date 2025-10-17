//
//  LocalizationTests.swift
//  Lingo lens
//
//  Created by Localization Implementation on 10/17/25.
//

import XCTest
import SwiftUI

/// Tests for localization functionality
class LocalizationTests: XCTestCase {
    
    func testEnglishLocalization() {
        // Test English strings
        XCTAssertEqual("tab.translate".localized(), "Translate")
        XCTAssertEqual("tab.chat".localized(), "Chat")
        XCTAssertEqual("tab.saved_words".localized(), "Saved Words")
        XCTAssertEqual("tab.settings".localized(), "Settings")
        XCTAssertEqual("app.name".localized(), "Lingo Lens")
        XCTAssertEqual("action.ok".localized(), "OK")
        XCTAssertEqual("action.cancel".localized(), "Cancel")
    }
    
    func testLocalizationWithArguments() {
        // Test string formatting
        let formattedString = "settings.current_language".localized(arguments: "Spanish")
        XCTAssertTrue(formattedString.contains("Spanish"))
    }
    
    func testPluralLocalization() {
        // Test plural forms
        XCTAssertEqual("items.count".localizedPlural(count: 0), "No items")
        XCTAssertEqual("items.count".localizedPlural(count: 1), "1 item")
        XCTAssertEqual("items.count".localizedPlural(count: 5), "5 items")
    }
    
    func testAppLanguageManager() {
        let languageManager = AppLanguageManager.shared
        
        // Test supported languages
        let supportedLanguages = languageManager.supportedLanguages
        XCTAssertFalse(supportedLanguages.isEmpty)
        XCTAssertTrue(supportedLanguages.contains { $0.code == "en" })
        XCTAssertTrue(supportedLanguages.contains { $0.code == "es" })
        XCTAssertTrue(supportedLanguages.contains { $0.code == "fr" })
        XCTAssertTrue(supportedLanguages.contains { $0.code == "de" })
        XCTAssertTrue(supportedLanguages.contains { $0.code == "zh-Hans" })
        XCTAssertTrue(supportedLanguages.contains { $0.code == "ja" })
        
        // Test language display names
        let englishName = languageManager.getLanguageDisplayName(for: "en")
        XCTAssertFalse(englishName.isEmpty)
        
        let spanishName = languageManager.getLanguageDisplayName(for: "es")
        XCTAssertFalse(spanishName.isEmpty)
    }
    
    func testRTLLanguageDetection() {
        let languageManager = AppLanguageManager.shared
        
        // Test that RTL detection works (though our supported languages are LTR)
        // This test ensures the mechanism is in place for future RTL language support
        XCTAssertFalse(languageManager.isRTL) // Current language should be LTR
    }
    
    func testLocalizationKeysExist() {
        // Test that all essential localization keys exist
        let essentialKeys: [String] = [
            "tab.translate", "tab.chat", "tab.saved_words", "tab.settings",
            "app.name", "app.tagline", "app.author",
            "action.ok", "action.cancel", "action.done", "action.save", "action.delete",
            "loading.loading", "loading.translating",
            "camera.permission_required", "camera.permission_description",
            "translation.no_languages_title", "translation.no_languages_message",
            "chat.title", "chat.clear_all", "chat.from", "chat.to",
            "settings.title", "settings.translation", "settings.language",
            "onboarding.start_learning",
            "saved_words.title", "saved_words.empty_title"
        ]
        
        for key in essentialKeys {
            let localizedString = key.localized()
            XCTAssertNotEqual(localizedString, key, "Missing localization for key: \(key)")
        }
    }
}

// MARK: - Preview for Testing

struct LocalizationTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text(localized: "app.name")
                .font(.title)
            
            Text(localized: "app.tagline")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(localized: "tab.translate")
                Text(localized: "tab.chat")
                Text(localized: "tab.saved_words")
                Text(localized: "tab.settings")
            }
            
            Text(localizedPlural: "items.count", count: 5)
            
            Text(localized: "settings.current_language", arguments: "Spanish")
        }
        .padding()
    }
}

#Preview {
    LocalizationTestView()
        .environmentObject(AppLanguageManager.shared)
}