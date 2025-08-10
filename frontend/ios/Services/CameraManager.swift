import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import Vision

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    @Published var isRealTimeAnalysisEnabled = false
    @Published var currentPoseConfidence: Float = 0.0
    @Published var detectedPoseCount: Int = 0
    
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var outputURL: URL?
    
    // Real-time analysis components
    private let poseDetector = MediaPipePoseDetector()
    private let analysisQueue = DispatchQueue(label: "pose.analysis.queue", qos: .userInitiated)
    private var frameCounter = 0
    private var lastAnalysisTime = Date()
    
    var formattedRecordingTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    override init() {
        super.init()
        // Don't setup session until we have permission
    }
    
    func checkPermission() {
        print("🎥 Checking camera permission...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 Current permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("✅ Camera permission already granted")
            Task { @MainActor in
                self.hasPermission = true
                self.setupSession()
                // Start session immediately after setup when permission is already granted
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        self.startSession()
                    }
                }
            }
        case .notDetermined:
            print("❓ Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                print("🎥 Permission request result: \(granted)")
                Task { @MainActor in
                    self.hasPermission = granted
                    if granted {
                        print("✅ Permission granted, setting up camera...")
                        self.setupSession()
                        // Start session after setup when permission is newly granted
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            await MainActor.run {
                                self.startSession()
                            }
                        }
                    } else {
                        print("❌ Camera permission denied")
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera permission denied or restricted")
            Task { @MainActor in
                self.hasPermission = false
            }
        @unknown default:
            Task { @MainActor in
                self.hasPermission = false
            }
        }
    }
    
    private func setupSession() {
        // Only setup session if we have permission
        guard hasPermission else {
            print("⚠️ Cannot setup camera session without permission")
            return
        }
        
        print("🔧 Setting up camera session...")
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("❌ Failed to create video input device")
            return
        }
        
        print("📹 Created video input device")
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            currentVideoInput = videoInput
            print("✅ Added video input to session")
        } else {
            print("❌ Cannot add video input to session")
            return
        }
        
        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                print("✅ Added audio input to session")
            } else {
                print("⚠️ Cannot add audio input to session - continuing without audio")
            }
        } else {
            print("⚠️ Failed to create audio input device - continuing without audio")
        }
        
        // Add video output
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            videoOutput = movieOutput
            print("✅ Added video output to session")
            
            // Configure video settings for better compatibility
            if let connection = movieOutput.connection(with: .video) {
                // Enable video stabilization if available
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                    print("✅ Enabled video stabilization")
                }
                
                // Set preferred video orientation
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(0) {
                        connection.videoRotationAngle = 0 // Portrait orientation
                        print("✅ Set video rotation angle to 0° (portrait)")
                    }
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                        print("✅ Set video orientation to portrait")
                    }
                }
            }
            
            // Configure output settings for better server compatibility
            movieOutput.movieFragmentInterval = CMTime.invalid // Disable fragmentation for compatibility
            print("✅ Configured video output settings for server compatibility")
            
        } else {
            print("❌ Cannot add video output to session")
        }
        
        // Add video data output for real-time analysis
        setupRealTimeAnalysis()
        
        print("🎬 Camera session setup complete")
    }
    
    private func setupRealTimeAnalysis() {
        print("🔍 Setting up real-time pose analysis...")
        
        // Create video data output for real-time frame analysis
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        
        // Configure video data output
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            self.videoDataOutput = videoDataOutput
            print("✅ Added video data output for real-time analysis")
        } else {
            print("❌ Cannot add video data output")
        }
    }
    
    func toggleRealTimeAnalysis() {
        isRealTimeAnalysisEnabled.toggle()
        print("🔍 Real-time analysis \(isRealTimeAnalysisEnabled ? "enabled" : "disabled")")
        
        if isRealTimeAnalysisEnabled {
            // Reset analysis counters
            detectedPoseCount = 0
            currentPoseConfidence = 0.0
            frameCounter = 0
            lastAnalysisTime = Date()
        }
    }
    
    func startSession() {
        guard !captureSession.isRunning else { 
            print("📹 Session already running")
            return 
        }
        
        guard hasPermission else {
            print("⚠️ Cannot start session without camera permission")
            return
        }
        
        guard captureSession.inputs.count > 0 else {
            print("⚠️ Cannot start session without camera inputs")
            return
        }
        
        print("▶️ Starting camera session...")
        let session = captureSession
        Task.detached { @Sendable in
            session.startRunning()
            await MainActor.run {
                print("✅ Camera session started successfully - isRunning: \(session.isRunning)")
            }
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { 
            print("📹 Session already stopped")
            return 
        }
        
        print("⏹️ Stopping camera session...")
        let session = captureSession
        Task.detached { @Sendable in
            session.stopRunning()
            await MainActor.run {
                print("✅ Camera session stopped - isRunning: \(session.isRunning)")
            }
        }
    }
    
    func debugSessionStatus() {
        print("🔍 === Camera Session Debug ===")
        print("📹 Has permission: \(hasPermission)")
        print("📹 Session running: \(captureSession.isRunning)")
        print("📹 Session inputs: \(captureSession.inputs.count)")
        print("📹 Session outputs: \(captureSession.outputs.count)")
        print("📹 Session preset: \(captureSession.sessionPreset.rawValue)")
        
        for (index, input) in captureSession.inputs.enumerated() {
            if let deviceInput = input as? AVCaptureDeviceInput {
                print("📹 Input \(index): \(deviceInput.device.localizedName) - Position: \(deviceInput.device.position.rawValue)")
            }
        }
        
        for (index, output) in captureSession.outputs.enumerated() {
            print("📹 Output \(index): \(type(of: output))")
        }
        print("🔍 === End Debug ===")
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !videoOutput.isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsPath.appendingPathComponent("swing_video_\(Date().timeIntervalSince1970).mp4")
        self.outputURL = outputURL
        
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        // Start timer
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingTime += 0.1
            }
        }
        
        self.isRecording = true
    }
    
    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard let videoOutput = videoOutput, videoOutput.isRecording else {
            completion(nil)
            return
        }
        
        videoOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        self.isRecording = false
        self.recordingTime = 0
        
        // Store completion for use in delegate
        self.recordingCompletion = completion
    }
    
    private var recordingCompletion: ((Data?) -> Void)?
    
    func flipCamera() {
        guard let currentInput = currentVideoInput else { return }
        
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            currentVideoInput = newInput
        }
        
        captureSession.commitConfiguration()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ Recording error: \(error)")
            Task { @MainActor in
                recordingCompletion?(nil)
            }
        } else {
            print("✅ Recording completed successfully")
            print("📹 Video file URL: \(outputFileURL)")
            
            // Get video file attributes
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    print("📹 Video file size: \(fileSize) bytes")
                }
            } catch {
                print("⚠️ Could not get file attributes: \(error)")
            }
            
            // Convert video file to Data
            do {
                let videoData = try Data(contentsOf: outputFileURL)
                print("📹 Video data loaded: \(videoData.count) bytes")
                
                // Check video file type by reading header
                if videoData.count > 8 {
                    let header = videoData.prefix(8)
                    let headerString = header.map { String(format: "%02x", $0) }.joined()
                    print("📹 Video file header: \(headerString)")
                    
                    // Check for common video formats
                    if headerString.contains("6674797071742020") || headerString.contains("667479704d534e56") {
                        print("📹 Detected QuickTime/MP4 format")
                    }
                }
                
                Task { @MainActor in
                    recordingCompletion?(videoData)
                }
                
                // Clean up the temporary file
                try? FileManager.default.removeItem(at: outputFileURL)
                print("🗑️ Cleaned up temporary video file")
            } catch {
                print("❌ Error reading video file: \(error)")
                Task { @MainActor in
                    recordingCompletion?(nil)
                }
            }
        }
        
        Task { @MainActor in
            recordingCompletion = nil
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        print("🖼️ Creating camera preview view")
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = UIColor.black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = UIColor.black.cgColor
        
        // Ensure the preview layer is ready
        if previewLayer.connection?.isEnabled == true {
            print("✅ Preview layer connection is enabled")
        } else {
            print("⚠️ Preview layer connection is not enabled")
        }
        
        view.layer.addSublayer(previewLayer)
        
        print("✅ Camera preview layer added to view")
        print("📹 Session running: \(session.isRunning)")
        print("📹 Session inputs: \(session.inputs.count)")
        print("📹 Session outputs: \(session.outputs.count)")
        
        // Force session to start if it's not already running and has inputs
        if !session.isRunning && session.inputs.count > 0 {
            print("🔄 Session not running but has inputs - attempting to start")
            let captureSession = session
            DispatchQueue.global(qos: .background).async {
                captureSession.startRunning()
                Task { @MainActor in
                    print("✅ Session started from preview")
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            print("🔄 Updated preview layer frame: \(uiView.bounds)")
        }
    }
}

// MARK: - Real-time Video Analysis

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Only process frames if real-time analysis is enabled
        Task { @MainActor in
            guard self.isRealTimeAnalysisEnabled else { return }
        }
        
        // Process the sample buffer immediately on the capture queue to avoid data races
        let bufferCopy = sampleBuffer
        Task.detached { [weak self] in
            await self?.processSampleBufferDetached(bufferCopy)
        }
    }
    
    nonisolated private func processSampleBufferDetached(_ sampleBuffer: CMSampleBuffer) async {
        // Check if analysis is enabled first
        let isEnabled = await MainActor.run { self.isRealTimeAnalysisEnabled }
        guard isEnabled else { return }
        // Get frame counter and last analysis time atomically
        let (currentFrameCounter, lastTime) = await MainActor.run {
            self.frameCounter += 1
            return (self.frameCounter, self.lastAnalysisTime)
        }
        
        // Throttle frame processing to avoid overwhelming the system
        if currentFrameCounter % 15 != 0 { // Process every 15th frame (~2 FPS at 30 FPS)
            return
        }
        
        // Check time since last analysis
        let now = Date()
        if now.timeIntervalSince(lastTime) < 0.5 { // Minimum 500ms between analyses
            return
        }
        
        // Convert sample buffer to UIImage
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        // Perform pose detection asynchronously
        Task.detached { [weak self, uiImage, now] in
            guard let self = self else { return }
            
            do {
                let timestamp = Date().timeIntervalSince1970
                if let poseResult = try await self.poseDetector.detectPose(in: uiImage, timestamp: timestamp) {
                    
                    // Update UI on main thread
                    await MainActor.run {
                        self.currentPoseConfidence = poseResult.confidence
                        self.detectedPoseCount += 1
                        self.lastAnalysisTime = now
                    }
                    
                    // Log successful detection
                    print("🦴 Real-time pose detected: \(poseResult.landmarks.count) landmarks, confidence: \(String(format: "%.2f", poseResult.confidence))")
                    
                } else {
                    await MainActor.run {
                        self.currentPoseConfidence = 0.0
                        self.lastAnalysisTime = now
                    }
                }
                
            } catch {
                print("❌ Real-time pose detection error: \(error)")
            }
        }
    }
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        print("⚠️ Dropped video frame for analysis")
    }
}