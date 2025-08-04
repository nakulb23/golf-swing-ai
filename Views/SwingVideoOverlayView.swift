import SwiftUI
import AVKit

struct SwingVideoOverlayView: View {
    let videoURL: URL
    let poseSequence: [PoseFrame]
    let optimalReference: [PoseFrame]?
    let comparisonData: ComparisonData?
    
    @State private var player: AVPlayer?
    @State private var currentFrame: Int = 0
    @State private var isPlaying = false
    @State private var showOptimalOverlay = true
    @State private var showIssueHighlights = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player
                VideoPlayer(player: player)
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        player?.pause()
                    }
                
                // Pose Overlay
                if currentFrame < poseSequence.count {
                    PoseOverlay(
                        frame: poseSequence[currentFrame],
                        optimalFrame: optimalReference?[safe: currentFrame],
                        deviations: comparisonData?.frame_comparisons[safe: currentFrame]?.deviations,
                        showOptimal: showOptimalOverlay,
                        showIssues: showIssueHighlights,
                        geometry: geometry
                    )
                }
                
                // Controls
                VStack {
                    Spacer()
                    
                    // Issue indicators
                    if let issues = poseSequence[safe: currentFrame]?.issues, !issues.isEmpty {
                        HStack {
                            ForEach(issues, id: \.self) { issue in
                                IssueTag(issue: issue)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Playback controls
                    HStack(spacing: 20) {
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(currentFrame) },
                            set: { currentFrame = Int($0) }
                        ), in: 0...Double(max(poseSequence.count - 1, 1)))
                        .accentColor(.white)
                        
                        Button(action: { showOptimalOverlay.toggle() }) {
                            Image(systemName: "person.2.fill")
                                .font(.title2)
                                .foregroundColor(showOptimalOverlay ? .green : .gray)
                        }
                        
                        Button(action: { showIssueHighlights.toggle() }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(showIssueHighlights ? .red : .gray)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
        
        // Add time observer for frame updates
        let interval = CMTime(seconds: 1.0/30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            updateCurrentFrame(time: time)
        }
    }
    
    private func updateCurrentFrame(time: CMTime) {
        guard let duration = player?.currentItem?.duration else { return }
        let progress = CMTimeGetSeconds(time) / CMTimeGetSeconds(duration)
        currentFrame = Int(progress * Double(poseSequence.count))
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
}

struct PoseOverlay: View {
    let frame: PoseFrame
    let optimalFrame: PoseFrame?
    let deviations: [String: LandmarkDeviation]?
    let showOptimal: Bool
    let showIssues: Bool
    let geometry: GeometryProxy
    
    // Define skeleton connections
    let connections = [
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle")
    ]
    
    var body: some View {
        Canvas { context, size in
            // Draw user pose
            drawPose(
                context: context,
                landmarks: frame.landmarks,
                color: .white,
                strokeWidth: 3,
                size: size
            )
            
            // Draw optimal pose overlay
            if showOptimal, let optimal = optimalFrame {
                drawPose(
                    context: context,
                    landmarks: optimal.landmarks,
                    color: .green.opacity(0.6),
                    strokeWidth: 2,
                    size: size
                )
            }
            
            // Highlight issues
            if showIssues, let issues = frame.issues {
                drawIssueHighlights(
                    context: context,
                    landmarks: frame.landmarks,
                    issues: issues,
                    deviations: deviations,
                    size: size
                )
            }
        }
    }
    
    private func drawPose(context: GraphicsContext, landmarks: [String: PoseLandmark], color: Color, strokeWidth: CGFloat, size: CGSize) {
        // Draw skeleton connections
        for (start, end) in connections {
            if let startLM = landmarks[start],
               let endLM = landmarks[end],
               startLM.confidence > 0.5 && endLM.confidence > 0.5 {
                
                let startPoint = CGPoint(
                    x: startLM.x * size.width,
                    y: startLM.y * size.height
                )
                let endPoint = CGPoint(
                    x: endLM.x * size.width,
                    y: endLM.y * size.height
                )
                
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                
                context.stroke(path, with: .color(color), lineWidth: strokeWidth)
            }
        }
        
        // Draw joints
        for (_, landmark) in landmarks {
            if landmark.confidence > 0.5 {
                let point = CGPoint(
                    x: landmark.x * size.width,
                    y: landmark.y * size.height
                )
                
                context.fill(
                    Circle().path(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
                    with: .color(color)
                )
            }
        }
    }
    
    private func drawIssueHighlights(context: GraphicsContext, landmarks: [String: PoseLandmark], issues: [String], deviations: [String: LandmarkDeviation]?, size: CGSize) {
        // Highlight problematic areas based on issues
        for issue in issues {
            switch issue {
            case "excessive_lead_arm_bend":
                highlightArmBend(context: context, landmarks: landmarks, size: size)
            case "poor_spine_angle":
                highlightSpineAngle(context: context, landmarks: landmarks, size: size)
            case "insufficient_weight_shift":
                highlightWeightShift(context: context, landmarks: landmarks, size: size)
            default:
                break
            }
        }
        
        // Draw deviation indicators
        if let deviations = deviations {
            for (landmarkName, deviation) in deviations {
                if deviation.distance > 0.1, // Significant deviation
                   let landmark = landmarks[landmarkName],
                   landmark.confidence > 0.5 {
                    
                    let point = CGPoint(
                        x: landmark.x * size.width,
                        y: landmark.y * size.height
                    )
                    
                    // Draw red circle around problematic joint
                    context.stroke(
                        Circle().path(in: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)),
                        with: .color(.red),
                        lineWidth: 2
                    )
                }
            }
        }
    }
    
    private func highlightArmBend(context: GraphicsContext, landmarks: [String: PoseLandmark], size: CGSize) {
        // Highlight the lead arm with red
        if let shoulder = landmarks["left_shoulder"],
           let elbow = landmarks["left_elbow"],
           let wrist = landmarks["left_wrist"] {
            
            var path = Path()
            path.move(to: CGPoint(x: shoulder.x * size.width, y: shoulder.y * size.height))
            path.addLine(to: CGPoint(x: elbow.x * size.width, y: elbow.y * size.height))
            path.addLine(to: CGPoint(x: wrist.x * size.width, y: wrist.y * size.height))
            
            context.stroke(path, with: .color(.red), lineWidth: 5)
        }
    }
    
    private func highlightSpineAngle(context: GraphicsContext, landmarks: [String: PoseLandmark], size: CGSize) {
        // Draw spine line
        if let nose = landmarks["nose"],
           let leftHip = landmarks["left_hip"],
           let rightHip = landmarks["right_hip"] {
            
            let hipCenter = CGPoint(
                x: ((leftHip.x + rightHip.x) / 2) * size.width,
                y: ((leftHip.y + rightHip.y) / 2) * size.height
            )
            
            var path = Path()
            path.move(to: CGPoint(x: nose.x * size.width, y: nose.y * size.height))
            path.addLine(to: hipCenter)
            
            context.stroke(path, with: .color(.orange), lineWidth: 5)
        }
    }
    
    private func highlightWeightShift(context: GraphicsContext, landmarks: [String: PoseLandmark], size: CGSize) {
        // Show weight distribution
        if let leftAnkle = landmarks["left_ankle"],
           let rightAnkle = landmarks["right_ankle"] {
            
            // Draw weight indicator
            let leftPoint = CGPoint(x: leftAnkle.x * size.width, y: leftAnkle.y * size.height)
            let rightPoint = CGPoint(x: rightAnkle.x * size.width, y: rightAnkle.y * size.height)
            
            context.fill(
                Circle().path(in: CGRect(x: leftPoint.x - 10, y: leftPoint.y - 10, width: 20, height: 20)),
                with: .color(.yellow.opacity(0.6))
            )
            
            context.fill(
                Circle().path(in: CGRect(x: rightPoint.x - 10, y: rightPoint.y - 10, width: 20, height: 20)),
                with: .color(.yellow.opacity(0.3))
            )
        }
    }
}

struct IssueTag: View {
    let issue: String
    
    var body: some View {
        Text(issueDescription)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(issueColor)
            .cornerRadius(4)
    }
    
    private var issueDescription: String {
        switch issue {
        case "excessive_lead_arm_bend":
            return "Lead Arm Bend"
        case "poor_spine_angle":
            return "Spine Angle"
        case "insufficient_weight_shift":
            return "Weight Shift"
        default:
            return issue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    private var issueColor: Color {
        switch issue {
        case "excessive_lead_arm_bend":
            return .red
        case "poor_spine_angle":
            return .orange
        case "insufficient_weight_shift":
            return .yellow
        default:
            return .gray
        }
    }
}

// Safe subscript extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}