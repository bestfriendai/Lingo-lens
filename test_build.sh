#!/bin/bash

cd "/Users/iamabillionaire/Downloads/Lingo-lens-main/Lingo lens"

echo "Building Lingo Lens..."
echo "========================"

# Build with timeout and capture output
timeout 120 xcodebuild -scheme "Lingo lens" -destination "platform=iOS Simulator,name=iPhone 15" clean build > build_output.txt 2>&1

# Extract just the errors
echo "BUILD ERRORS:"
echo "============="
grep -A 5 -B 5 "error:" build_output.txt | head -50

echo ""
echo "BUILD WARNINGS:"
echo "==============="
grep -A 2 -B 2 "warning:" build_output.txt | head -30

echo ""
echo "BUILD RESULT:"
echo "============"
grep -E "(BUILD SUCCEEDED|BUILD FAILED)" build_output.txt