import Foundation
@preconcurrency import CoreML
@preconcurrency import AVFoundation
import Accelerate
import CoreImage

// MARK: - Simple Model Wrapper
final class SwingAnalysisModelWrapper: @unchecked Sendable {
    private let model: MLModel
    
    init(model: MLModel) {
        self.model = model
    }
    
    nonisolated static func loadFromBundle() throws -> SwingAnalysisModelWrapper {
        // Try to load compiled model first (.mlmodelc)
        if let compiledModelURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlmodelc") {
            do {
                let model = try MLModel(contentsOf: compiledModelURL)
                print("✅ SwingAnalysisModel: Loaded compiled model (.mlmodelc)")
                return SwingAnalysisModelWrapper(model: model)
            } catch {
                print("⚠️ Failed to load compiled model: \(error)")
            }
        }
        
        // Try to load uncompiled model (.mlmodel)
        if let modelURL = Bundle.main.url(forResource: "SwingAnalysisModel", withExtension: "mlmodel") {
            do {
                let model = try MLModel(contentsOf: modelURL)
                print("✅ SwingAnalysisModel: Loaded uncompiled model (.mlmodel)")
                return SwingAnalysisModelWrapper(model: model)
            } catch {
                print("⚠️ Failed to load uncompiled model: \(error)")
            }
        }
        
        throw LocalAnalysisError.modelNotLoaded
    }
    
    nonisolated func predict(features: [Double]) async throws -> (String, Double) {
        // Create simple MLMultiArray input
        guard let multiArray = try? MLMultiArray(shape: [35], dataType: .double) else {
            throw LocalAnalysisError.inputPreparationFailed
        }
        
        for (index, feature) in features.enumerated() {
            guard index < 35 else { break }
            multiArray[index] = NSNumber(value: feature)
        }
        
        // Create input dictionary
        let input = try! MLDictionaryFeatureProvider(dictionary: ["physics_features": MLFeatureValue(multiArray: multiArray)])
        
        // Run prediction
        let output = try await model.prediction(from: input)
        
        // Extract prediction
        guard let classLabel = output.featureValue(for: "classLabel")?.stringValue else {
            throw LocalAnalysisError.invalidModelOutput
        }
        
        let probabilities = output.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] ?? [:]
        let confidence = probabilities[classLabel] ?? 0.5
        
        return (classLabel, confidence)
    }
}

// MARK: - Local AI Manager

@MainActor
class LocalAIManager: ObservableObject {
    @MainActor static let shared = LocalAIManager()
    
    @Published var isModelsLoaded = false
    @Published var loadingProgress: Double = 0.0
    // Local-only mode - no server options
    
    // Note: Actual AI models are handled by LocalSwingAnalyzer with proper MLModel instances
    
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
            
            // Note: Actual model loading is handled by LocalSwingAnalyzer with proper Golf AI models
            print("✅ LocalAIManager ready - using LocalSwingAnalyzer with custom Golf AI models")
            
            await MainActor.run {
                self.loadingProgress = 1.0
                self.isModelsLoaded = true
            }
        }
    }
}

// MARK: - Local Analysis Only
// This app runs all analysis locally for privacy and performance

// MARK: - Local Swing Analyzer

@MainActor
class LocalSwingAnalyzer: ObservableObject {
    private let golfPoseDetector = GolfPoseDetector()
    private let legacyPoseDetector = MediaPipePoseDetector() // Fallback only
    private let featureExtractor = SwingFeatureExtractor()
    private var swingAnalysisModel: SwingAnalysisModelWrapper?
    
    // Store the last prediction for feedback collection
    private var lastPredictionFeatures: [Double]?
    
    init() {
        loadModels()
    }
    
    private func loadModels() {
        Task {
            await loadSwingAnalysisModel()
        }
    }
    
    private func loadSwingAnalysisModel() async {
        // Use the SwingAnalysisModel wrapper to load from bundle
        do {
            swingAnalysisModel = try SwingAnalysisModelWrapper.loadFromBundle()
            print("✅ LocalSwingAnalyzer: SwingAnalysisModel loaded with proper wrapper")
        } catch {
            print("❌ Failed to load SwingAnalysisModel: \(error)")
            print("❌ Please add SwingAnalysisModel.mlmodelc to your Xcode project")
            print("❌ To create the model, run: python3 create_coreml_models.py")
        }
    }
    
    func analyzeSwing(from videoURL: URL) async throws -> SwingAnalysisResponse {
        print("🏌️ Starting local swing analysis...")
        
        // Extract frames from video
        let frames = try await extractFrames(from: videoURL)
        print("📹 Extracted \(frames.count) frames")
        
        // Use our custom Golf AI detector
        print("🏌️ Using Golf-Specific AI Pose Detector...")
        
        let golfPoses: [GolfPoseResult]
        do {
            // Try golf-specific AI detector first
            golfPoses = try await golfPoseDetector.analyzeSwingSequence(from: videoURL)
            print("✅ Golf AI detected poses in \(golfPoses.count) frames")
            
        } catch let golfError as GolfPoseError {
            print("⚠️ Golf AI failed: \(golfError), trying legacy detector...")
            
            // Fallback to legacy detector only if Golf AI fails
            do {
                let mediaPipePoses = try await legacyPoseDetector.detectPoseSequence(from: videoURL)
                let legacyPoses = mediaPipePoses.map { $0.asPoseData }
                
                // Convert legacy poses to golf poses for consistency
                let convertedGolfPoses = legacyPoses.map { poseData in
                    GolfPoseResult(
                        timestamp: poseData.timestamp,
                        keypoints: convertToGolfKeypoints(poseData.keypoints),
                        clubInfo: GolfClubInfo(isDetected: false, shaftAngle: 0, clubfaceAngle: 0, path: [], clubType: .unknown),
                        biomechanics: SwingBiomechanics(
                            spineAngle: 0, hipRotation: 0, shoulderTurn: 0,
                            weightTransfer: WeightTransfer(leftPercentage: 50, rightPercentage: 50, centerOfGravity: CGPoint(x: 0.5, y: 0.7)),
                            gripPosition: GripAnalysis(strength: .neutral, position: .correct, consistency: 0.5),
                            posture: PostureAnalysis(spineAngle: 0, kneeFlexion: 0, armHang: 0, rating: .fair),
                            clubPath: [],
                            tempo: GolfTempoAnalysis(backswingTempo: 0, downswingTempo: 0, ratio: 3.0, consistency: 0.5)
                        ),
                        swingPhase: .address,
                        confidence: 0.5
                    )
                }
                
                print("✅ Fallback detector provided \(convertedGolfPoses.count) poses")
                return await analyzeWithGolfPoses(convertedGolfPoses, videoURL: videoURL)
                
            } catch {
                print("❌ Both Golf AI and fallback detection failed: \(error)")
                throw LocalAnalysisError.noPosesDetected("""
                    Unable to detect golf swing poses in the video.
                    
                    Both our advanced Golf AI and fallback detection methods failed. This could be due to:
                    
                    • Video quality too low for pose detection
                    • Golfer not clearly visible or partially obscured  
                    • Lighting conditions too challenging
                    • Camera angle not suitable for analysis
                    
                    For best results:
                    • Record in good lighting (avoid backlighting)
                    • Keep full body visible throughout swing
                    • Use side-view or back-view camera angles
                    • Ensure stable camera position
                    • Record at least 5-10 seconds including full swing
                    """)
            }
        } catch {
            print("❌ Unexpected Golf AI error: \(error)")
            throw LocalAnalysisError.featureExtractionFailed
        }
        
        return await analyzeWithGolfPoses(golfPoses, videoURL: videoURL)
    }
    
    private func analyzeWithGolfPoses(_ golfPoses: [GolfPoseResult], videoURL: URL) async -> SwingAnalysisResponse {
        print("🏌️ Processing \(golfPoses.count) Golf AI poses for comprehensive analysis...")
        
        // Create comprehensive Golf AI analysis
        let golfAnalysis = createGolfAnalysisResult(from: golfPoses, videoURL: videoURL)
        
        // Convert to legacy format for UI compatibility
        let legacyResult = golfAnalysis.asSwingAnalysisResponse
        
        // Store the full Golf AI analysis for potential future use
        print("✅ Golf AI analysis complete: \(golfAnalysis.predicted_label) with \(String(format: "%.1f", golfAnalysis.confidence * 100))% confidence")
        print("🏌️ Golf AI detected \(golfAnalysis.swing_phases.count) swing phases")
        print("🎯 Golf AI recommendations: \(golfAnalysis.recommendations.count)")
        
        return legacyResult
    }
    
    private func createGolfAnalysisResult(from golfPoses: [GolfPoseResult], videoURL: URL) -> LocalGolfAnalysisResult {
        print("🧠 Creating comprehensive Golf AI analysis...")
        
        // Analyze swing phases
        let swingPhases = analyzeSwingPhases(golfPoses)
        
        // Comprehensive biomechanics analysis
        let biomechanics = analyzeCompleteBiomechanics(golfPoses, videoURL: videoURL)
        
        // Club analysis from Golf AI
        let clubAnalysis = analyzeClubData(golfPoses)
        
        // Generate golf-specific recommendations
        let recommendations = generateGolfRecommendations(
            phases: swingPhases,
            biomechanics: biomechanics,
            club: clubAnalysis
        )
        
        // Determine overall swing classification
        let swingClassification = classifySwing(
            biomechanics: biomechanics,
            club: clubAnalysis,
            phases: swingPhases
        )
        
        // Calculate overall performance score
        let overallScore = calculateGolfPerformanceScore(
            phases: swingPhases,
            biomechanics: biomechanics,
            club: clubAnalysis
        )
        
        return LocalGolfAnalysisResult(
            predicted_label: swingClassification.label,
            confidence: swingClassification.confidence,
            swing_phases: swingPhases,
            biomechanics: biomechanics,
            club_analysis: clubAnalysis,
            recommendations: recommendations,
            overall_score: overallScore,
            analysis_type: "golf_ai_local",
            model_version: "golf_ai_v1.0"
        )
    }
    
    // MARK: - Golf AI Analysis Functions
    
    private func analyzeSwingPhases(_ golfPoses: [GolfPoseResult]) -> [GolfSwingPhase] {
        var phases: [GolfSwingPhase] = []
        
        if golfPoses.isEmpty { return phases }
        
        // Group poses by swing phase
        let phaseGroups = Dictionary(grouping: golfPoses) { $0.swingPhase }
        
        for (phase, poses) in phaseGroups {
            guard let firstPose = poses.first, let lastPose = poses.last else { continue }
            
            let startTime = firstPose.timestamp
            let endTime = lastPose.timestamp
            let duration = endTime - startTime
            let avgKeypoints = poses.reduce(0) { $0 + $1.keypoints.count } / poses.count
            let avgConfidence = poses.reduce(0.0) { $0 + Double($1.confidence) } / Double(poses.count)
            
            phases.append(GolfSwingPhase(
                phase: phase.displayName,
                start_time: startTime,
                end_time: endTime,
                duration: duration,
                quality_score: avgConfidence,
                keypoints_detected: avgKeypoints
            ))
        }
        
        return phases.sorted { $0.start_time < $1.start_time }
    }
    
    private func analyzeCompleteBiomechanics(_ golfPoses: [GolfPoseResult], videoURL: URL) -> GolfBiomechanicsData {
        guard !golfPoses.isEmpty else {
            return createDefaultBiomechanics()
        }
        
        // Calculate averages and key metrics from all poses
        let avgSpineAngle = golfPoses.reduce(0.0) { $0 + $1.biomechanics.spineAngle } / Double(golfPoses.count)
        let avgHipRotation = golfPoses.reduce(0.0) { $0 + $1.biomechanics.hipRotation } / Double(golfPoses.count)
        let avgShoulderTurn = golfPoses.reduce(0.0) { $0 + $1.biomechanics.shoulderTurn } / Double(golfPoses.count)
        let avgTempoRatio = golfPoses.reduce(0.0) { $0 + $1.biomechanics.tempo.ratio } / Double(golfPoses.count)
        
        // Analyze weight transfer throughout swing
        let weightTransfer = analyzeWeightTransferSequence(golfPoses)
        
        // Determine camera angle from poses
        let cameraAngle = determineCameraAngle(golfPoses)
        
        // Calculate feature reliability
        let featureReliability = calculateFeatureReliability(golfPoses)
        
        // Generate insights
        let physicsInsights = generatePhysicsInsights(
            spineAngle: avgSpineAngle,
            hipRotation: avgHipRotation,
            shoulderTurn: avgShoulderTurn,
            weightTransfer: weightTransfer
        )
        
        let postureInsights = generatePostureInsights(
            spineAngle: avgSpineAngle,
            poses: golfPoses
        )
        
        return GolfBiomechanicsData(
            spine_angle: avgSpineAngle,
            hip_rotation: avgHipRotation,
            shoulder_rotation: avgShoulderTurn,
            weight_transfer: weightTransfer,
            posture_rating: ratePosture(avgSpineAngle, golfPoses),
            tempo_ratio: avgTempoRatio,
            swing_plane_angle: calculateSwingPlaneFromGolfPoses(golfPoses),
            balance_score: calculateBalanceScore(golfPoses),
            camera_angle: cameraAngle,
            angle_confidence: calculateAngleConfidence(golfPoses),
            feature_reliability: featureReliability,
            physics_summary: physicsInsights,
            posture_insights: postureInsights,
            video_duration: golfPoses.last?.timestamp ?? 0.0
        )
    }
    
    private func analyzeClubData(_ golfPoses: [GolfPoseResult]) -> GolfClubAnalysisData {
        // Find poses where club was detected
        let clubPoses = golfPoses.filter { $0.clubInfo.isDetected }
        
        guard !clubPoses.isEmpty else {
            return createDefaultClubAnalysis()
        }
        
        // Analyze club throughout swing
        let avgShaftAngle = clubPoses.reduce(0.0) { $0 + $1.clubInfo.shaftAngle } / Double(clubPoses.count)
        let avgClubfaceAngle = clubPoses.reduce(0.0) { $0 + $1.clubInfo.clubfaceAngle } / Double(clubPoses.count)
        
        // Find impact pose for impact analysis
        let impactPose = golfPoses.first { $0.swingPhase == .impact }
        let impactShaftAngle = impactPose?.clubInfo.shaftAngle ?? avgShaftAngle
        
        // Create club path
        let clubPath = clubPoses.compactMap { pose -> GolfPoint? in
            guard let firstPoint = pose.clubInfo.path.first else { return nil }
            return GolfPoint(x: Double(firstPoint.x), y: Double(firstPoint.y), timestamp: pose.timestamp)
        }
        
        // Analyze grip from poses
        let gripAnalysis = analyzeGripFromPoses(clubPoses)
        
        return GolfClubAnalysisData(
            club_detected: true,
            club_type: clubPoses.first?.clubInfo.clubType.rawValue ?? "unknown",
            shaft_angle_at_impact: impactShaftAngle,
            club_face_angle: avgClubfaceAngle,
            club_path: clubPath,
            grip_analysis: gripAnalysis,
            club_face_analysis: createClubFaceAnalysis(avgClubfaceAngle),
            club_speed_analysis: createClubSpeedAnalysis(clubPath)
        )
    }
    
    private func generateGolfRecommendations(phases: [GolfSwingPhase], biomechanics: GolfBiomechanicsData, club: GolfClubAnalysisData) -> [GolfRecommendation] {
        var recommendations: [GolfRecommendation] = []
        
        // Posture recommendations
        if biomechanics.spine_angle < 20 {
            recommendations.append(GolfRecommendation(
                category: "posture",
                priority: 1,
                title: "Improve Spine Angle",
                description: "Your spine angle is too upright. Bend more from your hips to create proper golf posture.",
                drill_suggestion: "Practice the 'butt against the wall' drill"
            ))
        } else if biomechanics.spine_angle > 50 {
            recommendations.append(GolfRecommendation(
                category: "posture",
                priority: 1,
                title: "Reduce Spine Angle",
                description: "You're bending over too much. Stand up slightly for better balance and power.",
                drill_suggestion: "Practice with a club across your chest"
            ))
        }
        
        // Grip recommendations
        if club.grip_analysis.grip_consistency < 0.7 {
            recommendations.append(GolfRecommendation(
                category: "grip",
                priority: 2,
                title: "Improve Grip Consistency",
                description: "Your grip changes during the swing. Focus on maintaining consistent hand position.",
                drill_suggestion: "Practice slow swings focusing only on grip"
            ))
        }
        
        // Tempo recommendations
        if biomechanics.tempo_ratio < 2.5 || biomechanics.tempo_ratio > 4.0 {
            recommendations.append(GolfRecommendation(
                category: "tempo",
                priority: 2,
                title: "Improve Swing Tempo",
                description: "Your swing tempo ratio is outside the ideal 3:1 range. Work on smooth transition.",
                drill_suggestion: "Practice with a metronome or count '1-2-3' for tempo"
            ))
        }
        
        return recommendations.sorted { $0.priority < $1.priority }
    }
    
    // MARK: - Helper Analysis Functions
    
    private func classifySwing(biomechanics: GolfBiomechanicsData, club: GolfClubAnalysisData, phases: [GolfSwingPhase]) -> (label: String, confidence: Double) {
        // Golf AI swing classification based on comprehensive analysis
        
        let swingPlane = biomechanics.swing_plane_angle
        let confidence: Double
        let label: String
        
        if swingPlane > 60 {
            label = "too_steep"
            confidence = min(0.9, (swingPlane - 45) / 20)
        } else if swingPlane < 35 {
            label = "too_flat" 
            confidence = min(0.9, (45 - swingPlane) / 15)
        } else if biomechanics.hip_rotation < biomechanics.shoulder_rotation * 0.6 {
            label = "over_the_top"
            confidence = 0.8
        } else if biomechanics.hip_rotation > biomechanics.shoulder_rotation * 1.2 {
            label = "inside_out"
            confidence = 0.75
        } else {
            // Check overall quality
            let qualityFactors = [
                biomechanics.balance_score / 100,
                biomechanics.tempo_ratio / 3.0,
                Double(club.grip_analysis.grip_consistency),
                phases.reduce(0.0) { $0 + $1.quality_score } / Double(max(phases.count, 1))
            ]
            
            let avgQuality = qualityFactors.reduce(0) { $0 + $1 } / Double(qualityFactors.count)
            
            if avgQuality > 0.8 {
                label = "perfect"
                confidence = avgQuality
            } else {
                label = "needs_improvement"
                confidence = 0.7
            }
        }
        
        return (label, confidence)
    }
    
    private func calculateGolfPerformanceScore(phases: [GolfSwingPhase], biomechanics: GolfBiomechanicsData, club: GolfClubAnalysisData) -> Double {
        // Calculate overall performance score from 0-100
        var score = 100.0
        
        // Posture scoring
        if biomechanics.spine_angle < 20 || biomechanics.spine_angle > 50 {
            score -= 15
        }
        
        // Tempo scoring
        if biomechanics.tempo_ratio < 2.5 || biomechanics.tempo_ratio > 4.0 {
            score -= 10
        }
        
        // Balance scoring
        score -= (100 - biomechanics.balance_score) * 0.2
        
        // Grip scoring
        if club.grip_analysis.grip_consistency < 0.7 {
            score -= 10
        }
        
        // Phase quality scoring
        let avgPhaseQuality = phases.reduce(0.0) { $0 + $1.quality_score } / Double(max(phases.count, 1))
        score *= avgPhaseQuality
        
        return max(0, min(100, score))
    }
    
    // MARK: - Golf AI Helper Functions
    
    private func createDefaultBiomechanics() -> GolfBiomechanicsData {
        return GolfBiomechanicsData(
            spine_angle: 35.0,
            hip_rotation: 45.0,
            shoulder_rotation: 90.0,
            weight_transfer: GolfWeightTransfer(
                left_percentage: 50,
                right_percentage: 50,
                transfer_quality: "needs_work",
                center_of_gravity_path: []
            ),
            posture_rating: "fair",
            tempo_ratio: 3.0,
            swing_plane_angle: 45.0,
            balance_score: 70.0,
            camera_angle: "side",
            angle_confidence: 0.5,
            feature_reliability: [:],
            physics_summary: "Basic analysis completed",
            posture_insights: "Standard posture detected",
            video_duration: 0.0
        )
    }
    
    private func createDefaultClubAnalysis() -> GolfClubAnalysisData {
        return GolfClubAnalysisData(
            club_detected: false,
            club_type: "unknown",
            shaft_angle_at_impact: 0.0,
            club_face_angle: 0.0,
            club_path: [],
            grip_analysis: GolfGripAnalysis(
                grip_strength: "neutral",
                grip_position: "correct",
                grip_consistency: 0.5,
                hand_separation: 0.1
            ),
            club_face_analysis: nil,
            club_speed_analysis: nil
        )
    }
    
    private func analyzeWeightTransferSequence(_ golfPoses: [GolfPoseResult]) -> GolfWeightTransfer {
        var cogPath: [GolfPoint] = []
        var totalLeft = 0.0
        var totalRight = 0.0
        
        for pose in golfPoses {
            let weightTransfer = pose.biomechanics.weightTransfer
            totalLeft += weightTransfer.leftPercentage
            totalRight += weightTransfer.rightPercentage
            
            cogPath.append(GolfPoint(
                x: Double(weightTransfer.centerOfGravity.x),
                y: Double(weightTransfer.centerOfGravity.y),
                timestamp: pose.timestamp
            ))
        }
        
        let avgLeft = totalLeft / Double(golfPoses.count)
        let avgRight = totalRight / Double(golfPoses.count)
        
        // Determine quality based on weight transfer pattern
        let quality: String
        if abs(avgLeft - 50) < 10 && abs(avgRight - 50) < 10 {
            quality = "excellent"
        } else if abs(avgLeft - 50) < 20 && abs(avgRight - 50) < 20 {
            quality = "good"
        } else {
            quality = "needs_work"
        }
        
        return GolfWeightTransfer(
            left_percentage: avgLeft,
            right_percentage: avgRight,
            transfer_quality: quality,
            center_of_gravity_path: cogPath
        )
    }
    
    private func determineCameraAngle(_ golfPoses: [GolfPoseResult]) -> String {
        // Analyze keypoint visibility patterns to determine camera angle
        var faceKeypointsCount = 0
        var sideKeypointsCount = 0
        
        for pose in golfPoses {
            for keypoint in pose.keypoints {
                switch keypoint.type {
                case .head, .leftEye, .rightEye:
                    if keypoint.confidence > 0.5 {
                        faceKeypointsCount += 1
                    }
                case .leftShoulder, .rightShoulder:
                    if abs(keypoint.position.x - 0.5) > 0.1 {
                        sideKeypointsCount += 1
                    }
                default:
                    break
                }
            }
        }
        
        if faceKeypointsCount > sideKeypointsCount {
            return "front"
        } else if sideKeypointsCount > faceKeypointsCount * 2 {
            return "side"
        } else {
            return "back"
        }
    }
    
    private func calculateFeatureReliability(_ golfPoses: [GolfPoseResult]) -> [String: Double] {
        var reliability: [String: Double] = [:]
        
        // Calculate reliability for key features
        let keypointTypes: [GolfKeypoint.GolfKeypointType] = [
            .leftWrist, .rightWrist, .leftShoulder, .rightShoulder, 
            .leftHip, .rightHip, .leftKnee, .rightKnee
        ]
        
        for keypointType in keypointTypes {
            let confidences = golfPoses.compactMap { pose in
                pose.keypoints.first { $0.type == keypointType }?.confidence
            }
            
            if !confidences.isEmpty {
                let avgConfidence = confidences.reduce(0) { $0 + $1 } / Float(confidences.count)
                reliability[String(describing: keypointType)] = Double(avgConfidence)
            }
        }
        
        return reliability
    }
    
    private func generatePhysicsInsights(spineAngle: Double, hipRotation: Double, shoulderTurn: Double, weightTransfer: GolfWeightTransfer) -> String {
        var insights: [String] = []
        
        if spineAngle > 45 {
            insights.append("Spine angle (\(String(format: "%.1f", spineAngle))°) promotes power generation")
        } else if spineAngle < 30 {
            insights.append("Consider increasing spine angle for better posture")
        }
        
        if shoulderTurn > hipRotation * 1.5 {
            insights.append("Good shoulder-hip separation creates coil for power")
        } else {
            insights.append("Work on shoulder turn relative to hips for more power")
        }
        
        if weightTransfer.transfer_quality == "excellent" {
            insights.append("Excellent weight transfer throughout swing")
        } else {
            insights.append("Focus on weight shift for better balance and power")
        }
        
        return insights.joined(separator: ". ")
    }
    
    private func generatePostureInsights(spineAngle: Double, poses: [GolfPoseResult]) -> String {
        var insights: [String] = []
        
        if spineAngle >= 20 && spineAngle <= 45 {
            insights.append("Good spine angle for golf posture")
        } else if spineAngle < 20 {
            insights.append("Too upright - bend more from hips")
        } else {
            insights.append("Too bent over - stand up slightly")
        }
        
        // Check posture consistency
        let spineAngles = poses.map { $0.biomechanics.spineAngle }
        let variation = spineAngles.max()! - spineAngles.min()!
        
        if variation < 10 {
            insights.append("Consistent posture throughout swing")
        } else {
            insights.append("Work on maintaining consistent posture")
        }
        
        return insights.joined(separator: ". ")
    }
    
    private func ratePosture(_ avgSpineAngle: Double, _ poses: [GolfPoseResult]) -> String {
        if avgSpineAngle >= 25 && avgSpineAngle <= 40 {
            return "excellent"
        } else if avgSpineAngle >= 20 && avgSpineAngle <= 45 {
            return "good"
        } else if avgSpineAngle >= 15 && avgSpineAngle <= 50 {
            return "fair"
        } else {
            return "needs_work"
        }
    }
    
    private func calculateSwingPlaneFromGolfPoses(_ golfPoses: [GolfPoseResult]) -> Double {
        // Calculate swing plane from golf poses
        guard !golfPoses.isEmpty else { return 45.0 }
        
        var totalAngle = 0.0
        var count = 0
        
        for pose in golfPoses where pose.swingPhase == .backswing || pose.swingPhase == .downswing {
            // Use shoulder positions to estimate swing plane
            if let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder }),
               let rightShoulder = pose.keypoints.first(where: { $0.type == .rightShoulder }) {
                
                let shoulderLine = CGPoint(
                    x: rightShoulder.position.x - leftShoulder.position.x,
                    y: rightShoulder.position.y - leftShoulder.position.y
                )
                
                let angle = atan2(shoulderLine.y, shoulderLine.x) * 180 / .pi
                totalAngle += abs(Double(angle))
                count += 1
            }
        }
        
        return count > 0 ? totalAngle / Double(count) : 45.0
    }
    
    private func calculateBalanceScore(_ golfPoses: [GolfPoseResult]) -> Double {
        guard !golfPoses.isEmpty else { return 70.0 }
        
        var totalBalance = 0.0
        
        for pose in golfPoses {
            let weightTransfer = pose.biomechanics.weightTransfer
            let centeredness = abs(weightTransfer.leftPercentage - weightTransfer.rightPercentage)
            let balanceScore = max(0, 100 - centeredness * 2)
            totalBalance += balanceScore
        }
        
        return totalBalance / Double(golfPoses.count)
    }
    
    private func calculateAngleConfidence(_ golfPoses: [GolfPoseResult]) -> Float {
        guard !golfPoses.isEmpty else { return 0.5 }
        
        let totalConfidence = golfPoses.reduce(0.0) { $0 + Double($1.confidence) }
        return Float(totalConfidence / Double(golfPoses.count))
    }
    
    private func analyzeGripFromPoses(_ clubPoses: [GolfPoseResult]) -> GolfGripAnalysis {
        guard !clubPoses.isEmpty else {
            return GolfGripAnalysis(grip_strength: "neutral", grip_position: "correct", grip_consistency: 0.5, hand_separation: 0.1)
        }
        
        var totalConsistency = 0.0
        var totalSeparation = 0.0
        
        for pose in clubPoses {
            totalConsistency += Double(pose.confidence)
            // Calculate hand separation from wrist positions
            if let leftWrist = pose.keypoints.first(where: { $0.type == .leftWrist }),
               let rightWrist = pose.keypoints.first(where: { $0.type == .rightWrist }) {
                let separation = sqrt(
                    pow(leftWrist.position.x - rightWrist.position.x, 2) +
                    pow(leftWrist.position.y - rightWrist.position.y, 2)
                )
                totalSeparation += Double(separation)
            }
        }
        
        let avgConsistency = totalConsistency / Double(clubPoses.count)
        let avgSeparation = totalSeparation / Double(clubPoses.count)
        
        return GolfGripAnalysis(
            grip_strength: "neutral", // Would require more complex analysis
            grip_position: avgSeparation < 0.08 ? "tooNarrow" : avgSeparation > 0.12 ? "tooWide" : "correct",
            grip_consistency: avgConsistency,
            hand_separation: avgSeparation
        )
    }
    
    private func createClubFaceAnalysis(_ avgClubfaceAngle: Double) -> ClubFaceAnalysis {
        let rating: String
        if abs(avgClubfaceAngle) < 2.0 {
            rating = "Square"
        } else if abs(avgClubfaceAngle) < 5.0 {
            rating = avgClubfaceAngle > 0 ? "Slightly Open" : "Slightly Closed"
        } else {
            rating = avgClubfaceAngle > 0 ? "Very Open" : "Very Closed"
        }
        
        return ClubFaceAnalysis(
            face_angle_at_impact: avgClubfaceAngle,
            face_angle_rating: rating,
            consistency_score: max(0, 100 - abs(avgClubfaceAngle) * 10),
            impact_position: ImpactPosition(
                toe_heel_impact: "Center",
                high_low_impact: "Center",
                impact_quality_score: 85.0
            ),
            recommendations: generateClubFaceRecommendations(avgClubfaceAngle),
            elite_benchmark: SwingEliteBenchmark(
                elite_average: 0.0,
                amateur_average: 3.5,
                your_percentile: max(0, min(100, 100 - abs(avgClubfaceAngle) * 20)),
                comparison_text: "Your face angle is \(String(format: "%.1f", abs(avgClubfaceAngle)))° from square"
            )
        )
    }
    
    private func createClubSpeedAnalysis(_ clubPath: [GolfPoint]) -> ClubSpeedAnalysis {
        guard clubPath.count >= 2 else {
            return ClubSpeedAnalysis(
                club_head_speed_mph: 0,
                speed_rating: "Below Average",
                acceleration_profile: AccelerationProfile(
                    backswing_speed: 0,
                    transition_speed: 0,
                    impact_speed: 0,
                    deceleration_after_impact: 0,
                    acceleration_efficiency: 0
                ),
                tempo_analysis: TempoAnalysis(
                    backswing_time: 0,
                    downswing_time: 0,
                    tempo_ratio: 3.0,
                    tempo_rating: "Good",
                    pause_at_top: 0
                ),
                efficiency_metrics: EfficiencyMetrics(
                    swing_efficiency: 0,
                    energy_loss_points: [],
                    smash_factor: 0,
                    centeredness_of_contact: 0
                ),
                distance_potential: DistancePotential(
                    current_estimated_distance: 0,
                    optimal_distance_potential: 0,
                    distance_gain_opportunities: []
                ),
                elite_benchmark: SwingEliteBenchmark(
                    elite_average: 120,
                    amateur_average: 90,
                    your_percentile: 50,
                    comparison_text: "No club speed data available"
                )
            )
        }
        
        // Calculate speed from path points
        var speeds: [Double] = []
        for i in 1..<clubPath.count {
            let prev = clubPath[i-1]
            let curr = clubPath[i]
            let distance = sqrt(pow(curr.x - prev.x, 2) + pow(curr.y - prev.y, 2))
            let time = curr.timestamp - prev.timestamp
            if time > 0 {
                speeds.append(distance / time)
            }
        }
        
        let avgSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let estimatedMPH = avgSpeed * 100 // Rough conversion for demo
        
        let speedRating: String
        if estimatedMPH < 80 {
            speedRating = "Below Average"
        } else if estimatedMPH < 100 {
            speedRating = "Average"
        } else if estimatedMPH < 120 {
            speedRating = "Above Average"
        } else {
            speedRating = "Tour Level"
        }
        
        return ClubSpeedAnalysis(
            club_head_speed_mph: estimatedMPH,
            speed_rating: speedRating,
            acceleration_profile: AccelerationProfile(
                backswing_speed: estimatedMPH * 0.3,
                transition_speed: estimatedMPH * 0.5,
                impact_speed: estimatedMPH,
                deceleration_after_impact: estimatedMPH * 0.7,
                acceleration_efficiency: max(0, min(100, estimatedMPH * 0.8))
            ),
            tempo_analysis: TempoAnalysis(
                backswing_time: 1.0,
                downswing_time: 0.3,
                tempo_ratio: 3.3,
                tempo_rating: "Good",
                pause_at_top: 0.1
            ),
            efficiency_metrics: EfficiencyMetrics(
                swing_efficiency: max(0, min(100, estimatedMPH * 0.75)),
                energy_loss_points: estimatedMPH < 90 ? ["Early release", "Poor weight transfer"] : [],
                smash_factor: 1.45,
                centeredness_of_contact: max(0, min(100, estimatedMPH * 0.9))
            ),
            distance_potential: DistancePotential(
                current_estimated_distance: estimatedMPH * 2.5,
                optimal_distance_potential: estimatedMPH * 2.8,
                distance_gain_opportunities: [
                    DistanceGainOpportunity(
                        improvement_area: "Club speed",
                        potential_yards_gained: 15,
                        difficulty_level: "Moderate",
                        practice_recommendation: "Focus on hip rotation and weight transfer"
                    )
                ]
            ),
            elite_benchmark: SwingEliteBenchmark(
                elite_average: 120,
                amateur_average: 90,
                your_percentile: max(0, min(100, (estimatedMPH / 90) * 50)),
                comparison_text: "Your club speed is \(String(format: "%.0f", (estimatedMPH / 90 - 1) * 100))% \(estimatedMPH > 90 ? "above" : "below") amateur average"
            )
        )
    }
    
    private func generateClubFaceRecommendations(_ angle: Double) -> [String] {
        var recs: [String] = []
        
        if abs(angle) < 3 {
            recs.append("Excellent clubface control")
        } else if angle > 3 {
            recs.append("Clubface is open - strengthen grip or focus on release")
        } else {
            recs.append("Clubface is closed - weaken grip or delay release")
        }
        
        return recs
    }
    
    private func analyzeWithMediaPipePoses(_ poses: [MediaPipePoseResult], videoURL: URL) async throws -> SwingAnalysisResponse {
        print("🦴 MediaPipe detected poses in \(poses.count) frames")
        
        // Critical debug: Check if we have any poses at all
        if poses.isEmpty {
            print("❌ CRITICAL: No poses detected from MediaPipe!")
            throw LocalAnalysisError.noPosesDetected("No body poses detected in the video. This could be due to:\n\n• Poor lighting or image quality\n• Golfer not clearly visible in frame\n• Camera too far from subject\n• Complex background interfering with detection\n\nTry:\n• Better lighting conditions\n• Closer camera position (6-12 feet)\n• Plain background\n• Clear view of full body")
        } else if poses.count < 2 {
            print("❌ CRITICAL: Very few poses detected (\(poses.count)) - insufficient for analysis")
            throw LocalAnalysisError.insufficientPoseData
        }
        
        // Detect camera angle and adapt analysis accordingly - moved outside conditional block
        let isBackView = isLikelyBackViewRecording(poses: poses.map { $0.asPoseData })
        
        if poses.count >= 2 {
            if isBackView {
                print("📐 Detected back-view recording - adapting analysis...")
            } else {
                print("📐 Detected side/front-view recording - using standard analysis...")
                
                // For non-back-view recordings, ensure we have adequate pose detection
                // Check if pose quality is too poor for analysis
                let totalKeypoints = poses.reduce(0) { $0 + $1.landmarks.count }
                let avgKeypointsPerPose = Double(totalKeypoints) / Double(poses.count)
                
                if avgKeypointsPerPose < 2.0 { // Very few keypoints detected
                    print("❌ CRITICAL: Poor pose detection quality - avg \(String(format: "%.1f", avgKeypointsPerPose)) keypoints per pose")
                    throw LocalAnalysisError.poorVideoQuality
                }
            }
            print("✅ Sufficient poses detected for analysis")
            // Sample keypoint data from first and middle poses
            let firstPose = poses[0]
            let middlePose = poses[poses.count / 2]
            print("🔍 First pose keypoints: \(firstPose.landmarks.count)")
            print("🔍 Middle pose keypoints: \(middlePose.landmarks.count)")
            
            // Check for critical keypoints
            let firstWrist = firstPose.asPoseData.keypoints.first { $0.type == .leftWrist }
            let middleWrist = middlePose.asPoseData.keypoints.first { $0.type == .leftWrist }
            if let fw = firstWrist, let mw = middleWrist {
                print("🔍 Found wrist keypoints - First: (\(String(format: "%.3f", fw.position.x)), \(String(format: "%.3f", fw.position.y))), Middle: (\(String(format: "%.3f", mw.position.x)), \(String(format: "%.3f", mw.position.y)))")
            } else {
                print("❌ CRITICAL: Missing wrist keypoints in poses!")
            }
        }
        
        // Extract physics-based features with camera angle adaptation
        var features = featureExtractor.extractFeatures(from: poses.map { $0.asPoseData }, cameraAngle: isBackView ? .back : .side)
        print("📊 Extracted \(features.count) physics features (camera angle: \(isBackView ? "back" : "side"))")
        
        // Debug: Print key features for troubleshooting
        if features.count >= 35 {
            print("🔍 Debug - Key features: Spine=\(String(format: "%.1f", features[0])), MaxShoulder=\(String(format: "%.1f", features[5])), PlaneAngle=\(String(format: "%.1f", features[8])), Tempo=\(String(format: "%.1f", features[17]))")
            
            // Handle swing plane calculation failure
            if features[8] == 0.0 {
                print("❌ CRITICAL: Swing plane calculation failed - attempting alternative calculation")
                
                // Try alternative swing plane calculation
                do {
                    let alternativeAngle = try calculateAlternativeSwingPlane(poses: poses.map { $0.asPoseData })
                    features[8] = alternativeAngle
                    print("🔧 Alternative swing plane angle: \(String(format: "%.1f", alternativeAngle))°")
                } catch {
                    print("❌ Both primary and alternative swing plane calculations failed")
                    throw LocalAnalysisError.noValidSwingMotionDetected
                }
            }
        }
        
        // Run inference (simplified for now)
        let prediction = try await runInference(features: features)
        
        // Store features for feedback collection
        self.lastPredictionFeatures = features
        
        // Create response with camera angle information
        return createLocalResponse(prediction: prediction, features: features, cameraAngle: isBackView ? .back : .side)
    }
    
    private func extractFrames(from videoURL: URL) async throws -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let frameRate = 15.0 // Reduced frame rate to prevent memory issues
        
        var frames: [UIImage] = []
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let totalSeconds = CMTimeGetSeconds(duration)
        let frameCount = min(Int(totalSeconds * frameRate), 100) // Cap at 100 frames max
        
        print("📊 Extracting \(frameCount) frames from \(String(format: "%.1f", totalSeconds))s video")
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / frameRate, preferredTimescale: 600)
            
            do {
                let result = try await generator.image(at: time)
                let image = UIImage(cgImage: result.image)
                frames.append(image)
            } catch {
                print("⚠️ Failed to extract frame at \(i): \(error)")
            }
            
            // Yield control periodically
            if i % 10 == 0 {
                await Task.yield()
            }
        }
        
        print("✅ Successfully extracted \(frames.count) frames")
        return frames
    }
    
    
    private func runInference(features: [Double]) async throws -> SwingPrediction {
        guard let model = swingAnalysisModel else {
            throw LocalAnalysisError.modelNotLoaded
        }
        
        return try await runRealMLInference(model: model, features: features)
    }
    
    private func runRealMLInference(model: SwingAnalysisModelWrapper, features: [Double]) async throws -> SwingPrediction {
        print("🤖 Running Core ML inference with production model")
        
        // Ensure we have 35 features
        guard features.count == 35 else {
            throw LocalAnalysisError.invalidFeatureCount
        }
        
        // Run prediction using the model wrapper in a detached task to avoid main actor isolation
        do {
            let (predictedLabel, confidence) = try await Task.detached {
                return try await model.predict(features: features)
            }.value
            
            // Extract key features for reporting
            let planeAngle = features[8]  // swing_plane_angle is at index 8
            let tempo = features[32]       // overall_tempo is at index 32
            
            print("✅ Core ML prediction: \(predictedLabel) (confidence: \(String(format: "%.2f", confidence)))")
            print("   Swing plane: \(String(format: "%.1f", planeAngle))°, Tempo: \(String(format: "%.1f", tempo))")
            
            return SwingPrediction(
                label: predictedLabel,
                confidence: confidence,
                planeAngle: planeAngle,
                tempo: tempo
            )
            
        } catch {
            print("❌ Core ML inference failed: \(error)")
            print("🔄 Falling back to rule-based prediction...")
            
            // Fallback to rule-based prediction if ML fails
            return createFallbackPrediction(features: features)
        }
    }
    
    private func createFallbackPrediction(features: [Double]) -> SwingPrediction {
        print("🎯 Creating rule-based fallback prediction")
        
        // Extract key features for rule-based analysis
        // Note: features array is validated to have exactly 35 elements before reaching this point
        let planeAngle = features[8]
        let tempo = features[32]
        
        // Simple rule-based classification
        let (label, confidence) = classifySwingByRules(planeAngle: planeAngle, tempo: tempo)
        
        print("🎯 Fallback prediction: \(label) (confidence: \(String(format: "%.2f", confidence)))")
        
        return SwingPrediction(
            label: label,
            confidence: confidence,
            planeAngle: planeAngle,
            tempo: tempo
        )
    }
    
    private func classifySwingByRules(planeAngle: Double, tempo: Double) -> (String, Double) {
        // Dynamic rule-based classification with variable confidence
        let optimalPlaneAngle = 42.0 // Ideal swing plane
        let optimalTempo = 3.0 // Ideal tempo ratio
        
        // Calculate confidence based on how close to optimal values
        let planeDeviation = abs(planeAngle - optimalPlaneAngle) / optimalPlaneAngle
        let tempoDeviation = abs(tempo - optimalTempo) / optimalTempo
        
        // Combined deviation score (lower is better)
        let combinedDeviation = (planeDeviation + tempoDeviation) / 2
        
        // Convert to confidence (higher is better)
        let baseConfidence = max(0.5, 1.0 - combinedDeviation)
        
        // Classify based on plane angle
        if planeAngle < 30 {
            let confidence = baseConfidence * 0.85 // Slightly lower for extreme angles
            return ("too_flat", min(0.95, max(0.55, confidence)))
        } else if planeAngle > 55 {
            let confidence = baseConfidence * 0.80 // Lower for steep swings
            return ("too_steep", min(0.90, max(0.50, confidence)))
        } else {
            // Good swing range - higher base confidence
            let confidence = baseConfidence * 1.1 + 0.05 // Bonus for good range
            return ("good_swing", min(0.95, max(0.60, confidence)))
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
    
    private func createDetailedGuidance(prediction: SwingPrediction, spineAngle: Double, kneeFlexion: Double, stanceWidth: Double, cameraAngle: CameraAngle) -> (String, String, [String]) {
        var physicsInsights = ""
        var stanceGuidance = ""
        var recommendations: [String] = []
        
        // Camera-angle specific swing analysis
        let cameraAnglePrefix = cameraAngle == .back ? "📐 Back view analysis" : "📐 Side view analysis"
        
        if cameraAngle == .back {
            // Back view analysis focuses on what's visible: shoulder rotation, body turn, grip
            switch prediction.label {
            case "too_steep":
                physicsInsights = "\(cameraAnglePrefix): Your shoulder turn shows a steep swing plane at \(Int(prediction.planeAngle))°. From this back view, I can see excessive vertical motion. This can cause pulls and slices."
                recommendations.append("Focus on more horizontal shoulder rotation")
                recommendations.append("Turn around your spine rather than lifting")
                recommendations.append("Practice shallow backswing with mirror behind you")
            case "too_flat":
                physicsInsights = "\(cameraAnglePrefix): Your shoulder turn shows a flat swing plane at \(Int(prediction.planeAngle))°. From this back view, I can see excessive horizontal motion. This can cause hooks and thin shots."
                recommendations.append("Add more vertical component to your turn")
                recommendations.append("Practice more upright shoulder rotation")
                recommendations.append("Focus on lifting arms while turning shoulders")
            default:
                physicsInsights = "\(cameraAnglePrefix): Good shoulder turn and body rotation at \(Int(prediction.planeAngle))°. Your body movement shows consistent swing plane. From behind, your turn looks balanced."
                recommendations.append("Maintain your current shoulder turn consistency")
                recommendations.append("Continue this balanced rotation pattern")
            }
        } else {
            // Side view analysis shows traditional swing plane, arc, and positions
            switch prediction.label {
            case "too_steep":
                physicsInsights = "\(cameraAnglePrefix): Your swing plane is \(Int(prediction.planeAngle))° (too steep). From the side, I can see an over-the-top move. This causes pulls, slices, and inconsistent contact."
                recommendations.append("Practice shallowing the club in transition")
                recommendations.append("Focus on rotating rather than lifting in backswing")
                recommendations.append("Work on inside-out swing path")
            case "too_flat":
                physicsInsights = "\(cameraAnglePrefix): Your swing plane is \(Int(prediction.planeAngle))° (too flat). From the side, your swing arc looks too shallow. This causes hooks, thin shots, and loss of distance."
                recommendations.append("Work on a more upright backswing plane")
                recommendations.append("Practice steeper shoulder turn")
                recommendations.append("Focus on proper swing arc height")
            default:
                physicsInsights = "\(cameraAnglePrefix): Good swing plane at \(Int(prediction.planeAngle))°. Your swing arc and positions look consistent from the side. This is within the ideal range of 35-45°."
                recommendations.append("Maintain your current swing plane consistency")
                recommendations.append("Continue working on consistent arc")
            }
        }
        
        // Camera-angle specific stance and setup analysis
        var stanceIssues: [String] = []
        var stanceAdvice: [String] = []
        
        if cameraAngle == .back {
            // Back view: Focus on posture, balance, and what's reliably visible
            
            // Posture analysis (visible from back)
            if spineAngle < 20 {
                stanceIssues.append("posture too upright from back view")
                stanceAdvice.append("More forward tilt visible - bend from hips")
                recommendations.append("From back view: you appear too upright - bend forward more from hips")
            } else if spineAngle > 35 {
                stanceIssues.append("too much forward bend from back view")
                stanceAdvice.append("Stand more upright - too much spine tilt")
                recommendations.append("From back view: too much forward bend - stand taller")
            } else {
                stanceAdvice.append("good posture from back view")
            }
            
            // Balance and stability (what's visible from behind)
            stanceAdvice.append("Hand placement appears centered")
            stanceAdvice.append("Body balance looks stable from behind")
            
            // Note: Avoid stance width analysis from back view as it's less reliable
            
        } else {
            // Side view: Full traditional stance analysis
            
            // Spine angle analysis
            if spineAngle < 20 {
                stanceIssues.append("spine too upright")
                stanceAdvice.append("Bend forward more from hips at address")
                recommendations.append("Improve posture: bend forward from hips, not waist")
            } else if spineAngle > 35 {
                stanceIssues.append("spine too bent over")
                stanceAdvice.append("Stand more upright at address")
                recommendations.append("Stand taller: less bend from hips")
            } else {
                stanceAdvice.append("good spine angle")
            }
            
            // Knee flexion analysis
            if kneeFlexion < 15 {
                stanceIssues.append("knees too straight")
                stanceAdvice.append("Add more knee flex for better balance")
                recommendations.append("Flex knees more for athletic posture")
            } else if kneeFlexion > 30 {
                stanceIssues.append("knees too bent")
                stanceAdvice.append("Straighten legs slightly")
            } else {
                stanceAdvice.append("good knee flex")
            }
            
            // Stance width analysis (reliable from side view)
            if stanceWidth < 0.3 {
                stanceIssues.append("stance too narrow")
                stanceAdvice.append("Widen your stance for better stability")
                recommendations.append("Widen stance to shoulder-width apart")
            } else if stanceWidth > 0.7 {
                stanceIssues.append("stance too wide")
                stanceAdvice.append("Narrow your stance slightly")
            } else {
                stanceAdvice.append("good stance width")
            }
        }
        
        // Create stance guidance summary
        if stanceIssues.isEmpty {
            stanceGuidance = "Setup analysis: " + stanceAdvice.joined(separator: ", ") + ". Your fundamentals look solid!"
        } else {
            stanceGuidance = "Setup analysis: Focus on improving " + stanceIssues.joined(separator: " and ") + ". " + stanceAdvice.joined(separator: ". ")
        }
        
        // Add general recommendations
        recommendations.append("Practice setup routine for consistency")
        
        // Add premium feature teaser
        if !stanceIssues.isEmpty {
            recommendations.append("🔒 Get detailed biomechanics analysis with Premium")
        }
        recommendations.append("🔒 Unlock club speed and face angle analysis")
        
        return (physicsInsights, stanceGuidance, recommendations)
    }
    
    private func createLocalResponse(prediction: SwingPrediction, features: [Double], cameraAngle: CameraAngle) -> SwingAnalysisResponse {
        let probabilities = [
            prediction.label: prediction.confidence,
            "other": 1.0 - prediction.confidence
        ]
        
        // Extract stance and setup analysis from features
        // Note: features array is validated to have exactly 35 elements before reaching this point
        let spineAngle = features[0]
        let kneeFlexion = features[1] 
        let stanceWidth = features[4]
        
        // Create camera-angle specific detailed guidance
        let (physicsInsights, stanceGuidance, recommendations) = createDetailedGuidance(
            prediction: prediction,
            spineAngle: spineAngle,
            kneeFlexion: kneeFlexion,
            stanceWidth: stanceWidth,
            cameraAngle: cameraAngle
        )
        
        return SwingAnalysisResponse(
            predicted_label: prediction.label,
            confidence: prediction.confidence,
            confidence_gap: prediction.confidence - 0.5,
            all_probabilities: probabilities,
            camera_angle: cameraAngle == .back ? "back_view" : "side_view",
            angle_confidence: 0.8,
            feature_reliability: nil,
            club_face_analysis: nil,
            club_speed_analysis: nil,
            premium_features_available: true, // Show premium features are available
            physics_insights: physicsInsights,
            angle_insights: stanceGuidance,
            recommendations: recommendations,
            extraction_status: "success",
            analysis_type: "local",
            model_version: "local_v1.0",
            plane_angle: prediction.planeAngle,
            tempo_ratio: prediction.tempo
        )
    }
    
    
    // Alternative swing plane calculation when primary method fails
    private func calculateAlternativeSwingPlane(poses: [PoseData]) throws -> Double {
        print("🔄 Attempting alternative swing plane calculation...")
        
        guard poses.count >= 2 else {
            print("❌ Alternative: Not enough poses")
            throw LocalAnalysisError.insufficientPoseData
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
        
        // No fallback values - if we can't detect real swing motion, fail the analysis
        
        throw LocalAnalysisError.noValidSwingMotionDetected
    }
    
    func getCurrentPredictionForFeedback() -> [Double]? {
        return lastPredictionFeatures
    }
    
    // MARK: - Golf AI Conversion Helpers
    
    private func convertToGolfKeypoints(_ standardKeypoints: [PoseKeypoint]) -> [GolfKeypoint] {
        return standardKeypoints.compactMap { keypoint in
            let golfType: GolfKeypoint.GolfKeypointType?
            
            switch keypoint.type {
            case .nose:
                golfType = .head
            case .leftShoulder:
                golfType = .leftShoulder
            case .rightShoulder:
                golfType = .rightShoulder
            case .leftElbow:
                golfType = .leftElbow
            case .rightElbow:
                golfType = .rightElbow
            case .leftWrist:
                golfType = .leftWrist
            case .rightWrist:
                golfType = .rightWrist
            case .leftHip:
                golfType = .leftHip
            case .rightHip:
                golfType = .rightHip
            case .leftKnee:
                golfType = .leftKnee
            case .rightKnee:
                golfType = .rightKnee
            case .leftAnkle:
                golfType = .leftAnkle
            case .rightAnkle:
                golfType = .rightAnkle
            default:
                golfType = nil
            }
            
            guard let type = golfType else { return nil }
            
            return GolfKeypoint(
                type: type,
                position: keypoint.position,
                confidence: keypoint.confidence
            )
        }
    }
    
    // MARK: - Golf-Specific Camera Angle Detection
    
    private func isLikelyBackViewRecording(poses: [PoseData]) -> Bool {
        print("⛳ Analyzing poses to detect golf camera angle...")
        
        var faceKeypointsCount = 0
        var bodyKeypointsCount = 0
        var backViewIndicators = 0
        var sideViewIndicators = 0
        var totalFramesAnalyzed = 0
        
        // Analyze a sample of poses (up to 10 frames)
        let sampleSize = min(10, poses.count)
        let step = max(1, poses.count / sampleSize)
        
        for i in stride(from: 0, to: poses.count, by: step) {
            let pose = poses[i]
            totalFramesAnalyzed += 1
            
            // Count face keypoints (nose, eyes, ears)
            let faceTypes: [KeypointType] = [.nose, .leftEye, .rightEye, .leftEar, .rightEar]
            let detectedFaceKeypoints = pose.keypoints.filter { faceTypes.contains($0.type) }
            
            if !detectedFaceKeypoints.isEmpty {
                faceKeypointsCount += 1
            }
            
            // Count essential body keypoints
            let bodyTypes: [KeypointType] = [.leftShoulder, .rightShoulder, .leftWrist, .rightWrist]
            let detectedBodyKeypoints = pose.keypoints.filter { bodyTypes.contains($0.type) }
            
            if detectedBodyKeypoints.count >= 2 {
                bodyKeypointsCount += 1
            }
            
            // GOLF-SPECIFIC INDICATORS
            
            // Back View Indicators:
            // 1. Hand placement close together (wrists near each other)
            if let leftWrist = pose.keypoints.first(where: { $0.type == .leftWrist })?.position,
               let rightWrist = pose.keypoints.first(where: { $0.type == .rightWrist })?.position {
                let wristDistance = sqrt(pow(leftWrist.x - rightWrist.x, 2) + pow(leftWrist.y - rightWrist.y, 2))
                if wristDistance < 0.1 { // Hands close together = grip position from behind
                    backViewIndicators += 1
                    print("🔍 Frame \(i): Back view indicator - Hands close together (distance: \(String(format: "%.3f", wristDistance)))")
                }
            }
            
            // 2. Symmetrical shoulder positioning (both shoulders at similar height)
            if let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
               let rightShoulder = pose.keypoints.first(where: { $0.type == .rightShoulder })?.position {
                let shoulderHeightDiff = abs(leftShoulder.y - rightShoulder.y)
                if shoulderHeightDiff < 0.05 { // Very similar height = back view symmetry
                    backViewIndicators += 1
                    print("🔍 Frame \(i): Back view indicator - Symmetrical shoulders (height diff: \(String(format: "%.3f", shoulderHeightDiff)))")
                }
            }
            
            // Side View Indicators:
            // 1. Feet positioning visible (both ankles detected with good separation)
            if let leftAnkle = pose.keypoints.first(where: { $0.type == .leftAnkle })?.position,
               let rightAnkle = pose.keypoints.first(where: { $0.type == .rightAnkle })?.position {
                let ankleDistance = sqrt(pow(leftAnkle.x - rightAnkle.x, 2) + pow(leftAnkle.y - rightAnkle.y, 2))
                if ankleDistance > 0.15 { // Good stance width visible = side view
                    sideViewIndicators += 1
                    print("🔍 Frame \(i): Side view indicator - Clear stance width (ankle distance: \(String(format: "%.3f", ankleDistance)))")
                }
            }
            
            // 2. Face profile visible (more than just nose detected)
            if detectedFaceKeypoints.count >= 3 { // Multiple face features = profile view
                sideViewIndicators += 1
                print("🔍 Frame \(i): Side view indicator - Face profile visible (\(detectedFaceKeypoints.count) face keypoints)")
            }
        }
        
        // Calculate ratios
        let faceDetectionRatio = Double(faceKeypointsCount) / Double(totalFramesAnalyzed)
        let bodyDetectionRatio = Double(bodyKeypointsCount) / Double(totalFramesAnalyzed)
        let backViewRatio = Double(backViewIndicators) / Double(totalFramesAnalyzed)
        let sideViewRatio = Double(sideViewIndicators) / Double(totalFramesAnalyzed)
        
        print("⛳ Golf Camera Analysis Results:")
        print("   Face detection ratio: \(String(format: "%.2f", faceDetectionRatio))")
        print("   Body detection ratio: \(String(format: "%.2f", bodyDetectionRatio))")
        print("   Back view indicators: \(String(format: "%.2f", backViewRatio)) (\(backViewIndicators)/\(totalFramesAnalyzed))")
        print("   Side view indicators: \(String(format: "%.2f", sideViewRatio)) (\(sideViewIndicators)/\(totalFramesAnalyzed))")
        
        // Enhanced logic: Combine traditional face/body detection with golf-specific indicators
        let isBackView = (bodyDetectionRatio > 0.3 && faceDetectionRatio < 0.1) || 
                        (backViewRatio > 0.3) || 
                        (backViewRatio > sideViewRatio && backViewRatio > 0.2)
        
        // Check if we have enough keypoints for ANY type of analysis
        let hasMinimumKeypoints = bodyDetectionRatio > 0.2 // At least 20% of frames have 2+ body keypoints
        
        if isBackView {
            print("⛳ Analysis: Back-view golf recording detected")
            print("   Primary indicators: Hand placement and shoulder symmetry")
            print("   Minimum keypoints available: \(hasMinimumKeypoints ? "✅" : "❌")")
        } else {
            print("⛳ Analysis: Side-view golf recording detected")
            print("   Primary indicators: Stance width and face profile")
            print("   Body detection: \(String(format: "%.0f", bodyDetectionRatio * 100))%, Face detection: \(String(format: "%.0f", faceDetectionRatio * 100))%")
        }
        
        // Only return true if it's CLEARLY a back view with sufficient keypoints
        return isBackView && hasMinimumKeypoints
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


// MARK: - Feature Extractor

class SwingFeatureExtractor {
    private var currentCameraAngle: CameraAngle = .side
    
    func extractFeatures(from poses: [PoseData], cameraAngle: CameraAngle = .side) -> [Double] {
        // Store camera angle for use in helper functions
        self.currentCameraAngle = cameraAngle
        
        guard poses.count >= 3 else {
            print("❌ Too few poses detected (\(poses.count)). Cannot perform analysis.")
            return Array(repeating: 0.0, count: 35) // Will trigger proper error handling
        }
        
        print("🎬 Processing \(poses.count) poses for feature extraction (camera: \(cameraAngle == .back ? "back" : "side"))")
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
        return SwingPhysicsCalculator.calculateSwingPlaneAngle(poses: poses, cameraAngle: currentCameraAngle)
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
    case insufficientPoseData
    case noValidSwingMotionDetected
    case poorVideoQuality
    case incorrectCameraAngle
    case noPosesDetected(String)
    case poorPoseQuality(String)
    case visionFrameworkUnavailable(String)
    
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
        case .insufficientPoseData:
            return "Not enough body pose data detected for analysis"
        case .noValidSwingMotionDetected:
            return "No valid golf swing motion detected in the video"
        case .poorVideoQuality:
            return "Video quality too poor for accurate analysis"
        case .incorrectCameraAngle:
            return "Camera angle not suitable for swing analysis"
        case .noPosesDetected(let message):
            return message
        case .poorPoseQuality(let message):
            return message
        case .visionFrameworkUnavailable(let message):
            return message
        }
    }
    
}

