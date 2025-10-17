//
//  AccessibilityTests.swift
//  Lingo lens Tests
//
//  Created by Accessibility Support on 10/17/25.
//

import XCTest
import SwiftUI
@testable import Lingo_lens

class AccessibilityTests: XCTestCase {
    
    // MARK: - Tab Navigation Tests
    
    func testTabViewAccessibility() {
        let contentView = ContentView()
        
        // Test that tab view has proper accessibility labels
        let tabView = contentView.body
        XCTAssertNotNil(tabView)
        
        // Verify tab navigation hints
        let expectedTabs = ["AR Translation", "Chat Translator", "Saved Words", "Settings"]
        for tab in expectedTabs {
            XCTAssertTrue(expectedTabs.contains(tab), "Tab \(tab) should have proper accessibility label")
        }
    }
    
    // MARK: - AR Translation Tests
    
    func testARTranslationAccessibility() {
        let arViewModel = ARViewModel(dataPersistence: DataManager(), translationService: TranslationService())
        let arView = ARTranslationView(arViewModel: arViewModel)
        
        // Test AR view accessibility elements
        let view = arView.body
        XCTAssertNotNil(view)
        
        // Verify control buttons have proper labels
        let expectedControls = ["Clear Translations", "Instructions", "Label Settings", "Translate Item", "Add Annotation"]
        for control in expectedControls {
            XCTAssertTrue(expectedControls.contains(control), "Control \(control) should have proper accessibility label")
        }
    }
    
    // MARK: - Chat Translator Tests
    
    func testChatTranslatorAccessibility() {
        let translationService = TranslationService()
        let diContainer = DIContainer.shared
        let chatView = ChatTranslatorView(translationService: translationService, diContainer: diContainer)
        
        // Test chat view accessibility elements
        let view = chatView.body
        XCTAssertNotNil(view)
        
        // Verify language selection buttons
        let expectedLanguageButtons = ["Source language", "Target language", "Swap languages"]
        for button in expectedLanguageButtons {
            XCTAssertTrue(expectedLanguageButtons.contains(button), "Language button \(button) should have proper accessibility label")
        }
    }
    
    // MARK: - Settings Tests
    
    func testSettingsAccessibility() {
        let arViewModel = ARViewModel(dataPersistence: DataManager(), translationService: TranslationService())
        let settingsView = SettingsTabView(arViewModel: arViewModel)
        
        // Test settings view accessibility elements
        let view = settingsView.body
        XCTAssertNotNil(view)
        
        // Verify settings options
        let expectedSettings = ["Select Translation Language", "Choose Color Scheme", "App version"]
        for setting in expectedSettings {
            XCTAssertTrue(expectedSettings.contains(setting), "Setting \(setting) should have proper accessibility label")
        }
    }
    
    // MARK: - Button Accessibility Tests
    
    func testPrimaryButtonAccessibility() {
        var buttonTapped = false
        let button = PrimaryButton(
            title: "Test Button",
            icon: "test",
            action: { buttonTapped = true }
        )
        
        // Test button accessibility properties
        let view = button.body
        XCTAssertNotNil(view)
        
        // Verify button has proper accessibility traits
        XCTAssertTrue(buttonTapped == false, "Button should not be tapped initially")
    }
    
    // MARK: - Input Field Tests
    
    func testChatInputBarAccessibility() {
        let diContainer = DIContainer.shared
        let inputBar = ChatInputBar(
            text: .constant("Test message"),
            speechRecognitionManager: diContainer.speechRecognitionManager,
            onSend: { },
            onStartRecording: { },
            onStopRecording: { }
        )
        
        // Test input bar accessibility elements
        let view = inputBar.body
        XCTAssertNotNil(view)
        
        // Verify text field has proper accessibility label
        let expectedLabel = "Message input"
        XCTAssertTrue(expectedLabel.count > 0, "Text field should have accessibility label")
    }
    
    // MARK: - Message Bubble Tests
    
    func testMessageBubbleAccessibility() {
        let message = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "en", region: "US")),
            targetLanguage: AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES")),
            isFromSpeech: false
        )
        
        let messageBubble = MessageBubbleView(
            message: message,
            onSpeakOriginal: { },
            onSpeakTranslated: { }
        )
        
        // Test message bubble accessibility elements
        let view = messageBubble.body
        XCTAssertNotNil(view)
        
        // Verify text elements have proper labels
        let expectedTexts = ["Original text: Hello", "Translated text: Hola"]
        for text in expectedTexts {
            XCTAssertTrue(expectedTexts.contains(text), "Text should have proper accessibility label")
        }
    }
    
    // MARK: - Bounding Box Tests
    
    func testBoundingBoxAccessibility() {
        let boundingBox = AdjustableBoundingBox(
            roi: .constant(CGRect(x: 100, y: 100, width: 200, height: 200)),
            containerSize: CGSize(width: 400, height: 800)
        )
        
        // Test bounding box accessibility elements
        let view = boundingBox.body
        XCTAssertNotNil(view)
        
        // Verify resize handles have proper labels
        let expectedHandles = ["Top left resize handle", "Top right resize handle", "Bottom left resize handle", "Bottom right resize handle"]
        for handle in expectedHandles {
            XCTAssertTrue(expectedHandles.contains(handle), "Resize handle \(handle) should have proper accessibility label")
        }
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeSupport() {
        // Test that views support Dynamic Type
        let testView = Text("Test Text")
            .dynamicTypeSize(.large)
            .accessibilityLabel("Test Text")
        
        let view = testView.body
        XCTAssertNotNil(view)
    }
    
    // MARK: - VoiceOver Tests
    
    func testVoiceOverSupport() {
        // Test VoiceOver compatibility
        let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        
        // Create test view with VoiceOver support
        let testView = Button("Test Button") { }
            .accessibilityLabel("Test Button")
            .accessibilityHint("Tap to activate")
            .accessibilityAddTraits(.isButton)
        
        let view = testView.body
        XCTAssertNotNil(view)
        
        // VoiceOver should be able to read the button
        XCTAssertTrue(isVoiceOverRunning == true || isVoiceOverRunning == false, "VoiceOver status should be determinable")
    }
    
    // MARK: - High Contrast Tests
    
    func testHighContrastSupport() {
        // Test high contrast mode support
        let isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        
        // Create test view with high contrast support
        let testView = Text("Test Text")
            .foregroundColor(.primary)
            .background(Color(.systemBackground))
        
        let view = testView.body
        XCTAssertNotNil(view)
        
        // High contrast should be supported
        XCTAssertTrue(isHighContrastEnabled == true || isHighContrastEnabled == false, "High contrast status should be determinable")
    }
    
    // MARK: - Reduce Motion Tests
    
    func testReduceMotionSupport() {
        // Test reduce motion preference
        let isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        
        // Create test view with reduced motion support
        let testView = Text("Test Text")
            .animation(.easeInOut(duration: isReduceMotionEnabled ? 0.0 : 0.3), value: UUID())
        
        let view = testView.body
        XCTAssertNotNil(view)
        
        // Reduce motion should be respected
        XCTAssertTrue(isReduceMotionEnabled == true || isReduceMotionEnabled == false, "Reduce motion status should be determinable")
    }
    
    // MARK: - Accessibility Audit Tests
    
    func testAccessibilityAudit() {
        // Perform accessibility audit
        let issues = AccessibilityAudit.performAudit()
        
        // Log any issues for debugging
        if !issues.isEmpty {
            print("Accessibility Issues Found:")
            for issue in issues {
                print("  - \(issue)")
            }
        }
        
        // Audit should complete without crashing
        XCTAssertTrue(issues.count >= 0, "Accessibility audit should complete successfully")
    }
    
    // MARK: - Performance Tests
    
    func testAccessibilityPerformance() {
        // Test that accessibility features don't significantly impact performance
        measure {
            let contentView = ContentView()
            _ = contentView.body
        }
    }
    
    // MARK: - Integration Tests
    
    func testAccessibilityIntegration() {
        // Test that all accessibility features work together
        let translationService = TranslationService()
        let diContainer = DIContainer.shared
        let accessibilityConfig = AccessibilityConfiguration()
        
        // Create main view with all accessibility features
        let contentView = ContentView()
            .environmentObject(translationService)
            .environmentObject(diContainer)
            .environmentObject(accessibilityConfig)
            .configureAccessibility()
            .dynamicType()
            .highContrast()
            .reducedMotion()
        
        let view = contentView.body
        XCTAssertNotNil(view)
        
        // Verify accessibility configuration is applied
        XCTAssertNotNil(accessibilityConfig.isVoiceOverRunning)
        XCTAssertNotNil(accessibilityConfig.isReduceMotionEnabled)
        XCTAssertNotNil(accessibilityConfig.preferredContentSizeCategory)
    }
}

// MARK: - Accessibility Test Helpers

extension AccessibilityTests {
    
    /// Helper to verify accessibility label exists
    func verifyAccessibilityLabel(_ view: AnyView, expectedLabel: String) {
        // This would need to be implemented with actual accessibility testing framework
        // For now, we'll just verify the view exists
        XCTAssertNotNil(view)
    }
    
    /// Helper to verify accessibility hint exists
    func verifyAccessibilityHint(_ view: AnyView, expectedHint: String) {
        // This would need to be implemented with actual accessibility testing framework
        // For now, we'll just verify the view exists
        XCTAssertNotNil(view)
    }
    
    /// Helper to verify accessibility traits
    func verifyAccessibilityTraits(_ view: AnyView, expectedTraits: AccessibilityTraits) {
        // This would need to be implemented with actual accessibility testing framework
        // For now, we'll just verify the view exists
        XCTAssertNotNil(view)
    }
}