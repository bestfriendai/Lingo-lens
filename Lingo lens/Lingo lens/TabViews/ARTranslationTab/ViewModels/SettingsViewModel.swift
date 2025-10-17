//
//  SettingsViewModel.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/22/25.
//

import SwiftUI

/// Small view model to handle the expandable settings panel in the AR view
/// Controls animation and expansion state of the settings drawer
/// @MainActor ensures all UI updates happen on the main thread (Swift 6 concurrency)
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let dataPersistence: any DataPersisting
    private let appearanceManager: any AppearanceManaging
    
    // Tracks whether the settings panel is currently expanded
    @Published var isExpanded = false
    
    // MARK: - Initialization
    
    init(dataPersistence: (any DataPersisting)? = nil, appearanceManager: (any AppearanceManaging)? = nil) {
        self.dataPersistence = dataPersistence ?? DataManager()
        self.appearanceManager = appearanceManager ?? AppearanceManager(dataPersistence: self.dataPersistence)
    }
    
    // MARK: - Panel Animation

    /// Toggles the settings panel with a smooth spring animation
    /// Used when user taps the settings button in the AR view
    func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
    }
}
