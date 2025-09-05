#!/bin/bash

echo "🔍 Golf Swing AI StoreKit Configuration Verification"
echo "=================================================="

# Check if Configuration.storekit exists
STOREKIT_FILE="frontend/ios/Golf Swing AI.xcodeproj/project.xcworkspace/Configuration.storekit"
if [ -f "$STOREKIT_FILE" ]; then
    echo "✅ Configuration.storekit file exists"
    
    # Check if it contains the correct product IDs
    if grep -q "nakulb.Golf-Swing-AI.premium_monthly" "$STOREKIT_FILE"; then
        echo "✅ Monthly subscription product ID found"
    else
        echo "❌ Monthly subscription product ID NOT found"
    fi
    
    if grep -q "nakulb.Golf-Swing-AI.premium_annual" "$STOREKIT_FILE"; then
        echo "✅ Annual subscription product ID found"
    else
        echo "❌ Annual subscription product ID NOT found"
    fi
else
    echo "❌ Configuration.storekit file NOT found"
fi

# Check Xcode scheme
SCHEME_FILE="frontend/ios/Golf Swing AI.xcodeproj/xcshareddata/xcschemes/Golf Swing AI.xcscheme"
if [ -f "$SCHEME_FILE" ]; then
    echo "✅ Xcode scheme file exists"
    
    if grep -q "StoreKitConfigurationFileReference" "$SCHEME_FILE"; then
        echo "✅ StoreKit configuration reference found in scheme"
    else
        echo "❌ StoreKit configuration reference NOT found in scheme"
    fi
else
    echo "❌ Xcode scheme file NOT found"
fi

# Check PremiumManager product IDs
PREMIUM_MANAGER="frontend/ios/Services/PremiumManager.swift"
if [ -f "$PREMIUM_MANAGER" ]; then
    echo "✅ PremiumManager.swift file exists"
    
    if grep -q "nakulb.Golf-Swing-AI.premium_monthly" "$PREMIUM_MANAGER"; then
        echo "✅ PremiumManager has correct monthly product ID"
    else
        echo "❌ PremiumManager has incorrect monthly product ID"
    fi
    
    if grep -q "nakulb.Golf-Swing-AI.premium_annual" "$PREMIUM_MANAGER"; then
        echo "✅ PremiumManager has correct annual product ID"
    else
        echo "❌ PremiumManager has incorrect annual product ID"
    fi
else
    echo "❌ PremiumManager.swift file NOT found"
fi

echo ""
echo "🚀 NEXT STEPS:"
echo "1. Open the project in Xcode"
echo "2. Clean build folder (Cmd+Shift+K)"
echo "3. Build and run the app"
echo "4. Test the premium purchase flow"
echo ""
echo "If issues persist, check the Xcode console for detailed StoreKit diagnostics."