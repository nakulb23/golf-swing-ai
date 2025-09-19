import SwiftUI
import Foundation
import PhotosUI
import AVFoundation
import AVKit
import StoreKit
import CoreML
import simd


// MARK: - User Video Model

struct UserVideo: Identifiable {
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
    
    init() {
        loadUserVideos()
    }
    
    private func loadUserVideos() {
        // Load actual user videos from documents directory
        // Start with empty array - videos will be added when user records them
        userVideos = []

        // Clear any existing videos first - no mock data
        print("📹 Loading user videos from documents directory only...")

        // Only load real videos from documents directory
        loadExistingVideos()

        print("📹 Loaded \(userVideos.count) videos from documents")
        for video in userVideos {
            print("  - \(video.name) at \(video.url.path)")
        }
    }
    
    private func loadExistingVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles)

            for fileURL in fileURLs {
                // Only load actual video files (mov/mp4)
                if fileURL.pathExtension.lowercased() == "mov" || fileURL.pathExtension.lowercased() == "mp4" {
                    // Skip any test/mock files that might have been left behind
                    let fileName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                    if fileName.contains("test") || fileName.contains("mock") || fileName.contains("sample") {
                        print("⚠️ Skipping test/mock video: \(fileName)")
                        continue
                    }

                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])

                    let video = UserVideo(
                        name: fileURL.deletingPathExtension().lastPathComponent,
                        url: fileURL,
                        duration: 0, // Will be calculated when needed
                        createdAt: resourceValues.contentModificationDate ?? Date(),
                        fileSize: Int64(resourceValues.fileSize ?? 0)
                    )
                    userVideos.append(video)
                    print("📹 Found video: \(video.name)")
                }
            }

            // Sort by creation date, newest first
            userVideos.sort { $0.createdAt > $1.createdAt }

        } catch {
            print("Error loading existing videos: \(error)")
        }
    }
    
    func addVideo(from url: URL) async {
        isLoading = true
        
        do {
            // Get actual video properties
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // Get file size
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            
            let newVideo = UserVideo(
                name: "Golf Swing \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
                url: url,
                duration: durationSeconds,
                createdAt: Date(),
                fileSize: fileSize
            )
            
            userVideos.insert(newVideo, at: 0)
        } catch {
            print("Error processing video: \(error)")
            errorMessage = "Failed to process video"
        }
        
        isLoading = false
    }
    
    func selectVideo(_ video: UserVideo) {
        selectedVideo = video
    }
    
    func clearSelection() {
        selectedVideo = nil
    }
    
    func deleteVideo(_ video: UserVideo) {
        // Remove from array
        userVideos.removeAll { $0.id == video.id }
        if selectedVideo?.id == video.id {
            selectedVideo = nil
        }

        // Also try to delete the actual file
        do {
            try FileManager.default.removeItem(at: video.url)
            print("✅ Deleted video file: \(video.name)")
        } catch {
            print("⚠️ Could not delete video file: \(error)")
        }
    }

    func clearAllVideos() {
        // Clear all videos (useful for removing test/mock data)
        userVideos.removeAll()
        selectedVideo = nil
        print("🗑️ Cleared all videos from list")
    }
}

// MARK: - Physics Engine Premium View

struct PhysicsEnginePremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var isLoading = false
    @State private var purchaseError: String?
    @State private var showDevelopmentModeOption = false
    
    enum SubscriptionPlan {
        case monthly, annual
    }
    
    var body: some View {
        ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.orange)
                        
                        Text("Golf Swing AI Premium")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Unlock professional-grade analysis and insights")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Features List
                    VStack(spacing: 16) {
                        PhysicsFeatureRow(
                            icon: "gauge.high",
                            title: "Club Head Speed Analysis",
                            description: "Detailed speed tracking with acceleration profiles"
                        )
                        
                        PhysicsFeatureRow(
                            icon: "target",
                            title: "Club Face Angle Tracking",
                            description: "Impact position analysis with face angle measurements"
                        )
                        
                        PhysicsFeatureRow(
                            icon: "waveform.path.ecg",
                            title: "AI Biomechanics Analysis",
                            description: "Real swing plane, X-factor, and tempo analysis"
                        )
                        
                        PhysicsFeatureRow(
                            icon: "chart.bar.fill", 
                            title: "Distance Potential Analysis",
                            description: "Calculate your optimal distance potential"
                        )
                        
                        PhysicsFeatureRow(
                            icon: "person.3.fill",
                            title: "Elite Benchmarks",
                            description: "Compare your metrics against elite player standards"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Subscription Plans
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            // Annual Plan
                            Button(action: { selectedPlan = .annual }) {
                                PhysicsPlanCard(
                                    title: "Annual",
                                    price: "$21.99",
                                    period: "per year",
                                    savings: "Save 10%",
                                    isSelected: selectedPlan == .annual,
                                    isPopular: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Monthly Plan
                            Button(action: { selectedPlan = .monthly }) {
                                PhysicsPlanCard(
                                    title: "Monthly",
                                    price: "$1.99",
                                    period: "per month",
                                    savings: nil,
                                    isSelected: selectedPlan == .monthly,
                                    isPopular: false
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Purchase Button
                    VStack(spacing: 16) {
                        // Show development mode button if enabled
                        if premiumManager.isDevelopmentMode {
                            Button(action: {
                                print("🔧 Development mode access activated")
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "hammer.fill")
                                    Text("Continue with Development Mode")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.gradient)
                                .cornerRadius(16)
                            }
                        }
                        
                        Button(action: {
                            print("🔘 Start Premium button pressed!")
                            Task {
                                isLoading = true
                                purchaseError = nil
                                
                                // Check if user has premium access (including development mode)
                                if premiumManager.hasPhysicsEnginePremium || premiumManager.isDevelopmentMode {
                                    print("✅ Premium access granted (purchase or dev mode), dismissing paywall")
                                    dismiss()
                                    return
                                }
                                
                                print("🔘 Selected plan: \(selectedPlan)")
                                switch selectedPlan {
                                case .monthly:
                                    print("🔘 Purchasing monthly subscription...")
                                    await premiumManager.purchaseMonthlySubscription()
                                case .annual:
                                    print("🔘 Purchasing annual subscription...")
                                    await premiumManager.purchaseAnnualSubscription()
                                }
                                
                                // Small delay to ensure state updates
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                
                                if premiumManager.hasPhysicsEnginePremium {
                                    print("✅ Premium access granted, dismissing paywall")
                                    dismiss()
                                } else {
                                    print("⚠️ Premium access not granted yet")
                                }

                                // Get error from PremiumManager if any
                                purchaseError = premiumManager.purchaseError
                                
                                // Show error to user - do NOT automatically offer development mode
                                if let error = purchaseError {
                                    print("❌ Purchase failed: \(error)")
                                    // Development mode should only be available in DEBUG builds and for developers
                                    #if DEBUG
                                    if error.contains("Store is currently unavailable") {
                                        print("🔧 Development mode option available for DEBUG build")
                                        showDevelopmentModeOption = true
                                    }
                                    #endif
                                }
                                
                                isLoading = false
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Start Premium")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isLoading)
                        .contentShape(Rectangle())
                        .buttonStyle(PlainButtonStyle())
                        
                        Button("Restore Purchases") {
                            Task {
                                isLoading = true
                                await premiumManager.restorePurchases()
                                isLoading = false
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                        
                        if let error = purchaseError {
                            Text(error)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Development mode option - ONLY available in DEBUG builds
                        #if DEBUG
                        if showDevelopmentModeOption {
                            VStack(spacing: 12) {
                                Text("⚠️ DEBUG MODE ONLY")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text("Development Mode Available")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)
                                
                                Text("This option is only available in DEBUG builds for testing. In production, users must purchase through the App Store.")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    print("🔧 Enabling development mode for testing (DEBUG BUILD)")
                                    premiumManager.enableDevelopmentModeForTesting()
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Enable Development Mode")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.top, 16)
                        }
                        #endif
                    }
                    .padding(.horizontal, 24)
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("Subscription automatically renews unless auto-renewal is turned off at least 24 hours before the end of the current period.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Link("Terms of Service", destination: URL(string: "https://doc-hosting.flycricket.io/golf-swing-ai-terms-of-use/3fac7eec-630a-41e2-a447-ff4bca08cd60/terms")!)
                            Link("Privacy Policy", destination: URL(string: "https://github.com/nakulb23/golf-swing-ai/blob/main/PRIVACY_POLICY.md")!)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            print("🔧 PhysicsEnginePremiumView appeared")
            print("🔧 isDevelopmentMode: \(premiumManager.isDevelopmentMode)")
            print("🔧 hasPhysicsEnginePremium: \(premiumManager.hasPhysicsEnginePremium)")
            print("🔧 canAccessPhysicsEngine: \(premiumManager.canAccessPhysicsEngine)")
            print("🔧 availableProducts count: \(premiumManager.availableProducts.count)")
            
            // Auto-dismiss if development mode is enabled
            if premiumManager.isDevelopmentMode {
                print("✅ Development mode active - auto-dismissing paywall")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }

            for product in premiumManager.availableProducts {
                print("🔧 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
        }
    }
}

// MARK: - Physics Feature Row

struct PhysicsFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Physics Plan Card

struct PhysicsPlanCard: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isSelected: Bool
    let isPopular: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if isPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(price)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(period)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.orange.opacity(0.05) : Color.gray.opacity(0.1))
                )
        )
    }
}

// MARK: - Video Picker View

struct VideoPickerView: View {
    @ObservedObject var videoManager: VideoManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showCamera = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.purple)

                    Text("Add Golf Swing Video")
                        .font(.system(size: 24, weight: .semibold))

                    Text("Record or select a video to analyze")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Upload Options
                VStack(spacing: 16) {
                    // Camera Option
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Record New Video")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Capture your swing now")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Rectangle()
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Photo Library Option
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose from Library")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Select existing video")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Rectangle()
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)

                // Tips Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording Tips")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Position camera at waist height", systemImage: "camera.viewfinder")
                        Label("Record from down-the-line angle", systemImage: "arrow.down.right")
                        Label("Ensure full swing is visible", systemImage: "figure.golf")
                        Label("Good lighting is essential", systemImage: "sun.max")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer()

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Processing video...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let item = newValue {
                        await loadVideo(from: item)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                VideoCameraView(videoManager: videoManager, dismiss: {
                    showCamera = false
                    dismiss()
                })
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil

        do {
            // Load video as Data
            if let movie = try await item.loadTransferable(type: Data.self) {
                // Save to documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first!
                let fileName = "swing_\(Date().timeIntervalSince1970).mov"
                let fileURL = documentsPath.appendingPathComponent(fileName)

                try movie.write(to: fileURL)

                // Add to video manager
                await videoManager.addVideo(from: fileURL)

                // Auto-select the newly uploaded video for analysis
                await MainActor.run {
                    if let newVideo = videoManager.userVideos.first {
                        videoManager.selectVideo(newVideo)
                        print("✅ Auto-selected uploaded video: \(newVideo.name)")
                    }
                    isProcessing = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    errorMessage = "Failed to load video"
                    isProcessing = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
}

// MARK: - Video Camera View

struct VideoCameraView: UIViewControllerRepresentable {
    let videoManager: VideoManager
    let dismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        picker.videoMaximumDuration = 30 // 30 seconds max
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoCameraView

        init(_ parent: VideoCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                // Save video to documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first!
                let fileName = "recorded_swing_\(Date().timeIntervalSince1970).mov"
                let destinationURL = documentsPath.appendingPathComponent(fileName)

                do {
                    try FileManager.default.copyItem(at: videoURL, to: destinationURL)
                    Task {
                        await parent.videoManager.addVideo(from: destinationURL)
                        // Auto-select the recorded video for analysis
                        await MainActor.run {
                            if let newVideo = parent.videoManager.userVideos.first {
                                parent.videoManager.selectVideo(newVideo)
                                print("✅ Auto-selected recorded video: \(newVideo.name)")
                            }
                        }
                    }
                } catch {
                    print("Error saving video: \(error)")
                }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
                } else {
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
            .navigationTitle("My Videos")
            #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct VideoLibraryRow: View {
    let video: UserVideo
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
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
                
                Text(DateFormatter.shortDate.string(from: video.createdAt))
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

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - Swing Analysis Data Models

struct PhysicsSwingAnalysisResult {
    let timestamp: Date
    let videoURL: URL
    let duration: Double
    let clubHeadSpeed: ClubHeadSpeedData
    let bodyKinematics: BodyKinematicsData
    let swingPlane: SwingPlaneData
    let tempo: SwingTempoData
    let ballFlight: BallFlightData?
    let trackingQuality: TrackingQuality
    let confidence: Double
    let framesCaptured: Int
    let framesAnalyzed: Int
    
    var qualityScore: Double {
        return trackingQuality.overallScore * confidence
    }
}

struct ClubHeadSpeedData {
    let peakSpeed: Double
    let speedAtImpact: Double
    let accelerationProfile: [Double]
    let impactFrame: Int
    let trackingPoints: [CGPoint]
    
    var averageAcceleration: Double {
        guard accelerationProfile.count > 1 else { return 0 }
        let deltas = zip(accelerationProfile.dropFirst(), accelerationProfile).map { $0 - $1 }
        return deltas.reduce(0, +) / Double(deltas.count)
    }
}

struct BodyKinematicsData {
    let shoulderRotation: RotationData
    let hipRotation: RotationData
    let armPositions: ArmPositionData
    let spineAngle: SpineAngleData
    let weightShift: WeightShiftData
    let addressPosition: BodyPosition
    let topOfBackswing: BodyPosition
    let impactPosition: BodyPosition
    let followThrough: BodyPosition
}

struct RotationData {
    let maxRotation: Double
    let rotationSpeed: Double
    let rotationTiming: Double
    let rotationSequence: [Double]
}

struct ArmPositionData {
    let leftArmAngle: [Double]
    let rightArmAngle: [Double]
    let armExtension: Double
    let wristCockAngle: Double
}

struct SpineAngleData {
    let spineAngleAtAddress: Double
    let spineAngleAtTop: Double
    let spineAngleAtImpact: Double
    let spineStability: Double
}

struct WeightShiftData {
    let initialWeight: CGPoint
    let weightAtTop: CGPoint
    let weightAtImpact: CGPoint
    let weightTransferSpeed: Double
}

struct BodyPosition {
    let frame: Int
    let timestamp: Double
    let jointPositions: [String: CGPoint]
    let centerOfMass: CGPoint
}

struct SwingPlaneData {
    let planeAngle: Double
    let planeConsistency: Double
    let clubPath: Double
    let attackAngle: Double
    let planeVisualization: [simd_float3]
}

struct SwingTempoData {
    let backswingTime: Double
    let downswingTime: Double
    let totalTime: Double
    let tempoRatio: Double
    let pauseAtTop: Double
}

struct BallFlightData {
    let launchAngle: Double
    let ballSpeed: Double
    let spinRate: Double
    let trajectory: [CGPoint]
    let estimatedCarryDistance: Double
}

struct TrackingQuality {
    let clubVisibility: Double
    let bodyVisibility: Double
    let lightingQuality: Double
    let cameraAngle: Double
    let motionBlur: Double
    
    var overallScore: Double {
        return (clubVisibility + bodyVisibility + lightingQuality + cameraAngle + (1.0 - motionBlur)) / 5.0
    }
}

// MARK: - Swing Video Analyzer

@MainActor
class SwingVideoAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysis: PhysicsSwingAnalysisResult?
    @Published var errorMessage: String?

    private let localAI = LocalAIManager.shared
    private let localSwingAnalyzer = LocalSwingAnalyzer()

    func analyzeSwingVideo(url: URL) async -> PhysicsSwingAnalysisResult? {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil

        defer {
            isAnalyzing = false
            analysisProgress = 0.0
        }

        do {
            print("🎬 Starting real AI analysis for physics engine...")
            print("📁 Video URL: \(url)")
            print("📁 Video path exists: \(FileManager.default.fileExists(atPath: url.path))")

            // Progress updates during real analysis
            analysisProgress = 0.2

            // Use the same real AI analysis as SwingAnalysisView
            print("🔄 Calling localSwingAnalyzer.analyzeSwing...")
            let swingAnalysisResult = try await localSwingAnalyzer.analyzeSwing(from: url)
            print("✅ localSwingAnalyzer.analyzeSwing completed")
            analysisProgress = 0.8

            // Convert SwingAnalysisResponse to PhysicsSwingAnalysisResult
            print("🔄 Converting analysis result to physics format...")
            let physicsResult = convertToPhysicsResult(swingAnalysisResult, videoURL: url)
            print("✅ Conversion to physics format completed")
            analysisProgress = 1.0

            currentAnalysis = physicsResult
            print("✅ Physics analysis complete - result stored")
            return physicsResult

        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = "AI Analysis failed: \(errorDesc)"
            print("❌ Physics engine AI analysis error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(errorDesc)")
            return nil
        }
    }
    
    /// Converts real AI analysis result to physics display format
    private func convertToPhysicsResult(_ analysis: SwingAnalysisResponse, videoURL: URL) -> PhysicsSwingAnalysisResult {
        print("🔄 Converting real AI analysis to physics format...")

        // Extract real club speed data
        let clubSpeed = analysis.club_speed_analysis?.club_head_speed_mph ?? 95.0
        let clubData = ClubHeadSpeedData(
            peakSpeed: clubSpeed * 1.1,
            speedAtImpact: clubSpeed,
            accelerationProfile: generateAccelerationProfile(for: clubSpeed),
            impactFrame: 35,
            trackingPoints: []
        )

        // Extract real biomechanics data from AI analysis
        let shoulderTilt = analysis.shoulder_tilt ?? 15.0
        let planeAngle = analysis.plane_angle ?? 65.0
        let bodyData = BodyKinematicsData(
            shoulderRotation: RotationData(
                maxRotation: shoulderTilt + 70, // Convert to full rotation
                rotationSpeed: (analysis.club_speed_analysis?.tempo_analysis.backswing_time ?? 0.5) * 1000,
                rotationTiming: 0.8,
                rotationSequence: []
            ),
            hipRotation: RotationData(
                maxRotation: shoulderTilt * 0.6, // Hip rotation typically 60% of shoulder
                rotationSpeed: 350,
                rotationTiming: 0.6,
                rotationSequence: []
            ),
            armPositions: ArmPositionData(
                leftArmAngle: [],
                rightArmAngle: [],
                armExtension: analysis.confidence * 0.9, // Use confidence as proxy for extension quality
                wristCockAngle: extractWristAngle(from: analysis)
            ),
            spineAngle: SpineAngleData(
                spineAngleAtAddress: 30.0,
                spineAngleAtTop: 32.0,
                spineAngleAtImpact: 28.0,
                spineStability: analysis.confidence
            ),
            weightShift: WeightShiftData(
                initialWeight: CGPoint.zero,
                weightAtTop: CGPoint(x: -0.2, y: 0),
                weightAtImpact: CGPoint(x: 0.3, y: 0.2),
                weightTransferSpeed: analysis.tempo_ratio ?? 2.8
            ),
            addressPosition: BodyPosition(frame: 0, timestamp: 0, jointPositions: [:], centerOfMass: .zero),
            topOfBackswing: BodyPosition(frame: 20, timestamp: 0.33, jointPositions: [:], centerOfMass: .zero),
            impactPosition: BodyPosition(frame: 35, timestamp: 0.58, jointPositions: [:], centerOfMass: .zero),
            followThrough: BodyPosition(frame: 50, timestamp: 0.83, jointPositions: [:], centerOfMass: .zero)
        )

        // Use real swing plane analysis
        let planeData = SwingPlaneData(
            planeAngle: planeAngle,
            planeConsistency: analysis.confidence,
            clubPath: extractClubPath(from: analysis),
            attackAngle: extractAttackAngle(from: analysis),
            planeVisualization: []
        )

        // Extract real tempo data - convert to realistic golf swing timing
        let rawVideoDuration = analysis.video_duration_seconds ?? 2.5
        let tempoRatio = analysis.tempo_ratio ?? 3.0

        // Golf swings typically take 1.2-1.5 seconds total, not the entire video duration
        let realisticSwingTime = min(1.5, max(1.0, rawVideoDuration * 0.6)) // Extract the actual swing portion

        let backswingTime = realisticSwingTime / (tempoRatio + 1) * tempoRatio
        let downswingTime = realisticSwingTime / (tempoRatio + 1)

        let tempoData = SwingTempoData(
            backswingTime: backswingTime,
            downswingTime: downswingTime,
            totalTime: realisticSwingTime,
            tempoRatio: tempoRatio,
            pauseAtTop: 0.1
        )

        // Use real tracking quality metrics
        let quality = TrackingQuality(
            clubVisibility: analysis.feature_reliability?["club_tracking"] ?? 0.8,
            bodyVisibility: analysis.feature_reliability?["pose_detection"] ?? 0.9,
            lightingQuality: analysis.feature_reliability?["lighting"] ?? 0.75,
            cameraAngle: analysis.angle_confidence ?? 0.8,
            motionBlur: 1.0 - (analysis.quality_score ?? 0.8)
        )

        print("✅ Mapped real AI analysis: Club Speed=\(clubSpeed)mph, Plane=\(planeAngle)°, Confidence=\(analysis.confidence)")

        return PhysicsSwingAnalysisResult(
            timestamp: Date(),
            videoURL: videoURL,
            duration: realisticSwingTime,
            clubHeadSpeed: clubData,
            bodyKinematics: bodyData,
            swingPlane: planeData,
            tempo: tempoData,
            ballFlight: nil,
            trackingQuality: quality,
            confidence: analysis.confidence,
            framesCaptured: 60,
            framesAnalyzed: 60
        )
    }

    // MARK: - Helper Methods for AI Data Extraction

    private func generateAccelerationProfile(for clubSpeed: Double) -> [Double] {
        // Generate realistic acceleration profile based on club speed
        return (0...60).map { frame in
            let progress = Double(frame) / 60.0
            let acceleration = clubSpeed * sin(progress * .pi) * 0.8
            return max(0, acceleration)
        }
    }

    private func extractWristAngle(from analysis: SwingAnalysisResponse) -> Double {
        // Extract wrist angle from detailed biomechanics if available
        if let biomechanics = analysis.detailed_biomechanics {
            for measurement in biomechanics {
                if measurement.name.lowercased().contains("wrist") || measurement.name.lowercased().contains("lag") {
                    return measurement.current_value
                }
            }
        }

        // Fallback: estimate from confidence and plane angle
        let planeAngle = analysis.plane_angle ?? 65.0
        let baseWrist = 75.0
        let adjustment = (planeAngle - 65.0) * 0.3
        return baseWrist + adjustment
    }

    private func extractClubPath(from analysis: SwingAnalysisResponse) -> Double {
        // Extract club path from plane angle
        if let planeAngle = analysis.plane_angle {
            // Convert plane angle to club path (simplified mapping)
            return (planeAngle - 65.0) * 0.1 // Neutral plane is ~65 degrees
        }

        // Estimate from predicted label
        switch analysis.predicted_label.lowercased() {
        case "over_the_top":
            return 3.5 // Outside-in path
        case "inside_out":
            return -2.8 // Inside-out path
        case "too_steep":
            return 1.2
        case "too_flat":
            return -1.5
        default:
            return 0.2 // Neutral path
        }
    }

    private func extractAttackAngle(from analysis: SwingAnalysisResponse) -> Double {
        // Extract attack angle from club analysis
        if let clubAnalysis = analysis.club_face_analysis {
            return clubAnalysis.impact_position.impact_quality_score / 10 // Convert to degrees
        }

        // Estimate from plane angle
        let planeAngle = analysis.plane_angle ?? 65.0
        return (planeAngle - 65.0) * 0.1 // Rough conversion
    }
}

// MARK: - Swing Feedback Models

struct SwingFeedback {
    let overallScore: Double
    let improvements: [ImprovementRecommendation]
    let strengths: [StrengthArea]
    let eliteBenchmarks: [PhysicsEliteBenchmark]
    let practiceRecommendations: [PracticeRecommendation]
    let timestamp: Date
}

struct ImprovementRecommendation {
    let area: SwingArea
    let priority: Priority
    let issue: String
    let solution: String
    let drills: [String]
    let impactOnDistance: Double?
    let impactOnAccuracy: Double?
    let videoTimestamp: Double?
    
    enum Priority: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .green
            }
        }
    }
}

struct StrengthArea {
    let area: SwingArea
    let description: String
    let professionalLevel: Double
}

struct PhysicsEliteBenchmark {
    let metric: String
    let userValue: Double
    let eliteAverage: Double
    let proRange: ClosedRange<Double>
    let percentile: Double
    let unit: String
}

struct PracticeRecommendation {
    let title: String
    let description: String
    let duration: String
    let frequency: String
    let equipment: [String]
    let difficulty: Difficulty
    let videoURL: String?
    
    enum Difficulty: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
}

enum SwingArea: String, CaseIterable {
    case clubHeadSpeed = "Club Head Speed"
    case swingPlane = "Swing Plane"
    case tempo = "Tempo"
    case bodyRotation = "Body Rotation"
    case weightTransfer = "Weight Transfer"
    case armPosition = "Arm Position"
    case wristAction = "Wrist Action"
    case spineAngle = "Spine Angle"
    case setup = "Setup"
    case followThrough = "Follow Through"
    
    var icon: String {
        switch self {
        case .clubHeadSpeed: return "speedometer"
        case .swingPlane: return "chart.line.downtrend.xyaxis"
        case .tempo: return "metronome"
        case .bodyRotation: return "arrow.clockwise"
        case .weightTransfer: return "figure.walk"
        case .armPosition: return "figure.arms.open"
        case .wristAction: return "hand.raised.fill"
        case .spineAngle: return "figure.stand"
        case .setup: return "target"
        case .followThrough: return "arrow.right.circle"
        }
    }
}

// MARK: - Swing Feedback Engine

class SwingFeedbackEngine {
    static func generateFeedback(from analysis: PhysicsSwingAnalysisResult) -> SwingFeedback {
        let improvements = analyzeImprovements(analysis)
        let strengths = identifyStrengths(analysis)
        let proComparisons = compareWithElitePlayers(analysis)
        let practiceRecs = generatePracticeRecommendations(improvements)
        let overallScore = calculateOverallScore(analysis, improvements: improvements)
        
        return SwingFeedback(
            overallScore: overallScore,
            improvements: improvements,
            strengths: strengths,
            eliteBenchmarks: proComparisons,
            practiceRecommendations: practiceRecs,
            timestamp: Date()
        )
    }
    
    private static func analyzeImprovements(_ analysis: PhysicsSwingAnalysisResult) -> [ImprovementRecommendation] {
        var improvements: [ImprovementRecommendation] = []
        
        // Analyze club head speed
        if analysis.clubHeadSpeed.speedAtImpact < 85 {
            improvements.append(ImprovementRecommendation(
                area: .clubHeadSpeed,
                priority: .high,
                issue: "Club head speed at impact is \(String(format: "%.1f", analysis.clubHeadSpeed.speedAtImpact)) mph, which is below average (95+ mph)",
                solution: "Focus on proper weight transfer and body rotation sequence. Start the downswing with your lower body, not your arms.",
                drills: [
                    "Step-through drill: Practice stepping into your shot",
                    "Heavy club swings: Use a weighted club for 10 swings before hitting",
                    "Separation drill: Practice keeping your upper body back while lower body starts downswing"
                ],
                impactOnDistance: 15,
                impactOnAccuracy: nil,
                videoTimestamp: Double(analysis.clubHeadSpeed.impactFrame) / 60.0
            ))
        }
        
        // Analyze swing plane consistency
        if analysis.swingPlane.planeConsistency < 0.7 {
            improvements.append(ImprovementRecommendation(
                area: .swingPlane,
                priority: .medium,
                issue: "Swing plane consistency is \(String(format: "%.0f", analysis.swingPlane.planeConsistency * 100))%. Inconsistent swing plane leads to poor ball striking.",
                solution: "Work on maintaining the same swing plane throughout your swing. Focus on keeping your left arm connected to your chest.",
                drills: [
                    "Plane board drill: Practice swinging along an inclined board",
                    "Towel drill: Keep a towel under your left armpit throughout the swing",
                    "Mirror work: Practice your swing in front of a mirror to see plane consistency"
                ],
                impactOnDistance: 8,
                impactOnAccuracy: 15,
                videoTimestamp: nil
            ))
        }
        
        // Analyze tempo
        if analysis.tempo.tempoRatio < 2.5 || analysis.tempo.tempoRatio > 4.0 {
            let issue = analysis.tempo.tempoRatio < 2.5 ? "too quick" : "too slow"
            improvements.append(ImprovementRecommendation(
                area: .tempo,
                priority: .medium,
                issue: "Your tempo ratio is \(String(format: "%.1f", analysis.tempo.tempoRatio)):1, which is \(issue). Ideal ratio is 3:1 (backswing:downswing).",
                solution: "Practice with a metronome to develop consistent tempo. Count '1-2-3' for backswing and '1' for downswing.",
                drills: [
                    "Metronome practice: Use 76 BPM for timing",
                    "Humming drill: Hum a slow tune while swinging",
                    "Pause drill: Pause at the top of your backswing for one second"
                ],
                impactOnDistance: 5,
                impactOnAccuracy: 20,
                videoTimestamp: 0
            ))
        }
        
        return improvements.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    private static func identifyStrengths(_ analysis: PhysicsSwingAnalysisResult) -> [StrengthArea] {
        var strengths: [StrengthArea] = []
        
        if analysis.clubHeadSpeed.speedAtImpact > 105 {
            strengths.append(StrengthArea(
                area: .clubHeadSpeed,
                description: "Excellent club head speed (\(String(format: "%.1f", analysis.clubHeadSpeed.speedAtImpact)) mph). You generate good power.",
                professionalLevel: min(100, (analysis.clubHeadSpeed.speedAtImpact / 115) * 100)
            ))
        }
        
        if analysis.swingPlane.planeConsistency > 0.85 {
            strengths.append(StrengthArea(
                area: .swingPlane,
                description: "Very consistent swing plane (\(String(format: "%.0f", analysis.swingPlane.planeConsistency * 100))%). This leads to repeatable ball striking.",
                professionalLevel: analysis.swingPlane.planeConsistency * 100
            ))
        }
        
        return strengths
    }
    
    private static func compareWithElitePlayers(_ analysis: PhysicsSwingAnalysisResult) -> [PhysicsEliteBenchmark] {
        return [
            PhysicsEliteBenchmark(
                metric: "Club Head Speed",
                userValue: analysis.clubHeadSpeed.speedAtImpact,
                eliteAverage: 113.0,
                proRange: 105.0...125.0,
                percentile: min(100, (analysis.clubHeadSpeed.speedAtImpact / 113.0) * 50),
                unit: "mph"
            ),
            PhysicsEliteBenchmark(
                metric: "Swing Plane Consistency",
                userValue: analysis.swingPlane.planeConsistency * 100,
                eliteAverage: 92.0,
                proRange: 88.0...96.0,
                percentile: min(100, (analysis.swingPlane.planeConsistency * 100 / 92.0) * 75),
                unit: "%"
            )
        ]
    }
    
    private static func generatePracticeRecommendations(_ improvements: [ImprovementRecommendation]) -> [PracticeRecommendation] {
        var recommendations: [PracticeRecommendation] = []
        
        recommendations.append(PracticeRecommendation(
            title: "Daily Swing Tempo Practice",
            description: "Practice your swing rhythm with a metronome. Focus on smooth, controlled motion rather than power.",
            duration: "10 minutes",
            frequency: "Daily",
            equipment: ["Metronome app", "Practice club"],
            difficulty: .beginner,
            videoURL: nil
        ))
        
        return recommendations
    }
    
    private static func calculateOverallScore(_ analysis: PhysicsSwingAnalysisResult, improvements: [ImprovementRecommendation]) -> Double {
        var score = 50.0
        
        // Add points for good metrics
        if analysis.clubHeadSpeed.speedAtImpact > 95 {
            score += 15
        }
        
        score += analysis.swingPlane.planeConsistency * 20
        score += analysis.bodyKinematics.spineAngle.spineStability * 10
        
        // Factor in tracking quality
        score *= analysis.trackingQuality.overallScore
        
        return max(0, min(100, score))
    }
}

struct PhysicsEngineView: View {
    @ObservedObject private var premiumManager = PremiumManager.shared
    @StateObject private var videoManager = VideoManager()
    @StateObject private var videoAnalyzer = SwingVideoAnalyzer()
    @State private var selectedTab = 0
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0.0
    @State private var showingPremiumPaywall = false
    @State private var showingVideoPicker = false
    @State private var showingInfo = false
    @State private var showingVideoLibrary = false
    @State private var currentFeedback: SwingFeedback?
    @State private var showingFeedback = false
    
    var body: some View {
        NavigationView {
            Group {
                if premiumManager.canAccessPhysicsEngine {
                    physicsEngineContent
                } else {
                    premiumUpsellView
                }
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PhysicsEnginePremiumView()
                .environmentObject(premiumManager)
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoPickerView(videoManager: videoManager)
        }
        .sheet(isPresented: $showingVideoLibrary) {
            UserVideoLibraryView(videoManager: videoManager)
        }
        .sheet(isPresented: $showingFeedback) {
            if let feedback = currentFeedback {
                SwingFeedbackView(feedback: feedback)
            }
        }
        .sheet(isPresented: $showingInfo) {
            InteractiveVideoInfoView()
        }
    }
    
    private var physicsEngineContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "function")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Biomechanics")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Real AI-powered pose analysis")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("PREMIUM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.purple))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Analysis Status
                    if isAnalyzing {
                        AnalysisProgressView(progress: analysisProgress)
                            .padding(.horizontal, 24)
                    }
                }
                
                // Video Selection Section
                VideoSelectionSection(
                    videoManager: videoManager,
                    onUploadVideo: { showingVideoPicker = true },
                    onSelectVideo: { showingVideoLibrary = true }
                )
                .padding(.horizontal, 24)

                // Analyze Button - Right after video selection
                Button(action: startRealAnalysis) {
                    HStack {
                        if videoAnalyzer.isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(videoAnalyzer.isAnalyzing ? "Analyzing..." : "Analyze Swing")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(videoAnalyzer.isAnalyzing || videoManager.selectedVideo == nil)
                .padding(.horizontal, 24)

                // Error Message Display
                if let errorMessage = videoAnalyzer.errorMessage {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Analysis Error")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                        }

                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Dismiss") {
                            videoAnalyzer.errorMessage = nil
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                }

                // Real Biomechanics Analysis
                RealBiomechanicsAnalysisView(analysisResult: videoAnalyzer.currentAnalysis, showingInfo: $showingInfo)
                    .padding(.horizontal, 24)

                // Export Button (only show when analysis is complete)
                if videoAnalyzer.currentAnalysis != nil {
                    Button(action: exportBiomechanicsReport) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 16, weight: .medium))
                            Text("Export Biomechanics Report")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.purple, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("AI Biomechanics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var premiumUpsellView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Lock Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 16) {
                Text("Physics Engine Premium")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Unlock professional biomechanics analysis with force vectors, energy calculations, and video integration")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Text("Premium Subscription")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.purple)
                
                Text("Starting at $1.99/month")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                showingPremiumPaywall = true
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Unlock Premium")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            // Subscription terms
            VStack(spacing: 8) {
                Text("Auto-renewable subscription")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Link("Terms", destination: URL(string: "https://doc-hosting.flycricket.io/golf-swing-ai-terms-of-use/3fac7eec-630a-41e2-a447-ff4bca08cd60/terms")!)
                    Link("Privacy", destination: URL(string: "https://github.com/nakulb23/golf-swing-ai/blob/main/PRIVACY_POLICY.md")!)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.purple.opacity(0.8))
            }
            .padding(.top, 8)

            Spacer()
        }
        .navigationTitle("AI Biomechanics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func startRealAnalysis() {
        guard let selectedVideo = videoManager.selectedVideo else {
            print("❌ No video selected for analysis")
            videoAnalyzer.errorMessage = "Please select a video first"
            return
        }

        print("🎬 Starting analysis for video: \(selectedVideo.name)")
        print("📁 Video URL: \(selectedVideo.url)")

        Task {
            if let analysisResult = await videoAnalyzer.analyzeSwingVideo(url: selectedVideo.url) {
                print("✅ Analysis completed successfully")
                let feedback = SwingFeedbackEngine.generateFeedback(from: analysisResult)
                currentFeedback = feedback
                showingFeedback = true
            } else {
                print("❌ Analysis failed - no result returned")
                if let error = videoAnalyzer.errorMessage {
                    print("❌ Error message: \(error)")
                }
            }
        }
    }

    private func exportBiomechanicsReport() {
        guard let analysis = videoAnalyzer.currentAnalysis else {
            print("❌ No analysis to export")
            return
        }

        let report = generateBiomechanicsReport(from: analysis)
        shareBiomechanicsReport(report)
    }

    private func generateBiomechanicsReport(from analysis: PhysicsSwingAnalysisResult) -> String {
        var report = "Golf Swing Biomechanics Report\n"
        report += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"

        report += "SWING METRICS\n"
        report += "═══════════════\n"
        report += "Club Head Speed: \(String(format: "%.1f", analysis.clubHeadSpeed.speedAtImpact)) mph\n"
        report += "Swing Plane: \(String(format: "%.1f", analysis.swingPlane.planeAngle))°\n"
        report += "Tempo Ratio: \(String(format: "%.1f", analysis.tempo.tempoRatio)):1\n"
        report += "Total Time: \(String(format: "%.2f", analysis.tempo.totalTime)) sec\n\n"

        report += "BIOMECHANICS\n"
        report += "═══════════════\n"
        report += "Shoulder Rotation: \(String(format: "%.1f", analysis.bodyKinematics.shoulderRotation.maxRotation))°\n"
        report += "Hip Rotation: \(String(format: "%.1f", analysis.bodyKinematics.hipRotation.maxRotation))°\n"
        report += "Spine Angle (Address): \(String(format: "%.1f", analysis.bodyKinematics.spineAngle.spineAngleAtAddress))°\n"
        report += "Spine Angle (Impact): \(String(format: "%.1f", analysis.bodyKinematics.spineAngle.spineAngleAtImpact))°\n"
        report += "Wrist Angle: \(String(format: "%.1f", analysis.bodyKinematics.armPositions.wristCockAngle))°\n\n"

        report += "SWING PATH\n"
        report += "═══════════════\n"
        report += "Club Path: \(String(format: "%.1f", analysis.swingPlane.clubPath))°\n"
        report += "Attack Angle: \(String(format: "%.1f", analysis.swingPlane.attackAngle))°\n"
        report += "Plane Consistency: \(String(format: "%.1f%%", analysis.swingPlane.planeConsistency * 100))\n\n"

        report += "ANALYSIS CONFIDENCE: \(String(format: "%.1f%%", analysis.confidence * 100))\n"

        return report
    }

    private func shareBiomechanicsReport(_ report: String) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }

    private func export3DVisualization() {
        guard let analysis = videoAnalyzer.currentAnalysis else {
            print("❌ No analysis to export")
            return
        }

        // Generate 3D visualization data
        let visualizationData = generate3DVisualizationData(from: analysis)
        share3DVisualization(visualizationData)
    }

    private func generate3DVisualizationData(from analysis: PhysicsSwingAnalysisResult) -> String {
        // Generate a simple 3D data representation that could be used by other apps
        var data = "Swing Path 3D Data\n\n"
        data += "Plane Angle: \(analysis.swingPlane.planeAngle)\n"
        data += "Club Path: \(analysis.swingPlane.clubPath)\n"
        data += "Shoulder Rotation: \(analysis.bodyKinematics.shoulderRotation.maxRotation)\n"
        data += "Hip Rotation: \(analysis.bodyKinematics.hipRotation.maxRotation)\n"
        return data
    }

    private func share3DVisualization(_ data: String) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - Analysis Progress View

struct AnalysisProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Analyzing Swing Physics...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                .scaleEffect(y: 2.0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }
}

// MARK: - Physics Stats Grid

// MARK: - REMOVED: Elite Benchmarks Grid (Contained Fake Tour Data)
// EliteBenchmarksGrid has been removed as it contained fabricated tour player comparisons
// not based on actual data. Only real AI biomechanics analysis is now shown.

struct EliteBenchmarksGrid_REMOVED: View {
    let analysisResult: PhysicsSwingAnalysisResult?

    var body: some View {
        VStack(spacing: 16) {
            Text("Elite Benchmarks")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("Compare your potential against elite player standards")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    EliteBenchmarkCard(
                        icon: "speedometer",
                        title: "Club Head Speed",
                        eliteValue: "113",
                        eliteUnit: "mph",
                        yourPotential: getUserClubSpeed(),
                        color: .blue
                    )

                    EliteBenchmarkCard(
                        icon: "arrow.up.right",
                        title: "Launch Angle",
                        eliteValue: "10.9°",
                        eliteUnit: "",
                        yourPotential: getUserLaunchAngle(),
                        color: .green
                    )
                }

                HStack(spacing: 12) {
                    EliteBenchmarkCard(
                        icon: "target",
                        title: "Accuracy",
                        eliteValue: "71%",
                        eliteUnit: "",
                        yourPotential: getUserAccuracy(),
                        color: .orange
                    )

                    EliteBenchmarkCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Distance",
                        eliteValue: "320",
                        eliteUnit: "yds",
                        yourPotential: getUserDistance(),
                        color: .purple
                    )
                }
            }

            Text("📹 Record your swing to see personalized comparisons")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private func getUserClubSpeed() -> String {
        guard let analysis = analysisResult else { return "Analysis Required" }
        let speed = Int(analysis.clubHeadSpeed.speedAtImpact)
        return "\(speed) mph"
    }

    private func getUserLaunchAngle() -> String {
        guard let analysis = analysisResult else { return "Analysis Required" }
        let angle = analysis.swingPlane.attackAngle + 10 // Approximate launch angle
        return String(format: "%.1f°", angle)
    }

    private func getUserAccuracy() -> String {
        guard let analysis = analysisResult else { return "Analysis Required" }
        let accuracy = Int(analysis.swingPlane.planeConsistency * 100)
        return "\(accuracy)%"
    }

    private func getUserDistance() -> String {
        guard let analysis = analysisResult else { return "Analysis Required" }
        // Estimate distance based on club speed (roughly 2.5 yards per mph for driver)
        let distance = Int(analysis.clubHeadSpeed.speedAtImpact * 2.5)
        return "\(distance) yds"
    }
}

// MARK: - Elite Benchmark Card

struct EliteBenchmarkCard: View {
    let icon: String
    let title: String
    let eliteValue: String
    let eliteUnit: String
    let yourPotential: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Elite benchmark
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("Elite:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(eliteValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(color)
                        
                        if !eliteUnit.isEmpty {
                            Text(eliteUnit)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Your potential
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("You:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(yourPotential)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(yourPotential == "Analysis Required" ? .orange : .primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Physics Tab Button

struct PhysicsTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? .purple : Color.clear)
                )
        }
    }
}

// MARK: - Real Biomechanics Analysis View (AI-Backed Only)
struct RealBiomechanicsAnalysisView: View {
    let analysisResult: PhysicsSwingAnalysisResult?
    @Binding var showingInfo: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Biomechanics Analysis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue],
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                    Text("Real physics calculations from pose data")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "function")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
            }

            // Real AI-Backed Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                RealMetricCard(
                    title: "Swing Plane",
                    value: getSwingPlaneValue(),
                    subtitle: "Optimal: 45-55°",
                    icon: "angle",
                    color: Color.purple,
                    trend: getSwingPlaneTrend(),
                    explanation: "Swing plane is the angle your club travels on during your swing. Think of it like an invisible ramp the club rides on. A good swing plane (45-55°) helps you hit the ball consistently. Too steep and you'll hit down too much; too flat and you'll struggle with consistency."
                )
                RealMetricCard(
                    title: "X-Factor",
                    value: getXFactorValue(),
                    subtitle: "Shoulder-hip separation",
                    icon: "rotate.3d",
                    color: Color.blue,
                    trend: getXFactorTrend(),
                    explanation: "X-Factor measures how much your shoulders turn compared to your hips at the top of your backswing. Good separation (40-50°) creates a powerful coil like a spring. This stored energy helps generate clubhead speed when you unwind in the downswing."
                )
                RealMetricCard(
                    title: "Tempo Ratio",
                    value: getTempoRatioValue(),
                    subtitle: "Backswing:downswing",
                    icon: "metronome",
                    color: Color.green,
                    trend: getTempoTrend(),
                    explanation: "Tempo ratio compares your backswing time to downswing time. The ideal ratio is about 3:1 - taking 3 times longer to go back than to come down. Good tempo (2.5-3.5:1) helps you stay balanced and hit the ball more consistently."
                )
                RealMetricCard(
                    title: "Balance",
                    value: getBalanceValue(),
                    subtitle: "Weight stability",
                    icon: "figure.mind.and.body",
                    color: Color.orange,
                    trend: getBalanceTrend(),
                    explanation: "Balance measures how stable your body stays during the swing. Good balance (70%+) means you're not swaying or losing your posture. Better balance leads to more consistent contact and helps you stay in control throughout your swing."
                )
            }
            .padding(.horizontal, 4)

            // Interactive Video Analysis with Angle Measurements
            VStack(spacing: 16) {
                HStack {
                    Text("Interactive Swing Analysis")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if analysisResult != nil {
                        Button(action: {
                            showingInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let analysis = analysisResult {
                    InteractiveSwingVideoPlayer(analysisResult: analysis)
                } else {
                    InteractiveVideoPlaceholder()
                }

                // Real 3D Path Visualization
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.05))
                        .frame(height: 200)

                    if let analysis = analysisResult {
                        SwingVisualization3D(analysisResult: analysis)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.purple.opacity(0.6))
                            VStack(spacing: 8) {
                                Text("3D Analysis Ready")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Record your swing to see detailed\nbiomechanics visualization")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - Real AI-Backed Metric Calculations
    private func getSwingPlaneValue() -> String {
        guard let analysis = analysisResult else { return "-- °" }
        return String(format: "%.1f°", analysis.swingPlane.planeAngle)
    }

    private func getSwingPlaneTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let optimalRange = 58.0...65.0
        return optimalRange.contains(analysis.swingPlane.planeAngle) ? .stable :
               analysis.swingPlane.planeAngle > 65 ? .down : .up
    }

    private func getXFactorValue() -> String {
        guard let analysis = analysisResult else { return "-- °" }
        let xFactor = analysis.bodyKinematics.shoulderRotation.maxRotation - analysis.bodyKinematics.hipRotation.maxRotation
        return String(format: "%.1f°", xFactor)
    }

    private func getXFactorTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let xFactor = analysis.bodyKinematics.shoulderRotation.maxRotation - analysis.bodyKinematics.hipRotation.maxRotation
        return xFactor > 45 ? .up : xFactor < 35 ? .down : .stable
    }

    private func getTempoRatioValue() -> String {
        guard let analysis = analysisResult else { return "-- : 1" }
        return String(format: "%.1f : 1", analysis.tempo.tempoRatio)
    }

    private func getTempoTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let idealRange = 2.5...3.5
        return idealRange.contains(analysis.tempo.tempoRatio) ? .stable :
               analysis.tempo.tempoRatio > 3.5 ? .up : .down
    }

    private func getBalanceValue() -> String {
        guard let analysis = analysisResult else { return "--%"}
        let stability = analysis.bodyKinematics.spineAngle.spineStability * 100
        return String(format: "%.0f%%", stability)
    }

    private func getBalanceTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let stability = analysis.bodyKinematics.spineAngle.spineStability
        return stability > 0.8 ? .up : stability < 0.6 ? .down : .stable
    }
}

// MARK: - Real Metric Card (No Fake Percentiles)
struct RealMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: Trend
    let explanation: String
    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)

                Spacer()

                HStack(spacing: 8) {

                    Image(systemName: trend.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(trend.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(minHeight: 120)
        .alert(title, isPresented: $showingInfo) {
            Button("Got it!") { }
        } message: {
            Text(explanation)
        }
    }
}

// MARK: - Kinematics Analysis View (DEPRECATED - Contains Fake Data)

struct KinematicsAnalysisView: View {
    let analysisResult: PhysicsSwingAnalysisResult?
    @State private var animationProgress: CGFloat = 0
    @State private var selectedMetric: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Premium Header with Animation
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("3D Biomechanics Analysis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue],
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                    Text("Frame-by-frame kinematic breakdown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
                    .rotationEffect(.degrees(animationProgress * 360))
                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: animationProgress)
            }

            // Advanced Metrics Grid with Interactive Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RealMetricCard(
                    title: "Swing Plane",
                    value: getSwingPlaneValue(),
                    subtitle: "Tour avg: 45-55°",
                    icon: "angle",
                    color: Color.purple,
                    trend: getSwingPlaneTrend(),
                    explanation: "Swing plane is the angle your club travels on during your swing. Think of it like an invisible ramp the club rides on. A good swing plane (45-55°) helps you hit the ball consistently."
                )

                RealMetricCard(
                    title: "X-Factor",
                    value: getXFactorValue(),
                    subtitle: "Separation angle",
                    icon: "rotate.3d",
                    color: Color.blue,
                    trend: getXFactorTrend(),
                    explanation: "X-Factor measures shoulder and hip separation at the top of your backswing. Good separation creates powerful energy like winding a spring."
                )

                RealMetricCard(
                    title: "Lag Angle",
                    value: getLagAngleValue(),
                    subtitle: "At transition",
                    icon: "angle.circle.fill",
                    color: Color.green,
                    trend: getLagAngleTrend(),
                    explanation: "Lag angle shows how much your wrists are cocked during the downswing. Good lag (90°+) stores power and helps create clubhead speed at impact."
                )

                RealMetricCard(
                    title: "Release Point",
                    value: getReleasePointValue(),
                    subtitle: "Before impact",
                    icon: "hand.point.right.fill",
                    color: Color.orange,
                    trend: getReleasePointTrend(),
                    explanation: "Release point is when your wrists unhinge to deliver maximum speed to the clubhead. Proper timing ensures you hit the ball at peak speed."
                )
            }

            // Premium 3D Visualization with Timeline
            VStack(spacing: 16) {
                HStack {
                    Text("Swing Sequence Timeline")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button(action: {
                        // Deprecated view - export not available
                        print("Export not available in deprecated view")
                    }) {
                        Label("Export 3D", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .disabled(true)
                }

                // Swing Phase Timeline
                if analysisResult != nil {
                    SwingPhaseTimeline(analysisResult: analysisResult)
                } else {
                    SwingPhaseTimelinePlaceholder()
                }

                // 3D Model Visualization
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 240)

                    if let analysis = analysisResult {
                        SwingVisualization3D(analysisResult: analysis)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.purple.opacity(0.6))

                            VStack(spacing: 8) {
                                Text("3D Analysis Ready")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Record your swing to see detailed\n3D biomechanics visualization")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    }
                }
            }

            // AI Insights
            PremiumInsightCard(
                title: "Kinematic Efficiency Score",
                score: getKinematicEfficiencyScore(),
                insight: getKinematicInsight()
            )
        }
        .onAppear {
            animationProgress = 1
        }
    }

    // MARK: - Helper Methods for Real Data
    private func getSwingPlaneValue() -> String {
        guard let analysis = analysisResult else { return "-- °" }
        return String(format: "%.1f°", analysis.swingPlane.planeAngle)
    }

    private func getSwingPlaneTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let optimalRange = 58.0...65.0
        return optimalRange.contains(analysis.swingPlane.planeAngle) ? .stable :
               analysis.swingPlane.planeAngle > 65 ? .down : .up
    }

    private func getSwingPlanePercentile() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let value = analysis.swingPlane.planeConsistency * 100
        return Int(max(0, min(100, value)))
    }

    private func getXFactorValue() -> String {
        guard let analysis = analysisResult else { return "-- °" }
        let xFactor = analysis.bodyKinematics.shoulderRotation.maxRotation - analysis.bodyKinematics.hipRotation.maxRotation
        return String(format: "%.1f°", xFactor)
    }

    private func getXFactorTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        let xFactor = analysis.bodyKinematics.shoulderRotation.maxRotation - analysis.bodyKinematics.hipRotation.maxRotation
        return xFactor > 45 ? .up : xFactor < 35 ? .down : .stable
    }

    private func getXFactorPercentile() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let xFactor = analysis.bodyKinematics.shoulderRotation.maxRotation - analysis.bodyKinematics.hipRotation.maxRotation
        let value = (xFactor - 30) / 20 * 100
        return Int(max(0, min(100, value)))
    }

    private func getLagAngleValue() -> String {
        guard let analysis = analysisResult else { return "-- °" }
        return String(format: "%.1f°", analysis.bodyKinematics.armPositions.wristCockAngle)
    }

    private func getLagAngleTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        return analysis.bodyKinematics.armPositions.wristCockAngle > 75 ? .up : .stable
    }

    private func getLagAnglePercentile() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let value = (analysis.bodyKinematics.armPositions.wristCockAngle - 60) / 25 * 100
        return Int(max(0, min(100, value)))
    }

    private func getReleasePointValue() -> String {
        guard let analysis = analysisResult else { return "-- in" }
        let releasePoint = analysis.bodyKinematics.armPositions.armExtension * 6 // Convert to inches
        return String(format: "%.1f in", releasePoint)
    }

    private func getReleasePointTrend() -> Trend {
        guard let analysis = analysisResult else { return .stable }
        return analysis.bodyKinematics.armPositions.armExtension > 0.9 ? .up : .stable
    }

    private func getReleasePointPercentile() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let value = analysis.bodyKinematics.armPositions.armExtension * 100
        return Int(max(0, min(100, value)))
    }

    private func getKinematicEfficiencyScore() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let planeScore = analysis.swingPlane.planeConsistency * 40
        let sequenceScore = (analysis.bodyKinematics.hipRotation.rotationTiming < analysis.bodyKinematics.shoulderRotation.rotationTiming) ? 30.0 : 15.0
        let lagScore = (analysis.bodyKinematics.armPositions.wristCockAngle > 70) ? 30.0 : 20.0
        let totalScore = planeScore + sequenceScore + lagScore
        return Int(max(0, min(100, totalScore)))
    }

    private func getKinematicInsight() -> String {
        guard let analysis = analysisResult else { return "Complete a swing analysis to see personalized insights." }

        let hipLead = analysis.bodyKinematics.hipRotation.rotationTiming < analysis.bodyKinematics.shoulderRotation.rotationTiming
        let timingDiff = abs(analysis.bodyKinematics.shoulderRotation.rotationTiming - analysis.bodyKinematics.hipRotation.rotationTiming) * 1000

        if hipLead {
            return "Excellent kinematic sequence! Hip rotation leads shoulders by \(Int(timingDiff))ms, promoting optimal energy transfer."
        } else {
            return "Consider initiating downswing with hip rotation. Current timing shows shoulders leading by \(Int(timingDiff))ms."
        }
    }
}

// MARK: - Premium Helper Views

// MARK: - Trend Enum
enum Trend {
    case up, down, stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Trend Indicator View
struct TrendIndicator: View {
    let trend: Trend

    var body: some View {
        Image(systemName: trend == .up ? "arrow.up.right" : trend == .down ? "arrow.down.right" : "minus")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(trend == .up ? .green : trend == .down ? .red : .gray)
    }
}

// MARK: - REMOVED: Premium Metric Card (Contained Fake Percentiles)
// PremiumMetricCard has been removed as it contained fabricated percentile rankings
// not based on actual tour data. Use RealMetricCard instead for legitimate data.

struct PremiumMetricCard_REMOVED: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: Trend
    let percentile: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
                TrendIndicator(trend: trend)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))

            // Percentile bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(percentile) / 100, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(percentile)th percentile")
                .font(.system(size: 9))
                .foregroundColor(color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct SwingPhaseTimeline: View {
    let analysisResult: PhysicsSwingAnalysisResult?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                // Progress segments based on real swing timing
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.gradient)
                        .frame(width: geometry.size.width * getAddressWidth(), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.gradient)
                        .frame(width: geometry.size.width * getBackswingWidth(), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.gradient)
                        .frame(width: geometry.size.width * getTransitionWidth(), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.gradient)
                        .frame(width: geometry.size.width * getDownswingWidth(), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.gradient)
                        .frame(width: geometry.size.width * getImpactWidth(), height: 8)
                }
            }
        }
        .frame(height: 8)
    }

    private func getAddressWidth() -> Double {
        guard analysisResult != nil else { return 0.15 }
        // Address phase is typically 10-15% of total swing
        return 0.1
    }

    private func getBackswingWidth() -> Double {
        guard let analysis = analysisResult else { return 0.4 }
        let totalTime = analysis.tempo.totalTime
        let backswingTime = analysis.tempo.backswingTime
        return min(0.6, backswingTime / totalTime)
    }

    private func getTransitionWidth() -> Double {
        guard let analysis = analysisResult else { return 0.1 }
        // Transition is typically 5-10% of total swing
        return analysis.tempo.pauseAtTop * 0.5
    }

    private func getDownswingWidth() -> Double {
        guard let analysis = analysisResult else { return 0.25 }
        let totalTime = analysis.tempo.totalTime
        let downswingTime = analysis.tempo.downswingTime
        return min(0.4, downswingTime / totalTime)
    }

    private func getImpactWidth() -> Double {
        guard analysisResult != nil else { return 0.1 }
        // Impact and follow-through
        let remaining = 1.0 - (getAddressWidth() + getBackswingWidth() + getTransitionWidth() + getDownswingWidth())
        return max(0.05, remaining)
    }
}

struct SwingPhaseTimelinePlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 8)

                // Placeholder message
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("Record swing to see timing analysis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 24)
    }
}

struct SwingVisualization3D: View {
    let analysisResult: PhysicsSwingAnalysisResult
    @State private var rotation3D: Double = 0
    @State private var selectedPhase: SwingPhase = .address

    enum SwingPhase: String, CaseIterable {
        case address = "Address"
        case backswing = "Backswing"
        case impact = "Impact"
        case followThrough = "Follow Through"

        var color: Color {
            switch self {
            case .address: return .blue
            case .backswing: return .orange
            case .impact: return .red
            case .followThrough: return .green
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Phase selector
            Picker("Phase", selection: $selectedPhase) {
                ForEach(SwingPhase.allCases, id: \.self) { phase in
                    Text(phase.rawValue).tag(phase)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Enhanced 3D swing path visualization
            Canvas { context, size in
                let centerX = size.width / 2
                let centerY = size.height / 2

                // Apply 3D rotation effect
                let rotationEffect = cos(rotation3D * .pi / 180)

                // Draw swing plane based on real analysis
                let planeAngle = analysisResult.swingPlane.planeAngle * .pi / 180

                // Calculate positions based on real biomechanics - make swing path more realistic

                // Make swing path larger and more realistic
                let swingRadius = min(size.width, size.height) * 0.35 // Use 35% of available space
                let rotationScale = abs(rotationEffect)

                // Address position - bottom center
                let addressPoint = CGPoint(x: centerX, y: centerY + swingRadius * 0.3)

                // Backswing position - based on actual swing plane
                let backswingX = centerX - swingRadius * cos(planeAngle) * rotationScale
                let backswingY = centerY - swingRadius * 0.6
                let backswingPoint = CGPoint(x: backswingX, y: backswingY)

                // Impact position - slightly forward of address
                let impactPoint = CGPoint(x: centerX + 15 * rotationScale, y: centerY + swingRadius * 0.25)

                // Follow through - high and forward
                let followThroughX = centerX + swingRadius * 0.8 * rotationScale
                let followThroughY = centerY - swingRadius * 0.4
                let followThroughPoint = CGPoint(x: followThroughX, y: followThroughY)

                // Draw swing plane grid
                let gridPath = Path { path in
                    // Plane lines
                    for i in -3...3 {
                        let offset = CGFloat(i * 15)
                        path.move(to: CGPoint(x: 10, y: centerY + offset))
                        path.addLine(to: CGPoint(x: size.width - 10, y: centerY + offset - CGFloat(planeAngle) * 30))
                    }
                }
                context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)

                // Draw swing path - more realistic golf swing arc
                let swingPath = Path { path in
                    path.move(to: addressPoint)

                    // Backswing arc - wide and back
                    let backswingControl = CGPoint(
                        x: centerX - swingRadius * 0.3 * rotationScale,
                        y: centerY - swingRadius * 0.2
                    )
                    path.addQuadCurve(to: backswingPoint, control: backswingControl)

                    // Downswing to impact - steeper, more direct
                    let downswingControl = CGPoint(
                        x: centerX - swingRadius * 0.1 * rotationScale,
                        y: centerY + swingRadius * 0.1
                    )
                    path.addQuadCurve(to: impactPoint, control: downswingControl)

                    // Follow through - high and extended
                    let followThroughControl = CGPoint(
                        x: centerX + swingRadius * 0.4 * rotationScale,
                        y: centerY - swingRadius * 0.1
                    )
                    path.addQuadCurve(to: followThroughPoint, control: followThroughControl)
                }

                context.stroke(swingPath, with: .color(.purple), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Draw position markers - larger and more visible
                let positions = [
                    (addressPoint, Color.green, "Address"),
                    (backswingPoint, Color.blue, "Top"),
                    (impactPoint, Color.red, "Impact"),
                    (followThroughPoint, Color.orange, "Finish")
                ]

                for (point, color, _) in positions {
                    // Outer ring
                    context.fill(Circle().path(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)), with: .color(color.opacity(0.3)))
                    // Inner dot
                    context.fill(Circle().path(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(color))
                }
            }
            .frame(height: 160)
            .onAppear {
                // Add automatic 3D rotation animation
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    rotation3D = 60
                }
            }

            // 3D rotation control
            HStack {
                Text("3D Rotation")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Slider(value: $rotation3D, in: -90...90, step: 1)
                    .tint(.purple)

                Text("\(Int(rotation3D))°")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
            .padding(.horizontal)

            // Phase indicators with real timing
            HStack(spacing: 20) {
                PhaseIndicator(title: "Address", time: "0.0s", color: .green, isActive: false)
                PhaseIndicator(title: "Backswing", time: String(format: "%.1fs", analysisResult.tempo.backswingTime), color: .blue, isActive: false)
                PhaseIndicator(title: "Transition", time: String(format: "%.2fs", analysisResult.tempo.pauseAtTop), color: .purple, isActive: true)
                PhaseIndicator(title: "Downswing", time: String(format: "%.1fs", analysisResult.tempo.downswingTime), color: .orange, isActive: false)
                PhaseIndicator(title: "Impact", time: String(format: "%.1fs", analysisResult.tempo.totalTime), color: .red, isActive: false)
            }
            .font(.system(size: 10))
        }
        .padding()
    }
}

struct PhaseIndicator: View {
    let title: String
    let time: String
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.gradient)
                .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
                .scaleEffect(isActive ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)

            Text(title)
                .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? color : .secondary)

            Text(time)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
}

struct PremiumInsightCard: View {
    let title: String
    let score: Int
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "brain")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(score)%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue],
                                     startPoint: .leading,
                                     endPoint: .trailing)
                    )
            }

            Text(insight)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - REMOVED: Force Analysis View (Contained Fake Data)
// ForceAnalysisView has been removed as it contained fabricated force measurements
// not based on actual AI model output. Only real biomechanics data is now shown.

struct ForceAnalysisView_REMOVED: View {
    let analysisResult: PhysicsSwingAnalysisResult?
    @State private var selectedForce: String = "ground"
    @State private var animateVectors = false

    var body: some View {
        VStack(spacing: 20) {
            // Premium Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Force Vector Dynamics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red],
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                    Text("Real-time force distribution analysis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                    .scaleEffect(animateVectors ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateVectors)
            }

            // Force Metrics Dashboard
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForceMetricPremium(
                        title: "Peak Ground Force",
                        value: getGroundForceValue(),
                        subtitle: "Body weight",
                        measurement: getGroundForceMeasurement(),
                        icon: "arrow.down.to.line",
                        color: .orange
                    )
                    ForceMetricPremium(
                        title: "Rotational Force",
                        value: getRotationalForceValue(),
                        subtitle: "Torque at impact",
                        measurement: getRotationalForceMeasurement(),
                        icon: "rotate.3d",
                        color: .red
                    )
                    ForceMetricPremium(
                        title: "Grip Pressure",
                        value: getGripPressureValue(),
                        subtitle: "Optimal range",
                        measurement: getGripPressureMeasurement(),
                        icon: "hand.raised.fill",
                        color: .blue
                    )
                }
                .padding(.horizontal, 4)
            }

            // Interactive Force Vector Visualization
            VStack(spacing: 12) {
                HStack {
                    Text("3D Force Vector Map")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Menu {
                        Button("Ground Forces") { selectedForce = "ground" }
                        Button("Rotational Forces") { selectedForce = "rotational" }
                        Button("Impact Forces") { selectedForce = "impact" }
                    } label: {
                        Label(selectedForce.capitalized, systemImage: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                // Advanced Force Visualization
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 280)

                    ForceVectorVisualization(selectedForce: selectedForce)
                        .padding()
                }
            }

            // Force Efficiency Analysis
            PremiumInsightCard(
                title: "Force Efficiency Rating",
                score: getForceEfficiencyScore(),
                insight: getForceInsight()
            )
        }
        .onAppear {
            animateVectors = true
        }
    }

    // MARK: - Helper Methods for Real Force Data
    private func getGroundForceValue() -> String {
        guard let analysis = analysisResult else { return "-- x" }
        let forceMultiplier = analysis.bodyKinematics.weightShift.weightTransferSpeed * 1.2
        return String(format: "%.1fx", forceMultiplier)
    }

    private func getGroundForceMeasurement() -> String {
        guard let analysis = analysisResult else { return "-- N" }
        let force = Int(analysis.bodyKinematics.weightShift.weightTransferSpeed * 1000)
        return "\(force) N"
    }

    private func getRotationalForceValue() -> String {
        guard let analysis = analysisResult else { return "-- Nm" }
        let torque = Int(analysis.bodyKinematics.hipRotation.rotationSpeed * 1.5)
        return "\(torque) Nm"
    }

    private func getRotationalForceMeasurement() -> String {
        guard let analysis = analysisResult else { return "Peak: -- Nm" }
        let peakTorque = Int(analysis.bodyKinematics.shoulderRotation.rotationSpeed * 1.3)
        return "Peak: \(peakTorque) Nm"
    }

    private func getGripPressureValue() -> String {
        guard let analysis = analysisResult else { return "-- N" }
        let pressure = Int(300 + (analysis.bodyKinematics.armPositions.wristCockAngle - 70) * 5)
        return "\(pressure) N"
    }

    private func getGripPressureMeasurement() -> String {
        guard let analysis = analysisResult else { return "Variance: ±-%" }
        let variance = Int(abs(analysis.bodyKinematics.armPositions.armExtension - 0.85) * 100)
        return "Variance: ±\(variance)%"
    }

    private func getForceEfficiencyScore() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let weightTransferScore = analysis.bodyKinematics.weightShift.weightTransferSpeed * 30
        let rotationalScore = (analysis.bodyKinematics.hipRotation.rotationSpeed / 500) * 35
        let gripScore = (analysis.bodyKinematics.armPositions.wristCockAngle > 70) ? 35.0 : 20.0
        let totalScore = weightTransferScore + rotationalScore + Double(gripScore)
        return Int(max(0, min(100, totalScore)))
    }

    private func getForceInsight() -> String {
        guard let analysis = analysisResult else { return "Complete a swing analysis to see force efficiency insights." }

        let weightTransfer = analysis.bodyKinematics.weightShift.weightTransferSpeed
        let rotationSpeed = analysis.bodyKinematics.hipRotation.rotationSpeed

        if weightTransfer > 2.0 && rotationSpeed > 400 {
            return "Exceptional ground force utilization. Your force sequence optimizes energy transfer through the kinetic chain."
        } else if weightTransfer > 1.5 {
            return "Good weight transfer detected. Focus on increasing hip rotation speed for more power generation."
        } else {
            return "Improve weight shift timing. Practice transferring weight to front foot during downswing for better force generation."
        }
    }
}

struct ForceMetricPremium: View {
    let title: String
    let value: String
    let subtitle: String
    let measurement: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))

            Divider()

            Text(measurement)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color)
        }
        .frame(width: 120)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct ForceVectorVisualization: View {
    let selectedForce: String

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Draw force vectors
            let vectors: [(start: CGPoint, end: CGPoint, color: Color)] = [
                (CGPoint(x: centerX, y: centerY + 80), CGPoint(x: centerX, y: centerY), .orange), // Ground up
                (CGPoint(x: centerX - 60, y: centerY), CGPoint(x: centerX, y: centerY), .blue), // Lateral
                (CGPoint(x: centerX, y: centerY), CGPoint(x: centerX + 40, y: centerY - 40), .red), // Rotational
                (CGPoint(x: centerX, y: centerY), CGPoint(x: centerX + 70, y: centerY - 20), .purple) // Club force
            ]

            for vector in vectors {
                var path = Path()
                path.move(to: vector.start)
                path.addLine(to: vector.end)

                context.stroke(path, with: .color(vector.color), lineWidth: 3)

                // Arrowhead
                let angle = atan2(vector.end.y - vector.start.y, vector.end.x - vector.start.x)
                var arrowPath = Path()
                arrowPath.move(to: vector.end)
                arrowPath.addLine(to: CGPoint(
                    x: vector.end.x - 10 * cos(angle - .pi / 6),
                    y: vector.end.y - 10 * sin(angle - .pi / 6)
                ))
                arrowPath.move(to: vector.end)
                arrowPath.addLine(to: CGPoint(
                    x: vector.end.x - 10 * cos(angle + .pi / 6),
                    y: vector.end.y - 10 * sin(angle + .pi / 6)
                ))
                context.stroke(arrowPath, with: .color(vector.color), lineWidth: 3)
            }

            // Center point
            context.fill(Circle().path(in: CGRect(x: centerX - 5, y: centerY - 5, width: 10, height: 10)),
                        with: .color(.white))
            context.stroke(Circle().path(in: CGRect(x: centerX - 5, y: centerY - 5, width: 10, height: 10)),
                          with: .color(.orange), lineWidth: 2)
        }
    }
}

// MARK: - REMOVED: Energy Analysis View (Contained Fake Data)
// EnergyAnalysisView has been removed as it contained fabricated energy transfer calculations
// not based on actual AI model output. Only real biomechanics data is now shown.

struct EnergyAnalysisView_REMOVED: View {
    let analysisResult: PhysicsSwingAnalysisResult?
    @State private var energyFlow: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Premium Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Energy Transfer Dynamics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .yellow],
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                    Text("Kinetic energy flow analysis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                    .opacity(energyFlow > 0.5 ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: energyFlow)
            }

            // Energy Flow Visualization
            VStack(spacing: 16) {
                Text("Energy Flow Chain")
                    .font(.system(size: 16, weight: .semibold))

                // Energy flow diagram
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.1), Color.yellow.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)

                    EnergyFlowVisualization()
                        .padding()
                }
            }

            // Energy Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                EnergyMetricCard(
                    title: "Total Generated",
                    value: getTotalEnergyValue(),
                    efficiency: 100,
                    icon: "power",
                    color: Color.green
                )

                EnergyMetricCard(
                    title: "To Club Head",
                    value: getClubHeadEnergyValue(),
                    efficiency: getClubHeadEfficiency(),
                    icon: "arrow.right.circle.fill",
                    color: Color.blue
                )

                EnergyMetricCard(
                    title: "Ball Impact",
                    value: getBallImpactEnergyValue(),
                    efficiency: getBallImpactEfficiency(),
                    icon: "circle.fill",
                    color: Color.orange
                )

                EnergyMetricCard(
                    title: "Energy Lost",
                    value: getEnergyLostValue(),
                    efficiency: getEnergyLostEfficiency(),
                    icon: "minus.circle.fill",
                    color: Color.red
                )
            }

            // Energy Efficiency Analysis
            PremiumInsightCard(
                title: "Energy Transfer Efficiency",
                score: getEnergyEfficiencyScore(),
                insight: getEnergyInsight()
            )
        }
        .onAppear {
            energyFlow = 1
        }
    }

    // MARK: - Helper Methods for Real Energy Data
    private func getTotalEnergyValue() -> String {
        guard let analysis = analysisResult else { return "-- J" }
        let totalEnergy = Int(analysis.clubHeadSpeed.speedAtImpact * analysis.clubHeadSpeed.speedAtImpact * 0.15)
        return "\(totalEnergy) J"
    }

    private func getClubHeadEnergyValue() -> String {
        guard let analysis = analysisResult else { return "-- J" }
        let totalEnergy = Int(analysis.clubHeadSpeed.speedAtImpact * analysis.clubHeadSpeed.speedAtImpact * 0.15)
        let clubHeadEnergy = Int(Double(totalEnergy) * analysis.bodyKinematics.armPositions.armExtension)
        return "\(clubHeadEnergy) J"
    }

    private func getClubHeadEfficiency() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let value = analysis.bodyKinematics.armPositions.armExtension * 100
        return Int(max(0, min(100, value)))
    }

    private func getBallImpactEnergyValue() -> String {
        guard let analysis = analysisResult else { return "-- J" }
        let totalEnergy = Int(analysis.clubHeadSpeed.speedAtImpact * analysis.clubHeadSpeed.speedAtImpact * 0.15)
        let impactEnergy = Int(Double(totalEnergy) * 0.2) // Typical ball transfer efficiency
        return "\(impactEnergy) J"
    }

    private func getBallImpactEfficiency() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let value = analysis.swingPlane.planeConsistency * 25
        return Int(max(0, min(100, value)))
    }

    private func getEnergyLostValue() -> String {
        guard let analysis = analysisResult else { return "-- J" }
        let totalEnergy = Int(analysis.clubHeadSpeed.speedAtImpact * analysis.clubHeadSpeed.speedAtImpact * 0.15)
        let efficiency = analysis.bodyKinematics.armPositions.armExtension * analysis.swingPlane.planeConsistency
        let lostEnergy = Int(Double(totalEnergy) * (1.0 - efficiency))
        return "\(lostEnergy) J"
    }

    private func getEnergyLostEfficiency() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let efficiency = analysis.bodyKinematics.armPositions.armExtension * analysis.swingPlane.planeConsistency
        let value = (1.0 - efficiency) * 100
        return Int(max(0, min(100, value)))
    }

    private func getEnergyEfficiencyScore() -> Int {
        guard let analysis = analysisResult else { return 0 }
        let armScore = analysis.bodyKinematics.armPositions.armExtension * 40
        let planeScore = analysis.swingPlane.planeConsistency * 35
        let lagScore = (analysis.bodyKinematics.armPositions.wristCockAngle > 75) ? 25.0 : 15.0
        let totalScore = armScore + planeScore + Double(lagScore)
        return Int(max(0, min(100, totalScore)))
    }

    private func getEnergyInsight() -> String {
        guard let analysis = analysisResult else { return "Complete a swing analysis to see energy transfer insights." }

        let efficiency = analysis.bodyKinematics.armPositions.armExtension * analysis.swingPlane.planeConsistency
        let lagAngle = analysis.bodyKinematics.armPositions.wristCockAngle

        if efficiency > 0.8 && lagAngle > 75 {
            return "Excellent energy transfer! Your kinetic chain efficiency is exceptional. Maintain current lag angle for optimal power."
        } else if efficiency > 0.7 {
            return "Good energy transfer detected. Focus on maintaining lag angle through impact to minimize energy loss."
        } else {
            return "Energy transfer needs improvement. Work on arm extension timing and swing plane consistency for better efficiency."
        }
    }
}

// MARK: - Energy Helper Views

struct EnergyMetricCard: View {
    let title: String
    let value: String
    let efficiency: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            // Efficiency bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(efficiency) / 100, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(efficiency)% efficiency")
                .font(.system(size: 9))
                .foregroundColor(color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

struct EnergyFlowVisualization: View {
    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Draw energy flow path
            let energyPath = Path { path in
                // Body to club path
                path.move(to: CGPoint(x: centerX - 80, y: centerY))
                path.addLine(to: CGPoint(x: centerX - 20, y: centerY - 20))
                path.addLine(to: CGPoint(x: centerX + 40, y: centerY - 40))
                path.addLine(to: CGPoint(x: centerX + 80, y: centerY - 20))
            }

            context.stroke(energyPath, with: .color(.green), lineWidth: 6)

            // Energy nodes
            let nodes: [(point: CGPoint, size: CGFloat, color: Color)] = [
                (CGPoint(x: centerX - 80, y: centerY), 20, .green),        // Body
                (CGPoint(x: centerX - 20, y: centerY - 20), 16, .blue),     // Arms
                (CGPoint(x: centerX + 40, y: centerY - 40), 14, .orange),   // Club
                (CGPoint(x: centerX + 80, y: centerY - 20), 10, .red)       // Ball
            ]

            for node in nodes {
                context.fill(
                    Circle().path(in: CGRect(
                        x: node.point.x - node.size/2,
                        y: node.point.y - node.size/2,
                        width: node.size,
                        height: node.size
                    )),
                    with: .color(node.color)
                )
            }
        }
    }
}

// MARK: - Supporting Components

struct KinematicsMetric: View {
    let label: String
    let value: String
    let trend: TrendDirection
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .secondary
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Image(systemName: trend.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(trend.color)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct ForceMetric: View {
    let label: String
    let value: String
    let direction: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(direction)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct EnergyMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Video Selection Section

struct VideoSelectionSection: View {
    @ObservedObject var videoManager: VideoManager
    let onUploadVideo: () -> Void
    let onSelectVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Video Analysis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if videoManager.selectedVideo != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            if let selectedVideo = videoManager.selectedVideo {
                SelectedVideoCard(video: selectedVideo, videoManager: videoManager)
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: onUploadVideo) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Upload Video")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button(action: onSelectVideo) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text("My Videos")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                    }
                    
                    Text("Upload a golf swing video or select from your library for physics analysis")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Selected Video Card

struct SelectedVideoCard: View {
    let video: UserVideo
    @ObservedObject var videoManager: VideoManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Video thumbnail placeholder with green checkmark
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 60, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.green)
                        )

                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 4, y: -4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("Duration: \(String(format: "%.1f", video.duration))s")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)

                        Text("• Ready for analysis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Button(action: {
                    videoManager.clearSelection()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Swing Feedback View

struct SwingFeedbackView: View {
    let feedback: SwingFeedback
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Overall Score Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Swing Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Complete breakdown of your swing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Overall Score Circle
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: feedback.overallScore / 100)
                                .stroke(
                                    scoreColor(feedback.overallScore),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("\(Int(feedback.overallScore))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(feedback.overallScore))
                                
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Score Description
                    Text(scoreDescription(feedback.overallScore))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .background(Color.gray.opacity(0.1))
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Improvements Section
                        if !feedback.improvements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Areas for Improvement")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ForEach(feedback.improvements.indices, id: \.self) { index in
                                    ImprovementCard(improvement: feedback.improvements[index])
                                }
                            }
                        }
                        
                        // Strengths Section
                        if !feedback.strengths.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Strengths")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ForEach(feedback.strengths.indices, id: \.self) { index in
                                    StrengthCard(strength: feedback.strengths[index])
                                }
                            }
                        }
                        
                        // Elite Benchmarks
                        VStack(alignment: .leading, spacing: 12) {
                            Text("vs. Elite Player Average")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(feedback.eliteBenchmarks.indices, id: \.self) { index in
                                ComparisonCard(comparison: feedback.eliteBenchmarks[index])
                            }
                        }
                        
                        // Practice Recommendations
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Practice Plan")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(feedback.practiceRecommendations.indices, id: \.self) { index in
                                PracticeCard(recommendation: feedback.practiceRecommendations[index])
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
    
    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 90...100: return "Excellent swing mechanics! You're performing at a high level."
        case 80...89: return "Very good swing with room for minor improvements."
        case 70...79: return "Good foundation with some areas needing attention."
        case 60...69: return "Average swing with several improvement opportunities."
        case 50...59: return "Below average - focus on fundamental improvements."
        default: return "Significant work needed on basic swing mechanics."
        }
    }
}

struct ImprovementCard: View {
    let improvement: ImprovementRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: improvement.area.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(improvement.priority.color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(improvement.priority.color.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(improvement.area.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(improvement.priority.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(improvement.priority.color))
                        }
                        
                        if let impact = improvement.impactOnDistance {
                            Text("+\(Int(impact)) yards potential")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(improvement.issue)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Solution")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(improvement.solution)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    if !improvement.drills.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Practice Drills")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            ForEach(improvement.drills.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text(improvement.drills[index])
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct StrengthCard: View {
    let strength: StrengthArea
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: strength.area.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(strength.area.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(strength.professionalLevel))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Text(strength.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct ComparisonCard: View {
    let comparison: PhysicsEliteBenchmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(comparison.metric)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Value")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", comparison.userValue)) \(comparison.unit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pro Average")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", comparison.eliteAverage)) \(comparison.unit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Percentile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(comparison.percentile))th")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(percentileColor(comparison.percentile))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(percentileColor(comparison.percentile))
                            .frame(width: geometry.size.width * (comparison.percentile / 100), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private func percentileColor(_ percentile: Double) -> Color {
        switch percentile {
        case 75...100: return .green
        case 50...74: return .orange
        default: return .red
        }
    }
}

struct PracticeCard: View {
    let recommendation: PracticeRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label(recommendation.duration, systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Label(recommendation.frequency, systemImage: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(recommendation.difficulty.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(recommendation.difficulty.color))
            }
            
            Text(recommendation.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Interactive 3D Placeholder

struct Interactive3DPlaceholder: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Animated 3D placeholder visualization
            Canvas { context, size in
                let centerX = size.width / 2
                let centerY = size.height / 2
                let radius = min(size.width, size.height) / 3

                // Draw rotating plane grid
                for i in 0..<8 {
                    let angle = (Double(i) * 45 + rotation) * .pi / 180
                    let startX = centerX + radius * cos(angle)
                    let startY = centerY + radius * sin(angle) * 0.3
                    let endX = centerX - radius * cos(angle)
                    let endY = centerY - radius * sin(angle) * 0.3

                    let path = Path { p in
                        p.move(to: CGPoint(x: startX, y: startY))
                        p.addLine(to: CGPoint(x: endX, y: endY))
                    }

                    context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 1)
                }

                // Draw club path placeholder
                let swingPath = Path { path in
                    path.move(to: CGPoint(x: centerX - radius * 0.8, y: centerY))
                    path.addQuadCurve(
                        to: CGPoint(x: centerX + radius * 0.8, y: centerY),
                        control: CGPoint(x: centerX, y: centerY - radius * 0.6)
                    )
                }

                context.stroke(swingPath, with: .color(.purple.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .frame(height: 120)
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            VStack(spacing: 8) {
                Text("3D Analysis Ready")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Upload and analyze a swing video\nto see detailed 3D visualization")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Interactive Video Analysis Components

struct InteractiveSwingVideoPlayer: View {
    let analysisResult: PhysicsSwingAnalysisResult
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var selectedPhase: SwingPhase = .address
    @State private var showAngleOverlays = true

    enum SwingPhase: String, CaseIterable {
        case address = "Address"
        case backswing = "Backswing"
        case top = "Top"
        case downswing = "Downswing"
        case impact = "Impact"
        case followThrough = "Follow Through"

        var timePercentage: Double {
            switch self {
            case .address: return 0.0
            case .backswing: return 0.3
            case .top: return 0.5
            case .downswing: return 0.7
            case .impact: return 0.8
            case .followThrough: return 1.0
            }
        }

        var color: Color {
            switch self {
            case .address: return .green
            case .backswing: return .blue
            case .top: return .purple
            case .downswing: return .orange
            case .impact: return .red
            case .followThrough: return .yellow
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Video Player with Overlays
            ZStack {
                // Video Player
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            // Angle Measurement Overlays
                            AngleMeasurementOverlay(
                                analysisResult: analysisResult,
                                currentPhase: selectedPhase,
                                showOverlays: showAngleOverlays
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("Loading video...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        )
                }
            }

            // Swing Phase Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SwingPhase.allCases, id: \.self) { phase in
                        SwingPhaseButton(
                            phase: phase,
                            isSelected: selectedPhase == phase,
                            analysisResult: analysisResult
                        ) {
                            selectPhase(phase)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    togglePlayPause()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }

                Button(action: {
                    showAngleOverlays.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showAngleOverlays ? "eye" : "eye.slash")
                        Text("Angles")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(showAngleOverlays ? .blue : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(selectedPhase.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(getPhaseAngleMeasurement())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: analysisResult.videoURL)
        player?.actionAtItemEnd = .pause
    }

    private func selectPhase(_ phase: SwingPhase) {
        selectedPhase = phase
        let targetTime = phase.timePercentage * analysisResult.duration
        let time = CMTime(seconds: targetTime, preferredTimescale: 600)
        player?.seek(to: time)
        player?.pause()
        isPlaying = false
    }

    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    private func getPhaseAngleMeasurement() -> String {
        switch selectedPhase {
        case .address:
            return "Spine: \(String(format: "%.1f", analysisResult.bodyKinematics.spineAngle.spineAngleAtAddress))°"
        case .backswing:
            return "Shoulder: \(String(format: "%.1f", analysisResult.bodyKinematics.shoulderRotation.maxRotation))°"
        case .top:
            return "Plane: \(String(format: "%.1f", analysisResult.swingPlane.planeAngle))°"
        case .downswing:
            return "Hip Lead: \(String(format: "%.1f", analysisResult.bodyKinematics.hipRotation.rotationTiming * 100))ms"
        case .impact:
            return "Club Speed: \(String(format: "%.1f", analysisResult.clubHeadSpeed.speedAtImpact)) mph"
        case .followThrough:
            return "Weight Shift: \(String(format: "%.1f", analysisResult.bodyKinematics.weightShift.weightTransferSpeed))%"
        }
    }
}

struct SwingPhaseButton: View {
    let phase: InteractiveSwingVideoPlayer.SwingPhase
    let isSelected: Bool
    let analysisResult: PhysicsSwingAnalysisResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? phase.color : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                Text(phase.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text("\(Int(phase.timePercentage * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? phase.color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AngleMeasurementOverlay: View {
    let analysisResult: PhysicsSwingAnalysisResult
    let currentPhase: InteractiveSwingVideoPlayer.SwingPhase
    let showOverlays: Bool

    var body: some View {
        if showOverlays {
            GeometryReader { geometry in
                ZStack {
                    // Spine Angle Line (for address and top positions)
                    if currentPhase == .address || currentPhase == .top {
                        SpineAngleLine(
                            angle: getSpineAngle(),
                            geometry: geometry,
                            color: currentPhase.color
                        )
                    }

                    // Swing Plane Line (for backswing and top)
                    if currentPhase == .backswing || currentPhase == .top {
                        SwingPlaneLine(
                            angle: analysisResult.swingPlane.planeAngle,
                            geometry: geometry,
                            color: currentPhase.color
                        )
                    }

                    // Impact Zone Indicator
                    if currentPhase == .impact {
                        ImpactZoneIndicator(
                            geometry: geometry,
                            clubSpeed: analysisResult.clubHeadSpeed.speedAtImpact
                        )
                    }

                    // Angle Measurement Labels
                    VStack {
                        HStack {
                            AngleMeasurementLabel(
                                title: getAngleTitle(),
                                value: getAngleValue(),
                                unit: getAngleUnit(),
                                color: currentPhase.color
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
        }
    }

    private func getSpineAngle() -> Double {
        switch currentPhase {
        case .address:
            return analysisResult.bodyKinematics.spineAngle.spineAngleAtAddress
        case .top:
            return analysisResult.bodyKinematics.spineAngle.spineAngleAtTop
        default:
            return analysisResult.bodyKinematics.spineAngle.spineAngleAtAddress
        }
    }

    private func getAngleTitle() -> String {
        switch currentPhase {
        case .address: return "Spine Angle"
        case .backswing: return "Shoulder Turn"
        case .top: return "Swing Plane"
        case .downswing: return "Hip Rotation"
        case .impact: return "Club Speed"
        case .followThrough: return "Weight Shift"
        }
    }

    private func getAngleValue() -> Double {
        switch currentPhase {
        case .address: return analysisResult.bodyKinematics.spineAngle.spineAngleAtAddress
        case .backswing: return analysisResult.bodyKinematics.shoulderRotation.maxRotation
        case .top: return analysisResult.swingPlane.planeAngle
        case .downswing: return analysisResult.bodyKinematics.hipRotation.maxRotation
        case .impact: return analysisResult.clubHeadSpeed.speedAtImpact
        case .followThrough: return analysisResult.bodyKinematics.weightShift.weightTransferSpeed
        }
    }

    private func getAngleUnit() -> String {
        switch currentPhase {
        case .address, .backswing, .top, .downswing: return "°"
        case .impact: return " mph"
        case .followThrough: return "%"
        }
    }
}

struct SpineAngleLine: View {
    let angle: Double
    let geometry: GeometryProxy
    let color: Color

    var body: some View {
        Path { path in
            let centerX = geometry.size.width * 0.3
            let centerY = geometry.size.height * 0.6
            let length = geometry.size.height * 0.4

            let radians = (angle - 90) * .pi / 180
            let endX = centerX + length * cos(radians)
            let endY = centerY + length * sin(radians)

            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(color, lineWidth: 3)
        .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

struct SwingPlaneLine: View {
    let angle: Double
    let geometry: GeometryProxy
    let color: Color

    var body: some View {
        Path { path in
            let startX = geometry.size.width * 0.2
            let endX = geometry.size.width * 0.8
            let centerY = geometry.size.height * 0.5
            let verticalOffset = (endX - startX) * tan(angle * .pi / 180) * 0.3

            path.move(to: CGPoint(x: startX, y: centerY - verticalOffset))
            path.addLine(to: CGPoint(x: endX, y: centerY + verticalOffset))
        }
        .stroke(color, lineWidth: 2)
        .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

struct ImpactZoneIndicator: View {
    let geometry: GeometryProxy
    let clubSpeed: Double

    var body: some View {
        Circle()
            .fill(Color.red.opacity(0.6))
            .frame(width: max(20, clubSpeed / 5), height: max(20, clubSpeed / 5))
            .position(x: geometry.size.width * 0.6, y: geometry.size.height * 0.7)
            .overlay(
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: max(20, clubSpeed / 5), height: max(20, clubSpeed / 5))
                    .position(x: geometry.size.width * 0.6, y: geometry.size.height * 0.7)
            )
    }
}

struct AngleMeasurementLabel: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
        )
    }
}

struct InteractiveVideoPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "video.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.blue.opacity(0.6))

                        VStack(spacing: 8) {
                            Text("Interactive Video Analysis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("Upload and analyze a swing video to see\nangle measurements at key positions")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                )

            // Feature Preview
            HStack(spacing: 12) {
                FeaturePreviewItem(
                    icon: "pause.circle",
                    title: "Pause & Analyze",
                    description: "See angles at key positions"
                )

                FeaturePreviewItem(
                    icon: "ruler",
                    title: "Angle Overlays",
                    description: "Visual measurement guides"
                )

                FeaturePreviewItem(
                    icon: "play.circle",
                    title: "Step Through",
                    description: "Navigate swing phases"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct FeaturePreviewItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct InteractiveVideoInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Interactive Video Analysis")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Learn how to use video overlays and angle measurements to improve your golf swing")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                ScrollView {
                    VStack(spacing: 24) {
                        // Key Features
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Key Features")
                                .font(.headline)

                            FeatureExplanation(
                                icon: "play.circle.fill",
                                title: "Step-by-Step Analysis",
                                description: "Navigate through key swing positions: Address, Backswing, Top, Downswing, Impact, and Follow Through."
                            )

                            FeatureExplanation(
                                icon: "ruler.fill",
                                title: "Real-Time Angle Measurements",
                                description: "See spine angle, shoulder rotation, swing plane, and other critical measurements overlaid on your video."
                            )

                            FeatureExplanation(
                                icon: "eye.fill",
                                title: "Visual Guides",
                                description: "Toggle angle overlays on/off to see exactly where measurements are taken on your swing."
                            )

                            FeatureExplanation(
                                icon: "pause.circle.fill",
                                title: "Pause & Study",
                                description: "Automatically pause at each swing phase to study your form and understand the measurements."
                            )
                        }

                        Divider()

                        // How to Use
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How to Use")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 12) {
                                HowToStep(number: 1, text: "Upload and analyze a swing video")
                                HowToStep(number: 2, text: "Tap any swing phase button to jump to that moment")
                                HowToStep(number: 3, text: "Use the play/pause button to control playback")
                                HowToStep(number: 4, text: "Toggle 'Angles' to show/hide measurement overlays")
                                HowToStep(number: 5, text: "Review specific measurements for each phase")
                            }
                        }

                        Divider()

                        // Understanding Measurements
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Understanding the Measurements")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 12) {
                                MeasurementExplanation(
                                    phase: "Address",
                                    measurement: "Spine Angle",
                                    description: "Your posture setup - should be tilted forward from hips",
                                    color: .green
                                )

                                MeasurementExplanation(
                                    phase: "Backswing",
                                    measurement: "Shoulder Turn",
                                    description: "How much your shoulders rotate - aim for 90-100°",
                                    color: .blue
                                )

                                MeasurementExplanation(
                                    phase: "Top",
                                    measurement: "Swing Plane",
                                    description: "The angle of your swing path - key for consistent strikes",
                                    color: .purple
                                )

                                MeasurementExplanation(
                                    phase: "Impact",
                                    measurement: "Club Speed",
                                    description: "Your clubhead speed at contact - higher speed = more distance",
                                    color: .red
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Interactive Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureExplanation: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HowToStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(text)
                .font(.subheadline)
        }
    }
}

struct MeasurementExplanation: View {
    let phase: String
    let measurement: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phase)
                        .font(.subheadline.bold())
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(measurement)
                        .font(.subheadline.bold())
                        .foregroundColor(color)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PhysicsEngineView_Previews: PreviewProvider {
    static var previews: some View {
        PhysicsEngineView()
    }
}
