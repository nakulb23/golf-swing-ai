import SwiftUI

struct OptimalSwingReferenceView: View {
    let optimalFrames: [PoseFrame]
    let comparisonData: ComparisonData?
    
    @State private var selectedFrameIndex: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient representing ideal motion
                LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Pose visualization
                if selectedFrameIndex < optimalFrames.count {
                    Canvas { context, size in
                        drawOptimalPose(
                            context: context,
                            frame: optimalFrames[selectedFrameIndex],
                            size: size
                        )
                        
                        // Draw motion trail for key positions
                        drawMotionTrail(
                            context: context,
                            frames: optimalFrames,
                            currentIndex: selectedFrameIndex,
                            size: size
                        )
                    }
                }
                
                // Phase indicator
                VStack {
                    HStack {
                        Spacer()
                        if let phase = optimalFrames[safe: selectedFrameIndex]?.phase {
                            Text(phase.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(6)
                                .padding(8)
                        }
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            // Set to key frame (e.g., impact position)
            selectedFrameIndex = findKeyFrame()
        }
    }
    
    private func findKeyFrame() -> Int {
        // Find impact frame or mid-point
        if let impactIndex = optimalFrames.firstIndex(where: { $0.phase == "impact" }) {
            return impactIndex
        }
        return optimalFrames.count / 2
    }
    
    private func drawOptimalPose(context: GraphicsContext, frame: PoseFrame, size: CGSize) {
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
        
        // Draw skeleton with gradient
        for (start, end) in connections {
            if let startLM = frame.landmarks[start],
               let endLM = frame.landmarks[end],
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
                
                // Special highlighting for key body parts
                var strokeWidth: CGFloat = 4
                var strokeColor = Color.green
                
                // Highlight arm line for lead arm extension
                if (start == "left_shoulder" && end == "left_elbow") ||
                   (start == "left_elbow" && end == "left_wrist") {
                    strokeWidth = 6
                    strokeColor = Color.green.opacity(0.9)
                }
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [strokeColor, strokeColor.opacity(0.7)]),
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    lineWidth: strokeWidth
                )
            }
        }
        
        // Draw joints with glow effect
        for (name, landmark) in frame.landmarks {
            if landmark.confidence > 0.5 {
                let point = CGPoint(
                    x: landmark.x * size.width,
                    y: landmark.y * size.height
                )
                
                // Outer glow
                context.fill(
                    Circle().path(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)),
                    with: .color(.green.opacity(0.3))
                )
                
                // Inner joint
                context.fill(
                    Circle().path(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)),
                    with: .color(.green)
                )
                
                // Highlight key joints
                if name == "left_wrist" || name == "left_elbow" {
                    context.stroke(
                        Circle().path(in: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)),
                        with: .color(.white.opacity(0.5)),
                        lineWidth: 2
                    )
                }
            }
        }
    }
    
    private func drawMotionTrail(context: GraphicsContext, frames: [PoseFrame], currentIndex: Int, size: CGSize) {
        // Draw fading trail of key positions
        let keyJoints = ["left_wrist", "right_wrist"]
        let trailFrames = 5
        
        for jointName in keyJoints {
            var path = Path()
            var points: [CGPoint] = []
            
            // Collect points from previous frames
            let startIndex = max(0, currentIndex - trailFrames)
            
            for i in startIndex...currentIndex {
                if let landmark = frames[safe: i]?.landmarks[jointName],
                   landmark.confidence > 0.5 {
                    let point = CGPoint(
                        x: landmark.x * size.width,
                        y: landmark.y * size.height
                    )
                    points.append(point)
                }
            }
            
            // Draw smooth trail
            if points.count > 1 {
                path.move(to: points[0])
                
                for i in 1..<points.count {
                    let opacity = Double(i) / Double(points.count)
                    path.addLine(to: points[i])
                    
                    context.stroke(
                        path,
                        with: .color(.green.opacity(opacity * 0.5)),
                        lineWidth: 2
                    )
                }
            }
        }
    }
}

