# StoreKit Configuration Setup

## To Enable StoreKit Testing in Xcode:

1. **Open the project in Xcode**
2. **Select the scheme** (Golf Swing AI) next to the play button
3. **Click "Edit Scheme..."**
4. **Go to the "Run" section** in the left sidebar
5. **Click the "Options" tab**
6. **Under "StoreKit Configuration"**, select `Configuration.storekit`
7. **Click "Close"**

## Product IDs Configured:
- `com.golfswingai.premium_monthly` - $1.99/month
- `com.golfswingai.premium_annual` - $19.99/year

## If StoreKit Testing Doesn't Work:
The app will automatically offer a "Development Mode" option that bypasses StoreKit for testing premium features.

## Files Updated:
- `Configuration.storekit` - StoreKit test configuration
- `Services/PremiumManager.swift` - Real StoreKit integration
- `Views/PhysicsEngineView.swift` - Development mode fallback
- `Golf Swing AI.xcodeproj/project.pbxproj` - Added StoreKit file to resources
- `Golf Swing AI.xcodeproj/xcshareddata/xcschemes/Golf Swing AI.xcscheme` - Scheme with StoreKit config