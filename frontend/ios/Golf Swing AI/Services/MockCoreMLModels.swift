import Foundation
import CoreML

// MARK: - Mock CoreML Model Generator
// Creates functional mock models when actual trained models are not available

class MockCoreMLModels {
    
    // MARK: - Swing Analysis Mock Model
    
    static func createMockSwingAnalysisModel() -> MLModel? {
        // Since we can't easily create a real MLModel programmatically,
        // we'll return nil and handle this in the model loading logic
        print("ℹ️ Mock model creation - actual models should be trained and added to bundle")
        return nil
    }
    
    // MARK: - Ball Tracking Mock Model
    
    static func createMockBallTrackingModel() -> MLModel? {
        print("ℹ️ Mock ball tracking model - using computer vision fallback")
        return nil
    }
    
    // MARK: - Mock Prediction Logic
    
    static func mockSwingAnalysisPrediction(features: [Double]) -> MockSwingAnalysisResult {
        // Analyze features to generate realistic mock predictions
        
        // Extract key features for analysis
        let spineAngle = features.count > 0 ? features[0] : 20.0
        let shoulderTurn = features.count > 5 ? features[5] : 90.0  // First backswing feature
        let tempo = features.count > 17 ? features[17] : 3.0        // Transition timing feature
        let planeAngle = features.count > 8 ? features[8] : 45.0    // Swing plane angle (5+3 in backswing features)
        
        // Calculate swing assessment
        var swingType: String
        var confidence: Double
        var probabilities: [String: Double]
        
        // Analyze swing plane
        if planeAngle < 35 {
            swingType = "too_flat"
            confidence = 0.75 + (35 - planeAngle) / 35 * 0.2
            probabilities = [
                "too_flat": confidence,
                "good_swing": (1.0 - confidence) * 0.7,
                "too_steep": (1.0 - confidence) * 0.3
            ]
        } else if planeAngle > 55 {
            swingType = "too_steep"
            confidence = 0.75 + (planeAngle - 55) / 35 * 0.2
            probabilities = [
                "too_steep": confidence,
                "good_swing": (1.0 - confidence) * 0.7,
                "too_flat": (1.0 - confidence) * 0.3
            ]
        } else {
            swingType = "good_swing"
            
            // Calculate confidence based on multiple factors
            let spineScore = max(0, 1.0 - abs(spineAngle - 25) / 25)
            let shoulderScore = max(0, 1.0 - abs(shoulderTurn - 90) / 45)
            let tempoScore = max(0, 1.0 - abs(tempo - 3.0) / 2.0)
            let planeScore = max(0, 1.0 - abs(planeAngle - 45) / 20)
            
            confidence = (spineScore + shoulderScore + tempoScore + planeScore) / 4.0
            confidence = max(0.6, min(0.95, confidence))
            
            probabilities = [
                "good_swing": confidence,
                "too_steep": (1.0 - confidence) * 0.4,
                "too_flat": (1.0 - confidence) * 0.6
            ]
        }
        
        // Generate physics insights
        let insights = generateMockPhysicsInsights(
            swingType: swingType,
            planeAngle: planeAngle,
            tempo: tempo,
            shoulderTurn: shoulderTurn,
            spineAngle: spineAngle
        )
        
        return MockSwingAnalysisResult(
            predictedLabel: swingType,
            confidence: confidence,
            confidenceGap: confidence - 0.5,
            allProbabilities: probabilities,
            physicsInsights: insights,
            extractionStatus: "success_mock"
        )
    }
    
    static func mockBallTrackingPrediction(image: UIImage) -> BallTrackingResult? {
        // Generate mock ball tracking result based on image analysis
        
        // Simulate ball detection with some variability
        let hasDetection = Bool.random() // 50% chance of detection
        
        guard hasDetection else { return nil }
        
        // Generate realistic ball position
        let centerX = 0.4 + Double.random(in: -0.2...0.2) // Slightly off-center
        let centerY = 0.6 + Double.random(in: -0.1...0.1) // Lower half of image
        
        let confidence = 0.7 + Double.random(in: 0...0.25) // 70-95% confidence
        
        return BallTrackingResult(
            position: CGPoint(x: centerX, y: centerY),
            confidence: confidence,
            ballSize: 0.02, // Relative to image size
            detectionMethod: "mock_cv"
        )
    }
    
    // MARK: - Mock Physics Insights Generation
    
    private static func generateMockPhysicsInsights(
        swingType: String,
        planeAngle: Double,
        tempo: Double,
        shoulderTurn: Double,
        spineAngle: Double
    ) -> MockPhysicsInsights {
        
        var analysis: String
        var recommendations: [String] = []
        
        switch swingType {
        case "too_steep":
            analysis = "Your swing plane is \(Int(planeAngle))° - steeper than ideal. This can cause fat shots and loss of distance."
            recommendations = [
                "Focus on a shallower takeaway",
                "Work on maintaining width in your backswing",
                "Practice the 'slot' move in transition",
                "Strengthen your core for better rotation"
            ]
            
        case "too_flat":
            analysis = "Your swing plane is \(Int(planeAngle))° - flatter than optimal. This may lead to inconsistent contact."
            recommendations = [
                "Work on a more upright backswing position",
                "Focus on shoulder turn rather than arm swing",
                "Practice steeper approach angles",
                "Check your setup posture"
            ]
            
        default: // good_swing
            analysis = "Excellent swing plane at \(Int(planeAngle))°! Your mechanics show good fundamentals."
            recommendations = [
                "Continue maintaining this swing plane",
                "Focus on tempo consistency",
                "Work on distance control",
                "Practice under pressure situations"
            ]
        }
        
        // Add tempo analysis
        if tempo < 2.5 {
            analysis += " Your tempo is quite fast (\(String(format: "%.1f", tempo)):1 ratio)."
            recommendations.append("Slow down your backswing for better control")
        } else if tempo > 4.0 {
            analysis += " Your tempo is slower (\(String(format: "%.1f", tempo)):1 ratio)."
            recommendations.append("Increase downswing speed for more power")
        } else {
            analysis += " Good tempo ratio of \(String(format: "%.1f", tempo)):1."
        }
        
        // Add shoulder turn analysis
        if shoulderTurn < 70 {
            recommendations.append("Increase shoulder rotation for more power")
        } else if shoulderTurn > 110 {
            recommendations.append("Control shoulder turn to maintain balance")
        }
        
        // Add posture analysis
        if spineAngle < 15 {
            recommendations.append("Maintain more forward spine tilt at address")
        } else if spineAngle > 35 {
            recommendations.append("Reduce excessive forward bend")
        }
        
        return MockPhysicsInsights(
            avgPlaneAngle: planeAngle,
            planeAnalysis: analysis,
            tempoRatio: tempo,
            maxShoulderTurn: shoulderTurn,
            spineAngle: spineAngle,
            recommendations: Array(recommendations.prefix(4)), // Limit to 4 recommendations
            overallScore: calculateOverallScore(
                swingType: swingType,
                planeAngle: planeAngle,
                tempo: tempo,
                shoulderTurn: shoulderTurn
            )
        )
    }
    
    private static func calculateOverallScore(
        swingType: String,
        planeAngle: Double,
        tempo: Double,
        shoulderTurn: Double
    ) -> Double {
        var score = 0.0
        
        // Base score from swing type
        switch swingType {
        case "good_swing": score = 80.0
        case "too_steep": score = 65.0
        case "too_flat": score = 60.0
        default: score = 50.0
        }
        
        // Adjust for plane angle
        let idealPlane = 45.0
        let planeDeviation = abs(planeAngle - idealPlane)
        score -= planeDeviation * 0.5
        
        // Adjust for tempo
        let idealTempo = 3.0
        let tempoDeviation = abs(tempo - idealTempo)
        score -= tempoDeviation * 3.0
        
        // Adjust for shoulder turn
        if shoulderTurn >= 80 && shoulderTurn <= 100 {
            score += 5.0 // Bonus for good shoulder turn
        } else {
            score -= abs(shoulderTurn - 90) * 0.2
        }
        
        return max(40.0, min(95.0, score))
    }
}

// MARK: - Mock Result Data Structures

struct MockSwingAnalysisResult {
    let predictedLabel: String
    let confidence: Double
    let confidenceGap: Double
    let allProbabilities: [String: Double]
    let physicsInsights: MockPhysicsInsights
    let extractionStatus: String
}

struct BallTrackingResult {
    let position: CGPoint
    let confidence: Double
    let ballSize: Double
    let detectionMethod: String
}

struct MockPhysicsInsights {
    let avgPlaneAngle: Double
    let planeAnalysis: String
    let tempoRatio: Double
    let maxShoulderTurn: Double
    let spineAngle: Double
    let recommendations: [String]
    let overallScore: Double
}