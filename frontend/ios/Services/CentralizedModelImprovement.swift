import Foundation
import CoreML

// MARK: - Centralized Model Improvement System
@MainActor
class CentralizedModelImprovement: ObservableObject {
    static let shared = CentralizedModelImprovement()
    
    @Published var isDataCollectionEnabled = true
    @Published var pendingUploads = 0
    @Published var totalDataPoints = 0
    @Published var lastSyncDate: Date?
    
    private let apiService = APIService.shared
    private let userDefaults = UserDefaults.standard
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let pendingDataDirectory: URL
    
    // User consent and privacy settings
    @Published var hasUserConsent = false
    @Published var shareAllPredictions = true
    @Published var shareFeedbackData = true
    @Published var shareAnonymousMetadata = true
    
    private init() {
        pendingDataDirectory = documentsDirectory.appendingPathComponent("PendingModelData")
        createDirectories()
        loadSettings()
        loadPendingCount()
    }
    
    // MARK: - Data Collection (All Predictions)
    
    /// Collect ALL predictions for centralized model improvement
    func collectPredictionData(
        features: [Double],
        modelPrediction: String,
        modelConfidence: Double,
        userFeedback: UserFeedback? = nil,
        swingMetadata: SwingMetadata,
        isFromLocalModel: Bool = true
    ) {
        guard hasUserConsent && isDataCollectionEnabled else { return }
        
        let dataPoint = ModelTrainingDataPoint(
            id: UUID(),
            timestamp: Date(),
            features: features,
            modelPrediction: modelPrediction,
            modelConfidence: modelConfidence,
            userFeedback: userFeedback,
            swingMetadata: swingMetadata,
            isFromLocalModel: isFromLocalModel,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            modelVersion: "1.0-local"
        )
        
        // Store locally first (for offline capability)
        storeDataPointLocally(dataPoint)
        
        // Try to upload immediately if online
        Task {
            await uploadDataPoint(dataPoint)
        }
        
        totalDataPoints += 1
        print("📊 Collected prediction data: \(modelPrediction) (confidence: \(Int(modelConfidence * 100))%)")
    }
    
    /// Collect user feedback corrections for server-side learning
    func collectUserCorrection(
        originalPrediction: String,
        correctedLabel: String,
        userConfidence: Int,
        features: [Double],
        swingMetadata: SwingMetadata
    ) {
        guard hasUserConsent && shareFeedbackData else { return }
        
        let feedback = UserFeedback(
            isCorrect: false,
            correctedLabel: correctedLabel,
            confidence: userConfidence,
            comments: nil,
            submissionDate: Date()
        )
        
        collectPredictionData(
            features: features,
            modelPrediction: originalPrediction,
            modelConfidence: 0.0, // Unknown since this is a correction
            userFeedback: feedback,
            swingMetadata: swingMetadata,
            isFromLocalModel: true
        )
        
        print("🔧 User correction collected: \(originalPrediction) → \(correctedLabel)")
    }
    
    // MARK: - Server Communication
    
    /// Upload data point to server for centralized model training
    private func uploadDataPoint(_ dataPoint: ModelTrainingDataPoint) async {
        do {
            let response = try await apiService.uploadModelTrainingData(dataPoint)
            
            if response.success {
                // Remove from local storage after successful upload
                removeLocalDataPoint(dataPoint.id)
                await MainActor.run {
                    if pendingUploads > 0 {
                        pendingUploads -= 1
                    }
                    lastSyncDate = Date()
                }
                print("✅ Data point uploaded successfully")
            }
        } catch {
            print("⚠️ Failed to upload data point: \(error)")
            // Will retry later during sync
        }
    }
    
    /// Sync all pending data points to server
    func syncPendingData() async {
        let pendingPoints = loadPendingDataPoints()
        
        for dataPoint in pendingPoints {
            await uploadDataPoint(dataPoint)
            
            // Small delay to avoid overwhelming server
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        print("🔄 Sync completed: \(pendingPoints.count) data points processed")
    }
    
    /// Check for and download model updates from server
    func checkForModelUpdates() async {
        do {
            let updateInfo = try await apiService.checkForModelUpdates()
            
            if updateInfo.hasUpdate && updateInfo.modelVersion != getCurrentModelVersion() {
                print("🆕 New model available: \(updateInfo.modelVersion)")
                await downloadAndInstallModel(updateInfo)
            }
        } catch {
            print("⚠️ Failed to check for model updates: \(error)")
        }
    }
    
    private func downloadAndInstallModel(_ updateInfo: ModelUpdateInfo) async {
        do {
            print("⬇️ Downloading new model version \(updateInfo.modelVersion)...")
            
            let modelData = try await apiService.downloadModelUpdate(updateInfo.downloadURL)
            let modelURL = try await installModel(modelData, version: updateInfo.modelVersion)
            
            // Notify app to reload model
            NotificationCenter.default.post(
                name: NSNotification.Name("ModelUpdateAvailable"),
                object: modelURL
            )
            
            print("✅ Model updated successfully to version \(updateInfo.modelVersion)")
            
        } catch {
            print("❌ Failed to download/install model update: \(error)")
        }
    }
    
    // MARK: - Privacy and Consent Management
    
    func requestUserConsent() {
        // This would typically show a consent dialog
        // For now, we'll assume consent is given through settings
        hasUserConsent = shareAllPredictions || shareFeedbackData || shareAnonymousMetadata
        saveSettings()
    }
    
    func updateDataSharingPreferences(
        shareAll: Bool,
        shareFeedback: Bool,
        shareMetadata: Bool
    ) {
        shareAllPredictions = shareAll
        shareFeedbackData = shareFeedback
        shareAnonymousMetadata = shareMetadata
        hasUserConsent = shareAll || shareFeedback || shareMetadata
        
        saveSettings()
        
        if !hasUserConsent {
            // Clear any pending data if user withdraws consent
            clearPendingData()
        }
    }
    
    // MARK: - Local Storage Management
    
    private func createDirectories() {
        try? FileManager.default.createDirectory(at: pendingDataDirectory, withIntermediateDirectories: true)
    }
    
    private func storeDataPointLocally(_ dataPoint: ModelTrainingDataPoint) {
        let fileURL = pendingDataDirectory.appendingPathComponent("\(dataPoint.id.uuidString).json")
        
        do {
            let jsonData = try JSONEncoder().encode(dataPoint)
            try jsonData.write(to: fileURL)
            pendingUploads += 1
        } catch {
            print("❌ Failed to store data point locally: \(error)")
        }
    }
    
    private func loadPendingDataPoints() -> [ModelTrainingDataPoint] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: pendingDataDirectory, includingPropertiesForKeys: nil)
            
            var dataPoints: [ModelTrainingDataPoint] = []
            for fileURL in fileURLs {
                if let data = try? Data(contentsOf: fileURL),
                   let dataPoint = try? JSONDecoder().decode(ModelTrainingDataPoint.self, from: data) {
                    dataPoints.append(dataPoint)
                }
            }
            
            return dataPoints
        } catch {
            return []
        }
    }
    
    private func removeLocalDataPoint(_ id: UUID) {
        let fileURL = pendingDataDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func clearPendingData() {
        try? FileManager.default.removeItem(at: pendingDataDirectory)
        createDirectories()
        pendingUploads = 0
    }
    
    private func loadPendingCount() {
        pendingUploads = loadPendingDataPoints().count
        totalDataPoints = userDefaults.integer(forKey: "total_data_points")
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        hasUserConsent = userDefaults.bool(forKey: "model_improvement_consent")
        shareAllPredictions = userDefaults.bool(forKey: "share_all_predictions")
        shareFeedbackData = userDefaults.bool(forKey: "share_feedback_data")
        shareAnonymousMetadata = userDefaults.bool(forKey: "share_anonymous_metadata")
        
        if let syncDate = userDefaults.object(forKey: "last_sync_date") as? Date {
            lastSyncDate = syncDate
        }
    }
    
    private func saveSettings() {
        userDefaults.set(hasUserConsent, forKey: "model_improvement_consent")
        userDefaults.set(shareAllPredictions, forKey: "share_all_predictions")
        userDefaults.set(shareFeedbackData, forKey: "share_feedback_data")
        userDefaults.set(shareAnonymousMetadata, forKey: "share_anonymous_metadata")
        userDefaults.set(totalDataPoints, forKey: "total_data_points")
        
        if let syncDate = lastSyncDate {
            userDefaults.set(syncDate, forKey: "last_sync_date")
        }
    }
    
    // MARK: - Model Management
    
    private func getCurrentModelVersion() -> String {
        return userDefaults.string(forKey: "current_model_version") ?? "1.0-local"
    }
    
    private func installModel(_ modelData: Data, version: String) async throws -> URL {
        let modelsDirectory = documentsDirectory.appendingPathComponent("UpdatedModels")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        let modelURL = modelsDirectory.appendingPathComponent("SwingAnalysisModel_\(version).mlmodel")
        try modelData.write(to: modelURL)
        
        userDefaults.set(version, forKey: "current_model_version")
        
        return modelURL
    }
    
    // MARK: - Statistics
    
    func getCollectionStats() -> CentralizedCollectionStats {
        return CentralizedCollectionStats(
            totalCollected: totalDataPoints,
            pendingUploads: pendingUploads,
            lastSyncDate: lastSyncDate,
            consentGiven: hasUserConsent,
            sharingAllPredictions: shareAllPredictions,
            sharingFeedback: shareFeedbackData
        )
    }
}

// MARK: - API Service Extensions

extension APIService {
    
    /// Upload model training data to server
    func uploadModelTrainingData(_ dataPoint: ModelTrainingDataPoint) async throws -> UploadResponse {
        let url = URL(string: "\(baseURL)/api/model/training-data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(dataPoint)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(UploadResponse.self, from: data)
    }
    
    /// Check for available model updates
    func checkForModelUpdates() async throws -> ModelUpdateInfo {
        let url = URL(string: "\(baseURL)/api/model/updates")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ModelUpdateInfo.self, from: data)
    }
    
    /// Download model update
    func downloadModelUpdate(_ downloadURL: String) async throws -> Data {
        guard let url = URL(string: downloadURL) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

// MARK: - Data Structures

struct ModelTrainingDataPoint: Codable {
    let id: UUID
    let timestamp: Date
    let features: [Double] // 35 physics features
    let modelPrediction: String
    let modelConfidence: Double
    let userFeedback: UserFeedback?
    let swingMetadata: SwingMetadata
    let isFromLocalModel: Bool
    let appVersion: String
    let modelVersion: String
}

struct UploadResponse: Codable {
    let success: Bool
    let message: String
    let dataPointId: String?
}

struct ModelUpdateInfo: Codable {
    let hasUpdate: Bool
    let modelVersion: String
    let downloadURL: String
    let releaseNotes: String
    let isRequired: Bool
}

struct CentralizedCollectionStats {
    let totalCollected: Int
    let pendingUploads: Int
    let lastSyncDate: Date?
    let consentGiven: Bool
    let sharingAllPredictions: Bool
    let sharingFeedback: Bool
}

enum ModelImprovementError: Error, LocalizedError {
    case consentRequired
    case uploadFailed(String)
    case modelUpdateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "User consent required for data collection"
        case .uploadFailed(let message):
            return "Failed to upload data: \(message)"
        case .modelUpdateFailed(let message):
            return "Failed to update model: \(message)"
        }
    }
}