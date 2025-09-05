# GolfSwingAI App Implementation Guide

## Authentication System Integration

This guide explains how to implement user authentication in your GolfSwingAI iOS/Android app to connect with the server's new authentication system.

## Server Endpoints

The authentication system is now live on your server at:
- **Base URL**: `https://golfai.duckdns.org:8443`
- **Authentication Prefix**: `/auth`

## Authentication Flow

### 1. User Registration

**Endpoint**: `POST /auth/register`

**Request Body**:
```json
{
  "email": "user@example.com",
  "username": "golfer123",
  "password": "securePassword123",
  "full_name": "John Doe",
  "handicap": 15.5,
  "skill_level": "intermediate",
  "preferred_hand": "right"
}
```

**Response**:
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "Bearer",
  "expires_in": 2592000,
  "user": {
    "id": "unique_user_id",
    "email": "user@example.com",
    "username": "golfer123",
    "full_name": "John Doe",
    "handicap": 15.5,
    "skill_level": "intermediate",
    "preferred_hand": "right",
    "profile_photo_url": null,
    "created_at": "2025-01-20T10:00:00",
    "last_login": null,
    "is_verified": false,
    "preferences": {},
    "stats": {}
  }
}
```

### 2. User Login

**Endpoint**: `POST /auth/login`

**Request Body**:
```json
{
  "username": "golfer123",  // Can be email or username
  "password": "securePassword123",
  "device_info": "iPhone 14 Pro, iOS 17.2"
}
```

**Response**: Same as registration response

### 3. Token Storage (Client-Side)

#### iOS (Swift) Implementation:

```swift
import KeychainSwift

class AuthManager {
    private let keychain = KeychainSwift()
    private let accessTokenKey = "golfai_access_token"
    private let refreshTokenKey = "golfai_refresh_token"
    private let userIdKey = "golfai_user_id"
    
    func saveTokens(accessToken: String, refreshToken: String, userId: String) {
        keychain.set(accessToken, forKey: accessTokenKey)
        keychain.set(refreshToken, forKey: refreshTokenKey)
        keychain.set(userId, forKey: userIdKey)
    }
    
    func getAccessToken() -> String? {
        return keychain.get(accessTokenKey)
    }
    
    func getRefreshToken() -> String? {
        return keychain.get(refreshTokenKey)
    }
    
    func clearTokens() {
        keychain.delete(accessTokenKey)
        keychain.delete(refreshTokenKey)
        keychain.delete(userIdKey)
    }
    
    func isLoggedIn() -> Bool {
        return getAccessToken() != nil
    }
}
```

#### Android (Kotlin) Implementation:

```kotlin
import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class AuthManager(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    
    private val sharedPreferences = EncryptedSharedPreferences.create(
        context,
        "golfai_auth_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
    
    fun saveTokens(accessToken: String, refreshToken: String, userId: String) {
        sharedPreferences.edit().apply {
            putString("access_token", accessToken)
            putString("refresh_token", refreshToken)
            putString("user_id", userId)
            apply()
        }
    }
    
    fun getAccessToken(): String? {
        return sharedPreferences.getString("access_token", null)
    }
    
    fun getRefreshToken(): String? {
        return sharedPreferences.getString("refresh_token", null)
    }
    
    fun clearTokens() {
        sharedPreferences.edit().clear().apply()
    }
    
    fun isLoggedIn(): Boolean {
        return getAccessToken() != null
    }
}
```

### 4. Making Authenticated Requests

All authenticated endpoints require the `Authorization` header with the Bearer token.

#### iOS (Swift) Example:

```swift
func makeAuthenticatedRequest(endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) {
    guard let accessToken = authManager.getAccessToken() else {
        completion(.failure(AuthError.notLoggedIn))
        return
    }
    
    var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)")!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            // Token expired, try to refresh
            self.refreshToken { success in
                if success {
                    // Retry the request with new token
                    self.makeAuthenticatedRequest(endpoint: endpoint, completion: completion)
                } else {
                    completion(.failure(AuthError.tokenExpired))
                }
            }
        } else if let data = data {
            completion(.success(data))
        } else if let error = error {
            completion(.failure(error))
        }
    }.resume()
}
```

#### Android (Kotlin) Example:

```kotlin
suspend fun makeAuthenticatedRequest(endpoint: String): Result<String> {
    val accessToken = authManager.getAccessToken() 
        ?: return Result.failure(Exception("Not logged in"))
    
    return try {
        val response = httpClient.get("$baseURL$endpoint") {
            header("Authorization", "Bearer $accessToken")
            contentType(ContentType.Application.Json)
        }
        
        if (response.status == HttpStatusCode.Unauthorized) {
            // Token expired, refresh and retry
            val refreshSuccess = refreshToken()
            if (refreshSuccess) {
                makeAuthenticatedRequest(endpoint)
            } else {
                Result.failure(Exception("Token refresh failed"))
            }
        } else {
            Result.success(response.bodyAsText())
        }
    } catch (e: Exception) {
        Result.failure(e)
    }
}
```

### 5. Token Refresh

When the access token expires (after 30 days), use the refresh token to get a new access token without requiring the user to login again.

**Endpoint**: `POST /auth/refresh`

**Request Body**:
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Response**:
```json
{
  "access_token": "new_access_token",
  "refresh_token": "new_refresh_token",
  "token_type": "Bearer",
  "expires_in": 2592000
}
```

### 6. Persistent Login Implementation

#### App Launch Flow:

```swift
// iOS Swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    if authManager.isLoggedIn() {
        // User has stored tokens, verify they're still valid
        verifyTokenAndLoadProfile { isValid in
            if isValid {
                // Navigate to main app screen
                self.showMainScreen()
            } else {
                // Try to refresh token
                self.refreshToken { success in
                    if success {
                        self.showMainScreen()
                    } else {
                        self.showLoginScreen()
                    }
                }
            }
        }
    } else {
        // No stored tokens, show login screen
        showLoginScreen()
    }
    
    return true
}
```

```kotlin
// Android Kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        lifecycleScope.launch {
            when {
                authManager.isLoggedIn() -> {
                    // Verify token is still valid
                    val profileResult = getUserProfile()
                    if (profileResult.isSuccess) {
                        navigateToMainScreen()
                    } else {
                        // Try to refresh
                        val refreshResult = refreshToken()
                        if (refreshResult) {
                            navigateToMainScreen()
                        } else {
                            navigateToLoginScreen()
                        }
                    }
                }
                else -> navigateToLoginScreen()
            }
        }
    }
}
```

## Protected Endpoints

These endpoints require authentication:

### Get User Profile
```
GET /auth/profile
Authorization: Bearer {access_token}
```

### Update Profile
```
PUT /auth/profile
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "full_name": "John Doe Updated",
  "handicap": 12.5,
  "skill_level": "advanced"
}
```

### Save Swing Analysis
```
POST /auth/swing/save
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "predicted_label": "on_plane",
  "confidence": 0.95,
  "camera_angle": "side_on",
  "physics_insights": "Good rotation through impact",
  "recommendations": ["Maintain current swing path"],
  "notes": "Felt good, using 7 iron",
  "video_url": "optional_cloud_storage_url"
}
```

### Get Swing History
```
GET /auth/swing/history?limit=50
Authorization: Bearer {access_token}
```

### Get Progress Analytics
```
GET /auth/progress?days=30
Authorization: Bearer {access_token}
```

### Update Preferences
```
PUT /auth/preferences
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "units": "metric",
  "receive_tips": true,
  "share_data_for_improvement": true,
  "notification_enabled": true
}
```

## Logout Implementation

```swift
// iOS Swift
func logout() {
    // Call logout endpoint
    makeAuthenticatedRequest(endpoint: "/auth/logout") { _ in
        // Clear stored tokens regardless of server response
        self.authManager.clearTokens()
        
        // Clear any cached user data
        UserDefaults.standard.removeObject(forKey: "cached_user_profile")
        
        // Navigate to login screen
        self.showLoginScreen()
    }
}
```

```kotlin
// Android Kotlin
fun logout() {
    lifecycleScope.launch {
        // Call logout endpoint
        makeAuthenticatedRequest("/auth/logout")
        
        // Clear stored tokens
        authManager.clearTokens()
        
        // Clear cached data
        getSharedPreferences("user_cache", MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
        
        // Navigate to login
        navigateToLoginScreen()
    }
}
```

## Error Handling

Handle these common authentication errors:

| Status Code | Error | Action |
|------------|-------|--------|
| 401 | Unauthorized | Try refresh token, then redirect to login |
| 403 | Forbidden | User doesn't have permission |
| 400 | Bad Request | Show validation errors to user |
| 409 | Conflict | Email/username already exists |
| 500 | Server Error | Show generic error, retry |

## Security Best Practices

1. **Never store passwords** - Only store tokens
2. **Use secure storage** - iOS Keychain / Android EncryptedSharedPreferences
3. **HTTPS only** - Never send tokens over HTTP
4. **Token expiration** - Tokens expire after 30 days
5. **Refresh tokens** - Valid for 90 days
6. **Clear on logout** - Remove all stored tokens
7. **Biometric authentication** - Optional additional security layer

## Database Location

User data is stored securely on the server at:
- **Windows Path**: `C:\Users\{username}\Documents\GolfSwingAI_Data\golfai_users.db`
- **Database**: SQLite with proper indexing
- **Backups**: Implement regular backups in production

## Testing the Authentication

You can test the authentication system using curl or Postman:

### Register Test User:
```bash
curl -X POST https://golfai.duckdns.org:8443/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testgolfer",
    "password": "Test123!",
    "full_name": "Test Golfer",
    "handicap": 18.0,
    "skill_level": "beginner"
  }'
```

### Login:
```bash
curl -X POST https://golfai.duckdns.org:8443/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testgolfer",
    "password": "Test123!"
  }'
```

### Get Profile:
```bash
curl -X GET https://golfai.duckdns.org:8443/auth/profile \
  -H "Authorization: Bearer {your_access_token}"
```

## Support & Troubleshooting

Common issues and solutions:

1. **Token Expired**: Implement automatic token refresh
2. **Network Errors**: Implement retry logic with exponential backoff
3. **SSL Certificate Issues**: For development, you may need to allow self-signed certificates
4. **CORS Issues**: Server is configured to accept all origins, but specify your app's domain in production

## Next Steps

1. Implement the authentication flow in your app
2. Add biometric authentication for additional security
3. Implement offline mode with data sync
4. Add social login options (Google, Apple, Facebook)
5. Implement push notifications for progress updates

## Contact

For any questions or issues with the authentication system, please refer to the server logs or contact the development team.