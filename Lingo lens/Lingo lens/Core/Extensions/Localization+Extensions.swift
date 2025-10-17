//
//  Localization+Extensions.swift
//  Lingo lens
//
//  Created by Localization Implementation on 10/17/25.
//

import Foundation
import SwiftUI

// MARK: - Localization Helper

extension String {
    /// Localizes the string using NSLocalizedString
    /// - Parameters:
    ///   - comment: Comment for translators
    ///   - arguments: Arguments for string formatting
    /// - Returns: Localized string
    func localized(comment: String = "", arguments: CVarArg...) -> String {
        let localizedString = NSLocalizedString(self, comment: comment)
        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }
    
    /// Localizes the string with plural handling using stringsdict
    /// - Parameters:
    ///   - count: Count for pluralization
    ///   - comment: Comment for translators
    /// - Returns: Localized plural string
    func localizedPlural(count: Int, comment: String = "") -> String {
        let format = NSLocalizedString(self, comment: comment)
        return String.localizedStringWithFormat(format, count)
    }
}

// MARK: - Text Extension for SwiftUI

extension Text {
    /// Creates a localized Text view
    /// - Parameters:
    ///   - key: Localization key
    ///   - comment: Comment for translators
    ///   - arguments: Arguments for string formatting
    /// - Returns: Localized Text view
    init(localized key: String, comment: String = "", arguments: CVarArg...) {
        if arguments.isEmpty {
            self.init(NSLocalizedString(key, comment: comment))
        } else {
            let format = NSLocalizedString(key, comment: comment)
            self.init(String(format: format, arguments: arguments))
        }
    }
    
    /// Creates a localized Text view with plural handling
    /// - Parameters:
    ///   - key: Localization key
    ///   - count: Count for pluralization
    ///   - comment: Comment for translators
    /// - Returns: Localized Text view
    init(localizedPlural key: String, count: Int, comment: String = "") {
        let format = NSLocalizedString(key, comment: comment)
        self.init(String.localizedStringWithFormat(format, count))
    }
}

// MARK: - App Language Manager

class AppLanguageManager: ObservableObject {
    static let shared = AppLanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            setAppLanguage(currentLanguage)
        }
    }
    
    private init() {
        // Initialize with system language or saved preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            currentLanguage = savedLanguage
        } else {
            currentLanguage = Locale.current.languageCode ?? "en"
        }
        setAppLanguage(currentLanguage)
    }
    
    private func setAppLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    /// Get localized display name for a language code
    func getLanguageDisplayName(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
    
    /// Check if the current language is RTL (Right-to-Left)
    var isRTL: Bool {
        let locale = Locale.current
        return locale.language.characterDirection == .rightToLeft
    }
    
    /// Get supported languages
    var supportedLanguages: [(code: String, name: String)] {
        return [
            ("en", getLanguageDisplayName(for: "en")),
            ("es", getLanguageDisplayName(for: "es")),
            ("fr", getLanguageDisplayName(for: "fr")),
            ("de", getLanguageDisplayName(for: "de")),
            ("zh-Hans", getLanguageDisplayName(for: "zh-Hans")),
            ("ja", getLanguageDisplayName(for: "ja"))
        ]
    }
}

// MARK: - View Modifier for RTL Support

struct RTLSupportModifier: ViewModifier {
    @EnvironmentObject private var languageManager: AppLanguageManager
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, languageManager.isRTL ? .rightToLeft : .leftToRight)
    }
}

extension View {
    /// Adds RTL support to the view
    func withRTLSupport() -> some View {
        self.modifier(RTLSupportModifier())
    }
}

// MARK: - Date Formatting Extension

extension DateFormatter {
    /// Creates a localized date formatter
    static let appLocalized: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Creates a localized relative date formatter
    static let appRelative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Number Formatting Extension

extension NumberFormatter {
    /// Creates a localized number formatter
    static let appLocalized: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Creates a localized currency formatter
    static func currencyFormatter(for currencyCode: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = currencyCode
        return formatter
    }
}