import Foundation
import SwiftUI
import AVFoundation

// MARK: - Supporting Types for SwingAnalysisView

enum AnalysisMode: String, CaseIterable {
    case local = "local"
    case server = "server"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .local: return "Local Only"
        case .server: return "Server Enhanced"
        case .hybrid: return "Hybrid Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "iphone"
        case .server: return "cloud"
        case .hybrid: return "icloud"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "All processing on device"
        case .server: return "Enhanced server analysis"
        case .hybrid: return "Best of both worlds"
        }
    }
}

struct SwingMetadata {
    let timestamp: Date
    let videoData: Data?
    let analysisResult: SwingAnalysisResponse?
    let userFeedback: String?
    let sessionId: String
    let videoDuration: TimeInterval?
    let deviceModel: String?
    let appVersion: String?
    let analysisDate: Date?
    let userSkillLevel: String?
    let clubType: String?
    let practiceOrRound: String?
    
    init(timestamp: Date = Date(), videoData: Data? = nil, analysisResult: SwingAnalysisResponse? = nil, userFeedback: String? = nil, sessionId: String = UUID().uuidString, videoDuration: TimeInterval? = nil, deviceModel: String? = nil, appVersion: String? = nil, analysisDate: Date? = nil, userSkillLevel: String? = nil, clubType: String? = nil, practiceOrRound: String? = nil) {
        self.timestamp = timestamp
        self.videoData = videoData
        self.analysisResult = analysisResult
        self.userFeedback = userFeedback
        self.sessionId = sessionId
        self.videoDuration = videoDuration
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.analysisDate = analysisDate
        self.userSkillLevel = userSkillLevel
        self.clubType = clubType
        self.practiceOrRound = practiceOrRound
    }
}

// The CentralizedModelImprovement and ModelFeedbackCollector classes are 
// implemented in their respective service files to avoid duplication.

@MainActor
class AnalysisExportManager: ObservableObject {
    static let shared = AnalysisExportManager()
    
    @Published var exportProgress: Double = 0.0
    @Published var isExporting = false
    
    private init() {}
    
    func exportAnalysis(_ analysis: SwingAnalysisResponse, videoData: Data?, format: ExportFormat) async throws -> URL {
        print("📤 Exporting analysis in \(format.rawValue) format")
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress
        for i in 0...10 {
            exportProgress = Double(i) / 10.0
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Create temporary export file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "swing_analysis_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let exportURL = tempDir.appendingPathComponent(filename)
        
        // Create export content based on format
        let content = createExportContent(analysis: analysis, format: format)
        try content.write(to: exportURL, atomically: true, encoding: .utf8)
        
        isExporting = false
        return exportURL
    }
    
    private func createExportContent(analysis: SwingAnalysisResponse, format: ExportFormat) -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(analysis),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        case .csv:
            return "Classification,Confidence,Plane Angle,Tempo\n\(analysis.predicted_label),\(analysis.confidence),\(analysis.plane_angle ?? 0),\(analysis.tempo_ratio ?? 0)"
        case .pdf:
            return """
            Swing Analysis Report
            ====================
            Classification: \(analysis.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
            Confidence: \(Int(analysis.confidence * 100))%
            Plane Angle: \(analysis.plane_angle ?? 0)°
            Tempo Ratio: \(analysis.tempo_ratio ?? 0)
            
            Recommendations:
            \(analysis.recommendations?.joined(separator: "\n• ") ?? "No recommendations available")
            """
        }
    }
}

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

// MARK: - Stored Analysis Model

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
    
    // Helper computed properties
    var confidencePercentage: Int {
        return Int(result.confidence * 100)
    }
    
    var swingType: String {
        return result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var analysisDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Analysis Storage Manager

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
    
    // MARK: - Save Analysis
    
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
    
    // MARK: - Load/Save to UserDefaults
    
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
            print("✅ Saved \(storedAnalyses.count) analyses to storage")
        } catch {
            print("❌ Failed to encode stored analyses: \(error)")
        }
    }
    
    // MARK: - Video File Management
    
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
    
    // MARK: - Utility Methods
    
    func getTotalStorageSize() -> String {
        let urls = try? FileManager.default.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: [.fileSizeKey])
        let totalBytes = urls?.compactMap { url in
            try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        }.reduce(0, +) ?? 0
        
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    func getAnalysisCount() -> Int {
        return storedAnalyses.count
    }
    
    func clearAllAnalyses() {
        // Delete all video files
        let urls = try? FileManager.default.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil)
        urls?.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
        
        // Clear array and save
        storedAnalyses.removeAll()
        saveStoredAnalyses()
        
        print("🗑️ Cleared all stored analyses")
    }
}

// MARK: - Analysis History View

struct AnalysisHistoryView: View {
    @StateObject private var storageManager = AnalysisStorageManager.shared
    @State private var selectedAnalysis: StoredAnalysis?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    @State private var showingDeleteAlert = false
    @State private var analysisToDelete: StoredAnalysis?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                if storageManager.storedAnalyses.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                        
                        Text("No Analysis History")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(UIColor.label))
                        
                        Text("Your swing analyses will appear here after you analyze videos")
                            .font(.body)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("Analyze Your First Swing") {
                            // Switch to Analysis tab
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToAnalysisTab"), object: nil)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    // Analysis list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(storageManager.storedAnalyses) { analysis in
                                AnalysisHistoryCard(
                                    analysis: analysis,
                                    onTap: {
                                        selectedAnalysis = analysis
                                    },
                                    onPlayVideo: {
                                        playVideo(for: analysis)
                                    },
                                    onDelete: {
                                        analysisToDelete = analysis
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Storage Info") {
                            // Show storage info
                        }
                        
                        if !storageManager.storedAnalyses.isEmpty {
                            Button("Clear All", role: .destructive) {
                                storageManager.clearAllAnalyses()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $selectedAnalysis) { analysis in
            AnalysisDetailView(analysis: analysis)
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                VideoPlayerView(videoURL: videoURL) {
                    showingVideoPlayer = false
                    self.videoURL = nil
                }
            }
        }
        .alert("Delete Analysis", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let analysis = analysisToDelete {
                    storageManager.deleteAnalysis(analysis)
                }
            }
        } message: {
            Text("This will permanently delete this swing analysis and video. This action cannot be undone.")
        }
    }
    
    private func playVideo(for analysis: StoredAnalysis) {
        if let url = storageManager.getVideoURL(for: analysis) {
            videoURL = url
            showingVideoPlayer = true
        }
    }
}

// MARK: - Analysis History Card

struct AnalysisHistoryCard: View {
    let analysis: StoredAnalysis
    let onTap: () -> Void
    let onPlayVideo: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 80, height: 60)
                        .overlay {
                            if let thumbnailData = analysis.thumbnailData,
                               let thumbnailImage = UIImage(data: thumbnailData) {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "video")
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                    
                    // Play button overlay
                    Button(action: onPlayVideo) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Analysis info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(analysis.swingType)
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        
                        Spacer()
                        
                        Text("\(analysis.confidencePercentage)%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(getConfidenceColor(analysis.result.confidence))
                    }
                    
                    Text(analysis.analysisDate)
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    
                    if let notes = analysis.userNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .lineLimit(2)
                    }
                }
                
                // Actions
                VStack {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getConfidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Analysis Detail View

struct AnalysisDetailView: View {
    let analysis: StoredAnalysis
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Video section
                    if let url = AnalysisStorageManager.shared.getVideoURL(for: analysis) {
                        VideoThumbnailView(analysis: analysis) {
                            videoURL = url
                            showingVideoPlayer = true
                        }
                    }
                    
                    // Results section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Analysis Results")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(UIColor.label))
                        
                        // Confidence score
                        HStack {
                            Text("Confidence")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            Text("\(analysis.confidencePercentage)%")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(getConfidenceColor(analysis.result.confidence))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Metrics
                        if let planeAngle = analysis.result.plane_angle {
                            MetricRow(title: "Plane Angle", value: "\(Int(planeAngle))°")
                        }
                        
                        if let tempoRatio = analysis.result.tempo_ratio {
                            MetricRow(title: "Tempo Ratio", value: String(format: "%.2f", tempoRatio))
                        }
                        
                        // Physics insights
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI Insights")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.label))
                            
                            Text(analysis.result.physics_insights.plane_analysis)
                                .font(.body)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Recommendations
                        if let recommendations = analysis.result.recommendations, !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recommendations")
                                    .font(.headline)
                                    .foregroundColor(Color(UIColor.label))
                                
                                ForEach(recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(Color("AccentColor"))
                                        Text(recommendation)
                                            .font(.body)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(analysis.swingType)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                VideoPlayerView(videoURL: videoURL) {
                    showingVideoPlayer = false
                    self.videoURL = nil
                }
            }
        }
    }
    
    private func getConfidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Supporting Views for History

struct VideoThumbnailView: View {
    let analysis: StoredAnalysis
    let onPlayVideo: () -> Void
    
    var body: some View {
        Button(action: onPlayVideo) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 200)
                    .overlay {
                        if let thumbnailData = analysis.thumbnailData,
                           let thumbnailImage = UIImage(data: thumbnailData) {
                            Image(uiImage: thumbnailImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Image(systemName: "video")
                                .font(.system(size: 40))
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                
                // Play button
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(Color(UIColor.label))
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}