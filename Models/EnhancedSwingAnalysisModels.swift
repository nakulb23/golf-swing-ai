import Foundation
import CoreGraphics
import simd

// MARK: - Enhanced Swing Analysis Result
// This integrates the premium features while maintaining compatibility with existing SwingAnalysisResponse

struct EnhancedSwingAnalysisResult {
    // Core analysis from existing system
    let baseAnalysis: SwingAnalysisResponse
    
    // Premium scoring system
    let scoreBreakdown: SwingScoreBreakdown
    
    // Enhanced kinematics data
    let bodyKinematics: BodyKinematicsData?
    
    // Detailed tempo analysis (enhanced from existing)
    let detailedTempo: DetailedSwingTempoData?
    
    // Enhanced tracking quality with more metrics
    let enhancedTrackingQuality: EnhancedTrackingQuality
    
    // Swing phases with precise timing
    let swingPhases: SwingPhases?
    
    // Computed overall quality score
    var overallQualityScore: Double {
        return scoreBreakdown.overallScore * enhancedTrackingQuality.overallScore * baseAnalysis.confidence
    }
    
    // Convenience accessors for compatibility
    var predictedLabel: String { baseAnalysis.predicted_label }
    var confidence: Double { baseAnalysis.confidence }
    var recommendations: [String] { baseAnalysis.recommendations ?? [] }
}

// MARK: - Swing Score Breakdown
struct SwingScoreBreakdown {
    let tempoScore: Double        // 0-100
    let planeScore: Double        // 0-100
    let kinematicsScore: Double   // 0-100
    let impactScore: Double       // 0-100
    let consistencyScore: Double  // 0-100
    
    // Weights for different aspects
    private let tempoWeight = 0.20
    private let planeWeight = 0.25
    private let kinematicsWeight = 0.25
    private let impactWeight = 0.20
    private let consistencyWeight = 0.10
    
    var overallScore: Double {
        let weighted = (tempoScore * tempoWeight +
                       planeScore * planeWeight +
                       kinematicsScore * kinematicsWeight +
                       impactScore * impactWeight +
                       consistencyScore * consistencyWeight)
        return weighted
    }
    
    var letterGrade: String {
        switch overallScore {
        case 90...100: return "A+"
        case 85..<90: return "A"
        case 80..<85: return "A-"
        case 75..<80: return "B+"
        case 70..<75: return "B"
        case 65..<70: return "B-"
        case 60..<65: return "C+"
        case 55..<60: return "C"
        case 50..<55: return "C-"
        case 45..<50: return "D+"
        case 40..<45: return "D"
        default: return "F"
        }
    }
    
    var feedback: String {
        let components = [
            (tempoScore, "Tempo", tempoWeight),
            (planeScore, "Swing Plane", planeWeight),
            (kinematicsScore, "Body Movement", kinematicsWeight),
            (impactScore, "Impact Quality", impactWeight),
            (consistencyScore, "Consistency", consistencyWeight)
        ]
        
        let weakest = components.min { $0.0 < $1.0 }
        let strongest = components.max { $0.0 < $1.0 }
        
        var feedback = "Overall Grade: \(letterGrade) (\(Int(overallScore))%)\n\n"
        
        if let strongest = strongest, strongest.0 >= 80 {
            feedback += "✅ Strongest area: \(strongest.1) (\(Int(strongest.0))%)\n"
        }
        
        if let weakest = weakest, weakest.0 < 70 {
            feedback += "⚠️ Focus area: \(weakest.1) (\(Int(weakest.0))%)\n"
        }
        
        return feedback
    }
}

// MARK: - Enhanced Body Kinematics
struct BodyKinematicsData {
    let shoulderRotation: RotationData
    let hipRotation: RotationData
    let spineAngle: SpineAngleData
    let weightShift: WeightShiftData
    let sequencing: KinematicSequencing
    
    // Key positions during swing
    let addressPosition: BodyPosition
    let topOfBackswing: BodyPosition
    let impactPosition: BodyPosition
    let followThrough: BodyPosition?
    
    // Computed efficiency metrics
    var xFactor: Double {
        return shoulderRotation.maxRotation - hipRotation.maxRotation
    }
    
    var sequencingScore: Double {
        return sequencing.calculateScore()
    }
}

struct RotationData {
    let maxRotation: Double        // degrees
    let rotationSpeed: Double      // degrees/second
    let rotationTiming: Double     // seconds from start
    let smoothness: Double         // 0-1 (1 = very smooth)
}

struct SpineAngleData {
    let addressAngle: Double
    let topAngle: Double
    let impactAngle: Double
    let maxDeviation: Double
    
    var stability: Double {
        // Calculate how stable spine angle is throughout swing
        let deviation = abs(addressAngle - impactAngle)
        return max(0, 1.0 - (deviation / 20.0)) // 20 degrees = 0 stability
    }
}

struct WeightShiftData {
    let initialBalance: CGPoint    // x: left/right, y: front/back
    let topBalance: CGPoint
    let impactBalance: CGPoint
    let transferEfficiency: Double // 0-1
    
    var pressureShiftMagnitude: Double {
        let dx = impactBalance.x - initialBalance.x
        let dy = impactBalance.y - initialBalance.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct KinematicSequencing {
    let hipInitiation: Double      // Time when hips start moving
    let shoulderInitiation: Double // Time when shoulders start
    let armInitiation: Double      // Time when arms start
    let clubInitiation: Double     // Time when club accelerates
    
    func calculateScore() -> Double {
        // Ideal sequence: hips -> shoulders -> arms -> club
        let idealGap = 0.05 // 50ms between each
        
        let hipToShoulder = shoulderInitiation - hipInitiation
        let shoulderToArm = armInitiation - shoulderInitiation
        let armToClub = clubInitiation - armInitiation
        
        var score = 100.0
        
        // Deduct points for improper sequencing
        if hipToShoulder < 0 { score -= 25 } // Shoulders before hips
        if shoulderToArm < 0 { score -= 25 } // Arms before shoulders
        if armToClub < 0 { score -= 25 }     // Club before arms
        
        // Deduct for timing issues
        score -= min(15, abs(hipToShoulder - idealGap) * 100)
        score -= min(15, abs(shoulderToArm - idealGap) * 100)
        score -= min(15, abs(armToClub - idealGap) * 100)
        
        return max(0, score)
    }
}

struct BodyPosition {
    let timestamp: Double
    let frame: Int
    let centerOfMass: CGPoint
    let jointPositions: [String: CGPoint]
    let postureQuality: Double // 0-1
}

// MARK: - Detailed Tempo Analysis
struct DetailedSwingTempoData {
    let backswingDuration: Double
    let transitionPause: Double
    let downswingDuration: Double
    let totalDuration: Double
    
    // Tempo segments
    let addressToTakeaway: Double
    let takeawayToTop: Double
    let topToImpact: Double
    let impactToFinish: Double
    
    // Computed metrics
    var tempoRatio: Double {
        return backswingDuration / downswingDuration
    }
    
    var tempoRating: TempoRating {
        switch tempoRatio {
        case 0..<2.5: return .tooFast
        case 2.5..<3.5: return .ideal
        case 3.5..<4.5: return .slightlySlow
        default: return .tooSlow
        }
    }
    
    var pauseQuality: PauseQuality {
        switch transitionPause {
        case 0..<0.05: return .noticeable
        case 0.05..<0.15: return .ideal
        case 0.15..<0.25: return .slight
        default: return .excessive
        }
    }
}

enum TempoRating: String {
    case tooFast = "Too Fast"
    case ideal = "Ideal"
    case slightlySlow = "Slightly Slow"
    case tooSlow = "Too Slow"
    
    var feedback: String {
        switch self {
        case .tooFast: return "Your downswing is too quick relative to backswing. Try counting '1-2-3' on backswing, '1' on downswing."
        case .ideal: return "Excellent tempo! Your timing ratio is in the ideal range."
        case .slightlySlow: return "Your tempo is slightly slow but still good. Maintain this rhythm."
        case .tooSlow: return "Your backswing is too slow relative to downswing. Try to be more dynamic."
        }
    }
}

enum PauseQuality: String {
    case noticeable = "No Pause"
    case ideal = "Perfect Pause"
    case slight = "Slight Pause"
    case excessive = "Too Long"
}

// MARK: - Enhanced Tracking Quality
struct EnhancedTrackingQuality {
    let clubVisibility: Double      // 0-1
    let bodyVisibility: Double      // 0-1
    let jointConfidence: Double     // 0-1
    let lightingQuality: Double     // 0-1
    let cameraStability: Double     // 0-1
    let frameRate: Double           // 0-1
    let resolution: Double          // 0-1
    
    var overallScore: Double {
        let weights = [
            clubVisibility * 0.25,
            bodyVisibility * 0.20,
            jointConfidence * 0.15,
            lightingQuality * 0.15,
            cameraStability * 0.10,
            frameRate * 0.10,
            resolution * 0.05
        ]
        return weights.reduce(0, +)
    }
    
    var qualityAssessment: String {
        switch overallScore {
        case 0.9...1.0: return "Excellent"
        case 0.75..<0.9: return "Good"
        case 0.6..<0.75: return "Fair"
        case 0.4..<0.6: return "Poor"
        default: return "Very Poor"
        }
    }
    
    var limitingFactors: [String] {
        var factors: [String] = []
        
        if clubVisibility < 0.7 { factors.append("Club visibility") }
        if bodyVisibility < 0.7 { factors.append("Body visibility") }
        if lightingQuality < 0.6 { factors.append("Lighting") }
        if cameraStability < 0.7 { factors.append("Camera movement") }
        
        return factors
    }
}

// MARK: - Swing Phases
struct SwingPhases {
    let setupFrame: Int
    let takeawayFrame: Int
    let midBackswingFrame: Int
    let topFrame: Int
    let transitionFrame: Int
    let midDownswingFrame: Int
    let impactFrame: Int
    let followThroughFrame: Int
    let finishFrame: Int?
    
    let totalFrames: Int
    let fps: Double
    
    // Computed timings
    var setupDuration: Double {
        return Double(takeawayFrame - setupFrame) / fps
    }
    
    var backswingDuration: Double {
        return Double(topFrame - takeawayFrame) / fps
    }
    
    var downswingDuration: Double {
        return Double(impactFrame - topFrame) / fps
    }
    
    var followThroughDuration: Double {
        if let finish = finishFrame {
            return Double(finish - impactFrame) / fps
        }
        return Double(followThroughFrame - impactFrame) / fps
    }
    
    func phaseAtFrame(_ frame: Int) -> String {
        switch frame {
        case ..<takeawayFrame: return "Setup"
        case takeawayFrame..<midBackswingFrame: return "Takeaway"
        case midBackswingFrame..<topFrame: return "Backswing"
        case topFrame..<transitionFrame: return "Transition"
        case transitionFrame..<midDownswingFrame: return "Early Downswing"
        case midDownswingFrame..<impactFrame: return "Late Downswing"
        case impactFrame..<followThroughFrame: return "Impact Zone"
        case followThroughFrame...: return "Follow Through"
        default: return "Unknown"
        }
    }
}

// MARK: - Analysis Helpers
extension EnhancedSwingAnalysisResult {
    // Factory method to create from existing SwingAnalysisResponse
    static func from(_ response: SwingAnalysisResponse, 
                     videoURL: URL? = nil,
                     videoDuration: Double? = nil) -> EnhancedSwingAnalysisResult {
        
        // Calculate scores based on available data
        let planeScore = calculatePlaneScore(from: response)
        let tempoScore = calculateTempoScore(from: response)
        let kinematicsScore = calculateKinematicsScore(from: response)
        let impactScore = calculateImpactScore(from: response)
        let consistencyScore = calculateConsistencyScore(from: response)
        
        let scoreBreakdown = SwingScoreBreakdown(
            tempoScore: tempoScore,
            planeScore: planeScore,
            kinematicsScore: kinematicsScore,
            impactScore: impactScore,
            consistencyScore: consistencyScore
        )
        
        // Enhanced tracking quality
        let trackingQuality = EnhancedTrackingQuality(
            clubVisibility: 0.8, // Default values, should be calculated from actual data
            bodyVisibility: 0.85,
            jointConfidence: response.confidence,
            lightingQuality: 0.75,
            cameraStability: 0.9,
            frameRate: 0.95,
            resolution: 0.8
        )
        
        return EnhancedSwingAnalysisResult(
            baseAnalysis: response,
            scoreBreakdown: scoreBreakdown,
            bodyKinematics: nil, // Would need pose data to calculate
            detailedTempo: nil,  // Would need frame timing data
            enhancedTrackingQuality: trackingQuality,
            swingPhases: nil     // Would need frame analysis
        )
    }
    
    // Score calculation helpers
    private static func calculatePlaneScore(from response: SwingAnalysisResponse) -> Double {
        switch response.predicted_label {
        case "on_plane":
            return 85 + (response.confidence * 15) // 85-100 based on confidence
        case "too_steep":
            return 60 - (response.confidence * 10) // 50-60
        case "too_flat":
            return 60 - (response.confidence * 10) // 50-60
        default:
            return 70
        }
    }
    
    private static func calculateTempoScore(from response: SwingAnalysisResponse) -> Double {
        // Use tempo data if available, otherwise estimate
        if let tempo = response.club_speed_analysis?.tempo_analysis {
            let ratioScore = tempo.tempo_ratio > 2.5 && tempo.tempo_ratio < 3.5 ? 90 : 70
            return Double(ratioScore)
        }
        return 75 // Default
    }
    
    private static func calculateKinematicsScore(from response: SwingAnalysisResponse) -> Double {
        // Would use actual kinematics data if available
        return 70 + (response.confidence * 20)
    }
    
    private static func calculateImpactScore(from response: SwingAnalysisResponse) -> Double {
        // Use club face analysis if available
        if let impact = response.club_face_analysis?.impact_position {
            return impact.impact_quality_score
        }
        return 75 // Default
    }
    
    private static func calculateConsistencyScore(from response: SwingAnalysisResponse) -> Double {
        // Based on confidence gap - smaller gap means more consistent
        let gapScore = (1.0 - response.confidence_gap) * 100
        return max(50, min(100, gapScore))
    }
}

// MARK: - Swing Improvement Suggestions
extension EnhancedSwingAnalysisResult {
    var topThreeImprovements: [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        // Check each score component
        let components = [
            (scoreBreakdown.tempoScore, "Tempo", generateTempoImprovement()),
            (scoreBreakdown.planeScore, "Swing Plane", generatePlaneImprovement()),
            (scoreBreakdown.kinematicsScore, "Body Movement", generateKinematicsImprovement()),
            (scoreBreakdown.impactScore, "Impact", generateImpactImprovement()),
            (scoreBreakdown.consistencyScore, "Consistency", generateConsistencyImprovement())
        ]
        
        // Sort by score (lowest first) and take top 3
        let sorted = components.sorted { $0.0 < $1.0 }
        
        for (score, area, improvement) in sorted.prefix(3) {
            if score < 80 {
                suggestions.append(improvement)
            }
        }
        
        return suggestions
    }
    
    private func generateTempoImprovement() -> ImprovementSuggestion {
        return ImprovementSuggestion(
            area: "Tempo",
            issue: "Timing ratio needs adjustment",
            drill: "Practice with a metronome: 3 beats backswing, 1 beat downswing",
            expectedImprovement: "5-10% score increase",
            difficulty: .moderate
        )
    }
    
    private func generatePlaneImprovement() -> ImprovementSuggestion {
        let issue = predictedLabel == "too_steep" ? "Swing plane is too steep" : 
                   predictedLabel == "too_flat" ? "Swing plane is too flat" : 
                   "Swing plane consistency"
        
        let drill = predictedLabel == "too_steep" ? 
            "Place a headcover outside the ball, practice missing it on takeaway" :
            "Practice swings with club shaft against a wall behind you"
        
        return ImprovementSuggestion(
            area: "Swing Plane",
            issue: issue,
            drill: drill,
            expectedImprovement: "10-15% score increase",
            difficulty: .moderate
        )
    }
    
    private func generateKinematicsImprovement() -> ImprovementSuggestion {
        return ImprovementSuggestion(
            area: "Body Movement",
            issue: "Sequencing or rotation needs work",
            drill: "Practice the step drill: step toward target during downswing",
            expectedImprovement: "8-12% score increase",
            difficulty: .advanced
        )
    }
    
    private func generateImpactImprovement() -> ImprovementSuggestion {
        return ImprovementSuggestion(
            area: "Impact Position",
            issue: "Contact consistency",
            drill: "Use impact tape or foot spray on club face to check strike location",
            expectedImprovement: "5-8% score increase",
            difficulty: .easy
        )
    }
    
    private func generateConsistencyImprovement() -> ImprovementSuggestion {
        return ImprovementSuggestion(
            area: "Consistency",
            issue: "Swing varies too much between repetitions",
            drill: "Slow motion swings focusing on exact positions",
            expectedImprovement: "10% score increase",
            difficulty: .easy
        )
    }
}

struct ImprovementSuggestion {
    let area: String
    let issue: String
    let drill: String
    let expectedImprovement: String
    let difficulty: Difficulty
    
    enum Difficulty {
        case easy, moderate, advanced
        
        var emoji: String {
            switch self {
            case .easy: return "🟢"
            case .moderate: return "🟡"
            case .advanced: return "🔴"
            }
        }
    }
}