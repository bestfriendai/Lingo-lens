//
//  InstructionsView.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/23/25.
//


import SwiftUI

/// Modal view that explains how to use the translation feature
struct InstructionsView: View {
    
    // Environment variable to dismiss this sheet when needed
    @Environment(\.dismiss) private var dismiss
    
    // To present the rating alert after the InstructionsView is dismissed
    @Binding var ratingAlert: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                HStack {
                    Text("How to use the Translate Feature")
                        .font(.title.bold())
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                    .accessibilityLabel("Close Instructions")
                }
                .padding(.horizontal)
                
                VStack(spacing: 20) {
                    instructionCard(
                        icon: "globe",
                        title: "Select Language",
                        description: "Open the Settings tab (gear icon at bottom) and choose your target language under language selection."
                    )

                    instructionCard(
                        icon: "camera.viewfinder",
                        title: "Start Detection",
                        description: "Return to the Translate tab and tap the green 'Start Detection' button in the bottom-center. Point your camera at objects you want to identify."
                    )

                    instructionCard(
                        icon: "square.dashed",
                        title: "Adjust Bounding Box",
                        description: "Position the yellow box around the object you want to translate. Move the box by dragging its edges. Resize using the circular handles at the corners. Move closer to the object if needed."
                    )

                    instructionCard(
                        icon: "plus.circle.fill",
                        title: "Add Annotations",
                        description: "When an object is detected (green text appears), tap the blue plus button to place a translation label on that object."
                    )

                    instructionCard(
                        icon: "battery.100",
                        title: "Battery Saving",
                        description: "You can tap the red 'Stop Detection' button when you're done detecting objects to save battery power. Resume detection anytime by tapping 'Start Detection' again."
                    )
                    
                    instructionCard(
                        icon: "hand.tap",
                        title: "View Translations",
                        description: "Tap on any label to see its detailed translation and hear pronunciation. You can also save words for future reference."
                    )

                    instructionCard(
                        icon: "hand.tap.fill",
                        title: "Remove Labels",
                        description: "Long press on any label to remove it."
                    )
                    
                    instructionCard(
                        icon: "textformat.size",
                        title: "Label Settings",
                        description: "Tap the text icon (bottom-left) to access label settings. Here you can adjust label size using the slider or clear all labels with the red button."
                    )
                    
                    instructionCard(
                        icon: "info.circle",
                        title: "Need Help?",
                        description: "Tap on the information button in the top-right corner of the Translate tab anytime to view these instructions again."
                    )
                }
                
                VStack(spacing: 16) {
                    Text("Enjoy Learning!")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    
                    Text("Discover new languages with Lingo Lens")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        
        // User should be presnted with the instructions view
        // when they start using the app for the first time
        // And when they dismiss it then we should mark that
        // the user has dismissed so we do not present instructions
        // unless user presses the info i button on the toolbar
        .onDisappear {
            if !DataManager.shared.hasDismissedInstructions() {
                DataManager.shared.dismissedInstructions()
                
                // Updating rating alert's value
                ratingAlert = DataManager.shared.shouldShowRatingPrompt()
            }
        }
    }
    
    /// Creates a single instruction card with icon, title and description
    /// Used to keep the UI consistent across all instruction steps
    private func instructionCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.title3.bold())
            }
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

#Preview {
    InstructionsView(ratingAlert: .constant(false))
}
