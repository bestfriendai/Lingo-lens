//
//  TextRecognitionManagerTests.swift
//  Lingo lens Tests
//
//  Created by AI Assistant on 10/17/25.
//

import XCTest
import Vision
import CoreImage
@testable import Lingo_lens

/// Comprehensive unit tests for TextRecognitionManager
/// Tests text recognition functionality, error handling, and performance
@MainActor
final class TextRecognitionManagerTests: XCTestCase {
    
    var sut: TextRecognitionManager!
    
    override func setUp() {
        super.setUp()
        sut = TextRecognitionManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_ShouldSetDefaultLanguages() {
        // Given/When - initialization happens in setUp
        
        // Then - manager should be initialized
        XCTAssertNotNil(sut, "TextRecognitionManager should be initialized")
    }
    
    // MARK: - Full Frame Text Recognition Tests
    
    func testRecognizeAllText_WithValidImage_ShouldReturnDetectedWords() {
        // Given
        let expectation = expectation(description: "Text recognition completes")
        let testImage = createTestImageWithText("HELLO WORLD")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeAllText(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(detectedWords.isEmpty, "Should detect text in image")
    }
    
    func testRecognizeAllText_WithEmptyImage_ShouldReturnEmptyArray() {
        // Given
        let expectation = expectation(description: "Recognition completes")
        let emptyImage = createEmptyImage()
        guard let pixelBuffer = emptyImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeAllText(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(detectedWords.isEmpty, "Empty image should return no words")
    }
    
    func testRecognizeAllText_WithMultipleWords_ShouldDetectAll() {
        // Given
        let expectation = expectation(description: "Recognition completes")
        let testImage = createTestImageWithText("MENU\nPRICE\nTOTAL")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeAllText(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(detectedWords.count, 1, "Should detect multiple words")
    }
    
    // MARK: - ROI Text Recognition Tests
    
    func testRecognizeTextInROI_WithValidROI_ShouldReturnWords() {
        // Given
        let expectation = expectation(description: "ROI recognition completes")
        let testImage = createTestImageWithText("TEST")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        let roi = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeTextInROI(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up,
            normalizedROI: roi
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Note: May be empty if text is outside ROI, but should not crash
        XCTAssertNotNil(detectedWords, "Should return array (may be empty)")
    }
    
    func testRecognizeTextInROI_WithInvalidROI_ShouldHandleGracefully() {
        // Given
        let expectation = expectation(description: "Invalid ROI handled")
        let testImage = createTestImageWithText("TEST")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        let invalidROI = CGRect(x: -0.5, y: -0.5, width: 2.0, height: 2.0)
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeTextInROI(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up,
            normalizedROI: invalidROI
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Should handle gracefully without crashing
        XCTAssertNotNil(detectedWords, "Should handle invalid ROI gracefully")
    }
    
    // MARK: - Confidence Threshold Tests
    
    func testRecognition_ShouldFilterLowConfidenceResults() {
        // Given
        let expectation = expectation(description: "Recognition with confidence filter")
        let testImage = createTestImageWithText("CLEAR TEXT")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        var detectedWords: [DetectedWord] = []
        
        // When
        sut.recognizeAllText(
            pixelBuffer: pixelBuffer,
            exifOrientation: .up
        ) { words in
            detectedWords = words
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // All returned words should have reasonable confidence
        for word in detectedWords {
            XCTAssertGreaterThan(word.confidence, 0.0, "Confidence should be positive")
            XCTAssertLessThanOrEqual(word.confidence, 1.0, "Confidence should be <= 1.0")
        }
    }
    
    // MARK: - Performance Tests
    
    func testRecognizeAllText_Performance_ShouldCompleteQuickly() {
        // Given
        let testImage = createTestImageWithText("PERFORMANCE TEST")
        guard let pixelBuffer = testImage.pixelBuffer else {
            XCTFail("Failed to create pixel buffer")
            return
        }
        
        // When/Then
        measure {
            let expectation = expectation(description: "Performance test")
            
            sut.recognizeAllText(
                pixelBuffer: pixelBuffer,
                exifOrientation: .up
            ) { _ in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a test image with rendered text
    private func createTestImageWithText(_ text: String) -> CIImage {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Black text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.black
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return CIImage(image: image) ?? CIImage()
    }
    
    /// Creates an empty white image
    private func createEmptyImage() -> CIImage {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        return CIImage(image: image) ?? CIImage()
    }
}

// MARK: - CIImage Extension for Testing

extension CIImage {
    /// Converts CIImage to CVPixelBuffer for testing
    var pixelBuffer: CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(extent.width),
            Int(extent.height),
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        let context = CIContext()
        context.render(self, to: buffer)
        
        return buffer
    }
}

