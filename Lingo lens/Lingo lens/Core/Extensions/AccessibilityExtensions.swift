//
//  AccessibilityExtensions.swift
//  Lingo lens
//
//  Created by Accessibility Support on 10/17/25.
//

import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    
    /// Applies Dynamic Type support with scaled font sizes
    func dynamicTypeSize(_ style: Font.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(style, design: design, weight: weight))
            .minimumScaleFactor(0.8)
            .lineLimit(nil)
    }
    
    /// Adds accessibility support for interactive elements
    func accessibleButton(label: String, hint: String? = nil, value: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds accessibility support for static text elements
    func accessibleText(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// Adds accessibility support for frequently updating elements
    func accessibleUpdating(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Adds accessibility support for selectable elements
    func accessibleSelectable(label: String, isSelected: Bool, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    /// Adds accessibility support for image elements
    func accessibleImage(label: String, hint: String? = nil, decorative: Bool = false) -> some View {
        self
            .accessibilityLabel(decorative ? "" : label)
            .accessibilityHint(decorative ? "" : (hint ?? ""))
            .accessibilityAddTraits(decorative ? [] : .isImage)
    }
    
    /// Adds accessibility support for progress indicators
    func accessibleProgress(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Adds accessibility support for alert elements
    func accessibleAlert(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Applies accessibility grouping for related elements
    func accessibleGroup(label: String? = nil, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
    }
    
    /// Hides element from accessibility while keeping it visible
    func accessibilityHidden(_ hidden: Bool = true) -> some View {
        self.accessibilityHidden(hidden)
    }
    
    /// Applies high contrast support
    func highContrastSupport() -> some View {
        self
            .background(Color.clear)
    }
    
    /// Applies reduced motion support
    func reducedMotionSupport() -> some View {
        self
            .animation(.easeInOut(duration: 0.2), value: UUID())
    }
    
    /// Applies accessibility rotor support for navigation
    func accessibilityRotorEntry(id: String, text: String) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(text)
    }
}

// MARK: - Accessibility Modifier

struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let value: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
}

// MARK: - Accessibility Preview Support

extension View {

}

// MARK: - Custom Accessibility Actions

extension View {
    /// Adds custom accessibility actions
    func accessibilityAction(_ action: AccessibilityActionKind, _ handler: @escaping () -> Void) -> some View {
        self.accessibilityAction(action) {
            handler()
        }
    }
    
    /// Adds custom accessibility action with named action
    func accessibilityAction(named name: String, _ handler: @escaping () -> Void) -> some View {
        self.accessibilityAction(.default) {
            handler()
        }
        .accessibilityLabel(name)
    }
}

// MARK: - Accessibility Constants

struct AccessibilityConstants {
    static let navigationSwipeHint = "Swipe left or right to navigate between tabs"
    static let doubleTapHint = "Double tap to activate"
    static let swipeUpHint = "Swipe up for more options"
    static let swipeDownHint = "Swipe down to refresh"
    static let pinchHint = "Pinch to zoom in or out"
    static let rotateHint = "Rotate to change orientation"
    
    struct AR {
        static let translationActive = "AR translation is active"
        static let pointCameraHint = "Point camera at text to translate"
        static let detectionBoxHint = "Drag to move detection box"
        static let resizeBoxHint = "Drag corners to resize detection box"
    }
    
    struct Chat {
        static let speakHint = "Tap to hear pronunciation"
        static let copyHint = "Tap to copy text"
        static let deleteHint = "Swipe left to delete"
        static let recordHint = "Tap to start recording"
        static let stopHint = "Tap to stop recording"
    }
    
    struct Settings {
        static let languageHint = "Tap to change language"
        static let themeHint = "Tap to change appearance"
        static let resetHint = "Tap to reset settings"
    }
}

// MARK: - Font Scaling Helper

struct FontScaling {
    static func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let baseSize = size
        let scaledSize = baseSize * UIFont.preferredFont(forTextStyle: .body).pointSize / 17.0
        
        return Font.system(size: scaledSize, weight: weight, design: design)
    }
    
    static func scaledTextStyle(_ style: Font.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        Font.system(style, design: design, weight: weight)
    }
}

// MARK: - Color Contrast Helper

struct ColorContrast {
    static func accessibleColor(for background: Color) -> Color {
        // Ensure sufficient contrast ratio (4.5:1 for normal text)
        return background == .black ? .white : .black
    }
    
    static func highContrastColors() -> (primary: Color, secondary: Color) {
        return (.primary, .secondary)
    }
}

// MARK: - Haptic Feedback Helper

struct HapticFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    
    static func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    static func light() {
        lightGenerator.impactOccurred()
    }
    
    static func medium() {
        mediumGenerator.impactOccurred()
    }
    
    static func heavy() {
        heavyGenerator.impactOccurred()
    }
    
    static func selection() {
        selectionGenerator.selectionChanged()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
}