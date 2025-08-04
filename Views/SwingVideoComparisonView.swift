import SwiftUI
import AVKit

struct SwingVideoComparisonView: View {
    let videoData: Data?
    let poseSequence: [PoseFrame]
    let showOverlay: Bool
    let highlightIssues: Bool
    
    @State private var videoURL: URL?
    @State private var currentFrameIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            if let url = videoURL {
                ZStack {
                    // Video background
                    VideoThumbnailView(url: url, frameTime: frameTime)
                    
                    // Pose overlay
                    if showOverlay && currentFrameIndex < poseSequence.count {
                        Canvas { context, size in
                            drawPoseOverlay(
                                context: context,
                                frame: poseSequence[currentFrameIndex],
                                size: size,
                                highlightIssues: highlightIssues
                            )
                        }
                    }
                }
            } else {
                // Placeholder while loading
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .onAppear {
            saveVideoToTemp()
        }
    }
    
    private var frameTime: Double {
        // For now, show frame at peak backswing (around 40% through sequence)
        return 0.4
    }
    
    private func saveVideoToTemp() {
        guard let data = videoData else { return }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("swing_\(UUID().uuidString).mp4")
        
        do {
            try data.write(to: tempURL)
            videoURL = tempURL
        } catch {
            print("Failed to save video: \(error)")
        }
    }
    
    private func drawPoseOverlay(context: GraphicsContext, frame: PoseFrame, size: CGSize, highlightIssues: Bool) {
        let connections = [
            ("left_shoulder", "left_elbow"),
            ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"),
            ("right_elbow", "right_wrist"),
            ("left_shoulder", "right_shoulder"),
            ("left_shoulder", "left_hip"),
            ("right_shoulder", "right_hip")
        ]
        
        // Determine color based on issues
        let baseColor: Color = (highlightIssues && frame.issues != nil && !frame.issues!.isEmpty) ? .red : .white
        
        // Draw skeleton connections
        for (start, end) in connections {
            if let startLM = frame.landmarks[start],
               let endLM = frame.landmarks[end],
               startLM.confidence > 0.5 && endLM.confidence > 0.5 {
                
                let startPoint = CGPoint(x: startLM.x, y: startLM.y)
                let endPoint = CGPoint(x: endLM.x, y: endLM.y)
                
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                
                // Highlight specific connections for issues
                var strokeColor = baseColor
                var strokeWidth: CGFloat = 3
                
                if highlightIssues, let issues = frame.issues {
                    if issues.contains("excessive_lead_arm_bend") &&
                       (start == "left_shoulder" && end == "left_elbow" ||
                        start == "left_elbow" && end == "left_wrist") {
                        strokeColor = .red
                        strokeWidth = 5
                    }
                }
                
                context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)
            }
        }
        
        // Draw joints
        for (_, landmark) in frame.landmarks {
            if landmark.confidence > 0.5 {
                let point = CGPoint(x: landmark.x, y: landmark.y)
                
                context.fill(
                    Circle().path(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
                    with: .color(baseColor)
                )
            }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    let frameTime: Double
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        if let thumbnail = thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.black
                .onAppear {
                    generateThumbnail()
                }
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: frameTime * asset.duration.seconds, preferredTimescale: 600)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                
                DispatchQueue.main.async {
                    self.thumbnail = uiImage
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
    }
}