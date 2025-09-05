import Foundation
import CoreML
import CreateML

// MARK: - Model Retraining Pipeline
@MainActor
class ModelRetrainingPipeline: ObservableObject {
    static let shared = ModelRetrainingPipeline()
    
    @Published var isRetraining = false
    @Published var retrainingProgress: Double = 0.0
    @Published var lastRetrainingDate: Date?
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let modelsDirectory: URL
    
    private init() {
        modelsDirectory = documentsDirectory.appendingPathComponent("RetainedModels")
        createDirectories()
        loadLastRetrainingDate()
    }
    
    // MARK: - Model Retraining
    
    /// Process exported training data and retrain the model
    func processExportedData(_ exportURL: URL) async throws {
        print("🔄 Starting model retraining pipeline...")
        
        isRetraining = true
        retrainingProgress = 0.0
        
        do {
            // Step 1: Load and validate exported data (20%)
            let exportData = try await loadExportedData(exportURL)
            await updateProgress(0.2)
            
            // Step 2: Prepare training data (40%)
            let (features, labels) = try await prepareTrainingData(exportData)
            await updateProgress(0.4)
            
            // Step 3: Create and train model (80%)
            let newModel = try await retrainModel(features: features, labels: labels)
            await updateProgress(0.8)
            
            // Step 4: Save and validate model (100%)
            try await saveRetrainedModel(newModel)
            await updateProgress(1.0)
            
            lastRetrainingDate = Date()
            saveLastRetrainingDate()
            
            print("✅ Model retraining completed successfully!")
            
        } catch {
            print("❌ Model retraining failed: \(error)")
            throw RetrainingError.retrainingFailed(error.localizedDescription)
        }
        
        isRetraining = false
    }
    
    /// Get recommendations for model improvement based on collected data
    func getImprovementRecommendations() async -> [ModelImprovementRecommendation] {
        let stats = ModelFeedbackCollector.shared.getCollectionStats()
        var recommendations: [ModelImprovementRecommendation] = []
        
        // Analyze collected data patterns
        if stats.totalSamples < 100 {
            recommendations.append(ModelImprovementRecommendation(
                type: .dataCollection,
                priority: .high,
                title: "Collect More Training Data",
                description: "You have \(stats.totalSamples) samples. Collecting 100+ samples will significantly improve model accuracy.",
                actionRequired: "Continue using the app and providing feedback on predictions."
            ))
        }
        
        if stats.feedbackSamples < stats.totalSamples / 2 {
            recommendations.append(ModelImprovementRecommendation(
                type: .feedbackQuality,
                priority: .medium,
                title: "Increase Feedback Rate",
                description: "Only \(Int(Double(stats.feedbackSamples) / Double(stats.totalSamples) * 100))% of predictions have user feedback.",
                actionRequired: "Provide feedback when prompted to help the AI learn from mistakes."
            ))
        }
        
        // Check class distribution balance
        let classDistribution = stats.classDistribution
        if !classDistribution.isEmpty {
            let maxCount = classDistribution.values.max() ?? 0
            let minCount = classDistribution.values.min() ?? 0
            
            if maxCount > minCount * 3 { // Imbalanced if one class has 3x more samples
                recommendations.append(ModelImprovementRecommendation(
                    type: .classBalance,
                    priority: .medium,
                    title: "Improve Class Balance",
                    description: "Some swing types have significantly more data than others.",
                    actionRequired: "Try recording different types of swings to balance the training data."
                ))
            }
        }
        
        if stats.uncertainSamples > stats.totalSamples / 4 {
            recommendations.append(ModelImprovementRecommendation(
                type: .modelConfidence,
                priority: .high,
                title: "High Uncertainty Rate",
                description: "\(stats.uncertainSamples) predictions had low confidence. Model needs retraining.",
                actionRequired: "Consider retraining the model with collected feedback data."
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    private func createDirectories() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    private func loadExportedData(_ url: URL) async throws -> TrainingDataExport {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TrainingDataExport.self, from: data)
    }
    
    private func prepareTrainingData(_ exportData: TrainingDataExport) async throws -> (MLDataTable, MLDataTable) {
        // Convert training samples to CreateML format
        var featuresData: [[String: Double]] = []
        var labelsData: [[String: String]] = []
        
        for sample in exportData.samples {
            // Use corrected labels if available, otherwise use model prediction
            let label = sample.userFeedback?.correctedLabel ?? sample.modelPrediction
            
            // Create feature dictionary
            var featureDict: [String: Double] = [:]
            for (index, value) in sample.features.enumerated() {
                if index < exportData.featureNames.count {
                    featureDict[exportData.featureNames[index]] = value
                }
            }
            
            featuresData.append(featureDict)
            labelsData.append(["label": label])
        }
        
        let featuresTable = try MLDataTable(dictionary: featuresData)
        let labelsTable = try MLDataTable(dictionary: labelsData)
        
        return (featuresTable, labelsTable)
    }
    
    private func retrainModel(features: MLDataTable, labels: MLDataTable) async throws -> MLClassifier {
        // Combine features and labels
        let trainingData = try features.adding(contentsOf: labels)
        
        // Create classifier with improved parameters
        let classifier = try MLClassifier(
            trainingData: trainingData,
            targetColumn: "label",
            featureColumns: ModelFeatureExtractor.featureNames
        )
        
        return classifier
    }
    
    private func saveRetrainedModel(_ model: MLClassifier) async throws {
        let modelURL = modelsDirectory.appendingPathComponent("SwingAnalysisModel_retrained_\(Date().timeIntervalSince1970).mlmodel")
        
        try model.write(to: modelURL)
        
        // Create metadata file
        let metadata = RetrainedModelMetadata(
            originalModelVersion: "1.0-local",
            retrainedDate: Date(),
            trainingSampleCount: ModelFeedbackCollector.shared.getCollectionStats().totalSamples,
            feedbackSampleCount: ModelFeedbackCollector.shared.getCollectionStats().feedbackSamples,
            modelPath: modelURL.lastPathComponent
        )
        
        let metadataURL = modelsDirectory.appendingPathComponent("retrained_metadata.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL)
        
        print("📄 Saved retrained model to: \(modelURL.lastPathComponent)")
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.retrainingProgress = progress
        }
    }
    
    private func loadLastRetrainingDate() {
        if let date = UserDefaults.standard.object(forKey: "last_retraining_date") as? Date {
            lastRetrainingDate = date
        }
    }
    
    private func saveLastRetrainingDate() {
        UserDefaults.standard.set(lastRetrainingDate, forKey: "last_retraining_date")
    }
    
    // MARK: - Model Management
    
    func getAvailableRetrainedModels() -> [RetrainedModelInfo] {
        guard let metadataURL = try? modelsDirectory.appendingPathComponent("retrained_metadata.json"),
              let metadataData = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(RetrainedModelMetadata.self, from: metadataData) else {
            return []
        }
        
        let modelURL = modelsDirectory.appendingPathComponent(metadata.modelPath)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return []
        }
        
        return [RetrainedModelInfo(
            id: metadata.modelPath,
            retrainedDate: metadata.retrainedDate,
            trainingSampleCount: metadata.trainingSampleCount,
            feedbackSampleCount: metadata.feedbackSampleCount,
            modelPath: modelURL,
            isActive: false // Would need to track which model is currently loaded
        )]
    }
}

// MARK: - Supporting Types

struct ModelImprovementRecommendation {
    let type: RecommendationType
    let priority: Priority
    let title: String
    let description: String
    let actionRequired: String
    
    enum RecommendationType {
        case dataCollection
        case feedbackQuality
        case classBalance
        case modelConfidence
    }
    
    enum Priority {
        case high
        case medium
        case low
        
        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "blue"
            }
        }
    }
}

struct RetrainedModelMetadata: Codable {
    let originalModelVersion: String
    let retrainedDate: Date
    let trainingSampleCount: Int
    let feedbackSampleCount: Int
    let modelPath: String
}

struct RetrainedModelInfo {
    let id: String
    let retrainedDate: Date
    let trainingSampleCount: Int
    let feedbackSampleCount: Int
    let modelPath: URL
    let isActive: Bool
}

enum RetrainingError: Error, LocalizedError {
    case retrainingFailed(String)
    case insufficientData
    case modelSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .retrainingFailed(let message):
            return "Model retraining failed: \(message)"
        case .insufficientData:
            return "Insufficient training data for retraining"
        case .modelSaveFailed:
            return "Failed to save retrained model"
        }
    }
}