#!/bin/bash

echo "🔧 Testing Golf Swing AI Build Fix"
echo "=================================="

# Check if the Swift concurrency fix was applied correctly
CAMERA_MANAGER="frontend/ios/Services/CameraManager.swift"
SWING_ANALYSIS="frontend/ios/Views/SwingAnalysisView.swift"

echo "🔍 Checking CameraManager concurrency fixes..."

if grep -q "let session = captureSession" "$CAMERA_MANAGER"; then
    echo "✅ Found session capture pattern in CameraManager"
else
    echo "❌ Missing session capture pattern in CameraManager"
fi

if grep -q "var isSessionRunning: Bool" "$CAMERA_MANAGER"; then
    echo "✅ Found isSessionRunning computed property"
else
    echo "❌ Missing isSessionRunning computed property"
fi

echo "🔍 Checking SwingAnalysisView fixes..."

if grep -q "cameraManager.isSessionRunning" "$SWING_ANALYSIS"; then
    echo "✅ Found usage of isSessionRunning property"
else
    echo "❌ Still using direct captureSession access"
fi

# Count remaining direct captureSession access
REMAINING_ISSUES=$(grep -c "cameraManager\.captureSession" "$SWING_ANALYSIS" 2>/dev/null || echo "0")
echo "📊 Remaining direct captureSession access: $REMAINING_ISSUES"

if [ "$REMAINING_ISSUES" = "0" ]; then
    echo "✅ All direct captureSession access has been replaced"
else
    echo "⚠️ Still some direct captureSession access remaining"
    echo "   Locations:"
    grep -n "cameraManager\.captureSession" "$SWING_ANALYSIS" 2>/dev/null || true
fi

echo ""
echo "🏗️ BUILD TEST RECOMMENDATIONS:"
echo "1. Clean build folder (Cmd+Shift+K) in Xcode"
echo "2. Try building the project again"
echo "3. The Swift 6 concurrency error should now be resolved"
echo ""
echo "📱 If build succeeds, test camera functionality:"
echo "1. Run the app in simulator or device"
echo "2. Tap 'Record Video' button"  
echo "3. Check if camera preview shows and '📹 ON' appears"
echo "4. If issues persist, use the 🔧 debug button in the camera view"