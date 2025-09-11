import Foundation
import UIKit
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Local-Only API Service
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    // Local AI components
    private let localAIManager = LocalAIManager.shared
    private let localSwingAnalyzer = LocalSwingAnalyzer()
    private let localBallTracker = LocalBallTracker()
    private let localCaddieChat = LocalCaddieChat()
    
    // Dynamic local golf AI with contextual responses
    private let dynamicGolfAI = DynamicGolfAI.shared
    
    private init() {
        print("📱 Local-only API Service initialized")
        print("📱 All analysis runs on-device for privacy and performance")
        print("🔒 No data is sent to external servers")
    }
    
    // MARK: - Swing Analysis (Local Only)
    func analyzeSwing(videoData: Data) async throws -> SwingAnalysisResponse {
        print("🏌️ Analyzing swing locally...")
        
        // Save video to temporary file for processing
        let tempURL = try saveVideoDataToTempFile(videoData)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return try await localSwingAnalyzer.analyzeSwing(from: tempURL)
    }
    
    func analyzeSwingFromURL(_ videoURL: URL) async throws -> SwingAnalysisResponse {
        print("🏌️ Analyzing swing from URL locally...")
        return try await localSwingAnalyzer.analyzeSwing(from: videoURL)
    }
    
    // MARK: - Ball Tracking (Local Only)
    func trackBall(videoData: Data) async throws -> BallTrackingResponse {
        print("🎾 Tracking ball locally...")
        
        // Save video to temporary file for processing
        let tempURL = try saveVideoDataToTempFile(videoData)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return try await localBallTracker.trackBall(from: tempURL)
    }
    
    func trackBallFromURL(_ videoURL: URL) async throws -> BallTrackingResponse {
        print("🎾 Tracking ball from URL locally...")
        return try await localBallTracker.trackBall(from: videoURL)
    }
    
    // MARK: - Caddie Chat (Dynamic AI with Context & Memory)
    func sendChatMessage(_ message: String) async throws -> ChatResponse {
        print("💬 Processing chat message with dynamic golf AI...")
        
        // Use dynamic local AI with contextual responses and memory
        return try await dynamicGolfAI.sendMessage(message)
    }
    
    // MARK: - Helper Methods
    private func saveVideoDataToTempFile(_ data: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_video_\(UUID().uuidString).mp4"
        let tempURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Error Handling
enum APIError: LocalizedError {
    case invalidResponse
    case noData
    case decodingFailed
    case videoSaveFailed
    case modelNotLoaded
    case analysisTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from local processing"
        case .noData:
            return "No data available for processing"
        case .decodingFailed:
            return "Failed to decode analysis results"
        case .videoSaveFailed:
            return "Failed to save video for processing"
        case .modelNotLoaded:
            return "AI model not loaded. Please restart the app."
        case .analysisTimeout:
            return "Analysis took too long. Please try again."
        }
    }
}


// MARK: - Analysis History Manager
@MainActor
class AnalysisHistoryManager: ObservableObject {
    static let shared = AnalysisHistoryManager()
    
    @Published var analysisHistory: [AnalysisHistoryEntry] = []
    
    private let maxHistoryCount = 50 // More storage for local-only
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let historyFileName = "analysis_history.json"
    
    private init() {
        loadHistory()
    }
    
    func addAnalysis(_ result: SwingAnalysisResponse, videoData: Data? = nil, thumbnail: Data? = nil) {
        let entry = AnalysisHistoryEntry(
            analysisResult: result,
            videoData: videoData,
            thumbnail: thumbnail
        )
        
        analysisHistory.insert(entry, at: 0)
        
        // Clean up old entries
        if analysisHistory.count > maxHistoryCount {
            let entriesToRemove = Array(analysisHistory.dropFirst(maxHistoryCount))
            for entry in entriesToRemove {
                deleteVideoFile(for: entry)
            }
            analysisHistory = Array(analysisHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    func deleteAnalysis(_ entry: AnalysisHistoryEntry) {
        deleteVideoFile(for: entry)
        analysisHistory.removeAll { $0.id == entry.id }
        saveHistory()
    }
    
    func clearHistory() {
        for entry in analysisHistory {
            deleteVideoFile(for: entry)
        }
        analysisHistory.removeAll()
        saveHistory()
    }
    
    private func loadHistory() {
        let historyURL = documentsDirectory.appendingPathComponent(historyFileName)
        
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([AnalysisHistoryEntry].self, from: data) else {
            return
        }
        
        analysisHistory = entries
    }
    
    private func saveHistory() {
        let historyURL = documentsDirectory.appendingPathComponent(historyFileName)
        
        guard let data = try? JSONEncoder().encode(analysisHistory) else { return }
        try? data.write(to: historyURL)
    }
    
    private func deleteVideoFile(for entry: AnalysisHistoryEntry) {
        guard let videoFileName = entry.videoFileName else { return }
        let videoURL = documentsDirectory.appendingPathComponent(videoFileName)
        try? FileManager.default.removeItem(at: videoURL)
    }
    
    nonisolated static func saveVideoToDocuments(videoData: Data, fileName: String) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try videoData.write(to: fileURL)
            return true
        } catch {
            print("❌ Failed to save video: \(error)")
            return false
        }
    }
}

// MARK: - Analysis History Entry
struct AnalysisHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let analysisResult: SwingAnalysisResponse
    let videoFileName: String?
    let thumbnail: Data?
    let isPermanentlySaved: Bool
    
    init(analysisResult: SwingAnalysisResponse, videoData: Data? = nil, thumbnail: Data? = nil, isPermanentlySaved: Bool = false) {
        self.id = UUID()
        self.date = Date()
        self.analysisResult = analysisResult
        self.thumbnail = thumbnail
        self.isPermanentlySaved = isPermanentlySaved
        
        // Save video data to local file if provided
        if let videoData = videoData {
            let fileName = "swing_\(self.id.uuidString).mp4"
            if AnalysisHistoryManager.saveVideoToDocuments(videoData: videoData, fileName: fileName) {
                self.videoFileName = fileName
            } else {
                self.videoFileName = nil
            }
        } else {
            self.videoFileName = nil
        }
    }
    
    var videoURL: URL? {
        guard let videoFileName = videoFileName else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsPath.appendingPathComponent(videoFileName)
        return FileManager.default.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    var videoData: Data? {
        guard let videoURL = videoURL else { return nil }
        return try? Data(contentsOf: videoURL)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

