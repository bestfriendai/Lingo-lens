//
//  SpeechRecognitionManager.swift
//  Lingo lens
//
//  Created by Claude Code on 10/14/25.
//

import Speech
import AVFoundation
import SwiftUI

/// Singleton manager for handling speech recognition (speech-to-text)
/// Converts spoken words into text for translation
class SpeechRecognitionManager: NSObject, ObservableObject {

    // Shared instance for whole app to use
    static let shared = SpeechRecognitionManager()

    // MARK: - Published Properties

    // True when actively listening to speech
    @Published var isRecording = false

    // Recognized text from speech
    @Published var recognizedText = ""

    // Error message if recognition fails
    @Published var errorMessage: String?

    // Authorization status for speech recognition
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    // Speech recognizer for the current language
    private var speechRecognizer: SFSpeechRecognizer?

    // Recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // Recognition task
    private var recognitionTask: SFSpeechRecognitionTask?

    // Audio engine for capturing microphone input
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    private override init() {
        super.init()
        // Initialize with English by default
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self

        // Get current authorization status
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Authorization

    /// Requests authorization to use speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        print("🎤 Requesting speech recognition authorization")

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status

                switch status {
                case .authorized:
                    print("✅ Speech recognition authorized")
                    completion(true)
                case .denied:
                    print("❌ Speech recognition denied")
                    self.errorMessage = "Speech recognition access denied. Please enable it in Settings."
                    completion(false)
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self.errorMessage = "Speech recognition is restricted on this device."
                    completion(false)
                case .notDetermined:
                    print("⚠️ Speech recognition not determined")
                    completion(false)
                @unknown default:
                    print("❌ Unknown speech recognition status")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Language Selection

    /// Updates the speech recognizer for a specific language
    /// - Parameter languageCode: Language code (e.g., "en-US", "es-ES")
    func setLanguage(_ languageCode: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        speechRecognizer?.delegate = self
    }

    // MARK: - Recording Control

    /// Starts recording and recognizing speech
    func startRecording() throws {
        print("🎤 Starting speech recognition")

        // Cancel any ongoing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio engine input
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                // Update recognized text
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                    print("📝 Recognized text: \(self.recognizedText)")
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                print("🛑 Speech recognition ended - Error: \(error?.localizedDescription ?? "none"), isFinal: \(isFinal)")

                // Stop audio engine
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                DispatchQueue.main.async {
                    self.isRecording = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.recognizedText = ""
            self.errorMessage = nil
            self.isRecording = true
        }

        print("✅ Speech recognition started successfully")
    }

    /// Stops recording and finalizes recognition
    func stopRecording() {
        print("🛑 Stopping speech recognition")

        audioEngine.stop()
        recognitionRequest?.endAudio()

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    /// Clears recognized text
    func clearText() {
        recognizedText = ""
        errorMessage = nil
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition is not available"
            }
        }
    }
}
