import Foundation
import CoreML
import Accelerate

// MARK: - Core ML Model Input
/// Input features for the swing analysis model
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class SwingAnalysisModelInput: MLFeatureProvider {
    /// 35 physics-based features extracted from pose data
    var physics_features: MLMultiArray
    
    var featureNames: Set<String> {
        return ["physics_features"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "physics_features" {
            return MLFeatureValue(multiArray: physics_features)
        }
        return nil
    }
    
    init(physics_features: MLMultiArray) {
        self.physics_features = physics_features
    }
    
    convenience init(features: [Double]) throws {
        guard features.count == 35 else {
            throw SwingAnalysisError.invalidFeatureCount
        }
        
        guard let multiArray = try? MLMultiArray(shape: [35], dataType: .double) else {
            throw SwingAnalysisError.modelInputCreationFailed
        }
        
        for (index, feature) in features.enumerated() {
            multiArray[index] = NSNumber(value: feature)
        }
        
        self.init(physics_features: multiArray)
    }
}

// MARK: - Core ML Model Output
/// Output from the swing analysis model
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class SwingAnalysisModelOutput: MLFeatureProvider {
    /// Predicted swing classification
    let classLabel: String
    
    /// Probability distribution over swing types
    let classLabelProbs: [String: Double]
    
    var featureNames: Set<String> {
        return ["classLabel", "classLabelProbs"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "classLabel" {
            return MLFeatureValue(string: classLabel)
        }
        if featureName == "classLabelProbs" {
            return MLFeatureValue(dictionary: classLabelProbs as NSDictionary)
        }
        return nil
    }
    
    init(classLabel: String, classLabelProbs: [String: Double]) {
        self.classLabel = classLabel
        self.classLabelProbs = classLabelProbs
    }
    
    init(features: MLFeatureProvider) throws {
        guard let classLabel = features.featureValue(for: "classLabel")?.stringValue else {
            throw SwingAnalysisError.invalidModelOutput
        }
        
        guard let classLabelProbs = features.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] else {
            throw SwingAnalysisError.invalidModelOutput
        }
        
        self.classLabel = classLabel
        self.classLabelProbs = classLabelProbs
    }
}

// MARK: - Swing Analysis Model Wrapper
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class SwingAnalysisModel {
    private let model: MLModel
    
    /// Feature normalization parameters
    private let featureScaler: FeatureScaler
    
    /// Model metadata
    let featureNames = [
        "spine_angle", "knee_flexion", "weight_distribution", "arm_hang_angle", "stance_width",
        "max_shoulder_turn", "hip_turn_at_top", "x_factor", "swing_plane_angle", "arm_extension",
        "weight_shift", "wrist_hinge", "backswing_tempo", "head_movement", "knee_stability",
        "transition_tempo", "hip_lead", "weight_transfer_rate", "wrist_timing", "sequence_efficiency",
        "hip_rotation_speed", "shoulder_rotation_speed", "club_path_angle", "attack_angle",
        "release_timing", "left_side_stability", "downswing_tempo", "power_generation",
        "impact_position", "extension_through_impact", "follow_through_balance", "finish_quality",
        "overall_tempo", "rhythm_consistency", "swing_efficiency"
    ]
    
    let classNames = ["good_swing", "too_steep", "too_flat"]
    
    init(model: MLModel, scalerPath: String? = nil) {
        self.model = model
        self.featureScaler = FeatureScaler(jsonPath: scalerPath)
    }
    
    /// Load model from bundle
    static func loadFromBundle() throws -> SwingAnalysisModel {
        guard let modelURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlmodelc") else {
            throw SwingAnalysisError.modelNotFound
        }
        
        let model = try MLModel(contentsOf: modelURL)
        
        // Load scaler if available
        let scalerPath = Bundle.main.path(forResource: "scaler_metadata", ofType: "json")
        
        return SwingAnalysisModel(model: model, scalerPath: scalerPath)
    }
    
    /// Predict swing type from features
    func predict(features: [Double]) throws -> SwingAnalysisModelOutput {
        // Normalize features
        let normalizedFeatures = featureScaler.normalize(features)
        
        // Create input
        let input = try SwingAnalysisModelInput(features: normalizedFeatures)
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Parse output
        return try SwingAnalysisModelOutput(features: output)
    }
    
    /// Batch prediction for multiple swings
    func predict(batchFeatures: [[Double]]) throws -> [SwingAnalysisModelOutput] {
        var results: [SwingAnalysisModelOutput] = []
        
        for features in batchFeatures {
            let result = try predict(features: features)
            results.append(result)
        }
        
        return results
    }
}

// MARK: - Feature Scaler
struct FeatureScaler {
    private let mean: [Double]
    private let scale: [Double]
    
    init(jsonPath: String? = nil) {
        if let path = jsonPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let meanArray = json["mean"] as? [Double],
           let scaleArray = json["scale"] as? [Double] {
            self.mean = meanArray
            self.scale = scaleArray
        } else {
            // Default normalization parameters
            self.mean = Array(repeating: 50.0, count: 35)
            self.scale = Array(repeating: 10.0, count: 35)
        }
    }
    
    func normalize(_ features: [Double]) -> [Double] {
        guard features.count == 35 else { return features }
        
        var normalized = [Double]()
        for i in 0..<35 {
            let value = (features[i] - mean[i]) / scale[i]
            normalized.append(value)
        }
        return normalized
    }
}

// MARK: - Errors
enum SwingAnalysisError: LocalizedError {
    case modelNotFound
    case modelLoadingFailed
    case invalidFeatureCount
    case modelInputCreationFailed
    case invalidModelOutput
    case predictionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Core ML model not found in bundle"
        case .modelLoadingFailed:
            return "Failed to load Core ML model"
        case .invalidFeatureCount:
            return "Expected 35 features for swing analysis"
        case .modelInputCreationFailed:
            return "Failed to create model input"
        case .invalidModelOutput:
            return "Invalid model output format"
        case .predictionFailed:
            return "Model prediction failed"
        }
    }
}