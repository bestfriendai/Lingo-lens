//
//  Lingo_lensApp.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI

// MARK: - Accessibility Configuration

@main
struct Lingo_lensApp: App {
    
    // MARK: - Properties

    //  Track if the app initialized
    private static var didInitOnce = false

    // Dependency injection container for centralized dependency management
    @StateObject private var diContainer = DIContainer.shared
    
    // Accessibility configuration
    @StateObject private var accessibilityConfig = AccessibilityConfiguration()
    
    // Language manager for localization
    @StateObject private var languageManager = AppLanguageManager.shared

    // Track whether to show onboarding
    @State private var showOnboarding = true

    // Add state for showing splash screen
    @State private var showSplashScreen = true

    // MARK: - Initialization
    
    init() {
        // Note: We can't access @StateObject here, so we'll track app launch
        // in the onAppear modifier of the ContentView
        if !Self.didInitOnce {
            Self.didInitOnce = true
            SecureLogger.log("App initializing", level: .info)
            
            // Log accessibility status for debugging
            #if DEBUG
            AccessibilityAudit.logAccessibilityStatus()
            #endif
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            
            ZStack {
                
                Group {
                    
                    // Show onboarding
                    if showOnboarding {
                        
                        OnboardingView {
                            showOnboarding = false
                            diContainer.dataPersistence.finishOnBoarding()
                        }
                        .environmentObject(languageManager)
                        .preferredColorScheme(diContainer.appearanceManager.colorSchemeOption.colorScheme)
                        .configureAccessibility()
                        .dynamicType()
                        .highContrast()
                        .reducedMotion()
                        
                    } else {
                        
                        ContentView()

                            // Makes translation service available to all child views
                            .environmentObject(diContainer.translationService as! TranslationService)

                            // Makes appearance settings available to all child views
                            .environmentObject(diContainer.appearanceManager as! AppearanceManager)

                            // Makes DI container available for factory methods
                            .environmentObject(diContainer)
                            
                            // Makes accessibility configuration available to all views
                            .environmentObject(accessibilityConfig)
                            
                            // Makes language manager available to all views
                            .environmentObject(languageManager)

                            // Applies the user's selected color scheme
                            .preferredColorScheme(diContainer.appearanceManager.colorSchemeOption.colorScheme)
                            
                            // Apply global accessibility configuration
                            .configureAccessibility()
                            .dynamicType()
                            .highContrast()
                            .reducedMotion()

                            // Gives Core Data access to all views
                            .environment(\.managedObjectContext, diContainer.persistenceController.container.viewContext)

                            // Save data when app is terminated
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                                diContainer.persistenceController.saveContext()
                                (diContainer.speechManager as? SpeechManager)?.deactivateAudioSession()
                            }

                            // Save data when app goes to background
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                                diContainer.persistenceController.saveContext()
                                (diContainer.speechManager as? SpeechManager)?.deactivateAudioSession()
                            }
                    }
                }
                
                // Show Splash Screen
                if showSplashScreen {
                    
                    SplashScreen()
                        .ignoresSafeArea()
                        .zIndex(1)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.linear(duration: 0)),
                            removal: .opacity.animation(.easeOut(duration: 0.3))
                        ))
                        .accessibilityLabel("Lingo Lens")
                        .accessibilityHint("Translation app is loading")
                        .onAppear {

                            // Dismiss splash after minimal delay (faster app launch)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showSplashScreen = false
                            }
                        }
                }
            }
        }
    }
}
