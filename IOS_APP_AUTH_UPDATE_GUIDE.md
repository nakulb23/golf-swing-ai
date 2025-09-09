# iOS App Authentication Update Guide

## Overview
This guide shows the exact changes needed in your iOS app to implement the simplified authentication flow where Google/Apple handle their own authentication, and your server just stores user profiles.

## Server Base URL
```swift
let SERVER_URL = "https://golfai.duckdns.org:8443"
```

---

## 1. Google Sign-In Implementation

### Current (What You Have Now - STOP USING THIS):
```swift
// DON'T send Google ID token to server for verification
let googleToken = authentication.idToken
sendToServer(endpoint: "/auth/signin/google", data: ["google_token": googleToken])
```

### NEW Simplified Approach (USE THIS):
```swift
import GoogleSignIn

class GoogleAuthManager {
    
    func signInWithGoogle(presentingViewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                print("Google Sign-In error: \(error)")
                return
            }
            
            guard let user = result?.user else { return }
            
            // Prepare user info to send to YOUR server
            let userInfo: [String: Any] = [
                "google_id": user.userID ?? "",
                "email": user.profile?.email ?? "",
                "name": user.profile?.name ?? "",
                "given_name": user.profile?.givenName ?? "",
                "family_name": user.profile?.familyName ?? "",
                "picture": user.profile?.imageURL(withDimension: 200)?.absoluteString ?? "",
                "verified_email": true
            ]
            
            // Send to YOUR server (not Google's)
            self.sendToYourServer(userInfo: userInfo)
        }
    }
    
    func sendToYourServer(userInfo: [String: Any]) {
        let url = URL(string: "\(SERVER_URL)/auth/google")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: userInfo)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Extract tokens and user profile
                let accessToken = json["access_token"] as? String ?? ""
                let refreshToken = json["refresh_token"] as? String ?? ""
                let isNewUser = json["is_new_user"] as? Bool ?? false
                let userProfile = json["user_profile"] as? [String: Any]
                
                // Save tokens to Keychain
                self.saveTokens(access: accessToken, refresh: refreshToken)
                
                // Navigate to main app
                DispatchQueue.main.async {
                    if isNewUser {
                        // Show onboarding for new users
                        self.showOnboarding(profile: userProfile)
                    } else {
                        // Go to main app for returning users
                        self.goToMainApp(profile: userProfile)
                    }
                }
            }
        }.resume()
    }
}
```

---

## 2. Apple Sign-In Implementation

### Setup in Xcode:
1. Add "Sign in with Apple" capability
2. Import `AuthenticationServices`

### Implementation:
```swift
import AuthenticationServices

class AppleAuthManager: NSObject {
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
}

extension AppleAuthManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, 
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        
        // Prepare user info to send to YOUR server
        let userInfo: [String: Any] = [
            "apple_id": appleIDCredential.user,
            "email": appleIDCredential.email ?? "",
            "given_name": appleIDCredential.fullName?.givenName ?? "",
            "family_name": appleIDCredential.fullName?.familyName ?? "",
            "verified_email": true
        ]
        
        // Send to YOUR server
        sendToYourServer(endpoint: "/auth/apple", userInfo: userInfo)
    }
}
```

---

## 3. Email/Password Sign-Up

### Sign-Up Form:
```swift
class EmailSignUpViewController: UIViewController {
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var fullNameField: UITextField!
    
    @IBAction func signUpTapped() {
        guard let email = emailField.text,
              let username = usernameField.text,
              let password = passwordField.text,
              let fullName = fullNameField.text else { return }
        
        // Validate inputs
        guard isValidEmail(email),
              username.count >= 3,
              password.count >= 8 else {
            showError("Please check your inputs")
            return
        }
        
        // Prepare registration data
        let registrationData: [String: Any] = [
            "email": email,
            "username": username,
            "password": password,
            "full_name": fullName,
            "device_info": [
                "device_type": "iOS",
                "device_model": UIDevice.current.model,
                "os_version": UIDevice.current.systemVersion,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ]
        ]
        
        // Send to server
        registerUser(data: registrationData)
    }
    
    func registerUser(data: [String: Any]) {
        let url = URL(string: "\(SERVER_URL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response (same as Google/Apple)
            self.handleAuthResponse(data: data)
        }.resume()
    }
}
```

---

## 4. Email/Password Login

### Login Form:
```swift
class EmailLoginViewController: UIViewController {
    @IBOutlet weak var usernameOrEmailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    @IBAction func loginTapped() {
        let loginData: [String: Any] = [
            "username": usernameOrEmailField.text ?? "",
            "password": passwordField.text ?? "",
            "device_info": [
                "device_type": "iOS",
                "device_model": UIDevice.current.model,
                "os_version": UIDevice.current.systemVersion,
                "app_version": "1.0"
            ]
        ]
        
        login(data: loginData)
    }
    
    func login(data: [String: Any]) {
        let url = URL(string: "\(SERVER_URL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleAuthResponse(data: data)
        }.resume()
    }
}
```

---

## 5. Shared Authentication Handler

### Response Handler (Used by All Methods):
```swift
extension UIViewController {
    
    func handleAuthResponse(data: Data?) {
        guard let data = data else { 
            showError("Network error")
            return 
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Success - extract tokens
                    let accessToken = json?["access_token"] as? String ?? ""
                    let refreshToken = json?["refresh_token"] as? String ?? ""
                    let userProfile = json?["user_profile"] as? [String: Any]
                    
                    // Save tokens to Keychain
                    KeychainHelper.save(key: "access_token", value: accessToken)
                    KeychainHelper.save(key: "refresh_token", value: refreshToken)
                    
                    // Save user profile to UserDefaults
                    UserDefaults.standard.set(userProfile, forKey: "user_profile")
                    
                    // Navigate to main app
                    DispatchQueue.main.async {
                        self.navigateToMainApp()
                    }
                } else {
                    // Error - show message
                    let errorMessage = json?["detail"] as? String ?? "Authentication failed"
                    DispatchQueue.main.async {
                        self.showError(errorMessage)
                    }
                }
            }
        } catch {
            showError("Invalid response from server")
        }
    }
}
```

---

## 6. Token Management

### Save Tokens Securely:
```swift
class KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
```

### Use Tokens for API Calls:
```swift
func makeAuthenticatedRequest(endpoint: String) {
    guard let accessToken = KeychainHelper.get(key: "access_token") else {
        // No token - user needs to login
        navigateToLogin()
        return
    }
    
    let url = URL(string: "\(SERVER_URL)\(endpoint)")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle response
    }.resume()
}
```

---

## 7. Persistent Login

### Check on App Launch:
```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Check for stored tokens
        if let accessToken = KeychainHelper.get(key: "access_token") {
            // Verify token is still valid
            verifyToken(accessToken) { isValid in
                if isValid {
                    // Go directly to main app
                    self.showMainApp()
                } else {
                    // Try to refresh token
                    self.refreshAccessToken()
                }
            }
        } else {
            // No token - show login screen
            self.showLoginScreen()
        }
        
        return true
    }
    
    func refreshAccessToken() {
        guard let refreshToken = KeychainHelper.get(key: "refresh_token") else {
            showLoginScreen()
            return
        }
        
        let url = URL(string: "\(SERVER_URL)/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle new tokens or show login if refresh failed
        }.resume()
    }
}
```

---

## Summary of Changes

### 1. **Google Sign-In** ✅
- Remove token verification code
- Send user info directly to `/auth/google`
- No more token expiration issues

### 2. **Apple Sign-In** ✅
- Implement ASAuthorizationController
- Send user info to `/auth/apple`
- Handle first-time vs returning users

### 3. **Email Sign-Up** ✅
- Send to `/auth/register`
- Include device info
- Validate inputs client-side

### 4. **Email Login** ✅
- Send to `/auth/login`
- Support username or email
- Include device info

### 5. **Token Storage** ✅
- Use Keychain for tokens
- UserDefaults for profile
- Automatic token refresh

### 6. **Error Handling** ✅
- Parse server error messages
- Show user-friendly errors
- Handle network failures

---

## Testing Checklist

- [ ] Google Sign-In creates new account
- [ ] Google Sign-In logs in existing user
- [ ] Apple Sign-In creates new account
- [ ] Apple Sign-In logs in existing user
- [ ] Email registration works
- [ ] Email login works
- [ ] Tokens persist after app restart
- [ ] Token refresh works when expired
- [ ] Profile data loads correctly
- [ ] Logout clears all stored data

---

**Server Endpoints:**
- `/auth/google` - Google sign-in (simplified)
- `/auth/apple` - Apple sign-in (simplified)
- `/auth/register` - Email registration
- `/auth/login` - Email/password login
- `/auth/refresh` - Refresh access token
- `/auth/logout` - Logout user
- `/auth/profile` - Get user profile (requires token)