//
//  ChatInputBar.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import SwiftUI

/// Input bar for entering text or recording speech
struct ChatInputBar: View {

    @Binding var text: String
    @ObservedObject var speechRecognitionManager: SpeechRecognitionManager

    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseAnimation = false

    // Character limits
    private let characterLimit = 500
    private var characterCount: Int { text.count }
    private var isNearLimit: Bool { characterCount > characterLimit - 50 }
    private var isOverLimit: Bool { characterCount > characterLimit }

    // Prepared haptic generators for better performance
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    textInputField
                    actionButton.transition(.scale.combined(with: .opacity))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if isNearLimit && !speechRecognitionManager.isRecording {
                    characterCountView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: speechRecognitionManager.isRecording)
            .animation(.easeInOut(duration: 0.2), value: isNearLimit)

            if speechRecognitionManager.isRecording {
                recordingIndicator
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Prepare haptic generators for better performance
            lightGenerator.prepare()
            mediumGenerator.prepare()
            heavyGenerator.prepare()
        }
    }

    // MARK: - Text Input Field

    private var textInputField: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .lineLimit(1...5)
                .submitLabel(.send)
                .disabled(speechRecognitionManager.isRecording)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message here to translate")
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOverLimit {
                        hapticFeedback(.light)
                        onSend()
                    }
                }
                .onChange(of: text) {
                    if text.count > characterLimit {
                        text = String(text.prefix(characterLimit))
                        hapticFeedback(.heavy)
                    }
                }

            if !text.isEmpty && !speechRecognitionManager.isRecording {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                    }
                    hapticFeedback(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear text")
                .accessibilityHint("Clear the message input field")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(textInputBackground)
        .opacity(speechRecognitionManager.isRecording ? 0.5 : 1.0)
    }

    private var textInputBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(textFieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isNearLimit ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
    }

    // MARK: - Character Count

    private var characterCountView: some View {
        HStack {
            Spacer()
            Text("\(characterCount)/\(characterLimit)")
                .font(.caption2)
                .foregroundStyle(isOverLimit ? .red : .orange)
                .padding(.horizontal, 16)
                .accessibilityLabel("Character count: \(characterCount) of \(characterLimit)")
                .accessibilityHint(isOverLimit ? "Character limit exceeded" : "Characters remaining: \(characterLimit - characterCount)")
                .accessibilityAddTraits(.updatesFrequently)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                waveformBars

                Text("Listening...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Listening for speech")
                    .accessibilityAddTraits(.updatesFrequently)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            if !speechRecognitionManager.recognizedText.isEmpty {
                recognizedTextView
            }
        }
        .padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            pulseAnimation = true
        }
    }

    private var waveformBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3, height: waveformHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: pulseAnimation
                    )
            }
        }
    }

    private var recognizedTextView: some View {
        HStack {
            Text(speechRecognitionManager.recognizedText)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )
                .accessibilityLabel("Recognized speech: \(speechRecognitionManager.recognizedText)")
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if speechRecognitionManager.isRecording {
            // Stop recording button
            AnimatedActionButton(
                icon: "stop.fill",
                color: .red,
                action: {
                    hapticFeedback(.medium)
                    onStopRecording()
                    pulseAnimation = false
                }
            )
        } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Microphone button
            AnimatedActionButton(
                icon: "mic.fill",
                color: .blue,
                action: {
                    hapticFeedback(.medium)
                    isTextFieldFocused = false
                    onStartRecording()
                }
            )
        } else {
            // Send button
            AnimatedActionButton(
                icon: "arrow.up",
                color: .blue,
                isDisabled: isOverLimit,
                action: {
                    hapticFeedback(.light)
                    onSend()
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let variation: CGFloat = pulseAnimation ? maxHeight : baseHeight

        // Create different heights for visual interest
        switch index {
        case 0: return variation * 0.6
        case 1: return variation * 1.0
        case 2: return variation * 0.8
        default: return variation * 0.7
        }
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // Use prepared generators for better performance
        switch style {
        case .light, .soft, .rigid:
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        @unknown default:
            lightGenerator.impactOccurred()
        }
    }

    // MARK: - Background Color

    private var textFieldBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }
    
    // MARK: - Accessibility Helpers
    
    private func actionLabel(for icon: String) -> String {
        switch icon {
        case "mic.fill":
            return "Start recording"
        case "stop.fill":
            return "Stop recording"
        case "arrow.up":
            return "Send message"
        default:
            return "Action button"
        }
    }
    
    private func actionHint(for icon: String) -> String {
        switch icon {
        case "mic.fill":
            return "Tap to start speech recognition"
        case "stop.fill":
            return "Tap to stop recording and translate"
        case "arrow.up":
            return "Tap to send message for translation"
        default:
            return "Perform action"
        }
    }
}

// MARK: - Animated Action Button

struct AnimatedActionButton: View {
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isDisabled ? Color.gray.opacity(0.5) : color)
                    .frame(width: 44, height: 44)
                    .shadow(color: color.opacity(isPressed ? 0.2 : 0.4),
                           radius: isPressed ? 4 : 8,
                           x: 0, y: isPressed ? 2 : 4)

                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Action button")
        .accessibilityHint("Tap to perform action")
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview("Empty Input") {
    let diContainer = DIContainer.shared
    ChatInputBar(
        text: .constant(""),
        speechRecognitionManager: diContainer.speechRecognitionManager,
        onSend: { print("Send") },
        onStartRecording: { print("Start recording") },
        onStopRecording: { print("Stop recording") }
    )
}

#Preview("With Text") {
    let diContainer = DIContainer.shared
    ChatInputBar(
        text: .constant("Hello world!"),
        speechRecognitionManager: diContainer.speechRecognitionManager,
        onSend: { print("Send") },
        onStartRecording: { print("Start recording") },
        onStopRecording: { print("Stop recording") }
    )
}
