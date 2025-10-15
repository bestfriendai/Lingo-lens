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

    /// Detects text in camera frame and returns individual words with their positions
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - normalizedROI: Optional region of interest in normalized coordinates (0-1)
    ///   - completion: Callback with array of detected words or empty array if none found
    func recognizeText(pixelBuffer: CVPixelBuffer,
                      exifOrientation: CGImagePropertyOrientation,
                      normalizedROI: CGRect? = nil,
                      completion: @escaping ([DetectedWord]) -> Void) {

        // Perform all heavy processing on background queue
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }

            #if DEBUG
            SecureLogger.log("Starting text recognition", level: .info)
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
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else { return }

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

                    // Filter ROI if specified
                    if let roi = normalizedROI {
                        let textBounds = observation.boundingBox
                        // Check if text overlaps with ROI
                        if !textBounds.intersects(roi) {
                            continue
                        }
                    }

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

                #if DEBUG
                SecureLogger.log("Text recognition found \(detectedWords.count) words", level: .info)
                #endif

                completion(detectedWords)
            }

            // Configure recognition settings for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = self.recognitionLanguages

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

/// Represents a detected word with its metadata
struct DetectedWord {
    let text: String
    let confidence: Float
    let boundingBox: CGRect

    /// Returns true if confidence is above minimum threshold
    var isConfident: Bool {
        return confidence > 0.5
    }
}
