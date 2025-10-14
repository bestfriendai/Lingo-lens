# Lingo Lens - Quick Fix Guide
**Priority-Ordered Action Items**

This document provides a quick reference for implementing the most critical fixes from the comprehensive code review. Start from the top and work your way down.

---

## 🔴 CRITICAL - Fix Today (1 hour total)

### 1. Add Camera Permission (5 minutes)
**File:** `Lingo lens/Lingo-lens-Info.plist`

Add this after line 8:
```xml
<key>NSCameraUsageDescription</key>
<string>Lingo Lens needs camera access to detect and translate objects in the real world using augmented reality.</string>
```

**Why:** App Store will reject without this. App will crash on camera access.

---

### 2. Fix ARCoordinator Memory Leak (30 minutes)
**File:** `Lingo lens/Lingo lens/TabViews/ARTranslationTab/Coordinators/ARCoordinator.swift`

**Line 18:** Change from:
```swift
var arViewModel: ARViewModel
```

To:
```swift
weak var arViewModel: ARViewModel?
```

**Then update all usages** to handle the optional:
```swift
guard let arViewModel = arViewModel else { return }
```

**Why:** Prevents memory accumulation during extended AR sessions.

---

### 3. Add Input Validation (30 minutes)
**File:** `Lingo lens/Lingo lens/TabViews/ChatTranslatorTab/ViewModels/ChatTranslatorViewModel.swift`

**In `translateText()` function, add after line 175:**
```swift
// Add length validation
guard trimmedText.count <= 5000 else {
    errorMessage = "Text is too long. Maximum 5000 characters."
    showError = true
    return
}

// Add rate limiting
if let lastTime = lastTranslationTime {
    let timeSinceLastTranslation = Date().timeIntervalSince(lastTime)
    if timeSinceLastTranslation < 0.5 {
        print("⚠️ Translation rate limit exceeded")
        return
    }
}
lastTranslationTime = Date()
```

**Add property:**
```swift
private var lastTranslationTime: Date?
```

**Why:** Prevents crashes from extremely long text and API abuse.

---

## 🟠 HIGH PRIORITY - Fix This Week (10 hours total)

### 4. Fix Core Data Force Cast (30 minutes)
**File:** `Lingo lens/Lingo lens/TabViews/SavedWordsTab/Views/SavedWords.swift`

**Line 214:** Change from:
```swift
let fetchRequest: NSFetchRequest<NSFetchRequestResult> = 
    SavedTranslation.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>
```

To:
```swift
guard let fetchRequest = SavedTranslation.fetchRequest() as? NSFetchRequest<NSFetchRequestResult> else {
    print("❌ Failed to create fetch request")
    await MainActor.run {
        isLoadingLanguages = false
        showLanguageLoadErrorAlert(message: "Unable to load language filters due to database error.")
    }
    return
}
```

---

### 5. Add Error Handling in Object Detection (1 hour)
**File:** `Lingo lens/Lingo lens/TabViews/ARTranslationTab/Services/ObjectDetectionManager.swift`

**Line 124-127:** Change from:
```swift
guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
    completion(nil)
    return
}
```

To:
```swift
guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
    print("❌ Failed to create CGImage from CIImage")
    DispatchQueue.main.async {
        ARErrorManager.shared.showError(
            message: "Image processing failed. Please try again.",
            retryAction: nil
        )
    }
    completion(nil)
    return
}
```

---

### 6. Create SecureLogger (2 hours)
**Create new file:** `Lingo lens/Lingo lens/Core/Utilities/SecureLogger.swift`

```swift
import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

struct SecureLogger {
    /// Logs a message with appropriate privacy controls
    /// - Parameters:
    ///   - message: The message to log (should NOT contain user data)
    ///   - level: The log level
    ///   - file: Source file (auto-populated)
    ///   - function: Source function (auto-populated)
    ///   - line: Source line (auto-populated)
    static func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            print("[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)")
        #else
            // In production, only log errors
            if level == .error {
                print("[\(level.rawValue)] \(message)")
            }
        #endif
    }
    
    /// Log with user data - ONLY use in DEBUG builds
    static func logDebugWithData(_ message: String, userData: String) {
        #if DEBUG
            print("[DEBUG] \(message): \(userData)")
        #else
            // Never log user data in production
            print("[DEBUG] \(message)")
        #endif
    }
}
```

**Then replace all print statements** containing user data:
```swift
// OLD:
print("🔄 Translating text: \"\(text)\"")

// NEW:
SecureLogger.log("Translating text", level: .info)
```

---

### 7. Add Accessibility Labels (3 hours)

**File:** `Lingo lens/Lingo lens/TabViews/ChatTranslatorTab/Views/MessageBubbleView.swift`

Add to all interactive elements:
```swift
Button(action: onSpeakOriginal) {
    Image(systemName: "speaker.wave.2.fill")
}
.accessibilityLabel("Play original text")
.accessibilityHint("Double tap to hear the original message")

Button(action: onSpeakTranslation) {
    Image(systemName: "speaker.wave.2.fill")
}
.accessibilityLabel("Play translation")
.accessibilityHint("Double tap to hear the translated message")

Button(action: onCopy) {
    Image(systemName: "doc.on.doc")
}
.accessibilityLabel("Copy translation")
.accessibilityHint("Double tap to copy the translated text")

Button(action: onSave) {
    Image(systemName: "bookmark")
}
.accessibilityLabel("Save translation")
.accessibilityHint("Double tap to save this translation for later")
```

**Repeat for all views** with buttons, images, and interactive elements.

---

### 8. Create AppConstants File (1 hour)
**Create new file:** `Lingo lens/Lingo lens/Core/Utilities/AppConstants.swift`

```swift
import Foundation
import CoreGraphics

struct AppConstants {
    struct AR {
        static let minimumDetectionSize: CGFloat = 10
        static let detectionInterval: TimeInterval = 0.5
        static let frameThrottleInterval: TimeInterval = 0.5
        static let confidenceThreshold: Float = 0.5
    }
    
    struct Translation {
        static let maxCacheSize = 50
        static let maxTextLength = 5000
        static let rateLimit: TimeInterval = 0.5
    }
    
    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let hapticFeedbackDelay: TimeInterval = 0.1
        static let messageMaxVisible = 100
    }
    
    struct Audio {
        static let speechRate: Float = 0.9
        static let pitchMultiplier: Float = 1.0
        static let volume: Float = 1.0
    }
    
    struct Performance {
        static let batchFetchSize = 20
        static let imageCacheSize = 10
    }
}
```

**Then replace all magic numbers** throughout the codebase with references to these constants.

---

### 9. Implement Basic Unit Tests (4 hours)
**Create new file:** `Lingo lens Tests/Unit Tests/ViewModels/ChatTranslatorViewModelTests.swift`

```swift
import XCTest
@testable import Lingo_lens

final class ChatTranslatorViewModelTests: XCTestCase {
    var sut: ChatTranslatorViewModel!
    
    override func setUp() {
        super.setUp()
        // Initialize with real dependencies for now
        // TODO: Add dependency injection and mocks
        sut = ChatTranslatorViewModel(
            translationService: TranslationService()
        )
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Translation Tests
    
    func testTranslateText_WithEmptyText_DoesNotTranslate() {
        // Given
        let text = "   "
        
        // When
        sut.translateText(text)
        
        // Then
        XCTAssertFalse(sut.isTranslating)
        XCTAssertNil(sut.pendingTranslation)
    }
    
    func testTranslateText_WhenAlreadyTranslating_IgnoresNewRequest() {
        // Given
        sut.isSessionReady = true
        sut.isTranslating = true
        
        // When
        sut.translateText("Hello")
        
        // Then
        XCTAssertNil(sut.pendingTranslation)
    }
    
    // MARK: - Message Management Tests
    
    func testClearMessages_RemovesAllMessages() {
        // Given
        sut.messages = [
            ChatMessage(
                originalText: "Hello",
                translatedText: "Hola",
                sourceLanguage: sut.sourceLanguage,
                targetLanguage: sut.targetLanguage
            )
        ]
        
        // When
        sut.clearMessages()
        
        // Then
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertTrue(sut.translationCache.isEmpty)
    }
    
    func testDeleteMessage_RemovesSpecificMessage() {
        // Given
        let message1 = ChatMessage(
            originalText: "Hello",
            translatedText: "Hola",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        let message2 = ChatMessage(
            originalText: "Goodbye",
            translatedText: "Adiós",
            sourceLanguage: sut.sourceLanguage,
            targetLanguage: sut.targetLanguage
        )
        sut.messages = [message1, message2]
        
        // When
        sut.deleteMessage(message1)
        
        // Then
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.id, message2.id)
    }
}
```

---

## 🟡 MEDIUM PRIORITY - Fix This Month

### 10. Add Core Data Encryption (2 hours)
**File:** `Lingo lens/Lingo lens/Core/Models/CoreData/PersistenceController.swift`

In the `init` method, after creating the container:
```swift
if !inMemory {
    let storeDescription = container.persistentStoreDescriptions.first!
    
    // Enable file protection
    storeDescription.setOption(
        FileProtectionType.complete as NSObject,
        forKey: NSPersistentStoreFileProtectionKey
    )
}
```

---

### 11. Implement Message Pagination (3 hours)
**File:** `Lingo lens/Lingo lens/TabViews/ChatTranslatorTab/ViewModels/ChatTranslatorViewModel.swift`

Add properties:
```swift
private let maxVisibleMessages = 100
private var archivedMessages: [ChatMessage] = []
```

Update `addMessage`:
```swift
private func addMessage(_ message: ChatMessage) {
    messages.append(message)
    
    // Archive old messages
    if messages.count > maxVisibleMessages {
        let toArchive = messages.removeFirst()
        archivedMessages.append(toArchive)
    }
}
```

---

## Testing Your Fixes

After implementing each fix:

1. **Build the project:** `Cmd + B`
2. **Run on simulator:** `Cmd + R`
3. **Test the specific feature** affected by your fix
4. **Check for crashes** in the console
5. **Run unit tests** (once implemented): `Cmd + U`

---

## Verification Checklist

- [ ] Camera permission added to Info.plist
- [ ] ARCoordinator uses weak reference
- [ ] Input validation added to translation
- [ ] Core Data force cast replaced with guard
- [ ] Error handling added to object detection
- [ ] SecureLogger created and implemented
- [ ] Accessibility labels added to all buttons
- [ ] AppConstants file created
- [ ] Basic unit tests created and passing
- [ ] All changes tested on device/simulator

---

**Estimated Total Time:** ~11 hours for critical and high priority fixes
**Recommended Schedule:** 2-3 hours per day over one week

