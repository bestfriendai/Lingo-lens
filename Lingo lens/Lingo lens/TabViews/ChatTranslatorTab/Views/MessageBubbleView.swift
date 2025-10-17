//
//  MessageBubbleView.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import SwiftUI

/// Displays a single chat message with original and translated text
struct MessageBubbleView: View, Equatable {

    let message: ChatMessage
    let onSpeakOriginal: () -> Void
    let onSpeakTranslated: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopyConfirmation = false
    @State private var copiedSection: CopiedSection? = nil
    @State private var copyTask: Task<Void, Never>?

    // Prepared haptic generator for better performance
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    // Equatable implementation to prevent unnecessary redraws
    static func == (lhs: MessageBubbleView, rhs: MessageBubbleView) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.originalText == rhs.message.originalText &&
        lhs.message.translatedText == rhs.message.translatedText
    }

    enum CopiedSection {
        case original, translated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Original text section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Language label with speech badge
                    HStack(spacing: 4) {
                        Text(message.sourceLanguage.localizedName())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        if message.isFromSpeech {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(.blue))
                                .accessibilityLabel("From speech")
                                .accessibilityHint("This message was transcribed from speech")
                        }
                    }

                    Spacer()

                    // Speaker button with enhanced design
                    SpeakerButton(color: .blue, action: onSpeakOriginal)
                }

                Text(message.originalText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Original text: \(message.originalText)")
                    .accessibilityAddTraits(.isStaticText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(originalTextBackground)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                           radius: 4, x: 0, y: 2)
            )
            .contextMenu {
                Button(action: { copyText(message.originalText, section: .original) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .accessibilityLabel("Copy original text")
                .accessibilityHint("Copy the original text to clipboard")
            }

            // Translation arrow with better visual hierarchy
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Translation")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 14)

            // Translated text section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(message.targetLanguage.localizedName())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Speaker button with enhanced design
                    SpeakerButton(color: .green, action: onSpeakTranslated)
                }

                Text(message.translatedText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Translated text: \(message.translatedText)")
                    .accessibilityAddTraits(.isStaticText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(translatedTextBackground)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                           radius: 4, x: 0, y: 2)
            )
            .contextMenu {
                Button(action: { copyText(message.translatedText, section: .translated) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .accessibilityLabel("Copy translated text")
                .accessibilityHint("Copy the translated text to clipboard")
            }

            // Timestamp with better styling
            HStack {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if showCopyConfirmation, let copied = copiedSection {
                    Text("• Copied \(copied == .original ? "original" : "translation")")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .accessibilityLabel("Copied \(copied == .original ? "original" : "translation")")
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.leading, 14)
            .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onAppear {
            // Prepare haptic generator for better performance
            impactGenerator.prepare()
        }
        .onDisappear {
            // Cancel copy task if view disappears
            copyTask?.cancel()
        }
    }

    // MARK: - Copy Functionality

    private func copyText(_ text: String, section: CopiedSection) {
        // Cancel existing task
        copyTask?.cancel()

        UIPasteboard.general.string = text

        // Haptic feedback using prepared generator
        impactGenerator.impactOccurred()

        // Show confirmation
        copiedSection = section
        withAnimation {
            showCopyConfirmation = true
        }

        // Hide after 2 seconds using Task instead of DispatchQueue
        copyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                showCopyConfirmation = false
            }
        }
    }

    // MARK: - Background Colors

    private var originalTextBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }

    private var translatedTextBackground: Color {
        colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.12)
    }
}

// MARK: - Speaker Button Component

struct SpeakerButton: View {
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    // Prepared haptic generator for better performance
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button(action: {
            // Haptic feedback using prepared generator
            impactGenerator.impactOccurred()

            action()
        }) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
                .scaleEffect(isPressed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color == .blue ? "Speak original text" : "Speak translated text")
        .accessibilityHint("Tap to hear pronunciation")
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            // Prepare haptic generator for better performance
            impactGenerator.prepare()
        }
    }
}

// MARK: - Preview

#Preview("Single Message") {
    let message = ChatMessage(
        originalText: "Hello, how are you?",
        translatedText: "Hola, ¿cómo estás?",
        sourceLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "en", region: "US")),
        targetLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES")),
        isFromSpeech: false
    )

    ScrollView {
        MessageBubbleView(
            message: message,
            onSpeakOriginal: { print("Speak original") },
            onSpeakTranslated: { print("Speak translated") }
        )
    }
}

#Preview("Speech Message") {
    let message = ChatMessage(
        originalText: "Where is the nearest restaurant?",
        translatedText: "¿Dónde está el restaurante más cercano?",
        sourceLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "en", region: "US")),
        targetLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES")),
        isFromSpeech: true
    )

    ScrollView {
        MessageBubbleView(
            message: message,
            onSpeakOriginal: { print("Speak original") },
            onSpeakTranslated: { print("Speak translated") }
        )
    }
}
