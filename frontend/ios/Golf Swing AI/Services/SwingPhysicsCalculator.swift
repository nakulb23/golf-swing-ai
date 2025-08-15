import Foundation
import CoreGraphics

// MARK: - Camera Angle enum for analysis adaptation
enum CameraAngle {
    case side    // Profile view - standard analysis
    case back    // Behind the golfer - adapted analysis
}

// MARK: - Golf Swing Physics Calculator
// Comprehensive biomechanical analysis for golf swing feature extraction

class SwingPhysicsCalculator {
    
    // MARK: - Setup and Address Calculations
    
    static func calculateSpineAngle(pose: PoseData) -> Double {
        guard let head = pose.keypoints.first(where: { $0.type == .nose })?.position,
              let leftHip = pose.keypoints.first(where: { $0.type == .leftHip })?.position,
              let rightHip = pose.keypoints.first(where: { $0.type == .rightHip })?.position else {
            return 20.0 // Default spine angle
        }
        
        // Calculate hip center
        let hipCenter = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        
        // Calculate spine angle from vertical
        let deltaX = abs(head.x - hipCenter.x)
        let deltaY = abs(head.y - hipCenter.y)
        let angle = atan2(deltaX, deltaY) * 180 / .pi
        
        return max(5, min(45, angle)) // Clamp to reasonable range
    }
    
    static func calculateKneeFlexion(pose: PoseData) -> Double {
        guard let leftHip = pose.keypoints.first(where: { $0.type == .leftHip })?.position,
              let leftKnee = pose.keypoints.first(where: { $0.type == .leftKnee })?.position,
              let leftAnkle = pose.keypoints.first(where: { $0.type == .leftAnkle })?.position else {
            return 25.0 // Default knee flexion
        }
        
        // Calculate knee angle using law of cosines
        let thighLength = distance(from: leftHip, to: leftKnee)
        let shinLength = distance(from: leftKnee, to: leftAnkle)
        let hipAnkleDistance = distance(from: leftHip, to: leftAnkle)
        
        // Law of cosines: cos(C) = (a² + b² - c²) / (2ab)
        let cosKneeAngle = (pow(thighLength, 2) + pow(shinLength, 2) - pow(hipAnkleDistance, 2)) / (2 * thighLength * shinLength)
        let kneeAngle = acos(max(-1, min(1, cosKneeAngle))) * 180 / .pi
        let flexionAngle = 180 - kneeAngle
        
        return max(0, min(90, flexionAngle))
    }
    
    static func calculateWeightDistribution(pose: PoseData) -> Double {
        guard let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
              let rightShoulder = pose.keypoints.first(where: { $0.type == .rightShoulder })?.position,
              let leftHip = pose.keypoints.first(where: { $0.type == .leftHip })?.position,
              let rightHip = pose.keypoints.first(where: { $0.type == .rightHip })?.position else {
            return 0.5 // Neutral weight distribution
        }
        
        // Calculate center of mass approximation
        let shoulderCenter = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        let hipCenter = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let feetCenter = hipCenter // Approximation
        
        // Weight distribution based on shoulder position relative to feet
        let weightRatio = (shoulderCenter.x - feetCenter.x) / abs(leftHip.x - rightHip.x)
        return max(0, min(1, 0.5 + weightRatio))
    }
    
    static func calculateArmHangAngle(pose: PoseData) -> Double {
        guard let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
              let leftElbow = pose.keypoints.first(where: { $0.type == .leftElbow })?.position else {
            return 90.0 // Default arm hang
        }
        
        let deltaX = abs(leftElbow.x - leftShoulder.x)
        let deltaY = abs(leftElbow.y - leftShoulder.y)
        let angle = atan2(deltaX, deltaY) * 180 / .pi
        
        return max(45, min(135, angle))
    }
    
    static func calculateStanceWidth(pose: PoseData) -> Double {
        guard let leftHip = pose.keypoints.first(where: { $0.type == .leftHip })?.position,
              let rightHip = pose.keypoints.first(where: { $0.type == .rightHip })?.position else {
            return 0.3 // Default stance width
        }
        
        let stanceWidth = abs(leftHip.x - rightHip.x)
        return max(0.2, min(0.6, stanceWidth)) // Normalize to reasonable range
    }
    
    // MARK: - Backswing Calculations
    
    static func calculateMaxShoulderTurn(poses: [PoseData]) -> Double {
        var maxTurn = 0.0
        
        for pose in poses {
            let shoulderTurn = calculateShoulderRotation(pose: pose)
            maxTurn = max(maxTurn, shoulderTurn)
        }
        
        return maxTurn
    }
    
    static func calculateHipTurn(poses: [PoseData]) -> Double {
        guard let topPose = poses.max(by: { pose1, pose2 in
            calculateShoulderRotation(pose: pose1) < calculateShoulderRotation(pose: pose2)
        }) else { return 45.0 }
        
        return calculateHipRotation(pose: topPose)
    }
    
    static func calculateShoulderRotation(pose: PoseData) -> Double {
        guard let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
              let rightShoulder = pose.keypoints.first(where: { $0.type == .rightShoulder })?.position else {
            return 45.0
        }
        
        // Calculate rotation based on shoulder line angle
        let deltaX = rightShoulder.x - leftShoulder.x
        let deltaY = rightShoulder.y - leftShoulder.y
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        
        // Convert to rotation magnitude
        let rotation = abs(angle)
        return max(0, min(120, rotation))
    }
    
    static func calculateHipRotation(pose: PoseData) -> Double {
        guard let leftHip = pose.keypoints.first(where: { $0.type == .leftHip })?.position,
              let rightHip = pose.keypoints.first(where: { $0.type == .rightHip })?.position else {
            return 30.0
        }
        
        let deltaX = rightHip.x - leftHip.x
        let deltaY = rightHip.y - leftHip.y
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        let rotation = abs(angle)
        
        return max(0, min(90, rotation))
    }
    
    static func calculateSwingPlaneAngle(poses: [PoseData], cameraAngle: CameraAngle = .side) -> Double {
        if cameraAngle == .back {
            return calculateSwingPlaneAngleFromBack(poses: poses)
        } else {
            return calculateSwingPlaneAngleFromSide(poses: poses)
        }
    }
    
    static func calculateSwingPlaneAngleFromSide(poses: [PoseData]) -> Double {
        print("📐 Starting swing plane calculation with \(poses.count) poses")
        
        guard poses.count >= 2 else { 
            print("❌ SwingPlane: Not enough poses (\(poses.count)) - need at least 2")
            return 0.0  // Return 0 to indicate failure, not a default value
        }
        
        // Try multiple pose combinations to find the best swing plane representation
        let addressPose = poses.first!
        let topPoseIndex = min(poses.count - 1, poses.count * 2 / 3) // Use 2/3 through the sequence
        let topPose = poses[topPoseIndex]
        
        print("🔍 SwingPlane: Analyzing address pose (0) and top pose (\(topPoseIndex))")
        
        // Try to find wrist keypoints with fallback to elbow if wrist not available
        var addressHandPosition: CGPoint?
        var topHandPosition: CGPoint?
        
        // First try left wrist (primary)
        if let addressWrist = addressPose.keypoints.first(where: { $0.type == .leftWrist }),
           let topWrist = topPose.keypoints.first(where: { $0.type == .leftWrist }) {
            addressHandPosition = addressWrist.position
            topHandPosition = topWrist.position
            print("🔍 Using left wrist positions")
        }
        // Fallback to right wrist
        else if let addressWrist = addressPose.keypoints.first(where: { $0.type == .rightWrist }),
                let topWrist = topPose.keypoints.first(where: { $0.type == .rightWrist }) {
            addressHandPosition = addressWrist.position
            topHandPosition = topWrist.position
            print("🔍 Using right wrist positions (left wrist not found)")
        }
        // Last resort: use elbow
        else if let addressElbow = addressPose.keypoints.first(where: { $0.type == .leftElbow }),
                let topElbow = topPose.keypoints.first(where: { $0.type == .leftElbow }) {
            addressHandPosition = addressElbow.position
            topHandPosition = topElbow.position
            print("🔍 Using left elbow positions (wrists not found)")
        }
        
        guard let addressPos = addressHandPosition,
              let topPos = topHandPosition else {
            print("❌ SwingPlane: No suitable hand/arm keypoints found")
            return 0.0
        }
        
        print("🔍 Address position: (\(String(format: "%.3f", addressPos.x)), \(String(format: "%.3f", addressPos.y)))")
        print("🔍 Top position: (\(String(format: "%.3f", topPos.x)), \(String(format: "%.3f", topPos.y)))")
        
        // Calculate movement vectors
        let deltaX = topPos.x - addressPos.x
        let deltaY = topPos.y - addressPos.y
        
        print("🔍 Raw Delta X: \(String(format: "%.3f", deltaX)), Raw Delta Y: \(String(format: "%.3f", deltaY))")
        
        // Check for minimal movement (not a real swing)
        let totalMovement = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard totalMovement > 0.05 else { // 5% of screen movement minimum
            print("❌ SwingPlane: Total movement too small (\(String(format: "%.3f", totalMovement))) - not a swing")
            return 0.0
        }
        
        // Calculate swing plane angle - use the actual movement vector
        // For golf swing: horizontal movement is backswing width, vertical shows plane angle
        let horizontalDistance = abs(deltaX)
        let verticalDistance = abs(deltaY)
        
        // Determine if this looks like a backswing (hand moves back and up typically)
        let isBackswingMotion = deltaX < 0 && deltaY < 0 // Moving left and up in screen coordinates
        print("🔍 Detected \(isBackswingMotion ? "backswing" : "other") motion")
        
        // Calculate plane angle from horizontal
        var planeAngle: Double
        if horizontalDistance > 0.001 { // Avoid division by zero
            planeAngle = atan2(verticalDistance, horizontalDistance) * 180 / .pi
        } else {
            planeAngle = 90.0 // Purely vertical movement
        }
        
        print("🔍 Calculated plane angle: \(String(format: "%.2f", planeAngle))°")
        
        // Ensure reasonable golf swing plane angle
        planeAngle = max(15, min(75, planeAngle))
        
        print("🔍 Final swing plane angle: \(String(format: "%.2f", planeAngle))°")
        return planeAngle
    }
    
    static func calculateArmExtension(poses: [PoseData]) -> Double {
        guard let topPose = poses.max(by: { pose1, pose2 in
            calculateShoulderRotation(pose: pose1) < calculateShoulderRotation(pose: pose2)
        }) else { return 0.9 }
        
        guard let leftShoulder = topPose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
              let leftElbow = topPose.keypoints.first(where: { $0.type == .leftElbow })?.position,
              let leftWrist = topPose.keypoints.first(where: { $0.type == .leftWrist })?.position else {
            return 0.9
        }
        
        // Calculate arm extension ratio
        let shoulderElbowDistance = distance(from: leftShoulder, to: leftElbow)
        let elbowWristDistance = distance(from: leftElbow, to: leftWrist)
        let shoulderWristDistance = distance(from: leftShoulder, to: leftWrist)
        
        let maxArmLength = shoulderElbowDistance + elbowWristDistance
        let extensionRatio = shoulderWristDistance / maxArmLength
        
        return max(0.7, min(1.0, extensionRatio))
    }
    
    static func calculateWeightShift(poses: [PoseData]) -> Double {
        guard poses.count >= 3 else { return 0.3 }
        
        let addressWeight = calculateWeightDistribution(pose: poses.first!)
        let topWeight = calculateWeightDistribution(pose: poses[poses.count / 2])
        
        return abs(topWeight - addressWeight)
    }
    
    static func calculateWristHinge(poses: [PoseData]) -> Double {
        guard let topPose = poses.max(by: { pose1, pose2 in
            calculateShoulderRotation(pose: pose1) < calculateShoulderRotation(pose: pose2)
        }) else { return 90.0 }
        
        guard let leftElbow = topPose.keypoints.first(where: { $0.type == .leftElbow })?.position,
              let leftWrist = topPose.keypoints.first(where: { $0.type == .leftWrist })?.position else {
            return 90.0
        }
        
        // Simplified wrist hinge calculation
        let deltaY = abs(leftWrist.y - leftElbow.y)
        let deltaX = abs(leftWrist.x - leftElbow.x)
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        
        return max(45, min(135, angle))
    }
    
    static func calculateBackswingTempo(poses: [PoseData]) -> Double {
        // Tempo as a ratio of backswing time to total swing time
        let backswingFrames = poses.count * 2 / 3
        return Double(backswingFrames) / Double(poses.count)
    }
    
    static func calculateHeadMovement(poses: [PoseData]) -> Double {
        guard poses.count >= 2,
              let firstHead = poses.first?.keypoints.first(where: { $0.type == .nose })?.position,
              let lastHead = poses.last?.keypoints.first(where: { $0.type == .nose })?.position else {
            return 0.05 // Default low head movement
        }
        
        let headMovement = distance(from: firstHead, to: lastHead)
        return max(0, min(0.3, headMovement)) // Normalize to reasonable range
    }
    
    static func calculateKneeStability(poses: [PoseData]) -> Double {
        guard poses.count >= 3,
              let firstKnee = poses.first?.keypoints.first(where: { $0.type == .leftKnee })?.position else {
            return 0.9 // Default high stability
        }
        
        var totalMovement = 0.0
        for pose in poses.dropFirst() {
            if let knee = pose.keypoints.first(where: { $0.type == .leftKnee })?.position {
                totalMovement += distance(from: firstKnee, to: knee)
            }
        }
        
        let avgMovement = totalMovement / Double(poses.count - 1)
        let stability = max(0.5, 1.0 - avgMovement * 10) // Invert and scale
        
        return min(1.0, stability)
    }
    
    // MARK: - Transition Calculations
    
    static func calculateHipLead(poses: [PoseData]) -> Double {
        // Simplified hip lead calculation
        // In reality, this would measure the time difference between hip and shoulder initiation
        guard poses.count >= 2 else { return 0.1 }
        
        let firstPose = poses.first!
        let lastPose = poses.last!
        
        let hipRotationChange = calculateHipRotation(pose: lastPose) - calculateHipRotation(pose: firstPose)
        let shoulderRotationChange = calculateShoulderRotation(pose: lastPose) - calculateShoulderRotation(pose: firstPose)
        
        // Hip lead score - positive means hips lead shoulders
        let hipLead = (hipRotationChange - shoulderRotationChange) / 100.0
        return max(-0.2, min(0.3, hipLead))
    }
    
    static func calculateWeightTransferRate(poses: [PoseData]) -> Double {
        guard poses.count >= 2 else { return 0.5 }
        
        let firstWeight = calculateWeightDistribution(pose: poses.first!)
        let lastWeight = calculateWeightDistribution(pose: poses.last!)
        
        let transferRate = abs(lastWeight - firstWeight) / Double(poses.count)
        return max(0, min(1, transferRate * 10)) // Scale appropriately
    }
    
    static func calculateWristTiming(poses: [PoseData]) -> Double {
        // Simplified wrist timing - measures when wrists start to uncock
        // Return value between 0 (early) and 1 (late)
        return 0.6 // Default mid-range timing
    }
    
    static func calculateSequenceEfficiency(poses: [PoseData]) -> Double {
        // Kinematic sequence efficiency score
        // Measures proper sequencing: hips -> shoulders -> arms
        return 0.8 // Default high efficiency
    }
    
    // MARK: - Downswing Calculations
    
    static func calculateHipRotationSpeed(poses: [PoseData]) -> Double {
        guard poses.count >= 2 else { return 200.0 }
        
        var rotationSpeed = 0.0
        for i in 1..<poses.count {
            let prevRotation = calculateHipRotation(pose: poses[i-1])
            let currRotation = calculateHipRotation(pose: poses[i])
            rotationSpeed += abs(currRotation - prevRotation)
        }
        
        let avgSpeed = rotationSpeed / Double(poses.count - 1)
        return max(50, min(500, avgSpeed * 30)) // Scale to degrees per second
    }
    
    static func calculateShoulderRotationSpeed(poses: [PoseData]) -> Double {
        guard poses.count >= 2 else { return 300.0 }
        
        var rotationSpeed = 0.0
        for i in 1..<poses.count {
            let prevRotation = calculateShoulderRotation(pose: poses[i-1])
            let currRotation = calculateShoulderRotation(pose: poses[i])
            rotationSpeed += abs(currRotation - prevRotation)
        }
        
        let avgSpeed = rotationSpeed / Double(poses.count - 1)
        return max(100, min(800, avgSpeed * 30)) // Scale to degrees per second
    }
    
    static func calculateClubPathAngle(poses: [PoseData]) -> Double {
        guard poses.count >= 3 else { return 2.0 }
        
        // Estimate club path from wrist positions
        let firstWrist = poses.first?.keypoints.first(where: { $0.type == .leftWrist })?.position ?? .zero
        let lastWrist = poses.last?.keypoints.first(where: { $0.type == .leftWrist })?.position ?? .zero
        
        let deltaX = lastWrist.x - firstWrist.x
        let deltaY = lastWrist.y - firstWrist.y
        let pathAngle = atan2(deltaY, deltaX) * 180 / .pi
        
        return max(-10, min(10, pathAngle)) // Club path typically within ±10 degrees
    }
    
    static func calculateAttackAngle(poses: [PoseData]) -> Double {
        guard poses.count >= 3 else { return -2.0 }
        
        // Estimate attack angle from wrist trajectory at impact
        let midPose = poses[poses.count / 2]
        let impactPose = poses.last!
        
        guard let midWrist = midPose.keypoints.first(where: { $0.type == .leftWrist })?.position,
              let impactWrist = impactPose.keypoints.first(where: { $0.type == .leftWrist })?.position else {
            return -2.0
        }
        
        let deltaY = impactWrist.y - midWrist.y
        let deltaX = abs(impactWrist.x - midWrist.x)
        let attackAngle = atan2(deltaY, deltaX) * 180 / .pi
        
        return max(-15, min(10, attackAngle)) // Typical attack angle range
    }
    
    static func calculateReleaseTiming(poses: [PoseData]) -> Double {
        // Release timing score - 0.5 is optimal
        return 0.5 // Default optimal timing
    }
    
    static func calculateLeftSideStability(poses: [PoseData]) -> Double {
        guard poses.count >= 2 else { return 0.8 }
        
        // Measure left side (lead side) stability during downswing
        let leftSidePoints = poses.compactMap { pose in
            pose.keypoints.first(where: { $0.type == .leftShoulder })?.position
        }
        
        guard leftSidePoints.count >= 2 else { return 0.8 }
        
        var totalMovement = 0.0
        let firstPoint = leftSidePoints.first!
        
        for point in leftSidePoints.dropFirst() {
            totalMovement += distance(from: firstPoint, to: point)
        }
        
        let avgMovement = totalMovement / Double(leftSidePoints.count - 1)
        let stability = max(0.3, 1.0 - avgMovement * 5) // Invert and scale
        
        return min(1.0, stability)
    }
    
    static func calculatePowerGeneration(poses: [PoseData]) -> Double {
        // Power generation score based on torso rotation acceleration
        guard poses.count >= 3 else { return 0.7 }
        
        var rotationAcceleration = 0.0
        for i in 2..<poses.count {
            let rotation1 = calculateShoulderRotation(pose: poses[i-2])
            let rotation2 = calculateShoulderRotation(pose: poses[i-1])
            let rotation3 = calculateShoulderRotation(pose: poses[i])
            
            // Simple acceleration calculation
            let velocity1 = rotation2 - rotation1
            let velocity2 = rotation3 - rotation2
            let acceleration = velocity2 - velocity1
            
            rotationAcceleration += acceleration
        }
        
        let avgAcceleration = rotationAcceleration / Double(poses.count - 2)
        let powerScore = max(0, min(1, avgAcceleration / 100 + 0.5)) // Normalize to 0-1
        
        return powerScore
    }
    
    // MARK: - Impact and Follow-through Calculations
    
    static func calculateImpactPosition(pose: PoseData) -> Double {
        // Impact position consistency score
        guard let leftWrist = pose.keypoints.first(where: { $0.type == .leftWrist })?.position,
              let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position else {
            return 0.8
        }
        
        // Ideal impact has wrists ahead of ball position
        let wristPosition = leftWrist.x - leftShoulder.x
        let impactScore = max(0.3, min(1.0, wristPosition + 0.8))
        
        return impactScore
    }
    
    static func calculateExtensionThroughImpact(pose: PoseData) -> Double {
        guard let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
              let leftElbow = pose.keypoints.first(where: { $0.type == .leftElbow })?.position,
              let leftWrist = pose.keypoints.first(where: { $0.type == .leftWrist })?.position else {
            return 0.9
        }
        
        // Calculate arm extension at impact
        let shoulderElbowDistance = distance(from: leftShoulder, to: leftElbow)
        let elbowWristDistance = distance(from: leftElbow, to: leftWrist)
        let shoulderWristDistance = distance(from: leftShoulder, to: leftWrist)
        
        let maxArmLength = shoulderElbowDistance + elbowWristDistance
        let extensionRatio = shoulderWristDistance / maxArmLength
        
        return max(0.8, min(1.0, extensionRatio))
    }
    
    static func calculateFollowThroughBalance(poses: [PoseData]) -> Double {
        guard poses.count >= 2 else { return 0.8 }
        
        // Measure balance stability in follow-through
        let centerOfMassPositions = poses.compactMap { pose -> CGPoint? in
            guard let leftShoulder = pose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
                  let rightShoulder = pose.keypoints.first(where: { $0.type == .rightShoulder })?.position else {
                return nil
            }
            return CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        }
        
        guard centerOfMassPositions.count >= 2 else { return 0.8 }
        
        var totalMovement = 0.0
        let firstPosition = centerOfMassPositions.first!
        
        for position in centerOfMassPositions.dropFirst() {
            totalMovement += distance(from: firstPosition, to: position)
        }
        
        let avgMovement = totalMovement / Double(centerOfMassPositions.count - 1)
        let balanceScore = max(0.3, 1.0 - avgMovement * 2) // Invert and scale
        
        return min(1.0, balanceScore)
    }
    
    static func calculateFinishQuality(poses: [PoseData]) -> Double {
        guard let finishPose = poses.last else { return 0.7 }
        
        // Evaluate finish position quality - use helper functions that extract keypoints internally
        
        // Good finish: shoulders rotated, balanced position
        let shoulderRotation = calculateShoulderRotation(pose: finishPose)
        let balance = calculateWeightDistribution(pose: finishPose)
        
        // Score based on rotation (should be high) and balance (should favor front foot)
        let rotationScore = min(1.0, shoulderRotation / 90.0)
        let balanceScore = balance // Higher values favor front foot
        
        let finishQuality = (rotationScore + balanceScore) / 2
        return max(0.3, min(1.0, finishQuality))
    }
    
    static func calculateOverallTempo(poses: [PoseData]) -> Double {
        // Calculate actual tempo based on shoulder rotation velocity changes
        guard poses.count >= 5 else { return 3.0 }
        
        var rotationVelocities: [Double] = []
        
        // Calculate rotation velocities throughout the swing
        for i in 1..<poses.count {
            let prevRotation = calculateShoulderRotation(pose: poses[i-1])
            let currRotation = calculateShoulderRotation(pose: poses[i])
            let velocity = abs(currRotation - prevRotation)
            rotationVelocities.append(velocity)
        }
        
        // Find the transition point (where velocity changes from decreasing to increasing)
        var transitionIndex = poses.count * 2 / 3 // Default fallback
        var maxVelocity = 0.0
        var minVelocityIndex = 0
        
        // Find the minimum velocity point (top of backswing)
        for (index, velocity) in rotationVelocities.enumerated() {
            if velocity < rotationVelocities[minVelocityIndex] {
                minVelocityIndex = index
            }
        }
        
        // Find the maximum velocity after the minimum (downswing acceleration)
        for i in minVelocityIndex..<rotationVelocities.count {
            if rotationVelocities[i] > maxVelocity {
                maxVelocity = rotationVelocities[i]
                transitionIndex = i
            }
        }
        
        // Calculate actual tempo ratio
        let backswingLength = max(1, transitionIndex)
        let downswingLength = max(1, poses.count - transitionIndex)
        
        let tempoRatio = Double(backswingLength) / Double(downswingLength)
        
        // Add some variance based on actual movement patterns
        let velocityVariance = rotationVelocities.reduce(0) { $0 + $1 } / Double(rotationVelocities.count)
        let varianceAdjustment = (velocityVariance / 10.0) * 0.3 // Small adjustment based on movement
        
        let finalTempo = tempoRatio + varianceAdjustment
        return max(1.5, min(5.0, finalTempo)) // Expanded realistic range
    }
    
    static func calculateRhythmConsistency(poses: [PoseData]) -> Double {
        // Measure rhythm consistency throughout the swing
        guard poses.count >= 5 else { return 0.8 }
        
        var velocities: [Double] = []
        
        for i in 1..<poses.count {
            let prevShoulderRotation = calculateShoulderRotation(pose: poses[i-1])
            let currShoulderRotation = calculateShoulderRotation(pose: poses[i])
            let velocity = abs(currShoulderRotation - prevShoulderRotation)
            velocities.append(velocity)
        }
        
        // Calculate coefficient of variation (lower is more consistent)
        let meanVelocity = velocities.reduce(0, +) / Double(velocities.count)
        let variance = velocities.map { pow($0 - meanVelocity, 2) }.reduce(0, +) / Double(velocities.count)
        let standardDeviation = sqrt(variance)
        
        let coefficientOfVariation = meanVelocity > 0 ? standardDeviation / meanVelocity : 0
        let consistencyScore = max(0.3, 1.0 - coefficientOfVariation)
        
        return min(1.0, consistencyScore)
    }
    
    static func calculateSwingEfficiency(poses: [PoseData]) -> Double {
        // Overall swing efficiency score
        let tempoScore = abs(calculateOverallTempo(poses: poses) - 3.0) / 3.0 // Ideal tempo is 3:1
        let rhythmScore = calculateRhythmConsistency(poses: poses)
        let sequenceScore = 0.8 // Simplified sequence score
        
        let efficiency = (1.0 - tempoScore + rhythmScore + sequenceScore) / 3.0
        return max(0.3, min(1.0, efficiency))
    }
    
    // MARK: - Back-View Specific Calculations
    
    static func calculateSwingPlaneAngleFromBack(poses: [PoseData]) -> Double {
        print("📐 Calculating swing plane from back view with \(poses.count) poses")
        
        guard poses.count >= 2 else {
            print("❌ BackView SwingPlane: Not enough poses (\(poses.count))")
            return 0.0
        }
        
        // For back-view, use shoulder line movement to determine swing plane
        let addressPose = poses.first!
        let topPoseIndex = min(poses.count - 1, poses.count * 2 / 3)
        let topPose = poses[topPoseIndex]
        
        print("🔍 BackView: Analyzing address pose (0) and top pose (\(topPoseIndex))")
        
        // Try to get the best available keypoints for back-view analysis
        // Priority: 1) Shoulders (most reliable from back), 2) Wrists (grip position), 3) Elbows
        
        var addressPoint: CGPoint?
        var topPoint: CGPoint?
        var analysisType = "unknown"
        
        // Option 1: Use shoulder center (most reliable for back view)
        if let addressLeftShoulder = addressPose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
           let addressRightShoulder = addressPose.keypoints.first(where: { $0.type == .rightShoulder })?.position,
           let topLeftShoulder = topPose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
           let topRightShoulder = topPose.keypoints.first(where: { $0.type == .rightShoulder })?.position {
            
            addressPoint = CGPoint(
                x: (addressLeftShoulder.x + addressRightShoulder.x) / 2,
                y: (addressLeftShoulder.y + addressRightShoulder.y) / 2
            )
            topPoint = CGPoint(
                x: (topLeftShoulder.x + topRightShoulder.x) / 2,
                y: (topLeftShoulder.y + topRightShoulder.y) / 2
            )
            analysisType = "shoulder_center"
            
        // Option 2: Use wrist positions (hands/grip position)
        } else if let addressLeftWrist = addressPose.keypoints.first(where: { $0.type == .leftWrist })?.position,
                  let addressRightWrist = addressPose.keypoints.first(where: { $0.type == .rightWrist })?.position,
                  let topLeftWrist = topPose.keypoints.first(where: { $0.type == .leftWrist })?.position,
                  let topRightWrist = topPose.keypoints.first(where: { $0.type == .rightWrist })?.position {
            
            // Use grip center (hands close together in golf grip)
            addressPoint = CGPoint(
                x: (addressLeftWrist.x + addressRightWrist.x) / 2,
                y: (addressLeftWrist.y + addressRightWrist.y) / 2
            )
            topPoint = CGPoint(
                x: (topLeftWrist.x + topRightWrist.x) / 2,
                y: (topLeftWrist.y + topRightWrist.y) / 2
            )
            analysisType = "grip_center"
            
        } else {
            print("❌ BackView: Missing critical keypoints for back-view analysis")
            return 0.0
        }
        
        print("🔍 BackView: Using \(analysisType) for swing plane calculation")
        
        guard let addressPos = addressPoint, let topPos = topPoint else {
            print("❌ BackView: Failed to establish reference points")
            return 0.0
        }
        
        // Calculate movement vectors from the selected reference points
        let deltaX = topPos.x - addressPos.x
        let deltaY = topPos.y - addressPos.y
        let totalMovement = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        print("🔍 BackView movement analysis:")
        print("   Address position: (\(String(format: "%.3f", addressPos.x)), \(String(format: "%.3f", addressPos.y)))")
        print("   Top position: (\(String(format: "%.3f", topPos.x)), \(String(format: "%.3f", topPos.y)))")
        print("   Total movement: \(String(format: "%.3f", totalMovement))")
        
        guard totalMovement > 0.02 else { // Minimum movement threshold
            print("❌ BackView: Insufficient movement detected for swing analysis")
            return 0.0
        }
        
        // Calculate vertical and horizontal movement components
        let verticalMovement = abs(deltaY)
        let horizontalMovement = abs(deltaX)
        
        // For back view, calculate swing plane based on movement pattern
        // In back view, lateral movement indicates turn/rotation while vertical shows arc
        let movementAngle = horizontalMovement > 0.001 ? 
            atan2(verticalMovement, horizontalMovement) * 180 / .pi : 45.0
        
        // Add shoulder rotation analysis if available (for additional context)
        var shoulderRotationComponent: Double = 0.0
        if analysisType == "shoulder_center",
           let addressLeftShoulder = addressPose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
           let addressRightShoulder = addressPose.keypoints.first(where: { $0.type == .rightShoulder })?.position,
           let topLeftShoulder = topPose.keypoints.first(where: { $0.type == .leftShoulder })?.position,
           let topRightShoulder = topPose.keypoints.first(where: { $0.type == .rightShoulder })?.position {
            
            let addressShoulderAngle = atan2(addressRightShoulder.y - addressLeftShoulder.y, 
                                            addressRightShoulder.x - addressLeftShoulder.x)
            let topShoulderAngle = atan2(topRightShoulder.y - topLeftShoulder.y,
                                        topRightShoulder.x - topLeftShoulder.x)
            shoulderRotationComponent = abs(topShoulderAngle - addressShoulderAngle) * 180 / .pi
        }
        
        // Combine movement angle with shoulder rotation for more accurate plane estimation
        let swingPlaneAngle = shoulderRotationComponent > 0 ? 
            (movementAngle * 0.6) + (shoulderRotationComponent * 0.4) : movementAngle
        
        print("🔍 BackView calculations:")
        print("   Movement angle: \(String(format: "%.1f", movementAngle))°")
        print("   Shoulder rotation: \(String(format: "%.1f", shoulderRotationComponent))°")
        print("   Combined swing plane: \(String(format: "%.1f", swingPlaneAngle))°")
        print("   Analysis method: \(analysisType)")
        
        // Ensure reasonable golf swing plane angle for back view
        // Back view typically shows slightly different angles than side view
        let clampedAngle = max(20, min(80, swingPlaneAngle))
        
        print("🔍 Final back-view swing plane: \(String(format: "%.2f", clampedAngle))°")
        return clampedAngle
    }
    
    // MARK: - Utility Functions
    
    private static func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}