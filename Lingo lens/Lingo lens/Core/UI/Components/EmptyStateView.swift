//
//  EmptyStateView.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import SwiftUI

/// Reusable empty state view component
struct EmptyStateView: View {
    
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 70))
                    .foregroundColor(.blue.opacity(0.7))
                
                Text(title)
                    .font(.title2.bold())
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("No Action") {
    EmptyStateView(
        icon: "book.closed",
        title: "No Saved Translations",
        message: "Your saved words will appear here."
    )
}

#Preview("With Action") {
    EmptyStateView(
        icon: "message",
        title: "No Messages",
        message: "Start a conversation to see your translations here.",
        actionTitle: "Start Translating"
    ) {
        print("Action tapped")
    }
}
