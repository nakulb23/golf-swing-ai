import Foundation

// MARK: - Wire types that mirror the server's JSON responses

struct AuthTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let user: ServerUser
}

struct TokenRefreshResponse: Codable {
    let access_token: String
    let token_type: String
}

/// Server-side user model (snake_case to match the API).
struct ServerUser: Codable {
    let id: String
    let email: String
    let username: String
    let first_name: String
    let last_name: String
    let handicap: Double?
    let preferred_hand: String
    let experience_level: String
    let home_course: String?
    let years_played: Int?
    let date_created: String
    let last_login: String?

    /// Convert to the local User model used throughout the app.
    func toLocalUser() -> User {
        let hand: GolfHand = (preferred_hand == "left") ? .left : .right
        let level = ExperienceLevel(rawValue: experience_level) ?? .beginner
        return User(
            email: email,
            username: username,
            firstName: first_name,
            lastName: last_name,
            handicap: handicap,
            preferredHand: hand,
            experienceLevel: level,
            homeCourse: home_course,
            yearsPlayed: years_played
        )
    }
}

struct ServerErrorResponse: Codable {
    let detail: String
}

// MARK: - Auth API errors

enum AuthAPIError: Error, LocalizedError {
    case emailAlreadyExists
    case invalidCredentials
    case networkError(String)
    case serverError(String)
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .emailAlreadyExists:   return "An account with this email already exists"
        case .invalidCredentials:   return "Invalid email or password"
        case .networkError(let m):  return m
        case .serverError(let m):   return m
        case .tokenExpired:         return "Session expired — please sign in again"
        }
    }
}

// MARK: - AuthAPIClient

/// Handles all HTTP communication with the /auth/* endpoints on the server.
/// Stores JWTs in Keychain and automatically refreshes the access token when needed.
@MainActor
final class AuthAPIClient {

    static let shared = AuthAPIClient()
    private init() {}

    // Build from Constants.baseURL so it's always in sync
    private var baseURL: String { Constants.baseURL }

    // MARK: - Register

    func register(
        email: String,
        password: String,
        username: String,
        firstName: String,
        lastName: String,
        handicap: Double? = nil,
        preferredHand: String = "right",
        experienceLevel: String = "beginner"
    ) async throws -> AuthTokenResponse {
        var body: [String: Any] = [
            "email":            email,
            "password":         password,
            "username":         username,
            "first_name":       firstName,
            "last_name":        lastName,
            "preferred_hand":   preferredHand,
            "experience_level": experienceLevel
        ]
        if let h = handicap { body["handicap"] = h }

        let response: AuthTokenResponse = try await post("/auth/register", body: body, requiresAuth: false)
        saveTokens(response)
        return response
    }

    // MARK: - Login

    func login(email: String, password: String) async throws -> AuthTokenResponse {
        let body: [String: Any] = ["email": email, "password": password]
        let response: AuthTokenResponse = try await post("/auth/login", body: body, requiresAuth: false)
        saveTokens(response)
        return response
    }

    // MARK: - Refresh

    func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainManager.read(.refreshToken) else {
            throw AuthAPIError.tokenExpired
        }
        let body: [String: Any] = ["refresh_token": refreshToken]
        let response: TokenRefreshResponse = try await post("/auth/refresh", body: body, requiresAuth: false)
        KeychainManager.save(response.access_token, for: .accessToken)
        return response.access_token
    }

    // MARK: - Get current user

    func getMe() async throws -> ServerUser {
        return try await get("/auth/me")
    }

    // MARK: - Update profile

    func updateProfile(
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        handicap: Double? = nil,
        preferredHand: String? = nil,
        experienceLevel: String? = nil,
        homeCourse: String? = nil,
        yearsPlayed: Int? = nil
    ) async throws -> ServerUser {
        var body: [String: Any] = [:]
        if let v = username      { body["username"]          = v }
        if let v = firstName     { body["first_name"]        = v }
        if let v = lastName      { body["last_name"]         = v }
        if let v = handicap      { body["handicap"]          = v }
        if let v = preferredHand { body["preferred_hand"]    = v }
        if let v = experienceLevel { body["experience_level"] = v }
        if let v = homeCourse    { body["home_course"]       = v }
        if let v = yearsPlayed   { body["years_played"]      = v }

        return try await put("/auth/me", body: body)
    }

    // MARK: - Reset password request

    func requestPasswordReset(email: String) async throws {
        let body: [String: Any] = ["email": email]
        let _: [String: String] = try await post("/auth/reset-password/request", body: body, requiresAuth: false)
    }

    // MARK: - Delete account

    func deleteAccount() async throws {
        try await delete("/auth/me")
    }

    // MARK: - Sign out (local only — JWTs are stateless)

    func signOut() {
        KeychainManager.clearAll()
    }

    // MARK: - Token accessors

    var accessToken: String? { KeychainManager.read(.accessToken) }
    var isLoggedIn: Bool { accessToken != nil }

    // MARK: - Private helpers

    private func saveTokens(_ response: AuthTokenResponse) {
        KeychainManager.save(response.access_token, for: .accessToken)
        KeychainManager.save(response.refresh_token, for: .refreshToken)
    }

    // MARK: Generic GET with auto-refresh

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", body: nil, requiresAuth: true)
        return try await performWithRetry(request)
    }

    // MARK: Generic POST

    private func post<T: Decodable>(_ path: String, body: [String: Any], requiresAuth: Bool) async throws -> T {
        let request = try buildRequest(path: path, method: "POST", body: body, requiresAuth: requiresAuth)
        return try await performWithRetry(request, retryOnUnauthorized: requiresAuth)
    }

    // MARK: Generic PUT

    private func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let request = try buildRequest(path: path, method: "PUT", body: body, requiresAuth: true)
        return try await performWithRetry(request)
    }

    // MARK: Generic DELETE (no response body)

    private func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE", body: nil, requiresAuth: true)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthAPIError.serverError("Delete failed")
        }
    }

    // MARK: Build URLRequest

    private func buildRequest(path: String, method: String, body: [String: Any]?, requiresAuth: Bool) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw AuthAPIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if requiresAuth, let token = KeychainManager.read(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    // MARK: Perform request with automatic token refresh

    private func performWithRetry<T: Decodable>(_ request: URLRequest, retryOnUnauthorized: Bool = true) async throws -> T {
        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthAPIError.networkError("No HTTP response")
        }

        // Try to refresh token once on 401
        if http.statusCode == 401 && retryOnUnauthorized {
            do {
                _ = try await refreshAccessToken()
            } catch {
                KeychainManager.clearAll()
                throw AuthAPIError.tokenExpired
            }

            // Rebuild with fresh token
            var retried = request
            if let newToken = KeychainManager.read(.accessToken) {
                retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            }
            let (retryData, retryResponse) = try await performRequest(retried)
            guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                throw AuthAPIError.networkError("No HTTP response on retry")
            }
            return try decode(retryData, statusCode: retryHTTP.statusCode)
        }

        return try decode(data, statusCode: http.statusCode)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw AuthAPIError.networkError(urlError.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ data: Data, statusCode: Int) throws -> T {
        switch statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw AuthAPIError.serverError("Could not parse server response")
            }
        case 401:
            throw AuthAPIError.invalidCredentials
        case 409:
            throw AuthAPIError.emailAlreadyExists
        default:
            // Try to extract the server's error message
            if let errResponse = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                throw AuthAPIError.serverError(errResponse.detail)
            }
            throw AuthAPIError.serverError("Server error (\(statusCode))")
        }
    }
}
