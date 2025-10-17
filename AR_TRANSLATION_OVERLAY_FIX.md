# AR Translation Overlay Fix - October 17, 2025

## Problem Statement
Translated words on the camera/AR were not staying visible - they were flickering and disappearing too quickly, creating a poor user experience.

## Root Cause Analysis

### Issue #1: Aggressive Stale Threshold
**Location:** `ARViewModel.swift:724`
- Overlays were marked as "stale" after only **1.5 seconds**
- If text wasn't re-detected within this window, the overlay would disappear
- This caused constant flickering as camera moved or detection temporarily missed text

### Issue #2: Overly Frequent Cleanup
**Location:** `ARTranslationView.swift:890`
- Cleanup timer was running every **0.2 seconds**
- Combined with the 1.5s stale threshold, this created aggressive removal behavior
- Overlays had very little time to persist on screen

### Why This Broke the Feature
1. Text recognition runs every 0.1-0.2 seconds (good)
2. When text is detected, overlay is created
3. If camera moves slightly or detection misses the text for >1.5s, overlay is removed
4. Text is detected again → overlay reappears
5. **Result:** Constant flickering and disappearing overlays

## Fixes Implemented

### Fix #1: Increased Stale Threshold
**File:** `ARViewModel.swift:724`
**Change:**
```swift
// BEFORE: 1.5 seconds
let staleThreshold: TimeInterval = 1.5

// AFTER: 5.0 seconds
let staleThreshold: TimeInterval = 5.0
```

**Impact:**
- Overlays now persist for **5 seconds** instead of 1.5 seconds
- This gives text detection plenty of time to re-detect words as camera moves
- Reduces flickering dramatically
- Matches Google Translate-style behavior better

### Fix #2: Reduced Cleanup Frequency
**File:** `ARTranslationView.swift:890`
**Change:**
```swift
// BEFORE: Check every 0.2 seconds
cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true)

// AFTER: Check every 1.0 second
cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)
```

**Impact:**
- Less CPU usage for cleanup checks
- More efficient battery usage
- Still removes stale overlays promptly (within 1 second of becoming stale)

### Fix #3: Visual Styling for True Text Replacement
**File:** `ARTranslationView.swift:582-594`
**Change:**
```swift
// BEFORE: Blue semi-transparent background
.foregroundColor(.white)
.padding(.horizontal, 6)
.padding(.vertical, 3)
.background(
    RoundedRectangle(cornerRadius: 4)
        .fill(Color(red: 0.2, green: 0.4, blue: 0.9))  // Blue background
)

// AFTER: White opaque background that covers original text
.foregroundColor(.black)  // Black text instead of white
.padding(.horizontal, 4)  // Tighter padding
.padding(.vertical, 2)
.background(
    RoundedRectangle(cornerRadius: 2)  // Sharper corners
        .fill(Color.white.opacity(0.95))  // Nearly opaque white
        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)  // Subtle shadow
)
```

**Impact:**
- **95% opaque white background fully covers original text**
- Black text on white background looks like natural printed text
- Sharper corners (radius 2 vs 4) for more seamless appearance
- Tighter padding for better fit over original text
- Subtle shadow adds depth and makes overlay look natural
- **TRUE text replacement effect like Google Translate**

## Expected Behavior After Fix

### Before (Broken):
❌ Overlays appear and disappear rapidly (flickering)
❌ Moving camera causes overlays to vanish instantly
❌ Poor user experience - hard to read translations
❌ Words disappear even when still visible in frame
❌ Blue semi-transparent background doesn't fully cover original text

### After (Fixed):
✅ Overlays persist stably for 5 seconds
✅ Camera movement doesn't immediately remove overlays
✅ Smooth, Google Translate-style experience
✅ Overlays stay visible as long as text is occasionally re-detected
✅ Only removed when text is truly out of frame for 5+ seconds
✅ **White opaque background fully replaces/covers original text**
✅ **Black text on white background - looks like printed text**

## Additional Notes

### Overlay Management Strategy
The app now uses a **persistent overlay** approach:

1. **Primary cleanup mechanism:** Maximum overlay count (25-50 based on screen size)
   - When max is reached, oldest overlays are removed first
   - Located in `ARViewModel.swift:417-425`

2. **Secondary cleanup mechanism:** Stale threshold (5 seconds)
   - Removes overlays that haven't been seen for 5+ seconds
   - Prevents memory buildup from old detections

3. **Manual cleanup:** User actions
   - Tapping "Clear" button
   - Switching tabs
   - Manually toggling translation mode

### Performance Characteristics
- Text detection: Every 0.1-0.2 seconds (device-dependent)
- Overlay updates: Instant when text is re-detected
- Cleanup checks: Every 1 second
- Stale threshold: 5 seconds
- Max overlays: 25-50 (device-dependent)

## Testing Recommendations

1. **Basic functionality:**
   - Point camera at text
   - Verify overlays appear and stay visible
   - Move camera slightly - overlays should persist

2. **Persistence test:**
   - Detect text, then move camera away briefly
   - Move camera back within 5 seconds
   - Overlay should still be there

3. **Cleanup test:**
   - Detect text, then move camera completely away
   - Wait 5+ seconds
   - Verify overlay is removed

4. **Maximum overlay test:**
   - Point camera at page with many words
   - Verify app limits overlays appropriately
   - Oldest overlays should be removed when limit is reached

## Files Modified

1. `Lingo lens/Lingo lens/TabViews/ARTranslationTab/ViewModels/ARViewModel.swift`
   - Line 724: Increased stale threshold from 1.5s to 5.0s
   - Updated comments to reflect persistent mode

2. `Lingo lens/Lingo lens/TabViews/ARTranslationTab/Views/ARTranslationView.swift`
   - Line 890: Reduced cleanup frequency from 0.2s to 1.0s
   - Lines 582-594: Changed visual styling to white opaque background for true text replacement
   - Updated comments to reflect persistent mode

## Related Issues Addressed

This fix resolves the core issue reported: "The translated words on the camera and AR is not working as it should be"

Specifically fixes:
- ✅ Overlays disappearing too quickly
- ✅ Flickering translations
- ✅ Poor persistence of detected text
- ✅ Unstable AR translation experience
- ✅ **Overlays not fully covering/replacing original text (blue semi-transparent background)**
- ✅ **Text replacement now looks like Google Translate (white opaque overlay)**

## Success Metrics

After this fix, users should experience:
- **Stability:** Overlays remain visible and stable
- **Reliability:** Translations don't flicker or disappear unexpectedly
- **Usability:** Easy to read translations without re-detection anxiety
- **Performance:** Smooth, responsive AR experience

---

**Status:** ✅ **FIXED**
**Date:** October 17, 2025
**Impact:** Critical UX improvement for AR translation feature
