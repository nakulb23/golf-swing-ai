import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn

class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaultsKey = "currentUser"
    private let isAuthenticatedKey = "isAuthenticated"
    private var authorizationController: ASAuthorizationController?
    
    override init() {
        super.init()
        loadUserFromStorage()
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            do {
                // In a real app, this would call your backend API
                let user = try validateAndCreateUser(email: email, password: password)
                currentUser = user
                isAuthenticated = true
                saveUserToStorage()
                SimpleAnalytics.shared.trackAuth(method: "email")
                SimpleAnalytics.shared.trackProfileUpdate(
                    experienceLevel: user.experienceLevel.rawValue,
                    hasHandicap: user.handicap != nil,
                    hasHomeCourse: user.homeCourse != nil,
                    yearsPlayed: SimpleAnalytics.shared.getYearsRange(user.yearsPlayed)
                )
            } catch {
                if let authError = error as? AuthenticationError {
                    errorMessage = authError.localizedDescription
                } else {
                    errorMessage = "An unexpected error occurred"
                }
            }
            isLoading = false
        }
    }
    
    func signUp(registrationData: RegistrationData) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            do {
                try validateRegistrationData(registrationData)
                
                let user = User(
                    email: registrationData.email,
                    username: registrationData.username,
                    firstName: registrationData.firstName,
                    lastName: registrationData.lastName,
                    handicap: Double(registrationData.handicap),
                    preferredHand: registrationData.preferredHand,
                    experienceLevel: registrationData.experienceLevel
                )
                
                currentUser = user
                isAuthenticated = true
                saveUserToStorage()
                SimpleAnalytics.shared.trackAuth(method: "email")
                SimpleAnalytics.shared.trackProfileUpdate(
                    experienceLevel: user.experienceLevel.rawValue,
                    hasHandicap: user.handicap != nil,
                    hasHomeCourse: user.homeCourse != nil,
                    yearsPlayed: SimpleAnalytics.shared.getYearsRange(user.yearsPlayed)
                )
            } catch {
                if let authError = error as? AuthenticationError {
                    errorMessage = authError.localizedDescription
                } else {
                    errorMessage = "An unexpected error occurred"
                }
            }
            isLoading = false
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        clearUserFromStorage()
    }
    
    func resetPassword(email: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // In a real app, this would call your backend API
            // For now, just show success
            isLoading = false
        }
    }
    
    // MARK: - Social Authentication Methods
    func signInWithApple() {
        print("🍎 Apple Sign-In: Starting...")
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // Store controller to prevent deallocation
        self.authorizationController = authorizationController
        print("🍎 Apple Sign-In: Performing requests...")
        
        // Ensure we're on main thread for UI presentation
        DispatchQueue.main.async {
            authorizationController.performRequests()
            print("🍎 Apple Sign-In: Requests performed on main thread")
        }
    }
    
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        print("🔍 Google Sign-In: Starting...")
        
        // Check if Google Sign-In is configured
        guard GIDSignIn.sharedInstance.configuration != nil else {
            print("❌ Google Sign-In: Configuration missing")
            await MainActor.run {
                self.errorMessage = "Google Sign-In not configured. Please add GoogleService-Info.plist"
                self.isLoading = false
            }
            return
        }
        
        print("✅ Google Sign-In: Configuration found")
        
        // Get the presenting view controller
        guard let windowScene = await MainActor.run(body: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
        }) else {
            print("❌ Google Sign-In: No active window scene")
            await MainActor.run {
                self.errorMessage = "Unable to find active window scene"
                self.isLoading = false
            }
            return
        }
        
        print("✅ Google Sign-In: Window scene found")
        
        guard let rootViewController = await MainActor.run(body: {
            windowScene.windows.first?.rootViewController
        }) else {
            print("❌ Google Sign-In: No root view controller")
            await MainActor.run {
                self.errorMessage = "Unable to find root view controller"
                self.isLoading = false
            }
            return
        }
        
        print("✅ Google Sign-In: Root view controller found: \(type(of: rootViewController))")
        
        await MainActor.run {
            print("🚀 Google Sign-In: Calling signIn on main thread...")
            
            Task {
                do {
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                    let user = result.user
                    
                    print("✅ Google Sign-In: Success! User: \(user.profile?.email ?? "unknown")")
                    
                    await MainActor.run {
                        let newUser = User(
                            email: user.profile?.email ?? "user@gmail.com",
                            username: "google_user_\(Date().timeIntervalSince1970)",
                            firstName: user.profile?.givenName ?? "Google",
                            lastName: user.profile?.familyName ?? "User"
                        )
                        self.currentUser = newUser
                        self.isAuthenticated = true
                        self.saveUserToStorage()
                        SimpleAnalytics.shared.trackAuth(method: "google")
                        SimpleAnalytics.shared.trackProfileUpdate(
                            experienceLevel: newUser.experienceLevel.rawValue,
                            hasHandicap: newUser.handicap != nil,
                            hasHomeCourse: newUser.homeCourse != nil,
                            yearsPlayed: SimpleAnalytics.shared.getYearsRange(newUser.yearsPlayed)
                        )
                        self.isLoading = false
                    }
                } catch {
                    print("❌ Google Sign-In: Error: \(error)")
                    await MainActor.run {
                        if let gidError = error as? GIDSignInError {
                            switch gidError.code {
                            case .canceled:
                                print("🔴 Google Sign-In: User cancelled")
                                // User cancelled - don't show error, just stop loading
                                break
                            case .keychain:
                                print("🔴 Google Sign-In: Keychain error")
                                self.errorMessage = "Keychain error occurred."
                            default:
                                print("🔴 Google Sign-In: Other error: \(gidError.code)")
                                self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                            }
                        } else {
                            print("🔴 Google Sign-In: Non-GID error: \(error)")
                            self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                        }
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    
    // MARK: - User Profile Updates
    func updateUserProfile(_ updatedUser: User) {
        currentUser = updatedUser
        saveUserToStorage()
        SimpleAnalytics.shared.trackProfileUpdate(
            experienceLevel: updatedUser.experienceLevel.rawValue,
            hasHandicap: updatedUser.handicap != nil,
            hasHomeCourse: updatedUser.homeCourse != nil,
            yearsPlayed: SimpleAnalytics.shared.getYearsRange(updatedUser.yearsPlayed)
        )
    }
    
    func recordSwingAnalysis(_ result: SwingAnalysisResult) {
        guard var user = currentUser else { return }
        user.profile.recordSwingAnalysis(result)
        currentUser = user
        saveUserToStorage()
        SimpleAnalytics.shared.trackSwingAnalysis(
            speedRange: SimpleAnalytics.shared.getSpeedRange(result.swingSpeed),
            userExperience: user.experienceLevel.rawValue
        )
    }
    
    // MARK: - Validation Methods
    private func validateRegistrationData(_ data: RegistrationData) throws {
        guard isValidEmail(data.email) else {
            throw AuthenticationError.invalidEmail
        }
        
        guard data.password.count >= 8 else {
            throw AuthenticationError.passwordTooShort
        }
        
        guard data.password == data.confirmPassword else {
            throw AuthenticationError.passwordsDoNotMatch
        }
        
        // In a real app, you'd check if email already exists
        // For demo purposes, we'll assume all emails are available
    }
    
    private func validateAndCreateUser(email: String, password: String) throws -> User {
        guard isValidEmail(email) else {
            throw AuthenticationError.invalidEmail
        }
        
        guard password.count >= 8 else {
            throw AuthenticationError.invalidCredentials
        }
        
        // In a real app, this would authenticate against your backend
        // For demo purposes, create a mock user
        return User(
            email: email,
            username: "demo_user",
            firstName: "Demo",
            lastName: "User"
        )
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Persistence
    private func saveUserToStorage() {
        guard let user = currentUser else { return }
        
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            UserDefaults.standard.set(true, forKey: isAuthenticatedKey)
        }
    }
    
    private func loadUserFromStorage() {
        guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return
        }
        
        currentUser = user
        isAuthenticated = UserDefaults.standard.bool(forKey: isAuthenticatedKey)
    }
    
    private func clearUserFromStorage() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: isAuthenticatedKey)
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎 Apple Sign-In: Success callback received!")
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print("🍎 Apple Sign-In: Processing Apple ID credential...")
            
            let email = appleIDCredential.email ?? "user@privaterelay.appleid.com"
            let firstName = appleIDCredential.fullName?.givenName ?? "Apple"
            let lastName = appleIDCredential.fullName?.familyName ?? "User"
            
            print("🍎 Apple Sign-In: Email: \(email), Name: \(firstName) \(lastName)")
            
            let user = User(
                email: email,
                username: "apple_user_\(Date().timeIntervalSince1970)",
                firstName: firstName,
                lastName: lastName
            )
            
            DispatchQueue.main.async {
                print("🍎 Apple Sign-In: Setting user and authentication state...")
                self.currentUser = user
                self.isAuthenticated = true
                self.saveUserToStorage()
                SimpleAnalytics.shared.trackAuth(method: "apple")
                SimpleAnalytics.shared.trackProfileUpdate(
                    experienceLevel: user.experienceLevel.rawValue,
                    hasHandicap: user.handicap != nil,
                    hasHomeCourse: user.homeCourse != nil,
                    yearsPlayed: SimpleAnalytics.shared.getYearsRange(user.yearsPlayed)
                )
                self.isLoading = false
                self.authorizationController = nil
                print("🍎 Apple Sign-In: Complete! User authenticated.")
            }
        } else {
            print("🍎 Apple Sign-In: ERROR - No Apple ID credential found")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to get Apple ID credential"
                self.isLoading = false
                self.authorizationController = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🍎 Apple Sign-In: Error callback received: \(error)")
        
        DispatchQueue.main.async {
            if let authError = error as? ASAuthorizationError {
                print("🍎 Apple Sign-In: ASAuthorizationError code: \(authError.code.rawValue)")
                switch authError.code {
                case .canceled:
                    // User cancelled - don't show error, just stop loading
                    break
                case .failed:
                    self.errorMessage = "Apple Sign-In failed. Please try again."
                case .invalidResponse:
                    self.errorMessage = "Invalid response from Apple. Please try again."
                case .notHandled:
                    self.errorMessage = "Apple Sign-In not handled. Please try again."
                case .unknown:
                    self.errorMessage = "An unknown error occurred with Apple Sign-In."
                case .notInteractive:
                    self.errorMessage = "Apple Sign-In requires user interaction."
                case .matchedExcludedCredential:
                    self.errorMessage = "Apple Sign-In credential excluded."
                case .credentialImport:
                    self.errorMessage = "Apple Sign-In credential import error."
                case .credentialExport:
                    self.errorMessage = "Apple Sign-In credential export error."
                @unknown default:
                    self.errorMessage = "Apple Sign-In encountered an unexpected error."
                }
            } else {
                self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
            self.isLoading = false
            self.authorizationController = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🍎 Apple Sign-In: Getting presentation anchor...")
        
        // Try to get the key window from active scenes
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            print("🍎 Apple Sign-In: Using active window: \(window)")
            return window
        }
        
        // Fallback to any available window from any scene
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               let window = windowScene.windows.first {
                print("🍎 Apple Sign-In: Using fallback window from scene: \(window)")
                return window
            }
        }
        
        print("🍎 Apple Sign-In: WARNING - No window found, creating new one")
        return UIWindow()
    }
}

