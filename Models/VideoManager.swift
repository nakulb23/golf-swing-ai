import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - User Video Model

struct UserVideo: Identifiable, Codable {
    let id = UUID()
    let name: String
    let url: URL
    let duration: Double
    let createdAt: Date
    let fileSize: Int64
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Manager

@MainActor
class VideoManager: ObservableObject {
    @Published var userVideos: [UserVideo] = []
    @Published var selectedVideo: UserVideo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let documentsDirectory: URL
    private let videosDirectory: URL
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        videosDirectory = documentsDirectory.appendingPathComponent("UserVideos")
        
        createVideosDirectoryIfNeeded()
        loadUserVideos()
    }
    
    // MARK: - Public Methods
    
    func addVideo(from url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let durationInSeconds = CMTimeGetSeconds(duration)
            
            // Generate unique filename
            let filename = "video_\(Date().timeIntervalSince1970).mov"
            let destinationURL = videosDirectory.appendingPathComponent(filename)
            
            // Copy video to documents directory
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Create UserVideo object
            let userVideo = UserVideo(
                name: filename,
                url: destinationURL,
                duration: durationInSeconds,
                createdAt: Date(),
                fileSize: fileSize
            )
            
            userVideos.append(userVideo)
            saveUserVideos()
            
            print("✅ Video saved successfully: \(filename)")
            
        } catch {
            errorMessage = "Failed to save video: \(error.localizedDescription)"
            print("❌ Error saving video: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteVideo(_ video: UserVideo) {
        do {
            try FileManager.default.removeItem(at: video.url)
            userVideos.removeAll { $0.id == video.id }
            
            if selectedVideo?.id == video.id {
                selectedVideo = nil
            }
            
            saveUserVideos()
            print("✅ Video deleted successfully")
            
        } catch {
            errorMessage = "Failed to delete video: \(error.localizedDescription)"
            print("❌ Error deleting video: \(error)")
        }
    }
    
    func selectVideo(_ video: UserVideo) {
        selectedVideo = video
    }
    
    func clearSelection() {
        selectedVideo = nil
    }
    
    // MARK: - Private Methods
    
    private func createVideosDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: videosDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Error creating videos directory: \(error)")
            }
        }
    }
    
    private func loadUserVideos() {
        do {
            let videoFiles = try FileManager.default.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            var videos: [UserVideo] = []
            
            for fileURL in videoFiles {
                if fileURL.pathExtension.lowercased() == "mov" || fileURL.pathExtension.lowercased() == "mp4" {
                    let asset = AVAsset(url: fileURL)
                    
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            let durationInSeconds = CMTimeGetSeconds(duration)
                            
                            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            let createdAt = attributes[.creationDate] as? Date ?? Date()
                            
                            let video = UserVideo(
                                name: fileURL.lastPathComponent,
                                url: fileURL,
                                duration: durationInSeconds,
                                createdAt: createdAt,
                                fileSize: fileSize
                            )
                            
                            await MainActor.run {
                                videos.append(video)
                                self.userVideos = videos.sorted { $0.createdAt > $1.createdAt }
                            }
                        } catch {
                            print("❌ Error loading video \(fileURL.lastPathComponent): \(error)")
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Error loading user videos: \(error)")
        }
    }
    
    private func saveUserVideos() {
        // User videos are automatically saved in the file system
        // This method can be used for additional metadata storage if needed
    }
}

// MARK: - Video Picker View

struct VideoPickerView: View {
    @ObservedObject var videoManager: VideoManager
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 16) {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.blue)
                    
                    Text("Upload Golf Swing Video")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select a video from your photo library to analyze with the Physics Engine")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Video Picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                        Text("Choose Video")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                
                if videoManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Processing video...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let errorMessage = videoManager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem = newItem else { return }
            
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    // Save to temporary file
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mov")
                    try? data.write(to: tempURL)
                    
                    await videoManager.addVideo(from: tempURL)
                    
                    if videoManager.errorMessage == nil {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - User Video Library View

struct UserVideoLibraryView: View {
    @ObservedObject var videoManager: VideoManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if videoManager.userVideos.isEmpty {
                    emptyStateView
                } else {
                    videoListView
                }
            }
            .navigationTitle("My Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "video.slash")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No Videos Yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Upload your first golf swing video to get started with physics analysis")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private var videoListView: some View {
        List {
            ForEach(videoManager.userVideos) { video in
                VideoLibraryRow(
                    video: video,
                    isSelected: videoManager.selectedVideo?.id == video.id,
                    onSelect: {
                        videoManager.selectVideo(video)
                        dismiss()
                    },
                    onDelete: {
                        videoManager.deleteVideo(video)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Video Library Row

struct VideoLibraryRow: View {
    let video: UserVideo
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemBackground))
                .frame(width: 80, height: 60)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Duration: \(video.formattedDuration)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                
                Text("Size: \(video.formattedFileSize)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button("Select") {
                    onSelect()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}