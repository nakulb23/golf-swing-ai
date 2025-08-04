import Foundation
import SwiftUI

// MARK: - Feedback System

struct SwingFeedback {
    let overallScore: Double // 0-100
    let improvements: [ImprovementRecommendation]
    let strengths: [StrengthArea]
    let eliteBenchmarks: [EliteBenchmark]
    let practiceRecommendations: [PracticeRecommendation]
    let timestamp: Date
}

struct ImprovementRecommendation {
    let area: SwingArea
    let priority: Priority
    let issue: String
    let solution: String
    let drills: [String]
    let impactOnDistance: Double? // yards gained if improved
    let impactOnAccuracy: Double? // percentage improvement
    let videoTimestamp: Double? // when in swing this occurs
    
    enum Priority: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .green
            }
        }
    }
}

struct StrengthArea {
    let area: SwingArea
    let description: String
    let professionalLevel: Double // 0-100, how close to pro level
}

struct EliteBenchmark {
    let metric: String
    let userValue: Double
    let eliteAverage: Double
    let eliteRange: ClosedRange<Double>
    let percentile: Double // where user ranks vs elite players
    let unit: String
}

struct PracticeRecommendation {
    let title: String
    let description: String
    let duration: String // "5-10 minutes"
    let frequency: String // "3 times per week"
    let equipment: [String] // what's needed
    let difficulty: Difficulty
    let videoURL: String? // instructional video
    
    enum Difficulty: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate" 
        case advanced = "Advanced"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
}

enum SwingArea: String, CaseIterable {
    case clubHeadSpeed = "Club Head Speed"
    case swingPlane = "Swing Plane"
    case tempo = "Tempo"
    case bodyRotation = "Body Rotation"
    case weightTransfer = "Weight Transfer"
    case armPosition = "Arm Position"
    case wristAction = "Wrist Action"
    case spineAngle = "Spine Angle"
    case setup = "Setup"
    case followThrough = "Follow Through"
    
    var icon: String {
        switch self {
        case .clubHeadSpeed: return "speedometer"
        case .swingPlane: return "chart.line.downtrend.xyaxis"
        case .tempo: return "metronome"
        case .bodyRotation: return "arrow.clockwise"
        case .weightTransfer: return "figure.walk"
        case .armPosition: return "figure.arms.open"
        case .wristAction: return "hand.raised.fill"
        case .spineAngle: return "figure.stand"
        case .setup: return "target"
        case .followThrough: return "arrow.right.circle"
        }
    }
}

// MARK: - Feedback Engine

class SwingFeedbackEngine {
    
    static func generateFeedback(from analysis: SwingAnalysisResult) -> SwingFeedback {
        let improvements = analyzeImprovements(analysis)
        let strengths = identifyStrengths(analysis)
        let eliteComparisons = compareWithElitePlayers(analysis)
        let practiceRecs = generatePracticeRecommendations(improvements)
        let overallScore = calculateOverallScore(analysis, improvements: improvements)
        
        return SwingFeedback(
            overallScore: overallScore,
            improvements: improvements,
            strengths: strengths,
            eliteBenchmarks: eliteComparisons,
            practiceRecommendations: practiceRecs,
            timestamp: Date()
        )
    }
    
    // MARK: - Analysis Methods
    
    private static func analyzeImprovements(_ analysis: SwingAnalysisResult) -> [ImprovementRecommendation] {
        var improvements: [ImprovementRecommendation] = []
        
        // Analyze club head speed
        if analysis.clubHeadSpeed.speedAtImpact < 85 {
            improvements.append(ImprovementRecommendation(
                area: .clubHeadSpeed,
                priority: .high,
                issue: "Club head speed at impact is \(String(format: "%.1f", analysis.clubHeadSpeed.speedAtImpact)) mph, which is below average (95+ mph)",
                solution: "Focus on proper weight transfer and body rotation sequence. Start the downswing with your lower body, not your arms.",
                drills: [
                    "Step-through drill: Practice stepping into your shot",
                    "Heavy club swings: Use a weighted club for 10 swings before hitting",
                    "Separation drill: Practice keeping your upper body back while lower body starts downswing"
                ],
                impactOnDistance: 15,
                impactOnAccuracy: nil,
                videoTimestamp: analysis.clubHeadSpeed.impactFrame > 0 ? Double(analysis.clubHeadSpeed.impactFrame) / 60.0 : nil
            ))
        }
        
        // Analyze swing plane consistency
        if analysis.swingPlane.planeConsistency < 0.7 {
            improvements.append(ImprovementRecommendation(
                area: .swingPlane,
                priority: .medium,
                issue: "Swing plane consistency is \(String(format: "%.0f", analysis.swingPlane.planeConsistency * 100))%. Inconsistent swing plane leads to poor ball striking.",
                solution: "Work on maintaining the same swing plane throughout your swing. Focus on keeping your left arm connected to your chest.",
                drills: [
                    "Plane board drill: Practice swinging along an inclined board",
                    "Towel drill: Keep a towel under your left armpit throughout the swing",
                    "Mirror work: Practice your swing in front of a mirror to see plane consistency"
                ],
                impactOnDistance: 8,
                impactOnAccuracy: 15,
                videoTimestamp: nil
            ))
        }
        
        // Analyze tempo
        if analysis.tempo.tempoRatio < 2.5 || analysis.tempo.tempoRatio > 4.0 {
            let issue = analysis.tempo.tempoRatio < 2.5 ? "too quick" : "too slow"
            improvements.append(ImprovementRecommendation(
                area: .tempo,
                priority: .medium,
                issue: "Your tempo ratio is \(String(format: "%.1f", analysis.tempo.tempoRatio)):1, which is \(issue). Ideal ratio is 3:1 (backswing:downswing).",
                solution: "Practice with a metronome to develop consistent tempo. Count '1-2-3' for backswing and '1' for downswing.",
                drills: [
                    "Metronome practice: Use 76 BPM for timing",
                    "Humming drill: Hum a slow tune while swinging",
                    "Pause drill: Pause at the top of your backswing for one second"
                ],
                impactOnDistance: 5,
                impactOnAccuracy: 20,
                videoTimestamp: 0
            ))
        }
        
        // Analyze body rotation sequence
        let shoulderRotation = analysis.bodyKinematics.shoulderRotation
        let hipRotation = analysis.bodyKinematics.hipRotation
        
        if shoulderRotation.rotationTiming <= hipRotation.rotationTiming {
            improvements.append(ImprovementRecommendation(
                area: .bodyRotation,
                priority: .critical,
                issue: "Your shoulders are rotating before or with your hips. This reduces power and can cause slicing.",
                solution: "Initiate the downswing with your lower body. Hips should start turning before shoulders.",
                drills: [
                    "Pump drill: Start downswing motion 3 times before actually swinging",
                    "Impact bag drill: Practice hitting into an impact bag with proper sequence",
                    "Lower body isolation: Practice hip turn while keeping shoulders back"
                ],
                impactOnDistance: 20,
                impactOnAccuracy: 10,
                videoTimestamp: hipRotation.rotationTiming
            ))
        }
        
        // Analyze weight transfer
        let weightShift = analysis.bodyKinematics.weightShift
        if abs(weightShift.weightAtImpact.x) < 0.2 {
            improvements.append(ImprovementRecommendation(
                area: .weightTransfer,
                priority: .high,
                issue: "Insufficient weight transfer to your front foot at impact. This reduces power and consistency.",
                solution: "Feel like you're throwing a ball - your weight should move toward the target during the downswing.",
                drills: [
                    "Step drill: Actually step toward the target during your swing",
                    "Baseball drill: Practice swinging like you're hitting a baseball",
                    "Wall drill: Practice with your back foot against a wall"
                ],
                impactOnDistance: 12,
                impactOnAccuracy: 8,
                videoTimestamp: nil
            ))
        }
        
        // Analyze spine angle stability
        if analysis.bodyKinematics.spineAngle.spineStability < 0.8 {
            improvements.append(ImprovementRecommendation(
                area: .spineAngle,
                priority: .medium,
                issue: "Your spine angle changes too much during the swing (\(String(format: "%.0f", (1.0 - analysis.bodyKinematics.spineAngle.spineStability) * 100))% variation). This affects consistency.",
                solution: "Maintain your posture throughout the swing. Keep your head steady and resist standing up.",
                drills: [
                    "Head against wall drill: Practice with your head touching a wall",
                    "Chair drill: Practice swinging while sitting on a high chair",
                    "Posture stick drill: Hold a club across your chest to feel proper rotation"
                ],
                impactOnDistance: 3,
                impactOnAccuracy: 12,
                videoTimestamp: nil
            ))
        }
        
        return improvements.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    private static func identifyStrengths(_ analysis: SwingAnalysisResult) -> [StrengthArea] {
        var strengths: [StrengthArea] = []
        
        if analysis.clubHeadSpeed.speedAtImpact > 105 {
            strengths.append(StrengthArea(
                area: .clubHeadSpeed,
                description: "Excellent club head speed (\(String(format: "%.1f", analysis.clubHeadSpeed.speedAtImpact)) mph). You generate good power.",
                professionalLevel: min(100, (analysis.clubHeadSpeed.speedAtImpact / 115) * 100)
            ))
        }
        
        if analysis.swingPlane.planeConsistency > 0.85 {
            strengths.append(StrengthArea(
                area: .swingPlane,
                description: "Very consistent swing plane (\(String(format: "%.0f", analysis.swingPlane.planeConsistency * 100))%). This leads to repeatable ball striking.",
                professionalLevel: analysis.swingPlane.planeConsistency * 100
            ))
        }
        
        if analysis.tempo.tempoRatio >= 2.8 && analysis.tempo.tempoRatio <= 3.2 {
            strengths.append(StrengthArea(
                area: .tempo,
                description: "Excellent tempo ratio (\(String(format: "%.1f", analysis.tempo.tempoRatio)):1). Your timing is very good.",
                professionalLevel: 90
            ))
        }
        
        if analysis.bodyKinematics.spineAngle.spineStability > 0.9 {
            strengths.append(StrengthArea(
                area: .spineAngle,
                description: "Outstanding spine angle stability. You maintain great posture throughout your swing.",
                professionalLevel: 95
            ))
        }
        
        return strengths
    }
    
    private static func compareWithElitePlayers(_ analysis: SwingAnalysisResult) -> [EliteBenchmark] {
        return [
            EliteBenchmark(
                metric: "Club Head Speed",
                userValue: analysis.clubHeadSpeed.speedAtImpact,
                eliteAverage: 113.0,
                eliteRange: 105.0...125.0,
                percentile: min(100, (analysis.clubHeadSpeed.speedAtImpact / 113.0) * 50), // Simplified percentile
                unit: "mph"
            ),
            EliteBenchmark(
                metric: "Swing Plane Consistency",
                userValue: analysis.swingPlane.planeConsistency * 100,
                eliteAverage: 92.0,
                eliteRange: 88.0...96.0,
                percentile: min(100, (analysis.swingPlane.planeConsistency * 100 / 92.0) * 75),
                unit: "%"
            ),
            EliteBenchmark(
                metric: "Tempo Ratio",
                userValue: analysis.tempo.tempoRatio,
                eliteAverage: 3.0,
                eliteRange: 2.8...3.2,
                percentile: analysis.tempo.tempoRatio >= 2.8 && analysis.tempo.tempoRatio <= 3.2 ? 80 : 30,
                unit: ":1"
            ),
            EliteBenchmark(
                metric: "Backswing Time",
                userValue: analysis.tempo.backswingTime,
                eliteAverage: 0.87,
                eliteRange: 0.75...1.0,
                percentile: min(100, (1.0 - abs(analysis.tempo.backswingTime - 0.87)) * 100),
                unit: "sec"
            )
        ]
    }
    
    private static func generatePracticeRecommendations(_ improvements: [ImprovementRecommendation]) -> [PracticeRecommendation] {
        var recommendations: [PracticeRecommendation] = []
        
        // Always include basic recommendations
        recommendations.append(PracticeRecommendation(
            title: "Daily Swing Tempo Practice",
            description: "Practice your swing rhythm with a metronome. Focus on smooth, controlled motion rather than power.",
            duration: "10 minutes",
            frequency: "Daily",
            equipment: ["Metronome app", "Practice club or alignment stick"],
            difficulty: .beginner,
            videoURL: nil
        ))
        
        // Add specific recommendations based on improvements needed
        for improvement in improvements.prefix(3) { // Top 3 priority items
            switch improvement.area {
            case .clubHeadSpeed:
                recommendations.append(PracticeRecommendation(
                    title: "Power Development Training",
                    description: "Build speed through proper sequencing and athletic motion. Focus on ground force and rotation.",
                    duration: "15-20 minutes",
                    frequency: "3 times per week",
                    equipment: ["Heavy training club", "Impact bag", "Medicine ball"],
                    difficulty: .intermediate,
                    videoURL: nil
                ))
                
            case .swingPlane:
                recommendations.append(PracticeRecommendation(
                    title: "Swing Plane Consistency Drills",
                    description: "Train your muscle memory to follow the same swing path consistently.",
                    duration: "15 minutes",
                    frequency: "4 times per week",
                    equipment: ["Plane board or alignment sticks", "Mirror"],
                    difficulty: .intermediate,
                    videoURL: nil
                ))
                
            case .bodyRotation:
                recommendations.append(PracticeRecommendation(
                    title: "Kinematic Sequence Training",
                    description: "Learn the proper order of body movement: ground up, hips before shoulders.",
                    duration: "10-15 minutes",
                    frequency: "Daily",
                    equipment: ["Mirror", "Resistance band"],
                    difficulty: .advanced,
                    videoURL: nil
                ))
                
            case .weightTransfer:
                recommendations.append(PracticeRecommendation(
                    title: "Weight Transfer Drills",
                    description: "Develop athletic weight shift patterns for more power and consistency.",
                    duration: "10 minutes",
                    frequency: "Daily",
                    equipment: ["Balance board (optional)", "Wall or fence"],
                    difficulty: .beginner,
                    videoURL: nil
                ))
                
            default:
                break
            }
        }
        
        // Add fitness recommendation if multiple power-related issues
        let powerIssues = improvements.filter { [.clubHeadSpeed, .bodyRotation, .weightTransfer].contains($0.area) }
        if powerIssues.count >= 2 {
            recommendations.append(PracticeRecommendation(
                title: "Golf-Specific Fitness Program",
                description: "Improve your physical capabilities for better golf performance. Focus on mobility, stability, and rotational power.",
                duration: "30 minutes",
                frequency: "2-3 times per week",
                equipment: ["Resistance bands", "Medicine ball", "Balance pad"],
                difficulty: .intermediate,
                videoURL: nil
            ))
        }
        
        return recommendations
    }
    
    private static func calculateOverallScore(_ analysis: SwingAnalysisResult, improvements: [ImprovementRecommendation]) -> Double {
        var score = 50.0 // Base score
        
        // Add points for good metrics
        if analysis.clubHeadSpeed.speedAtImpact > 95 {
            score += 15
        } else if analysis.clubHeadSpeed.speedAtImpact > 85 {
            score += 8
        }
        
        score += analysis.swingPlane.planeConsistency * 20
        
        if analysis.tempo.tempoRatio >= 2.5 && analysis.tempo.tempoRatio <= 3.5 {
            score += 10
        }
        
        score += analysis.bodyKinematics.spineAngle.spineStability * 10
        
        // Subtract points for critical issues
        let criticalIssues = improvements.filter { $0.priority == .critical }.count
        score -= Double(criticalIssues) * 5
        
        let highIssues = improvements.filter { $0.priority == .high }.count
        score -= Double(highIssues) * 3
        
        // Factor in tracking quality
        score *= analysis.trackingQuality.overallScore
        
        return max(0, min(100, score))
    }
}

// MARK: - Professional Benchmarks

struct ProfessionalBenchmarks {
    static let clubHeadSpeed = (average: 113.0, range: 105.0...125.0)
    static let swingPlaneConsistency = (average: 0.92, range: 0.88...0.96)
    static let tempoRatio = (average: 3.0, range: 2.8...3.2)
    static let backswingTime = (average: 0.87, range: 0.75...1.0)
    static let downswingTime = (average: 0.29, range: 0.25...0.33)
    static let shoulderRotation = (average: 88.0, range: 80.0...95.0)
    static let hipRotation = (average: 45.0, range: 40.0...50.0)
    static let spineStability = (average: 0.91, range: 0.88...0.95)
    
    static func getPercentile(for value: Double, metric: String) -> Double {
        switch metric.lowercased() {
        case "club head speed", "clubheadspeed":
            return min(100, max(0, (value - 85) / (125 - 85) * 100))
        case "swing plane consistency", "swingplaneconsistency":
            return min(100, max(0, (value - 0.7) / (0.96 - 0.7) * 100))
        case "tempo ratio", "temporatio":
            let ideal = 3.0
            let deviation = abs(value - ideal)
            return max(0, (1.0 - deviation / 2.0) * 100)
        default:
            return 50.0
        }
    }
}