//
//  Lingo_lensApp.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI

@main
struct Lingo_lensApp: App {
    
    // MARK: - Properties

    //  Track if the app initialized
    private static var didInitOnce = false

    // Dependency injection container for centralized dependency management
    @StateObject private var diContainer = DIContainer.shared

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
                        .preferredColorScheme(diContainer.appearanceManager.colorSchemeOption.colorScheme)
                        
                    } else {
                        
                        ContentView()

                            // Makes translation service available to all child views
                            .environmentObject(diContainer.translationService)

                            // Makes appearance settings available to all child views
                            .environmentObject(diContainer.appearanceManager)

                            // Makes DI container available for factory methods
                            .environmentObject(diContainer)

                            // Applies the user's selected color scheme
                            .preferredColorScheme(diContainer.appearanceManager.colorSchemeOption.colorScheme)

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
