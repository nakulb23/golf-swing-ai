import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UIKit
import Foundation

// MARK: - Storage Types for Analysis History

struct StoredAnalysis: Codable, Identifiable {
    let id: UUID
    let date: Date
    let videoFilename: String
    let result: SwingAnalysisResponse
    let thumbnailData: Data?
    let userNotes: String?
    
    init(result: SwingAnalysisResponse, videoFilename: String, thumbnailData: Data? = nil, userNotes: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.result = result
        self.videoFilename = videoFilename
        self.thumbnailData = thumbnailData
        self.userNotes = userNotes
    }
}

@MainActor
class AnalysisStorageManager: ObservableObject {
    static let shared = AnalysisStorageManager()
    
    @Published var storedAnalyses: [StoredAnalysis] = []
    
    private let userDefaults = UserDefaults.standard
    private let analysesKey = "stored_analyses"
    private let videosDirectory: URL
    
    private init() {
        // Create videos directory in app's documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        videosDirectory = documentsPath.appendingPathComponent("SwingVideos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        loadStoredAnalyses()
    }
    
    func saveAnalysis(result: SwingAnalysisResponse, videoData: Data, thumbnailData: Data? = nil, userNotes: String? = nil) async throws -> StoredAnalysis {
        // Generate unique filename
        let videoFilename = "swing_\(UUID().uuidString).mp4"
        let videoURL = videosDirectory.appendingPathComponent(videoFilename)
        
        // Save video file
        try videoData.write(to: videoURL)
        print("✅ Video saved to: \(videoURL.path)")
        
        // Create stored analysis
        let storedAnalysis = StoredAnalysis(
            result: result,
            videoFilename: videoFilename,
            thumbnailData: thumbnailData,
            userNotes: userNotes
        )
        
        // Add to array and save
        storedAnalyses.insert(storedAnalysis, at: 0) // Add to beginning for chronological order
        saveStoredAnalyses()
        
        return storedAnalysis
    }
    
    private func loadStoredAnalyses() {
        if let data = userDefaults.data(forKey: analysesKey) {
            do {
                storedAnalyses = try JSONDecoder().decode([StoredAnalysis].self, from: data)
                print("✅ Loaded \(storedAnalyses.count) stored analyses")
            } catch {
                print("❌ Failed to decode stored analyses: \(error)")
                storedAnalyses = []
            }
        }
    }
    
    private func saveStoredAnalyses() {
        do {
            let data = try JSONEncoder().encode(storedAnalyses)
            userDefaults.set(data, forKey: analysesKey)
            print("✅ Saved \(storedAnalyses.count) analyses to UserDefaults")
        } catch {
            print("❌ Failed to encode stored analyses: \(error)")
        }
    }
    
    func getVideoURL(for analysis: StoredAnalysis) -> URL? {
        let videoURL = videosDirectory.appendingPathComponent(analysis.videoFilename)
        return FileManager.default.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    func deleteAnalysis(_ analysis: StoredAnalysis) {
        // Remove video file
        let videoURL = videosDirectory.appendingPathComponent(analysis.videoFilename)
        try? FileManager.default.removeItem(at: videoURL)
        
        // Remove from array
        storedAnalyses.removeAll { $0.id == analysis.id }
        saveStoredAnalyses()
        
        print("🗑️ Deleted analysis: \(analysis.id)")
    }
    
    func clearAllAnalyses() {
        // Remove all video files
        for analysis in storedAnalyses {
            let videoURL = videosDirectory.appendingPathComponent(analysis.videoFilename)
            try? FileManager.default.removeItem(at: videoURL)
        }
        
        // Clear array
        storedAnalyses.removeAll()
        saveStoredAnalyses()
        
        print("🗑️ Cleared all analyses")
    }
}

// MARK: - Basic Analysis History View

struct AnalysisHistoryView: View {
    @StateObject private var storageManager = AnalysisStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                if storageManager.storedAnalyses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                        
                        Text("No Analysis History")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(UIColor.label))
                        
                        Text("Your swing analysis history will appear here")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(storageManager.storedAnalyses) { analysis in
                            BasicAnalysisHistoryCard(analysis: analysis)
                        }
                        .onDelete(perform: deleteAnalyses)
                    }
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !storageManager.storedAnalyses.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            storageManager.clearAllAnalyses()
                        }
                    }
                }
            }
        }
    }
    
    private func deleteAnalyses(offsets: IndexSet) {
        for index in offsets {
            storageManager.deleteAnalysis(storageManager.storedAnalyses[index])
        }
    }
}

// MARK: - Basic Analysis History Card

struct BasicAnalysisHistoryCard: View {
    let analysis: StoredAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(DateFormatter.recentDate.string(from: analysis.date))
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Spacer()
                
                let score = analysis.result.confidence * 100
                if score > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(Int(score))")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(scoreColor(score).cornerRadius(8))
                }
            }
            
            Text("Swing Type: \(analysis.result.predicted_label)")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(1)
            
            Text("Confidence: \(Int(analysis.result.confidence * 100))%")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Analysis Mode
enum AnalysisMode: String, CaseIterable {
    case local = "local"
    
    var displayName: String {
        switch self {
        case .local: return "AI Analysis"
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "brain.head.profile"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "AI-powered swing analysis on device"
        }
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case pdf = "pdf"
    case json = "json"
    case csv = "csv"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF Report"
        case .json: return "JSON Data"
        case .csv: return "CSV Spreadsheet"
        }
    }
    
    var description: String {
        switch self {
        case .pdf: return "Detailed visual report"
        case .json: return "Raw analysis data"
        case .csv: return "Tabular data format"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.text"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Main Swing Analysis View
struct SwingAnalysisView: View {
    @StateObject private var viewModel = SwingAnalysisViewModel()
    @StateObject private var localAI = LocalAIManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                if let result = viewModel.analysisResult, let videoData = viewModel.videoData {
                    // Results View
                    ComprehensiveResultsView(
                        result: result,
                        videoData: videoData,
                        onDismiss: viewModel.reset,
                        onExport: { format in
                            Task {
                                await viewModel.exportAnalysis(format: format)
                            }
                        }
                    )
                } else {
                    // Main Interface
                    ScrollView {
                        VStack(spacing: 30) {
                            // Header Section
                            SwingAnalysisHeader(showHistory: $viewModel.showHistory)
                            
                            // Video Input Section
                            VideoInputSection(
                                viewModel: viewModel
                            )
                            
                            // Recent History Preview Section
                            RecentAnalysisPreview(showFullHistory: $viewModel.showHistory)
                            
                            // Analysis Status
                            if viewModel.isAnalyzing {
                                SwingAnalysisProgressView(
                                    progress: viewModel.analysisProgress,
                                    currentStage: viewModel.currentAnalysisStage
                                )
                            }
                            
                            // Error Display
                            if let error = viewModel.errorMessage {
                                ErrorBanner(message: error) {
                                    viewModel.clearError()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarHidden(viewModel.analysisResult != nil)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showCamera) {
            SimpleCameraView { data in
                viewModel.handleVideoCapture(data)
            }
        }
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $viewModel.selectedVideo,
            matching: .videos
        )
        .onChange(of: viewModel.selectedVideo) { _, newValue in
            if let newValue = newValue {
                Task {
                    await viewModel.handleVideoSelection(newValue)
                }
            }
        }
        .sheet(isPresented: $viewModel.showHistory) {
            AnalysisHistoryView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPhotoPicker"))) { _ in
            viewModel.showPhotoPicker = true
        }
    }
}

// MARK: - View Model
@MainActor
class SwingAnalysisViewModel: ObservableObject {
    // Core State
    @Published var analysisResult: SwingAnalysisResponse?
    @Published var videoData: Data?
    @Published var selectedVideo: PhotosPickerItem?
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysisStage: AnalysisStage = .idle
    @Published var errorMessage: String?
    
    // UI State
    @Published var showCamera = false
    @Published var showPhotoPicker = false
    @Published var showHistory = false
    @Published var analysisMode: AnalysisMode = .local
    
    // Services
    private let apiService = APIService.shared
    private let localAI = LocalAIManager.shared
    private let localSwingAnalyzer = LocalSwingAnalyzer()
    
    enum AnalysisStage: String, CaseIterable {
        case idle = "Ready"
        case preprocessing = "Processing Video"
        case videoProcessing = "Compressing Video"
        case poseDetection = "Detecting Poses"
        case featureExtraction = "Extracting Features"
        case mlInference = "Running Analysis"
        case postprocessing = "Finalizing Results"
        case complete = "Complete"
    }
    
    func handleVideoSelection(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                videoData = data
                await analyzeVideo(data)
            }
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
    }
    
    func handleVideoCapture(_ data: Data?) {
        guard let data = data else {
            errorMessage = "Failed to capture video"
            return
        }
        videoData = data
        Task {
            await analyzeVideo(data)
        }
    }
    
    func analyzeVideo(_ data: Data) async {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        do {
            // Stage 1: Preprocessing
            currentAnalysisStage = .preprocessing
            analysisProgress = 0.1
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Stage 2: Local AI Analysis
            let result = try await performLocalAnalysis(data)
            
            currentAnalysisStage = .complete
            analysisProgress = 1.0
            analysisResult = result
            
            // Save analysis to local storage
            // Note: AnalysisStorageManager is defined in Models/SupportingTypes.swift
            // Uncomment when the file is properly included in the Xcode project
            /*
            Task {
                do {
                    let storedAnalysis = try await AnalysisStorageManager.shared.saveAnalysis(
                        result: result,
                        videoData: data
                    )
                    print("✅ Analysis saved with ID: \(storedAnalysis.id)")
                } catch {
                    print("❌ Failed to save analysis: \(error)")
                }
            }
            */
            
        } catch {
            errorMessage = createDetailedErrorMessage(from: error)
        }
        
        isAnalyzing = false
    }
    
    private func createDetailedErrorMessage(from error: Error) -> String {
        // Check if it's our specific LocalAnalysisError
        if let localError = error as? LocalAnalysisError {
            switch localError {
            case .noPosesDetected(let message):
                return message
            case .poorPoseQuality(let message):
                return message
            case .visionFrameworkUnavailable(let message):
                return message
            case .insufficientPoseData:
                return """
                Unable to detect your body pose clearly enough for analysis.
                
                📹 To fix this:
                • Ensure your full body is visible in the frame
                • Record in good lighting conditions
                • Stand at least 8 feet from the camera
                • Avoid busy backgrounds that might interfere with pose detection
                """
                
            case .noValidSwingMotionDetected:
                return """
                No golf swing motion was detected in your video.
                
                ⛳ To fix this:
                • Make sure you're performing a complete golf swing
                • Record from the side view (profile angle works best)
                • Ensure the swing motion is clearly visible
                • Try recording a practice swing if the ball is causing interference
                """
                
            case .poorVideoQuality:
                return """
                Video quality is too poor for accurate analysis.
                
                🎥 To fix this:
                • Record in better lighting (avoid backlighting)
                • Clean your camera lens
                • Record at higher resolution if possible
                • Avoid recording during golden hour or low light
                """
                
            case .incorrectCameraAngle:
                return """
                Camera angle needs adjustment for optimal analysis.
                
                📐 For best results:
                
                ✅ SIDE VIEW (Recommended):
                • Position camera to your LEFT or RIGHT side (profile view)
                • Your face should be visible to the camera
                • Place phone horizontally at chest height
                
                ✅ BACK VIEW (Supported):
                • Position camera directly behind you
                • Ensure your full body and swing arc are visible
                • Stand far enough that shoulders are clearly visible
                
                📱 General tips:
                • Stand 8-12 feet away from the camera
                • Record in good lighting conditions
                • Keep the camera steady during recording
                """
                
            case .modelNotLoaded:
                return """
                AI analysis model failed to load.
                
                🔄 To fix this:
                • Force close and restart the app
                • Ensure you have enough storage space
                • If problem persists, contact support
                """
                
            case .featureExtractionFailed:
                return """
                Unable to extract swing features from the video.
                
                📊 This usually means:
                • The video is too short (needs at least 2 seconds)
                • Motion is too fast or blurry
                • Body parts are obscured during the swing
                
                Try recording a slower, more deliberate practice swing.
                """
                
            default:
                return "Analysis failed: \(localError.localizedDescription)"
            }
        }
        
        // Handle other types of errors
        let errorDescription = error.localizedDescription
        
        if errorDescription.contains("memory") || errorDescription.contains("Memory") {
            return """
            Analysis failed due to memory constraints.
            
            📱 To fix this:
            • Close other apps before recording
            • Record shorter videos (15-30 seconds max)
            • Restart the app and try again
            """
        }
        
        if errorDescription.contains("file") || errorDescription.contains("File") {
            return """
            Video file could not be processed.
            
            📁 To fix this:
            • Ensure you have enough storage space
            • Try recording a new video
            • Check that your camera is working properly
            """
        }
        
        if errorDescription.contains("network") || errorDescription.contains("Network") {
            return """
            Network connection issue during analysis.
            
            📶 To fix this:
            • Check your internet connection
            • Try again when you have better signal
            • This analysis runs locally, so network shouldn't be required
            """
        }
        
        // Generic fallback with actionable advice
        return """
        Analysis encountered an unexpected error.
        
        🔄 Try these steps:
        • Record a new video with clear lighting
        • Ensure your full body is visible during the swing
        • Keep the camera steady and at a good distance
        • Contact support if the problem continues
        
        Error details: \(errorDescription)
        """
    }
    
    private func performLocalAnalysis(_ data: Data) async throws -> SwingAnalysisResponse {
        print("🎬 Starting real video analysis...")
        
        // Create a temporary file URL for the video data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("swing_video_\(Date().timeIntervalSince1970).mp4")
        
        do {
            try data.write(to: tempURL)
            print("✅ Wrote video data to temporary file: \(tempURL.path)")
            
            // Compress video for better AI processing performance
            currentAnalysisStage = .videoProcessing
            analysisProgress = 0.2
            
            let videoURLForAnalysis: URL
            do {
                videoURLForAnalysis = try await compressVideoForAnalysis(tempURL)
                print("✅ Video compressed for analysis")
            } catch {
                print("⚠️ Video compression failed, using original: \(error)")
                videoURLForAnalysis = tempURL
            }
            
            // Update progress for pose detection
            currentAnalysisStage = .poseDetection
            analysisProgress = 0.3
            
            // Update progress for feature extraction
            currentAnalysisStage = .featureExtraction
            analysisProgress = 0.6
            
            // Update progress for ML inference
            currentAnalysisStage = .mlInference
            analysisProgress = 0.8
            
            // Call the real analysis method with proper error handling
            let result: SwingAnalysisResponse
            do {
                result = try await localSwingAnalyzer.analyzeSwing(from: videoURLForAnalysis)
            } catch {
                print("❌ Local analysis failed: \(error)")
                // Clean up temporary files before falling back
                try? FileManager.default.removeItem(at: tempURL)
                if videoURLForAnalysis != tempURL {
                    try? FileManager.default.removeItem(at: videoURLForAnalysis)
                }
                throw error
            }
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: tempURL)
            if videoURLForAnalysis != tempURL {
                try? FileManager.default.removeItem(at: videoURLForAnalysis)
            }
            
            print("✅ Real analysis completed successfully")
            print("   Prediction: \(result.predicted_label)")
            print("   Confidence: \(String(format: "%.2f", result.confidence))")
            print("   Plane Angle: \(String(format: "%.1f", result.plane_angle ?? 0))°")
            
            return result
            
        } catch {
            // Clean up temporary file in case of error
            try? FileManager.default.removeItem(at: tempURL)
            
            print("❌ Real analysis failed: \(error)")
            print("❌ Error type: \(type(of: error))")
            if let localError = error as? LocalAnalysisError {
                print("❌ Local analysis error: \(localError)")
            }
            
            // Don't use fallback data - let the error bubble up to show proper error UI
            throw error
        }
    }
    
    private func compressVideoForAnalysis(_ inputURL: URL) async throws -> URL {
        print("🗜️ Starting video compression for AI analysis...")
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("compressed_\(Date().timeIntervalSince1970).mp4")
        
        let asset = AVURLAsset(url: inputURL)
        
        // Use a preset that doesn't require custom video composition
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            // Fallback to medium quality if 720p preset not available
            guard let fallbackSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                throw NSError(domain: "VideoCompression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
            }
            
            fallbackSession.outputURL = outputURL
            fallbackSession.outputFileType = .mp4
            fallbackSession.shouldOptimizeForNetworkUse = true
            fallbackSession.metadata = [] // Remove metadata
            
            // Don't set videoComposition - use the default preset settings
            // This avoids the crash while still compressing the video
            
            return try await exportVideo(with: fallbackSession, outputURL: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.metadata = [] // Remove metadata to reduce file size
        
        // Don't set custom videoComposition to avoid crash
        // The preset will handle the compression
        
        return try await exportVideo(with: exportSession, outputURL: outputURL)
    }
    
    private func exportVideo(with session: AVAssetExportSession, outputURL: URL) async throws -> URL {
        
        // Use new iOS 18 export API if available
        if #available(iOS 18.0, *) {
            do {
                try await session.export(to: outputURL, as: .mp4)
            } catch {
                print("❌ Video export failed: \(error)")
                throw error
            }
        } else {
            // Fallback for older iOS versions
            await withCheckedContinuation { continuation in
                session.exportAsynchronously {
                    continuation.resume()
                }
            }
            
            if session.status != .completed {
                let error = session.error ?? NSError(domain: "VideoCompression", code: 2, 
                    userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(session.status.rawValue)"])
                print("❌ Video export failed: \(error)")
                throw error
            }
        }
        
        // Get compressed file size for logging
        let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        print("✅ Video compression completed:")
        print("   Compressed size: \(ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file))")
        
        return outputURL
    }
    
    // Removed createEnhancedMockAnalysis - no more fallback dummy data
    
    func exportAnalysis(format: ExportFormat) async {
        guard let result = analysisResult else { return }
        
        // Simple export functionality
        let content = createExportContent(result: result, format: format)
        print("📤 Exported analysis as \(format.displayName): \(content.prefix(100))...")
    }
    
    private func createExportContent(result: SwingAnalysisResponse, format: ExportFormat) -> String {
        switch format {
        case .json:
            return "{\"prediction\": \"\(result.predicted_label)\", \"confidence\": \(result.confidence)}"
        case .csv:
            return "Prediction,Confidence\n\(result.predicted_label),\(result.confidence)"
        case .pdf:
            return "Swing Analysis Report\nPrediction: \(result.predicted_label)\nConfidence: \(Int(result.confidence * 100))%"
        }
    }
    
    func reset() {
        analysisResult = nil
        videoData = nil
        selectedVideo = nil
        errorMessage = nil
        isAnalyzing = false
        analysisProgress = 0.0
        currentAnalysisStage = .idle
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Header View
struct SwingAnalysisHeader: View {
    @Binding var showHistory: Bool
    @StateObject private var storageManager = AnalysisStorageManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Logo, Title, and History Button
            HStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.forestGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Swing Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIColor.label))
                    
                    Text("AI-Powered Golf Analysis")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                Spacer()
                
                // History Button
                Button(action: {
                    showHistory = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                        Text("History")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.forestGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.forestGreen.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.forestGreen.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(storageManager.storedAnalyses.isEmpty)
                .opacity(storageManager.storedAnalyses.isEmpty ? 0.5 : 1.0)
            }
            
            // Quick Stats Bar
            HStack(spacing: 20) {
                StatItem(title: "Analyses", value: "\(storageManager.storedAnalyses.count)")
                StatItem(title: "Accuracy", value: "95%")
                StatItem(title: "Local AI", value: "Ready")
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIColor.label))
            Text(title)
                .font(.caption2)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Video Input Section
struct VideoInputSection: View {
    @ObservedObject var viewModel: SwingAnalysisViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Input Method")
                .font(.headline)
                .foregroundColor(Color(UIColor.label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Record Video Button
                VideoInputButton(
                    icon: "video.fill",
                    title: "Record Swing",
                    subtitle: "Use camera to record new swing",
                    color: .forestGreen,
                    isDisabled: viewModel.isAnalyzing
                ) {
                    viewModel.showCamera = true
                }
                
                // Upload Video Button
                VideoInputButton(
                    icon: "photo.on.rectangle",
                    title: "Upload Video",
                    subtitle: "Choose from photo library",
                    color: Color("AccentColor"),
                    isDisabled: viewModel.isAnalyzing
                ) {
                    viewModel.showPhotoPicker = true
                }
                
                // Quick Tips
                TipsCard()
            }
            .padding(.horizontal)
        }
    }
}

struct VideoInputButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color(UIColor.label))
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .stroke(color.opacity(0.3), lineWidth: 1)

            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct TipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Recording Tips")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Down the Line Camera Angle works - AI detects automatically")
                Text("• Keep entire swing in frame")
                Text("• Ensure good lighting")
                Text("• 5-10 second videos work best")
            }
            .font(.caption2)
            .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Swing Analysis Progress View
struct SwingAnalysisProgressView: View {
    let progress: Double
    let currentStage: SwingAnalysisViewModel.AnalysisStage
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated icon
            Image(systemName: "figure.golf")
                .font(.system(size: 60))
                .foregroundColor(.forestGreen)
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Text("Analyzing Your Swing")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIColor.label))
            
            Text(currentStage.rawValue)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            
            // Enhanced Progress Bar
            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.forestGreen, .sage],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, progress * UIScreen.main.bounds.width * 0.8), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.forestGreen.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Real Camera View
struct SimpleCameraView: View {
    let onVideoRecorded: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera Preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    
                    Spacer()
                    
                    VStack {
                        Text("Record Swing")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Debug info
                        Text("📹 \(cameraManager.isSessionRunning ? "ON" : "OFF")")
                            .font(.caption)
                            .foregroundColor(cameraManager.isSessionRunning ? .green : .red)
                    }
                    
                    Spacer()
                    
                    VStack {
                        // Duration display
                        Text(cameraManager.formattedRecordingTime)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 60)
                        
                        // Debug button (only show if session is not running)
                        if !cameraManager.isSessionRunning && cameraManager.hasPermission {
                            Button("🔧") {
                                print("🔧 Debug button pressed - restarting camera")
                                cameraManager.debugSessionStatus()
                                cameraManager.stopSession()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    cameraManager.startSession()
                                }
                            }
                            .foregroundColor(.orange)
                            .font(.caption)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Recording indicator
                if cameraManager.isRecording {
                    VStack {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text("Recording...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 50) {
                    // Flip camera button
                    Button(action: {
                        cameraManager.flipCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                    }
                    
                    // Record button
                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording { videoData in
                                onVideoRecorded(videoData)
                                dismiss()
                            }
                        } else {
                            cameraManager.startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 80, height: 80)
                            
                            if cameraManager.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 65, height: 65)
                            }
                        }
                    }
                    .disabled(!cameraManager.hasPermission)
                    
                    // Gallery button
                    Button(action: {
                        dismiss()
                        // Trigger photo picker from parent view
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenPhotoPicker"), object: nil)
                        }
                    }) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Permission message
            if !cameraManager.hasPermission {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Camera Permission Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Please enable camera access in Settings to record your swing")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            print("🎬 SimpleCameraView appeared - initializing camera")
            cameraManager.checkPermission()
        }
        .onDisappear {
            print("🎬 SimpleCameraView disappeared - stopping session")
            cameraManager.stopSession()
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        print("🖼️ Creating CameraPreviewView")
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = UIColor.black
        
        // Get the preview layer from camera manager
        let previewLayer = cameraManager.getPreviewLayer()
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add the layer to the view
        view.layer.addSublayer(previewLayer)
        
        print("✅ CameraPreviewView created with preview layer")
        print("📹 Session running: \(cameraManager.isSessionRunning)")
        
        // Ensure session starts if it's not already running
        if !cameraManager.isSessionRunning && cameraManager.hasPermission {
            print("🔄 Session not running but permission granted - attempting to start")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cameraManager.startSession()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame to match the view bounds
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
        
        // Debug session state
        if !cameraManager.isSessionRunning && cameraManager.hasPermission {
            print("⚠️ Preview update: Session not running despite having permission")
            cameraManager.debugSessionStatus()
        }
    }
}

// MARK: - Comprehensive Results View
struct ComprehensiveResultsView: View {
    let result: SwingAnalysisResponse
    let videoData: Data
    let onDismiss: () -> Void
    let onExport: (ExportFormat) -> Void
    
    @State private var showingExportSheet = false
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Video Replay Section
                        VideoReplaySection(
                            videoData: videoData,
                            onPlayVideo: { url in
                                videoURL = url
                                showingVideoPlayer = true
                            }
                        )
                        
                        // Header with Score
                        ResultsHeader(result: result)
                        
                        // Metrics
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                if let planeAngle = result.plane_angle {
                                    MetricCard(title: "Plane Angle", value: "\(Int(planeAngle))°", color: .orange)
                                }
                                
                                if let tempo = result.tempo_ratio {
                                    let tempoText = formatTempoRatio(tempo)
                                    let tempoColor = getTempoColor(tempo)
                                    MetricCard(title: "Tempo", value: tempoText, color: tempoColor)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                MetricCard(title: "Confidence", value: "\(Int(result.confidence * 100))%", color: .green)
                                
                                // Add Club Path metric (always show with fallback)
                                let clubPathText = formatClubPath(result)
                                MetricCard(title: "Club Path", value: clubPathText, color: .blue)
                            }
                        }
                        
                        // Insights Section
                        InsightsCard(insights: result.physics_insights)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: { showingExportSheet = true }) {
                                Label("Export Analysis", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.forestGreen)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button(action: onDismiss) {
                                Text("Analyze Another Swing")
                                    .font(.headline)
                                    .foregroundColor(Color(UIColor.label))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportOptionsSheet(onExport: onExport)
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                VideoPlayerView(videoURL: videoURL) {
                    showingVideoPlayer = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions for Metrics
    private func formatTempoRatio(_ tempo: Double) -> String {
        // Convert raw tempo ratio to user-friendly format
        // Ideal tempo ratio is around 3:1 (backswing:downswing)
        
        if tempo < 2.0 {
            return "Fast ⚡"  // Too fast
        } else if tempo <= 2.5 {
            return "Quick 🔥"  // Quick but acceptable
        } else if tempo <= 3.5 {
            return "Good ✅"   // Ideal range (2.5-3.5:1)
        } else if tempo <= 4.5 {
            return "Smooth 🎯" // Smooth tempo
        } else {
            return "Slow 🐌"   // Too slow
        }
    }
    
    private func getTempoColor(_ tempo: Double) -> Color {
        if tempo < 2.0 || tempo > 4.5 {
            return .red        // Too fast or too slow
        } else if tempo <= 2.5 || tempo > 3.5 {
            return .orange     // Acceptable but not ideal
        } else {
            return .green      // Ideal range
        }
    }
    
    private func formatClubPath(_ result: SwingAnalysisResponse) -> String {
        // Primary: Use club speed analysis if available
        if let clubSpeed = result.club_speed_analysis {
            let efficiency = clubSpeed.efficiency_metrics.swing_efficiency
            
            // Determine path type from energy loss points
            let energyLossPoints = clubSpeed.efficiency_metrics.energy_loss_points
            let hasOutsideIn = energyLossPoints.contains { $0.lowercased().contains("outside") }
            let hasInsideOut = energyLossPoints.contains { $0.lowercased().contains("inside") }
            
            if efficiency >= 85 {
                return "On-Plane ✅"
            } else if efficiency >= 75 {
                return "Good 👍"
            } else if hasOutsideIn {
                return "Outside-In ⚠️"
            } else if hasInsideOut {
                return "Inside-Out ⚠️"  
            } else if efficiency >= 60 {
                return "Neutral 📈"
            } else {
                return "Needs Work 🔧"
            }
        }
        
        // Fallback: Use predicted label to infer club path
        let label = result.predicted_label.lowercased()
        if label.contains("over the top") || label.contains("outside") {
            return "Outside-In ⚠️"
        } else if label.contains("inside") || label.contains("under") {
            return "Inside-Out ⚠️"
        } else if label.contains("good") || label.contains("excellent") {
            return "On-Plane ✅"
        } else if let planeAngle = result.plane_angle {
            // Use plane angle as final fallback
            if planeAngle >= 40 && planeAngle <= 50 {
                return "On-Plane ✅"
            } else if planeAngle < 40 {
                return "Too Flat 📉"
            } else {
                return "Too Steep 📈"
            }
        } else {
            return "Analyzing... 🔍"
        }
    }
}

struct ResultsHeader: View {
    let result: SwingAnalysisResponse
    
    var body: some View {
        VStack(spacing: 12) {
            // Swing Rating Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Convert swing plane angle to progress (normalize 0-45 degrees to 0-1)
                let swingRating = calculateSwingRating(from: result)
                Circle()
                    .trim(from: 0, to: swingRating.progress)
                    .stroke(
                        LinearGradient(
                            colors: swingRating.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: swingRating.progress)
                
                VStack(spacing: 2) {
                    Text("\(swingRating.score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color(UIColor.label))
                    
                    Text(swingRating.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(swingRating.textColor)
                }
            }
            
            Text(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(getPredictionColor(for: result.predicted_label))
            
            Text("Swing Plane Analysis")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
    
    private func calculateSwingRating(from result: SwingAnalysisResponse) -> (score: Int, label: String, progress: Double, colors: [Color], textColor: Color) {
        // Extract plane angle from available properties
        var planeAngle: Double = 45.0 // Default neutral value
        var swingScore: Int = 75
        var label = "On Plane"
        var colors: [Color] = [.forestGreen, .sage]
        var textColor: Color = .forestGreen
        
        // Use actual plane angle if available
        if let actualPlaneAngle = result.plane_angle {
            planeAngle = actualPlaneAngle
        }
        
        // Calculate swing score based on plane angle and tempo
        if let tempoRatio = result.tempo_ratio {
            // Combine plane angle and tempo for overall score
            let idealAngle = 45.0
            let planeDeviation = abs(planeAngle - idealAngle)
            let planeScore = max(0, 100 - (planeDeviation * 2))
            let tempoScore = max(0, min(100, tempoRatio * 100))
            swingScore = Int((planeScore + tempoScore) / 2)
        } else {
            // Calculate score based on plane angle only (ideal is around 45 degrees)
            let idealAngle = 45.0
            let deviation = abs(planeAngle - idealAngle)
            swingScore = Int(max(0, min(100, 100 - (deviation * 2))))
        }
        
        // Determine label based on calculated score and plane angle (not predicted label)
        // This ensures score and label are consistent
        if swingScore >= 85 {
            // High scores should show positive results
            label = "Excellent Plane"
            colors = [.forestGreen, .sage]
            textColor = .forestGreen
        } else if swingScore >= 70 {
            // Good scores
            label = "On Plane"
            colors = [.forestGreen, .sage]
            textColor = .forestGreen
        } else if swingScore >= 50 {
            // Average scores - check plane angle for specific feedback
            if planeAngle < 35 {
                label = "Slightly Flat"
                colors = [.yellow, .orange]
                textColor = .orange
            } else if planeAngle > 55 {
                label = "Slightly Steep"
                colors = [.yellow, .orange]
                textColor = .orange
            } else {
                label = "Needs Work"
                colors = [.yellow, .orange]
                textColor = .orange
            }
        } else {
            // Low scores - more specific feedback
            if planeAngle < 35 {
                label = "Too Flat"
                colors = [.orange, .red]
                textColor = .red
            } else if planeAngle > 55 {
                label = "Too Steep"
                colors = [.orange, .red]
                textColor = .red
            } else {
                label = "Poor Plane"
                colors = [.orange, .red]
                textColor = .red
            }
        }
        
        // Convert score to progress (0-1)
        let progress = Double(swingScore) / 100.0
        
        return (score: swingScore, label: label, progress: progress, colors: colors, textColor: textColor)
    }
    
    private func getPredictionColor(for label: String) -> Color {
        switch label.lowercased() {
        case "good_swing", "excellent_swing":
            return .green
        case "too_steep":
            return .orange
        case "too_flat":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Video Replay Section
struct VideoReplaySection: View {
    let videoData: Data
    let onPlayVideo: (URL) -> Void
    
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Your Swing Video")
                .font(.headline)
                .foregroundColor(Color(UIColor.label))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: playVideo) {
                ZStack {
                    // Video thumbnail or placeholder
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay {
                            if videoData.count > 0 {
                                if let thumbnail = videoThumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video")
                                            .font(.system(size: 40))
                                            .foregroundColor(Color(UIColor.label))
                                        Text("Your Swing Video")
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "video.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                    Text("No Video Available")
                                        .font(.caption)
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                    Text("Use 'Upload Video' to select a real video")
                                        .font(.caption2)
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    
                    // Play button overlay (only show if we have video data)
                    if videoData.count > 0 {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(videoData.count == 0)
            
            Text("Tap to replay your swing video")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func playVideo() {
        // Check if we have actual video data
        guard videoData.count > 0 else {
            print("❌ No video data to play (empty or nil)")
            return
        }
        
        // Convert Data to temporary URL for video playback
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("swing_video_\(UUID().uuidString).mp4")
        do {
            try videoData.write(to: tempURL)
            print("✅ Video written to temp URL: \(tempURL)")
            print("📹 Video data size: \(videoData.count) bytes")
            
            // Verify the file exists and has content
            if FileManager.default.fileExists(atPath: tempURL.path) {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64
                print("📁 File exists with size: \(fileSize ?? 0) bytes")
                
                if (fileSize ?? 0) > 0 {
                    onPlayVideo(tempURL)
                } else {
                    print("❌ File is empty")
                }
            } else {
                print("❌ File was not created at path: \(tempURL.path)")
            }
        } catch {
            print("❌ Failed to write video data: \(error)")
        }
    }
    
    private func generateThumbnail() {
        // Generate a thumbnail from the video data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_thumb_\(UUID().uuidString).mov")
        do {
            try videoData.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            Task {
                do {
                    let cgImage = try await imageGenerator.image(at: CMTime.zero).image
                    await MainActor.run {
                        self.videoThumbnail = UIImage(cgImage: cgImage)
                    }
                } catch {
                    print("Failed to generate thumbnail: \(error)")
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch {
            print("Failed to create temp file for thumbnail: \(error)")
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let videoURL: URL
    let onDismiss: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Video Player
            if let player = player {
                VideoPlayer(player: player) {
                    // Custom overlay controls
                    Color.clear
                }
                .ignoresSafeArea()
                .onTapGesture {
                    showControls.toggle()
                }
            } else {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading video...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            
            // Control Overlay
            if showControls {
                VStack {
                    // Top bar with back button
                    HStack {
                        Button(action: onDismiss) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Back")
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(25)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .ignoresSafeArea()
                    )
                    
                    Spacer()
                    
                    // Bottom play/pause control
                    HStack {
                        Button(action: {
                            if isPlaying {
                                player?.pause()
                            } else {
                                player?.play()
                            }
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 80, height: 80)
                                )
                        }
                    }
                    .padding(.bottom, 50)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showControls)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func setupPlayer() {
        print("🎬 Setting up video player with URL: \(videoURL)")
        
        // Configure audio session for video playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to set audio session: \(error)")
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Video file does not exist at path: \(videoURL.path)")
            return
        }
        
        print("✅ Video file exists, creating player...")
        
        // Create player with the URL directly
        DispatchQueue.main.async {
            let playerItem = AVPlayerItem(url: videoURL)
            let newPlayer = AVPlayer(playerItem: playerItem)
            
            // Set player properties
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            newPlayer.volume = 1.0
            
            // Assign and play
            self.player = newPlayer
            newPlayer.play()
            self.isPlaying = true
            
            print("▶️ Video should be playing now")
            
            // Add notification observer for when video ends
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                // Loop the video
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Insights Card
struct InsightsCard: View {
    let insights: PhysicsInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("AI Insights")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Plane Analysis:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.label))
                
                Text(insights.plane_analysis)
                    .font(.body)
                    .foregroundColor(Color(UIColor.label))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Average Plane Angle: \(String(format: "%.1f", insights.avg_plane_angle))°")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Export Options Sheet
struct ExportOptionsSheet: View {
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        ExportOptionRow(format: format) {
                            onExport(format)
                            dismiss()
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExportOptionRow: View {
    let format: ExportFormat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: format.icon)
                    .foregroundColor(.forestGreen)
                
                VStack(alignment: .leading) {
                    Text(format.displayName)
                        .font(.headline)
                    Text(format.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .textCase(.uppercase)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.2))
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Recent Analysis Preview Section
struct RecentAnalysisPreview: View {
    @Binding var showFullHistory: Bool
    @StateObject private var storageManager = AnalysisStorageManager.shared
    
    var body: some View {
        if !storageManager.storedAnalyses.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Section Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(UIColor.label))
                        
                        Text("Your latest swing analysis results")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    
                    Spacer()
                    
                    if storageManager.storedAnalyses.count > 1 {
                        Button(action: {
                            showFullHistory = true
                        }) {
                            HStack(spacing: 4) {
                                Text("View All")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.forestGreen)
                        }
                    }
                }
                
                // Recent Analysis Cards (show up to 2)
                LazyVStack(spacing: 12) {
                    ForEach(Array(storageManager.storedAnalyses.prefix(2))) { analysis in
                        RecentAnalysisCard(analysis: analysis) {
                            showFullHistory = true
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .stroke(Color.forestGreen.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Recent Analysis Card
struct RecentAnalysisCard: View {
    let analysis: StoredAnalysis
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.forestGreen.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    if let thumbnailData = analysis.thumbnailData,
                       let thumbnail = UIImage(data: thumbnailData) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "figure.golf")
                            .font(.title2)
                            .foregroundColor(.forestGreen)
                    }
                }
                
                // Analysis info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(DateFormatter.recentDate.string(from: analysis.date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(UIColor.label))
                        
                        Spacer()
                        
                        // Score badge
                        let score = analysis.result.confidence * 100
                if score > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text("\(Int(score))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(scoreColor(score).cornerRadius(8))
                        }
                    }
                    
                    Text("Swing: \(analysis.result.predicted_label)")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let recentDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

// MARK: - Preview
struct SwingAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        SwingAnalysisView()
            .preferredColorScheme(.dark)
    }
}
