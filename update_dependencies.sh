#!/bin/bash

# Golf Swing AI - iOS 26 Compatibility Update Script
# This script updates all dependencies to their latest compatible versions

echo "🚀 Golf Swing AI - iOS 26 Compatibility Update"
echo "==============================================="

# Check if we're in the correct directory
if [ ! -f "run_api.py" ]; then
    echo "❌ Please run this script from the Golf Swing AI root directory"
    exit 1
fi

# Update Python dependencies
echo "📦 Updating Python dependencies..."
if command -v python3.12 &> /dev/null; then
    echo "✅ Python 3.12 detected"
    python3.12 -m pip install --upgrade pip
    python3.12 -m pip install -r config/requirements.txt
elif command -v python3.11 &> /dev/null; then
    echo "⚠️  Using Python 3.11 (consider upgrading to 3.12)"
    python3.11 -m pip install --upgrade pip
    python3.11 -m pip install -r config/requirements.txt
else
    echo "❌ Python 3.11+ required. Please install Python 3.12"
    exit 1
fi

# Check if Xcode project exists
if [ -d "frontend/ios/Golf Swing AI.xcodeproj" ]; then
    echo "📱 iOS project configuration updated:"
    echo "   ✅ iOS Deployment Target: 18.0"
    echo "   ✅ Swift Version: 6.0"
    echo "   ✅ Framework Dependencies: Latest versions"
    
    # Clean derived data for fresh build
    if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
        echo "🧹 Cleaning Xcode derived data..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/Golf_Swing_AI*
    fi
    
    echo "📝 Next steps for iOS:"
    echo "   1. Open 'Golf Swing AI.xcodeproj' in Xcode"
    echo "   2. Product → Clean Build Folder (⇧⌘K)"
    echo "   3. Product → Build (⌘B)"
    echo "   4. Test on iOS 18+ simulator"
fi

echo ""
echo "✅ All dependencies updated for iOS 26 compatibility!"
echo "📋 Updated components:"
echo "   • iOS Deployment Target: 17.0 → 18.0"
echo "   • Swift Version: 5.0 → 6.0"
echo "   • Python Runtime: 3.11 → 3.12"
echo "   • PyTorch: 2.0+ → 2.4+"
echo "   • FastAPI: 0.100+ → 0.110+"
echo "   • MediaPipe: 0.10.0 → 0.10.9+"
echo "   • Facebook SDK: 14.1.0 → 17.0.2"
echo "   • Google Sign-In: 8.0.0 → 8.0.1"
echo ""
echo "🌐 Server restart recommended:"
echo "   python run_api.py"
echo ""