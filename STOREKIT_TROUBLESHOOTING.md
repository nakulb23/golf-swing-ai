# StoreKit Configuration Troubleshooting Guide

## Current Configuration Status ✅

The Golf Swing AI project has been properly configured with StoreKit testing:

- **StoreKit Configuration File**: `Configuration.storekit` ✅
- **Scheme Configuration**: Properly linked in `Golf Swing AI.xcscheme` ✅
- **Product IDs Match**: Configuration.storekit matches PremiumManager.swift ✅

## Available Products

| Product ID | Type | Price | Period |
|------------|------|-------|--------|
| `com.golfswingai.premium_monthly` | Subscription | $1.99 | 1 Month |
| `com.golfswingai.premium_annual` | Subscription | $21.99 | 1 Year |

## If StoreKit Still Shows "Store Currently Unavailable"

### 1. Verify Xcode Scheme (Most Common Issue)
```
1. In Xcode menu: Product → Scheme → Edit Scheme...
2. Select "Run" from left sidebar
3. Click "Options" tab
4. Under "StoreKit Configuration":
   - Make sure it's set to "Configuration.storekit"
   - Ensure checkbox is checked ✅
5. Click "Close"
6. Clean build (Cmd+Shift+K)
7. Build and run
```

### 2. Check Simulator vs Device
- **Simulator**: Uses StoreKit Testing (Configuration.storekit)
- **Device**: Requires App Store Connect Sandbox or TestFlight

### 3. For Device Testing
```
1. Create sandbox tester account in App Store Connect
2. Sign out of App Store on your device
3. When purchasing, sign in with sandbox account
4. Products must be configured in App Store Connect
```

### 4. Debug Commands
Use the "Test StoreKit" button in Settings → Developer Options to run diagnostics.

### 5. Alternative Solution
If StoreKit continues to fail, the app includes a DEBUG-only development mode for testing premium features during development.

## Troubleshooting Commands

In the app console, look for these messages when testing:

### Success ✅
```
✅ Successfully loaded 2 products:
📦 com.golfswingai.premium_monthly
   Name: Golf Swing AI Premium - Monthly
   Price: $1.99
   Type: AutoRenewableSubscription
```

### Configuration Issue ❌
```
⚠️ No products found!
⚠️ Product IDs requested: ["com.golfswingai.premium_monthly", "com.golfswingai.premium_annual"]
```

**Solution**: Check Xcode scheme StoreKit configuration

### Network/System Issue ❌
```
❌ Network error: [underlying error details]
❌ System error: [underlying error details]
```

**Solution**: Check internet connection, restart Xcode/Simulator

## Manual Testing Steps

1. **Reset Premium Access**: Settings → Developer Options → "Reset Premium"
2. **Test StoreKit**: Settings → Developer Options → "Test StoreKit" 
3. **Try Purchase**: Go to Physics Engine → Tap "Start Premium"
4. **Check Console**: Look for StoreKit debug messages

## Development vs Production

- **DEBUG builds**: Can use development mode for testing
- **RELEASE builds**: Must use real App Store purchases
- **TestFlight**: Uses production App Store Connect configuration

## Contact Support

If StoreKit still doesn't work after following this guide:
1. Check Xcode version compatibility
2. Verify iOS deployment target
3. Clean derived data: ~/Library/Developer/Xcode/DerivedData
4. Restart Xcode and rebuild project