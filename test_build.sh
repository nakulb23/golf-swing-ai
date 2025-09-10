#!/bin/bash

echo "🏌️ Testing Golf Swing AI Build..."
echo "================================"

cd "/Users/nakulbhatnagar/Desktop/Golf Swing AI/frontend/ios"

# Test Swift compilation
echo "📱 Testing Swift compilation..."
swift build --package-path . 2>&1 | head -20

# Test with xcodebuild
echo "🔨 Testing with xcodebuild..."
xcodebuild -project "Golf Swing AI.xcodeproj" \
           -scheme "Golf Swing AI" \
           -destination "platform=iOS Simulator,name=iPhone 15" \
           -quiet \
           clean build 2>&1 | grep -E "(error|warning|SUCCESS|FAILED)" | head -30

echo "✅ Build test complete!"