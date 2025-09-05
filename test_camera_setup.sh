#!/bin/bash

echo "🎥 Golf Swing AI Camera Setup Verification"
echo "==========================================="

# Check if Info.plist has camera permissions
INFO_PLIST="frontend/ios/Golf-Swing-AI-Info.plist"
if [ -f "$INFO_PLIST" ]; then
    echo "✅ Info.plist file exists"
    
    if grep -q "NSCameraUsageDescription" "$INFO_PLIST"; then
        echo "✅ Camera usage description found"
        CAMERA_DESC=$(grep -A1 "NSCameraUsageDescription" "$INFO_PLIST" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo "   Description: $CAMERA_DESC"
    else
        echo "❌ Camera usage description NOT found"
    fi
    
    if grep -q "NSMicrophoneUsageDescription" "$INFO_PLIST"; then
        echo "✅ Microphone usage description found"
        MIC_DESC=$(grep -A1 "NSMicrophoneUsageDescription" "$INFO_PLIST" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo "   Description: $MIC_DESC"
    else
        echo "❌ Microphone usage description NOT found"
    fi
else
    echo "❌ Info.plist file NOT found"
fi

# Check CameraManager implementation
CAMERA_MANAGER="frontend/ios/Services/CameraManager.swift"
if [ -f "$CAMERA_MANAGER" ]; then
    echo "✅ CameraManager.swift exists"
    
    if grep -q "checkPermission" "$CAMERA_MANAGER"; then
        echo "✅ Permission checking method found"
    else
        echo "❌ Permission checking method NOT found"
    fi
    
    if grep -q "startSession" "$CAMERA_MANAGER"; then
        echo "✅ Session start method found"
    else
        echo "❌ Session start method NOT found"
    fi
    
    if grep -q "setupSession" "$CAMERA_MANAGER"; then
        echo "✅ Session setup method found"
    else
        echo "❌ Session setup method NOT found"
    fi
else
    echo "❌ CameraManager.swift NOT found"
fi

# Check SimpleCameraView implementation
SWING_ANALYSIS_VIEW="frontend/ios/Views/SwingAnalysisView.swift"
if [ -f "$SWING_ANALYSIS_VIEW" ]; then
    echo "✅ SwingAnalysisView.swift exists"
    
    if grep -q "SimpleCameraView" "$SWING_ANALYSIS_VIEW"; then
        echo "✅ SimpleCameraView found"
    else
        echo "❌ SimpleCameraView NOT found"
    fi
    
    if grep -q "CameraPreviewView" "$SWING_ANALYSIS_VIEW"; then
        echo "✅ CameraPreviewView found"
    else
        echo "❌ CameraPreviewView NOT found"
    fi
else
    echo "❌ SwingAnalysisView.swift NOT found"
fi

echo ""
echo "🚀 TESTING STEPS:"
echo "1. Build and run the app in Xcode"
echo "2. Tap on 'Record Video' button"
echo "3. When prompted, allow camera access"
echo "4. Check if camera preview appears (should see live camera feed)"
echo "5. Look for debug info at the top: '📹 ON' means camera is working"
echo "6. If camera shows '📹 OFF', tap the 🔧 debug button to restart"
echo ""
echo "📋 TROUBLESHOOTING:"
echo "- If no permission prompt appears, check iOS Settings > Privacy & Security > Camera"
echo "- Reset iOS Simulator: Device > Erase All Content and Settings"
echo "- Check Xcode console for detailed camera setup logs"
echo "- Ensure you're testing on a device or simulator with camera support"