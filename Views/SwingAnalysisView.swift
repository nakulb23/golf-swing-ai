import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct SwingAnalysisView: View {
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var apiService = APIService.shared
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var isAnalyzing = false
    @State private var analysisResult: SwingAnalysisResponse?
    @State private var showClassifications = false
    @State private var errorMessage: String?
    @State private var showingCamera = false
    @State private var showingSourceSelection = false
    @State private var showingPhotoPicker = false
    @State private var showingPremiumPaywall = false
    
    // Multi-angle enhancement states
    @State private var isDetectingAngle = false
    @State private var showAngleGuidance = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.blue)
                        
                        Text("Swing Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Upload or record your golf swing for AI-powered analysis")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    
                    // Video Upload/Record Section
                    VStack(spacing: 20) {
                        if videoData == nil {
                            // No video selected
                            VStack(spacing: 16) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.gray)
                                
                                Text("No video selected")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Record a new swing or choose from your photo library")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                            
                            // Action buttons
                            HStack(spacing: 16) {
                                Button(action: { showingCamera = true }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.fill")
                                            .font(.title2)
                                        Text("Record")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(
                                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.title2)
                                        Text("Upload")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(
                                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        } else {
                            // Video selected
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                
                                Text("Video Ready")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Your swing video is ready for analysis")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Button(action: { 
                                    selectedVideo = nil
                                    videoData = nil
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Change Video")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Analysis Button
                    if videoData != nil {
                        Button(action: analyzeSwing) {
                            HStack(spacing: 12) {
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isAnalyzing ? "Analyzing Swing..." : "Analyze My Swing")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isAnalyzing)
                        .padding(.horizontal)
                    }
                    
                    // Analysis Results
                    if let result = analysisResult {
                        AIAnalysisResultView(result: result)
                            .padding(.horizontal)
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Analysis Error")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Swing Analysis")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .sheet(isPresented: $showingCamera) {
            SimpleCameraView(videoData: $videoData)
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            SwingAnalysisPremiumView()
                .environmentObject(premiumManager)
        }
        .onChange(of: selectedVideo) { _, newValue in
            if let newValue = newValue {
                Task {
                    do {
                        if let data = try await newValue.loadTransferable(type: Data.self) {
                            videoData = data
                        }
                    } catch {
                        errorMessage = "Failed to load video: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func analyzeSwing() {
        guard let videoData = videoData else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                print("🧠 Starting AI swing analysis...")
                let result = try await apiService.analyzeSwing(videoData: videoData)
                
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                    print("✅ AI analysis completed: \(result.predicted_label)")
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = "Analysis failed: \(error.localizedDescription)"
                    print("❌ AI analysis failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SimpleCameraView: View {
    @Binding var videoData: Data?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if cameraManager.hasPermission {
                    // Camera Preview
                    CameraPreview(session: cameraManager.captureSession)
                        .onAppear {
                            cameraManager.startSession()
                        }
                        .onDisappear {
                            cameraManager.stopSession()
                        }
                } else {
                    // Permission request or denied view
                    VStack(spacing: 24) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white.opacity(0.7))
                        
                        VStack(spacing: 12) {
                            Text("Camera Access Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Golf Swing AI needs camera access to record your swing videos for analysis.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            if cameraManager.hasPermission == false {
                                // Check if we should show the permission request or go to settings
                                let status = AVCaptureDevice.authorizationStatus(for: .video)
                                if status == .notDetermined {
                                    cameraManager.checkPermission()
                                } else {
                                    showingPermissionAlert = true
                                }
                            }
                        }) {
                            Text("Grant Camera Permission")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                
                VStack {
                    Spacer()
                    
                    // Recording Controls
                    HStack(spacing: 50) {
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        // Record Button
                        Button(action: {
                            if cameraManager.isRecording {
                                cameraManager.stopRecording { data in
                                    videoData = data
                                    dismiss()
                                }
                            } else {
                                cameraManager.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(cameraManager.isRecording ? Color.red : Color.white)
                                    .frame(width: 70, height: 70)
                                
                                if cameraManager.isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        }
                        
                        // Flip Camera Button
                        Button(action: {
                            cameraManager.flipCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 50)
                }
                
                // Recording Timer
                if cameraManager.isRecording {
                    VStack {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .opacity(cameraManager.recordingTime.truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0.3)
                            
                            Text(cameraManager.formattedRecordingTime)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .onAppear {
                cameraManager.checkPermission()
            }
            .navigationBarHidden(true)
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                dismiss()
            }
        } message: {
            Text("Camera access was denied. Please enable camera access in Settings to record swing videos.")
        }
    }
}

struct SwingAnalysisPremiumView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Premium Analysis")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Upgrade to unlock advanced swing analysis features including detailed biomechanics, force vectors, and elite benchmarks")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Upgrade Now") {
                // Handle upgrade
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct AIAnalysisResultView: View {
    let result: SwingAnalysisResponse
    
    var body: some View {
        VStack(spacing: 20) {
            // AI Prediction Header
            VStack(spacing: 8) {
                Text("AI Analysis Result")
                    .font(.headline)
                
                Text(result.predicted_label.capitalized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(predictionColor(result.predicted_label))
                
                Text("Confidence: \(Int(result.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Confidence Visualization
            VStack(spacing: 8) {
                Text("Analysis Confidence")
                    .font(.headline)
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(result.confidence))
                        .stroke(confidenceColor(result.confidence), lineWidth: 8)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(result.confidence * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(confidenceColor(result.confidence))
                }
            }
            
            // Analysis Details
            VStack(spacing: 12) {
                AnalysisDetailRow(title: "Prediction", value: result.predicted_label.capitalized)
                AnalysisDetailRow(title: "Confidence Gap", value: String(format: "%.1f%%", result.confidence_gap * 100))
                
                if let cameraAngle = result.camera_angle {
                    AnalysisDetailRow(title: "Camera Angle", value: cameraAngle.capitalized)
                }
                
                if let speedAnalysis = result.club_speed_analysis {
                    AnalysisDetailRow(title: "Club Head Speed", value: String(format: "%.1f mph", speedAnalysis.club_head_speed_mph))
                }
            }
            
            // All Probabilities
            if !result.all_probabilities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Predictions")
                        .font(.headline)
                    
                    ForEach(result.all_probabilities.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        HStack {
                            Text(key.capitalized)
                                .font(.body)
                            Spacer()
                            Text("\(Int(value * 100))%")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(key == result.predicted_label ? .primary : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(key == result.predicted_label ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                        )
                    }
                }
            }
            
            // Recommendations (if available)
            if let recommendations = result.recommendations, !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Recommendations")
                        .font(.headline)
                    
                    ForEach(recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(recommendation)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            
            // Physics Insights (if available)
            if let insights = result.angle_insights {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Physics Insights")
                        .font(.headline)
                    
                    Text(insights)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private func predictionColor(_ prediction: String) -> Color {
        switch prediction.lowercased() {
        case "on_plane", "on plane": return .green
        case "too_steep", "too steep": return .orange
        case "too_flat", "too flat": return .red
        default: return .blue
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct AnalysisDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Data Models
// Using SwingAnalysisResponse from APIModels.swift

struct SwingAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        SwingAnalysisView()
    }
}