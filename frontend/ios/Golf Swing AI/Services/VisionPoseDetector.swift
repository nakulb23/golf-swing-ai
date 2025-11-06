import Foundation
import UIKit
import CoreImage
@preconcurrency import AVFoundation
@preconcurrency import Vision

enum VisionPoseError: Error, LocalizedError {
    case noPosesDetected
    case imageProcessingFailed
    case unsupportedOS
    case visionFrameworkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noPosesDetected:
            return "No poses detected in the video"
        case .imageProcessingFailed:
            return "Failed to process image for pose detection"
        case .unsupportedOS:
            return "Body pose detection requires iOS 14.0 or later"
        case .visionFrameworkError(let message):
            return "Vision framework error: \(message)"
        }
    }
}

@MainActor
class VisionPoseDetector: ObservableObject {
    @Published var isInitialized = false
    
    init() {
        checkVisionFrameworkAvailability()
    }
    
    private func checkVisionFrameworkAvailability() {
        // Check if Vision framework is available
        if #available(iOS 14.0, *) {
            // Test if we can actually create a pose request
            _ = VNDetectHumanBodyPoseRequest()
            print("✅ Vision framework body pose detection is available")
            print("📱 iOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
            isInitialized = true
        } else {
            print("❌ iOS 14.0+ required for body pose detection")
            print("📱 Current iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
            isInitialized = false
        }
    }
    
    func detectPoseSequence(from videoURL: URL) async throws -> [MediaPipePoseResult] {
        print("🎬 Starting enhanced Vision framework pose detection for golf video...")
        print("📁 Video URL: \(videoURL.lastPathComponent)")
        print("📁 Full path: \(videoURL.path)")
        
        // Verify video file exists and is readable
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Video file does not exist at path: \(videoURL.path)")
            throw VisionPoseError.imageProcessingFailed
        }
        
        // Check file size and basic properties
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                print("📊 Video file size: \(fileSize / 1024 / 1024) MB")
            }
        } catch {
            print("⚠️ Could not read file attributes: \(error)")
        }
        
        let asset = AVURLAsset(url: videoURL)
        
        // Check if asset can be loaded with detailed analysis
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            print("📊 Video duration: \(String(format: "%.2f", CMTimeGetSeconds(duration)))s")
            print("📊 Video tracks: \(tracks.count)")
            
            // Ensure we have video tracks
            let videoTracks = tracks.filter { $0.mediaType == .video }
            guard !videoTracks.isEmpty else {
                print("❌ No video tracks found in the asset")
                throw VisionPoseError.imageProcessingFailed
            }
            
            print("✅ Found \(videoTracks.count) video track(s)")
            
            // Analyze first video track for detailed info
            if let firstVideoTrack = videoTracks.first {
                let naturalSize = try await firstVideoTrack.load(.naturalSize)
                let nominalFrameRate = try await firstVideoTrack.load(.nominalFrameRate)
                
                print("📊 Video resolution: \(Int(naturalSize.width))x\(Int(naturalSize.height))")
                print("📊 Frame rate: \(String(format: "%.1f", nominalFrameRate)) fps")
                
                // Check if resolution is too low for good pose detection
                if naturalSize.width < 480 || naturalSize.height < 360 {
                    print("⚠️ WARNING: Low resolution video may affect pose detection quality")
                    print("💡 Recommended: 720p or higher for best results")
                }
            }
            
        } catch {
            print("❌ Failed to load video asset: \(error)")
            throw VisionPoseError.imageProcessingFailed
        }
        
        // Configure image generator for better frame extraction
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime.zero // Exact timing
        generator.requestedTimeToleranceAfter = CMTime.zero
        
        // Use larger image size for better pose detection
        generator.maximumSize = CGSize(width: 1280, height: 720) // Higher resolution for better detection
        
        var poseResults: [MediaPipePoseResult] = []
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        
        // Golf-optimized frame selection strategy
        let frameRate: Double
        let frameCount: Int
        
        if totalSeconds <= 5.0 {
            // Short videos: sample more frequently
            frameRate = min(10.0, totalSeconds * 2.0)
            frameCount = Int(totalSeconds * frameRate)
        } else if totalSeconds <= 15.0 {
            // Medium videos: balanced sampling
            frameRate = 5.0
            frameCount = min(Int(totalSeconds * frameRate), 60)
        } else {
            // Long videos: focus on key moments
            frameRate = 3.0
            frameCount = min(Int(totalSeconds * frameRate), 40)
        }
        
        print("📊 Golf video strategy: Processing \(frameCount) frames at \(String(format: "%.1f", frameRate)) fps")
        print("📊 This will analyze frames every \(String(format: "%.1f", 1.0/frameRate)) seconds")
        
        // Generate time points for frame extraction with golf-specific strategy
        var timePoints: [CMTime] = []
        
        // For golf videos, also test middle frames where swing likely occurs
        let keyTestTimes = [
            totalSeconds * 0.25,  // Early part
            totalSeconds * 0.5,   // Middle (likely swing)
            totalSeconds * 0.75   // Later part
        ]
        
        // Add key test frames first for immediate feedback
        for testTime in keyTestTimes {
            if testTime < totalSeconds - 0.1 {
                timePoints.append(CMTime(seconds: testTime, preferredTimescale: 600))
            }
        }
        
        // Add regular sampling frames
        for i in 0..<frameCount {
            let timestamp = Double(i) / frameRate
            let time = CMTime(seconds: min(timestamp, totalSeconds - 0.1), preferredTimescale: 600)
            if !timePoints.contains(where: { Swift.abs(Double(CMTimeGetSeconds($0)) - timestamp) < 0.1 }) {
                timePoints.append(time)
            }
        }
        
        print("📊 Total frames to analyze: \(timePoints.count) (including \(keyTestTimes.count) key test frames)")
        
        // Process frames in batches to avoid memory issues
        let batchSize = 5
        for batchStart in stride(from: 0, to: timePoints.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, timePoints.count)
            let batch = Array(timePoints[batchStart..<batchEnd])
            
            for (index, time) in batch.enumerated() {
                let frameIndex = batchStart + index
                let timestamp = CMTimeGetSeconds(time)
                
                do {
                    print("📸 Extracting frame \(frameIndex + 1)/\(frameCount) at \(String(format: "%.2f", timestamp))s")
                    
                    let cgImage = try await generator.image(at: time).image
                    let image = UIImage(cgImage: cgImage)
                    
                    print("📱 Frame size: \(image.size.width)x\(image.size.height), CGImage: \(cgImage.width)x\(cgImage.height)")
                    let colorSpaceName = cgImage.colorSpace?.name.map { (name: CFString) -> String in String(name) } ?? "unknown"
                    print("📱 Color space: \(colorSpaceName)")
                    print("📱 Bits per component: \(cgImage.bitsPerComponent), Bits per pixel: \(cgImage.bitsPerPixel)")
                    
                    // Try multiple detection strategies for golf videos
                    var poseResult: MediaPipePoseResult? = nil
                    
                    // Strategy 1: Standard detection
                    poseResult = try await detectPoseInImage(image, timestamp: timestamp)
                    
                    // Strategy 2: If failed, try with smaller image (sometimes works better)
                    if poseResult == nil {
                        let smallerImage = resizeImage(image, to: CGSize(width: 640, height: 360))
                        poseResult = try await detectPoseInImage(smallerImage, timestamp: timestamp)
                        if poseResult != nil {
                            print("✅ Frame \(frameIndex + 1): Pose detected using smaller image strategy")
                        }
                    }
                    
                    // Strategy 3: If still failed, try with enhanced contrast
                    if poseResult == nil {
                        let enhancedImage = enhanceImageForPoseDetection(image)
                        poseResult = try await detectPoseInImage(enhancedImage, timestamp: timestamp)
                        if poseResult != nil {
                            print("✅ Frame \(frameIndex + 1): Pose detected using enhanced contrast strategy")
                        }
                    }
                    
                    if let result = poseResult {
                        poseResults.append(result)
                        print("✅ Frame \(frameIndex + 1): Pose detected with confidence \(String(format: "%.3f", result.confidence))")
                    } else {
                        print("⚠️ Frame \(frameIndex + 1): No pose detected with any strategy")
                    }
                } catch {
                    print("❌ Failed to process frame \(frameIndex + 1): \(error.localizedDescription)")
                    if let error = error as? VisionPoseError {
                        print("   Vision error details: \(error.localizedDescription)")
                    }
                    continue
                }
            }
            
            // Small delay between batches to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        print("📊 Final results: \(poseResults.count) poses detected from \(frameCount) frames")
        
        if poseResults.isEmpty {
            print("❌ CRITICAL: No poses detected in any frame")
            print("💡 This could be due to:")
            print("   • Video quality too low")
            print("   • Person not visible or too small in frame")
            print("   • Poor lighting conditions")
            print("   • Unsupported video format")
            throw VisionPoseError.noPosesDetected
        }
        
        // Analyze camera angle suitability for golf
        analyzeCameraAngleSuitability(poseResults)
        
        return poseResults
    }
    
    func detectPoseInImage(_ image: UIImage, timestamp: TimeInterval) async throws -> MediaPipePoseResult? {
        print("🔍 Starting Vision pose detection for frame at \(String(format: "%.2f", timestamp))s")
        
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage from UIImage")
            return nil
        }
        
        print("📱 Processing image: \(cgImage.width)x\(cgImage.height)")
        
        // Check iOS version
        guard #available(iOS 14.0, *) else {
            print("❌ Vision body pose detection requires iOS 14.0+")
            return nil
        }
        
        // Create the request and handler (these don't throw)
        let request = VNDetectHumanBodyPoseRequest()
        // Don't set revision - let it use default
        // request.revision = VNDetectHumanBodyPoseRequestRevision1

        // Create handler using CIImage for better compatibility
        let ciImage = CIImage(cgImage: cgImage)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        print("✅ Vision request and handler created successfully")
        
        do {
            print("🚀 Performing Vision request...")
            try handler.perform([request])
            
            // Debug: Check all observations regardless of confidence
            if let allObservations = request.results {
                print("📊 Vision returned \(allObservations.count) total observations")
                
                for (index, obs) in allObservations.enumerated() {
                    print("   Observation \(index): confidence = \(String(format: "%.3f", obs.confidence))")
                }
                
                // Try with very low confidence first to see if anything is detected
                let veryLowConfidenceObs = allObservations.filter { $0.confidence > 0.1 }
                print("📊 Found \(veryLowConfidenceObs.count) observations with confidence > 0.1")
                
                if veryLowConfidenceObs.isEmpty {
                    // Try even lower threshold
                    let anyObs = allObservations.filter { $0.confidence > 0.0 }
                    print("📊 Found \(anyObs.count) observations with any confidence > 0.0")
                    
                    if anyObs.isEmpty {
                        print("❌ ZERO observations detected - this suggests the image doesn't contain detectable human poses")
                        print("💡 Troubleshooting suggestions:")
                        print("   • Image might be too small, blurry, or low quality")
                        print("   • Person might not be fully visible in frame")
                        print("   • Lighting conditions might be poor")
                        print("   • Camera angle might not show human body clearly")
                        return nil
                    }
                }
                
                // Use the best observation available, even with low confidence
                guard let bestObservation = allObservations.max(by: { $0.confidence < $1.confidence }) else {
                    print("⚠️ No observations at all")
                    return nil
                }
                
                print("📊 Using best observation with confidence: \(String(format: "%.3f", bestObservation.confidence))")
                
                let landmarks = try extractLandmarks(from: bestObservation)
                print("✅ Vision extracted \(landmarks.count) landmarks")
                
                // Accept lower confidence for golf videos since they can be challenging
                let result = MediaPipePoseResult(
                    landmarks: landmarks,
                    timestamp: timestamp,
                    confidence: bestObservation.confidence
                )
                return result
                
            } else {
                print("❌ No observations returned from Vision framework at all")
                return nil
            }
            
        } catch {
            print("❌ Failed to perform Vision request: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractLandmarks(from observation: VNHumanBodyPoseObservation) throws -> [MediaPipeLandmark] {
        var landmarks: [MediaPipeLandmark] = []
        
        // Map Vision framework joint names to our landmark format
        let jointMappings: [(VNHumanBodyPoseObservation.JointName, String)] = [
            (.nose, "nose"),
            (.leftEye, "left_eye"),
            (.rightEye, "right_eye"),
            (.leftEar, "left_ear"),
            (.rightEar, "right_ear"),
            (.leftShoulder, "left_shoulder"),
            (.rightShoulder, "right_shoulder"),
            (.leftElbow, "left_elbow"),
            (.rightElbow, "right_elbow"),
            (.leftWrist, "left_wrist"),
            (.rightWrist, "right_wrist"),
            (.leftHip, "left_hip"),
            (.rightHip, "right_hip"),
            (.leftKnee, "left_knee"),
            (.rightKnee, "right_knee"),
            (.leftAnkle, "left_ankle"),
            (.rightAnkle, "right_ankle")
        ]
        
        for (visionJoint, landmarkName) in jointMappings {
            do {
                let recognizedPoint = try observation.recognizedPoint(visionJoint)
                
                // Only include points with sufficient confidence
                if recognizedPoint.confidence > 0.1 {
                    let landmark = MediaPipeLandmark(
                        name: landmarkName,
                        position: CGPoint(x: recognizedPoint.location.x, y: 1.0 - recognizedPoint.location.y), // Flip Y coordinate
                        confidence: recognizedPoint.confidence,
                        visibility: recognizedPoint.confidence
                    )
                    landmarks.append(landmark)
                }
            } catch {
                // Joint recognition failed - continue with other joints
                print("⚠️ Failed to recognize joint \(landmarkName): \(error)")
                continue
            }
        }
        
        return landmarks
    }
    
    private func analyzeCameraAngleSuitability(_ poseResults: [MediaPipePoseResult]) {
        guard let firstPose = poseResults.first else { return }
        
        // Analyze camera angle based on shoulder and hip positions
        if let leftShoulder = firstPose.landmarks.first(where: { $0.name == "left_shoulder" }),
           let rightShoulder = firstPose.landmarks.first(where: { $0.name == "right_shoulder" }),
           let leftHip = firstPose.landmarks.first(where: { $0.name == "left_hip" }),
           let rightHip = firstPose.landmarks.first(where: { $0.name == "right_hip" }) {

            // Calculate horizontal spread of shoulders and hips
            let shoulderSpread = Swift.abs(Double(rightShoulder.position.x) - Double(leftShoulder.position.x))
            let hipSpread = Swift.abs(Double(rightHip.position.x) - Double(leftHip.position.x))
            
            print("📐 Camera angle analysis:")
            print("  → Shoulder spread: \(String(format: "%.3f", shoulderSpread))")
            print("  → Hip spread: \(String(format: "%.3f", hipSpread))")
            
            // Determine camera angle
            if shoulderSpread < 0.15 && hipSpread < 0.15 {
                print("📐 Camera angle: DOWN-THE-LINE view detected")
                print("⭐ EXCELLENT for golf swing analysis!")
                print("💡 This angle shows weight transfer, spine tilt, and swing plane clearly")
            } else if shoulderSpread > 0.3 || hipSpread > 0.3 {
                print("📐 Camera angle: SIDE view detected - EXCELLENT for golf analysis!")
            } else {
                print("📐 Camera angle: ANGLED view detected - Good for golf analysis")
            }
            
            // Check for pose quality issues that might affect analysis
            let avgConfidence = poseResults.reduce(0.0) { $0 + $1.confidence } / Float(poseResults.count)
            print("📊 Average pose confidence: \(String(format: "%.2f", avgConfidence))")
            
            if avgConfidence < 0.6 {
                print("⚠️  Low pose detection confidence - consider:")
                print("   • Better lighting")
                print("   • Closer camera position")
                print("   • Keep full body in frame")
                print("   • Stable camera mount")
            }
        }
    }
    
    // MARK: - Helper Functions for Enhanced Detection
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func enhanceImageForPoseDetection(_ image: UIImage) -> UIImage {
        guard let inputImage = CIImage(image: image) else { return image }
        
        // Apply contrast and brightness adjustment for better pose detection
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey)      // Increase contrast
        filter.setValue(0.1, forKey: kCIInputBrightnessKey)    // Slight brightness boost
        filter.setValue(1.1, forKey: kCIInputSaturationKey)    // Slight saturation boost
        
        guard let outputImage = filter.outputImage else { return image }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
}

