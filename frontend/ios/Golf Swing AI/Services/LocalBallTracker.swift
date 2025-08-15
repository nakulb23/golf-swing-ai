import Foundation
import CoreImage
@preconcurrency import AVFoundation
import Accelerate
@preconcurrency import CoreML

// MARK: - Ball Tracking Errors

enum BallTrackingError: LocalizedError {
    case noFramesExtracted
    case frameExtractionFailed(Error)
    case noBallDetected
    case trajectoryAnalysisFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noFramesExtracted:
            return "No frames could be extracted from the video"
        case .frameExtractionFailed(let error):
            return "Frame extraction failed: \(error.localizedDescription)"
        case .noBallDetected:
            return "No golf ball could be detected in the video"
        case .trajectoryAnalysisFailed(let error):
            return "Trajectory analysis failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Local Ball Tracker

@MainActor
class LocalBallTracker: ObservableObject {
    @Published var isTracking = false
    @Published var trackingProgress: Double = 0.0
    @Published var detectedTrajectory: BallTrajectory?
    
    private var ballDetector: GolfBallDetector!
    private let trajectoryAnalyzer = TrajectoryAnalyzer()
    private var ballTrackingModel: MLModel?
    
    init() {
        ballDetector = GolfBallDetector()
        loadBallTrackingModel()
    }
    
    private func loadBallTrackingModel() {
        do {
            // Try to load compiled model first (.mlmodelc)
            if let compiledModelURL = Bundle.main.url(forResource: "BallTrackingModel", withExtension: "mlmodelc") {
                ballTrackingModel = try MLModel(contentsOf: compiledModelURL)
                print("✅ Ball tracking model loaded from compiled model (.mlmodelc)")
            }
            // Try to load uncompiled model (.mlmodel)
            else if let modelURL = Bundle.main.url(forResource: "BallTrackingModel", withExtension: "mlmodel") {
                ballTrackingModel = try MLModel(contentsOf: modelURL)
                print("✅ Ball tracking model loaded from uncompiled model (.mlmodel)")
            }
            // Try to load package model (.mlpackage)
            else if let packageURL = Bundle.main.url(forResource: "BallTrackingModel", withExtension: "mlpackage") {
                ballTrackingModel = try MLModel(contentsOf: packageURL)
                print("✅ Ball tracking model loaded from package (.mlpackage)")
            }
            else {
                print("❌ BallTrackingModel not found in any format")
                print("❌ Ensure model is added to Xcode project with proper target membership")
                ballTrackingModel = nil
            }
            
            // Reinitialize detector with the loaded model
            ballDetector = GolfBallDetector(ballTrackingModel: ballTrackingModel)
            
            if ballTrackingModel != nil {
                print("✅ LocalBallTracker: Core ML model loaded successfully")
            } else {
                print("⚠️ LocalBallTracker: Using fallback computer vision algorithms")
            }
        } catch {
            print("❌ Failed to load BallTrackingModel: \(error)")
            ballTrackingModel = nil
            ballDetector = GolfBallDetector(ballTrackingModel: nil)
        }
    }
    
    func trackBall(from videoURL: URL) async throws -> BallTrackingResponse {
        print("🏌️ Starting local ball tracking...")
        
        defer {
            Task { @MainActor in
                self.isTracking = false
            }
        }
        
        await MainActor.run {
            self.isTracking = true
            self.trackingProgress = 0.0
        }
        
        // Extract frames with error handling
        let frames: [(image: UIImage, timestamp: Double)]
        do {
            frames = try await extractFrames(from: videoURL, fps: 30) // Reduced FPS for stability
            print("📹 Extracted \(frames.count) frames for ball tracking")
            
            guard !frames.isEmpty else {
                throw BallTrackingError.noFramesExtracted
            }
        } catch {
            print("❌ Frame extraction failed: \(error)")
            throw BallTrackingError.frameExtractionFailed(error)
        }
        
        // Detect ball in each frame with error handling
        var ballPositions: [BallPosition] = []
        
        for (index, frame) in frames.enumerated() {
            do {
                if let position = try await ballDetector.detectBall(in: frame.image) {
                    ballPositions.append(BallPosition(
                        frameIndex: index,
                        timestamp: frame.timestamp,
                        position: position,
                        confidence: 0.9
                    ))
                }
            } catch {
                print("⚠️ Ball detection failed for frame \(index): \(error)")
                // Continue with next frame rather than crashing
            }
            
            await MainActor.run {
                self.trackingProgress = Double(index) / Double(frames.count)
            }
        }
        
        print("⚾ Detected ball in \(ballPositions.count) frames out of \(frames.count)")
        
        // Ensure we have some ball detections
        guard !ballPositions.isEmpty else {
            throw BallTrackingError.noBallDetected
        }
        
        // Analyze trajectory with error handling
        let trajectory: BallTrajectory
        do {
            trajectory = trajectoryAnalyzer.analyzeTrajectory(from: ballPositions)
        } catch {
            print("❌ Trajectory analysis failed: \(error)")
            throw BallTrackingError.trajectoryAnalysisFailed(error)
        }
        
        await MainActor.run {
            self.detectedTrajectory = trajectory
            self.trackingProgress = 1.0
        }
        
        // Create response
        return createTrackingResponse(trajectory: trajectory, frameCount: frames.count)
    }
    
    nonisolated private func extractFrames(from videoURL: URL, fps: Double) async throws -> [(image: UIImage, timestamp: Double)] {
        let asset = AVURLAsset(url: videoURL)
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

class GolfBallDetector: @unchecked Sendable {
    private let colorThreshold: Float = 0.8
    private let minBallSize: CGFloat = 5
    private let maxBallSize: CGFloat = 30
    private weak var ballTrackingModel: MLModel?
    
    init(ballTrackingModel: MLModel? = nil) {
        self.ballTrackingModel = ballTrackingModel
    }
    
    func detectBall(in image: UIImage) async throws -> CGPoint? {
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
            // Create model input dictionary for generic MLModel
            let inputDict = try MLDictionaryFeatureProvider(dictionary: [
                "input_image": MLFeatureValue(pixelBuffer: pixelBuffer)
            ])
            
            // Run Core ML prediction
            let prediction = try await model.prediction(from: inputDict)
            
            // Try multiple output names commonly used in ball tracking models
            let outputNames = ["output", "ball_position", "coordinates", "var_50", "Identity"]
            
            for outputName in outputNames {
                if let outputArray = prediction.featureValue(for: outputName)?.multiArrayValue,
                   outputArray.count >= 2 {
                    let x = outputArray[0].doubleValue
                    let y = outputArray[1].doubleValue
                    let confidence = outputArray.count > 2 ? outputArray[2].doubleValue : 0.8
                    
                    // Only return position if confidence is high enough
                    if confidence > 0.3 {
                        // Convert normalized coordinates back to image coordinates
                        let imageX = x * Double(image.size.width)
                        let imageY = y * Double(image.size.height)
                        print("✅ Ball detected at (\(imageX), \(imageY)) with confidence \(confidence)")
                        return CGPoint(x: imageX, y: imageY)
                    }
                }
            }
            
        } catch {
            print("❌ Core ML ball detection failed: \(error)")
        }
        
        // Fallback to traditional computer vision
        return try await detectBallFallback(in: image)
    }
    
    private func detectBallFallback(in image: UIImage) async throws -> CGPoint? {
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
    
    private func detectCircles(in image: CIImage) async -> [DetectedCircle] {
        var circles: [DetectedCircle] = []
        
        // Convert to grayscale for better edge detection
        let grayscale = CIFilter(name: "CIColorMonochrome")!
        grayscale.setValue(image, forKey: kCIInputImageKey)
        grayscale.setValue(CIColor.white, forKey: "inputColor")
        grayscale.setValue(1.0, forKey: "inputIntensity")
        
        guard let grayImage = grayscale.outputImage else { return circles }
        
        // Edge detection using Canny-like filter
        let edges = CIFilter(name: "CIEdges")!
        edges.setValue(grayImage, forKey: kCIInputImageKey)
        edges.setValue(1.5, forKey: "inputIntensity")
        
        guard let edgeImage = edges.outputImage else { return circles }
        
        // Create context for pixel analysis
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        guard let cgImage = context.createCGImage(edgeImage, from: edgeImage.extent) else { return circles }
        
        // Simplified Hough Transform for circle detection
        let width = cgImage.width
        let height = cgImage.height
        let minRadius = 5
        
        // Sample grid points to look for circular patterns
        for y in stride(from: minRadius, to: height - minRadius, by: 8) {
            for x in stride(from: minRadius, to: width - minRadius, by: 8) {
                
                // Check if this point could be a circle center
                var circleVotes = 0
                let sampleRadius = 15
                
                // Sample points around the potential center
                for angle in stride(from: 0, to: 360, by: 45) {
                    let radians = Double(angle) * .pi / 180.0
                    let sampleX = x + Int(Double(sampleRadius) * cos(radians))
                    let sampleY = y + Int(Double(sampleRadius) * sin(radians))
                    
                    if sampleX >= 0 && sampleX < width && sampleY >= 0 && sampleY < height {
                        if getPixelIntensity(cgImage: cgImage, x: sampleX, y: sampleY) > 128 {
                            circleVotes += 1
                        }
                    }
                }
                
                // If enough edge points found around this center, it's likely a circle
                if circleVotes >= 4 {
                    let confidence = Double(circleVotes) / 8.0
                    
                    // Additional validation: check if it's white/light colored (golf ball)
                    let centerIntensity = getPixelIntensity(cgImage: cgImage, x: x, y: y)
                    if centerIntensity > 100 || confidence > 0.6 {
                        
                        // Convert to normalized coordinates
                        let normalizedCenter = CGPoint(
                            x: Double(x) / Double(width),
                            y: Double(y) / Double(height)
                        )
                        
                        let circle = DetectedCircle(
                            center: CGPoint(
                                x: normalizedCenter.x * image.extent.width + image.extent.minX,
                                y: normalizedCenter.y * image.extent.height + image.extent.minY
                            ),
                            radius: Double(sampleRadius)
                        )
                        
                        circles.append(circle)
                    }
                }
            }
        }
        
        // Remove duplicate/overlapping detections
        circles = removeDuplicateCircles(circles)
        
        // Sort by likelihood (distance from center + size factors)
        circles.sort { circle1, circle2 in
            let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
            let dist1 = distance(from: circle1.center, to: center)
            let dist2 = distance(from: circle2.center, to: center)
            return dist1 < dist2
        }
        
        return Array(circles.prefix(3)) // Return top 3 candidates
    }
    
    private func getPixelIntensity(cgImage: CGImage, x: Int, y: Int) -> UInt8 {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let buffer = CFDataGetBytePtr(data) else { return 0 }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        
        if pixelOffset < CFDataGetLength(data) && bytesPerPixel > 0 {
            return buffer[pixelOffset]
        }
        return 0
    }
    
    private func removeDuplicateCircles(_ circles: [DetectedCircle]) -> [DetectedCircle] {
        var uniqueCircles: [DetectedCircle] = []
        let overlapThreshold: Double = 20.0 // pixels
        
        for circle in circles {
            var isUnique = true
            for existingCircle in uniqueCircles {
                let dist = distance(from: circle.center, to: existingCircle.center)
                if dist < overlapThreshold {
                    isUnique = false
                    break
                }
            }
            if isUnique {
                uniqueCircles.append(circle)
            }
        }
        
        return uniqueCircles
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func isBallCandidate(circle: DetectedCircle, in imageSize: CGSize) -> Bool {
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

struct DetectedCircle {
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