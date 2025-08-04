# API Connection Configuration

## Current Configuration

**API Base URL**: `https://golfai.duckdns.org:8443`

## Changes Made

### 1. Updated Constants.swift
- Changed base URL from local development server to production server
- Updated to `https://golfai.duckdns.org:8443` (secure HTTPS connection)

### 2. Network Security Configuration
- Configured App Transport Security in `Golf-Swing-AI-Info.plist` for HTTPS
- Disabled forward secrecy requirement for compatibility
- Allows secure HTTPS connections to `golfai.duckdns.org`

### 3. Connection Testing
- Added automatic connection test on app launch
- Visual connection status indicator in HomeView
- Manual retry by tapping the connection status
- Enhanced error logging for troubleshooting

### 4. API Endpoints Configured

All endpoints use the new base URL:
- **Health Check**: `https://golfai.duckdns.org:8443/health`
- **Swing Analysis**: `https://golfai.duckdns.org:8443/predict`
- **Chat**: `https://golfai.duckdns.org:8443/chat`
- **Ball Tracking**: `https://golfai.duckdns.org:8443/track-ball`

## Testing the Connection

### 1. Visual Indicator
- Green dot = Connected to API server
- Red dot = Connection failed
- Located next to "Golf Swing AI" title in HomeView

### 2. Manual Testing
- Tap the connection status indicator to retry connection
- Check Xcode console for detailed connection logs

### 3. Console Logs
Look for these messages in Xcode console:
```
🌐 APIService initialized
🌐 API Base URL: https://golfai.duckdns.org:8443
✅ API Connection successful: [status]
```

Or if failed:
```
❌ API Connection failed: [error details]
🔍 Attempting to connect to: https://golfai.duckdns.org:8443
```

## Testing Swing Analysis

1. **Navigate to Swing Analysis tab**
2. **Record or upload a video**
3. **Tap "Analyze Swing"**
4. **The app will POST to**: `https://golfai.duckdns.org:8443/predict`

## Troubleshooting

### Connection Issues
1. **Check server status**: Ensure the API server is running at `golfai.duckdns.org:8443`
2. **Network connectivity**: Verify device can reach the server
3. **SSL Configuration**: App configured with ATS exceptions for HTTPS compatibility
4. **Firewall**: Check if port 8443 is accessible

### Expected API Response Format
The API should return responses matching these models:
- `HealthResponse` for `/health`
- `SwingAnalysisResponse` for `/predict`
- `ChatResponse` for `/chat`

## Files Modified
- `Utilities/Constants.swift` - Updated base URL
- `Golf-Swing-AI-Info.plist` - Configured ATS for HTTPS with compatibility settings
- `Services/API Service.swift` - Enhanced connection testing
- `Views/HomeView.swift` - Added connection status indicator

## Security Note
The app uses secure HTTPS connection to your API server at `https://golfai.duckdns.org:8443`. App Transport Security has been configured with compatibility settings (disabled forward secrecy requirement) to ensure reliable connection while maintaining encryption.