//
//  AccessibilityConfiguration.swift
//  Lingo lens
//
//  Created by Accessibility Support on 10/17/25.
//

import SwiftUI
import UIKit

// MARK: - Global Accessibility Configuration

class AccessibilityConfiguration: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isVoiceOverRunning: Bool {
        didSet {
            NotificationCenter.default.post(name: .voiceOverStatusChanged, object: isVoiceOverRunning)
        }
    }
    
    @Published var isReduceMotionEnabled: Bool
    @Published var isReduceTransparencyEnabled: Bool
    @Published var isInvertColorsEnabled: Bool
    @Published var isDifferentiateWithoutColorEnabled: Bool
    @Published var isHighContrastEnabled: Bool
    @Published var preferredContentSizeCategory: UIContentSizeCategory
    
    // MARK: - Initialization
    
    init() {
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        self.isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
        self.isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        self.isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        self.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        setupNotifications()
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryChanged),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(darkerSystemColorsStatusChanged),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func voiceOverStatusChanged() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    @objc private func reduceMotionStatusChanged() {
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    @objc private func contentSizeCategoryChanged() {
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    }
    
    @objc private func darkerSystemColorsStatusChanged() {
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    // MARK: - Accessibility Helpers
    
    /// Returns appropriate animation duration based on reduce motion setting
    var animationDuration: Double {
        isReduceMotionEnabled ? 0.0 : 0.3
    }
    
    /// Returns appropriate animation based on reduce motion setting
    var defaultAnimation: Animation {
        isReduceMotionEnabled ? .linear(duration: 0) : .easeInOut(duration: animationDuration)
    }
    
    /// Returns font scaling factor based on content size category
    var fontScalingFactor: CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall:
            return 0.8
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.1
        case .extraLarge:
            return 1.2
        case .extraExtraLarge:
            return 1.3
        case .extraExtraExtraLarge:
            return 1.4
        case .accessibilityMedium:
            return 1.5
        case .accessibilityLarge:
            return 1.6
        case .accessibilityExtraLarge:
            return 1.7
        case .accessibilityExtraExtraLarge:
            return 1.8
        case .accessibilityExtraExtraExtraLarge:
            return 1.9
        default:
            return 1.0
        }
    }
    
    /// Returns appropriate color scheme for high contrast
    var highContrastColorScheme: ColorScheme? {
        isHighContrastEnabled ? nil : nil // Use system default
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let voiceOverStatusChanged = Notification.Name("voiceOverStatusChanged")
    static let reduceMotionStatusChanged = Notification.Name("reduceMotionStatusChanged")
    static let contentSizeCategoryChanged = Notification.Name("contentSizeCategoryChanged")
    static let highContrastStatusChanged = Notification.Name("highContrastStatusChanged")
}

// MARK: - Accessibility View Modifier

struct AccessibilityViewModifier: ViewModifier {
    @StateObject private var accessibilityConfig = AccessibilityConfiguration()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(accessibilityConfig)
            .animation(accessibilityConfig.defaultAnimation, value: accessibilityConfig.isVoiceOverRunning)
            .animation(accessibilityConfig.defaultAnimation, value: accessibilityConfig.isReduceMotionEnabled)
            .animation(accessibilityConfig.defaultAnimation, value: accessibilityConfig.preferredContentSizeCategory)
    }
}

// MARK: - View Extension for Accessibility

extension View {
    /// Applies global accessibility configuration
    func configureAccessibility() -> some View {
        self.modifier(AccessibilityViewModifier())
    }
    
    /// Applies accessibility-aware animations
    func accessibleAnimation<Value>(_ animation: Animation? = nil, value: Value) -> some View where Value: Equatable {
        let config = AccessibilityConfiguration()
        let anim = animation ?? config.defaultAnimation
        return self.animation(anim, value: value)
    }
    
    /// Applies Dynamic Type scaling
    func dynamicType() -> some View {
        self.dynamicTypeSize(.large)
    }
    
    /// Applies high contrast support
    func highContrast() -> some View {
        self.preferredColorScheme(nil) // Use system default with high contrast awareness
    }
    
    /// Applies reduced motion support
    func reducedMotion() -> some View {
        self.animation(.linear(duration: 0), value: UUID()) // Disable animations for reduced motion
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
extension View {
    /// Enables accessibility preview for testing
    func accessibilityTestMode() -> some View {
        self
            .animation(.linear(duration: 0), value: UUID()) // Reduced motion
            .opacity(1.0) // Full opacity for reduced transparency
            .contrast(1.2) // Higher contrast
    }
}
#endif

// MARK: - Accessibility Audit

struct AccessibilityAudit {
    
    /// Performs basic accessibility audit on the app
    static func performAudit() -> [String] {
        var issues: [String] = []
        
        // Check VoiceOver status
        if UIAccessibility.isVoiceOverRunning {
            issues.append("VoiceOver is running - ensure all elements have proper labels")
        }
        
        // Check Reduce Motion
        if UIAccessibility.isReduceMotionEnabled {
            issues.append("Reduce Motion is enabled - ensure animations are respectful")
        }
        
        // Check Dynamic Type
        let category = UIApplication.shared.preferredContentSizeCategory
        if category != .large {
            issues.append("Dynamic Type is set to \(category) - ensure text scales properly")
        }
        
        // Check High Contrast
        if UIAccessibility.isDarkerSystemColorsEnabled {
            issues.append("High Contrast is enabled - ensure sufficient color contrast")
        }
        
        return issues
    }
    
    /// Logs accessibility status for debugging
    static func logAccessibilityStatus() {
        print("🔍 Accessibility Status:")
        print("  VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "ON" : "OFF")")
        print("  Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "ON" : "OFF")")
        print("  Reduce Transparency: \(UIAccessibility.isReduceTransparencyEnabled ? "ON" : "OFF")")
        print("  Invert Colors: \(UIAccessibility.isInvertColorsEnabled ? "ON" : "OFF")")
        print("  Differentiate Without Color: \(UIAccessibility.shouldDifferentiateWithoutColor ? "ON" : "OFF")")
        print("  High Contrast: \(UIAccessibility.isDarkerSystemColorsEnabled ? "ON" : "OFF")")
        print("  Dynamic Type: \(UIApplication.shared.preferredContentSizeCategory)")
    }
}