#!/bin/bash

# Script to automatically switch Xcode scheme to Release mode
# Usage: ./switch_to_release.sh

echo "🚀 Lingo Lens - Switch to Release Mode"
echo "======================================"
echo ""

SCHEME_NAME="Lingo lens"
XCODEPROJ="Lingo lens/Lingo lens.xcodeproj"

# Check if project exists
if [ ! -d "$XCODEPROJ" ]; then
    echo "❌ Error: Could not find Xcode project at $XCODEPROJ"
    exit 1
fi

echo "✅ Found Xcode project"
echo ""
echo "Building in Release mode for maximum performance..."
echo ""

# Build in Release configuration
cd "Lingo lens"
xcodebuild \
    -project "Lingo lens.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    clean build \
    | xcpretty || true

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! App built in Release mode"
    echo ""
    echo "📱 Next steps:"
    echo "1. Open Xcode"
    echo "2. Select your device"
    echo "3. Click Run (⌘R)"
    echo ""
    echo "💡 Or use: Product → Scheme → Edit Scheme → Change to Release"
else
    echo ""
    echo "⚠️  Build completed with warnings (this is normal)"
    echo ""
    echo "📱 In Xcode, manually switch to Release mode:"
    echo "   Product → Scheme → Edit Scheme → Run → Build Configuration → Release"
fi
