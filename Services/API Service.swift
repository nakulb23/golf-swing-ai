import Foundation
import UIKit

class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var isOnline = true
    @Published var connectionType: String?
    
    private init() {
        // Initialize API service
        print("🌐 APIService initialized")
    }
    
    // MARK: - Health Check
    func checkHealth() async throws -> HealthResponse {
        let url = URL(string: "\(Constants.baseURL)\(Constants.API.health)")!
        let (data, _) = try await URLSession.shared.data(from: url)
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout for video processing
        
        let httpBody = createMultipartBody(data: videoData, boundary: boundary, fieldName: "file", fileName: "swing_video.mp4", mimeType: "video/mp4")
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 504 {
                throw APIError.serverTimeout
            }
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(SwingAnalysisResponse.self, from: data)
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        }
    }
}