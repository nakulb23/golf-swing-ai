# Complete Authentication Implementation Guide for GolfSwingAI

## Overview

GolfSwingAI's authentication system provides multiple login methods for users:
- **Email/Password Registration** - Traditional account creation
- **Google Sign-In** - OAuth authentication via Google
- **Apple Sign-In** - OAuth authentication via Apple
- **Persistent Login** - 30-day token system keeps users logged in

## Server Setup

### Base URL
- **Production**: `https://golfai.duckdns.org:8443`
- **Authentication Base**: `/auth`

### Required Dependencies

Install on your server:
```bash
pip install PyJWT bcrypt httpx
```

### OAuth Configuration

Edit `backend/core/golfai_oauth.py` and add your credentials:
```python
# Google OAuth - Get from Google Cloud Console
GOOGLE_CLIENT_ID = "your-client-id.apps.googleusercontent.com"

# Apple OAuth - Get from Apple Developer Portal  
APPLE_CLIENT_ID = "com.yourcompany.golfswingai"  # Your Bundle ID
APPLE_TEAM_ID = "YOUR_TEAM_ID"
APPLE_KEY_ID = "YOUR_KEY_ID"
```

## iOS Implementation

### 1. Project Setup

#### Add Dependencies (Swift Package Manager)

In Xcode, go to File → Add Package Dependencies:
```
https://github.com/google/GoogleSignIn-iOS
```

#### Info.plist Configuration

Add to your `Info.plist`:
```xml
<!-- Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from Google -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com</string>

<!-- Camera Usage (for swing recording) -->
<key>NSCameraUsageDescription</key>
<string>GolfSwingAI needs camera access to record your golf swing</string>
```

#### Enable Capabilities

In Xcode:
1. Select your app target
2. Go to "Signing & Capabilities"
3. Click "+" and add "Sign in with Apple"

### 2. Authentication Manager

Create `AuthenticationManager.swift`:
```swift
import Foundation
import SwiftUI
import GoogleSignIn
import AuthenticationServices
import Security

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var isLoading = false
    
    private let baseURL = "https://golfai.duckdns.org:8443"
    private let keychain = KeychainHelper()
    
    init() {
        checkAuthStatus()
    }
    
    // MARK: - Token Management
    
    func saveTokens(accessToken: String, refreshToken: String) {
        keychain.save(accessToken, for: "access_token")
        keychain.save(refreshToken, for: "refresh_token")
        isAuthenticated = true
    }
    
    func getAccessToken() -> String? {
        return keychain.get("access_token")
    }
    
    func clearTokens() {
        keychain.delete("access_token")
        keychain.delete("refresh_token")
        isAuthenticated = false
        currentUser = nil
    }
    
    // MARK: - Authentication Status
    
    func checkAuthStatus() {
        guard let token = getAccessToken() else {
            isAuthenticated = false
            return
        }
        
        // Verify token with server
        Task {
            await fetchUserProfile()
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func register(email: String, username: String, password: String, fullName: String?, handicap: Double?) async throws {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "username": username,
            "password": password,
            "full_name": fullName ?? "",
            "handicap": handicap ?? 0,
            "skill_level": "beginner"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.registrationFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        await MainActor.run {
            saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            currentUser = authResponse.user
        }
    }
    
    func login(username: String, password: String) async throws {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "username": username,
            "password": password,
            "device_info": UIDevice.current.name
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.loginFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        await MainActor.run {
            saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            currentUser = authResponse.user
        }
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result,
                      let idToken = result.user.idToken?.tokenString else {
                    continuation.resume(throwing: AuthError.googleSignInFailed)
                    return
                }
                
                Task {
                    do {
                        try await self.sendGoogleTokenToServer(
                            idToken: idToken,
                            email: result.user.profile?.email,
                            name: result.user.profile?.name,
                            picture: result.user.profile?.imageURL(withDimension: 200)?.absoluteString
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func sendGoogleTokenToServer(idToken: String, email: String?, name: String?, picture: String?) async throws {
        let url = URL(string: "\(baseURL)/auth/signin/google")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "id_token": idToken,
            "email": email,
            "name": name,
            "picture": picture
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.googleSignInFailed
        }
        
        let socialResponse = try JSONDecoder().decode(SocialAuthResponse.self, from: data)
        await MainActor.run {
            saveTokens(accessToken: socialResponse.accessToken, refreshToken: socialResponse.refreshToken)
            currentUser = socialResponse.userProfile
            
            if socialResponse.isNewUser {
                // Handle new user onboarding if needed
            }
        }
    }
    
    // MARK: - Apple Sign-In
    
    func handleAppleSignIn(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.appleSignInFailed
        }
        
        var fullName: [String: String]? = nil
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            fullName = [
                "givenName": givenName,
                "familyName": familyName
            ]
        }
        
        try await sendAppleTokenToServer(
            idToken: idTokenString,
            authorizationCode: appleIDCredential.authorizationCode.map { String(data: $0, encoding: .utf8) } ?? nil,
            email: appleIDCredential.email,
            fullName: fullName
        )
    }
    
    private func sendAppleTokenToServer(idToken: String, authorizationCode: String?, email: String?, fullName: [String: String]?) async throws {
        let url = URL(string: "\(baseURL)/auth/signin/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "id_token": idToken,
            "authorization_code": authorizationCode,
            "email": email,
            "full_name": fullName
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.appleSignInFailed
        }
        
        let socialResponse = try JSONDecoder().decode(SocialAuthResponse.self, from: data)
        await MainActor.run {
            saveTokens(accessToken: socialResponse.accessToken, refreshToken: socialResponse.refreshToken)
            currentUser = socialResponse.userProfile
        }
    }
    
    // MARK: - Profile Management
    
    func fetchUserProfile() async {
        guard let token = getAccessToken() else { return }
        
        let url = URL(string: "\(baseURL)/auth/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                await refreshToken()
                return
            }
            
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            await MainActor.run {
                self.currentUser = profile
                self.isAuthenticated = true
            }
        } catch {
            print("Failed to fetch profile: \(error)")
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async {
        guard let refreshToken = keychain.get("refresh_token") else {
            await MainActor.run {
                clearTokens()
            }
            return
        }
        
        let url = URL(string: "\(baseURL)/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RefreshResponse.self, from: data)
            
            await MainActor.run {
                saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            }
            
            // Retry fetching profile
            await fetchUserProfile()
        } catch {
            print("Token refresh failed: \(error)")
            await MainActor.run {
                clearTokens()
            }
        }
    }
    
    // MARK: - Logout
    
    func logout() async {
        if let token = getAccessToken() {
            let url = URL(string: "\(baseURL)/auth/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            _ = try? await URLSession.shared.data(for: request)
        }
        
        await MainActor.run {
            clearTokens()
        }
    }
    
    // MARK: - Swing Analysis
    
    func saveSwingAnalysis(result: SwingAnalysisResult) async throws {
        guard let token = getAccessToken() else { throw AuthError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/auth/swing/save")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "predicted_label": result.predictedLabel,
            "confidence": result.confidence,
            "camera_angle": result.cameraAngle ?? "",
            "physics_insights": result.physicsInsights ?? "",
            "recommendations": result.recommendations ?? [],
            "notes": result.notes ?? ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.saveFailed
        }
    }
}

// MARK: - Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: UserProfile
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct SocialAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let isNewUser: Bool
    let userProfile: UserProfile
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case isNewUser = "is_new_user"
        case userProfile = "user_profile"
    }
}

struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let fullName: String?
    let handicap: Double?
    let skillLevel: String?
    let preferredHand: String?
    let profilePhotoUrl: String?
    let createdAt: String
    let lastLogin: String?
    let isVerified: Bool
    let preferences: [String: Any]?
    let stats: UserStats?
    
    enum CodingKeys: String, CodingKey {
        case id, email, username
        case fullName = "full_name"
        case handicap
        case skillLevel = "skill_level"
        case preferredHand = "preferred_hand"
        case profilePhotoUrl = "profile_photo_url"
        case createdAt = "created_at"
        case lastLogin = "last_login"
        case isVerified = "is_verified"
        case preferences, stats
    }
}

struct UserStats: Codable {
    let totalSwings: Int
    let onPlaneCount: Int?
    let avgConfidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalSwings = "total_swings"
        case onPlaneCount = "on_plane_count"
        case avgConfidence = "avg_confidence"
    }
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case registrationFailed
    case loginFailed
    case googleSignInFailed
    case appleSignInFailed
    case tokenExpired
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please login to continue"
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .loginFailed:
            return "Invalid username or password"
        case .googleSignInFailed:
            return "Google sign-in failed"
        case .appleSignInFailed:
            return "Apple sign-in failed"
        case .tokenExpired:
            return "Session expired. Please login again."
        case .saveFailed:
            return "Failed to save data"
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    func save(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

### 3. SwiftUI Views

Create `LoginView.swift`:
```swift
import SwiftUI
import GoogleSignIn
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var username = ""
    @State private var password = ""
    @State private var showRegistration = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo
            Image("golf_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
            
            Text("GolfSwingAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Email/Password Login
            VStack(spacing: 15) {
                TextField("Username or Email", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: loginWithPassword) {
                    Text("Sign In")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Button(action: { showRegistration = true }) {
                    Text("Create Account")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("OR")
                    .foregroundColor(.gray)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal)
            
            // Social Login
            VStack(spacing: 12) {
                // Google Sign-In
                Button(action: signInWithGoogle) {
                    HStack {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Apple Sign-In
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                )
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
                .frame(height: 50)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView(authManager: authManager)
        }
    }
    
    func loginWithPassword() {
        Task {
            do {
                try await authManager.login(username: username, password: password)
            } catch {
                // Show error alert
                print("Login failed: \(error)")
            }
        }
    }
    
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        Task {
            do {
                try await authManager.signInWithGoogle(presentingViewController: rootViewController)
            } catch {
                print("Google sign-in failed: \(error)")
            }
        }
    }
    
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .success(let authorization):
                do {
                    try await authManager.handleAppleSignIn(authorization: authorization)
                } catch {
                    print("Apple sign-in failed: \(error)")
                }
            case .failure(let error):
                print("Apple sign-in error: \(error)")
            }
        }
    }
}
```

### 4. App Entry Point

Update your `App.swift`:
```swift
import SwiftUI
import GoogleSignIn

@main
struct GolfSwingAIApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
```

## Android Implementation

### 1. Dependencies

Add to `app/build.gradle`:
```gradle
dependencies {
    // Google Sign-In
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
    
    // Retrofit for API calls
    implementation 'com.squareup.retrofit2:retrofit:2.9.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
    
    // Secure storage
    implementation 'androidx.security:security-crypto:1.1.0-alpha06'
    
    // Coroutines
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
}
```

### 2. API Service

Create `ApiService.kt`:
```kotlin
interface ApiService {
    @POST("/auth/register")
    suspend fun register(@Body request: RegisterRequest): AuthResponse
    
    @POST("/auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse
    
    @POST("/auth/signin/google")
    suspend fun googleSignIn(@Body request: GoogleSignInRequest): SocialAuthResponse
    
    @POST("/auth/signin/apple")
    suspend fun appleSignIn(@Body request: AppleSignInRequest): SocialAuthResponse
    
    @GET("/auth/profile")
    suspend fun getProfile(@Header("Authorization") token: String): UserProfile
    
    @POST("/auth/refresh")
    suspend fun refreshToken(@Body request: RefreshRequest): RefreshResponse
    
    @POST("/auth/swing/save")
    suspend fun saveSwingAnalysis(
        @Header("Authorization") token: String,
        @Body analysis: SwingAnalysis
    ): Response<Unit>
}
```

## Testing

### Test Authentication Flow

1. **Register New User**:
```bash
curl -k -X POST https://golfai.duckdns.org:8443/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "Test123!",
    "full_name": "Test User",
    "handicap": 15.5,
    "skill_level": "intermediate"
  }'
```

2. **Login**:
```bash
curl -k -X POST https://golfai.duckdns.org:8443/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "Test123!"
  }'
```

3. **Get Profile** (with token):
```bash
curl -k -X GET https://golfai.duckdns.org:8443/auth/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## Getting OAuth Credentials

### Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google Sign-In API
4. Go to Credentials → Create Credentials → OAuth 2.0 Client ID
5. Choose iOS/Android application type
6. Add your bundle ID (iOS) or package name (Android)
7. Download the configuration file
8. Copy the Client ID to your server's `golfai_oauth.py`

### Apple Sign-In Setup

1. Go to [Apple Developer Portal](https://developer.apple.com/)
2. Go to Identifiers → Your App ID
3. Enable "Sign in with Apple" capability
4. Go to Keys → Create a new key
5. Enable "Sign in with Apple" for the key
6. Download the key file (.p8)
7. Note your Team ID and Key ID
8. Update `golfai_oauth.py` with these values

## Security Best Practices

1. **Token Storage**: Use iOS Keychain / Android EncryptedSharedPreferences
2. **HTTPS Only**: Never send tokens over HTTP
3. **Token Expiration**: Access tokens expire after 30 days
4. **Refresh Tokens**: Valid for 90 days, use to get new access tokens
5. **Input Validation**: Validate all inputs on both client and server
6. **Rate Limiting**: Implement rate limiting on authentication endpoints
7. **Password Requirements**: Minimum 6 characters (increase for production)

## Database Location

User data is stored at:
- **Windows**: `C:\Users\{username}\Documents\GolfSwingAI_Data\golfai_users.db`
- **Database**: SQLite with encrypted sensitive fields
- **Backup**: Implement regular backups in production

## Troubleshooting

### Common Issues

1. **SSL Certificate Warnings**: 
   - Development uses self-signed certificates
   - In production, use Let's Encrypt or proper SSL

2. **Token Expired**:
   - Implement automatic token refresh
   - Check token before each API call

3. **OAuth Token Invalid**:
   - Verify Client IDs match between app and server
   - Check bundle ID / package name configuration

4. **CORS Issues**:
   - Server is configured to accept all origins
   - In production, specify your app's domain

## Support

For issues or questions:
- Check server logs: `start_server_with_logs.bat`
- GitHub Issues: https://github.com/nakulb23/golf-swing-ai/issues
- API Documentation: View at https://golfai.duckdns.org:8443/docs