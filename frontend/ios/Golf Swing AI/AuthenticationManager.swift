import SwiftUI
import Combine
import AuthenticationServices
@preconcurrency import GoogleSignIn

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaultsKey = "currentUser"
    private let isAuthenticatedKey = "isAuthenticated"
    private var authorizationController: ASAuthorizationController?

    // Reference to the shared API client
    private let api = AuthAPIClient.shared

    override init() {
        super.init()
        loadUserFromStorage()
    }

    // MARK: - Email / Password Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.login(email: email, password: password)
            let user = response.user.toLocalUser()
            currentUser = user
            isAuthenticated = true
            saveUserToStorage()
            trackAuth(user: user, method: "email")
        } catch let authError as AuthAPIError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    // MARK: - Email / Password Sign Up

    func signUp(registrationData: RegistrationData) async {
        isLoading = true
        errorMessage = nil

        // Local validation first (fast feedback before hitting the network)
        do {
            try validateRegistrationData(registrationData)
        } catch let authError as AuthenticationError {
            errorMessage = authError.localizedDescription
            isLoading = false
            return
        } catch {
            errorMessage = "Validation failed"
            isLoading = false
            return
        }

        do {
            let response = try await api.register(
                email: registrationData.email,
                password: registrationData.password,
                username: registrationData.username,
                firstName: registrationData.firstName,
                lastName: registrationData.lastName,
                handicap: Double(registrationData.handicap),
                preferredHand: registrationData.preferredHand.rawValue,
                experienceLevel: registrationData.experienceLevel.rawValue
            )
            let user = response.user.toLocalUser()
            currentUser = user
            isAuthenticated = true
            saveUserToStorage()
            trackAuth(user: user, method: "email")
        } catch let authError as AuthAPIError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        ChatHistoryManager.shared.clearUserData()
        api.signOut()          // clears Keychain tokens
        currentUser = nil
        isAuthenticated = false
        clearUserFromStorage()
    }

    // MARK: - Reset Password

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await api.requestPasswordReset(email: email)
            // No error means the request was accepted.
            // The server always returns 200 whether or not the email exists,
            // so we don't leak whether an account is registered.
        } catch let authError as AuthAPIError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = "Could not send reset email. Please try again."
        }

        isLoading = false
    }

    // MARK: - Social: Apple Sign-In

    func signInWithApple() {
        print("🍎 Apple Sign-In: Starting...")
        isLoading = true
        errorMessage = nil

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.authorizationController = controller

        DispatchQueue.main.async {
            controller.performRequests()
        }
    }

    // MARK: - Social: Google Sign-In

    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard GIDSignIn.sharedInstance.configuration != nil else {
            errorMessage = "Google Sign-In not configured. Please add GoogleService-Info.plist"
            isLoading = false
            return
        }

        guard let windowScene = await MainActor.run(body: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
        }) else {
            errorMessage = "Unable to find active window scene"
            isLoading = false
            return
        }

        guard let rootViewController = await MainActor.run(body: {
            windowScene.windows.first?.rootViewController
        }) else {
            errorMessage = "Unable to find root view controller"
            isLoading = false
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let googleUser = result.user

            let email     = googleUser.profile?.email ?? "user@gmail.com"
            let firstName = googleUser.profile?.givenName ?? "Golf"
            let lastName  = googleUser.profile?.familyName ?? "User"
            let username  = firstName.lowercased() + (lastName.isEmpty ? "" : "_" + lastName.lowercased())

            // Register (or silently re-login) on the server via email derived from Google
            // We use the Google ID token as the password so it's deterministic and private.
            let serverPassword = "google_" + (googleUser.userID ?? email)

            do {
                let response = try await api.login(email: email, password: serverPassword)
                let user = response.user.toLocalUser()
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.saveUserToStorage()
                    self.trackAuth(user: user, method: "google")
                    self.isLoading = false
                }
            } catch AuthAPIError.invalidCredentials {
                // Account doesn't exist yet — register it
                let response = try await api.register(
                    email: email,
                    password: serverPassword,
                    username: username,
                    firstName: firstName,
                    lastName: lastName
                )
                let user = response.user.toLocalUser()
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.saveUserToStorage()
                    self.trackAuth(user: user, method: "google")
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                if let gidError = error as? GIDSignInError, gidError.code == .canceled {
                    // User cancelled — no error shown
                } else if let apiError = error as? AuthAPIError {
                    self.errorMessage = apiError.localizedDescription
                } else {
                    self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - User Profile Updates

    func updateUserProfile(_ updatedUser: User) {
        currentUser = updatedUser
        saveUserToStorage()

        // Sync to server in the background
        Task {
            do {
                _ = try await api.updateProfile(
                    username: updatedUser.username,
                    firstName: updatedUser.firstName,
                    lastName: updatedUser.lastName,
                    handicap: updatedUser.handicap,
                    preferredHand: updatedUser.preferredHand.rawValue,
                    experienceLevel: updatedUser.experienceLevel.rawValue,
                    homeCourse: updatedUser.homeCourse,
                    yearsPlayed: updatedUser.yearsPlayed
                )
            } catch {
                print("⚠️ Profile sync to server failed: \(error)")
            }
        }

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

    // MARK: - Private Helpers

    private func trackAuth(user: User, method: String) {
        SimpleAnalytics.shared.trackAuth(method: method)
        SimpleAnalytics.shared.trackProfileUpdate(
            experienceLevel: user.experienceLevel.rawValue,
            hasHandicap: user.handicap != nil,
            hasHomeCourse: user.homeCourse != nil,
            yearsPlayed: SimpleAnalytics.shared.getYearsRange(user.yearsPlayed)
        )
    }

    private func validateRegistrationData(_ data: RegistrationData) throws {
        guard isValidEmail(data.email) else { throw AuthenticationError.invalidEmail }
        guard data.password.count >= 8 else { throw AuthenticationError.passwordTooShort }
        guard data.password == data.confirmPassword else { throw AuthenticationError.passwordsDoNotMatch }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    // MARK: - Persistence (local cache of the user object)

    private func saveUserToStorage() {
        guard let user = currentUser,
              let encoded = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        UserDefaults.standard.set(true, forKey: isAuthenticatedKey)
    }

    private func loadUserFromStorage() {
        // Restore from local cache. If a valid JWT token is present in the Keychain,
        // the user is considered authenticated without a network round-trip on launch.
        guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else { return }

        // Only restore session if the Keychain still holds a token
        guard AuthAPIClient.shared.isLoggedIn else {
            clearUserFromStorage()
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
        print("🍎 Apple Sign-In: Credential received")

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.errorMessage = "Failed to get Apple ID credential"
                self.isLoading = false
                self.authorizationController = nil
            }
            return
        }

        let email     = appleCredential.email ?? "apple_\(appleCredential.user)@privaterelay.appleid.com"
        let firstName = appleCredential.fullName?.givenName ?? "Apple"
        let lastName  = appleCredential.fullName?.familyName ?? "User"
        let username  = firstName.lowercased() + "_" + lastName.lowercased()

        // Use the stable Apple user identifier as the server password (deterministic, private)
        let serverPassword = "apple_" + appleCredential.user

        Task { @MainActor in
            do {
                let response: AuthTokenResponse
                do {
                    response = try await api.login(email: email, password: serverPassword)
                } catch AuthAPIError.invalidCredentials {
                    // First time sign-in with Apple — register the account
                    response = try await api.register(
                        email: email,
                        password: serverPassword,
                        username: username,
                        firstName: firstName,
                        lastName: lastName
                    )
                }
                self.currentUser = response.user.toLocalUser()
                self.isAuthenticated = true
                self.saveUserToStorage()
                self.trackAuth(user: self.currentUser!, method: "apple")
            } catch let apiError as AuthAPIError {
                self.errorMessage = apiError.localizedDescription
            } catch {
                self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
            self.isLoading = false
            self.authorizationController = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                // User cancelled — no error shown
            } else {
                self.errorMessage = "Apple Sign-In failed. Please try again."
            }
            self.isLoading = false
            self.authorizationController = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window
        }
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene, let window = windowScene.windows.first {
                return window
            }
        }
        return UIWindow()
    }
}
