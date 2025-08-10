import Foundation
import CoreML
import UIKit
import AVFoundation

// MARK: - Local AI Validation Test

@MainActor
class LocalAIValidationTest: ObservableObject {
    @Published var testResults: [ValidationResult] = []
    @Published var isRunning = false
    
    nonisolated private let swingAnalyzer = LocalSwingAnalyzer()
    nonisolated private let ballTracker = LocalBallTracker()
    nonisolated private let caddieChat = LocalCaddieChat()
    
    func runValidationTests() async {
        await MainActor.run {
            self.isRunning = true
            self.testResults = []
        }
        
        print("🧪 Starting Local AI Validation Tests...")
        
        // Test 1: Model Loading
        await testModelLoading()
        
        // Test 2: Feature Extraction
        await testFeatureExtraction()
        
        // Test 3: Core ML Inference
        await testCoreMLInference()
        
        // Test 4: MediaPipe Integration
        await testMediaPipeIntegration()
        
        // Test 5: Ball Tracking
        await testBallTracking()
        
        // Test 6: Caddie Chat
        await testCaddieChat()
        
        await MainActor.run {
            self.isRunning = false
        }
        
        // Print summary
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        print("✅ Validation Complete: \(passedTests)/\(totalTests) tests passed")
    }
    
    // MARK: - Test Cases
    
    private func testModelLoading() async {
        print("🔍 Testing model loading...")
        
        var passed = true
        var details: [String] = []
        
        // Test SwingAnalysisModel loading
        if let modelPath = Bundle.main.path(forResource: "SwingAnalysisModel", ofType: "mlmodel") {
            do {
                let model = try MLModel(contentsOf: URL(fileURLWithPath: modelPath))
                details.append("✅ SwingAnalysisModel loaded successfully")
                print("Model input description: \(model.modelDescription.inputDescriptionsByName)")
                print("Model output description: \(model.modelDescription.outputDescriptionsByName)")
            } catch {
                passed = false
                details.append("❌ Failed to load SwingAnalysisModel: \(error)")
            }
        } else {
            passed = false
            details.append("❌ SwingAnalysisModel.mlmodel not found in bundle")
        }
        
        // Test BallTrackingModel loading
        if let modelPath = Bundle.main.path(forResource: "BallTrackingModel", ofType: "mlmodel") {
            do {
                let model = try MLModel(contentsOf: URL(fileURLWithPath: modelPath))
                details.append("✅ BallTrackingModel loaded successfully")
            } catch {
                passed = false
                details.append("❌ Failed to load BallTrackingModel: \(error)")
            }
        } else {
            passed = false
            details.append("❌ BallTrackingModel.mlmodel not found in bundle")
        }
        
        // Test scaler metadata
        if Bundle.main.path(forResource: "scaler_metadata", ofType: "json") != nil {
            details.append("✅ Scaler metadata found")
        } else {
            details.append("⚠️ Scaler metadata not found (using defaults)")
        }
        
        await addTestResult("Model Loading", passed: passed, details: details)
    }
    
    private func testFeatureExtraction() async {
        print("🔍 Testing feature extraction...")
        
        var passed = true
        var details: [String] = []
        
        // Create mock pose data
        let mockPoses = createMockPoseData()
        let extractor = SwingFeatureExtractor()
        
        do {
            let features = extractor.extractFeatures(from: mockPoses)
            
            if features.count == 35 {
                details.append("✅ Extracted \(features.count) features (expected 35)")
                passed = true
            } else {
                details.append("❌ Expected 35 features, got \(features.count)")
                passed = false
            }
            
            // Check feature validity
            let validFeatures = features.allSatisfy { !$0.isNaN && $0.isFinite }
            if validFeatures {
                details.append("✅ All features are valid numbers")
            } else {
                details.append("❌ Some features are NaN or infinite")
                passed = false
            }
            
        } catch {
            passed = false
            details.append("❌ Feature extraction failed: \(error)")
        }
        
        await addTestResult("Feature Extraction", passed: passed, details: details)
    }
    
    private func testCoreMLInference() async {
        print("🔍 Testing Core ML inference...")
        
        var passed = true
        var details: [String] = []
        
        guard let modelPath = Bundle.main.path(forResource: "SwingAnalysisModel", ofType: "mlmodel") else {
            await addTestResult("Core ML Inference", passed: false, details: ["❌ Model file not found"])
            return
        }
        
        do {
            let model = try MLModel(contentsOf: URL(fileURLWithPath: modelPath))
            
            // Create test input
            guard let inputArray = try? MLMultiArray(shape: [1, 35], dataType: .double) else {
                await addTestResult("Core ML Inference", passed: false, details: ["❌ Failed to create input array"])
                return
            }
            
            // Fill with test data
            for i in 0..<35 {
                inputArray[i] = NSNumber(value: Double.random(in: 0...1))
            }
            
            let input = SwingAnalysisModelInput(physics_features: inputArray)
            let prediction = try model.prediction(from: input)
            
            details.append("✅ Core ML inference completed")
            
            // Check output format
            if let outputArray = prediction.featureValue(for: "var_16")?.multiArrayValue {
                details.append("✅ Output array has \(outputArray.count) values")
                
                // Validate output values
                var outputValues: [Double] = []
                for i in 0..<outputArray.count {
                    outputValues.append(outputArray[i].doubleValue)
                }
                
                let validOutput = outputValues.allSatisfy { !$0.isNaN && $0.isFinite }
                if validOutput {
                    details.append("✅ All output values are valid")
                } else {
                    details.append("⚠️ Some output values are invalid")
                }
                
                passed = true
            } else {
                details.append("❌ Failed to extract output array")
                passed = false
            }
            
        } catch {
            passed = false
            details.append("❌ Core ML inference failed: \(error)")
        }
        
        await addTestResult("Core ML Inference", passed: passed, details: details)
    }
    
    private func testMediaPipeIntegration() async {
        print("🔍 Testing MediaPipe integration...")
        
        var passed = true
        var details: [String] = []
        
        let poseDetector = MediaPipePoseDetector()
        
        // Check initialization
        if poseDetector.isInitialized {
            details.append("✅ MediaPipe pose detector initialized")
        } else {
            details.append("❌ MediaPipe pose detector not initialized")
            passed = false
        }
        
        // Test with sample image
        let testImage = createTestImage()
        
        do {
            let poseResult = try await poseDetector.detectPose(in: testImage, timestamp: 0.0)
            
            if let result = poseResult {
                details.append("✅ Pose detection returned result with \(result.landmarks.count) landmarks")
                details.append("✅ Pose confidence: \(result.confidence)")
                passed = true
            } else {
                details.append("⚠️ No pose detected in test image (may be expected)")
            }
            
        } catch {
            details.append("❌ Pose detection failed: \(error)")
            passed = false
        }
        
        await addTestResult("MediaPipe Integration", passed: passed, details: details)
    }
    
    private func testBallTracking() async {
        print("🔍 Testing ball tracking...")
        
        var passed = true
        var details: [String] = []
        
        let testImage = createTestImage()
        let ballDetector = GolfBallDetector()
        
        do {
            let ballPosition = try await ballDetector.detectBall(in: testImage)
            
            if let position = ballPosition {
                details.append("✅ Ball detected at position: \(position)")
                passed = true
            } else {
                details.append("⚠️ No ball detected in test image (expected for test image)")
                passed = true // This is expected for a test image
            }
            
        } catch {
            details.append("❌ Ball detection failed: \(error)")
            passed = false
        }
        
        await addTestResult("Ball Tracking", passed: passed, details: details)
    }
    
    private func testCaddieChat() async {
        print("🔍 Testing Caddie Chat...")
        
        var passed = true
        var details: [String] = []
        
        do {
            let response = try await caddieChat.sendChatMessage("What's the best way to improve my swing?")
            
            if response.is_golf_related && !response.answer.isEmpty {
                details.append("✅ Golf-related response: \(response.answer.prefix(100))...")
                passed = true
            } else {
                details.append("❌ Invalid response format")
                passed = false
            }
            
            // Test non-golf question
            let nonGolfResponse = try await caddieChat.sendChatMessage("What's the weather like?")
            
            if !nonGolfResponse.is_golf_related {
                details.append("✅ Correctly identified non-golf question")
            } else {
                details.append("⚠️ Failed to identify non-golf question")
            }
            
        } catch {
            details.append("❌ Caddie chat failed: \(error)")
            passed = false
        }
        
        await addTestResult("Caddie Chat", passed: passed, details: details)
    }
    
    // MARK: - Helper Methods
    
    private func addTestResult(_ testName: String, passed: Bool, details: [String]) async {
        let result = ValidationResult(
            testName: testName,
            passed: passed,
            details: details,
            timestamp: Date()
        )
        
        await MainActor.run {
            self.testResults.append(result)
        }
    }
    
    private func createMockPoseData() -> [PoseData] {
        var poses: [PoseData] = []
        
        for i in 0..<30 {
            let keypoints = [
                PoseKeypoint(type: .leftShoulder, position: CGPoint(x: 0.4, y: 0.45), confidence: 0.9),
                PoseKeypoint(type: .rightShoulder, position: CGPoint(x: 0.6, y: 0.45), confidence: 0.9),
                PoseKeypoint(type: .leftWrist, position: CGPoint(x: 0.3 + Double(i) * 0.01, y: 0.75), confidence: 0.8),
                PoseKeypoint(type: .rightWrist, position: CGPoint(x: 0.7 - Double(i) * 0.01, y: 0.75), confidence: 0.8)
            ]
            
            poses.append(PoseData(timestamp: Double(i) * 0.033, keypoints: keypoints))
        }
        
        return poses
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.green.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}

// MARK: - Validation Result

struct ValidationResult: Identifiable {
    let id = UUID()
    let testName: String
    let passed: Bool
    let details: [String]
    let timestamp: Date
    
    var statusIcon: String {
        passed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    var statusColor: String {
        passed ? "green" : "red"
    }
}

// MARK: - Validation View

import SwiftUI

struct LocalAIValidationView: View {
    @StateObject private var validator = LocalAIValidationTest()
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Results") {
                    if validator.testResults.isEmpty && !validator.isRunning {
                        Text("No tests run yet")
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(validator.testResults) { result in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(result.details, id: \.self) { detail in
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: result.statusIcon)
                                    .foregroundColor(result.passed ? .green : .red)
                                
                                Text(result.testName)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(result.passed ? "PASS" : "FAIL")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(result.passed ? .green : .red)
                            }
                        }
                    }
                }
                
                Section("Actions") {
                    Button(action: runTests) {
                        HStack {
                            if validator.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Running Tests...")
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Run Validation Tests")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(validator.isRunning)
                }
            }
            .navigationTitle("AI Validation")
        }
    }
    
    private func runTests() {
        Task {
            await validator.runValidationTests()
        }
    }
}