# Facebook Login Setup Guide

## 1. Add Facebook SDK to Xcode Project

### Step 1: Add Package Dependency
1. Open your Xcode project
2. Go to **File → Add Package Dependencies**
3. Enter this URL: `https://github.com/facebook/facebook-ios-sdk`
4. Click **Add Package**
5. Select these libraries:
   - **FacebookCore**
   - **FacebookLogin** 
   - **FacebookBasics**
6. Click **Add Package**

### Step 2: Configure Info.plist
Add the following to your `Golf-Swing-AI-Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string></string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fb[YOUR_FACEBOOK_APP_ID]</string>
        </array>
    </dict>
</array>
<key>FacebookAppID</key>
<string>[YOUR_FACEBOOK_APP_ID]</string>
<key>FacebookClientToken</key>
<string>[YOUR_FACEBOOK_CLIENT_TOKEN]</string>
<key>FacebookDisplayName</key>
<string>Golf Swing AI</string>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>fbapi</string>
    <string>fb-messenger-share-api</string>
</array>
```

## 2. Create Facebook App

### Step 1: Facebook Developer Account
1. Go to [Facebook Developers](https://developers.facebook.com)
2. Create a developer account if you don't have one
3. Click **Create App**

### Step 2: Configure App
1. Choose **Consumer** app type
2. Enter app details:
   - **App Name**: Golf Swing AI
   - **Contact Email**: your email
3. Click **Create App**

### Step 3: Add iOS Platform
1. In your app dashboard, click **Add Platform**
2. Choose **iOS**
3. Enter:
   - **Bundle ID**: `com.yourcompany.golf-swing-ai` (match your Xcode bundle ID)
   - **App Store ID**: (leave blank for now)
4. Click **Save Changes**

### Step 4: Get App Credentials
1. Go to **App Settings → Basic**
2. Copy your **App ID** and **Client Token**
3. Replace `[YOUR_FACEBOOK_APP_ID]` and `[YOUR_FACEBOOK_CLIENT_TOKEN]` in Info.plist

## 3. Configure App Review (For Production)

### Required Steps:
1. **App Review**: Submit for `public_profile` and `email` permissions
2. **Privacy Policy**: Add privacy policy URL: `https://yourdomain.com/privacy-policy.html`
3. **Terms of Service**: Add terms of service URL
4. **App Icon**: Upload 1024x1024 app icon
5. **Data Deletion**: Add data deletion URL: `https://yourdomain.com/data-deletion.html`

### Data Deletion Callback URL:
Facebook requires a data deletion callback URL. Use:
```
https://yourdomain.com/data-deletion.html
```

### Privacy Policy URL:
```
https://yourdomain.com/privacy-policy.html
```

### For Development:
- Add test users in **Roles → Test Users**
- Test users can login without app review

### App Settings Required:
1. **App Domains**: Add your domain
2. **Privacy Policy URL**: Link to your privacy policy
3. **User Data Deletion**: Link to data deletion page
4. **Data Use Checkup**: Complete Facebook's data use review

## 4. Test the Integration

1. Build and run the app
2. Try Facebook login
3. Check console logs for debugging
4. Verify user profile data is retrieved correctly

## 5. Troubleshooting

### Common Issues:
- **"App Not Setup"**: Check App ID in Info.plist
- **"Invalid URL Scheme"**: Verify `fb[APP_ID]` format
- **"Login Cancelled"**: Normal user behavior
- **"Graph API Error"**: Check app permissions

### Debug Steps:
1. Check Xcode console for detailed error messages
2. Verify all SDK libraries are linked
3. Ensure Info.plist values match Facebook app settings
4. Test with Facebook app installed vs. web login

## 6. Security Notes

- **Never commit** App ID/Client Token to public repositories
- Use **environment variables** or **secure configuration** for production
- Implement **proper error handling** for all login scenarios
- Follow **Facebook Platform Policies**

---

**Status**: ✅ Code implementation complete, SDK integration required