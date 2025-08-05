import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UIKit

// MARK: - Video Selection View

struct VideoSelectionView: View {
    @Binding var selectedVideo: PhotosPickerItem?
    @Binding var videoData: Data?
    @Binding var isAnalyzing: Bool
    @Binding var showingCamera: Bool
    @Binding var errorMessage: String?
    @Binding var analysisResult: SwingAnalysisResponse?
    
    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo/Icon
            VStack(spacing: 16) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                
                Text("Swing Analysis")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Record or upload your swing for AI analysis")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 20) {
                if videoData == nil {
                    // Record Button
                    Button(action: { showingCamera = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.title2)
                            Text("Record Swing")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Upload Button
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Upload Video")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                } else {
                    // Analysis Button
                    Button(action: analyzeSwing) {
                        HStack(spacing: 12) {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.black)
                            } else {
                                Image(systemName: "brain.head.profile")
                                    .font(.title2)
                            }
                            Text(isAnalyzing ? "Analyzing..." : "Analyze Swing")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isAnalyzing)
                    
                    // Change Video Button
                    Button(action: {
                        selectedVideo = nil
                        videoData = nil
                        errorMessage = nil
                    }) {
                        Text("Change Video")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .onChange(of: selectedVideo) { _, newValue in
            if let newValue = newValue {
                Task {
                    do {
                        if let data = try await newValue.loadTransferable(type: Data.self) {
                            videoData = data
                            errorMessage = nil
                        }
                    } catch {
                        errorMessage = "Failed to load video: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
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
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let analysisResult = analysisResult, let videoData = videoData {
                    // Main Video View with Overlay
                    VideoFirstAnalysisView(
                        videoData: videoData,
                        analysisResult: analysisResult,
                        onDismiss: {
                            self.analysisResult = nil
                            self.videoData = nil
                            self.selectedVideo = nil
                            self.errorMessage = nil
                        }
                    )
                } else {
                    // Video Selection/Upload State
                    VideoSelectionView(
                        selectedVideo: $selectedVideo,
                        videoData: $videoData,
                        isAnalyzing: $isAnalyzing,
                        showingCamera: $showingCamera,
                        errorMessage: $errorMessage,
                        analysisResult: $analysisResult
                    )
                }
            }
        }
        .navigationBarHidden(analysisResult != nil)
        .navigationBarTitleDisplayMode(.inline)
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
    // Analysis is now handled by VideoSelectionView
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
                            .onDisappear {
                                print("📹 Camera preview disappeared - stopping session")
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
                    print("📹 SimpleCameraView appeared - checking permission")
                    cameraManager.checkPermission()
                    
                    // Debug session status after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        cameraManager.debugSessionStatus()
                    }
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
    
    // MARK: - Enhanced Results View
    
    struct EnhancedSwingAnalysisResultView: View {
        let result: SwingAnalysisResponse
        let videoData: Data?
        @State private var selectedTab: AnalysisTab = .setup
        @State private var selectedPriority: Int = 1
        @State private var showComparison = false
        
        enum AnalysisTab: String, CaseIterable {
            case setup = "Set Up"
            case backswing = "Backswing"
            case impact = "Impact"
            
            var color: Color {
                switch self {
                case .setup: return .green
                case .backswing: return .red
                case .impact: return .red
                }
            }
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Title and Score
                    headerSection
                    
                    // Main Analysis Card
                    mainAnalysisCard
                    
                    // Professional Swing Plane Analysis
                    if videoData != nil {
                        professionalSwingAnalysisSection
                    }
                    
                    // Key Recommendations
                    keyRecommendationsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemBackground))
        }
        
        private var headerSection: some View {
            VStack(spacing: 8) {
                Text("Swing Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Down The Line")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
                
                Text("\(analyzedAreasCount) areas to improve")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        
        private var mainAnalysisCard: some View {
            VStack(spacing: 16) {
                // Top Priority Header
                topPriorityHeader
                
                // Analysis Summary Section
                analysisInfoSection
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        
        private var topPriorityHeader: some View {
            VStack(spacing: 8) {
                Text("Your top priority is to work on")
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(topPriorityTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        
        
        
        
        
        
        
        
        private var analysisInfoSection: some View {
            VStack(spacing: 12) {
                if let topFlaw = result.priority_flaws?.first {
                    Text(topFlaw.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Analysis confidence indicator
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Analysis Confidence")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(Int(result.confidence * 100))% confident in \(result.predicted_label.replacingOccurrences(of: "_", with: " "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        
        private var professionalSwingAnalysisSection: some View {
            VStack(spacing: 16) {
                // Header with Export Controls
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swing Plane Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Compare your swing plane with the ideal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            exportVideoWithOverlays()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Export")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button(action: {
                            // Toggle full screen
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Professional Video Analysis Container
                ProfessionalSwingAnalysisView(
                    videoData: videoData,
                    analysisResult: result
                )
                .aspectRatio(16/9, contentMode: ContentMode.fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Live Stats Bar
                liveStatsBar
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        
        private var issueHighlightLegend: some View {
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Major Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Minor Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Good Form")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        
        private var analysisDetailsSection: some View {
            VStack(spacing: 16) {
                // Tab Selection
                HStack(spacing: 0) {
                    ForEach(AnalysisTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(tab.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == tab ?
                                Color(.systemBackground) :
                                    Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(4)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Pass/Improve indicators
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Pass")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Improve")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        
        private var priorityIssuesSection: some View {
            VStack(spacing: 12) {
                HStack {
                    Text("Priority")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Flaw")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Results")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                
                // Issue rows
                ForEach(priorityIssues, id: \.priority) { issue in
                    priorityIssueRow(issue: issue)
                }
            }
        }
        
        private func priorityIssueRow(issue: PriorityIssue) -> some View {
            HStack(spacing: 16) {
                // Priority number
                Text("\(issue.priority)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(issue.priority == 1 ? .red : .primary)
                
                Spacer()
                
                // Flaw description
                Text(issue.flaw)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Result
                HStack(spacing: 8) {
                    Text(issue.result)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(issue.result == "Pass" ? .green : .red)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        
        private var fixTopPriorityButton: some View {
            Button(action: {
                // Handle fix top priority action
            }) {
                Text("Fix Your Top Priority")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 20)
        }
        
        private var keyRecommendationsSection: some View {
            VStack(spacing: 16) {
                HStack {
                    Text("Key Recommendations")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    if let recommendations = result.recommendations, !recommendations.isEmpty {
                        ForEach(recommendations.prefix(3), id: \.self) { recommendation in
                            RecommendationCard(
                                title: getRecommendationTitle(recommendation),
                                description: recommendation,
                                priority: getRecommendationPriority(recommendation)
                            )
                        }
                    } else {
                        // Fallback recommendations based on analysis
                        RecommendationCard(
                            title: "Swing Plane Focus",
                            description: getMainRecommendation(),
                            priority: .high
                        )
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        
        private func getMainRecommendation() -> String {
            switch result.predicted_label {
            case "too_steep":
                return "Focus on shallowing your swing plane. Try to feel like you're swinging more around your body rather than over the top."
            case "too_flat":
                return "Work on getting your swing plane more upright. Focus on lifting your arms higher in the backswing."
            case "on_plane":
                return "Great swing plane! Focus on maintaining this consistency and work on tempo and timing."
            default:
                return "Continue working on your swing fundamentals and consistency."
            }
        }
        
        private func getRecommendationTitle(_ recommendation: String) -> String {
            if recommendation.lowercased().contains("plane") {
                return "Swing Plane"
            } else if recommendation.lowercased().contains("tempo") {
                return "Tempo"
            } else if recommendation.lowercased().contains("grip") {
                return "Grip"
            } else {
                return "Technique"
            }
        }
        
        private func getRecommendationPriority(_ recommendation: String) -> RecommendationPriority {
            switch result.predicted_label {
            case "too_steep", "too_flat": return .high
            default: return .medium
            }
        }
        
        private func exportVideoWithOverlays() {
            // TODO: Implement video export with swing plane overlays
            print("Exporting video with swing plane overlays...")
            
            // For now, show a simple alert
            // In a real implementation, this would:
            // 1. Composite the video with swing plane overlays
            // 2. Add the stats bar overlay
            // 3. Export to Photos or share
        }
        
        private var liveStatsBar: some View {
            HStack(spacing: 20) {
                // Swing Plane Angle
                StatBadge(
                    icon: "triangle",
                    label: "Plane Angle",
                    value: "\(Int(result.physics_insights.avg_plane_angle))°",
                    status: getPlaneAngleStatus()
                )
                
                // Attack Angle
                if let biomechanics = result.detailed_biomechanics,
                   let attackAngle = biomechanics.first(where: { $0.name.contains("attack") }) {
                    StatBadge(
                        icon: "arrow.down.right",
                        label: "Attack Angle",
                        value: "\(Int(attackAngle.current_value))°",
                        status: attackAngle.severity == "pass" ? .good : .needs_work
                    )
                }
                
                // Club Speed (if available)
                if let speedAnalysis = result.club_speed_analysis {
                    StatBadge(
                        icon: "speedometer",
                        label: "Club Speed",
                        value: "\(Int(speedAnalysis.club_head_speed_mph)) mph",
                        status: .good
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        
        private func getPlaneAngleStatus() -> StatStatus {
            let _ = result.physics_insights.avg_plane_angle
            switch result.predicted_label {
            case "on_plane": return .good
            case "too_steep", "too_flat": return .needs_work
            default: return .neutral
            }
        }
        
        // MARK: - Computed Properties
        
        private var topPriorityTitle: String {
            if let topFlaw = result.priority_flaws?.first {
                return topFlaw.description.uppercased()
            }
            return "EXCESSIVE LEAD ARM BEND AT..."
        }
        
        private var analyzedAreasCount: Int {
            // Use actual count from analysis or fallback
            return result.priority_flaws?.count ?? 8
        }
        
        // Removed inaccurate scoring system per user feedback
        
        private var priorityIssues: [PriorityIssue] {
            // Use dynamic data from analysis if available
            if let flaws = result.priority_flaws, !flaws.isEmpty {
                return flaws.map { flaw in
                    PriorityIssue(
                        priority: flaw.priority,
                        flaw: flaw.flaw,
                        result: flaw.result
                    )
                }
            }
            
            // Fallback to static data if no detailed analysis
            return [
                PriorityIssue(priority: 1, flaw: "Lead Arm", result: "Improve"),
                PriorityIssue(priority: 2, flaw: "Spine Angle", result: "Improve"),
                PriorityIssue(priority: 3, flaw: "Head Movement", result: "Improve"),
                PriorityIssue(priority: 4, flaw: "Butt Position", result: "Improve"),
                PriorityIssue(priority: 5, flaw: "Hip Rotation", result: "Improve")
            ]
        }
    }
    
    // MARK: - Supporting Models
    
    struct PriorityIssue {
        let priority: Int
        let flaw: String
        let result: String
    }
    
    // MARK: - Data Models
    // Using SwingAnalysisResponse from APIModels.swift
    
    
    // MARK: - Video Preview with Highlights
    
    struct SwingVideoPreview: View {
        let videoData: Data?
        let analysisResult: SwingAnalysisResponse
        
        @State private var videoURL: URL?
        @State private var currentTime: Double = 0
        @State private var isPlaying = false
        @State private var videoDuration: Double = 1.0
        
        var body: some View {
            ZStack {
                // Video Background
                if let url = videoURL {
                    VideoPlayerView(
                        url: url,
                        currentTime: $currentTime,
                        isPlaying: $isPlaying,
                        duration: $videoDuration
                    )
                } else {
                    // Loading state
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Loading video...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                            }
                        )
                }
                
                // Swing Plane Overlay
                SwingPlaneOverlay(
                    analysisResult: analysisResult,
                    currentTime: currentTime,
                    videoDuration: videoDuration
                )
                
                // Issue Highlight Overlays
                if let priorityFlaws = analysisResult.priority_flaws {
                    EnhancedIssueHighlightOverlay(
                        flaws: priorityFlaws,
                        poseSequence: analysisResult.pose_sequence,
                        currentTime: currentTime,
                        videoDuration: videoDuration
                    )
                }
                
                // Play/Pause Control
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 60, height: 60)
                        )
                }
                .opacity(isPlaying ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isPlaying)
                
                // Time scrubber
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Slider(
                            value: $currentTime,
                            in: 0...videoDuration,
                            onEditingChanged: { editing in
                                if !editing {
                                    // Seek to new position
                                }
                            }
                        )
                        .accentColor(.white)
                        
                        Text(formatTime(videoDuration))
                            .font(.caption)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                    )
                }
            }
            .onAppear {
                setupVideo()
            }
        }
        
        private func setupVideo() {
            guard let data = videoData else { return }
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("swing_analysis_\(UUID().uuidString).mp4")
            
            do {
                try data.write(to: tempURL)
                videoURL = tempURL
            } catch {
                print("Failed to write video data: \(error)")
            }
        }
        
        private func formatTime(_ time: Double) -> String {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    struct VideoPlayerView: UIViewRepresentable {
        let url: URL
        @Binding var currentTime: Double
        @Binding var isPlaying: Bool
        @Binding var duration: Double
        
        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = .black
            
            // Create AVPlayer and AVPlayerLayer
            let player = AVPlayer(url: url)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            
            view.layer.addSublayer(playerLayer)
            
            // Store player reference
            context.coordinator.player = player
            context.coordinator.playerLayer = playerLayer
            
            // Setup time observer
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                currentTime = CMTimeGetSeconds(time)
            }
            
            // Get duration using modern iOS 16+ API
            Task {
                if let item = player.currentItem {
                    do {
                        let loadedDuration = try await item.asset.load(.duration)
                        await MainActor.run {
                            duration = CMTimeGetSeconds(loadedDuration)
                        }
                    } catch {
                        print("Failed to load asset duration: \(error)")
                    }
                }
            }
            
            return view
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // Update player layer frame
            if let playerLayer = context.coordinator.playerLayer {
                playerLayer.frame = uiView.bounds
            }
            
            // Control playback
            if isPlaying {
                context.coordinator.player?.play()
            } else {
                context.coordinator.player?.pause()
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        class Coordinator: NSObject {
            var player: AVPlayer?
            var playerLayer: AVPlayerLayer?
        }
    }
    
    struct IssueHighlightOverlay: View {
        let flaws: [PriorityFlaw]
        let currentTime: Double
        let videoDuration: Double
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Issue indicators positioned around the video
                    ForEach(Array(flaws.enumerated()), id: \.offset) { index, flaw in
                        if shouldShowFlaw(flaw, at: currentTime) {
                            IssueIndicator(
                                flaw: flaw,
                                position: getIndicatorPosition(for: index, in: geometry.size)
                            )
                        }
                    }
                    
                    // Timeline indicators at bottom
                    VStack {
                        Spacer()
                        IssueTimeline(flaws: flaws, currentTime: currentTime, duration: videoDuration)
                            .padding(.bottom, 60) // Above the scrubber
                    }
                }
            }
        }
        
        private func shouldShowFlaw(_ flaw: PriorityFlaw, at time: Double) -> Bool {
            // Show flaw during its relevant frame range
            let totalFrames = flaw.frame_indices.count > 0 ? max(flaw.frame_indices.max() ?? 100, 100) : 100
            
            return flaw.frame_indices.contains { frameIndex in
                let frameTime = Double(frameIndex) / Double(totalFrames) * videoDuration
                return abs(frameTime - time) < 0.5 // Show within 0.5 seconds of frame time
            }
        }
        
        private func getIndicatorPosition(for index: Int, in size: CGSize) -> CGPoint {
            // Position indicators around the video frame
            let positions: [CGPoint] = [
                CGPoint(x: size.width * 0.2, y: size.height * 0.2), // Top left area
                CGPoint(x: size.width * 0.8, y: size.height * 0.2), // Top right area
                CGPoint(x: size.width * 0.2, y: size.height * 0.5), // Mid left
                CGPoint(x: size.width * 0.8, y: size.height * 0.5), // Mid right
                CGPoint(x: size.width * 0.5, y: size.height * 0.8), // Bottom center
            ]
            
            return positions[index % positions.count]
        }
    }
    
    struct IssueIndicator: View {
        let flaw: PriorityFlaw
        let position: CGPoint
        
        var body: some View {
            VStack(spacing: 4) {
                // Pulsing indicator
                Circle()
                    .fill(issueColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(issueColor, lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.6)
                    )
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                
                // Issue label
                Text(flaw.flaw)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(issueColor.opacity(0.8))
                    )
            }
            .position(position)
        }
        
        private var issueColor: Color {
            switch flaw.severity.lowercased() {
            case "critical", "major":
                return .red
            case "minor":
                return .orange
            default:
                return .yellow
            }
        }
    }
    
    struct IssueTimeline: View {
        let flaws: [PriorityFlaw]
        let currentTime: Double
        let duration: Double
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<100, id: \.self) { segment in
                    Rectangle()
                        .fill(getSegmentColor(for: segment))
                        .frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(.horizontal, 16)
        }
        
        private func getSegmentColor(for segment: Int) -> Color {
            let segmentTime = Double(segment) / 100.0 * duration
            
            // Check if any major issues occur in this time segment
            for flaw in flaws {
                let totalFrames = max(flaw.frame_indices.max() ?? 100, 100)
                
                for frameIndex in flaw.frame_indices {
                    let frameTime = Double(frameIndex) / Double(totalFrames) * duration
                    
                    if abs(frameTime - segmentTime) < duration / 100.0 {
                        switch flaw.severity.lowercased() {
                        case "critical", "major":
                            return .red
                        case "minor":
                            return .orange
                        default:
                            return .yellow
                        }
                    }
                }
            }
            
            return .green.opacity(0.3)
        }
    }
    
    // MARK: - Enhanced Swing Plane Overlay
    
    struct SwingPlaneOverlay: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Swing Plane Lines
                    if let poseSequence = analysisResult.pose_sequence {
                        SwingPlaneLines(
                            poseSequence: poseSequence,
                            currentTime: currentTime,
                            videoDuration: videoDuration,
                            size: geometry.size
                        )
                    }
                    
                    // Swing Arc
                    SwingArcPath(
                        analysisResult: analysisResult,
                        currentTime: currentTime,
                        size: geometry.size
                    )
                    
                    // Angle Measurements
                    SwingAngleMeasurements(
                        analysisResult: analysisResult,
                        currentTime: currentTime,
                        size: geometry.size
                    )
                    
                    // Swing Plane Indicator
                    SwingPlaneIndicator(
                        prediction: analysisResult.predicted_label,
                        confidence: analysisResult.confidence,
                        size: geometry.size
                    )
                }
            }
        }
    }
    
    struct SwingPlaneLines: View {
        let poseSequence: [PoseFrame]
        let currentTime: Double
        let videoDuration: Double
        let size: CGSize
        
        var body: some View {
            ZStack {
                // Ideal swing plane line (reference)
                Path { path in
                    let startPoint = CGPoint(x: size.width * 0.3, y: size.height * 0.7)
                    let endPoint = CGPoint(x: size.width * 0.8, y: size.height * 0.2)
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.green.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                
                // Current swing plane line (based on pose data)
                if let currentPose = getCurrentPoseFrame() {
                    Path { path in
                        let swingLine = calculateSwingPlaneLine(from: currentPose, in: size)
                        path.move(to: swingLine.start)
                        path.addLine(to: swingLine.end)
                    }
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                
                // Plane deviation indicators
                ForEach(getPlaneDeviationPoints(), id: \.frame) { point in
                    Circle()
                        .fill(getDeviationColor(point.deviation))
                        .frame(width: 8, height: 8)
                        .position(point.position)
                        .animation(.easeInOut(duration: 0.3), value: currentTime)
                }
            }
        }
        
        private func getCurrentPoseFrame() -> PoseFrame? {
            let frameIndex = Int((currentTime / videoDuration) * Double(poseSequence.count))
            guard frameIndex < poseSequence.count else { return poseSequence.last }
            return poseSequence[frameIndex]
        }
        
        private func calculateSwingPlaneLine(from pose: PoseFrame, in size: CGSize) -> (start: CGPoint, end: CGPoint) {
            // Get shoulder and club positions from pose landmarks
            guard let leftShoulder = pose.landmarks["left_shoulder"],
                  let rightShoulder = pose.landmarks["right_shoulder"],
                  let leftWrist = pose.landmarks["left_wrist"] else {
                // Fallback to estimated positions
                return (
                    start: CGPoint(x: size.width * 0.4, y: size.height * 0.6),
                    end: CGPoint(x: size.width * 0.7, y: size.height * 0.3)
                )
            }
            
            // Convert normalized coordinates to screen coordinates
            let shoulderPoint = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2 * size.width,
                y: (leftShoulder.y + rightShoulder.y) / 2 * size.height
            )
            
            let clubPoint = CGPoint(
                x: leftWrist.x * size.width,
                y: leftWrist.y * size.height
            )
            
            // Extend the line for visual effect
            let direction = CGPoint(
                x: clubPoint.x - shoulderPoint.x,
                y: clubPoint.y - shoulderPoint.y
            )
            
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            let normalizedDirection = CGPoint(x: direction.x / length, y: direction.y / length)
            
            return (
                start: CGPoint(
                    x: shoulderPoint.x - normalizedDirection.x * 100,
                    y: shoulderPoint.y - normalizedDirection.y * 100
                ),
                end: CGPoint(
                    x: shoulderPoint.x + normalizedDirection.x * 200,
                    y: shoulderPoint.y + normalizedDirection.y * 200
                )
            )
        }
        
        private func getPlaneDeviationPoints() -> [PlaneDeviationPoint] {
            var points: [PlaneDeviationPoint] = []
            
            for (index, pose) in poseSequence.enumerated() {
                let frameTime = Double(index) / Double(poseSequence.count) * videoDuration
                if abs(frameTime - currentTime) < 0.5 { // Show points near current time
                    let deviation = calculatePlaneDeviation(for: pose)
                    let position = getScreenPosition(for: pose, in: size)
                    
                    points.append(PlaneDeviationPoint(
                        frame: index,
                        position: position,
                        deviation: deviation
                    ))
                }
            }
            
            return points
        }
        
        private func calculatePlaneDeviation(for pose: PoseFrame) -> Double {
            // Calculate how far off the ideal plane the swing is
            // This would use the actual pose data to determine deviation
            return Double.random(in: -15...15) // Placeholder - would be calculated from actual data
        }
        
        private func getScreenPosition(for pose: PoseFrame, in size: CGSize) -> CGPoint {
            // Convert pose position to screen coordinates
            if let wrist = pose.landmarks["left_wrist"] {
                return CGPoint(x: wrist.x * size.width, y: wrist.y * size.height)
            }
            return CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        }
        
        private func getDeviationColor(_ deviation: Double) -> Color {
            switch abs(deviation) {
            case 0..<5: return .green
            case 5..<10: return .yellow
            case 10..<15: return .orange
            default: return .red
            }
        }
    }
    
    struct SwingArcPath: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let size: CGSize
        
        var body: some View {
            ZStack {
                // Swing arc path
                Path { path in
                    let arcPoints = generateSwingArcPoints()
                    if let firstPoint = arcPoints.first {
                        path.move(to: firstPoint)
                        for point in arcPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.6), .blue.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                
                // Current club position on arc
                if let currentPosition = getCurrentClubPosition() {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(currentPosition)
                        .shadow(color: .blue, radius: 4)
                        .animation(.easeInOut(duration: 0.1), value: currentTime)
                }
            }
        }
        
        private func generateSwingArcPoints() -> [CGPoint] {
            var points: [CGPoint] = []
            let centerX = size.width * 0.45
            let centerY = size.height * 0.55
            let radiusX = size.width * 0.25
            let radiusY = size.height * 0.3
            
            for i in 0..<50 {
                let angle = Double(i) / 49.0 * .pi * 1.2 - .pi * 0.6 // Swing arc
                let x = centerX + cos(angle) * radiusX
                let y = centerY + sin(angle) * radiusY
                points.append(CGPoint(x: x, y: y))
            }
            
            return points
        }
        
        private func getCurrentClubPosition() -> CGPoint? {
            let progress = currentTime / max(1.0, currentTime + 1.0) // Normalized progress
            let arcPoints = generateSwingArcPoints()
            let index = Int(progress * Double(arcPoints.count - 1))
            guard index < arcPoints.count else { return arcPoints.last }
            return arcPoints[index]
        }
    }
    
    struct SwingAngleMeasurements: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let size: CGSize
        
        var body: some View {
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        // Swing plane angle
                        AngleMeasurement(
                            label: "Plane Angle",
                            value: "\(Int(analysisResult.physics_insights.avg_plane_angle))°",
                            color: getAngleColor(analysisResult.physics_insights.avg_plane_angle),
                            isOptimal: isOptimalAngle(analysisResult.physics_insights.avg_plane_angle)
                        )
                        
                        // Attack angle (if available)
                        if let biomechanics = analysisResult.detailed_biomechanics,
                           let attackAngle = biomechanics.first(where: { $0.name.contains("attack") }) {
                            AngleMeasurement(
                                label: "Attack Angle",
                                value: "\(Int(attackAngle.current_value))°",
                                color: getAngleColor(attackAngle.current_value),
                                isOptimal: attackAngle.severity == "pass"
                            )
                        }
                        
                        // Spine angle (if available)
                        if let biomechanics = analysisResult.detailed_biomechanics,
                           let spineAngle = biomechanics.first(where: { $0.name.contains("spine") }) {
                            AngleMeasurement(
                                label: "Spine Angle",
                                value: "\(Int(spineAngle.current_value))°",
                                color: getAngleColor(spineAngle.current_value),
                                isOptimal: spineAngle.severity == "pass"
                            )
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
        }
        
        private func getAngleColor(_ angle: Double) -> Color {
            switch analysisResult.predicted_label {
            case "on_plane": return .green
            case "too_steep": return .red
            case "too_flat": return .orange
            default: return .blue
            }
        }
        
        private func isOptimalAngle(_ angle: Double) -> Bool {
            return angle >= 35 && angle <= 55 // Typical optimal range
        }
    }
    
    struct SwingPlaneIndicator: View {
        let prediction: String
        let confidence: Double
        let size: CGSize
        
        var body: some View {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWING PLANE")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(getStatusColor())
                                .frame(width: 12, height: 12)
                            
                            Text(getStatusText())
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        
        private func getStatusColor() -> Color {
            switch prediction {
            case "on_plane": return .green
            case "too_steep": return .red
            case "too_flat": return .orange
            default: return .blue
            }
        }
        
        private func getStatusText() -> String {
            switch prediction {
            case "on_plane": return "On Plane"
            case "too_steep": return "Too Steep"
            case "too_flat": return "Too Flat"
            default: return "Analyzing..."
            }
        }
    }
    
    struct AngleMeasurement: View {
        let label: String
        let value: String
        let color: Color
        let isOptimal: Bool
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: isOptimal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(isOptimal ? .green : color)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
    
    struct PlaneDeviationPoint {
        let frame: Int
        let position: CGPoint
        let deviation: Double
    }
    
    // MARK: - Enhanced Issue Highlight Overlay
    
    struct EnhancedIssueHighlightOverlay: View {
        let flaws: [PriorityFlaw]
        let poseSequence: [PoseFrame]?
        let currentTime: Double
        let videoDuration: Double
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Real-time pose-based issue indicators
                    if let poseSequence = poseSequence {
                        ForEach(Array(flaws.enumerated()), id: \.offset) { index, flaw in
                            if shouldShowFlaw(flaw, at: currentTime) {
                                PoseBasedIssueIndicator(
                                    flaw: flaw,
                                    poseSequence: poseSequence,
                                    currentTime: currentTime,
                                    videoDuration: videoDuration,
                                    size: geometry.size
                                )
                            }
                        }
                    }
                    
                    // Enhanced timeline with issue markers
                    VStack {
                        Spacer()
                        EnhancedIssueTimeline(
                            flaws: flaws,
                            currentTime: currentTime,
                            duration: videoDuration
                        )
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        
        private func shouldShowFlaw(_ flaw: PriorityFlaw, at time: Double) -> Bool {
            let totalFrames = flaw.frame_indices.count > 0 ? max(flaw.frame_indices.max() ?? 100, 100) : 100
            
            return flaw.frame_indices.contains { frameIndex in
                let frameTime = Double(frameIndex) / Double(totalFrames) * videoDuration
                return abs(frameTime - time) < 0.5
            }
        }
    }
    
    struct PoseBasedIssueIndicator: View {
        let flaw: PriorityFlaw
        let poseSequence: [PoseFrame]
        let currentTime: Double
        let videoDuration: Double
        let size: CGSize
        
        var body: some View {
            if let currentPose = getCurrentPoseFrame(),
               let position = getFlawPosition(for: flaw, in: currentPose) {
                
                VStack(spacing: 4) {
                    // Pulsing indicator with severity-based styling
                    ZStack {
                        Circle()
                            .fill(issueColor.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                        
                        Circle()
                            .fill(issueColor)
                            .frame(width: 12, height: 12)
                        
                        Image(systemName: getIssueIcon())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Issue label with current value
                    VStack(spacing: 2) {
                        Text(flaw.flaw)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("\(Int(flaw.current_value))\(getUnit())")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(issueColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.8))
                    )
                }
                .position(position)
            }
        }
        
        private func getCurrentPoseFrame() -> PoseFrame? {
            let frameIndex = Int((currentTime / videoDuration) * Double(poseSequence.count))
            guard frameIndex < poseSequence.count else { return poseSequence.last }
            return poseSequence[frameIndex]
        }
        
        private func getFlawPosition(for flaw: PriorityFlaw, in pose: PoseFrame) -> CGPoint? {
            // Map flaw type to relevant pose landmark
            let landmarkKey: String
            
            switch flaw.flaw.lowercased() {
            case let f where f.contains("arm"):
                landmarkKey = "left_elbow"
            case let f where f.contains("spine"):
                landmarkKey = "nose" // Center of body
            case let f where f.contains("hip"):
                landmarkKey = "left_hip"
            case let f where f.contains("head"):
                landmarkKey = "nose"
            default:
                landmarkKey = "left_wrist" // Default to wrist
            }
            
            guard let landmark = pose.landmarks[landmarkKey] else { return nil }
            
            return CGPoint(
                x: landmark.x * size.width,
                y: landmark.y * size.height
            )
        }
        
        private var issueColor: Color {
            switch flaw.severity.lowercased() {
            case "critical": return .red
            case "major": return .red.opacity(0.8)
            case "minor": return .orange
            default: return .yellow
            }
        }
        
        private func getIssueIcon() -> String {
            switch flaw.severity.lowercased() {
            case "critical": return "exclamationmark"
            case "major": return "minus"
            case "minor": return "info"
            default: return "questionmark"
            }
        }
        
        private func getUnit() -> String {
            switch flaw.flaw.lowercased() {
            case let f where f.contains("angle"):
                return "°"
            case let f where f.contains("bend"):
                return "°"
            default:
                return ""
            }
        }
    }
    
    struct EnhancedIssueTimeline: View {
        let flaws: [PriorityFlaw]
        let currentTime: Double
        let duration: Double
        
        var body: some View {
            VStack(spacing: 8) {
                // Issue severity legend
                HStack(spacing: 16) {
                    ForEach(["Critical", "Major", "Minor"], id: \.self) { severity in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(getSeverityColor(severity))
                                .frame(width: 8, height: 8)
                            Text(severity)
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Timeline with issue markers
                HStack(spacing: 1) {
                    ForEach(0..<100, id: \.self) { segment in
                        Rectangle()
                            .fill(getSegmentColor(for: segment))
                            .frame(height: 6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    // Current time indicator
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 8)
                        .offset(x: CGFloat(currentTime / duration) * 320 - 160) // Approximate timeline width
                )
                .padding(.horizontal, 16)
            }
        }
        
        private func getSeverityColor(_ severity: String) -> Color {
            switch severity.lowercased() {
            case "critical": return .red
            case "major": return .red.opacity(0.8)
            case "minor": return .orange
            default: return .yellow
            }
        }
        
        private func getSegmentColor(for segment: Int) -> Color {
            let segmentTime = Double(segment) / 100.0 * duration
            
            // Find the most severe issue in this time segment
            var maxSeverity = ""
            
            for flaw in flaws {
                let totalFrames = max(flaw.frame_indices.max() ?? 100, 100)
                
                for frameIndex in flaw.frame_indices {
                    let frameTime = Double(frameIndex) / Double(totalFrames) * duration
                    
                    if abs(frameTime - segmentTime) < duration / 100.0 {
                        if flaw.severity == "critical" || (flaw.severity == "major" && maxSeverity != "critical") || (flaw.severity == "minor" && maxSeverity == "") {
                            maxSeverity = flaw.severity
                        }
                    }
                }
            }
            
            return getSeverityColor(maxSeverity.isEmpty ? "normal" : maxSeverity)
        }
    }
    
    // MARK: - Professional Swing Analysis View
    
    struct ProfessionalSwingAnalysisView: View {
        let videoData: Data?
        let analysisResult: SwingAnalysisResponse
        
        @State private var videoURL: URL?
        @State private var currentTime: Double = 0
        @State private var isPlaying = false
        @State private var videoDuration: Double = 1.0
        @State private var showIdealPlane = true
        @State private var showUserPlane = true
        @State private var isRightHanded = true
        
        var body: some View {
            ZStack {
                // Video Background
                if let url = videoURL {
                    VideoPlayerView(
                        url: url,
                        currentTime: $currentTime,
                        isPlaying: $isPlaying,
                        duration: $videoDuration
                    )
                } else {
                    // Loading state
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Loading video...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                            }
                        )
                }
                
                // Professional Swing Plane Overlays
                ProfessionalSwingPlaneOverlay(
                    analysisResult: analysisResult,
                    currentTime: currentTime,
                    videoDuration: videoDuration,
                    showIdealPlane: showIdealPlane,
                    showUserPlane: showUserPlane,
                    isRightHanded: isRightHanded
                )
                
                // Video Controls
                VStack {
                    Spacer()
                    
                    // Overlay Toggle Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            // Handedness Selector
                            HStack(spacing: 12) {
                                Text("Golfer:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 0) {
                                    Button(action: { isRightHanded = true }) {
                                        Text("Right")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(isRightHanded ? .black : .white)
                                            .frame(width: 50, height: 24)
                                            .background(isRightHanded ? Color.white : Color.white.opacity(0.2))
                                    }
                                    
                                    Button(action: { isRightHanded = false }) {
                                        Text("Left")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(!isRightHanded ? .black : .white)
                                            .frame(width: 50, height: 24)
                                            .background(!isRightHanded ? Color.white : Color.white.opacity(0.2))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            Divider()
                                .frame(height: 1)
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 4)
                            
                            Toggle("Ideal Plane", isOn: $showIdealPlane)
                                .toggleStyle(PlaneToggleStyle(color: .green))
                            
                            Toggle("Your Plane", isOn: $showUserPlane)
                                .toggleStyle(PlaneToggleStyle(color: .yellow))
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                        
                        // Play/Pause Control
                        Button(action: {
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                )
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 16)
                }
            }
            .onAppear {
                setupVideo()
            }
        }
        
        private func setupVideo() {
            guard let data = videoData else { return }
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("professional_analysis_\(UUID().uuidString).mp4")
            
            do {
                try data.write(to: tempURL)
                videoURL = tempURL
            } catch {
                print("Failed to write video data: \(error)")
            }
        }
    }
    
    struct ProfessionalSwingPlaneOverlay: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        let showIdealPlane: Bool
        let showUserPlane: Bool
        let isRightHanded: Bool
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Dynamic Ball Position Indicator
                    let ballPosition = getCurrentBallPosition(for: geometry.size)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        )
                        .position(ballPosition)
                        .animation(.easeInOut(duration: 0.1), value: ballPosition)
                    
                    // Dynamic Club Head Tracking
                    if let clubPath = getClubHeadPath(for: geometry.size) {
                        Path { path in
                            if clubPath.count > 1 {
                                path.move(to: clubPath[0])
                                for point in clubPath.dropFirst() {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                    }
                    
                    // Ideal Swing Plane (Dynamic based on pose)
                    if showIdealPlane, let idealPlane = getDynamicIdealPlane(for: geometry.size) {
                        Path { path in
                            path.move(to: idealPlane.start)
                            path.addLine(to: idealPlane.end)
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .shadow(color: .green.opacity(0.5), radius: 2)
                        
                        // Ideal plane extension (dotted)
                        Path { path in
                            let extended = extendPlane(idealPlane, by: 50)
                            path.move(to: idealPlane.end)
                            path.addLine(to: extended)
                        }
                        .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    }
                    
                    // User's Actual Swing Plane (Dynamic based on pose)
                    if showUserPlane, let userPlane = getDynamicUserPlane(for: geometry.size) {
                        Path { path in
                            path.move(to: userPlane.start)
                            path.addLine(to: userPlane.end)
                        }
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .shadow(color: .yellow.opacity(0.5), radius: 2)
                        
                        // User plane extension (dotted)
                        Path { path in
                            let extended = extendPlane(userPlane, by: 50)
                            path.move(to: userPlane.end)
                            path.addLine(to: extended)
                        }
                        .stroke(Color.yellow.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    }
                    
                    // Real-time pose landmarks for key points
                    if let currentPose = getCurrentPoseFrame() {
                        ForEach(getKeyLandmarks(from: currentPose, size: geometry.size), id: \.name) { landmark in
                            Circle()
                                .fill(landmark.color)
                                .frame(width: 8, height: 8)
                                .position(landmark.position)
                                .opacity(landmark.confidence > 0.5 ? 1.0 : 0.3)
                        }
                    }
                    
                    // Plane Analysis Badge
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SWING PLANE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(getPlaneStatusText())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(getPlaneStatusColor())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.8))
                            )
                            
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
            }
        }
        
        // MARK: - Dynamic Tracking Functions
        
        private func getCurrentBallPosition(for size: CGSize) -> CGPoint {
            // Try to get ball position from pose data first
            if let _ = analysisResult.pose_sequence,
               let currentPose = getCurrentPoseFrame() {
                
                // Estimate ball position based on stance and club position
                if let leftFoot = currentPose.landmarks["left_ankle"],
                   let rightFoot = currentPose.landmarks["right_ankle"],
                   let _ = currentPose.landmarks["left_wrist"] {
                    
                    // Ball is typically positioned between feet, slightly forward
                    let feetCenter = CGPoint(
                        x: (leftFoot.x + rightFoot.x) / 2 * size.width,
                        y: max(leftFoot.y, rightFoot.y) * size.height
                    )
                    
                    // Adjust based on swing phase
                    let swingProgress = currentTime / videoDuration
                    let ballOffset = getBallOffsetForSwingPhase(swingProgress)
                    
                    return CGPoint(
                        x: feetCenter.x + ballOffset.x,
                        y: feetCenter.y + ballOffset.y
                    )
                }
            }
            
            // Fallback to estimated position based on handedness
            let baseX = isRightHanded ? size.width * 0.48 : size.width * 0.52
            return CGPoint(x: baseX, y: size.height * 0.8)
        }
        
        private func getBallOffsetForSwingPhase(_ progress: Double) -> CGPoint {
            // Ball appears to move due to camera angle and golfer movement
            switch progress {
            case 0.0..<0.3: // Setup/Backswing
                return CGPoint(x: 0, y: 0)
            case 0.3..<0.6: // Top of backswing
                return CGPoint(x: -5, y: -2)
            case 0.6..<0.8: // Downswing
                return CGPoint(x: 2, y: -1)
            default: // Impact/Follow through
                return CGPoint(x: 8, y: 0)
            }
        }
        
        private func getCurrentPoseFrame() -> PoseFrame? {
            guard let poseSequence = analysisResult.pose_sequence,
                  !poseSequence.isEmpty else { return nil }
            
            let frameIndex = Int((currentTime / videoDuration) * Double(poseSequence.count))
            let clampedIndex = min(max(frameIndex, 0), poseSequence.count - 1)
            return poseSequence[clampedIndex]
        }
        
        private func getClubHeadPath(for size: CGSize) -> [CGPoint]? {
            guard let poseSequence = analysisResult.pose_sequence else { return nil }
            
            var clubPath: [CGPoint] = []
            let currentFrame = Int((currentTime / videoDuration) * Double(poseSequence.count))
            
            // Show club path for the last 10 frames leading to current position
            let startFrame = max(0, currentFrame - 10)
            
            for i in startFrame...min(currentFrame, poseSequence.count - 1) {
                let pose = poseSequence[i]
                if let leftWrist = pose.landmarks["left_wrist"],
                   let rightWrist = pose.landmarks["right_wrist"] {
                    
                    // Estimate club head position (extend from wrists)
                    let wristCenter = CGPoint(
                        x: (leftWrist.x + rightWrist.x) / 2,
                        y: (leftWrist.y + rightWrist.y) / 2
                    )
                    
                    // Extend down to estimate club head
                    let clubHead = CGPoint(
                        x: wristCenter.x * size.width,
                        y: (wristCenter.y + 0.15) * size.height
                    )
                    
                    clubPath.append(clubHead)
                }
            }
            
            return clubPath.isEmpty ? nil : clubPath
        }
        
        private func getDynamicIdealPlane(for size: CGSize) -> (start: CGPoint, end: CGPoint)? {
            guard let currentPose = getCurrentPoseFrame() else {
                // Fallback to static ideal plane if no pose data
                return getStaticIdealPlane(for: size)
            }
            
            let _ = getCurrentBallPosition(for: size)
            
            // Get shoulder position as the rotation center
            if let leftShoulder = currentPose.landmarks["left_shoulder"],
               let rightShoulder = currentPose.landmarks["right_shoulder"] {
                
                let shoulderCenter = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2 * size.width,
                    y: (leftShoulder.y + rightShoulder.y) / 2 * size.height
                )
                
                // Calculate ideal plane angle based on golfer's setup
                let idealAngle = getIdealPlaneAngle()
                let planeLength: CGFloat = 150
                
                let endPoint = CGPoint(
                    x: shoulderCenter.x + cos(idealAngle) * planeLength,
                    y: shoulderCenter.y + sin(idealAngle) * planeLength
                )
                
                return (start: shoulderCenter, end: endPoint)
            }
            
            return getStaticIdealPlane(for: size)
        }
        
        private func getDynamicUserPlane(for size: CGSize) -> (start: CGPoint, end: CGPoint)? {
            guard let currentPose = getCurrentPoseFrame() else {
                // Fallback to static user plane if no pose data
                return getStaticUserPlane(for: size)
            }
            
            // Get actual club/arm position
            if let leftShoulder = currentPose.landmarks["left_shoulder"],
               let rightShoulder = currentPose.landmarks["right_shoulder"],
               let leftWrist = currentPose.landmarks["left_wrist"] {
                
                let shoulderCenter = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2 * size.width,
                    y: (leftShoulder.y + rightShoulder.y) / 2 * size.height
                )
                
                let wristPosition = CGPoint(
                    x: leftWrist.x * size.width,
                    y: leftWrist.y * size.height
                )
                
                // Calculate actual swing plane direction
                let direction = CGPoint(
                    x: wristPosition.x - shoulderCenter.x,
                    y: wristPosition.y - shoulderCenter.y
                )
                
                // Normalize and extend
                let length = sqrt(direction.x * direction.x + direction.y * direction.y)
                guard length > 0 else { return getStaticUserPlane(for: size) }
                
                let normalizedDirection = CGPoint(
                    x: direction.x / length,
                    y: direction.y / length
                )
                
                let extendedEnd = CGPoint(
                    x: shoulderCenter.x + normalizedDirection.x * 150,
                    y: shoulderCenter.y + normalizedDirection.y * 150
                )
                
                return (start: shoulderCenter, end: extendedEnd)
            }
            
            return getStaticUserPlane(for: size)
        }
        
        private func getStaticIdealPlane(for size: CGSize) -> (start: CGPoint, end: CGPoint) {
            if isRightHanded {
                return (
                    start: CGPoint(x: size.width * 0.35, y: size.height * 0.75),
                    end: CGPoint(x: size.width * 0.75, y: size.height * 0.25)
                )
            } else {
                return (
                    start: CGPoint(x: size.width * 0.65, y: size.height * 0.75),
                    end: CGPoint(x: size.width * 0.25, y: size.height * 0.25)
                )
            }
        }
        
        private func getStaticUserPlane(for size: CGSize) -> (start: CGPoint, end: CGPoint) {
            let deviation = getPlaneDeviation()
            
            if isRightHanded {
                return (
                    start: CGPoint(x: size.width * 0.35, y: size.height * 0.75),
                    end: CGPoint(
                        x: size.width * 0.75 + deviation.x,
                        y: size.height * 0.25 + deviation.y
                    )
                )
            } else {
                return (
                    start: CGPoint(x: size.width * 0.65, y: size.height * 0.75),
                    end: CGPoint(
                        x: size.width * 0.25 - deviation.x,
                        y: size.height * 0.25 + deviation.y
                    )
                )
            }
        }
        
        private func getPlaneDeviation() -> CGPoint {
            switch analysisResult.predicted_label {
            case "too_steep":
                return CGPoint(x: -30, y: -40)
            case "too_flat":
                return CGPoint(x: 20, y: 30)
            default:
                return CGPoint(x: 0, y: 0)
            }
        }
        
        private func getIdealPlaneAngle() -> CGFloat {
            // Ideal swing plane angle based on handedness and club type
            let baseAngle: CGFloat = isRightHanded ? -0.8 : 0.8 // ~45 degrees
            return baseAngle
        }
        
        private func extendPlane(_ plane: (start: CGPoint, end: CGPoint), by distance: CGFloat) -> CGPoint {
            let direction = CGPoint(
                x: plane.end.x - plane.start.x,
                y: plane.end.y - plane.start.y
            )
            
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            guard length > 0 else { return plane.end }
            
            let normalizedDirection = CGPoint(
                x: direction.x / length,
                y: direction.y / length
            )
            
            return CGPoint(
                x: plane.end.x + normalizedDirection.x * distance,
                y: plane.end.y + normalizedDirection.y * distance
            )
        }
        
        private func getKeyLandmarks(from pose: PoseFrame, size: CGSize) -> [LandmarkVisualization] {
            var landmarks: [LandmarkVisualization] = []
            
            // Key points to visualize
            let keyPoints = [
                ("left_shoulder", Color.blue),
                ("right_shoulder", Color.blue),
                ("left_wrist", Color.red),
                ("right_wrist", Color.red),
                ("left_hip", Color.green),
                ("right_hip", Color.green)
            ]
            
            for (name, color) in keyPoints {
                if let landmark = pose.landmarks[name] {
                    landmarks.append(LandmarkVisualization(
                        name: name,
                        position: CGPoint(
                            x: landmark.x * size.width,
                            y: landmark.y * size.height
                        ),
                        color: color,
                        confidence: landmark.confidence
                    ))
                }
            }
            
            return landmarks
        }
        
        private func getPlaneStatusText() -> String {
            guard getCurrentPoseFrame() != nil else {
                return "Analyzing..."
            }
            
            // Dynamic status based on current frame analysis
            let swingPhase = getSwingPhase()
            switch analysisResult.predicted_label {
            case "on_plane":
                return "\(swingPhase) - On Plane ✓"
            case "too_steep":
                return "\(swingPhase) - Too Steep"
            case "too_flat":
                return "\(swingPhase) - Too Flat"
            default:
                return "\(swingPhase) - Analyzing..."
            }
        }
        
        private func getSwingPhase() -> String {
            let progress = currentTime / videoDuration
            switch progress {
            case 0.0..<0.2: return "Setup"
            case 0.2..<0.4: return "Takeaway"
            case 0.4..<0.6: return "Backswing"
            case 0.6..<0.8: return "Downswing"
            case 0.8..<0.95: return "Impact"
            default: return "Follow Through"
            }
        }
        
        private func getPlaneStatusColor() -> Color {
            switch analysisResult.predicted_label {
            case "on_plane": return .green
            case "too_steep", "too_flat": return .yellow
            default: return .white
            }
        }
    }
    
    // MARK: - Supporting Models for Dynamic Overlay
    
    struct LandmarkVisualization {
        let name: String
        let position: CGPoint
        let color: Color
        let confidence: Double
    }
    
    struct PlaneToggleStyle: ToggleStyle {
        let color: Color
        
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(configuration.isOn ? color : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                
                configuration.label
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
    
    enum StatStatus {
        case good, needs_work, neutral
        
        var color: Color {
            switch self {
            case .good: return .green
            case .needs_work: return .orange
            case .neutral: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .needs_work: return "exclamationmark.triangle.fill"
            case .neutral: return "circle.fill"
            }
        }
    }
    
    struct StatBadge: View {
        let icon: String
        let label: String
        let value: String
        let status: StatStatus
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(value)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Image(systemName: status.icon)
                    .font(.caption2)
                    .foregroundColor(status.color)
            }
        }
    }
    
    enum RecommendationPriority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
        
        var text: String {
            switch self {
            case .high: return "HIGH"
            case .medium: return "MEDIUM"
            case .low: return "LOW"
            }
        }
    }
    
    struct RecommendationCard: View {
        let title: String
        let description: String
        let priority: RecommendationPriority
        
        var body: some View {
            HStack(spacing: 12) {
                // Priority Badge
                VStack {
                    Text(priority.text)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priority.color)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Video-First Analysis View
    
    struct VideoFirstAnalysisView: View {
        let videoData: Data
        let analysisResult: SwingAnalysisResponse
        let onDismiss: () -> Void
        
        @State private var videoURL: URL?
        @State private var currentTime: Double = 0
        @State private var isPlaying = false
        @State private var videoDuration: Double = 1.0
        @State private var isRightHanded = true
        @State private var showControls = true
        
        var body: some View {
            VStack(spacing: 0) {
                // Video Section (constrained height)
                GeometryReader { geometry in
                    ZStack {
                        // Video Background
                        if let url = videoURL {
                            VideoPlayerView(
                                url: url,
                                currentTime: $currentTime,
                                isPlaying: $isPlaying,
                                duration: $videoDuration
                            )
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        } else {
                            // Loading state
                            Rectangle()
                                .fill(Color.black)
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                )
                        }
                        
                        // Interactive Swing Tracking Overlay
                        InteractiveSwingOverlay(
                            analysisResult: analysisResult,
                            currentTime: currentTime,
                            videoDuration: videoDuration,
                            isRightHanded: isRightHanded,
                            screenSize: geometry.size,
                            showControls: $showControls
                        )
                        .allowsHitTesting(true)
                        .zIndex(1)
                    
                    // Minimal Controls
                    VStack {
                        Spacer()
                        
                        if showControls {
                            HStack {
                                // Back Button
                                Button(action: onDismiss) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                
                                Spacer()
                                
                                // Handedness Toggle
                                HStack(spacing: 0) {
                                    Button(action: { isRightHanded = true }) {
                                        Text("R")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(isRightHanded ? .black : .white)
                                            .frame(width: 32, height: 32)
                                            .background(isRightHanded ? Color.white : Color.white.opacity(0.2))
                                    }
                                    
                                    Button(action: { isRightHanded = false }) {
                                        Text("L")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(!isRightHanded ? .black : .white)
                                            .frame(width: 32, height: 32)
                                            .background(!isRightHanded ? Color.white : Color.white.opacity(0.2))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                
                                Spacer()
                                
                                // Play/Pause
                                Button(action: {
                                    isPlaying.toggle()
                                }) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                    
                    // Tap to toggle controls (excluding interactive overlay areas)
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                        .zIndex(0)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showControls.toggle()
                            }
                        }
                    }
                }
                .frame(height: 300) // Constrain video height
                
                // Detailed Analysis Section Below Video
                DetailedSwingAnalysisView(
                    analysisResult: analysisResult,
                    currentTime: currentTime,
                    videoDuration: videoDuration,
                    isPlaying: $isPlaying
                )
            }
            .onAppear {
                setupVideo()
            }
        }
        
        func setupVideo() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_first_analysis_\(UUID().uuidString).mp4")
            
            do {
                try videoData.write(to: tempURL)
                videoURL = tempURL
            } catch {
                print("Failed to write video data: \(error)")
            }
        }
    }
    
    // MARK: - Clean Swing Tracking Overlay
    
    struct CleanSwingTrackingOverlay: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        let isRightHanded: Bool
        let screenSize: CGSize
        
        var body: some View {
            ZStack {
                // Dynamic Ball Position with pose tracking
                if let ballPosition = getDynamicBallPosition() {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 3)
                                .frame(width: 24, height: 24)
                        )
                        .position(ballPosition)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .animation(.easeInOut(duration: 0.1), value: ballPosition)
                }
                
                // Dynamic Pose-Based Swing Planes
                if let currentPose = getCurrentPoseFrame() {
                    // Ideal swing plane based on actual body position
                    if let idealPlane = getIdealPlaneFromPose(currentPose) {
                        Path { path in
                            path.move(to: idealPlane.start)
                            path.addLine(to: idealPlane.end)
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .shadow(color: .green.opacity(0.3), radius: 3)
                    }
                    
                    // User's actual swing plane from pose data
                    if let userPlane = getUserPlaneFromPose(currentPose) {
                        Path { path in
                            path.move(to: userPlane.start)
                            path.addLine(to: userPlane.end)
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.8), Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .shadow(color: .yellow.opacity(0.3), radius: 3)
                    }
                }
                
                
            }
        }
        
        // MARK: - Helper Functions
        
        private func getBallPosition() -> CGPoint {
            // Get ball position based on pose data or fallback
            if let currentPose = getCurrentPoseFrame() {
                if let leftFoot = currentPose.landmarks["left_ankle"],
                   let rightFoot = currentPose.landmarks["right_ankle"] {
                    
                    let feetCenter = CGPoint(
                        x: (leftFoot.x + rightFoot.x) / 2 * screenSize.width,
                        y: max(leftFoot.y, rightFoot.y) * screenSize.height
                    )
                    
                    // Adjust for swing phase
                    let progress = currentTime / videoDuration
                    let offset = getBallOffset(for: progress)
                    
                    return CGPoint(
                        x: feetCenter.x + offset.x,
                        y: feetCenter.y + offset.y
                    )
                }
            }
            
            // Fallback position
            return CGPoint(
                x: screenSize.width * (isRightHanded ? 0.5 : 0.5),
                y: screenSize.height * 0.75
            )
        }
        
        private func getSwingPlanePoints() -> (start: CGPoint, end: CGPoint) {
            // Ideal swing plane based on pose or fallback
            if let currentPose = getCurrentPoseFrame(),
               let leftShoulder = currentPose.landmarks["left_shoulder"],
               let rightShoulder = currentPose.landmarks["right_shoulder"] {
                
                let shoulderCenter = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2 * screenSize.width,
                    y: (leftShoulder.y + rightShoulder.y) / 2 * screenSize.height
                )
                
                let ballPos = getBallPosition()
                
                // Calculate ideal plane from shoulder to ball and beyond
                let direction = CGPoint(
                    x: ballPos.x - shoulderCenter.x,
                    y: ballPos.y - shoulderCenter.y
                )
                
                let length = sqrt(direction.x * direction.x + direction.y * direction.y)
                let normalizedDirection = CGPoint(
                    x: direction.x / length,
                    y: direction.y / length
                )
                
                // Extend the line
                let extensionLength: CGFloat = 150
                
                return (
                    start: CGPoint(
                        x: shoulderCenter.x - normalizedDirection.x * extensionLength * 0.5,
                        y: shoulderCenter.y - normalizedDirection.y * extensionLength * 0.5
                    ),
                    end: CGPoint(
                        x: ballPos.x + normalizedDirection.x * extensionLength,
                        y: ballPos.y + normalizedDirection.y * extensionLength
                    )
                )
            }
            
            // Fallback static plane
            return getStaticPlanePoints(ideal: true)
        }
        
        private func getUserSwingPlanePoints() -> (start: CGPoint, end: CGPoint) {
            // User's actual swing plane based on pose
            if let currentPose = getCurrentPoseFrame(),
               let leftShoulder = currentPose.landmarks["left_shoulder"],
               let rightShoulder = currentPose.landmarks["right_shoulder"],
               let leftWrist = currentPose.landmarks["left_wrist"] {
                
                let shoulderCenter = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2 * screenSize.width,
                    y: (leftShoulder.y + rightShoulder.y) / 2 * screenSize.height
                )
                
                let wristPos = CGPoint(
                    x: leftWrist.x * screenSize.width,
                    y: leftWrist.y * screenSize.height
                )
                
                // Calculate direction from shoulder to wrist
                let direction = CGPoint(
                    x: wristPos.x - shoulderCenter.x,
                    y: wristPos.y - shoulderCenter.y
                )
                
                let length = sqrt(direction.x * direction.x + direction.y * direction.y)
                guard length > 0 else { return getStaticPlanePoints(ideal: false) }
                
                let normalizedDirection = CGPoint(
                    x: direction.x / length,
                    y: direction.y / length
                )
                
                let extensionLength: CGFloat = 200
                
                return (
                    start: CGPoint(
                        x: shoulderCenter.x - normalizedDirection.x * extensionLength * 0.3,
                        y: shoulderCenter.y - normalizedDirection.y * extensionLength * 0.3
                    ),
                    end: CGPoint(
                        x: shoulderCenter.x + normalizedDirection.x * extensionLength,
                        y: shoulderCenter.y + normalizedDirection.y * extensionLength
                    )
                )
            }
            
            return getStaticPlanePoints(ideal: false)
        }
        
        private func getStaticPlanePoints(ideal: Bool) -> (start: CGPoint, end: CGPoint) {
            let deviation: CGPoint = ideal ? CGPoint.zero : getPlaneDeviation()
            
            if isRightHanded {
                return (
                    start: CGPoint(x: screenSize.width * 0.3, y: screenSize.height * 0.7),
                    end: CGPoint(
                        x: screenSize.width * 0.8 + deviation.x,
                        y: screenSize.height * 0.3 + deviation.y
                    )
                )
            } else {
                return (
                    start: CGPoint(x: screenSize.width * 0.7, y: screenSize.height * 0.7),
                    end: CGPoint(
                        x: screenSize.width * 0.2 - deviation.x,
                        y: screenSize.height * 0.3 + deviation.y
                    )
                )
            }
        }
        
        private func getPlaneDeviation() -> CGPoint {
            switch analysisResult.predicted_label {
            case "too_steep": return CGPoint(x: -25, y: -35)
            case "too_flat": return CGPoint(x: 25, y: 35)
            default: return CGPoint.zero
            }
        }
        
        private func getCurrentPoseFrame() -> PoseFrame? {
            guard let poseSequence = analysisResult.pose_sequence,
                  !poseSequence.isEmpty else { return nil }
            
            let frameIndex = Int((currentTime / videoDuration) * Double(poseSequence.count))
            let clampedIndex = min(max(frameIndex, 0), poseSequence.count - 1)
            return poseSequence[clampedIndex]
        }
        
        private func getBallOffset(for progress: Double) -> CGPoint {
            switch progress {
            case 0.0..<0.3: return CGPoint(x: 0, y: 0)
            case 0.3..<0.6: return CGPoint(x: -8, y: -3)
            case 0.6..<0.8: return CGPoint(x: 3, y: -2)
            default: return CGPoint(x: 12, y: 2)
            }
        }
        
        private func getSwingPhase() -> String {
            let progress = currentTime / videoDuration
            switch progress {
            case 0.0..<0.2: return "Setup"
            case 0.2..<0.4: return "Takeaway"
            case 0.4..<0.6: return "Backswing"
            case 0.6..<0.8: return "Downswing"
            case 0.8..<0.95: return "Impact"
            default: return "Follow Through"
            }
        }
        
        private func getPlaneStatus() -> String {
            switch analysisResult.predicted_label {
            case "on_plane": return "On Plane ✓"
            case "too_steep": return "Too Steep"
            case "too_flat": return "Too Flat"
            default: return "Analyzing..."
            }
        }
        
        private func getPlaneStatusColor() -> Color {
            switch analysisResult.predicted_label {
            case "on_plane": return .green
            case "too_steep", "too_flat": return .yellow
            default: return .white
            }
        }
        
        private func getDynamicBallPosition() -> CGPoint? {
            guard let poseSequence = analysisResult.pose_sequence,
                  !poseSequence.isEmpty else {
                return nil
            }
            
            // Find the address position (first few frames) to establish ball position
            let addressFrames = Array(poseSequence.prefix(3))
            
            var ballX: Double = 0
            var ballY: Double = 0
            var validFrames = 0
            
            for frame in addressFrames {
                // Use right ankle as reference point for ball position
                if let rightAnkle = frame.landmarks["right_ankle"] {
                    // Ball is typically positioned relative to front foot
                    ballX += rightAnkle.x - 0.1 // Slightly forward of right ankle
                    ballY += rightAnkle.y - 0.05 // Slightly above ground level
                    validFrames += 1
                }
            }
            
            if validFrames > 0 {
                ballX /= Double(validFrames)
                ballY /= Double(validFrames)
                
                // Convert normalized coordinates to screen coordinates
                return CGPoint(
                    x: ballX * screenSize.width,
                    y: ballY * screenSize.height
                )
            }
            
            return nil
        }
        
        private func getIdealPlaneFromPose(_ pose: PoseFrame) -> (start: CGPoint, end: CGPoint)? {
            // Calculate ideal swing plane based on golfer's setup
            guard let leftShoulder = pose.landmarks["left_shoulder"],
                  let rightShoulder = pose.landmarks["right_shoulder"],
                  let leftHip = pose.landmarks["left_hip"],
                  let rightHip = pose.landmarks["right_hip"] else {
                return nil
            }
            
            // Calculate shoulder and hip center points
            let shoulderCenter = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2 * screenSize.width,
                y: (leftShoulder.y + rightShoulder.y) / 2 * screenSize.height
            )
            
            let hipCenter = CGPoint(
                x: (leftHip.x + rightHip.x) / 2 * screenSize.width,
                y: (leftHip.y + rightHip.y) / 2 * screenSize.height
            )
            
            // Create ideal plane line from shoulder to hip and extend
            let direction = CGPoint(
                x: hipCenter.x - shoulderCenter.x,
                y: hipCenter.y - shoulderCenter.y
            )
            
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            guard length > 0 else { return nil }
            
            let normalizedDirection = CGPoint(
                x: direction.x / length,
                y: direction.y / length
            )
            
            let extensionLength: CGFloat = 150
            
            return (
                start: CGPoint(
                    x: shoulderCenter.x - normalizedDirection.x * extensionLength * 0.5,
                    y: shoulderCenter.y - normalizedDirection.y * extensionLength * 0.5
                ),
                end: CGPoint(
                    x: hipCenter.x + normalizedDirection.x * extensionLength,
                    y: hipCenter.y + normalizedDirection.y * extensionLength
                )
            )
        }
        
        private func getUserPlaneFromPose(_ pose: PoseFrame) -> (start: CGPoint, end: CGPoint)? {
            // Calculate user's actual swing plane from club/hand position
            guard let leftWrist = pose.landmarks["left_wrist"],
                  let rightWrist = pose.landmarks["right_wrist"],
                  let leftShoulder = pose.landmarks["left_shoulder"] else {
                return nil
            }
            
            // Calculate hand center (approximates club position)
            let handCenter = CGPoint(
                x: (leftWrist.x + rightWrist.x) / 2 * screenSize.width,
                y: (leftWrist.y + rightWrist.y) / 2 * screenSize.height
            )
            
            let shoulderPos = CGPoint(
                x: leftShoulder.x * screenSize.width,
                y: leftShoulder.y * screenSize.height
            )
            
            // Calculate direction from shoulder to hands
            let direction = CGPoint(
                x: handCenter.x - shoulderPos.x,
                y: handCenter.y - shoulderPos.y
            )
            
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            guard length > 0 else { return nil }
            
            let normalizedDirection = CGPoint(
                x: direction.x / length,
                y: direction.y / length
            )
            
            let extensionLength: CGFloat = 200
            
            return (
                start: CGPoint(
                    x: shoulderPos.x - normalizedDirection.x * extensionLength * 0.3,
                    y: shoulderPos.y - normalizedDirection.y * extensionLength * 0.3
                ),
                end: CGPoint(
                    x: handCenter.x + normalizedDirection.x * extensionLength,
                    y: handCenter.y + normalizedDirection.y * extensionLength
                )
            )
        }
    }
    
    // MARK: - Interactive Swing Overlay
    
    struct InteractiveSwingOverlay: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        let isRightHanded: Bool
        let screenSize: CGSize
        @Binding var showControls: Bool
        @State private var selectedClubPosition: String = "Takeaway" // "Takeaway", "Impact", etc.
        @State private var showingClubPath = true
        @State private var showingSwingPlane = true
        
        var body: some View {
            ZStack {
                // Dynamic Ball Position
                if let ballPosition = getDynamicBallPosition() {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 3)
                                .frame(width: 24, height: 24)
                        )
                        .position(ballPosition)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                
                // Club Position Analysis (like reference image)
                if let currentPose = getCurrentPoseFrame() {
                    ClubPositionIndicator(
                        pose: currentPose,
                        screenSize: screenSize,
                        phase: getSwingPhase()
                    )
                    
                    // Swing plane lines
                    if showingSwingPlane {
                        if let idealPlane = getIdealPlaneFromPose(currentPose) {
                            Path { path in
                                path.move(to: idealPlane.start)
                                path.addLine(to: idealPlane.end)
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.8), Color.green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                        }
                        
                        if let userPlane = getUserPlaneFromPose(currentPose) {
                            Path { path in
                                path.move(to: userPlane.start)
                                path.addLine(to: userPlane.end)
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 5])
                            )
                        }
                    }
                }
                
                // Interactive Controls (top of screen)
                VStack {
                    HStack {
                        // Club Position Toggle
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingClubPath.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(showingClubPath ? Color.blue : Color.gray)
                                    .frame(width: 10, height: 10)
                                Text("Club Path")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showingClubPath ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Club Position Warning (Interactive)
                        Button(action: {
                            // Show detailed club position analysis
                            print("🏌️ Club position analysis tapped")
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                
                                Text("Club Outside at Setup")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .scaleEffect(1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture {
                            // Provide haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        Spacer()
                        
                        // Setup Button (Interactive)  
                        Button(action: {
                            // Show setup guidance
                            print("⚙️ Setup guidance requested")
                        }) {
                            Text("Setup")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16) 
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .scaleEffect(1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture {
                            // Provide haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Bottom analysis indicators
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            // Show detailed swing plane analysis
                            print("📐 Swing plane analysis tapped")
                        }) {
                            VStack(spacing: 4) {
                                Text("SWING PLANE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("\(String(format: "%.1f", analysisResult.physics_insights.avg_plane_angle))°")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(getPlaneAngleColor())
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scaleEffect(1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture {
                            // Provide haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        .padding(.bottom, 20)
                        .padding(.trailing, 20)
                    }
                }
            }
        }
        
        // Helper functions
        private func getDynamicBallPosition() -> CGPoint? {
            guard let poseSequence = analysisResult.pose_sequence,
                  !poseSequence.isEmpty else { return nil }
            
            let addressFrames = Array(poseSequence.prefix(3))
            var ballX: Double = 0
            var ballY: Double = 0
            var validFrames = 0
            
            for frame in addressFrames {
                if let rightAnkle = frame.landmarks["right_ankle"] {
                    ballX += rightAnkle.x - 0.1
                    ballY += rightAnkle.y - 0.05
                    validFrames += 1
                }
            }
            
            if validFrames > 0 {
                ballX /= Double(validFrames)
                ballY /= Double(validFrames)
                return CGPoint(x: ballX * screenSize.width, y: ballY * screenSize.height)
            }
            return nil
        }
        
        private func getCurrentPoseFrame() -> PoseFrame? {
            guard let poseSequence = analysisResult.pose_sequence,
                  !poseSequence.isEmpty else { return nil }
            
            let frameIndex = Int(currentTime / videoDuration * Double(poseSequence.count))
            let clampedIndex = max(0, min(frameIndex, poseSequence.count - 1))
            return poseSequence[clampedIndex]
        }
        
        private func getIdealPlaneFromPose(_ pose: PoseFrame) -> (start: CGPoint, end: CGPoint)? {
            guard let leftShoulder = pose.landmarks["left_shoulder"],
                  let rightShoulder = pose.landmarks["right_shoulder"] else { return nil }
            
            let shoulderCenter = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2 * screenSize.width,
                y: (leftShoulder.y + rightShoulder.y) / 2 * screenSize.height
            )
            
            let extensionLength: CGFloat = 200
            let angle: Double = -30 * .pi / 180 // 30 degree downward angle
            
            return (
                start: CGPoint(x: shoulderCenter.x - extensionLength * cos(angle), y: shoulderCenter.y - extensionLength * sin(angle)),
                end: CGPoint(x: shoulderCenter.x + extensionLength * cos(angle), y: shoulderCenter.y + extensionLength * sin(angle))
            )
        }
        
        private func getUserPlaneFromPose(_ pose: PoseFrame) -> (start: CGPoint, end: CGPoint)? {
            guard let leftWrist = pose.landmarks["left_wrist"],
                  let rightWrist = pose.landmarks["right_wrist"],
                  let leftShoulder = pose.landmarks["left_shoulder"] else { return nil }
            
            let handCenter = CGPoint(
                x: (leftWrist.x + rightWrist.x) / 2 * screenSize.width,
                y: (leftWrist.y + rightWrist.y) / 2 * screenSize.height
            )
            
            let shoulderPos = CGPoint(
                x: leftShoulder.x * screenSize.width,
                y: leftShoulder.y * screenSize.height
            )
            
            let direction = CGPoint(x: handCenter.x - shoulderPos.x, y: handCenter.y - shoulderPos.y)
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            guard length > 0 else { return nil }
            
            let normalizedDirection = CGPoint(x: direction.x / length, y: direction.y / length)
            let extensionLength: CGFloat = 150
            
            return (
                start: CGPoint(x: shoulderPos.x - normalizedDirection.x * extensionLength * 0.3, y: shoulderPos.y - normalizedDirection.y * extensionLength * 0.3),
                end: CGPoint(x: handCenter.x + normalizedDirection.x * extensionLength, y: handCenter.y + normalizedDirection.y * extensionLength)
            )
        }
        
        private func getSwingPhase() -> String {
            let progress = currentTime / videoDuration
            switch progress {
            case 0.0..<0.2: return "Setup"
            case 0.2..<0.4: return "Takeaway"
            case 0.4..<0.6: return "Backswing"
            case 0.6..<0.8: return "Downswing"
            case 0.8..<0.95: return "Impact"
            default: return "Follow Through"
            }
        }
        
        private func getClubPositionText() -> String {
            let phase = getSwingPhase()
            switch analysisResult.predicted_label {
            case "too_steep": return "Club Outside at \(phase)"
            case "too_flat": return "Club Inside at \(phase)"
            default: return "Club On-Plane at \(phase)"
            }
        }
        
        private func getPlaneAngleColor() -> Color {
            let angle = analysisResult.physics_insights.avg_plane_angle
            switch angle {
            case 40...50: return .green
            case 35..<40, 50..<55: return .yellow
            default: return .red
            }
        }
    }
    
    // MARK: - Club Position Indicator
    
    struct ClubPositionIndicator: View {
        let pose: PoseFrame
        let screenSize: CGSize
        let phase: String
        
        var body: some View {
            if let leftWrist = pose.landmarks["left_wrist"] {
                VStack(spacing: 4) {
                    // Position indicator
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        )
                    
                    // Phase label
                    Text(phase)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .position(
                    CGPoint(
                        x: leftWrist.x * screenSize.width,
                        y: leftWrist.y * screenSize.height
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
    }
    
    // MARK: - Detailed Swing Analysis View
    
    struct DetailedSwingAnalysisView: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        @Binding var isPlaying: Bool
        @State private var selectedTab = 0
        
        var body: some View {
            VStack(spacing: 0) {
                // Tab Bar
                HStack(spacing: 0) {
                    TabButton(title: "Overview", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Physics", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Breakdown", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                    TabButton(title: "Tips", isSelected: selectedTab == 3) {
                        selectedTab = 3
                    }
                }
                .background(Color(UIColor.systemBackground))
                
                // Content
                ScrollView {
                    Group {
                        switch selectedTab {
                        case 0:
                            OverviewTabContent(analysisResult: analysisResult)
                        case 1:
                            PhysicsTabContent(analysisResult: analysisResult)
                        case 2:
                            BreakdownTabContent(analysisResult: analysisResult, currentTime: currentTime, videoDuration: videoDuration)
                        case 3:
                            TipsTabContent(analysisResult: analysisResult)
                        default:
                            OverviewTabContent(analysisResult: analysisResult)
                        }
                    }
                    .padding(.bottom, 100) // Space for tab bar
                }
                .background(Color(UIColor.systemBackground))
            }
        }
    }
    
    struct OverviewTabContent: View {
        let analysisResult: SwingAnalysisResponse
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Main Result Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: getResultIcon())
                            .font(.title2)
                            .foregroundColor(getResultColor())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Swing Analysis")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(analysisResult.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(getResultColor())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(analysisResult.confidence * 100))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(analysisResult.confidence > 0.8 ? .green : .orange)
                        }
                    }
                    
                    // Confidence bar
                    ProgressView(value: analysisResult.confidence)
                        .progressViewStyle(LinearProgressViewStyle(tint: analysisResult.confidence > 0.8 ? .green : .orange))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Key Metrics
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    MetricCard(
                        title: "Swing Plane",
                        value: "\(String(format: "%.1f", analysisResult.physics_insights.avg_plane_angle))°",
                        status: getPlaneStatus(),
                        color: getPlaneColor()
                    )
                    
                    MetricCard(
                        title: "Overall",
                        value: analysisResult.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized,
                        status: "Analysis Complete",
                        color: getResultColor()
                    )
                }
                
                // Quick Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis Summary")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(analysisResult.physics_insights.plane_analysis)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
        
        private func getResultIcon() -> String {
            switch analysisResult.predicted_label {
            case "on_plane": return "checkmark.circle.fill"
            case "too_steep": return "arrow.up.circle.fill"
            case "too_flat": return "arrow.down.circle.fill"
            default: return "questionmark.circle.fill"
            }
        }
        
        private func getResultColor() -> Color {
            switch analysisResult.predicted_label {
            case "on_plane": return .green
            case "too_steep", "too_flat": return .orange
            default: return .gray
            }
        }
        
        private func getPlaneStatus() -> String {
            let angle = analysisResult.physics_insights.avg_plane_angle
            switch angle {
            case 40...50: return "Optimal"
            case 35..<40: return "Too Flat"
            case 50..<60: return "Steep"
            case 60...: return "Too Steep"
            default: return "Very Flat"
            }
        }
        
        private func getPlaneColor() -> Color {
            let angle = analysisResult.physics_insights.avg_plane_angle
            switch angle {
            case 40...50: return .green
            case 35..<40, 50..<55: return .orange
            default: return .red
            }
        }
    }
    
    struct MetricCard: View {
        let title: String
        let value: String
        let status: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(status)
                    .font(.caption)
                    .foregroundColor(color)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    struct BreakdownTabContent: View {
        let analysisResult: SwingAnalysisResponse
        let currentTime: Double
        let videoDuration: Double
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Timeline breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Swing Breakdown")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // Timeline phases
                    VStack(spacing: 12) {
                        PhaseRow(title: "Setup", range: "0% - 20%", status: "Good", color: .green)
                        PhaseRow(title: "Takeaway", range: "20% - 40%", status: "Check Position", color: .orange)
                        PhaseRow(title: "Backswing", range: "40% - 60%", status: "On Track", color: .green)
                        PhaseRow(title: "Downswing", range: "60% - 80%", status: "Issue Detected", color: .red)
                        PhaseRow(title: "Impact", range: "80% - 95%", status: "Needs Work", color: .orange)
                        PhaseRow(title: "Follow Through", range: "95% - 100%", status: "Good", color: .green)
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Current phase highlight
                let currentPhase = getCurrentPhase()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current: \(currentPhase)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("At this point in your swing, focus on maintaining proper club position and body alignment.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
        
        private func getCurrentPhase() -> String {
            let progress = currentTime / videoDuration
            switch progress {
            case 0.0..<0.2: return "Setup"
            case 0.2..<0.4: return "Takeaway"
            case 0.4..<0.6: return "Backswing"
            case 0.6..<0.8: return "Downswing"
            case 0.8..<0.95: return "Impact"
            default: return "Follow Through"
            }
        }
    }
    
    struct PhaseRow: View {
        let title: String
        let range: String
        let status: String
        let color: Color
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(range)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    
                    Text(status)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    struct PhysicsTabContent: View {
        let analysisResult: SwingAnalysisResponse
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Main Physics Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SWING PLANE ANGLE")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(String(format: "%.1f", analysisResult.physics_insights.avg_plane_angle))°")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(getPlaneColor())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("STATUS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(getPlaneStatus())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(getPlaneColor())
                        }
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Physics Analysis
                VStack(alignment: .leading, spacing: 12) {
                    Text("Physics Analysis")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(analysisResult.physics_insights.plane_analysis)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
        
        private func getPlaneStatus() -> String {
            let angle = analysisResult.physics_insights.avg_plane_angle
            switch angle {
            case 40...50: return "Optimal"
            case 35..<40: return "Too Flat"
            case 50..<60: return "Steep"
            case 60...: return "Too Steep"
            default: return "Very Flat"
            }
        }
        
        private func getPlaneColor() -> Color {
            let angle = analysisResult.physics_insights.avg_plane_angle
            switch angle {
            case 40...50: return .green
            case 35..<40, 50..<55: return .orange
            default: return .red
            }
        }
    }
    
    struct TipsTabContent: View {
        let analysisResult: SwingAnalysisResponse
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                if let recommendations = analysisResult.recommendations, !recommendations.isEmpty {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 16) {
                            Text("\(index + 1).")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .frame(width: 24, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(tip)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General Tips")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Keep practicing! Focus on maintaining a consistent swing plane and follow through.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
    }
    
    struct TabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
        }
    }

struct SwingAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        SwingAnalysisView()
    }
}
