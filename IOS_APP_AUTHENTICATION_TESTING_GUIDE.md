# Golf Swing AI - iOS App Authentication Testing Guide

## Overview
This guide helps you test and verify that your iOS app correctly integrates with the Golf Swing AI authentication server. The server is now running with a trusted Let's Encrypt SSL certificate and is ready for production use.

## Server Information
- **Server URL:** `https://golfai.duckdns.org:8443`
- **SSL Certificate:** Let's Encrypt (trusted by browsers)
- **Status:** ✅ Operational

## Authentication Endpoints

### 1. Google Sign-In
**Endpoint:** `POST /auth/signin/google`

**Your App Should Send:**
```json
{
  "google_token": "eyJhbGciOiJSUzI1NiIs...", 
  "user_info": {
    "email": "user@example.com",
    "name": "User Name",
    "given_name": "User",
    "family_name": "Name",
    "picture": "https://profile-photo-url"
  }
}
```

**Server Returns (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 2592000,
  "is_new_user": true,
  "user_profile": {
    "id": "user-uuid",
    "email": "user@example.com", 
    "username": "generated_username",
    "full_name": "User Name",
    "handicap": null,
    "skill_level": null,
    "preferred_hand": null,
    "profile_photo_url": "https://profile-photo-url",
    "created_at": "2025-01-08T12:00:00",
    "last_login": null,
    "is_verified": true,
    "preferences": {},
    "stats": {}
  }
}
```

### 2. Regular Registration
**Endpoint:** `POST /auth/register`

**Your App Should Send:**
```json
{
  "email": "user@example.com",
  "username": "chosen_username", 
  "password": "secure_password",
  "full_name": "User Full Name",
  "device_info": {
    "device_type": "iOS",
    "device_model": "iPhone 15",
    "os_version": "17.0",
    "app_version": "1.0.0"
  }
}
```

### 3. Login
**Endpoint:** `POST /auth/login`

**Your App Should Send:**
```json
{
  "username": "username_or_email",
  "password": "user_password",
  "device_info": {
    "device_type": "iOS",
    "device_model": "iPhone 15", 
    "os_version": "17.0",
    "app_version": "1.0.0"
  }
}
```

## Testing Checklist

### ✅ Pre-Flight Checks
1. **Server URL Updated:** App uses `https://golfai.duckdns.org:8443`
2. **SSL Certificate:** App accepts the Let's Encrypt certificate (no warnings)
3. **Content-Type:** App sends `Content-Type: application/json` header

### ✅ Google Sign-In Testing

#### Test Case 1: First-Time User
1. **Action:** Sign in with Google for the first time
2. **Expected Response:** `200 OK` with `is_new_user: true`
3. **App Should:**
   - Parse JSON response successfully
   - Extract `access_token` and `refresh_token` 
   - Store tokens securely in Keychain
   - Extract user profile data
   - Navigate to main app interface

#### Test Case 2: Returning User
1. **Action:** Sign in with Google (user exists)
2. **Expected Response:** `200 OK` with `is_new_user: false`
3. **App Should:**
   - Parse JSON response successfully
   - Update stored tokens
   - Update user profile if changed
   - Navigate to main app interface

#### Test Case 3: Error Handling
1. **Action:** Sign in with invalid/expired Google token
2. **Expected Response:** `500 Internal Server Error`
3. **App Should:**
   - Handle error gracefully
   - Show appropriate error message to user
   - Not crash or hang

### ✅ JSON Parsing Verification

**Critical Fields to Check:**
```swift
// Your iOS code should access these fields:
let accessToken = response["access_token"] as? String
let refreshToken = response["refresh_token"] as? String
let tokenType = response["token_type"] as? String  // "Bearer"
let expiresIn = response["expires_in"] as? Int     // 2592000 (30 days)
let isNewUser = response["is_new_user"] as? Bool
let userProfile = response["user_profile"] as? [String: Any]

// User profile fields:
let userId = userProfile["id"] as? String
let email = userProfile["email"] as? String
let username = userProfile["username"] as? String
let fullName = userProfile["full_name"] as? String
let profilePhotoUrl = userProfile["profile_photo_url"] as? String
```

### ✅ Token Management

#### Access Token
- **Purpose:** Authenticate API requests
- **Expiration:** 30 days
- **Usage:** Include in Authorization header: `Bearer {access_token}`

#### Refresh Token  
- **Purpose:** Get new access token when expired
- **Expiration:** 90 days
- **Endpoint:** `POST /auth/refresh`

### ✅ Persistent Login Testing

1. **Fresh Install:**
   - User signs in with Google
   - App stores tokens securely
   - App closes

2. **App Reopens:**
   - App checks for stored tokens
   - If tokens exist and valid, user stays logged in
   - If tokens expired, use refresh token
   - If refresh token expired, require re-login

### ✅ Profile API Testing

Once authenticated, test these endpoints:

1. **Get Profile:** `GET /auth/profile`
   - Header: `Authorization: Bearer {access_token}`

2. **Update Profile:** `PUT /auth/profile`
   - Update handicap, skill level, etc.

3. **Upload Profile Photo:** `POST /auth/profile/photo`
   - Upload user's profile picture

### ✅ Error Scenarios to Test

1. **Network Issues:**
   - No internet connection
   - Server temporarily down
   - Request timeout

2. **Authentication Failures:**
   - Expired tokens
   - Invalid tokens
   - Malformed requests

3. **Server Errors:**
   - 500 Internal Server Error
   - 422 Validation Error
   - 401 Unauthorized

## Common Issues & Solutions

### Issue: "Data couldn't be read because it is missing"
**Cause:** JSON parsing error in iOS app
**Solution:** 
```swift
// Ensure proper JSON parsing:
if let data = data {
    do {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Access fields using exact names from server response
    } catch {
        print("JSON parsing error: \(error)")
    }
}
```

### Issue: SSL Certificate Warnings
**Cause:** App not using HTTPS or certificate validation issues
**Solution:** Ensure app uses `https://golfai.duckdns.org:8443`

### Issue: 401/422 Errors
**Cause:** Missing required fields or wrong data format
**Solution:** Check server logs and verify request format matches examples above

## Server Logs
Monitor server behavior by checking logs. Successful requests show:
```
INFO: 24.130.129.186:64190 - "POST /auth/signin/google HTTP/1.1" 200 OK
```

## Support
If you encounter issues:
1. Check this guide first
2. Verify your request format matches the examples
3. Check server logs for error details
4. Ensure you're using the correct server URL and HTTPS

## Final Notes
- The server is production-ready with trusted SSL certificate
- All authentication endpoints are functional
- Google OAuth is configured for your Client ID: `565652533895-84ia5eudkma9ch65ciu5blm9pd8jtk8t.apps.googleusercontent.com`
- User data is stored securely with password hashing and encrypted sessions

---
**Last Updated:** September 8, 2025
**Server Status:** ✅ Operational at `https://golfai.duckdns.org:8443`