//
//  AppearanceManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 3/12/25.
//

import SwiftUI
import Combine

/// Manages the app's theme settings (light mode, dark mode, or system preference)
/// and persists the user's choice between app launches
/// @MainActor ensures all UI updates happen on the main thread (Swift 6 concurrency)
@MainActor
class AppearanceManager: ObservableObject, AppearanceManaging {
    
    // MARK: - Color Scheme Types
    
    /// Represents the different theme options available to the user
    enum ColorSchemeOption: Int, CaseIterable, Identifiable {
        case system
        case light
        case dark
        
        var id: Int { self.rawValue }
        
        // Display name for the settings UI
        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        // Localized display name for the settings UI
        var localizedTitle: String {
            switch self {
            case .system: return "appearance.system".localized()
            case .light: return "appearance.light".localized()
            case .dark: return "appearance.dark".localized()
            }
        }
        
        // Icon to display in the settings UI
        var icon: String {
            switch self {
            case .system: return "gear"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
        
        // Converts our enum to SwiftUI's ColorScheme type
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    // MARK: - Properties

    // The user's selected color scheme, automatically saved when changed
    @Published var colorSchemeOption: ColorSchemeOption {
        didSet {
            print("🎨 Color scheme changed to: \(colorSchemeOption.title)")
            dataPersistence.saveColorSchemeOption(colorSchemeOption.rawValue)
        }
    }
    
    // MARK: - AppearanceManaging Protocol
    
    var colorSchemeOptionPublisher: AnyPublisher<ColorSchemeOption, Never> {
        $colorSchemeOption.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let dataPersistence: DataPersisting
    
    // MARK: - Initialization
    
    init(dataPersistence: DataPersisting) {
        self.dataPersistence = dataPersistence
        
        // Load the user's saved preference from previous sessions
        let savedValue = dataPersistence.getColorSchemeOption()
    
        // Use the saved value if valid, otherwise default to system setting
        if let option = ColorSchemeOption(rawValue: savedValue) {
            self.colorSchemeOption = option
        } else {
            self.colorSchemeOption = .system
        }
    }
}
