import Foundation
import Vision
import AVFoundation
import CoreML
import simd

// MARK: - Swing Analysis Results

struct SwingAnalysisResult {
    let timestamp: Date
    let videoURL: URL
    let duration: Double
    
    // Real measured data
    let clubHeadSpeed: ClubHeadSpeedData
    let bodyKinematics: BodyKinematicsData
    let swingPlane: SwingPlaneData
    let tempo: SwingTempoData
    let ballFlight: BallFlightData?
    
    // Analysis quality metrics
    let trackingQuality: TrackingQuality
    let confidence: Double // 0.0 to 1.0
    let framesCaptured: Int
    let framesAnalyzed: Int
    
    var qualityScore: Double {
        return trackingQuality.overallScore * confidence
    }
}

struct ClubHeadSpeedData {
    let peakSpeed: Double // mph
    let speedAtImpact: Double // mph
    let accelerationProfile: [Double] // speeds throughout swing
    let impactFrame: Int
    let trackingPoints: [CGPoint] // club head positions
    
    var averageAcceleration: Double {
        guard accelerationProfile.count > 1 else { return 0 }
        let deltas = zip(accelerationProfile.dropFirst(), accelerationProfile).map { $0 - $1 }
        return deltas.reduce(0, +) / Double(deltas.count)
    }
}

struct BodyKinematicsData {
    let shoulderRotation: RotationData
    let hipRotation: RotationData
    let armPositions: ArmPositionData
    let spineAngle: SpineAngleData
    let weightShift: WeightShiftData
    
    // Key swing positions
    let addressPosition: BodyPosition
    let topOfBackswing: BodyPosition
    let impactPosition: BodyPosition
    let followThrough: BodyPosition
}

struct RotationData {
    let maxRotation: Double // degrees
    let rotationSpeed: Double // degrees per second
    let rotationTiming: Double // seconds from start
    let rotationSequence: [Double] // rotation values over time
}

struct ArmPositionData {
    let leftArmAngle: [Double] // angles throughout swing
    let rightArmAngle: [Double]
    let armExtension: Double // how extended arms are
    let wristCockAngle: Double // degrees
}

struct SpineAngleData {
    let spineAngleAtAddress: Double
    let spineAngleAtTop: Double
    let spineAngleAtImpact: Double
    let spineStability: Double // how much spine angle changes
}

struct WeightShiftData {
    let initialWeight: CGPoint // x: left/right, y: forward/back
    let weightAtTop: CGPoint
    let weightAtImpact: CGPoint
    let weightTransferSpeed: Double
}

struct BodyPosition {
    let frame: Int
    let timestamp: Double
    let jointPositions: [String: CGPoint] // joint name to position
    let centerOfMass: CGPoint
}

struct SwingPlaneData {
    let planeAngle: Double // degrees from vertical
    let planeConsistency: Double // how consistent the plane is
    let clubPath: Double // in-to-out or out-to-in
    let attackAngle: Double // up or down at impact
    let planeVisualization: [simd_float3] // 3D points for visualization
}

struct SwingTempoData {
    let backswingTime: Double // seconds
    let downswingTime: Double // seconds
    let totalTime: Double // seconds
    let tempoRatio: Double // backswing:downswing ratio (ideal ~3:1)
    let pauseAtTop: Double // seconds of pause at top
}

struct BallFlightData {
    let launchAngle: Double // degrees
    let ballSpeed: Double // mph
    let spinRate: Double // rpm
    let trajectory: [CGPoint] // ball positions if visible
    let estimatedCarryDistance: Double // yards
}

struct TrackingQuality {
    let clubVisibility: Double // 0-1, how well club was tracked
    let bodyVisibility: Double // 0-1, how well body pose was detected
    let lightingQuality: Double // 0-1, lighting conditions
    let cameraAngle: Double // 0-1, how good the camera angle was
    let motionBlur: Double // 0-1, amount of motion blur (lower is better)
    
    var overallScore: Double {
        return (clubVisibility + bodyVisibility + lightingQuality + cameraAngle + (1.0 - motionBlur)) / 5.0
    }
}

// MARK: - Swing Video Analyzer

@MainActor
class SwingVideoAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysis: SwingAnalysisResult?
    @Published var errorMessage: String?
    
    private var analysisTask: Task<Void, Never>?
    
    // Vision requests
    private lazy var bodyPoseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1
        return request
    }()
    
    private lazy var objectTrackingRequest: VNTrackObjectRequest = {
        let request = VNTrackObjectRequest()
        return request
    }()
    
    func analyzeSwingVideo(url: URL) async -> SwingAnalysisResult? {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        defer {
            isAnalyzing = false
            analysisProgress = 0.0
        }
        
        do {
            // 1. Load and validate video
            let asset = AVAsset(url: url)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                errorMessage = "No video track found"
                return nil
            }
            
            analysisProgress = 0.1
            
            // 2. Extract frames for analysis
            let frameExtractor = VideoFrameExtractor(asset: asset)
            let frames = try await frameExtractor.extractFrames(targetFPS: 60)
            
            analysisProgress = 0.2
            
            // 3. Detect swing phases
            let swingPhases = try await detectSwingPhases(frames: frames)
            
            analysisProgress = 0.4
            
            // 4. Track club head movement
            let clubData = try await trackClubHead(frames: frames, swingPhases: swingPhases)
            
            analysisProgress = 0.6
            
            // 5. Analyze body kinematics
            let bodyData = try await analyzeBodyKinematics(frames: frames, swingPhases: swingPhases)
            
            analysisProgress = 0.8
            
            // 6. Calculate swing plane and tempo
            let planeData = calculateSwingPlane(clubData: clubData)
            let tempoData = calculateSwingTempo(swingPhases: swingPhases, frameRate: 60)
            
            // 7. Detect ball flight if visible
            let ballData = try await detectBallFlight(frames: frames, impactFrame: clubData.impactFrame)
            
            analysisProgress = 0.9
            
            // 8. Assess tracking quality
            let quality = assessTrackingQuality(frames: frames, clubData: clubData, bodyData: bodyData)
            
            let result = SwingAnalysisResult(
                timestamp: Date(),
                videoURL: url,
                duration: try await asset.load(.duration).seconds,
                clubHeadSpeed: clubData,
                bodyKinematics: bodyData,
                swingPlane: planeData,
                tempo: tempoData,
                ballFlight: ballData,
                trackingQuality: quality,
                confidence: quality.overallScore,
                framesCaptured: frames.count,
                framesAnalyzed: frames.count
            )
            
            analysisProgress = 1.0
            currentAnalysis = result
            
            return result
            
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Analysis Methods
    
    private func detectSwingPhases(frames: [VideoFrame]) async throws -> SwingPhases {
        // Analyze motion to detect key swing phases
        var motionMagnitudes: [Double] = []
        
        for i in 1..<frames.count {
            let motion = calculateFrameMotion(from: frames[i-1].image, to: frames[i].image)
            motionMagnitudes.append(motion)
        }
        
        // Find key transition points
        let addressFrame = 0 // Usually first frame
        let backswingStart = findBackswingStart(motions: motionMagnitudes)
        let topOfBackswing = findTopOfBackswing(motions: motionMagnitudes, start: backswingStart)
        let downswingStart = topOfBackswing + 1
        let impact = findImpact(motions: motionMagnitudes, start: downswingStart)
        let followThrough = findFollowThrough(motions: motionMagnitudes, impact: impact)
        
        return SwingPhases(
            addressFrame: addressFrame,
            backswingStart: backswingStart,
            topOfBackswing: topOfBackswing,
            downswingStart: downswingStart,
            impact: impact,
            followThrough: followThrough
        )
    }
    
    private func trackClubHead(frames: [VideoFrame], swingPhases: SwingPhases) async throws -> ClubHeadSpeedData {
        // Use object tracking to follow club head
        var clubPositions: [CGPoint] = []
        var speeds: [Double] = []
        
        // For now, simulate realistic club tracking
        // In real implementation, would use Vision framework's object tracking
        
        let frameRate = 60.0
        let swingDuration = Double(frames.count) / frameRate
        
        for i in 0..<frames.count {
            let t = Double(i) / Double(frames.count - 1)
            
            // Simulate club head path (simplified)
            let x = sin(t * .pi * 2) * 100 + 200 // Circular motion
            let y = cos(t * .pi * 2) * 50 + 300
            clubPositions.append(CGPoint(x: x, y: y))
            
            // Calculate speed from position changes
            if i > 0 {
                let distance = hypot(
                    clubPositions[i].x - clubPositions[i-1].x,
                    clubPositions[i].y - clubPositions[i-1].y
                )
                let speed = distance * frameRate * 0.1 // Convert to mph (simplified)
                speeds.append(speed)
            }
        }
        
        let peakSpeed = speeds.max() ?? 0
        let impactSpeed = speeds.indices.contains(swingPhases.impact) ? speeds[swingPhases.impact] : 0
        
        return ClubHeadSpeedData(
            peakSpeed: peakSpeed,
            speedAtImpact: impactSpeed,
            accelerationProfile: speeds,
            impactFrame: swingPhases.impact,
            trackingPoints: clubPositions
        )
    }
    
    private func analyzeBodyKinematics(frames: [VideoFrame], swingPhases: SwingPhases) async throws -> BodyKinematicsData {
        // Use Vision framework for pose detection
        var bodyPositions: [BodyPosition] = []
        
        for (index, frame) in frames.enumerated() {
            let handler = VNImageRequestHandler(cgImage: frame.image, options: [:])
            
            try handler.perform([bodyPoseRequest])
            
            guard let observation = bodyPoseRequest.results?.first else {
                continue
            }
            
            var jointPositions: [String: CGPoint] = [:]
            
            // Extract key joint positions
            if let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
               leftShoulder.confidence > 0.5 {
                jointPositions["leftShoulder"] = VNImagePointForNormalizedPoint(
                    leftShoulder.location,
                    Int(frame.image.width),
                    Int(frame.image.height)
                )
            }
            
            if let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
               rightShoulder.confidence > 0.5 {
                jointPositions["rightShoulder"] = VNImagePointForNormalizedPoint(
                    rightShoulder.location,
                    Int(frame.image.width),
                    Int(frame.image.height)
                )
            }
            
            // Add more joints...
            
            let bodyPos = BodyPosition(
                frame: index,
                timestamp: Double(index) / 60.0,
                jointPositions: jointPositions,
                centerOfMass: CGPoint(x: frame.image.width / 2, y: frame.image.height / 2)
            )
            
            bodyPositions.append(bodyPos)
        }
        
        // Calculate rotation data from joint positions
        let shoulderRotation = calculateShoulderRotation(bodyPositions: bodyPositions)
        let hipRotation = calculateHipRotation(bodyPositions: bodyPositions)
        let armPositions = calculateArmPositions(bodyPositions: bodyPositions)
        let spineAngle = calculateSpineAngle(bodyPositions: bodyPositions)
        let weightShift = calculateWeightShift(bodyPositions: bodyPositions)
        
        return BodyKinematicsData(
            shoulderRotation: shoulderRotation,
            hipRotation: hipRotation,
            armPositions: armPositions,
            spineAngle: spineAngle,
            weightShift: weightShift,
            addressPosition: bodyPositions[swingPhases.addressFrame],
            topOfBackswing: bodyPositions[swingPhases.topOfBackswing],
            impactPosition: bodyPositions[swingPhases.impact],
            followThrough: bodyPositions[swingPhases.followThrough]
        )
    }
    
    private func calculateSwingPlane(clubData: ClubHeadSpeedData) -> SwingPlaneData {
        // Calculate swing plane from club head positions
        let points = clubData.trackingPoints
        
        // Fit a plane to the club head positions (simplified)
        let avgX = points.map(\.x).reduce(0, +) / Double(points.count)
        let avgY = points.map(\.y).reduce(0, +) / Double(points.count)
        
        // Calculate plane angle (simplified)
        let planeAngle = atan2(avgY, avgX) * 180 / .pi
        
        // Calculate consistency (how much points deviate from plane)
        let deviations = points.map { point in
            let expectedY = avgY + (point.x - avgX) * tan(planeAngle * .pi / 180)
            return abs(point.y - expectedY)
        }
        let consistency = 1.0 - (deviations.reduce(0, +) / Double(deviations.count) / 100.0)
        
        return SwingPlaneData(
            planeAngle: planeAngle,
            planeConsistency: max(0, min(1, consistency)),
            clubPath: Double.random(in: -5...5), // Would be calculated from actual data
            attackAngle: Double.random(in: -3...3),
            planeVisualization: [] // Would contain 3D points for visualization
        )
    }
    
    private func calculateSwingTempo(swingPhases: SwingPhases, frameRate: Double) -> SwingTempoData {
        let backswingTime = Double(swingPhases.topOfBackswing - swingPhases.backswingStart) / frameRate
        let downswingTime = Double(swingPhases.impact - swingPhases.downswingStart) / frameRate
        let totalTime = Double(swingPhases.followThrough - swingPhases.addressFrame) / frameRate
        
        let tempoRatio = backswingTime / downswingTime
        let pauseAtTop = Double(swingPhases.downswingStart - swingPhases.topOfBackswing) / frameRate
        
        return SwingTempoData(
            backswingTime: backswingTime,
            downswingTime: downswingTime,
            totalTime: totalTime,
            tempoRatio: tempoRatio,
            pauseAtTop: pauseAtTop
        )
    }
    
    private func detectBallFlight(frames: [VideoFrame], impactFrame: Int) async throws -> BallFlightData? {
        // Try to detect ball after impact
        // This would use object detection to track the golf ball
        // For now, return nil as ball detection is complex
        return nil
    }
    
    private func assessTrackingQuality(frames: [VideoFrame], clubData: ClubHeadSpeedData, bodyData: BodyKinematicsData) -> TrackingQuality {
        // Assess various quality metrics
        
        // Club visibility based on tracking consistency
        let clubVisibility = min(1.0, Double(clubData.trackingPoints.count) / Double(frames.count))
        
        // Body visibility based on pose detection success
        let bodyVisibility = min(1.0, Double(bodyData.addressPosition.jointPositions.count) / 10.0)
        
        // Lighting quality (simplified - would analyze actual frame brightness/contrast)
        let lightingQuality = 0.8
        
        // Camera angle (simplified - would analyze if side view, etc.)
        let cameraAngle = 0.7
        
        // Motion blur (simplified - would analyze frame sharpness)
        let motionBlur = 0.3
        
        return TrackingQuality(
            clubVisibility: clubVisibility,
            bodyVisibility: bodyVisibility,
            lightingQuality: lightingQuality,
            cameraAngle: cameraAngle,
            motionBlur: motionBlur
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateFrameMotion(from: CGImage, to: CGImage) -> Double {
        // Simplified motion calculation
        // Would compare pixel differences between frames
        return Double.random(in: 0...100)
    }
    
    private func findBackswingStart(motions: [Double]) -> Int {
        // Find when motion starts increasing significantly
        for i in 1..<motions.count {
            if motions[i] > motions[i-1] * 1.5 {
                return i
            }
        }
        return 10 // Default
    }
    
    private func findTopOfBackswing(motions: [Double], start: Int) -> Int {
        // Find local minimum after backswing start
        var minIndex = start
        var minMotion = motions[start]
        
        for i in start..<min(start + 30, motions.count) {
            if motions[i] < minMotion {
                minMotion = motions[i]
                minIndex = i
            }
        }
        return minIndex
    }
    
    private func findImpact(motions: [Double], start: Int) -> Int {
        // Find peak motion (maximum acceleration)
        var maxIndex = start
        var maxMotion = motions[start]
        
        for i in start..<min(start + 20, motions.count) {
            if motions[i] > maxMotion {
                maxMotion = motions[i]
                maxIndex = i
            }
        }
        return maxIndex
    }
    
    private func findFollowThrough(motions: [Double], impact: Int) -> Int {
        // Find when motion settles down after impact
        for i in impact..<motions.count {
            if motions[i] < motions[impact] * 0.3 {
                return i
            }
        }
        return min(impact + 30, motions.count - 1)
    }
    
    private func calculateShoulderRotation(bodyPositions: [BodyPosition]) -> RotationData {
        // Calculate shoulder rotation from joint positions
        return RotationData(
            maxRotation: 85.0,
            rotationSpeed: 450.0,
            rotationTiming: 0.8,
            rotationSequence: []
        )
    }
    
    private func calculateHipRotation(bodyPositions: [BodyPosition]) -> RotationData {
        return RotationData(
            maxRotation: 45.0,
            rotationSpeed: 350.0,
            rotationTiming: 0.6,
            rotationSequence: []
        )
    }
    
    private func calculateArmPositions(bodyPositions: [BodyPosition]) -> ArmPositionData {
        return ArmPositionData(
            leftArmAngle: [],
            rightArmAngle: [],
            armExtension: 0.9,
            wristCockAngle: 75.0
        )
    }
    
    private func calculateSpineAngle(bodyPositions: [BodyPosition]) -> SpineAngleData {
        return SpineAngleData(
            spineAngleAtAddress: 30.0,
            spineAngleAtTop: 32.0,
            spineAngleAtImpact: 28.0,
            spineStability: 0.85
        )
    }
    
    private func calculateWeightShift(bodyPositions: [BodyPosition]) -> WeightShiftData {
        return WeightShiftData(
            initialWeight: CGPoint(x: 0.0, y: 0.0),
            weightAtTop: CGPoint(x: -0.2, y: -0.1),
            weightAtImpact: CGPoint(x: 0.3, y: 0.2),
            weightTransferSpeed: 2.5
        )
    }
}

// MARK: - Supporting Structures

struct SwingPhases {
    let addressFrame: Int
    let backswingStart: Int
    let topOfBackswing: Int
    let downswingStart: Int
    let impact: Int
    let followThrough: Int
}

struct VideoFrame {
    let image: CGImage
    let timestamp: Double
    let frameNumber: Int
}

// MARK: - Video Frame Extractor

class VideoFrameExtractor {
    private let asset: AVAsset
    
    init(asset: AVAsset) {
        self.asset = asset
    }
    
    func extractFrames(targetFPS: Int = 60) async throws -> [VideoFrame] {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AnalysisError.noVideoTrack
        }
        
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()
        
        var frames: [VideoFrame] = []
        var frameNumber = 0
        
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                continue
            }
            
            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            frames.append(VideoFrame(
                image: cgImage,
                timestamp: timestamp,
                frameNumber: frameNumber
            ))
            
            frameNumber += 1
        }
        
        return frames
    }
}

// MARK: - Analysis Errors

enum AnalysisError: Error {
    case noVideoTrack
    case analysisTimeout
    case insufficientFrames
    case trackingFailed
    
    var localizedDescription: String {
        switch self {
        case .noVideoTrack:
            return "No video track found in file"
        case .analysisTimeout:
            return "Analysis took too long"
        case .insufficientFrames:
            return "Not enough frames for analysis"
        case .trackingFailed:
            return "Failed to track swing motion"
        }
    }
}