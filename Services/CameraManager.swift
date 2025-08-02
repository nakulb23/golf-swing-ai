import Foundation
import AVFoundation
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var outputURL: URL?
    
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
            hasPermission = true
            setupSession()
            startSession()
        case .notDetermined:
            print("❓ Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🎥 Permission request result: \(granted)")
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    if granted {
                        print("✅ Permission granted, setting up camera...")
                        self.setupSession()
                        self.startSession()
                    } else {
                        print("❌ Camera permission denied")
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera permission denied or restricted")
            hasPermission = false
        @unknown default:
            hasPermission = false
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
            
            // Configure video stabilization if available
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                    print("✅ Enabled video stabilization")
                }
            }
        } else {
            print("❌ Cannot add video output to session")
        }
        
        print("🎬 Camera session setup complete")
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !videoOutput.isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsPath.appendingPathComponent("swing_video_\(Date().timeIntervalSince1970).mp4")
        self.outputURL = outputURL
        
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        // Start timer
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingTime += 0.1
            }
        }
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard let videoOutput = videoOutput, videoOutput.isRecording else {
            completion(nil)
            return
        }
        
        videoOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTime = 0
        }
        
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
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
            recordingCompletion?(nil)
        } else {
            // Convert video file to Data
            do {
                let videoData = try Data(contentsOf: outputFileURL)
                recordingCompletion?(videoData)
                
                // Clean up the temporary file
                try? FileManager.default.removeItem(at: outputFileURL)
            } catch {
                print("Error reading video file: \(error)")
                recordingCompletion?(nil)
            }
        }
        
        recordingCompletion = nil
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}