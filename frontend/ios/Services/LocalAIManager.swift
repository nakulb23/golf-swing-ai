import Foundation
import CoreML
import Vision
import AVFoundation
import Accelerate
import CoreImage

// MARK: - Local AI Manager

@MainActor
class LocalAIManager: ObservableObject {
    nonisolated static let shared = LocalAIManager()
    
    @Published var isModelsLoaded = false
    @Published var loadingProgress: Double = 0.0
    @Published var currentMode: AnalysisMode = .automatic
    
    // Core ML models (placeholders for now - will be replaced with actual models)
    private var swingAnalysisModel: VNCoreMLModel?
    private var ballTrackingModel: VNCoreMLModel?
    
    // Model configurations
    private let swingInputSize = CGSize(width: 224, height: 224)
    private let ballInputSize = CGSize(width: 416, height: 416)
    
    private init() {
        loadModels()
    }
    
    // MARK: - Model Loading
    
    private func loadModels() {
        Task {
            await MainActor.run {
                self.loadingProgress = 0.0
            }
            
            // Load swing analysis model
            if let swingModel = await loadSwingAnalysisModel() {
                self.swingAnalysisModel = swingModel
                await MainActor.run {
                    self.loadingProgress = 0.33
                }
            }
            
            // Load ball tracking model
            if let ballModel = await loadBallTrackingModel() {
                self.ballTrackingModel = ballModel
                await MainActor.run {
                    self.loadingProgress = 0.66
                }
            }
            
            // Models loaded
            await MainActor.run {
                self.loadingProgress = 1.0
                self.isModelsLoaded = true
            }
            
            print("✅ Local AI models loaded successfully")
        }
    }
    
    private func loadSwingAnalysisModel() async -> VNCoreMLModel? {
        print("📱 Loading swing analysis model...")
        
        // Load the actual Core ML model
        guard let modelPath = Bundle.main.path(forResource: "SwingAnalysisModel", ofType: "mlmodel") else {
            print("❌ SwingAnalysisModel.mlmodel not found in bundle")
            return nil
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ Successfully loaded SwingAnalysisModel")
            return vnModel
        } catch {
            print("❌ Failed to load SwingAnalysisModel: \(error)")
            return nil
        }
    }
    
    private func loadBallTrackingModel() async -> VNCoreMLModel? {
        print("📱 Loading ball tracking model...")
        
        // Load the actual Core ML model
        guard let modelPath = Bundle.main.path(forResource: "BallTrackingModel", ofType: "mlmodel") else {
            print("❌ BallTrackingModel.mlmodel not found in bundle")
            return nil
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ Successfully loaded BallTrackingModel")
            return vnModel
        } catch {
            print("❌ Failed to load BallTrackingModel: \(error)")
            return nil
        }
    }
}

// MARK: - Analysis Mode

enum AnalysisMode: String, CaseIterable {
    case local = "Local (Offline)"
    case cloud = "Cloud (Full Features)"
    case automatic = "Automatic"
    
    var description: String {
        switch self {
        case .local:
            return "Fast, private analysis on your device"
        case .cloud:
            return "Advanced analysis with latest AI models"
        case .automatic:
            return "Automatically choose best option"
        }
    }
    
    var icon: String {
        switch self {
        case .local:
            return "iphone"
        case .cloud:
            return "icloud"
        case .automatic:
            return "sparkles"
        }
    }
}

// MARK: - Local Swing Analyzer

class LocalSwingAnalyzer: ObservableObject {
    private let poseDetector = MediaPipePoseDetector()
    private let featureExtractor = SwingFeatureExtractor()
    private let modelManager = LocalModelManager.shared
    private var swingAnalysisModel: MLModel?
    private var currentPrediction: PredictionForFeedback?
    
    @Published var shouldShowFeedbackPrompt = false
    
    init() {
        loadModels()
    }
    
    private func loadModels() {
        Task {
            await loadSwingAnalysisModel()
        }
    }
    
    private func loadSwingAnalysisModel() async {
        guard let modelPath = Bundle.main.path(forResource: "SwingAnalysisModel", ofType: "mlmodel") else {
            print("❌ SwingAnalysisModel.mlmodel not found in bundle")
            return
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        
        do {
            swingAnalysisModel = try MLModel(contentsOf: modelURL)
            print("✅ LocalSwingAnalyzer: Core ML model loaded")
        } catch {
            print("❌ Failed to load SwingAnalysisModel in LocalSwingAnalyzer: \(error)")
        }
    }
    
    func analyzeSwing(from videoURL: URL) async throws -> SwingAnalysisResponse {
        print("🏌️ Starting local swing analysis...")
        
        // Extract frames from video
        let frames = try await extractFrames(from: videoURL)
        print("📹 Extracted \(frames.count) frames")
        
        // Detect poses using MediaPipe
        let mediaPipePoses = try await poseDetector.detectPoseSequence(from: videoURL)
        let poses = mediaPipePoses.map { $0.asPoseData }
        print("🦴 MediaPipe detected poses in \(poses.count) frames")
        
        // Extract physics-based features
        let features = featureExtractor.extractFeatures(from: poses)
        print("📊 Extracted \(features.count) physics features")
        
        // Run inference (simplified for now)
        let prediction = try await runInference(features: features)
        
        // Create response
        return createLocalResponse(prediction: prediction, features: features)
    }
    
    private func extractFrames(from videoURL: URL) async throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let frameRate = 30.0 // Process at 30 FPS
        
        var frames: [UIImage] = []
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let totalSeconds = CMTimeGetSeconds(duration)
        let frameCount = Int(totalSeconds * frameRate)
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / frameRate, preferredTimescale: 600)
            
            do {
                let cgImage = try await generator.image(at: time).image
                let image = UIImage(cgImage: cgImage)
                frames.append(image)
            } catch {
                print("⚠️ Failed to extract frame at \(i): \(error)")
            }
        }
        
        return frames
    }
    
    private func detectPoses(in frames: [UIImage]) async throws -> [PoseData] {
        var poses: [PoseData] = []
        
        for (index, frame) in frames.enumerated() {
            if let pose = try await poseDetector.detectPose(in: frame) {
                poses.append(pose)
            }
        }
        
        return poses
    }
    
    private func runInference(features: [Double]) async throws -> SwingPrediction {
        guard let model = swingAnalysisModel else {
            throw LocalAnalysisError.modelNotLoaded
        }
        
        print("🤖 Running Core ML inference with \(features.count) features")
        
        // Normalize features using scaler metadata
        let normalizedFeatures = normalizeFeatures(features)
        
        // Prepare input for Core ML model
        guard let inputArray = try? MLMultiArray(shape: [1, 35], dataType: .double) else {
            throw LocalAnalysisError.inputPreparationFailed
        }
        
        // Fill the input array with normalized features
        for (index, feature) in normalizedFeatures.enumerated() {
            guard index < 35 else { break }
            inputArray[index] = NSNumber(value: feature)
        }
        
        // Create model input
        let modelInput = SwingAnalysisModelInput(physics_features: inputArray)
        
        // Run prediction
        do {
            let prediction = try model.prediction(from: modelInput)
            
            // Process the output
            let outputArray = prediction.featureValue(for: "var_16")?.multiArrayValue
            let probabilities = extractProbabilities(from: outputArray)
            
            let (predictedClass, maxConfidence) = findMaxProbability(probabilities)
            let planeAngle = features.count > 0 ? features[0] : 45.0
            let tempo = features.count > 1 ? features[1] : 3.0
            
            print("✅ Core ML prediction: \(predictedClass) (confidence: \(maxConfidence))")
            
            let swingPrediction = SwingPrediction(
                label: predictedClass,
                confidence: maxConfidence,
                planeAngle: planeAngle,
                tempo: tempo
            )
            
            // Collect ALL predictions for centralized model improvement
            Task { @MainActor in
                CentralizedModelImprovement.shared.collectPredictionData(
                    features: features,
                    modelPrediction: predictedClass,
                    modelConfidence: maxConfidence,
                    userFeedback: nil, // No feedback yet - just the prediction
                    swingMetadata: createSwingMetadata(),
                    isFromLocalModel: true
                )
                
                // Also collect for local improvement (backwards compatibility)
                ModelFeedbackCollector.shared.collectUncertainPrediction(
                    features: features,
                    modelPrediction: predictedClass,
                    modelConfidence: maxConfidence,
                    swingMetadata: createSwingMetadata()
                )
            }
            
            return swingPrediction
            
        } catch {
            print("❌ Core ML inference failed: \(error)")
            throw LocalAnalysisError.inferenceFailed
        }
    }
    
    private func normalizeFeatures(_ features: [Double]) -> [Double] {
        // Load scaler metadata
        guard let scalerPath = Bundle.main.path(forResource: "scaler_metadata", ofType: "json"),
              let scalerData = try? Data(contentsOf: URL(fileURLWithPath: scalerPath)),
              let scalerInfo = try? JSONDecoder().decode(ScalerMetadata.self, from: scalerData) else {
            print("⚠️ Using unnormalized features (scaler metadata not found)")
            return features
        }
        
        var normalized: [Double] = []
        for (index, feature) in features.enumerated() {
            if index < scalerInfo.mean.count && index < scalerInfo.scale.count {
                let normalizedValue = (feature - scalerInfo.mean[index]) / scalerInfo.scale[index]
                normalized.append(normalizedValue)
            } else {
                normalized.append(feature)
            }
        }
        
        return normalized
    }
    
    private func extractProbabilities(from array: MLMultiArray?) -> [Double] {
        guard let array = array else { return [0.33, 0.33, 0.34] }
        
        var probabilities: [Double] = []
        for i in 0..<array.count {
            probabilities.append(array[i].doubleValue)
        }
        
        // Apply softmax to convert to probabilities
        return softmax(probabilities)
    }
    
    private func softmax(_ values: [Double]) -> [Double] {
        let maxValue = values.max() ?? 0
        let expValues = values.map { exp($0 - maxValue) }
        let sumExpValues = expValues.reduce(0, +)
        return expValues.map { $0 / sumExpValues }
    }
    
    private func findMaxProbability(_ probabilities: [Double]) -> (String, Double) {
        let classLabels = ["good_swing", "too_steep", "too_flat"]
        
        guard let maxIndex = probabilities.firstIndex(of: probabilities.max() ?? 0),
              maxIndex < classLabels.count else {
            return ("good_swing", 0.5)
        }
        
        return (classLabels[maxIndex], probabilities[maxIndex])
    }
    
    private func createLocalResponse(prediction: SwingPrediction, features: [Double]) -> SwingAnalysisResponse {
        let probabilities = [
            prediction.label: prediction.confidence,
            "other": 1.0 - prediction.confidence
        ]
        
        let physicsInsights = generatePhysicsInsights(
            prediction: prediction.label,
            planeAngle: prediction.planeAngle
        )
        
        let response = SwingAnalysisResponse(
            predicted_label: prediction.label,
            confidence: prediction.confidence,
            confidence_gap: prediction.confidence - 0.5,
            all_probabilities: probabilities,
            physics_insights: physicsInsights,
            extraction_status: "success",
            plane_angle: prediction.planeAngle,
            tempo_ratio: prediction.tempo,
            analysis_type: "local",
            model_version: "1.0-local"
        )
        
        // Store prediction for potential feedback collection
        currentPrediction = PredictionForFeedback(
            prediction: prediction.label,
            confidence: prediction.confidence,
            features: features
        )
        
        return response
    }
    
    private func generatePhysicsInsights(prediction: String, planeAngle: Double) -> PhysicsInsights {
        let analysis: String
        
        switch prediction {
        case "too_steep":
            analysis = "Your swing plane is too steep at \(Int(planeAngle))°. Focus on a shallower takeaway and maintaining width in your backswing."
        case "too_flat":
            analysis = "Your swing plane is too flat at \(Int(planeAngle))°. Work on a more upright backswing position."
        default:
            analysis = "Good swing plane at \(Int(planeAngle))°. Continue maintaining this consistent path."
        }
        
        return PhysicsInsights(
            avg_plane_angle: planeAngle,
            plane_analysis: analysis
        )
    }
    
    private func createSwingMetadata() -> SwingMetadata {
        return SwingMetadata(
            videoDuration: nil,
            deviceModel: UIDevice.current.model,
            appVersion: Constants.appVersion,
            analysisDate: Date(),
            userSkillLevel: nil,
            clubType: nil,
            practiceOrRound: nil
        )
    }
    
    // MARK: - Feedback Collection Interface
    
    func promptForFeedback() {
        guard let prediction = currentPrediction else { return }
        
        // Only prompt for feedback on uncertain predictions or randomly for confident ones
        if prediction.confidence < 0.7 || (prediction.confidence < 0.9 && Bool.random()) {
            shouldShowFeedbackPrompt = true
        }
    }
    
    func submitFeedback(_ feedback: UserFeedback?) {
        guard let prediction = currentPrediction else { return }
        
        if let feedback = feedback {
            Task { @MainActor in
                ModelFeedbackCollector.shared.collectAnalysisData(
                    features: prediction.features,
                    modelPrediction: prediction.prediction,
                    modelConfidence: prediction.confidence,
                    userFeedback: feedback,
                    swingMetadata: createSwingMetadata()
                )
            }
        }
        
        currentPrediction = nil
        shouldShowFeedbackPrompt = false
    }
    
    func getCurrentPredictionForFeedback() -> PredictionForFeedback? {
        return currentPrediction
    }
}

// MARK: - Supporting Types

struct SwingPrediction {
    let label: String
    let confidence: Double
    let planeAngle: Double
    let tempo: Double
}

struct PredictionForFeedback {
    let prediction: String
    let confidence: Double
    let features: [Double]
}

struct Constants {
    static let appVersion = "1.0.0"
}

struct PoseData {
    let timestamp: Double
    let keypoints: [PoseKeypoint]
}

struct PoseKeypoint {
    let type: KeypointType
    let position: CGPoint
    let confidence: Float
}

enum KeypointType: String {
    case nose, leftEye, rightEye, leftEar, rightEar
    case leftShoulder, rightShoulder, leftElbow, rightElbow
    case leftWrist, rightWrist, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle
}

// MARK: - Pose Detector

class PoseDetector {
    private let humanBodyPoseRequest: VNDetectHumanBodyPoseRequest
    
    init() {
        humanBodyPoseRequest = VNDetectHumanBodyPoseRequest()
    }
    
    func detectPose(in image: UIImage) async throws -> PoseData? {
        guard let cgImage = image.cgImage else { return nil }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([humanBodyPoseRequest])
        
        guard let observation = humanBodyPoseRequest.results?.first else {
            return nil
        }
        
        var keypoints: [PoseKeypoint] = []
        
        // Extract key points
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > 0.3 {
                let keypoint = PoseKeypoint(
                    type: mapJointToKeypoint(jointName),
                    position: CGPoint(x: point.location.x, y: 1 - point.location.y),
                    confidence: Float(point.confidence)
                )
                keypoints.append(keypoint)
            }
        }
        
        return PoseData(timestamp: Date().timeIntervalSince1970, keypoints: keypoints)
    }
    
    private func mapJointToKeypoint(_ joint: VNHumanBodyPoseObservation.JointName) -> KeypointType {
        switch joint {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        default: return .nose
        }
    }
}

// MARK: - Feature Extractor

class SwingFeatureExtractor {
    func extractFeatures(from poses: [PoseData]) -> [Double] {
        var features: [Double] = []
        
        // Calculate swing plane angle
        let planeAngle = calculateSwingPlaneAngle(poses: poses)
        features.append(planeAngle)
        
        // Calculate tempo ratio
        let tempoRatio = calculateTempoRatio(poses: poses)
        features.append(tempoRatio)
        
        // Calculate shoulder rotation
        let shoulderRotation = calculateShoulderRotation(poses: poses)
        features.append(shoulderRotation)
        
        // Add more physics-based features as needed
        // This is a simplified version - the actual implementation would extract all 35 features
        
        // Pad to 35 features for compatibility
        while features.count < 35 {
            features.append(0.0)
        }
        
        return features
    }
    
    private func calculateSwingPlaneAngle(poses: [PoseData]) -> Double {
        // Improved swing plane calculation
        guard poses.count > 10 else { return 45.0 }
        
        // Find address and top positions
        let addressPose = poses.first!
        let topPose = poses[poses.count / 2]
        
        // Get wrist positions - use safe defaults if not found
        let addressWrist = addressPose.keypoints.first(where: { $0.type == .leftWrist })?.position ?? CGPoint(x: 0.5, y: 0.7)
        let topWrist = topPose.keypoints.first(where: { $0.type == .leftWrist })?.position ?? CGPoint(x: 0.4, y: 0.3)
        
        // Calculate swing plane angle more accurately
        let deltaX = topWrist.x - addressWrist.x
        let deltaY = addressWrist.y - topWrist.y // Invert Y for upward movement
        
        // Prevent division by zero
        guard abs(deltaX) > 0.01 || abs(deltaY) > 0.01 else { return 45.0 }
        
        // Calculate angle from horizontal plane
        let angle = abs(atan2(deltaY, abs(deltaX)) * 180 / .pi)
        
        return max(20, min(70, angle)) // Clamp to reasonable range
    }
    
    private func calculateTempoRatio(poses: [PoseData]) -> Double {
        // Simplified tempo calculation
        // Backswing to downswing ratio
        guard poses.count > 20 else { return 3.0 }
        
        let backswingFrames = poses.count * 2 / 3
        let downswingFrames = poses.count / 3
        
        return Double(backswingFrames) / Double(downswingFrames)
    }
    
    private func calculateShoulderRotation(poses: [PoseData]) -> Double {
        // Simplified shoulder rotation
        guard let topPose = poses.first(where: { _ in true }) else { return 90.0 }
        
        let leftShoulder = topPose.keypoints.first(where: { $0.type == .leftShoulder })?.position ?? .zero
        let rightShoulder = topPose.keypoints.first(where: { $0.type == .rightShoulder })?.position ?? .zero
        
        let rotation = abs(leftShoulder.x - rightShoulder.x) * 180
        return min(120, rotation)
    }
}

// MARK: - Supporting Data Structures

struct SwingAnalysisModelInput: MLFeatureProvider, @unchecked Sendable {
    let physics_features: MLMultiArray
    
    var featureNames: Set<String> {
        return ["physics_features"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "physics_features" {
            return MLFeatureValue(multiArray: physics_features)
        }
        return nil
    }
}

struct ScalerMetadata: Codable {
    let mean: [Double]
    let scale: [Double]
}

enum LocalAnalysisError: Error, LocalizedError {
    case modelNotLoaded
    case inputPreparationFailed
    case inferenceFailed
    case featureExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Local AI model not loaded"
        case .inputPreparationFailed:
            return "Failed to prepare model input"
        case .inferenceFailed:
            return "Core ML inference failed"
        case .featureExtractionFailed:
            return "Failed to extract features from pose data"
        }
    }
}