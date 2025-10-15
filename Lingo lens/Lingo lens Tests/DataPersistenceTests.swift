//
//  DataPersistenceTests.swift
//  Lingo lens Tests
//
//  Created by Code Improvement on 10/14/25.
//

import XCTest
@testable import Lingo_lens

final class DataPersistenceTests: XCTestCase {
    
    var sut: MockDataPersistence!
    
    override func setUp() {
        super.setUp()
        sut = MockDataPersistence()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Tests
    
    func testIsFirstLaunch_ReturnsTrue_WhenNeverLaunched() {
        // Then
        XCTAssertTrue(sut.isFirstLaunch(), "Should be first launch")
        XCTAssertEqual(sut.getLaunchCount(), 0, "Launch count should be 0")
    }
    
    func testTrackAppLaunch_IncrementsCount() {
        // When
        sut.trackAppLaunch()
        
        // Then
        XCTAssertEqual(sut.getLaunchCount(), 1, "Launch count should be 1")
        XCTAssertNotNil(sut.getInitialLaunchDate(), "Should save initial launch date")
    }
    
    func testTrackAppLaunch_MultipleTimes_IncrementsCount() {
        // When
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        
        // Then
        XCTAssertEqual(sut.getLaunchCount(), 3, "Launch count should be 3")
    }
    
    func testIsFirstLaunch_ReturnsFalse_AfterSecondLaunch() {
        // Given
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        
        // Then
        XCTAssertFalse(sut.isFirstLaunch(), "Should not be first launch")
    }
    
    // MARK: - Onboarding Tests
    
    func testDidFinishOnBoarding_ReturnsFalse_Initially() {
        // Then
        XCTAssertFalse(sut.didFinishOnBoarding(), "Onboarding should not be finished")
    }
    
    func testFinishOnBoarding_SetsFlag() {
        // When
        sut.finishOnBoarding()
        
        // Then
        XCTAssertTrue(sut.didFinishOnBoarding(), "Onboarding should be finished")
    }
    
    func testHasDismissedInstructions_ReturnsFalse_Initially() {
        // Then
        XCTAssertFalse(sut.hasDismissedInstructions(), "Instructions should not be dismissed")
    }
    
    func testDismissedInstructions_SetsFlag() {
        // When
        sut.dismissedInstructions()
        
        // Then
        XCTAssertTrue(sut.hasDismissedInstructions(), "Instructions should be dismissed")
    }
    
    // MARK: - Rating Prompt Tests
    
    func testShouldShowRatingPrompt_ReturnsFalse_OnFirstLaunch() {
        // Given
        sut.trackAppLaunch()
        
        // Then
        XCTAssertFalse(sut.shouldShowRatingPrompt(), "Should not show on first launch")
    }
    
    func testShouldShowRatingPrompt_ReturnsTrue_OnThirdLaunch() {
        // Given
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        
        // Then
        XCTAssertTrue(sut.shouldShowRatingPrompt(), "Should show on third launch")
    }
    
    func testShouldShowRatingPrompt_ReturnsFalse_AfterMarkedAsShown() {
        // Given
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.markRatingPromptAsShown()
        
        // Then
        XCTAssertFalse(sut.shouldShowRatingPrompt(), "Should not show after marked as shown")
    }
    
    func testShouldShowRatingPrompt_ReturnsFalse_WhenNeverAskSet() {
        // Given
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.trackAppLaunch()
        sut.setNeverAskForRating()
        
        // Then
        XCTAssertFalse(sut.shouldShowRatingPrompt(), "Should not show when never ask is set")
    }
    
    // MARK: - Language Settings Tests
    
    func testGetSelectedLanguageCode_ReturnsNil_Initially() {
        // Then
        XCTAssertNil(sut.getSelectedLanguageCode(), "Should be nil initially")
    }
    
    func testSaveAndGetSelectedLanguageCode_StoresValue() {
        // When
        sut.saveSelectedLanguageCode("es-ES")
        
        // Then
        XCTAssertEqual(sut.getSelectedLanguageCode(), "es-ES", "Should return saved language code")
    }
    
    // MARK: - Appearance Settings Tests
    
    func testGetColorSchemeOption_ReturnsZero_Initially() {
        // Then
        XCTAssertEqual(sut.getColorSchemeOption(), 0, "Should be 0 initially")
    }
    
    func testSaveAndGetColorSchemeOption_StoresValue() {
        // When
        sut.saveColorSchemeOption(2)
        
        // Then
        XCTAssertEqual(sut.getColorSchemeOption(), 2, "Should return saved option")
    }
    
    // MARK: - UI Preferences Tests
    
    func testGetNeverShowLabelRemovalWarning_ReturnsFalse_Initially() {
        // Then
        XCTAssertFalse(sut.getNeverShowLabelRemovalWarning(), "Should be false initially")
    }
    
    func testSaveAndGetNeverShowLabelRemovalWarning_StoresValue() {
        // When
        sut.saveNeverShowLabelRemovalWarning(true)
        
        // Then
        XCTAssertTrue(sut.getNeverShowLabelRemovalWarning(), "Should return saved value")
    }
    
    func testGetAnnotationScale_ReturnsDefault_Initially() {
        // Then
        XCTAssertEqual(sut.getAnnotationScale(), 1.0, accuracy: 0.01, "Should be 1.0 initially")
    }
    
    func testSaveAndGetAnnotationScale_StoresValue() {
        // When
        sut.saveAnnotationScale(1.5)
        
        // Then
        XCTAssertEqual(sut.getAnnotationScale(), 1.5, accuracy: 0.01, "Should return saved scale")
    }
}
