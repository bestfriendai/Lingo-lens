//
//  ChatMessage.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import Foundation

/// Represents a single message in the chat translator
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let originalText: String
    let translatedText: String
    let sourceLanguage: AvailableLanguage
    let targetLanguage: AvailableLanguage
    let timestamp: Date
    let isFromSpeech: Bool // True if message originated from speech input

    init(
        id: UUID = UUID(),
        originalText: String,
        translatedText: String,
        sourceLanguage: AvailableLanguage,
        targetLanguage: AvailableLanguage,
        timestamp: Date = Date(),
        isFromSpeech: Bool = false
    ) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFromSpeech = isFromSpeech
    }
}
