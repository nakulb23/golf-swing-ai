import SwiftUI
import PhotosUI
import AVFoundation

struct SwingAnalysisView: View {
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
    
    // Multi-angle enhancement states
    @State private var cameraAngleResult: CameraAngleResponse?
    @State private var isDetectingAngle = false
    @State private var showAngleGuidance = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero Header
                        VStack(spacing: 16) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 72, weight: .light))
                                .foregroundColor(.blue)
                                .padding(.top, 20)
                            
                            Text("Swing Analysis")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text("Upload your swing video for instant AI-powered analysis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 20)
                        
                        // Video Capture/Upload Card
                        VStack(spacing: 24) {
                            VStack(spacing: 24) {
                                // Video Status Display
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                videoData != nil 
                                                ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                : LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: videoData != nil ? "checkmark.circle.fill" : "video.fill")
                                            .font(.system(size: 36, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Text(videoData != nil ? "Video Ready for Analysis" : "Record or Upload Your Swing")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Text(videoData != nil ? "Ready to analyze your swing video" : "Capture a new video or choose from your library")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.vertical, 10)
                                
                                // Video Source Options
                                if videoData == nil {
                                    HStack(spacing: 16) {
                                        // Record Video Button
                                        Button(action: { showingCamera = true }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "video.badge.plus")
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 50, height: 50)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    )
                                                
                                                Text("Record Video")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Upload Video Button
                                        Button(action: { showingSourceSelection = true }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.on.rectangle")
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 50, height: 50)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    )
                                                
                                                Text("Upload Video")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.vertical, 10)
                                } else {
                                    // Change Video Button
                                    Button(action: { showingSourceSelection = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Change Video")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                    }
                                }
                                
                                // Camera Angle Detection Button (NEW)
                                if videoData != nil {
                                    Button(action: detectCameraAngle) {
                                        HStack(spacing: 12) {
                                            if isDetectingAngle {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(.orange)
                                            } else {
                                                Image(systemName: "camera.viewfinder")
                                                    .font(.system(size: 16, weight: .medium))
                                            }
                                            Text(isDetectingAngle ? "Detecting Camera Angle..." : "Check Camera Angle")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    !isDetectingAngle
                                                    ? LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                                    : LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                                )
                                        )
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    }
                                    .disabled(isDetectingAngle || isAnalyzing)
                                }
                                
                                // Camera Angle Result Display
                                if let angleResult = cameraAngleResult {
                                    CameraAngleResultView(result: angleResult)
                                        .transition(.slide)
                                }
                                
                                Button(action: analyzeSwing) {
                                    HStack(spacing: 12) {
                                        if isAnalyzing {
                                            ProgressView()
                                                .scaleEffect(0.9)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 18, weight: .medium))
                                        }
                                        Text(isAnalyzing ? "Analyzing Your Swing..." : "Start AI Analysis")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                videoData != nil && !isAnalyzing 
                                                ? LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                                                : LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                            )
                                    )
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                }
                                .disabled(videoData == nil || isAnalyzing)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Analysis Results
                        if let result = analysisResult {
                            AnalysisResultView(result: result)
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            VStack(spacing: 12) {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.title2)
                                        Text("Analysis Error")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    Text(error)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
                
                // Swing Classifications Overlay
                if showClassifications {
                    SwingClassificationsOverlay(isPresented: $showClassifications)
                }
            }
            .navigationTitle("Swing Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showClassifications = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(videoData: $videoData)
        }
        .confirmationDialog("Select Video Source", isPresented: $showingSourceSelection, titleVisibility: .visible) {
            Button("Record New Video") {
                showingCamera = true
            }
            
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How would you like to get your swing video?")
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedVideo, matching: .videos)
        .onChange(of: selectedVideo) { oldValue, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    videoData = data
                    analysisResult = nil
                    errorMessage = nil
                }
            }
        }
    }
    
    private func detectCameraAngle() {
        guard let data = videoData else { 
            print("⚠️ No video data available for angle detection")
            return 
        }
        
        print("📷 Starting camera angle detection...")
        isDetectingAngle = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await apiService.detectCameraAngle(videoData: data)
                
                await MainActor.run {
                    print("✅ Camera angle detected: \(result.camera_angle)")
                    cameraAngleResult = result
                    isDetectingAngle = false
                    
                    // Show guidance if angle needs adjustment
                    if result.guidance.status != "excellent" {
                        showAngleGuidance = true
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Camera angle detection failed: \(error.localizedDescription)")
                    errorMessage = "Failed to detect camera angle: \(error.localizedDescription)"
                    isDetectingAngle = false
                }
            }
        }
    }
    
    private func analyzeSwing() {
        guard let data = videoData else { 
            print("⚠️ No video data available for analysis")
            return 
        }
        
        print("🎯 Starting swing analysis...")
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await apiService.analyzeSwing(videoData: data)
                
                await MainActor.run {
                    print("✅ Swing analysis completed: \(result.predicted_label)")
                    print("📷 Analysis type: \(result.analysis_type ?? "traditional")")
                    if let cameraAngle = result.camera_angle {
                        print("📷 Camera angle used: \(cameraAngle)")
                    }
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Swing analysis failed: \(error.localizedDescription)")
                    errorMessage = "Failed to analyze swing: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    // Mock data for testing UI when API is unavailable
    private func createMockResult() -> SwingAnalysisResponse {
        let scenarios = [
            // Scenario 1: Too Steep with Multi-angle
            SwingAnalysisResponse(
                predicted_label: "too_steep",
                confidence: 0.85,
                confidence_gap: 0.32,
                all_probabilities: [
                    "too_steep": 0.85,
                    "on_plane": 0.12,
                    "too_flat": 0.03
                ],
                camera_angle: "side_on",
                angle_confidence: 0.92,
                feature_reliability: [
                    "swing_plane": 1.0,
                    "body_rotation": 0.8,
                    "balance": 0.9,
                    "tempo": 1.0,
                    "club_path": 0.7
                ],
                physics_insights: "Your swing plane is too steep (confidence: 85%). This can lead to fat shots, loss of distance, and inconsistent ball striking. Focus on taking the club back more around your body and less vertically.",
                angle_insights: "Side-on view provides optimal swing plane analysis. This is the ideal angle for detecting swing plane issues.",
                recommendations: [
                    "Work on a more shallow backswing takeaway",
                    "Practice the 'one-piece' takeaway drill",
                    "Focus on turning your shoulders rather than lifting your arms"
                ],
                extraction_status: "success",
                analysis_type: "multi_angle",
                model_version: "2.0_multi_angle"
            ),
            
            // Scenario 2: On Plane (Good)
            SwingAnalysisResponse(
                predicted_label: "on_plane",
                confidence: 0.92,
                confidence_gap: 0.45,
                all_probabilities: [
                    "on_plane": 0.92,
                    "too_steep": 0.05,
                    "too_flat": 0.03
                ],
                physics_insights: PhysicsInsights(
                    avg_plane_angle: 43.7,
                    plane_analysis: "Excellent! Your swing plane is optimal at 43.7 degrees. This promotes consistent ball contact, accuracy, and distance control. Your swing mechanics are working very well - keep up the great work!"
                ),
                extraction_status: "success"
            ),
            
            // Scenario 3: Too Flat
            SwingAnalysisResponse(
                predicted_label: "too_flat",
                confidence: 0.78,
                confidence_gap: 0.28,
                all_probabilities: [
                    "too_flat": 0.78,
                    "on_plane": 0.15,
                    "too_steep": 0.07
                ],
                physics_insights: PhysicsInsights(
                    avg_plane_angle: 28.9,
                    plane_analysis: "Your swing plane is too horizontal at 28.9 degrees. This flat approach can lead to hooks and thin shots. The club is traveling too much around your body rather than up and down, which affects timing and power."
                ),
                extraction_status: "success"
            )
        ]
        
        // Randomly select one of the scenarios for testing
        return scenarios.randomElement() ?? scenarios[0]
    }
}

struct AnalysisResultView: View {
    let result: SwingAnalysisResponse
    @State private var showDetailedGuidance = false
    @State private var showVideoAnalysis = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Hero Result Card
            VStack(spacing: 20) {
                VStack(spacing: 20) {
                    // Result Header
                    VStack(spacing: 12) {
                        Image(systemName: iconForLabel(result.predicted_label))
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(colorForLabel(result.predicted_label))
                            .padding()
                            .background(
                                Circle()
                                    .fill(colorForLabel(result.predicted_label).opacity(0.15))
                            )
                        
                        Text(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(colorForLabel(result.predicted_label))
                        
                        Text(summaryForLabel(result.predicted_label))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Key Metrics
                    HStack(spacing: 32) {
                        MetricView(
                            value: "\(Int(result.confidence * 100))%",
                            label: "Confidence",
                            color: confidenceColor(result.confidence),
                            icon: "checkmark.shield"
                        )
                        
                        MetricView(
                            value: "\(String(format: "%.1f°", result.physics_insights.avg_plane_angle))",
                            label: "Swing Plane",
                            color: colorForLabel(result.predicted_label),
                            icon: "arrow.up.right"
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // Quick Assessment
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("AI Assessment")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    
                    Text(result.physics_insights.plane_analysis)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Video Analysis Button
                Button(action: { showVideoAnalysis = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("View Swing Plane")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [.swingAnalysis, .indigo.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                // Detailed Guidance Button
                Button(action: { showDetailedGuidance = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Improvement Tips")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.accentGradient)
                    )
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal)
            
            // Probability Breakdown
            GolfCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Analysis Breakdown")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    
                    ForEach(Array(result.all_probabilities.sorted(by: { $0.value > $1.value })), id: \.key) { key, value in
                        ProbabilityBar(
                            label: key.replacingOccurrences(of: "_", with: " ").capitalized,
                            percentage: value,
                            color: colorForLabel(key),
                            isHighest: key == result.predicted_label
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showDetailedGuidance) {
            DetailedGuidanceView(result: result)
        }
        .sheet(isPresented: $showVideoAnalysis) {
            VideoSwingPlaneAnalysisView(result: result)
        }
    }
    
    private func colorForLabel(_ label: String) -> Color {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return .success
        case "too_steep", "too steep":
            return .error
        case "too_flat", "too flat":
            return .warning
        default:
            return .swingAnalysis
        }
    }
    
    private func iconForLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return "checkmark.circle.fill"
        case "too_steep", "too steep":
            return "arrow.up.circle.fill"
        case "too_flat", "too flat":
            return "arrow.down.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private func summaryForLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return "Excellent! Your swing plane is optimal for consistent ball striking."
        case "too_steep", "too steep":
            return "Your swing plane is too vertical. This can lead to slices and fat shots."
        case "too_flat", "too flat":
            return "Your swing plane is too horizontal. This may cause hooks and thin shots."
        default:
            return "Analysis complete. See detailed guidance for improvement tips."
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .success
        } else if confidence >= 0.6 {
            return .warning
        } else {
            return .error
        }
    }
}

struct MetricView: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .golfCaption()
                .foregroundColor(.secondaryText)
        }
    }
}

struct ProbabilityBar: View {
    let label: String
    let percentage: Double
    let color: Color
    let isHighest: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .golfBody()
                    .foregroundColor(.primaryText)
                    .fontWeight(isHighest ? .semibold : .regular)
                
                Spacer()
                
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.easeInOut(duration: 1.0), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

struct DetailedGuidanceView: View {
    let result: SwingAnalysisResponse
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: iconForLabel(result.predicted_label))
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(colorForLabel(result.predicted_label))
                        
                        Text("Improvement Guide")
                            .golfTitle()
                            .foregroundColor(.primaryText)
                        
                        Text("Personalized tips based on your swing analysis")
                            .golfSubheadline()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.top, 20)
                    
                    // Current Status
                    GolfCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundColor(colorForLabel(result.predicted_label))
                                    .font(.title2)
                                
                                Text("Current Analysis")
                                    .golfHeadline()
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Swing Classification: \(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)")
                                    .golfBody()
                                    .foregroundColor(.primary)
                                
                                Text("Swing Plane Angle: \(String(format: "%.1f°", result.physics_insights.avg_plane_angle))")
                                    .golfBody()
                                    .foregroundColor(.primary)
                                
                                Text("Confidence Level: \(Int(result.confidence * 100))%")
                                    .golfBody()
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Specific Guidance
                    GolfCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.warning)
                                    .font(.title2)
                                
                                Text("What This Means")
                                    .golfHeadline()
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Text(detailedExplanation(for: result.predicted_label))
                                .golfBody()
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Improvement Tips
                    GolfCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                    .foregroundColor(.success)
                                    .font(.title2)
                                
                                Text("How to Improve")
                                    .golfHeadline()
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(improvementTips(for: result.predicted_label).enumerated()), id: \.offset) { index, tip in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.success)
                                            .frame(width: 20, alignment: .leading)
                                        
                                        Text(tip)
                                            .golfBody()
                                            .foregroundColor(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Practice Drills
                    GolfCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "figure.golf")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text("Practice Drills")
                                    .golfHeadline()
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(practiceDrills(for: result.predicted_label).enumerated()), id: \.offset) { index, drill in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "sportscourt")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                            .frame(width: 20)
                                        
                                        Text(drill)
                                            .golfBody()
                                            .foregroundColor(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Swing Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.swingAnalysis)
                }
            }
        }
    }
    
    private func colorForLabel(_ label: String) -> Color {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return .success
        case "too_steep", "too steep":
            return .error
        case "too_flat", "too flat":
            return .warning
        default:
            return .swingAnalysis
        }
    }
    
    private func iconForLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return "checkmark.circle.fill"
        case "too_steep", "too steep":
            return "arrow.up.circle.fill"
        case "too_flat", "too flat":
            return "arrow.down.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private func detailedExplanation(for label: String) -> String {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return "Your swing plane is in the optimal range (35-55°). This promotes consistent ball contact, better accuracy, and improved distance control. Keep maintaining this excellent swing plane through practice and proper setup."
        case "too_steep", "too steep":
            return "Your swing plane is too vertical (>55°). This typically occurs when the club approaches the ball from too high an angle, often leading to slices, fat shots, and loss of distance. The steep angle can cause the club to dig into the ground before impact."
        case "too_flat", "too flat":
            return "Your swing plane is too horizontal (<35°). This happens when the club travels around your body rather than up and down, often causing hooks, thin shots, and inconsistent ball striking. The flat plane can lead to timing issues and reduced power."
        default:
            return "Continue working on your swing mechanics with focus on maintaining a consistent swing plane angle between 35-55 degrees for optimal results."
        }
    }
    
    private func improvementTips(for label: String) -> [String] {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return [
                "Continue your current swing mechanics - they're working well!",
                "Focus on consistent tempo and rhythm to maintain this good plane",
                "Practice with alignment sticks to reinforce proper swing path",
                "Work on maintaining balance throughout your swing",
                "Consider fine-tuning your short game for even better scoring"
            ]
        case "too_steep", "too steep":
            return [
                "Focus on a more shallow takeaway - think 'low and slow' for the first few feet",
                "Work on rotating your shoulders around your spine rather than lifting the club",
                "Practice the 'flatten the plane' drill with a towel under your right arm",
                "Strengthen your core to improve rotation and reduce over-the-top moves",
                "Consider a more upright stance to naturally shallow your swing"
            ]
        case "too_flat", "too flat":
            return [
                "Focus on a more upright backswing - lift the club higher earlier",
                "Work on proper wrist hinge to create the correct swing plane angle",
                "Practice swinging along an inclined plane (use alignment sticks on a slope)",
                "Strengthen your lats and shoulders for better club control",
                "Focus on turning rather than sliding during the downswing"
            ]
        default:
            return [
                "Focus on maintaining a consistent swing plane between 35-55 degrees",
                "Practice with a mirror to visualize your swing plane",
                "Work with a golf instructor for personalized guidance",
                "Record your swing from different angles to track progress"
            ]
        }
    }
    
    private func practiceDrills(for label: String) -> [String] {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return [
                "Mirror work: Practice your swing in front of a mirror to maintain consistency",
                "Tempo drills: Use a metronome to keep your swing rhythm steady",
                "Impact bag work: Focus on solid contact at impact position",
                "Alignment stick drills: Place sticks on the ground to reinforce good setup"
            ]
        case "too_steep", "too steep":
            return [
                "Towel drill: Keep a towel under your right arm throughout the swing",
                "Baseball swing drill: Practice horizontal swings to feel a flatter plane",
                "Wall drill: Stand close to a wall and avoid hitting it on backswing",
                "Shallow angle drill: Practice with ball on a tee, focus on sweeping motion"
            ]
        case "too_flat", "too flat":
            return [
                "Upright swing drill: Practice against a steep hill or inclined plane",
                "Headcover drill: Place headcover outside ball, avoid hitting it",
                "Pump drill: Make small upright swings focusing on proper plane",
                "Medicine ball throws: Overhead throws to strengthen correct swing muscles"
            ]
        default:
            return [
                "General swing plane drills focusing on consistency",
                "Video analysis of your swing from down-the-line view",
                "Work with impact tape to check ball contact patterns",
                "Practice with different clubs to feel proper plane for each"
            ]
        }
    }
}

struct SwingClassificationsOverlay: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    Text("Swing Classifications")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(spacing: 16) {
                    ClassificationCard(
                        title: "On Plane",
                        range: "35-55°",
                        description: "Ideal swing plane angle that promotes consistent ball striking and accuracy",
                        color: .green
                    )
                    
                    ClassificationCard(
                        title: "Too Steep",
                        range: ">55°",
                        description: "Swing plane is too vertical, often leads to slices and fat shots",
                        color: .red
                    )
                    
                    ClassificationCard(
                        title: "Too Flat",
                        range: "<35°",
                        description: "Swing plane is too horizontal, can cause hooks and inconsistent contact",
                        color: .orange
                    )
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(20)
        }
    }
}

struct ClassificationCard: View {
    let title: String
    let range: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text(range)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Camera View
struct CameraView: View {
    @Binding var videoData: Data?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showAlignmentOverlay = true
    @State private var showInstructions = true
    @State private var isRightHanded = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                CameraPreview(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // Camera Alignment Overlay
                if showAlignmentOverlay && !cameraManager.isRecording {
                    SwingAlignmentOverlay(isRightHanded: isRightHanded)
                        .allowsHitTesting(false)
                }
                
                // Instructions Overlay
                if showInstructions && !cameraManager.isRecording {
                    VStack {
                        SwingSetupInstructions(
                            isRightHanded: $isRightHanded,
                            showAlignmentOverlay: $showAlignmentOverlay,
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showInstructions = false
                                }
                            }
                        )
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(1)
                }
                
                // Camera Controls Layer (Always on top)
                VStack {
                    // Simplified Top Controls
                    HStack {
                        // Combined Settings Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showInstructions = true
                            }
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 6)
                        }
                        
                        Spacer()
                        
                        // Handedness Toggle (Only when overlay is visible)
                        if showAlignmentOverlay && !cameraManager.isRecording {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRightHanded.toggle()
                                }
                            }) {
                                Text(isRightHanded ? "R" : "L")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .green.opacity(0.4), radius: 6)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Recording Controls
                    HStack(spacing: 40) {
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        
                        // Record Button
                        Button(action: {
                            if cameraManager.isRecording {
                                cameraManager.stopRecording { url in
                                    if let url = url,
                                       let data = try? Data(contentsOf: url) {
                                        videoData = data
                                        dismiss()
                                    }
                                }
                            } else {
                                // Hide instructions when recording starts
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showInstructions = false
                                }
                                cameraManager.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.3), radius: 6)
                                
                                Circle()
                                    .fill(cameraManager.isRecording ? Color.red : Color.red)
                                    .frame(width: cameraManager.isRecording ? 30 : 60, height: cameraManager.isRecording ? 30 : 60)
                                    .animation(.easeInOut(duration: 0.2), value: cameraManager.isRecording)
                            }
                        }
                        
                        // Flip Camera Button
                        Button(action: {
                            cameraManager.flipCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                    }
                    .padding(.bottom, 50)
                    
                    if cameraManager.isRecording {
                        Text("Recording...")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.5), radius: 4)
                            )
                            .padding(.bottom, 20)
                    }
                }
                .zIndex(2)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            cameraManager.checkPermissions()
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var videoFileURL: URL?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.sessionPreset = .high
        
        // Camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        currentCamera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            captureSession.addInput(input)
        } catch {
            print("Error adding camera input: \(error)")
            return
        }
        
        // Movie output
        movieOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieOutput {
            captureSession.addOutput(movieOutput)
        }
        
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
    }
    
    func startRecording() {
        guard let movieOutput = movieOutput else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        videoFileURL = documentsPath.appendingPathComponent("swing_video_\(Date().timeIntervalSince1970).mov")
        
        if let videoFileURL = videoFileURL {
            movieOutput.startRecording(to: videoFileURL, recordingDelegate: self)
            isRecording = true
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        movieOutput?.stopRecording()
        isRecording = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(self.videoFileURL)
        }
    }
    
    func flipCamera() {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // Remove current input
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        // Switch camera position
        let newPosition: AVCaptureDevice.Position = currentCamera?.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: newCamera)
            captureSession.addInput(input)
            currentCamera = newCamera
        } catch {
            print("Error switching camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        if let captureSession = cameraManager.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Premium Swing Alignment Overlay
struct SwingAlignmentOverlay: View {
    let isRightHanded: Bool
    @State private var animateGolfer = false
    @State private var animateTargetLine = false
    @State private var animateSwingPlane = false
    @State private var animateDistanceRings = false
    @State private var pulseGlow = false
    @State private var sequenceAnimation = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Professional Grid System
                PremiumGridOverlay(geometry: geometry)
                    .opacity(0.6)
                
                // Distance Rings
                PremiumDistanceRings(animate: animateDistanceRings)
                    .opacity(0.3)
                
                // Target Line with Physics
                PremiumTargetLine(
                    isRightHanded: isRightHanded,
                    animate: animateTargetLine,
                    geometry: geometry
                )
                
                // Swing Plane Visualization
                PremiumSwingPlane(
                    isRightHanded: isRightHanded,
                    animate: animateSwingPlane,
                    geometry: geometry
                )
                
                // Professional Golfer Template
                PremiumGolferTemplate(
                    isRightHanded: isRightHanded,
                    animate: animateGolfer,
                    pulseGlow: pulseGlow,
                    geometry: geometry
                )
                
                // Premium Ball Position System
                PremiumBallPosition(
                    isRightHanded: isRightHanded,
                    geometry: geometry
                )
                
                // Minimal Distance Indicator
                VStack {
                    Spacer()
                    HStack {
                        Text("6-8 FEET")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                        
                        Spacer()
                        
                        Text(isRightHanded ? "RIGHT HANDED" : "LEFT HANDED")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 180)
                }
            }
        }
        .onAppear {
            startPremiumAnimations()
        }
    }
    
    private func startPremiumAnimations() {
        // Simple fade-in animation
        withAnimation(.easeOut(duration: 0.8)) {
            animateDistanceRings = true
            animateTargetLine = true
            animateSwingPlane = true
            animateGolfer = true
        }
        
        // Gentle pulse for the golfer template
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}

// MARK: - Premium Grid Overlay
struct PremiumGridOverlay: View {
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Rule of thirds grid
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical thirds
                path.move(to: CGPoint(x: width/3, y: 0))
                path.addLine(to: CGPoint(x: width/3, y: height))
                
                path.move(to: CGPoint(x: 2*width/3, y: 0))
                path.addLine(to: CGPoint(x: 2*width/3, y: height))
                
                // Horizontal thirds
                path.move(to: CGPoint(x: 0, y: height/3))
                path.addLine(to: CGPoint(x: width, y: height/3))
                
                path.move(to: CGPoint(x: 0, y: 2*height/3))
                path.addLine(to: CGPoint(x: width, y: 2*height/3))
            }
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.3), .clear, .white.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 0.5, dash: [3, 6])
            )
            
            // Center alignment cross
            Path { path in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                path.move(to: CGPoint(x: centerX - 20, y: centerY))
                path.addLine(to: CGPoint(x: centerX + 20, y: centerY))
                
                path.move(to: CGPoint(x: centerX, y: centerY - 20))
                path.addLine(to: CGPoint(x: centerX, y: centerY + 20))
            }
            .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
            .shadow(color: .cyan, radius: 4)
        }
    }
}

// MARK: - Premium Distance Rings
struct PremiumDistanceRings: View {
    let animate: Bool
    
    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { ring in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .green.opacity(0.6),
                                .mint.opacity(0.3),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 8])
                    )
                    .frame(width: CGFloat(120 + ring * 60), height: CGFloat(120 + ring * 60))
                    .scaleEffect(animate ? 1.0 : 0.3)
                    .opacity(animate ? 1.0 : 0.0)
                    .animation(
                        .easeOut(duration: 1.0)
                        .delay(Double(ring) * 0.2),
                        value: animate
                    )
            }
        }
    }
}

// MARK: - Premium Target Line
struct PremiumTargetLine: View {
    let isRightHanded: Bool
    let animate: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Target line with gradient
            Path { path in
                let centerY = geometry.size.height / 2 + 40
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        .clear,
                        .yellow.opacity(0.8),
                        .orange.opacity(0.6),
                        .yellow.opacity(0.8),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .shadow(color: .yellow.opacity(0.5), radius: 6)
            .scaleEffect(x: animate ? 1.0 : 0.0, y: 1.0, anchor: .center)
            .animation(.easeOut(duration: 1.2), value: animate)
            
            // Directional arrows
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
            }
            .padding(.horizontal, 40)
            .offset(y: 40)
            .opacity(animate ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.8).delay(0.5), value: animate)
        }
    }
}

// MARK: - Premium Swing Plane
struct PremiumSwingPlane: View {
    let isRightHanded: Bool
    let animate: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Swing plane arc
            Path { path in
                let center = CGPoint(x: geometry.size.width/2, y: geometry.size.height/2 + 60)
                let radius: CGFloat = 150
                let startAngle = isRightHanded ? -120.0 : -60.0
                let endAngle = isRightHanded ? -60.0 : -120.0
                
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
            }
            .stroke(
                LinearGradient(
                    colors: [
                        .blue.opacity(0.8),
                        .cyan.opacity(0.6),
                        .blue.opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 4])
            )
            .shadow(color: .blue.opacity(0.5), radius: 6)
            .opacity(animate ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 1.5), value: animate)
            
            // Swing plane angle indicator
            VStack {
                Spacer()
                HStack {
                    if !isRightHanded { Spacer() }
                    
                    VStack(spacing: 4) {
                        Text("45°")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.5), radius: 3)
                        
                        Text("OPTIMAL PLANE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.cyan.opacity(0.5), .clear],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .offset(x: isRightHanded ? -40 : 40, y: -60)
                    .opacity(animate ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: animate)
                    
                    if isRightHanded { Spacer() }
                }
                .padding(.bottom, 160)
            }
        }
    }
}

// MARK: - Premium Golfer Template
struct PremiumGolferTemplate: View {
    let isRightHanded: Bool
    let animate: Bool
    let pulseGlow: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        RadialGradient(
                            colors: [
                                .green.opacity(pulseGlow ? 0.4 : 0.2),
                                .mint.opacity(pulseGlow ? 0.2 : 0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 140, height: 180)
                    .scaleEffect(pulseGlow ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseGlow)
                
                // Sophisticated golfer silhouette
                VStack(spacing: 12) {
                    // Head with premium styling
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .mint.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: .green.opacity(0.5), radius: 6)
                        
                        // Golf cap indicator
                        Ellipse()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 24, height: 8)
                            .offset(y: -2)
                    }
                    .scaleEffect(animate ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animate)
                    
                    // Premium body with sophisticated design
                    ZStack {
                        // Body outline with glassmorphism
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(width: 90, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .green.opacity(0.8),
                                                .mint.opacity(0.4),
                                                .green.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .green.opacity(0.3), radius: 8)
                        
                        VStack(spacing: 8) {
                            // Shoulder indicators with handedness
                            HStack(spacing: isRightHanded ? 12 : -12) {
                                if isRightHanded {
                                    // Right-handed shoulder positioning
                                    PremiumShoulderIndicator(isLeading: false, isRightHanded: true)
                                    PremiumShoulderIndicator(isLeading: true, isRightHanded: true)
                                } else {
                                    // Left-handed shoulder positioning
                                    PremiumShoulderIndicator(isLeading: true, isRightHanded: false)
                                    PremiumShoulderIndicator(isLeading: false, isRightHanded: false)
                                }
                            }
                            .padding(.top, 12)
                            
                            Spacer()
                            
                            // Premium golf club with physics
                            PremiumGolfClub(isRightHanded: isRightHanded, animate: animate)
                            
                            Spacer()
                        }
                    }
                    .scaleEffect(animate ? 1.0 : 0.0)
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.4), value: animate)
                    
                    // Premium stance indicators
                    HStack(spacing: 24) {
                        if isRightHanded {
                            PremiumFootIndicator(foot: "R", isBack: true)
                            PremiumFootIndicator(foot: "L", isBack: false)
                        } else {
                            PremiumFootIndicator(foot: "L", isBack: true)
                            PremiumFootIndicator(foot: "R", isBack: false)
                        }
                    }
                    .scaleEffect(animate ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6), value: animate)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Premium Shoulder Indicator
struct PremiumShoulderIndicator: View {
    let isLeading: Bool
    let isRightHanded: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isLeading ? .green.opacity(0.8) : .green.opacity(0.5),
                            isLeading ? .mint.opacity(0.4) : .mint.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 8
                    )
                )
                .frame(width: isLeading ? 18 : 16, height: isLeading ? 18 : 16)
                .overlay(
                    Circle()
                        .stroke(
                            Color.green.opacity(isLeading ? 1.0 : 0.6),
                            lineWidth: 2
                        )
                )
                .shadow(color: .green.opacity(0.4), radius: 4)
            
            Text(isRightHanded ? (isLeading ? "R" : "L") : (isLeading ? "L" : "R"))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Premium Golf Club
struct PremiumGolfClub: View {
    let isRightHanded: Bool
    let animate: Bool
    @State private var clubGlow = false
    
    var body: some View {
        ZStack {
            // Club shaft with premium gradient
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            .gray.opacity(0.9),
                            .white.opacity(0.8),
                            .gray.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 80)
                .rotationEffect(.degrees(isRightHanded ? -25 : 25))
                .offset(x: isRightHanded ? 15 : -15)
                .shadow(color: .black.opacity(0.3), radius: 2)
            
            // Club head
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.gray, .white, .gray],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(isRightHanded ? -25 : 25))
                .offset(
                    x: isRightHanded ? 35 : -35,
                    y: 35
                )
                .shadow(color: .black.opacity(0.3), radius: 3)
            
            // Grip highlight
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.green.opacity(0.8))
                .frame(width: 4, height: 16)
                .rotationEffect(.degrees(isRightHanded ? -25 : 25))
                .offset(
                    x: isRightHanded ? 5 : -5,
                    y: -32
                )
                .shadow(color: .green.opacity(clubGlow ? 0.8 : 0.3), radius: clubGlow ? 6 : 2)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: clubGlow)
        }
        .onAppear {
            clubGlow = true
        }
    }
}

// MARK: - Premium Foot Indicator
struct PremiumFootIndicator: View {
    let foot: String
    let isBack: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(foot)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: .green.opacity(0.3), radius: 4)
            
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .green.opacity(isBack ? 0.6 : 0.9),
                            .mint.opacity(isBack ? 0.3 : 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isBack ? 20 : 24, height: 10)
                .overlay(
                    Ellipse()
                        .stroke(
                            Color.green.opacity(isBack ? 0.7 : 1.0),
                            lineWidth: 2
                        )
                )
                .shadow(color: .green.opacity(0.4), radius: 4)
        }
    }
}

// MARK: - Premium Ball Position
struct PremiumBallPosition: View {
    let isRightHanded: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                if isRightHanded {
                    Spacer()
                }
                
                ZStack {
                    // Ball glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.8),
                                    .yellow.opacity(0.4),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    // Golf ball with realistic styling
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .gray.opacity(0.1)],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 8
                            )
                        )
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 2)
                    
                    // Ball position label
                    VStack {
                        Text("⚪")
                            .font(.title3)
                        Text("BALL")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    .offset(y: -35)
                }
                .offset(x: isRightHanded ? -40 : 40, y: -20)
                
                if !isRightHanded {
                    Spacer()
                }
            }
            .padding(.bottom, 140)
        }
    }
}

// MARK: - Premium HUD Elements
struct PremiumHUDElements: View {
    let isRightHanded: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            // Top HUD
            HStack {
                // Camera position with premium styling
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.8), .cyan.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("CAMERA")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Text("6-8 FEET")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Spacer()
                
                // Target direction with premium styling
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.orange.opacity(0.8), .red.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .orange.opacity(0.3), radius: 8)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "target")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("TARGET")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                        Text("AIM")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 80)
            
            Spacer()
            
            // Bottom HUD - Handedness and Setup Info
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        // Handedness indicator
                        HStack(spacing: 6) {
                            Text(isRightHanded ? "R" : "L")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .green.opacity(0.5), radius: 6)
                                )
                            
                            Text(isRightHanded ? "RIGHT HANDED" : "LEFT HANDED")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Setup quality indicator
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index < 4 ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        
                        Text("SETUP QUALITY")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green.opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10)
                )
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, 200)
        }
    }
}

// MARK: - Premium Coaching Indicators
struct PremiumCoachingIndicators: View {
    let isRightHanded: Bool
    let sequence: Int
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Animated coaching arrows
            if sequence == 0 {
                CoachingArrow(
                    direction: .down,
                    text: "ALIGN FEET",
                    color: .green,
                    position: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2 + 120)
                )
            } else if sequence == 1 {
                CoachingArrow(
                    direction: .right,
                    text: "SHOULDER POSITION",
                    color: .blue,
                    position: CGPoint(x: geometry.size.width/2 - 60, y: geometry.size.height/2 - 20)
                )
            } else if sequence == 2 {
                CoachingArrow(
                    direction: .diagonalDown,
                    text: "CLUB ANGLE",
                    color: .orange,
                    position: CGPoint(x: geometry.size.width/2 + (isRightHanded ? 40 : -40), y: geometry.size.height/2 + 40)
                )
            } else if sequence == 3 {
                CoachingArrow(
                    direction: .up,
                    text: "PERFECT STANCE",
                    color: .green,
                    position: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2 + 80)
                )
            }
        }
    }
}

// MARK: - Coaching Arrow
struct CoachingArrow: View {
    enum Direction {
        case up, down, left, right, diagonalDown
    }
    
    let direction: Direction
    let text: String
    let color: Color
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 8) {
            // Arrow icon
            Image(systemName: arrowIcon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: color.opacity(0.5), radius: 6)
            
            // Text label
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8)
                )
        }
        .position(position)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    private var arrowIcon: String {
        switch direction {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .left: return "arrow.left.circle.fill"
        case .right: return "arrow.right.circle.fill"
        case .diagonalDown: return "arrow.down.right.circle.fill"
        }
    }
}

// MARK: - Swing Setup Instructions
struct SwingSetupInstructions: View {
    @Binding var isRightHanded: Bool
    @Binding var showAlignmentOverlay: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("📱 Golf Setup Guide")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Handedness toggle
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRightHanded = true
                                }
                            }) {
                                Text("Right")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isRightHanded ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isRightHanded ? Color.green : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRightHanded = false
                                }
                            }) {
                                Text("Left")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(!isRightHanded ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(!isRightHanded ? Color.green : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Overlay Toggle
                        HStack(spacing: 12) {
                            Text("Show Guide:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showAlignmentOverlay.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showAlignmentOverlay ? "eye" : "eye.slash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(showAlignmentOverlay ? "ON" : "OFF")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(showAlignmentOverlay ? .green : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(showAlignmentOverlay ? .green.opacity(0.2) : .gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(showAlignmentOverlay ? .green : .gray, lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        // Key Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Position camera 6-8 feet away at waist height")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Stand sideways to camera in the template")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                if isRightHanded {
                                    Text("Right foot back, left foot forward")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                } else {
                                    Text("Left foot back, right foot forward")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 80)
    }
}

// MARK: - Camera Angle Result View (NEW Multi-Angle Enhancement)
struct CameraAngleResultView: View {
    let result: CameraAngleResponse
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: iconForAngle(result.camera_angle))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(colorForStatus(result.guidance.status))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera Angle: \(result.camera_angle.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Confidence: \(Int(result.confidence * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                Text(result.guidance.status.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorForStatus(result.guidance.status).opacity(0.2))
                    )
                    .foregroundColor(colorForStatus(result.guidance.status))
            }
            
            // Guidance Message
            VStack(alignment: .leading, spacing: 12) {
                Text(result.guidance.message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Recommendations
                if !result.guidance.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendations:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(result.guidance.recommendations, id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                    .padding(.top, 2)
                                
                                Text(recommendation)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func iconForAngle(_ angle: String) -> String {
        switch angle {
        case "side_on":
            return "camera.aperture"
        case "front_on":
            return "camera.circle"
        case "behind":
            return "camera.circle.fill"
        case "angled_side", "angled_front":
            return "camera.rotate"
        case "overhead":
            return "camera.metering.center.weighted"
        default:
            return "camera.viewfinder"
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "excellent":
            return .green
        case "good":
            return .blue
        case "fair":
            return .orange
        case "poor", "unknown":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    SwingAnalysisView()
        .environmentObject(AuthenticationManager())
}
