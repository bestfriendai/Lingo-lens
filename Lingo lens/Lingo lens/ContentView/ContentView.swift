//
//  ContentView.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI

/// Main container view that manages navigation between app sections through tabs
struct ContentView: View {

    // MARK: - Properties

    // Provides translation features throughout the app
    @EnvironmentObject var translationService: TranslationService
    
    // DI Container for creating ViewModels
    @EnvironmentObject var diContainer: DIContainer
    
    // Manages AR camera session and translation-related state
    @State private var arViewModel: ARViewModel?

    // Controls alert when no languages are available for translation
    @State private var showNoLanguagesAlert = false

    // Navigation tabs for the app's main sections
    enum Tab {
        case arTranslationView
        case chatTranslatorView
        case savedWordsView
        case settingsView
    }
    
    // Currently selected tab in the UI
    @State private var selectedTab: Tab = .arTranslationView

    // MARK: - Initialization
    
    init() {
        // We'll initialize arViewModel in onAppear since we need access to diContainer
    }

    // MARK: - View Body

    var body: some View {
        TabView(selection: $selectedTab) {
            if let arViewModel = arViewModel {
                ARTranslationView(arViewModel: arViewModel)
                .tabItem {
                    Label(localized: "tab.translate", systemImage: "camera.viewfinder")
                }
                .tag(Tab.arTranslationView)
                .environmentObject(diContainer.speechManager)
                .accessibilityLabel("AR Translation")
                .accessibilityHint("Point camera at text to translate in real-time")
            } else {
                // Loading view while ARViewModel initializes
                ProgressView(localized: "loading.loading")
                    .tag(Tab.arTranslationView)
                    .accessibilityLabel("Loading AR Translation")
                    .accessibilityHint("Please wait while AR translation initializes")
            }

            ChatTranslatorView(translationService: translationService, diContainer: diContainer)
                .tabItem {
                    Label(localized: "tab.chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.chatTranslatorView)
                .accessibilityLabel("Chat Translator")
                .accessibilityHint("Translate text conversations and speech")

            SavedWords()
                .tabItem {
                    Label(localized: "tab.saved_words", systemImage: "bookmark.fill")
                }
                .tag(Tab.savedWordsView)
                .environmentObject(diContainer.speechManager)
                .accessibilityLabel("Saved Words")
                .accessibilityHint("View and manage your saved translations")

            SettingsTabView(arViewModel: arViewModel)
                .tabItem {
                    Label(localized: "tab.settings", systemImage: "gear")
                }
                .tag(Tab.settingsView)
                .accessibilityLabel("Settings")
                .accessibilityHint("Configure app preferences and languages")
        }
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
        .withCoreDataErrorHandling()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main Navigation")
        .accessibilityHint("Swipe left or right to navigate between tabs")
        
        .onReceive(translationService.$availableLanguages) { languages in
            if !languages.isEmpty {
                arViewModel.updateSelectedLanguageFromUserDefaults(availableLanguages: languages)
                showNoLanguagesAlert = false
            } else if !translationService.isInitialLoading {
                showNoLanguagesAlert = true
            }
        }
        
        .alert(localized: "translation.no_languages_title", isPresented: $showNoLanguagesAlert) {
            Button(localized: "action.ok", role: .cancel) { }
                .accessibilityLabel("Dismiss alert")
                .accessibilityHint("Close the no languages available alert")
        } message: {
            Text(localized: "translation.no_languages_message")
        }
        
        .onChange(of: selectedTab) { oldValue, newValue in
            // Pause AR session when leaving AR tab for instant Chat performance
            if oldValue == .arTranslationView && newValue != .arTranslationView {
                arViewModel?.pauseARSession()
            }

            // Resume AR session when returning to AR tab
            if newValue == .arTranslationView && oldValue != .arTranslationView {
                arViewModel?.resumeARSession()
            }

            // Audio session management
            if newValue == .arTranslationView || newValue == .savedWordsView || newValue == .chatTranslatorView {
                Task {
                    diContainer.speechManager.prepareAudioSession()
                }
            } else if newValue == .settingsView {
                diContainer.speechManager.deactivateAudioSession()
            }
        }

        .onAppear {
            // Initialize ARViewModel with dependencies
            if arViewModel == nil {
                arViewModel = diContainer.makeARViewModel()
            }
            
            // Track app launch and check onboarding status
            // Note: Skipping the didInitOnce check as it's handled in the App struct
            diContainer.dataPersistence.trackAppLaunch()
            
            // Check if onboarding should be shown
            if !diContainer.dataPersistence.didFinishOnBoarding() {
                // This will be handled by the app's showOnboarding state
                return
            }
            
            // Trigger lazy language loading
            translationService.loadLanguagesIfNeeded()

            if selectedTab == .arTranslationView || selectedTab == .savedWordsView || selectedTab == .chatTranslatorView {
                Task {
                    diContainer.speechManager.prepareAudioSession()
                }
            }
        }
        
        // When app becomes active again from background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Prepare audio session if we're on a tab that needs it
            if selectedTab == .arTranslationView || selectedTab == .savedWordsView || selectedTab == .chatTranslatorView {
                Task {
                    diContainer.speechManager.prepareAudioSession()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Normal State") {
    createNormalStatePreview()
}

@MainActor
private func createNormalStatePreview() -> some View {
    let translationService = TranslationService()
    translationService.availableLanguages = [
        AvailableLanguage(locale: .init(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: .init(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: .init(languageCode: "de", region: "DE"))
    ]
    
    return ContentView()
        .environmentObject(translationService)
        .environmentObject(AppearanceManager(dataPersistence: DataManager()))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Active Detection") {
    createActiveDetectionPreview()
}

@MainActor
private func createActiveDetectionPreview() -> some View {
    let translationService = TranslationService()
    let dataPersistence = DataManager()
    let arViewModel = ARViewModel(dataPersistence: dataPersistence, translationService: translationService)
    arViewModel.isDetectionActive = true
    arViewModel.detectedObjectName = "Coffee Cup"
    arViewModel.adjustableROI = CGRect(x: 100, y: 100, width: 200, height: 200)
    
    return ContentView()
        .environmentObject(translationService)
        .environmentObject(AppearanceManager(dataPersistence: dataPersistence))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
