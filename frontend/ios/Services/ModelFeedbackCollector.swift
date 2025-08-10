import Foundation
import CoreML

// MARK: - Model Feedback Collection System
@MainActor
class ModelFeedbackCollector: ObservableObject {
    static let shared = ModelFeedbackCollector()
    
    @Published var feedbackEnabled = true
    @Published var collectedSamplesCount = 0
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let feedbackDirectory: URL
    private let maxStoredSamples = 1000
    
    private init() {
        feedbackDirectory = documentsDirectory.appendingPathComponent("ModelFeedback")
        createFeedbackDirectory()
        updateSampleCount()
    }
    
    // MARK: - Data Collection
    
    /// Collect analysis data with user feedback for model improvement
    func collectAnalysisData(
        features: [Double],
        modelPrediction: String,
        modelConfidence: Double,
        userFeedback: UserFeedback,
        swingMetadata: SwingMetadata?
    ) {
        guard feedbackEnabled else { return }
        
        let sample = TrainingSample(
            id: UUID(),
            timestamp: Date(),
            features: features,
            modelPrediction: modelPrediction,
            modelConfidence: modelConfidence,
            userFeedback: userFeedback,
            swingMetadata: swingMetadata
        )
        
        saveSample(sample)
        updateSampleCount()
        
        print("📊 Collected training sample: \(userFeedback.correctedLabel ?? modelPrediction)")
    }
    
    /// Collect uncertain predictions for manual review
    func collectUncertainPrediction(
        features: [Double],
        modelPrediction: String,
        modelConfidence: Double,
        swingMetadata: SwingMetadata?
    ) {
        guard modelConfidence < 0.7 else { return } // Only collect low-confidence predictions
        
        let sample = UncertainSample(
            id: UUID(),
            timestamp: Date(),
            features: features,
            modelPrediction: modelPrediction,
            modelConfidence: modelConfidence,
            swingMetadata: swingMetadata
        )
        
        saveUncertainSample(sample)
        print("🤔 Collected uncertain prediction for review: \(modelPrediction) (\(String(format: "%.1f", modelConfidence * 100))%)")
    }
    
    // MARK: - User Feedback Interface
    
    func promptForFeedback(
        prediction: String,
        confidence: Double,
        completion: @escaping (UserFeedback?) -> Void
    ) {
        // This would typically trigger a UI component
        // For now, we'll simulate different feedback scenarios
        
        if confidence < 0.6 {
            // Low confidence - always ask for feedback
            print("🤖 Low confidence prediction (\(String(format: "%.1f", confidence * 100))%) - requesting user feedback")
            // Trigger feedback UI
        } else if confidence < 0.8 && Bool.random() {
            // Medium confidence - occasionally ask for feedback
            print("🤖 Medium confidence prediction - randomly requesting feedback")
            // Trigger feedback UI
        }
        
        // For demonstration, return nil (no feedback provided)
        completion(nil)
    }
    
    // MARK: - Data Export for Model Training
    
    /// Export collected data in format suitable for model retraining
    func exportTrainingData() -> URL? {
        let exportURL = documentsDirectory.appendingPathComponent("training_export_\(Date().timeIntervalSince1970).json")
        
        guard let samples = loadAllSamples() else { return nil }
        
        let exportData = TrainingDataExport(
            exportDate: Date(),
            sampleCount: samples.count,
            samples: samples,
            featureNames: ModelFeatureExtractor.featureNames,
            appVersion: Constants.appVersion
        )
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            try jsonData.write(to: exportURL)
            
            print("📤 Exported \(samples.count) training samples to \(exportURL.lastPathComponent)")
            return exportURL
        } catch {
            print("❌ Failed to export training data: \(error)")
            return nil
        }
    }
    
    /// Get anonymized statistics about collected data
    func getCollectionStats() -> CollectionStats {
        guard let samples = loadAllSamples() else {
            return CollectionStats(totalSamples: 0, feedbackSamples: 0, uncertainSamples: 0, classDistribution: [:])
        }
        
        let feedbackCount = samples.filter { $0.userFeedback != nil }.count
        let uncertainCount = loadUncertainSamples()?.count ?? 0
        
        var classDistribution: [String: Int] = [:]
        for sample in samples {
            let label = sample.userFeedback?.correctedLabel ?? sample.modelPrediction
            classDistribution[label, default: 0] += 1
        }
        
        return CollectionStats(
            totalSamples: samples.count,
            feedbackSamples: feedbackCount,
            uncertainSamples: uncertainCount,
            classDistribution: classDistribution
        )
    }
    
    // MARK: - Privacy Controls
    
    func clearAllData() {
        try? FileManager.default.removeItem(at: feedbackDirectory)
        createFeedbackDirectory()
        updateSampleCount()
        print("🗑️ Cleared all feedback data")
    }
    
    func enableDataCollection(_ enabled: Bool) {
        feedbackEnabled = enabled
        print("📊 Data collection \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    private func createFeedbackDirectory() {
        try? FileManager.default.createDirectory(at: feedbackDirectory, withIntermediateDirectories: true)
    }
    
    private func saveSample(_ sample: TrainingSample) {
        let sampleURL = feedbackDirectory.appendingPathComponent("sample_\(sample.id.uuidString).json")
        
        do {
            let jsonData = try JSONEncoder().encode(sample)
            try jsonData.write(to: sampleURL)
        } catch {
            print("❌ Failed to save training sample: \(error)")
        }
    }
    
    private func saveUncertainSample(_ sample: UncertainSample) {
        let sampleURL = feedbackDirectory.appendingPathComponent("uncertain_\(sample.id.uuidString).json")
        
        do {
            let jsonData = try JSONEncoder().encode(sample)
            try jsonData.write(to: sampleURL)
        } catch {
            print("❌ Failed to save uncertain sample: \(error)")
        }
    }
    
    private func loadAllSamples() -> [TrainingSample]? {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: feedbackDirectory, includingPropertiesForKeys: nil)
            let sampleFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix("sample_") }
            
            var samples: [TrainingSample] = []
            for fileURL in sampleFiles {
                if let data = try? Data(contentsOf: fileURL),
                   let sample = try? JSONDecoder().decode(TrainingSample.self, from: data) {
                    samples.append(sample)
                }
            }
            
            return samples
        } catch {
            print("❌ Failed to load samples: \(error)")
            return nil
        }
    }
    
    private func loadUncertainSamples() -> [UncertainSample]? {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: feedbackDirectory, includingPropertiesForKeys: nil)
            let uncertainFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix("uncertain_") }
            
            var samples: [UncertainSample] = []
            for fileURL in uncertainFiles {
                if let data = try? Data(contentsOf: fileURL),
                   let sample = try? JSONDecoder().decode(UncertainSample.self, from: data) {
                    samples.append(sample)
                }
            }
            
            return samples
        } catch {
            return nil
        }
    }
    
    private func updateSampleCount() {
        collectedSamplesCount = loadAllSamples()?.count ?? 0
    }
}

// MARK: - Data Structures

struct TrainingSample: Codable {
    let id: UUID
    let timestamp: Date
    let features: [Double] // 35 physics features
    let modelPrediction: String
    let modelConfidence: Double
    let userFeedback: UserFeedback?
    let swingMetadata: SwingMetadata?
}

struct UncertainSample: Codable {
    let id: UUID
    let timestamp: Date
    let features: [Double]
    let modelPrediction: String
    let modelConfidence: Double
    let swingMetadata: SwingMetadata?
}

struct UserFeedback: Codable {
    let isCorrect: Bool
    let correctedLabel: String?
    let confidence: Int // 1-5 scale
    let comments: String?
    let submissionDate: Date
}

struct SwingMetadata: Codable {
    let videoDuration: TimeInterval?
    let deviceModel: String?
    let appVersion: String
    let analysisDate: Date
    let userSkillLevel: String? // "beginner", "intermediate", "advanced", "pro"
    let clubType: String? // "driver", "iron", "wedge", etc.
    let practiceOrRound: String? // "practice", "course"
}

struct TrainingDataExport: Codable {
    let exportDate: Date
    let sampleCount: Int
    let samples: [TrainingSample]
    let featureNames: [String]
    let appVersion: String
}

struct CollectionStats {
    let totalSamples: Int
    let feedbackSamples: Int
    let uncertainSamples: Int
    let classDistribution: [String: Int]
}

// MARK: - Model Feature Extractor Helper

struct ModelFeatureExtractor {
    static let featureNames = [
        "spine_angle", "knee_flexion", "weight_distribution", "arm_hang_angle", "stance_width",
        "max_shoulder_turn", "hip_turn_at_top", "x_factor", "swing_plane_angle", "arm_extension",
        "weight_shift", "wrist_hinge", "backswing_tempo", "head_movement", "knee_stability",
        "transition_tempo", "hip_lead", "weight_transfer_rate", "wrist_timing", "sequence_efficiency",
        "hip_rotation_speed", "shoulder_rotation_speed", "club_path_angle", "attack_angle",
        "release_timing", "left_side_stability", "downswing_tempo", "power_generation",
        "impact_position", "extension_through_impact", "follow_through_balance", "finish_quality",
        "overall_tempo", "rhythm_consistency", "swing_efficiency"
    ]
}