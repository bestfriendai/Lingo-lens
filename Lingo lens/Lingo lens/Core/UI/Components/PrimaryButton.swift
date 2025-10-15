//
//  PrimaryButton.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import SwiftUI

/// Reusable primary button with consistent styling throughout the app
struct PrimaryButton: View {
    
    // MARK: - Properties
    
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    // MARK: - Styling
    
    private let backgroundColor: Color
    private let foregroundColor: Color
    
    // MARK: - Initialization
    
    init(
        title: String,
        icon: String? = nil,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(foregroundColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                backgroundColor.opacity(isDisabled ? 0.5 : 1.0)
            )
            .cornerRadius(12)
        }
        .disabled(isDisabled || isLoading)
    }
}

/// Secondary button variant
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        PrimaryButton(
            title: title,
            icon: icon,
            backgroundColor: Color(.systemGray6),
            foregroundColor: .primary,
            action: action
        )
    }
}

/// Destructive button variant
struct DestructiveButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        PrimaryButton(
            title: title,
            icon: icon,
            backgroundColor: .red,
            foregroundColor: .white,
            isLoading: isLoading,
            action: action
        )
    }
}

#Preview("Primary Button") {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") { }
        PrimaryButton(title: "Speak", icon: "speaker.wave.2") { }
        PrimaryButton(title: "Loading...", isLoading: true) { }
        PrimaryButton(title: "Disabled", isDisabled: true) { }
    }
    .padding()
}

#Preview("Button Variants") {
    VStack(spacing: 16) {
        PrimaryButton(title: "Primary") { }
        SecondaryButton(title: "Secondary") { }
        DestructiveButton(title: "Delete", icon: "trash") { }
    }
    .padding()
}
