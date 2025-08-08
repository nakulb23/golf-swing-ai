import Foundation
import UIKit

class APIService: NSObject, ObservableObject {
    static let shared = APIService()
    
    @Published var isOnline = false
    @Published var connectionType: String?
    @Published var lastHealthCheck: Date?
    
    // Custom URLSession that bypasses SSL validation for our server
    private var urlSession: URLSession!
    
    private override init() {
        super.init()
        
        // Initialize custom URLSession after super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        // Initialize API service
        print("🌐 APIService initialized")
        print("🌐 API Base URL: \(Constants.baseURL)")
        
        // Test connection on initialization
        Task {
            await testConnection()
            // Start periodic health checks
            await startPeriodicHealthChecks()
        }
    }
    
    // MARK: - Connection Testing
    func testConnection() async {
        do {
            let health = try await checkHealth()
            print("✅ API Connection successful: \(health.status)")
            await MainActor.run {
                self.isOnline = true
                self.lastHealthCheck = Date()
                // Determine connection type based on response
                if health.minimal == true {
                    self.connectionType = "Basic"
                } else if health.model_loaded == true {
                    self.connectionType = "Full AI"
                } else {
                    self.connectionType = "Connected"
                }
            }
        } catch {
            print("❌ API Connection failed: \(error)")
            print("🔍 Attempting to connect to: \(Constants.baseURL)")
            
            // Additional debugging information
            if let nsError = error as NSError? {
                print("🔍 Error domain: \(nsError.domain)")
                print("🔍 Error code: \(nsError.code)")
                print("🔍 Error description: \(nsError.localizedDescription)")
                
                // Check for SSL-specific errors
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorServerCertificateUntrusted:
                        print("🔍 SSL Error: Server certificate untrusted")
                    case NSURLErrorSecureConnectionFailed:
                        print("🔍 SSL Error: Secure connection failed")
                    case NSURLErrorServerCertificateHasBadDate:
                        print("🔍 SSL Error: Certificate has bad date")
                    case NSURLErrorServerCertificateNotYetValid:
                        print("🔍 SSL Error: Certificate not yet valid")
                    case NSURLErrorClientCertificateRequired:
                        print("🔍 SSL Error: Client certificate required")
                    default:
                        print("🔍 URL Error code: \(nsError.code)")
                    }
                }
            }
            
            await MainActor.run {
                self.isOnline = false
                self.lastHealthCheck = Date()
                self.connectionType = nil
            }
        }
    }
    
    // MARK: - Periodic Health Checks
    func startPeriodicHealthChecks() async {
        // Check every 30 seconds
        while true {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            await testConnection()
        }
    }
    
    // Manual retry for testing
    func retryConnection() async {
        print("🔄 Manually retrying connection...")
        await testConnection()
    }
    
    // MARK: - Health Check
    func checkHealth() async throws -> HealthResponse {
        let url = URL(string: "\(Constants.baseURL)\(Constants.API.health)")!
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
    
    // MARK: - CaddieChat
    func sendChatMessage(_ message: String) async throws -> ChatResponse {
        let urlString = "\(Constants.baseURL)\(Constants.API.chat)"
        print("🌐 Chat API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 30 second timeout
        
        let chatRequest = ChatRequest(question: message)
        
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("📤 Sending chat request: \(message)")
        } catch {
            print("❌ Failed to encode chat request: \(error)")
            throw APIError.decodingError
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw APIError.invalidResponse
            }
            
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Response: \(responseString)")
                throw APIError.invalidResponse
            }
            
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                print("✅ Chat response decoded successfully")
                return chatResponse
            } catch {
                print("❌ Failed to decode chat response: \(error)")
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Raw response: \(responseString)")
                throw APIError.decodingError
            }
            
        } catch {
            if error is APIError {
                throw error
            }
            print("❌ Network error: \(error)")
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Swing Analysis
    func analyzeSwing(videoData: Data) async throws -> SwingAnalysisResponse {
        let url = URL(string: "\(Constants.baseURL)/predict")!
        let boundary = UUID().uuidString
        
        print("🧠 Starting swing analysis...")
        print("📹 Video data size: \(videoData.count) bytes")
        print("🌐 POST URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout for video processing
        
        let httpBody = createMultipartBody(data: videoData, boundary: boundary, fieldName: "file", fileName: "swing_video.mp4", mimeType: "video/mp4")
        request.httpBody = httpBody
        
        print("📦 Multipart body size: \(httpBody.count) bytes")
        print("🔍 Content-Type: multipart/form-data; boundary=\(boundary)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw APIError.invalidResponse
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        print("📡 Response headers: \(httpResponse.allHeaderFields)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "No response data"
            print("❌ Response body: \(responseString)")
            
            if httpResponse.statusCode == 504 {
                throw APIError.serverTimeout
            }
            throw APIError.invalidResponse
        }
        
        // Log the raw response for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "No response data"
        print("📡 Raw response: \(responseString)")
        
        do {
            let result = try JSONDecoder().decode(SwingAnalysisResponse.self, from: data)
            print("✅ Successfully decoded SwingAnalysisResponse")
            return result
        } catch {
            print("❌ JSON decoding error: \(error)")
            print("❌ Raw data: \(responseString)")
            
            // Check if it's a server error response
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorDict["detail"] as? String {
                print("🔍 Server error detail: \(detail)")
                throw APIError.serverError(detail)
            }
            
            throw APIError.decodingError
        }
    }
    
    // MARK: - Camera Angle Detection (NEW - Multi-Angle Enhancement)
    func detectCameraAngle(videoData: Data) async throws -> CameraAngleResponse {
        let url = URL(string: "\(Constants.baseURL)/detect-camera-angle")!
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 1 minute timeout for angle detection (faster than full analysis)
        
        let httpBody = createMultipartBody(data: videoData, boundary: boundary, fieldName: "file", fileName: "angle_test.mp4", mimeType: "video/mp4")
        request.httpBody = httpBody
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 504 {
                throw APIError.serverTimeout
            }
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(CameraAngleResponse.self, from: data)
    }
    
    // MARK: - Ball Tracking
    func trackBall(videoData: Data) async throws -> BallTrackingResponse {
        let url = URL(string: "\(Constants.baseURL)/track-ball")!
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout for video processing
        
        let httpBody = createMultipartBody(data: videoData, boundary: boundary, fieldName: "file", fileName: "ball_video.mp4", mimeType: "video/mp4")
        request.httpBody = httpBody
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 504 {
                throw APIError.serverTimeout
            }
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(BallTrackingResponse.self, from: data)
    }
    
    // MARK: - Data Collection & Model Improvement
    func submitDataCollectionConsent(_ consent: DataCollectionConsent) async throws -> ModelImprovementResponse {
        let url = URL(string: "\(Constants.baseURL)/submit-consent")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        request.httpBody = try JSONEncoder().encode(consent)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(ModelImprovementResponse.self, from: data)
    }
    
    func submitAnonymousSwingData(_ swingData: AnonymousSwingData) async throws -> ModelImprovementResponse {
        let url = URL(string: "\(Constants.baseURL)/submit-swing-data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Longer timeout for data submission
        
        request.httpBody = try JSONEncoder().encode(swingData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(ModelImprovementResponse.self, from: data)
    }
    
    func submitUserFeedback(sessionId: String, feedback: UserFeedback) async throws -> ModelImprovementResponse {
        let url = URL(string: "\(Constants.baseURL)/submit-feedback")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let feedbackData = [
            "session_id": sessionId,
            "feedback": feedback
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: feedbackData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(ModelImprovementResponse.self, from: data)
    }
    
    func getDataContributionStats(userId: String) async throws -> DataContributionStats {
        let url = URL(string: "\(Constants.baseURL)/contribution-stats/\(userId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(DataContributionStats.self, from: data)
    }
    
    // MARK: - Helper Methods
    private func createMultipartBody(data: Data, boundary: String, fieldName: String, fileName: String, mimeType: String) -> Data {
        var body = Data()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    case serverTimeout
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration"
        case .invalidResponse:
            return "Invalid response from Golf Swing AI server"
        case .noData:
            return "No data received from server"
        case .decodingError:
            return "Failed to decode server response"
        case .serverTimeout:
            return "Server is starting up. Please try again in 30 seconds."
        case .networkError:
            return "Network connection error. Check your internet connection."
        case .serverError(let detail):
            return "Server error: \(detail)"
        }
    }
}

// MARK: - URLSessionDelegate for SSL Certificate Bypass

extension APIService: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Only bypass SSL for our specific server
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host == "golfai.duckdns.org" else {
            // Use default handling for other servers
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        print("🔐 Bypassing SSL certificate validation for: \(challenge.protectionSpace.host)")
        
        // Create credential with the server trust
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}