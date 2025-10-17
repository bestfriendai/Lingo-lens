//
//  ChatTranslatorView.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import SwiftUI
import Translation

/// Main view for the chat-based translator tab
struct ChatTranslatorView: View {

    @StateObject private var viewModel: ChatTranslatorViewModel
    @EnvironmentObject var translationService: TranslationService
    @EnvironmentObject var diContainer: DIContainer

    @State private var showLanguageSelectionSheet = false
    @State private var isSelectingSourceLanguage = true
    @State private var scrollToBottom = false
    
    private var speechRecognitionManager: SpeechRecognitionManager {
        diContainer.speechRecognitionManager
    }

    init(translationService: TranslationService, diContainer: DIContainer) {
        _viewModel = StateObject(wrappedValue: diContainer.makeChatTranslatorViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Language selection bar
                languageBar

                // Messages list
                messagesList

                // Input bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    speechRecognitionManager: speechRecognitionManager,
                    onSend: {
                        viewModel.translateText(viewModel.inputText)
                    },
                    onStartRecording: {
                        viewModel.startSpeechRecognition()
                    },
                    onStopRecording: {
                        Task {
                            await viewModel.stopSpeechRecognition()
                        }
                    }
                )
            }
            .navigationTitle(Text(localized: "chat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.clearMessages() }) {
                            Label {
                                Text(localized: "chat.clear_all")
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                        .accessibilityLabel("Clear all messages")
                        .accessibilityHint("Delete all conversation history")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("More options")
                            .accessibilityHint("Open menu with additional options")
                    }
                }
            }
            .sheet(isPresented: $showLanguageSelectionSheet) {
                languageSelectionSheet
            }
            .alert("chat.translation_error", isPresented: $viewModel.showError) {
                Button("action.ok", role: .cancel) {
                    viewModel.errorMessage = nil
                    viewModel.showError = false
                }
                .accessibilityLabel("Dismiss error")
                .accessibilityHint("Close the translation error alert")
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .accessibilityLabel("Error message: \(errorMessage)")
                }
            }
            .overlay(alignment: .top) {
                // Loading indicator for translation
                if viewModel.isTranslating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("Translating")
                            .accessibilityAddTraits(.updatesFrequently)
                        Text("loading.translating")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .accessibilityLabel("Translating...")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.blue)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isTranslating)
                }
            }
        }
        .onAppear {
            SecureLogger.log("ChatTranslatorView appeared", level: .info)
            // Only update session if not already configured
            if viewModel.translationConfiguration == nil {
                viewModel.updateTranslationSession()
            }
        }
        .translationTask(viewModel.translationConfiguration) { session in
            // Mark session as ready
            await MainActor.run {
                viewModel.markSessionReady()
            }

            // Process pending translations
            for await request in viewModel.$pendingTranslation.values {
                // Skip nil values (no translation pending)
                guard let translation = request else { continue }

                // Process this translation
                do {
                    print("🔄 Processing translation for: \"\(translation.text)\"")
                    let response = try await session.translate(translation.text)

                    await MainActor.run {
                        viewModel.handleTranslationResult(response.targetText, for: translation)
                    }
                } catch {
                    print("❌ Translation failed: \(error.localizedDescription)")
                    await MainActor.run {
                        viewModel.pendingTranslation = nil
                        viewModel.isTranslating = false
                        viewModel.handleTranslationError(.unknown(error.localizedDescription))
                    }
                }
            }
        }
        .onDisappear {
            SecureLogger.log("ChatTranslatorView disappeared", level: .info)
            // Only clean up pending translation, keep session configuration
            viewModel.pendingTranslation = nil
            viewModel.isTranslating = false
            // Note: Keep isSessionReady and translationConfiguration for faster return
        }
    }
    
    // MARK: - Language Bar

    private var languageBar: some View {
        HStack(spacing: 10) {
            // Source language button
            Button(action: {
                isSelectingSourceLanguage = true
                showLanguageSelectionSheet = true
            }) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("chat.from")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(viewModel.sourceLanguage.localizedName())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Source language: \(viewModel.sourceLanguage.localizedName())")
            .accessibilityHint("Tap to change source language")
            .accessibilityAddTraits(.isButton)

            // Swap languages button with rotation animation
            Button(action: {
                viewModel.swapLanguages()
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap languages")
            .accessibilityHint("Swap source and target languages")
            .accessibilityAddTraits(.isButton)

            // Target language button
            Button(action: {
                isSelectingSourceLanguage = false
                showLanguageSelectionSheet = true
            }) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("chat.to")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(viewModel.targetLanguage.localizedName())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Target language: \(viewModel.targetLanguage.localizedName())")
            .accessibilityHint("Tap to change target language")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                onSpeakOriginal: {
                                    viewModel.speakOriginalText(of: message)
                                },
                                onSpeakTranslated: {
                                    viewModel.speakTranslatedText(of: message)
                                }
                            )
                            .equatable()
                            .id(message.id)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteMessage(message)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete message")
                                .accessibilityHint("Remove this message from conversation")
                            }
                        }
                    }

                    // Invisible anchor for auto-scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) {
                // Scroll to bottom when new message is added
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("chat.start_conversation")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("chat.start_conversation_description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 14) {
                FeatureTip(
                    icon: "keyboard",
                    color: .blue,
                    titleKey: "chat.type_to_translate",
                    descriptionKey: "chat.type_to_translate_description"
                )

                FeatureTip(
                    icon: "mic.fill",
                    color: .green,
                    titleKey: "chat.speak_naturally",
                    descriptionKey: "chat.speak_naturally_description"
                )

                FeatureTip(
                    icon: "speaker.wave.2.fill",
                    color: .orange,
                    titleKey: "chat.hear_pronunciations",
                    descriptionKey: "chat.hear_pronunciations_description"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Language Selection Sheet

    private var languageSelectionSheet: some View {
        NavigationStack {
            List(translationService.availableLanguages) { language in
                let isSelected = isSelectingSourceLanguage ?
                    language.shortName() == viewModel.sourceLanguage.shortName() :
                    language.shortName() == viewModel.targetLanguage.shortName()

                Button(action: {
                    if isSelectingSourceLanguage {
                        viewModel.updateSourceLanguage(language)
                    } else {
                        viewModel.updateTargetLanguage(language)
                    }
                    showLanguageSelectionSheet = false
                }) {
                    HStack(spacing: 12) {
                        Text(language.localizedName())
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    isSelected ?
                        Color.blue.opacity(0.08) :
                        Color(.systemBackground)
                )
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isSelectingSourceLanguage ? "chat.source_language".localized() : "chat.target_language".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.done".localized()) {
                        showLanguageSelectionSheet = false
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close language selection")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Feature Tip Component

struct FeatureTip: View {
    let icon: String
    let color: Color
    let titleKey: String
    let descriptionKey: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(descriptionKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview {
    createChatTranslatorPreview()
}

@MainActor
private func createChatTranslatorPreview() -> some View {
    let translationService = TranslationService()
    translationService.availableLanguages = [
        AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: Locale.Language(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: Locale.Language(languageCode: "de", region: "DE"))
    ]

    let diContainer = DIContainer.shared
    return ChatTranslatorView(translationService: translationService, diContainer: diContainer)
        .environmentObject(translationService)
        .environmentObject(diContainer)
        .environmentObject(diContainer.appearanceManager as! AppearanceManager)
}
