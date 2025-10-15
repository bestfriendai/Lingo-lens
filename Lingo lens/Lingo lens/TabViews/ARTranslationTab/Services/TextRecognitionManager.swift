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

    /// Detects ALL text in camera frame and returns individual words with their positions
    /// This version processes the entire frame for restaurant menu translation use case
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - completion: Callback with array of detected words or empty array if none found
    func recognizeAllText(pixelBuffer: CVPixelBuffer,
                         exifOrientation: CGImagePropertyOrientation,
                         completion: @escaping ([DetectedWord]) -> Void) {

        // Perform all heavy processing on background queue
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion([])
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
                completion([])
                return
            }

            // Create text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    SecureLogger.logError("Text recognition request failed", error: error)
                    completion([])
                    return
                }

                // Process recognized text observations
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion([])
                    return
                }

                var detectedWords: [DetectedWord] = []

                for observation in observations {
                    // Get top candidate text
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    // Split text into individual words
                    let text = topCandidate.string
                    let words = text.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }

                    // Calculate approximate bounding box per word
                    let totalChars = text.count
                    let boundingBox = observation.boundingBox

                    var currentCharIndex = 0
                    for word in words {
                        // Filter out non-alphabetic words and very short words
                        let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters)
                        if cleanedWord.count >= 2 && cleanedWord.rangeOfCharacter(from: .letters) != nil {

                            // Estimate word's bounding box position within the line
                            let wordCharCount = word.count
                            let wordRatio = CGFloat(wordCharCount) / CGFloat(max(totalChars, 1))
                            let charOffset = CGFloat(currentCharIndex) / CGFloat(max(totalChars, 1))

                            // Create approximate bounding box for this word
                            let wordBoundingBox = CGRect(
                                x: boundingBox.origin.x + (boundingBox.width * charOffset),
                                y: boundingBox.origin.y,
                                width: boundingBox.width * wordRatio,
                                height: boundingBox.height
                            )

                            let detectedWord = DetectedWord(
                                text: cleanedWord,
                                confidence: topCandidate.confidence,
                                boundingBox: wordBoundingBox
                            )
                            detectedWords.append(detectedWord)
                        }
                        currentCharIndex += word.count + 1 // +1 for space
                    }
                }

                #if DEBUG
                SecureLogger.log("Text recognition found \(detectedWords.count) words in full frame", level: .info)
                #endif

                completion(detectedWords)
            }

            // Configure recognition settings for better accuracy and performance
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = self.recognitionLanguages

            // NO region of interest - process entire frame
            // Filter out very small text to reduce noise
            request.minimumTextHeight = 0.015 // 1.5% of image height for better menu detection

            // Run the image through Vision framework
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                SecureLogger.logError("Vision text recognition failed", error: error)
                completion([])
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
                completion([])
                return
            }

            // Convert pixel buffer to CIImage and fix orientation
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                .oriented(forExifOrientation: exifOrientation.numericValue)

            // Convert CIImage to CGImage for Vision framework
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                SecureLogger.logError("Failed to create CGImage from CIImage for text recognition")
                completion([])
                return
            }

            // Create text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    SecureLogger.logError("Text recognition request failed", error: error)
                    completion([])
                    return
                }

                // Process recognized text observations
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion([])
                    return
                }

                var detectedWords: [DetectedWord] = []

                for observation in observations {
                    // Get top candidate text
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    // Split text into individual words
                    let text = topCandidate.string
                    let words = text.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }

                    for word in words {
                        // Filter out non-alphabetic words and very short words
                        let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters)
                        if cleanedWord.count >= 2 && cleanedWord.rangeOfCharacter(from: .letters) != nil {
                            let detectedWord = DetectedWord(
                                text: cleanedWord,
                                confidence: topCandidate.confidence,
                                boundingBox: observation.boundingBox
                            )
                            detectedWords.append(detectedWord)
                        }
                    }
                }

                completion(detectedWords)
            }

            // Configure recognition settings for better accuracy and performance
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = self.recognitionLanguages
            request.regionOfInterest = normalizedROI
            request.minimumTextHeight = 0.03 // 3% of image height

            // Run the image through Vision framework
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                SecureLogger.logError("Vision text recognition failed", error: error)
                completion([])
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
    var isConfident: Bool {
        return confidence > 0.5
    }
}
