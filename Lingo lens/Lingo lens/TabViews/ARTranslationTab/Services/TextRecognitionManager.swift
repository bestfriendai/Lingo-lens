//
//  TextRecognitionManager.swift
//  Lingo lens
//
//  Handles automatic text recognition using Vision framework
//  Detects words in camera frames and enables automatic translation
//

import Foundation
import Vision
import CoreImage
import AVFoundation

/// Manages automatic text recognition from camera frames
/// Uses Vision framework to detect text and extract individual words for translation
class TextRecognitionManager {

    // CIContext for efficient image processing operations (reused across all detections)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Dedicated queue for background processing
    private let processingQueue = DispatchQueue(label: "com.lingolens.textrecognition", qos: .userInitiated)

    // Recognition languages to optimize accuracy
    private var recognitionLanguages: [String] = ["en-US"]

    // Cache for improved performance
    private let textCache = NSCache<NSString, NSArray>()

    // MARK: - Setup

    init() {
        // Configure text cache
        textCache.countLimit = 20
    }

    // MARK: - Text Recognition

    /// Detects ALL text in camera frame and returns complete phrases with their positions
    /// This version processes the entire frame for restaurant menu translation use case
    /// Phrases are detected as complete text observations (e.g., "TAKE A RISK" instead of "TAKE", "A", "RISK")
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - completion: Callback with array of detected phrases or empty array if none found
    func recognizeAllText(pixelBuffer: CVPixelBuffer,
                         exifOrientation: CGImagePropertyOrientation,
                         completion: @escaping ([DetectedWord]) -> Void) {

        // Perform all heavy processing on background queue
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            #if DEBUG
            SecureLogger.log("Starting full-frame text recognition", level: .info)
            #endif

            // Convert pixel buffer to CIImage and fix orientation
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                .oriented(forExifOrientation: exifOrientation.numericValue)

            // Convert CIImage to CGImage for Vision framework
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                SecureLogger.logError("Failed to create CGImage from CIImage for text recognition")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            // Create text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    SecureLogger.logError("Text recognition request failed", error: error)
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                // Process recognized text observations
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                var detectedWords: [DetectedWord] = []
                var seenPhrases = Set<String>() // Track phrases to prevent duplicates

                for observation in observations {
                    // Get top candidate text
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    // Use entire observation as a phrase (don't split into individual words)
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    let boundingBox = observation.boundingBox

                    // IMPROVED FILTER: Support BOTH individual words AND phrases
                    // - Allow single characters if they're letters (e.g., "A", "I")
                    // - Allow 2+ character words/phrases
                    // - Must contain at least one letter
                    // - Allow some non-letter characters (numbers, punctuation)
                    let letterCount = text.filter { $0.isLetter || $0.isWhitespace }.count
                    let hasLetters = text.rangeOfCharacter(from: .letters) != nil
                    let isValid = text.count >= 1 &&  // Allow single characters
                                 hasLetters &&  // Must have at least one letter
                                 letterCount >= max(1, text.count - 3)  // Allow up to 3 non-letter/space chars

                    if isValid {
                        // Skip if we've already seen this phrase (deduplication)
                        let lowercasedPhrase = text.lowercased()
                        if seenPhrases.contains(lowercasedPhrase) {
                            continue
                        }
                        seenPhrases.insert(lowercasedPhrase)

                        let detectedWord = DetectedWord(
                            text: text,
                            confidence: topCandidate.confidence,
                            boundingBox: boundingBox
                        )
                        detectedWords.append(detectedWord)
                    }
                }

                #if DEBUG
                SecureLogger.log("Text recognition found \(detectedWords.count) phrases in full frame", level: .info)
                #endif

                DispatchQueue.main.async {
                    completion(detectedWords)
                }
            }

            // Google Translate mode: Optimize for SPEED while maintaining accuracy
            request.recognitionLevel = .fast  // Fast mode for real-time performance
            request.usesLanguageCorrection = false  // Disable for speed
            request.recognitionLanguages = self.recognitionLanguages

            // Lower minimum text height to detect more text (like Google Translate)
            request.minimumTextHeight = 0.015 // 1.5% of image height

            // Use latest revision for best speed
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            // NO region of interest - process full frame for accurate positioning

            // Run the image through Vision framework
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                SecureLogger.logError("Vision text recognition failed", error: error)
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    /// Detects text in a specific region for object detection mode
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - normalizedROI: Region of interest in normalized coordinates (0-1)
    ///   - completion: Callback with array of detected words or empty array if none found
    func recognizeTextInROI(pixelBuffer: CVPixelBuffer,
                           exifOrientation: CGImagePropertyOrientation,
                           normalizedROI: CGRect,
                           completion: @escaping ([DetectedWord]) -> Void) {

        // Perform all heavy processing on background queue
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            // Convert pixel buffer to CIImage and fix orientation
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                .oriented(forExifOrientation: exifOrientation.numericValue)

            // Convert CIImage to CGImage for Vision framework
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                SecureLogger.logError("Failed to create CGImage from CIImage for text recognition")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            // Create text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    SecureLogger.logError("Text recognition request failed", error: error)
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                // Process recognized text observations
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                var detectedWords: [DetectedWord] = []

                for observation in observations {
                    // Get top candidate text
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    // Use the ENTIRE detected text as a phrase (don't split into words)
                    // This gives better context for translation
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

                    // IMPROVED FILTER: Support BOTH individual words AND phrases
                    // - Allow single characters if they're letters (e.g., "A", "I")
                    // - Allow 1+ character words/phrases
                    // - Must contain at least one letter
                    // - Allow some non-letter characters (numbers, punctuation)
                    let letterCount = text.filter { $0.isLetter || $0.isWhitespace }.count
                    let hasLetters = text.rangeOfCharacter(from: .letters) != nil
                    let isValid = text.count >= 1 &&  // Allow single characters
                                 hasLetters &&  // Must have at least one letter
                                 letterCount >= max(1, text.count - 3)  // Allow up to 3 non-letter/space chars

                    if isValid {
                        let detectedWord = DetectedWord(
                            text: text,
                            confidence: topCandidate.confidence,
                            boundingBox: observation.boundingBox
                        )
                        detectedWords.append(detectedWord)
                    }
                }

                DispatchQueue.main.async {
                    completion(detectedWords)
                }
            }

            // Configure recognition settings for better accuracy in ROI
            request.recognitionLevel = .accurate  // Use accurate mode for better quality
            request.usesLanguageCorrection = true  // Enable for better accuracy
            request.recognitionLanguages = self.recognitionLanguages
            request.regionOfInterest = normalizedROI
            request.minimumTextHeight = 0.02  // Lowered from 0.03 to detect smaller text (2% of image height)

            // Run the image through Vision framework
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                SecureLogger.logError("Vision text recognition failed", error: error)
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    /// Updates the recognition languages for better accuracy
    /// - Parameter languages: Array of language codes (e.g., ["en-US", "es-ES"])
    func updateRecognitionLanguages(_ languages: [String]) {
        self.recognitionLanguages = languages
    }
}

/// Represents a detected word with its metadata and translation
struct DetectedWord: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    var translation: String? = nil

    /// Returns true if confidence is above minimum threshold
    /// Lower threshold for .fast mode (Google Translate-style)
    var isConfident: Bool {
        return confidence > 0.2  // Lower threshold for fast mode
    }

    /// Determines if this is a single word vs multi-word phrase
    var isSingleWord: Bool {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count == 1
    }

    /// Returns the word count
    var wordCount: Int {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    /// Type of detected text for smarter handling
    enum TextType {
        case shortWord      // 1 word, < 5 chars (e.g., "MON", "TUE", "GET")
        case mediumWord     // 1 word, 5-10 chars (e.g., "MONDAY", "WORKING")
        case longWord       // 1 word, > 10 chars (e.g., "PROCRASTINATION")
        case shortPhrase    // 2-3 words (e.g., "GET IT DONE")
        case longPhrase     // 4+ words (e.g., "NEVER NOT WORKING ON WEEKENDS")
    }

    /// Categorizes the detected text for optimal handling
    var textType: TextType {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count == 1 {
            let length = text.count
            if length < 5 {
                return .shortWord
            } else if length <= 10 {
                return .mediumWord
            } else {
                return .longWord
            }
        } else if words.count <= 3 {
            return .shortPhrase
        } else {
            return .longPhrase
        }
    }
}
