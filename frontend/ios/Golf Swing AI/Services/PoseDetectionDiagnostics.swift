import Foundation
@preconcurrency import Vision
import UIKit
@preconcurrency import AVFoundation

@MainActor
class PoseDetectionDiagnostics: ObservableObject {
    
    static func runDiagnostics() {
        print("🔍 Running Pose Detection Diagnostics...")
        print("=====================================")
        
        // Check iOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("📱 iOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        
        // Check Vision framework availability
        if #available(iOS 14.0, *) {
            print("✅ iOS 14.0+ detected - Vision body pose detection supported")
            
            // Test if VNDetectHumanBodyPoseRequest is available
            let request = VNDetectHumanBodyPoseRequest()
            print("✅ VNDetectHumanBodyPoseRequest created successfully")
            print("📊 Request revision: \(request.revision)")
            
            // Test supported joints
            let allJointNames: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .leftEye, .rightEye, .leftEar, .rightEar,
                .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
                .leftWrist, .rightWrist, .leftHip, .rightHip,
                .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
                .root, .neck
            ]
            let jointDescriptions = allJointNames.map { joint in
                switch joint {
                case .nose: return "nose"
                case .leftEye: return "leftEye"
                case .rightEye: return "rightEye"
                case .leftEar: return "leftEar"
                case .rightEar: return "rightEar"
                case .leftShoulder: return "leftShoulder"
                case .rightShoulder: return "rightShoulder"
                case .leftElbow: return "leftElbow"
                case .rightElbow: return "rightElbow"
                case .leftWrist: return "leftWrist"
                case .rightWrist: return "rightWrist"
                case .leftHip: return "leftHip"
                case .rightHip: return "rightHip"
                case .leftKnee: return "leftKnee"
                case .rightKnee: return "rightKnee"
                case .leftAnkle: return "leftAnkle"
                case .rightAnkle: return "rightAnkle"
                case .root: return "root"
                case .neck: return "neck"
                default: return "unknown"
                }
            }
            print("📊 Available joints (\(allJointNames.count)): \(jointDescriptions.joined(separator: ", "))")
            
        } else {
            print("❌ iOS version too old for Vision body pose detection")
        }
        
        // Test with a simple test image
        testWithSimpleImage()
        
        print("=====================================")
        print("✅ Diagnostics complete")
    }
    
    private static func testWithSimpleImage() {
        print("🖼️ Testing with simple test image...")
        
        // Create a simple test image with a basic human figure
        let imageSize = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let testImage = renderer.image { context in
            let cgContext = context.cgContext
            
            // Background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            // Draw a simple stick figure
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(8.0)
            
            // Head
            let headCenter = CGPoint(x: 150, y: 60)
            cgContext.addEllipse(in: CGRect(x: headCenter.x - 20, y: headCenter.y - 20, width: 40, height: 40))
            cgContext.strokePath()
            
            // Body
            cgContext.move(to: CGPoint(x: 150, y: 80))
            cgContext.addLine(to: CGPoint(x: 150, y: 250))
            
            // Arms
            cgContext.move(to: CGPoint(x: 150, y: 120))
            cgContext.addLine(to: CGPoint(x: 100, y: 160))
            cgContext.move(to: CGPoint(x: 150, y: 120))
            cgContext.addLine(to: CGPoint(x: 200, y: 160))
            
            // Legs
            cgContext.move(to: CGPoint(x: 150, y: 250))
            cgContext.addLine(to: CGPoint(x: 120, y: 350))
            cgContext.move(to: CGPoint(x: 150, y: 250))
            cgContext.addLine(to: CGPoint(x: 180, y: 350))
            
            cgContext.strokePath()
        }
        
        print("✅ Test image created: \(testImage.size)")
        
        // Test pose detection on this simple image
        Task {
            await testPoseDetectionOnImage(testImage)
        }
    }
    
    private static func testPoseDetectionOnImage(_ image: UIImage) async {
        guard #available(iOS 14.0, *) else {
            print("❌ Cannot test - iOS 14.0+ required")
            return
        }
        
        guard let cgImage = image.cgImage else {
            print("❌ Cannot get CGImage from test image")
            return
        }
        
        print("🧪 Testing pose detection on simple test image...")
        
        do {
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            try handler.perform([request])
            
            if let observations = request.results {
                print("📊 Test image results: \(observations.count) observations")
                
                for (index, observation) in observations.enumerated() {
                    print("📊 Observation \(index + 1): confidence = \(String(format: "%.3f", observation.confidence))")
                    
                    // Test extracting a few key joints
                    do {
                        let nose = try observation.recognizedPoint(.nose)
                        print("   👃 Nose: \(String(format: "%.2f", nose.confidence)) confidence")
                        
                        let leftShoulder = try observation.recognizedPoint(.leftShoulder)
                        print("   👈 Left shoulder: \(String(format: "%.2f", leftShoulder.confidence)) confidence")
                        
                        let rightShoulder = try observation.recognizedPoint(.rightShoulder)
                        print("   👉 Right shoulder: \(String(format: "%.2f", rightShoulder.confidence)) confidence")
                        
                    } catch {
                        print("   ⚠️ Could not extract specific joints: \(error)")
                    }
                }
                
                if observations.isEmpty {
                    print("⚠️ No poses detected in simple test image")
                    print("💡 This suggests Vision framework may have issues on this device")
                } else {
                    print("✅ Pose detection working on test image!")
                }
                
            } else {
                print("❌ No observations returned from test")
            }
            
        } catch {
            print("❌ Error testing pose detection: \(error)")
        }
    }
}