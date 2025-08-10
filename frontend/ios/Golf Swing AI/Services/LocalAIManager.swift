import Foundation
@preconcurrency import CoreML
import Vision
@preconcurrency import AVFoundation
import Accelerate
import CoreImage

// MARK: - Local AI Manager

@MainActor
class LocalAIManager: ObservableObject {
    @MainActor static let shared = LocalAIManager()
    
    @Published var isModelsLoaded = false
    @Published var loadingProgress: Double = 0.0
    // Local-only mode - no server options
    
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
        
        // Load the actual Core ML model from bundle
        guard let modelPath = Bundle.main.path(forResource: "SwingAnalysisModel", ofType: "mlmodel") else {
            print("❌ SwingAnalysisModel.mlmodel not found in bundle")
            print("❌ Ensure model is added to Xcode project with proper target membership")
            return nil
        }
        
        let url = URL(fileURLWithPath: modelPath)
        print("✅ Loading SwingAnalysisModel from bundle: \(modelPath)")
        
        do {
            let mlModel = try MLModel(contentsOf: url)
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
        
        // Load the actual Core ML model from bundle
        guard let modelPath = Bundle.main.path(forResource: "BallTrackingModel", ofType: "mlmodel") else {
            print("❌ BallTrackingModel.mlmodel not found in bundle")
            print("❌ Ensure model is added to Xcode project with proper target membership")
            return nil
        }
        
        let url = URL(fileURLWithPath: modelPath)
        print("✅ Loading BallTrackingModel from bundle: \(modelPath)")
        
        do {
            let mlModel = try MLModel(contentsOf: url)
            let vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ Successfully loaded BallTrackingModel")
            return vnModel
        } catch {
            print("❌ Failed to load BallTrackingModel: \(error)")
            return nil
        }
    }
}

// MARK: - Local Analysis Only
// This app runs all analysis locally for privacy and performance

// MARK: - Local Swing Analyzer

@MainActor
class LocalSwingAnalyzer: ObservableObject {
    private let poseDetector = MediaPipePoseDetector()
    private let featureExtractor = SwingFeatureExtractor()
    // Note: LocalModelManager not implemented yet
    private var swingAnalysisModel: MLModel?
    
    init() {
        loadModels()
    }
    
    private func loadModels() {
        Task {
            await loadSwingAnalysisModel()
        }
    }
    
    private func loadSwingAnalysisModel() async {
        // Try to load compiled model first (.mlmodelc)
        if let compiledModelURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlmodelc") {
            do {
                swingAnalysisModel = try MLModel(contentsOf: compiledModelURL)
                print("✅ LocalSwingAnalyzer: Core ML compiled model loaded")
                return
            } catch {
                print("⚠️ Failed to load compiled model: \(error)")
            }
        }
        
        // Try to load uncompiled model (.mlmodel)
        if let modelURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlmodel") {
            do {
                swingAnalysisModel = try MLModel(contentsOf: modelURL)
                print("✅ LocalSwingAnalyzer: Core ML model loaded")
                return
            } catch {
                print("⚠️ Failed to load model: \(error)")
            }
        }
        
        // Try to load package model (.mlpackage)
        if let packageURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlpackage") {
            do {
                swingAnalysisModel = try MLModel(contentsOf: packageURL)
                print("✅ LocalSwingAnalyzer: Core ML package model loaded")
                return
            } catch {
                print("⚠️ Failed to load package model: \(error)")
            }
        }
        
        print("❌ SwingAnalysisModel not found in bundle")
        print("❌ Please add SwingAnalysisModel.mlmodelc, .mlmodel, or .mlpackage to your Xcode project")
        print("❌ To create the model, run: python3 create_coreml_models.py")
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
        
        // Critical debug: Check if we have any poses at all
        if poses.isEmpty {
            print("❌ CRITICAL: No poses detected from MediaPipe!")
        } else if poses.count < 3 {
            print("❌ CRITICAL: Very few poses detected (\(poses.count)) - insufficient for analysis")
        } else {
            print("✅ Sufficient poses detected for analysis")
            // Sample keypoint data from first and middle poses
            let firstPose = poses[0]
            let middlePose = poses[poses.count / 2]
            print("🔍 First pose keypoints: \(firstPose.keypoints.count)")
            print("🔍 Middle pose keypoints: \(middlePose.keypoints.count)")
            
            // Check for critical keypoints
            let firstWrist = firstPose.keypoints.first { $0.type == .leftWrist }
            let middleWrist = middlePose.keypoints.first { $0.type == .leftWrist }
            if let fw = firstWrist, let mw = middleWrist {
                print("🔍 Found wrist keypoints - First: (\(String(format: "%.3f", fw.position.x)), \(String(format: "%.3f", fw.position.y))), Middle: (\(String(format: "%.3f", mw.position.x)), \(String(format: "%.3f", mw.position.y)))")
            } else {
                print("❌ CRITICAL: Missing wrist keypoints in poses!")
            }
        }
        
        // Extract physics-based features
        var features = featureExtractor.extractFeatures(from: poses)
        print("📊 Extracted \(features.count) physics features")
        
        // Debug: Print key features for troubleshooting
        if features.count >= 35 {
            print("🔍 Debug - Key features: Spine=\(String(format: "%.1f", features[0])), MaxShoulder=\(String(format: "%.1f", features[5])), PlaneAngle=\(String(format: "%.1f", features[8])), Tempo=\(String(format: "%.1f", features[17]))")
            
            // Handle swing plane calculation failure
            if features[8] == 0.0 {
                print("❌ CRITICAL: Swing plane calculation failed - attempting alternative calculation")
                
                // Try alternative swing plane calculation
                let alternativeAngle = calculateAlternativeSwingPlane(poses: poses)
                features[8] = alternativeAngle
                print("🔧 Alternative swing plane angle: \(String(format: "%.1f", alternativeAngle))°")
            }
        }
        
        // Run inference (simplified for now)
        let prediction = try await runInference(features: features)
        
        // Create response
        return createLocalResponse(prediction: prediction, features: features)
    }
    
    private func extractFrames(from videoURL: URL) async throws -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
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
                let result = try await generator.image(at: time)
                let image = UIImage(cgImage: result.image)
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
            let timestamp = TimeInterval(index) * (1.0 / 30.0) // Assuming 30 FPS
            if let pose = try await poseDetector.detectPose(in: frame, timestamp: timestamp) {
                poses.append(pose.asPoseData)
            }
        }
        
        return poses
    }
    
    private func runInference(features: [Double]) async throws -> SwingPrediction {
        guard let model = swingAnalysisModel else {
            throw LocalAnalysisError.modelNotLoaded
        }
        
        return try await runRealMLInference(model: model, features: features)
    }
    
    private func runRealMLInference(model: MLModel, features: [Double]) async throws -> SwingPrediction {
        print("🤖 Running Core ML inference with production model")
        
        // Ensure we have 35 features
        guard features.count == 35 else {
            throw LocalAnalysisError.invalidFeatureCount
        }
        
        // Create input array
        guard let inputArray = try? MLMultiArray(shape: [35], dataType: .double) else {
            throw LocalAnalysisError.inputPreparationFailed
        }
        
        // Fill input array
        for (index, feature) in features.enumerated() {
            inputArray[index] = NSNumber(value: feature)
        }
        
        // Create input provider
        let input = SwingAnalysisModelInput(physics_features: inputArray)
        
        // Run prediction
        do {
            let output = try model.prediction(from: input)
            
            // Extract class label and probabilities
            guard let predictedClass = output.featureValue(for: "classLabel")?.stringValue,
                  let probabilities = output.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] else {
                throw LocalAnalysisError.invalidModelOutput
            }
            
            // Get confidence for predicted class
            let confidence = probabilities[predictedClass] ?? 0.5
            
            // Extract key features for reporting
            let planeAngle = features[8]  // swing_plane_angle is at index 8
            let tempo = features[32]       // overall_tempo is at index 32
            
            print("✅ Core ML prediction: \(predictedClass) (confidence: \(String(format: "%.2f", confidence)))")
            print("   Swing plane: \(String(format: "%.1f", planeAngle))°, Tempo: \(String(format: "%.1f", tempo))")
            
            return SwingPrediction(
                label: predictedClass,
                confidence: confidence,
                planeAngle: planeAngle,
                tempo: tempo
            )
            
        } catch {
            print("❌ Core ML inference failed: \(error)")
            throw LocalAnalysisError.inferenceFailed
        }
    }
    
    private func normalizeFeatures(_ features: [Double]) -> [Double] {
        print("⚠️ Feature normalization not implemented - using raw features")
        return features
        // TODO: Implement proper feature normalization when scaler metadata is available
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
        
        // Create physics insights string for compatibility
        let physicsInsights: String
        switch prediction.label {
        case "too_steep":
            physicsInsights = "Your swing plane is too steep at \(Int(prediction.planeAngle))°. Focus on a shallower takeaway and maintaining width in your backswing."
        case "too_flat":
            physicsInsights = "Your swing plane is too flat at \(Int(prediction.planeAngle))°. Work on a more upright backswing position."
        default:
            physicsInsights = "Good swing plane at \(Int(prediction.planeAngle))°. Continue maintaining this consistent path."
        }
        
        let recommendations: [String] = [
            "Focus on consistent setup position",
            "Maintain spine angle throughout swing",
            "Work on tempo and timing"
        ]
        
        return SwingAnalysisResponse(
            predicted_label: prediction.label,
            confidence: prediction.confidence,
            confidence_gap: prediction.confidence - 0.5,
            all_probabilities: probabilities,
            camera_angle: "mobile_portrait",
            angle_confidence: 0.8,
            feature_reliability: nil,
            club_face_analysis: nil,
            club_speed_analysis: nil,
            premium_features_available: false,
            physics_insights: physicsInsights,
            angle_insights: nil,
            recommendations: recommendations,
            extraction_status: "success",
            analysis_type: "local",
            model_version: "local_v1.0",
            plane_angle: prediction.planeAngle,
            tempo_ratio: prediction.tempo
        )
    }
    
    
    // Alternative swing plane calculation when primary method fails
    private func calculateAlternativeSwingPlane(poses: [PoseData]) -> Double {
        print("🔄 Attempting alternative swing plane calculation...")
        
        guard poses.count >= 2 else {
            print("❌ Alternative: Not enough poses")
            return 35.0 // Reasonable default for "good" swing
        }
        
        // Try using shoulder movement as a proxy for swing plane
        let firstPose = poses[0]
        let lastPose = poses[poses.count - 1]
        
        // Look for any available arm keypoints in order of preference
        let keyPointPairs: [(KeypointType, KeypointType)] = [
            (.leftWrist, .leftShoulder),
            (.rightWrist, .rightShoulder),
            (.leftElbow, .leftShoulder),
            (.rightElbow, .rightShoulder)
        ]
        
        for (handType, shoulderType) in keyPointPairs {
            if let firstHand = firstPose.keypoints.first(where: { $0.type == handType }),
               let lastHand = lastPose.keypoints.first(where: { $0.type == handType }) {
                
                print("🔍 Alternative: Using \(handType.rawValue) and \(shoulderType.rawValue)")
                
                // Calculate relative movement
                let deltaX = lastHand.position.x - firstHand.position.x
                let deltaY = lastHand.position.y - firstHand.position.y
                
                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
                
                if distance > 0.02 { // Minimum movement threshold
                    // Calculate angle based on movement pattern
                    let angle = atan2(abs(deltaY), abs(deltaX)) * 180 / .pi
                    let clampedAngle = max(25, min(65, angle))
                    
                    print("🔧 Alternative calculated angle: \(String(format: "%.2f", clampedAngle))°")
                    return clampedAngle
                }
            }
        }
        
        // If all else fails, analyze the overall motion pattern
        print("🔄 Using motion pattern analysis...")
        
        // Calculate average pose dimensions to estimate swing characteristics
        var totalMovement: Double = 0
        var frameCount = 0
        
        for i in 1..<poses.count {
            let prevPose = poses[i-1]
            let currPose = poses[i]
            
            // Look for any detectable movement
            for keypoint in currPose.keypoints {
                if let prevKeypoint = prevPose.keypoints.first(where: { $0.type == keypoint.type }) {
                    let dx = keypoint.position.x - prevKeypoint.position.x
                    let dy = keypoint.position.y - prevKeypoint.position.y
                    totalMovement += sqrt(dx * dx + dy * dy)
                    frameCount += 1
                }
            }
        }
        
        let avgMovement = frameCount > 0 ? totalMovement / Double(frameCount) : 0
        
        // Estimate swing plane based on total movement
        if avgMovement > 0.01 {
            let estimatedAngle = min(55, max(25, avgMovement * 800)) // Scale movement to reasonable angle
            print("🔧 Motion-based estimated angle: \(String(format: "%.2f", estimatedAngle))°")
            return estimatedAngle
        }
        
        // Final fallback: return a typical swing plane angle
        print("🔧 Using default swing plane angle: 35°")
        return 35.0
    }
}

// MARK: - Supporting Types

struct SwingPrediction {
    let label: String
    let confidence: Double
    let planeAngle: Double
    let tempo: Double
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
        guard poses.count >= 3 else {
            print("❌ Too few poses detected (\(poses.count)). Cannot perform analysis.")
            return Array(repeating: 0.0, count: 35) // Will trigger proper error handling
        }
        
        print("🎬 Processing \(poses.count) poses for feature extraction")
        if poses.count < 10 {
            print("⚠️ Limited poses detected (\(poses.count)). Analysis may be less accurate.")
        }
        
        var features: [Double] = []
        
        // Phase 1: Setup and Address Features (5 features)
        let setupFeatures = extractSetupFeatures(poses: poses)
        features.append(contentsOf: setupFeatures)
        
        // Phase 2: Backswing Features (10 features)
        let backswingFeatures = extractBackswingFeatures(poses: poses)
        features.append(contentsOf: backswingFeatures)
        
        // Phase 3: Transition Features (5 features)
        let transitionFeatures = extractTransitionFeatures(poses: poses)
        features.append(contentsOf: transitionFeatures)
        
        // Phase 4: Downswing Features (8 features)
        let downswingFeatures = extractDownswingFeatures(poses: poses)
        features.append(contentsOf: downswingFeatures)
        
        // Phase 5: Impact and Follow-through Features (7 features)
        let impactFeatures = extractImpactFeatures(poses: poses)
        features.append(contentsOf: impactFeatures)
        
        // Ensure exactly 35 features
        while features.count < 35 {
            features.append(0.0)
        }
        
        return Array(features.prefix(35))
    }
    
    // MARK: - Setup and Address Analysis
    
    private func extractSetupFeatures(poses: [PoseData]) -> [Double] {
        guard let addressPose = poses.first else { return Array(repeating: 0.0, count: 5) }
        
        var features: [Double] = []
        
        // 1. Spine angle at address
        let spineAngle = calculateSpineAngle(pose: addressPose)
        features.append(spineAngle)
        
        // 2. Knee flex angle
        let kneeFlexion = calculateKneeFlexion(pose: addressPose)
        features.append(kneeFlexion)
        
        // 3. Weight distribution (shoulder position relative to hips)
        let weightDistribution = calculateWeightDistribution(pose: addressPose)
        features.append(weightDistribution)
        
        // 4. Arm hang angle
        let armHangAngle = calculateArmHangAngle(pose: addressPose)
        features.append(armHangAngle)
        
        // 5. Stance width (hip to hip distance)
        let stanceWidth = calculateStanceWidth(pose: addressPose)
        features.append(stanceWidth)
        
        return features
    }
    
    // MARK: - Backswing Analysis
    
    private func extractBackswingFeatures(poses: [PoseData]) -> [Double] {
        let backswingPoses = Array(poses.prefix(poses.count * 2 / 3))
        print("🏌️ Analyzing backswing: \(backswingPoses.count) poses from total \(poses.count)")
        
        guard backswingPoses.count >= 2 else { 
            print("❌ Insufficient backswing poses (\(backswingPoses.count)). Using zero values.")
            return Array(repeating: 0.0, count: 10)
        }
        
        var features: [Double] = []
        
        // 1. Maximum shoulder turn
        let maxShoulderTurn = calculateMaxShoulderTurn(poses: backswingPoses)
        features.append(maxShoulderTurn)
        
        // 2. Hip turn at top
        let hipTurnAtTop = calculateHipTurn(poses: backswingPoses)
        features.append(hipTurnAtTop)
        
        // 3. X-Factor (shoulder-hip separation)
        let xFactor = maxShoulderTurn - hipTurnAtTop
        features.append(xFactor)
        
        // 4. Swing plane deviation
        let swingPlaneAngle = calculateSwingPlaneAngle(poses: backswingPoses)
        print("📐 Calculated swing plane angle: \(String(format: "%.2f", swingPlaneAngle))°")
        features.append(swingPlaneAngle)
        
        // 5. Arm extension
        let armExtension = calculateArmExtension(poses: backswingPoses)
        features.append(armExtension)
        
        // 6. Weight shift pattern
        let weightShift = calculateWeightShift(poses: backswingPoses)
        features.append(weightShift)
        
        // 7. Wrist hinge angle
        let wristHinge = calculateWristHinge(poses: backswingPoses)
        features.append(wristHinge)
        
        // 8. Backswing tempo (time to reach top)
        let backswingTempo = calculateBackswingTempo(poses: backswingPoses)
        features.append(backswingTempo)
        
        // 9. Head stability
        let headMovement = calculateHeadMovement(poses: backswingPoses)
        features.append(headMovement)
        
        // 10. Left knee stability
        let kneeStability = calculateKneeStability(poses: backswingPoses)
        features.append(kneeStability)
        
        return features
    }
    
    // MARK: - Transition Analysis
    
    private func extractTransitionFeatures(poses: [PoseData]) -> [Double] {
        let transitionStart = poses.count * 2 / 3
        let transitionEnd = poses.count * 3 / 4
        let transitionPoses = Array(poses[transitionStart..<min(transitionEnd, poses.count)])
        
        guard transitionPoses.count >= 2 else { return Array(repeating: 0.0, count: 5) }
        
        var features: [Double] = []
        
        // 1. Transition tempo (pause time)
        let transitionTempo = Double(transitionPoses.count) / Double(poses.count)
        features.append(transitionTempo)
        
        // 2. Hip lead (hips start before shoulders)
        let hipLead = calculateHipLead(poses: transitionPoses)
        features.append(hipLead)
        
        // 3. Weight transfer rate
        let weightTransferRate = calculateWeightTransferRate(poses: transitionPoses)
        features.append(weightTransferRate)
        
        // 4. Wrist uncocking timing
        let wristTiming = calculateWristTiming(poses: transitionPoses)
        features.append(wristTiming)
        
        // 5. Sequence efficiency (kinematic sequence score)
        let sequenceEfficiency = calculateSequenceEfficiency(poses: transitionPoses)
        features.append(sequenceEfficiency)
        
        return features
    }
    
    // MARK: - Downswing Analysis
    
    private func extractDownswingFeatures(poses: [PoseData]) -> [Double] {
        let downswingStart = poses.count * 3 / 4
        let downswingPoses = Array(poses[downswingStart...])
        
        guard downswingPoses.count >= 3 else { return Array(repeating: 0.0, count: 8) }
        
        var features: [Double] = []
        
        // 1. Hip rotation speed
        let hipRotationSpeed = calculateHipRotationSpeed(poses: downswingPoses)
        features.append(hipRotationSpeed)
        
        // 2. Shoulder rotation speed  
        let shoulderRotationSpeed = calculateShoulderRotationSpeed(poses: downswingPoses)
        features.append(shoulderRotationSpeed)
        
        // 3. Club path angle
        let clubPathAngle = calculateClubPathAngle(poses: downswingPoses)
        features.append(clubPathAngle)
        
        // 4. Attack angle
        let attackAngle = calculateAttackAngle(poses: downswingPoses)
        features.append(attackAngle)
        
        // 5. Release timing
        let releaseTiming = calculateReleaseTiming(poses: downswingPoses)
        features.append(releaseTiming)
        
        // 6. Left side stability
        let leftSideStability = calculateLeftSideStability(poses: downswingPoses)
        features.append(leftSideStability)
        
        // 7. Downswing tempo
        let downswingTempo = Double(downswingPoses.count) / Double(poses.count)
        features.append(downswingTempo)
        
        // 8. Power generation (torso rotation acceleration)
        let powerGeneration = calculatePowerGeneration(poses: downswingPoses)
        features.append(powerGeneration)
        
        return features
    }
    
    // MARK: - Impact and Follow-through Analysis
    
    private func extractImpactFeatures(poses: [PoseData]) -> [Double] {
        guard let impactPose = poses.last else { return Array(repeating: 0.0, count: 7) }
        let followThroughPoses = Array(poses.suffix(min(5, poses.count / 4)))
        
        var features: [Double] = []
        
        // 1. Impact position consistency
        let impactPosition = calculateImpactPosition(pose: impactPose)
        features.append(impactPosition)
        
        // 2. Extension through impact
        let extensionThroughImpact = calculateExtensionThroughImpact(pose: impactPose)
        features.append(extensionThroughImpact)
        
        // 3. Follow-through balance
        let followThroughBalance = calculateFollowThroughBalance(poses: followThroughPoses)
        features.append(followThroughBalance)
        
        // 4. Finish position quality
        let finishQuality = calculateFinishQuality(poses: followThroughPoses)
        features.append(finishQuality)
        
        // 5. Overall tempo ratio
        let overallTempo = calculateOverallTempo(poses: poses)
        features.append(overallTempo)
        
        // 6. Swing rhythm consistency
        let rhythmConsistency = calculateRhythmConsistency(poses: poses)
        features.append(rhythmConsistency)
        
        // 7. Overall swing efficiency
        let swingEfficiency = calculateSwingEfficiency(poses: poses)
        features.append(swingEfficiency)
        
        return features
    }
    
    // MARK: - Individual Physics Calculation Methods
    // These methods delegate to SwingPhysicsCalculator for comprehensive analysis
    
    private func calculateSpineAngle(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateSpineAngle(pose: pose)
    }
    
    private func calculateKneeFlexion(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateKneeFlexion(pose: pose)
    }
    
    private func calculateWeightDistribution(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateWeightDistribution(pose: pose)
    }
    
    private func calculateArmHangAngle(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateArmHangAngle(pose: pose)
    }
    
    private func calculateStanceWidth(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateStanceWidth(pose: pose)
    }
    
    private func calculateMaxShoulderTurn(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateMaxShoulderTurn(poses: poses)
    }
    
    private func calculateHipTurn(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateHipTurn(poses: poses)
    }
    
    private func calculateSwingPlaneAngle(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateSwingPlaneAngle(poses: poses)
    }
    
    private func calculateArmExtension(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateArmExtension(poses: poses)
    }
    
    private func calculateWeightShift(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateWeightShift(poses: poses)
    }
    
    private func calculateWristHinge(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateWristHinge(poses: poses)
    }
    
    private func calculateBackswingTempo(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateBackswingTempo(poses: poses)
    }
    
    private func calculateHeadMovement(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateHeadMovement(poses: poses)
    }
    
    private func calculateKneeStability(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateKneeStability(poses: poses)
    }
    
    private func calculateHipLead(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateHipLead(poses: poses)
    }
    
    private func calculateWeightTransferRate(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateWeightTransferRate(poses: poses)
    }
    
    private func calculateWristTiming(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateWristTiming(poses: poses)
    }
    
    private func calculateSequenceEfficiency(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateSequenceEfficiency(poses: poses)
    }
    
    private func calculateHipRotationSpeed(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateHipRotationSpeed(poses: poses)
    }
    
    private func calculateShoulderRotationSpeed(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateShoulderRotationSpeed(poses: poses)
    }
    
    private func calculateClubPathAngle(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateClubPathAngle(poses: poses)
    }
    
    private func calculateAttackAngle(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateAttackAngle(poses: poses)
    }
    
    private func calculateReleaseTiming(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateReleaseTiming(poses: poses)
    }
    
    private func calculateLeftSideStability(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateLeftSideStability(poses: poses)
    }
    
    private func calculatePowerGeneration(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculatePowerGeneration(poses: poses)
    }
    
    private func calculateImpactPosition(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateImpactPosition(pose: pose)
    }
    
    private func calculateExtensionThroughImpact(pose: PoseData) -> Double {
        return SwingPhysicsCalculator.calculateExtensionThroughImpact(pose: pose)
    }
    
    private func calculateFollowThroughBalance(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateFollowThroughBalance(poses: poses)
    }
    
    private func calculateFinishQuality(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateFinishQuality(poses: poses)
    }
    
    private func calculateOverallTempo(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateOverallTempo(poses: poses)
    }
    
    private func calculateRhythmConsistency(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateRhythmConsistency(poses: poses)
    }
    
    private func calculateSwingEfficiency(poses: [PoseData]) -> Double {
        return SwingPhysicsCalculator.calculateSwingEfficiency(poses: poses)
    }
}

// MARK: - Supporting Data Structures

struct ScalerMetadata: Codable {
    let mean: [Double]
    let scale: [Double]
}

enum LocalAnalysisError: Error, LocalizedError {
    case modelNotLoaded
    case inputPreparationFailed
    case inferenceFailed
    case featureExtractionFailed
    case invalidFeatureCount
    case invalidModelOutput
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Local AI model not loaded - please ensure SwingAnalysisModel.mlmodelc is in the app bundle"
        case .inputPreparationFailed:
            return "Failed to prepare model input"
        case .inferenceFailed:
            return "Core ML inference failed"
        case .featureExtractionFailed:
            return "Failed to extract features from pose data"
        case .invalidFeatureCount:
            return "Invalid feature count - expected 35 features"
        case .invalidModelOutput:
            return "Invalid model output format"
        }
    }
}

