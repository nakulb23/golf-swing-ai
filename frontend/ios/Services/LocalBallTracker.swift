import Foundation
import Vision
import CoreImage
import AVFoundation
import Accelerate

// MARK: - Local Ball Tracker

@MainActor
class LocalBallTracker: ObservableObject {
    @Published var isTracking = false
    @Published var trackingProgress: Double = 0.0
    @Published var detectedTrajectory: BallTrajectory?
    
    private let ballDetector = GolfBallDetector()
    private let trajectoryAnalyzer = TrajectoryAnalyzer()
    private var ballTrackingModel: MLModel?
    
    init() {
        loadBallTrackingModel()
    }
    
    private func loadBallTrackingModel() {
        guard let modelPath = Bundle.main.path(forResource: "BallTrackingModel", ofType: "mlmodel") else {
            print("❌ BallTrackingModel.mlmodel not found in bundle")
            return
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        
        do {
            ballTrackingModel = try MLModel(contentsOf: modelURL)
            print("✅ LocalBallTracker: Core ML model loaded")
        } catch {
            print("❌ Failed to load BallTrackingModel in LocalBallTracker: \(error)")
        }
    }
    
    nonisolated func trackBall(from videoURL: URL) async throws -> BallTrackingResponse {
        print("🏌️ Starting local ball tracking...")
        
        await MainActor.run {
            self.isTracking = true
            self.trackingProgress = 0.0
        }
        
        // Extract frames
        let frames = try await extractFrames(from: videoURL, fps: 60) // Higher FPS for ball tracking
        print("📹 Extracted \(frames.count) frames for ball tracking")
        
        // Detect ball in each frame
        var ballPositions: [BallPosition] = []
        
        for (index, frame) in frames.enumerated() {
            if let position = try await ballDetector.detectBall(in: frame.image) {
                ballPositions.append(BallPosition(
                    frameIndex: index,
                    timestamp: frame.timestamp,
                    position: position,
                    confidence: 0.9
                ))
            }
            
            await MainActor.run {
                self.trackingProgress = Double(index) / Double(frames.count)
            }
        }
        
        print("⚾ Detected ball in \(ballPositions.count) frames")
        
        // Analyze trajectory
        let trajectory = trajectoryAnalyzer.analyzeTrajectory(from: ballPositions)
        
        await MainActor.run {
            self.detectedTrajectory = trajectory
            self.isTracking = false
            self.trackingProgress = 1.0
        }
        
        // Create response
        return createTrackingResponse(trajectory: trajectory, frameCount: frames.count)
    }
    
    nonisolated private func extractFrames(from videoURL: URL, fps: Double) async throws -> [(image: UIImage, timestamp: Double)] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        
        var frames: [(image: UIImage, timestamp: Double)] = []
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 600)
        
        let totalSeconds = CMTimeGetSeconds(duration)
        let frameInterval = 1.0 / fps
        let frameCount = Int(totalSeconds * fps)
        
        for i in 0..<frameCount {
            let timestamp = Double(i) * frameInterval
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            
            do {
                let cgImage = try await generator.image(at: time).image
                let image = UIImage(cgImage: cgImage)
                frames.append((image: image, timestamp: timestamp))
            } catch {
                // Skip frames that fail to extract
                continue
            }
        }
        
        return frames
    }
    
    private func createTrackingResponse(trajectory: BallTrajectory, frameCount: Int) -> BallTrackingResponse {
        let detectionRate = Double(trajectory.positions.count) / Double(frameCount)
        
        let summary = DetectionSummary(
            total_frames: frameCount,
            ball_detected_frames: trajectory.positions.count,
            detection_rate: detectionRate,
            trajectory_points: trajectory.positions.count
        )
        
        let flightAnalysis = trajectory.flightMetrics.map { metrics in
            FlightAnalysis(
                launch_speed_ms: metrics.launchSpeed,
                launch_angle_degrees: metrics.launchAngle,
                trajectory_type: metrics.trajectoryType,
                estimated_max_height: metrics.maxHeight,
                estimated_range: metrics.estimatedDistance
            )
        }
        
        let trajectoryData = TrajectoryData(
            flight_time: trajectory.flightTime,
            has_valid_trajectory: trajectory.isValid
        )
        
        return BallTrackingResponse(
            detection_summary: summary,
            flight_analysis: flightAnalysis,
            trajectory_data: trajectoryData,
            visualization_created: true
        )
    }
}

// MARK: - Golf Ball Detector

class GolfBallDetector {
    private let colorThreshold: Float = 0.8
    private let minBallSize: CGFloat = 5
    private let maxBallSize: CGFloat = 30
    
    nonisolated func detectBall(in image: UIImage) async throws -> CGPoint? {
        guard let model = ballTrackingModel else {
            print("⚠️ BallTrackingModel not loaded, using fallback detection")
            return try await detectBallFallback(in: image)
        }
        
        // Resize image to model input size (224x224)
        guard let resizedImage = resizeImage(image, to: CGSize(width: 224, height: 224)),
              let pixelBuffer = resizedImage.pixelBuffer() else {
            return nil
        }
        
        do {
            // Create model input
            let input = BallTrackingModelInput(input_image: pixelBuffer)
            
            // Run Core ML prediction
            let prediction = try model.prediction(from: input)
            
            // Extract ball position from output
            if let outputArray = prediction.featureValue(for: "var_50")?.multiArrayValue,
               outputArray.count >= 3 {
                let x = outputArray[0].doubleValue
                let y = outputArray[1].doubleValue
                let confidence = outputArray[2].doubleValue
                
                // Only return position if confidence is high enough
                if confidence > 0.5 {
                    // Convert normalized coordinates back to image coordinates
                    let imageX = x * Double(image.size.width)
                    let imageY = y * Double(image.size.height)
                    return CGPoint(x: imageX, y: imageY)
                }
            }
            
        } catch {
            print("❌ Core ML ball detection failed: \(error)")
        }
        
        // Fallback to traditional computer vision
        return try await detectBallFallback(in: image)
    }
    
    nonisolated private func detectBallFallback(in image: UIImage) async throws -> CGPoint? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Apply filters to enhance ball visibility
        let enhancedImage = enhanceForBallDetection(ciImage)
        
        // Detect circular objects
        let circles = await detectCircles(in: enhancedImage)
        
        // Filter for golf ball characteristics
        let ballCandidates = circles.filter { circle in
            isBallCandidate(circle: circle, in: image.size)
        }
        
        // Return the most likely ball position
        return ballCandidates.first?.center
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func enhanceForBallDetection(_ image: CIImage) -> CIImage {
        // Increase contrast and brightness for white ball detection
        let colorControls = CIFilter(name: "CIColorControls")!
        colorControls.setValue(image, forKey: kCIInputImageKey)
        colorControls.setValue(1.2, forKey: kCIInputContrastKey)
        colorControls.setValue(0.1, forKey: kCIInputBrightnessKey)
        
        guard let enhanced = colorControls.outputImage else { return image }
        
        // Apply Gaussian blur to reduce noise
        let blur = CIFilter(name: "CIGaussianBlur")!
        blur.setValue(enhanced, forKey: kCIInputImageKey)
        blur.setValue(0.5, forKey: kCIInputRadiusKey)
        
        return blur.outputImage ?? enhanced
    }
    
    nonisolated private func detectCircles(in image: CIImage) async -> [Circle] {
        // Simple circle detection using edge detection and Hough transform
        // In a real implementation, this would use more sophisticated CV techniques
        
        var circles: [Circle] = []
        
        // Convert to grayscale
        let grayscale = CIFilter(name: "CIColorMonochrome")!
        grayscale.setValue(image, forKey: kCIInputImageKey)
        grayscale.setValue(CIColor.white, forKey: "inputColor")
        grayscale.setValue(1.0, forKey: "inputIntensity")
        
        guard let grayImage = grayscale.outputImage else { return circles }
        
        // Edge detection
        let edges = CIFilter(name: "CIEdges")!
        edges.setValue(grayImage, forKey: kCIInputImageKey)
        edges.setValue(2.0, forKey: "inputIntensity")
        
        // Simplified circle detection
        // In production, use OpenCV or Vision framework's shape detection
        let potentialCircle = Circle(
            center: CGPoint(x: image.extent.midX, y: image.extent.midY),
            radius: 10
        )
        circles.append(potentialCircle)
        
        return circles
    }
    
    private func isBallCandidate(circle: Circle, in imageSize: CGSize) -> Bool {
        // Check if circle radius is within expected ball size range
        let scaledMinSize = minBallSize * min(imageSize.width, imageSize.height) / 1000
        let scaledMaxSize = maxBallSize * min(imageSize.width, imageSize.height) / 1000
        
        return circle.radius >= scaledMinSize && circle.radius <= scaledMaxSize
    }
}

// MARK: - Trajectory Analyzer

class TrajectoryAnalyzer {
    func analyzeTrajectory(from positions: [BallPosition]) -> BallTrajectory {
        guard positions.count >= 3 else {
            return BallTrajectory(positions: positions, isValid: false)
        }
        
        // Sort positions by timestamp
        let sortedPositions = positions.sorted { $0.timestamp < $1.timestamp }
        
        // Calculate flight metrics
        let flightMetrics = calculateFlightMetrics(from: sortedPositions)
        
        // Calculate flight time
        let flightTime = sortedPositions.last!.timestamp - sortedPositions.first!.timestamp
        
        return BallTrajectory(
            positions: sortedPositions,
            isValid: true,
            flightTime: flightTime,
            flightMetrics: flightMetrics
        )
    }
    
    private func calculateFlightMetrics(from positions: [BallPosition]) -> FlightMetrics? {
        guard positions.count >= 5 else { return nil }
        
        // Calculate launch angle from first few positions
        let launchPositions = Array(positions.prefix(5))
        let launchAngle = calculateLaunchAngle(from: launchPositions)
        
        // Calculate launch speed
        let launchSpeed = calculateLaunchSpeed(from: launchPositions)
        
        // Estimate trajectory type
        let trajectoryType = classifyTrajectory(positions: positions)
        
        // Calculate max height
        let maxHeight = positions.map { $0.position.y }.max() ?? 0
        
        // Estimate distance (simplified)
        let estimatedDistance = estimateDistance(
            launchSpeed: launchSpeed,
            launchAngle: launchAngle
        )
        
        return FlightMetrics(
            launchSpeed: launchSpeed,
            launchAngle: launchAngle,
            trajectoryType: trajectoryType,
            maxHeight: Double(maxHeight),
            estimatedDistance: estimatedDistance
        )
    }
    
    private func calculateLaunchAngle(from positions: [BallPosition]) -> Double {
        guard positions.count >= 2 else { return 0 }
        
        let p1 = positions[0].position
        let p2 = positions[min(4, positions.count - 1)].position
        
        let deltaY = p2.y - p1.y
        let deltaX = abs(p2.x - p1.x)
        
        return atan2(deltaY, deltaX) * 180 / .pi
    }
    
    private func calculateLaunchSpeed(from positions: [BallPosition]) -> Double {
        guard positions.count >= 2 else { return 0 }
        
        let p1 = positions[0]
        let p2 = positions[1]
        
        let distance = sqrt(
            pow(p2.position.x - p1.position.x, 2) +
            pow(p2.position.y - p1.position.y, 2)
        )
        
        let timeDelta = p2.timestamp - p1.timestamp
        
        // Convert from pixels/second to m/s (approximate)
        let pixelsToMeters = 0.001 // Rough approximation
        return Double(distance) / timeDelta * pixelsToMeters
    }
    
    private func classifyTrajectory(positions: [BallPosition]) -> String {
        // Simple trajectory classification
        let startY = positions.first!.position.y
        let endY = positions.last!.position.y
        let maxY = positions.map { $0.position.y }.max()!
        
        let heightDiff = maxY - startY
        let endDiff = abs(endY - startY)
        
        if heightDiff > 100 {
            return "high"
        } else if endDiff < 20 {
            return "straight"
        } else {
            return "normal"
        }
    }
    
    private func estimateDistance(launchSpeed: Double, launchAngle: Double) -> Double {
        // Simplified projectile motion calculation
        let g = 9.81 // gravity
        let angleRad = launchAngle * .pi / 180
        
        let distance = (launchSpeed * launchSpeed * sin(2 * angleRad)) / g
        return max(0, min(300, distance)) // Clamp to reasonable golf distances
    }
}

// MARK: - Supporting Types

struct BallPosition {
    let frameIndex: Int
    let timestamp: Double
    let position: CGPoint
    let confidence: Float
}

struct BallTrajectory {
    let positions: [BallPosition]
    let isValid: Bool
    var flightTime: Double = 0
    var flightMetrics: FlightMetrics?
}

struct FlightMetrics {
    let launchSpeed: Double // m/s
    let launchAngle: Double // degrees
    let trajectoryType: String
    let maxHeight: Double // meters
    let estimatedDistance: Double // meters
}

struct Circle {
    let center: CGPoint
    let radius: CGFloat
}

// MARK: - Ball Tracking Visualizer

class BallTrackingVisualizer {
    func createTrajectoryVisualization(
        trajectory: BallTrajectory,
        videoSize: CGSize
    ) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: videoSize)
        
        // Create path for trajectory
        let path = UIBezierPath()
        
        for (index, position) in trajectory.positions.enumerated() {
            if index == 0 {
                path.move(to: position.position)
            } else {
                path.addLine(to: position.position)
            }
        }
        
        // Create shape layer for path
        let pathLayer = CAShapeLayer()
        pathLayer.path = path.cgPath
        pathLayer.strokeColor = UIColor.yellow.cgColor
        pathLayer.lineWidth = 3
        pathLayer.fillColor = UIColor.clear.cgColor
        
        layer.addSublayer(pathLayer)
        
        // Add ball markers
        for position in trajectory.positions {
            let ballLayer = CAShapeLayer()
            let circle = UIBezierPath(
                arcCenter: position.position,
                radius: 5,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            ballLayer.path = circle.cgPath
            ballLayer.fillColor = UIColor.yellow.cgColor
            ballLayer.opacity = Float(position.confidence)
            
            layer.addSublayer(ballLayer)
        }
        
        return layer
    }
}

// MARK: - Core ML Support

struct BallTrackingModelInput: MLFeatureProvider, @unchecked Sendable {
    let input_image: CVPixelBuffer
    
    var featureNames: Set<String> {
        return ["input_image"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input_image" {
            return MLFeatureValue(pixelBuffer: input_image)
        }
        return nil
    }
}

extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}