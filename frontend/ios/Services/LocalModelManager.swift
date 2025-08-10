import Foundation
import CoreML

// MARK: - Local Model Manager

@MainActor
class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()
    
    @Published var availableModels: [ModelInfo] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading = false
    @Published var modelVersions: [String: String] = [:]
    
    private let fileManager = FileManager.default
    private let modelDirectory: URL
    
    private init() {
        // Create models directory in Documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        modelDirectory = documentsPath.appendingPathComponent("Models")
        
        createModelDirectory()
        loadInstalledModels()
    }
    
    // MARK: - Model Management
    
    func checkForModelUpdates() async {
        print("🔍 Checking for model updates...")
        
        do {
            let latestVersions = try await fetchLatestModelVersions()
            
            await MainActor.run {
                for model in self.availableModels {
                    if let latestVersion = latestVersions[model.id],
                       let currentVersion = self.modelVersions[model.id],
                       latestVersion != currentVersion {
                        // Update available
                        if var updatedModel = self.availableModels.first(where: { $0.id == model.id }) {
                            updatedModel.hasUpdate = true
                            updatedModel.latestVersion = latestVersion
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to check for updates: \(error)")
        }
    }
    
    func downloadModel(_ modelInfo: ModelInfo) async throws {
        print("📥 Downloading model: \(modelInfo.name)")
        
        await MainActor.run {
            self.isDownloading = true
            self.downloadProgress[modelInfo.id] = 0.0
        }
        
        defer {
            Task {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress.removeValue(forKey: modelInfo.id)
                }
            }
        }
        
        // Download model file
        let downloadURL = try await getModelDownloadURL(for: modelInfo)
        let localURL = modelDirectory.appendingPathComponent("\(modelInfo.id).mlmodel")
        
        // Simulate download with progress
        try await downloadWithProgress(from: downloadURL, to: localURL, modelId: modelInfo.id)
        
        // Verify model
        try await verifyModel(at: localURL)
        
        // Update installed models
        await MainActor.run {
            if let index = self.availableModels.firstIndex(where: { $0.id == modelInfo.id }) {
                self.availableModels[index].isInstalled = true
                self.availableModels[index].hasUpdate = false
            }
            self.modelVersions[modelInfo.id] = modelInfo.version
            self.saveModelMetadata()
        }
        
        print("✅ Model downloaded successfully: \(modelInfo.name)")
    }
    
    func deleteModel(_ modelInfo: ModelInfo) {
        let modelURL = modelDirectory.appendingPathComponent("\(modelInfo.id).mlmodel")
        
        do {
            try fileManager.removeItem(at: modelURL)
            
            if let index = availableModels.firstIndex(where: { $0.id == modelInfo.id }) {
                availableModels[index].isInstalled = false
            }
            modelVersions.removeValue(forKey: modelInfo.id)
            saveModelMetadata()
            
            print("🗑️ Deleted model: \(modelInfo.name)")
        } catch {
            print("❌ Failed to delete model: \(error)")
        }
    }
    
    func loadModel(id: String) -> MLModel? {
        let modelURL = modelDirectory.appendingPathComponent("\(id).mlmodel")
        
        guard fileManager.fileExists(atPath: modelURL.path) else {
            print("❌ Model file not found: \(id)")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            print("✅ Loaded model: \(id)")
            return model
        } catch {
            print("❌ Failed to load model \(id): \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func createModelDirectory() {
        do {
            try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            print("📁 Created models directory at: \(modelDirectory)")
        } catch {
            print("❌ Failed to create models directory: \(error)")
        }
    }
    
    private func loadInstalledModels() {
        // Initialize available models
        availableModels = [
            ModelInfo(
                id: "swing_analyzer",
                name: "Swing Analyzer",
                description: "AI model for golf swing analysis",
                version: "1.0",
                size: "15 MB",
                isInstalled: false
            ),
            ModelInfo(
                id: "ball_tracker",
                name: "Ball Tracker",
                description: "Computer vision model for ball tracking",
                version: "1.0",
                size: "25 MB",
                isInstalled: false
            ),
            ModelInfo(
                id: "pose_detector",
                name: "Pose Detector",
                description: "Human pose detection for swing analysis",
                version: "1.0",
                size: "40 MB",
                isInstalled: false
            )
        ]
        
        // Check which models are already installed
        for (index, model) in availableModels.enumerated() {
            let modelURL = modelDirectory.appendingPathComponent("\(model.id).mlmodel")
            availableModels[index].isInstalled = fileManager.fileExists(atPath: modelURL.path)
        }
        
        // Load metadata
        loadModelMetadata()
    }
    
    private func fetchLatestModelVersions() async throws -> [String: String] {
        // In a real implementation, this would fetch from your server
        // For now, return mock data
        return [
            "swing_analyzer": "1.1",
            "ball_tracker": "1.0",
            "pose_detector": "1.2"
        ]
    }
    
    private func getModelDownloadURL(for model: ModelInfo) async throws -> URL {
        // In a real implementation, this would get the download URL from your server
        // For now, return a placeholder URL
        guard let url = URL(string: "https://golfai.duckdns.org/models/\(model.id).mlmodel") else {
            throw ModelError.invalidURL
        }
        return url
    }
    
    private func downloadWithProgress(from remoteURL: URL, to localURL: URL, modelId: String) async throws {
        // Simulate download with progress updates
        for i in 0...100 {
            await MainActor.run {
                self.downloadProgress[modelId] = Double(i) / 100.0
            }
            
            // Simulate download time
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // In a real implementation, use URLSession with progress tracking
        // For now, create a placeholder file
        try "placeholder_model_data".write(to: localURL, atomically: true, encoding: .utf8)
    }
    
    private func verifyModel(at url: URL) async throws {
        // In a real implementation, verify the model integrity
        guard fileManager.fileExists(atPath: url.path) else {
            throw ModelError.verificationFailed
        }
        
        // Additional verification could include:
        // - File size check
        // - Checksum verification
        // - Model loading test
    }
    
    private func saveModelMetadata() {
        let metadataURL = modelDirectory.appendingPathComponent("metadata.json")
        
        do {
            let data = try JSONEncoder().encode(modelVersions)
            try data.write(to: metadataURL)
        } catch {
            print("❌ Failed to save model metadata: \(error)")
        }
    }
    
    private func loadModelMetadata() {
        let metadataURL = modelDirectory.appendingPathComponent("metadata.json")
        
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            modelVersions = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("❌ Failed to load model metadata: \(error)")
        }
    }
}

// MARK: - Model Info

struct ModelInfo: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let size: String
    var isInstalled: Bool
    var hasUpdate: Bool = false
    var latestVersion: String?
    
    var displayVersion: String {
        if hasUpdate, let latest = latestVersion {
            return "\(version) → \(latest)"
        }
        return version
    }
    
    var statusIcon: String {
        if hasUpdate {
            return "arrow.down.circle.fill"
        } else if isInstalled {
            return "checkmark.circle.fill"
        } else {
            return "circle"
        }
    }
    
    var statusColor: String {
        if hasUpdate {
            return "orange"
        } else if isInstalled {
            return "green"
        } else {
            return "gray"
        }
    }
}

// MARK: - Model Errors

enum ModelError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case verificationFailed
    case modelNotFound
    case loadingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model download URL"
        case .downloadFailed:
            return "Failed to download model"
        case .verificationFailed:
            return "Model verification failed"
        case .modelNotFound:
            return "Model file not found"
        case .loadingFailed:
            return "Failed to load model"
        }
    }
}

// MARK: - Model Settings View Integration

extension LocalModelManager {
    func getStorageUsed() -> String {
        let modelFiles = (try? fileManager.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        
        let totalSize = modelFiles.reduce(0) { total, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + fileSize
        }
        
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    func clearAllModels() {
        for model in availableModels where model.isInstalled {
            deleteModel(model)
        }
    }
}