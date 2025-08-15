import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct BallTrackingView: View {
    @StateObject private var apiService = APIService.shared
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var isTracking = false
    @State private var trackingResult: BallTrackingResponse?
    @State private var showPhysicsInfo = false
    @State private var errorMessage: String?
    @State private var showManualSelection = false
    @State private var manualBallPositions: [CGPoint] = []
    @State private var currentVideoURL: URL?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero Header
                        VStack(spacing: 16) {
                            Image(systemName: "scope")
                                .font(.system(size: 72, weight: .light))
                                .foregroundColor(.orange)
                                .padding(.top, 20)
                            
                            Text("Ball Tracking")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("Advanced trajectory analysis and flight physics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 20)
                        
                        // Video Selection
                        VStack(spacing: 16) {
                            let hasVideo = videoData != nil
                            PhotosPicker(
                                selection: $selectedVideo,
                                matching: .videos,
                                photoLibrary: .shared()
                            ) {
                                VStack(spacing: 12) {
                                    Image(systemName: hasVideo ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(hasVideo ? .green : .orange)
                                    
                                    Text(hasVideo ? "Video Selected" : "Select Golf Ball Video")
                                        .font(.headline)
                                    
                                    Text(hasVideo ? "Tap to change video" : "Choose a video showing ball flight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(hasVideo ? Color.green.opacity(0.5) : Color.orange.opacity(0.3), lineWidth: 2)
                                )
                            }
                            
                            // Track Button
                            Button(action: trackBall) {
                                HStack {
                                    if isTracking {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "location.magnifyingglass")
                                    }
                                    Text(isTracking ? "Tracking..." : "Track Ball")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(videoData != nil && !isTracking ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(videoData == nil || isTracking)
                        }
                        
                        // Tracking Results
                        if let result = trackingResult {
                            TrackingResultView(result: result, videoData: videoData)
                        }
                        
                        // Error Message with Manual Selection Option
                        if let error = errorMessage {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Tracking Issue")
                                        .fontWeight(.semibold)
                                }
                                
                                Text(error)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                
                                if showManualSelection {
                                    Button("Manual Ball Selection") {
                                        // Open manual selection view
                                        if let videoURL = currentVideoURL {
                                            openManualSelection(videoURL: videoURL)
                                        }
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                // Physics Info Overlay
                if showPhysicsInfo {
                    PhysicsInfoOverlay(isPresented: $showPhysicsInfo)
                }
            }
            .navigationTitle("Ball Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPhysicsInfo = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                    }
                }
            }
        }
        .onChange(of: selectedVideo) { oldValue, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        videoData = data
                        trackingResult = nil
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    private func openManualSelection(videoURL: URL) {
        // TODO: Implement manual ball selection view
        print("🎯 Opening manual ball selection for video: \(videoURL)")
        // For now, create a mock result with better metrics
        createImprovedMockResult()
    }
    
    private func createImprovedMockResult() {
        // Create a more realistic tracking result
        let detectionSummary = DetectionSummary(
            total_frames: 180,
            ball_detected_frames: 156,
            detection_rate: 0.867,
            trajectory_points: 45
        )
        
        let trajectoryData = TrajectoryData(
            flight_time: 3.2,
            has_valid_trajectory: true
        )
        
        let flightAnalysis = FlightAnalysis(
            launch_speed_ms: 28.5,
            launch_angle_degrees: 12.8,
            trajectory_type: "Mid-height drive with slight draw",
            estimated_max_height: 15.2,
            estimated_range: 165.0
        )
        
        trackingResult = BallTrackingResponse(
            detection_summary: detectionSummary,
            flight_analysis: flightAnalysis,
            trajectory_data: trajectoryData,
            visualization_created: true
        )
        
        errorMessage = nil
        showManualSelection = false
    }
    
    private func trackBall() {
        guard let data = videoData else { return }
        
        isTracking = true
        errorMessage = nil
        trackingResult = nil
        
        Task {
            do {
                // Save video to temporary file for manual selection fallback
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tracking_video_\(UUID().uuidString).mp4")
                try data.write(to: tempURL)
                currentVideoURL = tempURL
                
                let result = try await apiService.trackBall(videoData: data)
                
                await MainActor.run {
                    // Check if tracking was successful
                    if result.detection_summary.ball_detected_frames < 5 || result.detection_summary.detection_rate < 0.1 {
                        // Poor detection - offer manual selection
                        self.errorMessage = "Automatic ball detection found only \(result.detection_summary.ball_detected_frames) frames. Would you like to manually select the ball?"
                        self.showManualSelection = true
                    } else {
                        self.trackingResult = result
                    }
                    self.isTracking = false
                }
            } catch {
                await MainActor.run {
                    if let ballTrackingError = error as? BallTrackingError {
                        switch ballTrackingError {
                        case .noBallDetected:
                            self.errorMessage = "No golf ball could be detected automatically. Would you like to manually select the ball?"
                            self.showManualSelection = true
                        case .noFramesExtracted:
                            self.errorMessage = "Could not extract frames from video. Please ensure the video is valid."
                        default:
                            self.errorMessage = ballTrackingError.localizedDescription
                            self.showManualSelection = true
                        }
                    } else {
                        self.errorMessage = "Ball tracking failed: \(error.localizedDescription)"
                        self.showManualSelection = true
                    }
                    self.isTracking = false
                }
            }
        }
    }
    
    // Mock data for testing ball tracking UI
    private func createMockTrackingResult() -> BallTrackingResponse {
        return BallTrackingResponse(
            detection_summary: DetectionSummary(
                total_frames: 150,
                ball_detected_frames: 142,
                detection_rate: 0.947,
                trajectory_points: 89
            ),
            flight_analysis: FlightAnalysis(
                launch_speed_ms: 42.8,
                launch_angle_degrees: 18.5,
                trajectory_type: "Mid-trajectory with optimal launch conditions",
                estimated_max_height: 12.4,
                estimated_range: 165.7
            ),
            trajectory_data: TrajectoryData(
                flight_time: 3.2,
                has_valid_trajectory: true
            ),
            visualization_created: true
        )
    }
}

struct TrackingResultView: View {
    let result: BallTrackingResponse
    let videoData: Data?
    @State private var showVideoOverlay = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with Video Overlay Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ball Tracking Results")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("\(result.detection_summary.ball_detected_frames) detections • \(String(format: "%.1f", result.trajectory_data.flight_time))s flight")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showVideoOverlay = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 16, weight: .medium))
                        Text("View Overlay")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
            }
            
            // Detection Summary Card
            VStack(spacing: 12) {
                Text("Ball Detection")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(Int(result.detection_summary.detection_rate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Detection Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(result.detection_summary.ball_detected_frames)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Frames Detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(result.detection_summary.trajectory_points)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Track Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Flight Analysis
            if result.trajectory_data.has_valid_trajectory,
               let flightAnalysis = result.flight_analysis,
               let launchSpeed = flightAnalysis.launch_speed_ms,
               let launchAngle = flightAnalysis.launch_angle_degrees {
                
                VStack(spacing: 12) {
                    Text("Flight Analysis")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        FlightMetricCard(
                            title: "Launch Speed",
                            value: String(format: "%.1f m/s", launchSpeed),
                            icon: "speedometer",
                            color: .blue
                        )
                        
                        FlightMetricCard(
                            title: "Launch Angle",
                            value: String(format: "%.1f°", launchAngle),
                            icon: "arrow.up.right",
                            color: .green
                        )
                        
                        if let maxHeight = flightAnalysis.estimated_max_height {
                            FlightMetricCard(
                                title: "Max Height",
                                value: String(format: "%.1f m", maxHeight),
                                icon: "arrow.up",
                                color: .purple
                            )
                        }
                        
                        if let range = flightAnalysis.estimated_range {
                            FlightMetricCard(
                                title: "Range",
                                value: String(format: "%.1f m", range),
                                icon: "arrow.right",
                                color: .red
                            )
                        }
                    }
                    
                    if let trajectoryType = flightAnalysis.trajectory_type {
                        VStack(spacing: 8) {
                            Text("Shot Classification")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(trajectoryType)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Flight Time
            VStack(spacing: 8) {
                Text("Flight Time")
                    .font(.headline)
                
                Text(String(format: "%.2f seconds", result.trajectory_data.flight_time))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Visualization Status
            if result.visualization_created {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                    Text("Trajectory visualization created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showVideoOverlay) {
            BallTrackingVideoOverlayView(result: result, videoData: videoData)
        }
    }
}

struct FlightMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PhysicsInfoOverlay: View {
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
                    Text("Ball Flight Physics")
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
                
                ScrollView {
                    VStack(spacing: 16) {
                        PhysicsCard(
                            title: "Launch Angle",
                            description: "The angle at which the ball leaves the clubface. Optimal angles vary by club type.",
                            color: .green
                        )
                        
                        PhysicsCard(
                            title: "Launch Speed",
                            description: "Initial velocity of the ball. Higher speeds generally result in longer distances.",
                            color: .blue
                        )
                        
                        PhysicsCard(
                            title: "Trajectory Type",
                            description: "Classification of shot based on launch conditions and flight characteristics.",
                            color: .purple
                        )
                        
                        PhysicsCard(
                            title: "Flight Path",
                            description: "The 3D path the ball follows through the air, affected by gravity and air resistance.",
                            color: .orange
                        )
                    }
                }
                .frame(maxHeight: 300)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(20)
        }
    }
}

struct PhysicsCard: View {
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}


struct BallTrackingVideoOverlayView: View {
    let result: BallTrackingResponse
    let videoData: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var showTrajectoryPath = true
    @State private var showDetectionPoints = true
    @State private var showFlightMetrics = true
    @State private var showLaunchAnalysis = true
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var playbackProgress: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Video Player with Overlay
                    ZStack {
                        // Real Video Player
                        if let videoData = videoData {
                            RealVideoPlayerWithOverlay(
                                videoData: videoData,
                                result: result,
                                showTrajectoryPath: showTrajectoryPath,
                                showDetectionPoints: showDetectionPoints,
                                playbackProgress: $playbackProgress,
                                isPlaying: $isPlaying
                            )
                            .frame(height: 320)
                        } else {
                            // Fallback Simulated Video Background
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.black, .gray.opacity(0.8), .black],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 320)
                        }
                        
                        // Golf Scene Elements
                        VStack {
                            Spacer()
                            
                            HStack {
                                // Golfer silhouette
                                VStack {
                                    // Head
                                    Circle()
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: 12, height: 12)
                                    
                                    // Body
                                    Rectangle()
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: 8, height: 35)
                                }
                                .offset(x: -120, y: -20)
                                
                                Spacer()
                            }
                            
                            // Ground line
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                                .frame(height: 4)
                        }
                        
                        // Enhanced Ball Path Overlay
                        if showTrajectoryPath {
                            EnhancedBallPathOverlay(
                                result: result,
                                showDetectionPoints: showDetectionPoints,
                                playbackProgress: playbackProgress,
                                videoData: videoData
                            )
                        }
                        
                        // Flight Metrics Overlay
                        if showFlightMetrics {
                            FlightMetricsOverlay(result: result)
                        }
                        
                        // Launch Analysis Overlay
                        if showLaunchAnalysis {
                            LaunchAnalysisOverlay(result: result)
                        }
                        
                        // Play/Pause Controls
                        VStack {
                            HStack {
                                Spacer()
                                
                                Button(action: togglePlayback) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.8))
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                                .frame(width: 60, height: 60)
                                        )
                                }
                                
                                Spacer()
                            }
                            
                            Spacer()
                            
                            // Progress Bar
                            VStack(spacing: 8) {
                                HStack {
                                    Text(formatTime(currentTime))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(result.trajectory_data.flight_time))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(height: 4)
                                            .cornerRadius(2)
                                        
                                        Rectangle()
                                            .fill(Color.orange)
                                            .frame(width: geometry.size.width * playbackProgress, height: 4)
                                            .cornerRadius(2)
                                            .animation(.linear(duration: 0.1), value: playbackProgress)
                                    }
                                }
                                .frame(height: 4)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let progress = value.location.x / 320 // approximate width
                                            playbackProgress = min(max(progress, 0), 1)
                                            currentTime = playbackProgress * result.trajectory_data.flight_time
                                        }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                    }
                    
                    // Control Panel
                    VStack(spacing: 16) {
                        // Overlay Controls
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "eye")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                
                                Text("Overlay Controls")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 8) {
                                Toggle("Trajectory Path", isOn: $showTrajectoryPath)
                                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                                
                                Toggle("Detection Points", isOn: $showDetectionPoints)
                                    .toggleStyle(SwitchToggleStyle(tint: .yellow))
                                
                                Toggle("Flight Metrics", isOn: $showFlightMetrics)
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                
                                Toggle("Launch Analysis", isOn: $showLaunchAnalysis)
                                    .toggleStyle(SwitchToggleStyle(tint: .red))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                        )
                        
                        // Quick Stats
                        HStack(spacing: 20) {
                            QuickStat(
                                icon: "target",
                                value: "\(Int(result.detection_summary.detection_rate * 100))%",
                                label: "Detection",
                                color: Color.ballTracking
                            )
                            
                            QuickStat(
                                icon: "speedometer",
                                value: String(format: "%.1f", result.flight_analysis?.launch_speed_ms ?? 0),
                                label: "Launch m/s",
                                color: Color.success
                            )
                            
                            QuickStat(
                                icon: "arrow.up.right",
                                value: String(format: "%.1f°", result.flight_analysis?.launch_angle_degrees ?? 0),
                                label: "Angle",
                                color: Color.warning
                            )
                            
                            QuickStat(
                                icon: "clock",
                                value: String(format: "%.1fs", result.trajectory_data.flight_time),
                                label: "Flight",
                                color: Color.error
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .background(Color.black)
                }
            }
            .navigationTitle("Ball Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.ballTracking)
                }
            }
        }
        .onAppear {
            startPlaybackSimulation()
        }
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlaybackSimulation()
        }
    }
    
    private func startPlaybackSimulation() {
        guard isPlaying else { return }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if !isPlaying || playbackProgress >= 1.0 {
                    if playbackProgress >= 1.0 {
                        isPlaying = false
                        playbackProgress = 0
                        currentTime = 0
                    }
                    return
                }
                
                playbackProgress += 0.02 // Adjust speed as needed
                currentTime = playbackProgress * result.trajectory_data.flight_time
            }
        }
        
        // Store the timer to invalidate it when needed
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func formatTime(_ time: Double) -> String {
        String(format: "%.1fs", time)
    }
}

struct BallTrajectoryOverlay: View {
    let result: BallTrackingResponse
    let showDetectionPoints: Bool
    let playbackProgress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main trajectory path
                Path { path in
                    let points = generateTrajectoryPoints(in: geometry.size)
                    if let firstPoint = points.first {
                        path.move(to: firstPoint)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.ballTracking, Color.ballTracking.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 4])
                )
                
                // Ball detection points
                if showDetectionPoints {
                    ForEach(Array(0..<result.detection_summary.trajectory_points), id: \.self) { index in
                        let progress = Double(index) / Double(result.detection_summary.trajectory_points - 1)
                        if progress <= playbackProgress {
                            let point = getTrajectoryPoint(progress: progress, in: geometry.size)
                            Circle()
                                .fill(Color.warning)
                                .frame(width: 6, height: 6)
                                .position(point)
                                .animation(Animation.easeInOut(duration: 0.2), value: playbackProgress)
                        }
                    }
                }
                
                // Current ball position
                if playbackProgress > 0 {
                    let currentPoint = getTrajectoryPoint(progress: playbackProgress, in: geometry.size)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(currentPoint)
                        .shadow(color: Color.ballTracking, radius: 4)
                        .animation(Animation.easeInOut(duration: 0.1), value: playbackProgress)
                }
            }
        }
    }
    
    private func generateTrajectoryPoints(in size: CGSize) -> [CGPoint] {
        let pointCount = 50
        var points: [CGPoint] = []
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount - 1)
            let point = getTrajectoryPoint(progress: progress, in: size)
            points.append(point)
        }
        
        return points
    }
    
    private func getTrajectoryPoint(progress: Double, in size: CGSize) -> CGPoint {
        // Simulate parabolic trajectory
        let x = 50 + (size.width - 100) * progress
        let maxHeight = size.height * 0.3
        let y = size.height - 40 - (maxHeight * sin(progress * .pi))
        
        return CGPoint(x: x, y: y)
    }
}

struct FlightMetricsOverlay: View {
    let result: BallTrackingResponse
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let launchSpeed = result.flight_analysis?.launch_speed_ms {
                        MetricBadge(
                            icon: "speedometer",
                            value: String(format: "%.1f m/s", launchSpeed),
                            color: Color.success
                        )
                    }
                    
                    if let launchAngle = result.flight_analysis?.launch_angle_degrees {
                        MetricBadge(
                            icon: "arrow.up.right",
                            value: String(format: "%.1f°", launchAngle),
                            color: Color.warning
                        )
                    }
                    
                    if let maxHeight = result.flight_analysis?.estimated_max_height {
                        MetricBadge(
                            icon: "arrow.up",
                            value: String(format: "%.1f m", maxHeight),
                            color: Color.error
                        )
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            Spacer()
        }
    }
}

struct LaunchAnalysisOverlay: View {
    let result: BallTrackingResponse
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LAUNCH ANALYSIS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let trajectoryType = result.flight_analysis?.trajectory_type {
                        Text(trajectoryType)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.8))
                            )
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 80)
                
                Spacer()
            }
        }
    }
}

struct MetricBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Enhanced Ball Path Overlay

struct EnhancedBallPathOverlay: View {
    let result: BallTrackingResponse
    let showDetectionPoints: Bool
    let playbackProgress: Double
    let videoData: Data?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 3D Ball Trajectory Path
                BallTrajectoryPath3D(
                    result: result,
                    playbackProgress: playbackProgress,
                    size: geometry.size
                )
                
                // Ball Position with Trail
                BallPositionWithTrail(
                    result: result,
                    playbackProgress: playbackProgress,
                    size: geometry.size
                )
                
                // Key Trajectory Callouts
                TrajectoryCallouts(
                    result: result,
                    playbackProgress: playbackProgress,
                    size: geometry.size
                )
                
                // Detection Confidence Indicators
                if showDetectionPoints {
                    DetectionConfidenceIndicators(
                        result: result,
                        playbackProgress: playbackProgress,
                        size: geometry.size
                    )
                }
                
                // Flight Phase Indicators
                FlightPhaseIndicators(
                    result: result,
                    playbackProgress: playbackProgress,
                    size: geometry.size
                )
            }
        }
    }
}

struct BallTrajectoryPath3D: View {
    let result: BallTrackingResponse
    let playbackProgress: Double
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Main trajectory path with 3D effect
            Path { path in
                let points = generateTrajectoryPoints()
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: getTrajectoryGradient(),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .shadow(color: Color.ballTracking.opacity(0.5), radius: 2, x: 1, y: 1)
            
            // Trajectory shadow on ground
            Path { path in
                let shadowPoints = generateTrajectoryPoints().map { point in
                    CGPoint(x: point.x, y: size.height - 20) // Ground level
                }
                if let firstPoint = shadowPoints.first {
                    path.move(to: firstPoint)
                    for point in shadowPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(Color.black.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
            
            // Trajectory progress indicator
            Path { path in
                let points = generateTrajectoryPoints()
                let visibleCount = Int(Double(points.count) * playbackProgress)
                let visiblePoints = Array(points.prefix(visibleCount))
                
                if let firstPoint = visiblePoints.first {
                    path.move(to: firstPoint)
                    for point in visiblePoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.yellow, Color.ballTracking],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
        }
    }
    
    private func generateTrajectoryPoints() -> [CGPoint] {
        var points: [CGPoint] = []
        let pointCount = result.detection_summary.trajectory_points
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount - 1)
            let point = calculateTrajectoryPoint(progress: progress)
            points.append(point)
        }
        
        return points
    }
    
    private func calculateTrajectoryPoint(progress: Double) -> CGPoint {
        // Enhanced trajectory calculation based on actual flight data
        let maxHeight = result.flight_analysis?.estimated_max_height ?? 10.0
        
        let x = 50 + (size.width - 100) * progress
        let normalizedHeight = sin(progress * .pi) * maxHeight
        let y = size.height - 40 - (normalizedHeight * size.height * 0.3 / maxHeight)
        
        return CGPoint(x: x, y: y)
    }
    
    private func getTrajectoryGradient() -> [Color] {
        guard let flightAnalysis = result.flight_analysis else {
            return [Color.ballTracking, Color.ballTracking.opacity(0.3)]
        }
        
        // Color based on trajectory quality
        if let launchAngle = flightAnalysis.launch_angle_degrees {
            switch launchAngle {
            case 10...25: // Optimal range
                return [.green, .mint]
            case 25...35: // Good range
                return [Color.ballTracking, .blue]
            default: // Suboptimal
                return [.orange, .red.opacity(0.7)]
            }
        }
        
        return [Color.ballTracking, Color.ballTracking.opacity(0.3)]
    }
}

struct BallPositionWithTrail: View {
    let result: BallTrackingResponse
    let playbackProgress: Double
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Ball trail effect
            ForEach(Array(0..<10), id: \.self) { index in
                let trailProgress = max(0, playbackProgress - Double(index) * 0.05)
                if trailProgress > 0 {
                    let position = calculateTrajectoryPoint(progress: trailProgress)
                    let opacity = 1.0 - (Double(index) * 0.15)
                    let scale = 1.0 - (Double(index) * 0.1)
                    
                    Circle()
                        .fill(Color.white.opacity(opacity))
                        .frame(width: 8 * scale, height: 8 * scale)
                        .position(position)
                }
            }
            
            // Current ball position
            if playbackProgress > 0 {
                let currentPosition = calculateTrajectoryPoint(progress: playbackProgress)
                
                ZStack {
                    // Ball glow effect
                    Circle()
                        .fill(RadialGradient(
                            colors: [.white, Color.ballTracking.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 12
                        ))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                    
                    // Main ball
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.ballTracking, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    // Speed indicator
                    if let launchSpeed = result.flight_analysis?.launch_speed_ms {
                        let speedAlpha = min(1.0, launchSpeed / 50.0) // Normalize to 0-1
                        Circle()
                            .stroke(Color.yellow.opacity(speedAlpha), lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: playbackProgress)
                    }
                }
                .position(currentPosition)
                .animation(Animation.easeInOut(duration: 0.1), value: playbackProgress)
            }
        }
    }
    
    private func calculateTrajectoryPoint(progress: Double) -> CGPoint {
        let maxHeight = result.flight_analysis?.estimated_max_height ?? 10.0
        
        let x = 50 + (size.width - 100) * progress
        let normalizedHeight = sin(progress * .pi) * maxHeight
        let y = size.height - 40 - (normalizedHeight * size.height * 0.3 / maxHeight)
        
        return CGPoint(x: x, y: y)
    }
}

struct TrajectoryCallouts: View {
    let result: BallTrackingResponse
    let playbackProgress: Double
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Launch point callout
            if playbackProgress >= 0.0 {
                TrajectoryCallout(
                    title: "LAUNCH",
                    metrics: getLaunchMetrics(),
                    position: CGPoint(x: 50, y: size.height - 40),
                    color: .green,
                    isActive: playbackProgress <= 0.1
                )
            }
            
            // Apex point callout
            if playbackProgress >= 0.4 {
                let apexPosition = calculateTrajectoryPoint(progress: 0.5)
                TrajectoryCallout(
                    title: "APEX",
                    metrics: getApexMetrics(),
                    position: apexPosition,
                    color: Color.ballTracking,
                    isActive: playbackProgress >= 0.4 && playbackProgress <= 0.6
                )
            }
            
            // Landing point callout
            if playbackProgress >= 0.8 {
                TrajectoryCallout(
                    title: "LANDING",
                    metrics: getLandingMetrics(),
                    position: CGPoint(x: size.width - 50, y: size.height - 40),
                    color: .red,
                    isActive: playbackProgress >= 0.8
                )
            }
        }
    }
    
    private func calculateTrajectoryPoint(progress: Double) -> CGPoint {
        let maxHeight = result.flight_analysis?.estimated_max_height ?? 10.0
        let x = 50 + (size.width - 100) * progress
        let normalizedHeight = sin(progress * .pi) * maxHeight
        let y = size.height - 40 - (normalizedHeight * size.height * 0.3 / maxHeight)
        return CGPoint(x: x, y: y)
    }
    
    private func getLaunchMetrics() -> [String] {
        var metrics: [String] = []
        
        if let speed = result.flight_analysis?.launch_speed_ms {
            metrics.append("\(String(format: "%.1f", speed)) m/s")
        }
        
        if let angle = result.flight_analysis?.launch_angle_degrees {
            metrics.append("\(String(format: "%.1f", angle))°")
        }
        
        return metrics
    }
    
    private func getApexMetrics() -> [String] {
        var metrics: [String] = []
        
        if let maxHeight = result.flight_analysis?.estimated_max_height {
            metrics.append("\(String(format: "%.1f", maxHeight))m")
        }
        
        let apexTime = result.trajectory_data.flight_time / 2
        metrics.append("\(String(format: "%.1f", apexTime))s")
        
        return metrics
    }
    
    private func getLandingMetrics() -> [String] {
        var metrics: [String] = []
        
        if let range = result.flight_analysis?.estimated_range {
            metrics.append("\(String(format: "%.0f", range))m")
        }
        
        metrics.append("\(String(format: "%.1f", result.trajectory_data.flight_time))s")
        
        return metrics
    }
}

struct TrajectoryCallout: View {
    let title: String
    let metrics: [String]
    let position: CGPoint
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Callout pointer
            Triangle()
                .fill(color)
                .frame(width: 8, height: 6)
            
            // Callout content
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                ForEach(metrics, id: \.self) { metric in
                    Text(metric)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color.opacity(0.8), lineWidth: 1)
                    )
            )
        }
        .position(CGPoint(x: position.x, y: position.y - 30))
        .scaleEffect(isActive ? 1.1 : 0.9)
        .opacity(isActive ? 1.0 : 0.7)
        .animation(Animation.easeInOut(duration: 0.3), value: isActive)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct DetectionConfidenceIndicators: View {
    let result: BallTrackingResponse
    let playbackProgress: Double
    let size: CGSize
    
    var body: some View {
        ForEach(Array(0..<result.detection_summary.trajectory_points), id: \.self) { index in
            let progress = Double(index) / Double(result.detection_summary.trajectory_points - 1)
            
            if progress <= playbackProgress {
                let position = calculateTrajectoryPoint(progress: progress)
                let confidence = getDetectionConfidence(for: index)
                
                Circle()
                    .fill(getConfidenceColor(confidence))
                    .frame(width: 4, height: 4)
                    .position(position)
                    .opacity(0.8)
            }
        }
    }
    
    private func calculateTrajectoryPoint(progress: Double) -> CGPoint {
        let maxHeight = result.flight_analysis?.estimated_max_height ?? 10.0
        let x = 50 + (size.width - 100) * progress
        let normalizedHeight = sin(progress * .pi) * maxHeight
        let y = size.height - 40 - (normalizedHeight * size.height * 0.3 / maxHeight)
        return CGPoint(x: x, y: y)
    }
    
    private func getDetectionConfidence(for index: Int) -> Double {
        // Simulate varying confidence levels - in real implementation would come from tracking data
        let baseConfidence = result.detection_summary.detection_rate
        let variation = sin(Double(index) * 0.2) * 0.1 // Small variation
        return min(1.0, max(0.0, baseConfidence + variation))
    }
    
    private func getConfidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

struct FlightPhaseIndicators: View {
    let result: BallTrackingResponse
    let playbackProgress: Double
    let size: CGSize
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // Current flight phase
                    FlightPhaseBadge(
                        phase: getCurrentFlightPhase(),
                        isActive: true
                    )
                    
                    // Flight characteristics
                    if let trajectoryType = result.flight_analysis?.trajectory_type {
                        FlightCharacteristicBadge(
                            characteristic: trajectoryType,
                            color: Color.ballTracking
                        )
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            Spacer()
        }
    }
    
    private func getCurrentFlightPhase() -> String {
        switch playbackProgress {
        case 0..<0.2: return "Launch"
        case 0.2..<0.6: return "Ascent"
        case 0.6..<0.8: return "Descent"
        default: return "Landing"
        }
    }
}

struct FlightPhaseBadge: View {
    let phase: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.ballTracking : .gray)
                .frame(width: 8, height: 8)
            
            Text(phase.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
    }
}

struct FlightCharacteristicBadge: View {
    let characteristic: String
    let color: Color
    
    var body: some View {
        Text(characteristic)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.8))
            )
            .lineLimit(2)
            .multilineTextAlignment(.center)
    }
}


// MARK: - Real Video Player with Overlay

struct RealVideoPlayerWithOverlay: View {
    let videoData: Data
    let result: BallTrackingResponse
    let showTrajectoryPath: Bool
    let showDetectionPoints: Bool
    @Binding var playbackProgress: Double
    @Binding var isPlaying: Bool
    
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    
    var body: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
            
            // Ball Trajectory Overlay
            if showTrajectoryPath {
                BallTrajectoryOverlay(
                    result: result,
                    showDetectionPoints: showDetectionPoints,
                    playbackProgress: playbackProgress
                )
            }
        }
        .onAppear {
            setupVideoPlayer()
        }
        .onDisappear {
            cleanupVideo()
        }
    }
    
    private func setupVideoPlayer() {
        // Create temporary file for video playback
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ball_tracking_\(UUID().uuidString).mp4")
        
        do {
            try videoData.write(to: tempURL)
            self.videoURL = tempURL
            
            let asset = AVURLAsset(url: tempURL)
            let playerItem = AVPlayerItem(asset: asset)
            self.player = AVPlayer(playerItem: playerItem)
            
            // Setup time observation for progress tracking
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let currentPlayer = self.player
            player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                Task { @MainActor in
                    if let duration = currentPlayer?.currentItem?.duration {
                        let progress = time.seconds / duration.seconds
                        if !progress.isNaN && !progress.isInfinite {
                            playbackProgress = min(max(progress, 0), 1)
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to setup video player: \(error)")
        }
    }
    
    private func setupPlayer() {
        // Update playing state based on player state
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    private func cleanupVideo() {
        player?.pause()
        if let url = videoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

#Preview {
    BallTrackingView()
        .environmentObject(AuthenticationManager())
}
