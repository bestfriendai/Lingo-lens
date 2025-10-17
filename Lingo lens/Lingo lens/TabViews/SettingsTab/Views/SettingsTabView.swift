//
//  SettingsTabView.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 3/11/25.
//

import SwiftUI

/// Main settings tab for the app
/// Provides options for language selection and appearance customization
struct SettingsTabView: View {
    
    // AR view model passed from parent view
    @ObservedObject var arViewModel: ARViewModel
    
    // Access to the app's appearance settings
    @EnvironmentObject private var appearanceManager: AppearanceManager
    
    // App version information from Info.plist
    // Used to display version number in settings
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    var body: some View {
        NavigationStack {
            List {
                
                // MARK: - Translation Settings

                // Language selection section
                Section(header: Text(localized: "settings.translation")) {
                    NavigationLink {
                        LanguageSelectionView(
                            selectedLanguage: $arViewModel.selectedLanguage)
                    } label: {
                        HStack {
                            Text(localized: "settings.language")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            // Show currently selected language
                            Text(arViewModel.selectedLanguage.localizedName())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 5)
                    }
                    .accessibilityLabel(Text(localized: "settings.select_language"))
                    .accessibilityValue(Text(localized: "settings.current_language", arguments: arViewModel.selectedLanguage.localizedName()))
                    .accessibilityAddTraits(.isButton)
                }
                
                // MARK: - App Language Settings
                
                Section(header: Text(localized: "app.language")) {
                    NavigationLink {
                        AppLanguageSelectionView()
                    } label: {
                        HStack {
                            Text(localized: "app.language")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            // Show currently selected app language
                            Text(AppLanguageManager.shared.getLanguageDisplayName(for: AppLanguageManager.shared.currentLanguage))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 5)
                    }
                    .accessibilityLabel("Select App Language")
                    .accessibilityValue("Current app language: \(AppLanguageManager.shared.getLanguageDisplayName(for: AppLanguageManager.shared.currentLanguage))")
                    .accessibilityAddTraits(.isButton)
                }
                
                // MARK: - Appearance Settings

                // Theme selection section (dark/light mode)
                Section(header: Text(localized: "settings.appearance")) {
                    Picker(localized: "settings.color_scheme", selection: $appearanceManager.colorSchemeOption) {
                        ForEach(AppearanceManager.ColorSchemeOption.allCases) { option in
                            HStack {
                                
                                // Show icon for each theme option
                                Image(systemName: option.icon)
                                    .foregroundColor(iconColor(for: option))
                                    .accessibilityHidden(true)
                                Text(option.localizedTitle)
                            }
                            .tag(option)
                            .accessibilityLabel(option.localizedTitle)
                            .accessibilityValue(option == appearanceManager.colorSchemeOption ? "Selected" : "")
                            .accessibilityAddTraits(option == appearanceManager.colorSchemeOption ? .isSelected : [])
                        }
                    }
                    .pickerStyle(NavigationLinkPickerStyle())
                    .accessibilityLabel(localized: "settings.choose_color_scheme")
                    .accessibilityHint(localized: "settings.color_scheme_hint")
                    .accessibilityAddTraits(.isButton)
                }
                
                // MARK: - About Section

                // App version information
                Section(header: Text(localized: "settings.about")) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        Text(localized: "settings.version")
                        Spacer()
                        Text("\(version) (\(build))")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("App version \(version) build \(build)")
                    .accessibilityAddTraits(.isStaticText)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(Text(localized: "settings.title"))
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    /// Returns an appropriate color for each theme option icon
    /// Makes the icons visually represent their theme
    private func iconColor(for option: AppearanceManager.ColorSchemeOption) -> Color {
        switch option {
        case .system:
            return .gray
        case .light:
            return .yellow
        case .dark:
            return .blue
        }
    }
}

#Preview {
    createSettingsTabPreview()
}

@MainActor
private func createSettingsTabPreview() -> some View {
    let arViewModel = ARViewModel(dataPersistence: DataManager(), translationService: TranslationService())
    arViewModel.selectedLanguage = AvailableLanguage(
        locale: Locale.Language(languageCode: "es", region: "ES"))
    
    let translationService = TranslationService()
    translationService.availableLanguages = [
        AvailableLanguage(locale: .init(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: .init(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: .init(languageCode: "de", region: "DE"))
    ]
    
    return SettingsTabView(arViewModel: arViewModel)
            .environmentObject(translationService)
            .environmentObject(AppearanceManager(dataPersistence: DataManager()))
}