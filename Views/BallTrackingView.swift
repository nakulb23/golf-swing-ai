import SwiftUI
import PhotosUI

struct BallTrackingView: View {
    @StateObject private var apiService = APIService.shared
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var isTracking = false
    @State private var trackingResult: BallTrackingResponse?
    @State private var showPhysicsInfo = false
    @State private var errorMessage: String?
    
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
                            PhotosPicker(
                                selection: $selectedVideo,
                                matching: .videos,
                                photoLibrary: .shared()
                            ) {
                                VStack(spacing: 12) {
                                    Image(systemName: videoData != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(videoData != nil ? .green : .orange)
                                    
                                    Text(videoData != nil ? "Video Selected" : "Select Golf Ball Video")
                                        .font(.headline)
                                    
                                    Text(videoData != nil ? "Tap to change video" : "Choose a video showing ball flight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(videoData != nil ? Color.green.opacity(0.5) : Color.orange.opacity(0.3), lineWidth: 2)
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
                        
                        // Error Message
                        if let error = errorMessage {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Tracking Error")
                                        .fontWeight(.semibold)
                                }
                                Text(error)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
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
                    videoData = data
                    trackingResult = nil
                    errorMessage = nil
                }
            }
        }
    }
    
    private func trackBall() {
        guard let data = videoData else { return }
        
        isTracking = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await apiService.trackBall(videoData: data)
                
                await MainActor.run {
                    trackingResult = result
                    isTracking = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to track ball: \(error.localizedDescription)"
                    isTracking = false
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
                        // Simulated Video Background
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.8), .black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 320)
                        
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
                        
                        // Ball Trajectory Overlay
                        if showTrajectoryPath {
                            BallTrajectoryOverlay(
                                result: result,
                                showDetectionPoints: showDetectionPoints,
                                playbackProgress: playbackProgress
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
                                color: .ballTracking
                            )
                            
                            QuickStat(
                                icon: "speedometer",
                                value: String(format: "%.1f", result.flight_analysis?.launch_speed_ms ?? 0),
                                label: "Launch m/s",
                                color: .success
                            )
                            
                            QuickStat(
                                icon: "arrow.up.right",
                                value: String(format: "%.1f°", result.flight_analysis?.launch_angle_degrees ?? 0),
                                label: "Angle",
                                color: .warning
                            )
                            
                            QuickStat(
                                icon: "clock",
                                value: String(format: "%.1fs", result.trajectory_data.flight_time),
                                label: "Flight",
                                color: .error
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
                    .foregroundColor(.ballTracking)
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
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isPlaying || playbackProgress >= 1.0 {
                timer.invalidate()
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
                        colors: [.ballTracking, .ballTracking.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 4])
                )
                
                // Ball detection points
                if showDetectionPoints {
                    ForEach(0..<result.detection_summary.trajectory_points, id: \.self) { index in
                        let progress = Double(index) / Double(result.detection_summary.trajectory_points - 1)
                        if progress <= playbackProgress {
                            let point = getTrajectoryPoint(progress: progress, in: geometry.size)
                            Circle()
                                .fill(Color.warning)
                                .frame(width: 6, height: 6)
                                .position(point)
                                .animation(.easeInOut(duration: 0.2), value: playbackProgress)
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
                        .shadow(color: .ballTracking, radius: 4)
                        .animation(.easeInOut(duration: 0.1), value: playbackProgress)
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
                            color: .success
                        )
                    }
                    
                    if let launchAngle = result.flight_analysis?.launch_angle_degrees {
                        MetricBadge(
                            icon: "arrow.up.right",
                            value: String(format: "%.1f°", launchAngle),
                            color: .warning
                        )
                    }
                    
                    if let maxHeight = result.flight_analysis?.estimated_max_height {
                        MetricBadge(
                            icon: "arrow.up",
                            value: String(format: "%.1f m", maxHeight),
                            color: .error
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

#Preview {
    BallTrackingView()
        .environmentObject(AuthenticationManager())
}
