import SwiftUI
import Foundation
import PhotosUI
import AVFoundation
import StoreKit
import Vision
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
        // Add mock videos for development
        loadMockVideos()
    }
    
    private func loadMockVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        userVideos = [
            UserVideo(
                name: "Driver Swing - Range Session",
                url: documentsPath.appendingPathComponent("mock_driver.mov"),
                duration: 3.2,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                fileSize: 15_000_000
            ),
            UserVideo(
                name: "Iron Shot - Practice",
                url: documentsPath.appendingPathComponent("mock_iron.mov"),
                duration: 2.8,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                fileSize: 12_000_000
            ),
            UserVideo(
                name: "Wedge Swing - Short Game",
                url: documentsPath.appendingPathComponent("mock_wedge.mov"),
                duration: 2.1,
                createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
                fileSize: 8_500_000
            )
        ]
    }
    
    func addVideo(from url: URL) async {
        isLoading = true
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let newVideo = UserVideo(
            name: "New Golf Swing",
            url: url,
            duration: 3.0,
            createdAt: Date(),
            fileSize: 14_000_000
        )
        
        userVideos.insert(newVideo, at: 0)
        isLoading = false
    }
    
    func selectVideo(_ video: UserVideo) {
        selectedVideo = video
    }
    
    func clearSelection() {
        selectedVideo = nil
    }
    
    func deleteVideo(_ video: UserVideo) {
        userVideos.removeAll { $0.id == video.id }
        if selectedVideo?.id == video.id {
            selectedVideo = nil
        }
    }
}

// MARK: - Physics Engine Premium View

struct PhysicsEnginePremiumView: View {
    @Environment(\.dismiss) private var dismiss
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
                            title: "Advanced Physics Engine",
                            description: "3D biomechanics analysis with force vectors"
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
                        Button(action: {
                            print("🔘 Start Premium button pressed!")
                            Task {
                                isLoading = true
                                purchaseError = nil
                                
                                // Check if user actually has premium access (not just development mode)
                                if PremiumManager.shared.hasPhysicsEnginePremium && !PremiumManager.shared.isDevelopmentMode {
                                    print("✅ User already has premium access, dismissing paywall")
                                    dismiss()
                                    return
                                }
                                
                                // For DEBUG builds only, allow development mode to bypass
                                #if DEBUG
                                if PremiumManager.shared.isDevelopmentMode && PremiumManager.shared.hasPhysicsEnginePremium {
                                    print("🔧 DEBUG: Development mode active with premium access")
                                    dismiss()
                                    return
                                }
                                #endif
                                
                                print("🔘 Selected plan: \(selectedPlan)")
                                switch selectedPlan {
                                case .monthly:
                                    print("🔘 Purchasing monthly subscription...")
                                    await PremiumManager.shared.purchaseMonthlySubscription()
                                case .annual:
                                    print("🔘 Purchasing annual subscription...")
                                    await PremiumManager.shared.purchaseAnnualSubscription()
                                }
                                
                                // Small delay to ensure state updates
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                
                                if PremiumManager.shared.hasPhysicsEnginePremium {
                                    print("✅ Premium access granted, dismissing paywall")
                                    dismiss()
                                } else {
                                    print("⚠️ Premium access not granted yet")
                                }
                                
                                // Get error from PremiumManager if any
                                purchaseError = PremiumManager.shared.purchaseError
                                
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
                                await PremiumManager.shared.restorePurchases()
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
                                    PremiumManager.shared.enableDevelopmentModeForTesting()
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
                            Button("Terms of Service") { /* Handle terms */ }
                            Button("Privacy Policy") { /* Handle privacy */ }
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
            print("🔧 isDevelopmentMode: \(PremiumManager.shared.isDevelopmentMode)")
            print("🔧 hasPhysicsEnginePremium: \(PremiumManager.shared.hasPhysicsEnginePremium)")
            print("🔧 canAccessPhysicsEngine: \(PremiumManager.shared.canAccessPhysicsEngine)")
            print("🔧 availableProducts count: \(PremiumManager.shared.availableProducts.count)")
            for product in PremiumManager.shared.availableProducts {
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
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Video Upload")
                    .font(.largeTitle)
                    .padding()
                
                Text("Video upload functionality coming soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Upload Video")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") { dismiss() }
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
    
    func analyzeSwingVideo(url: URL) async -> PhysicsSwingAnalysisResult? {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        defer {
            isAnalyzing = false
            analysisProgress = 0.0
        }
        
        do {
            // Simulate realistic analysis with progressive updates
            for progress in stride(from: 0.1, through: 1.0, by: 0.1) {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                analysisProgress = progress
            }
            
            // Generate realistic analysis results
            let result = generateRealisticAnalysis(url: url)
            currentAnalysis = result
            return result
            
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func generateRealisticAnalysis(url: URL) -> PhysicsSwingAnalysisResult {
        // Generate realistic but varied data
        let clubSpeed = Double.random(in: 85...115)
        let consistency = Double.random(in: 0.6...0.95)
        let tempoRatio = Double.random(in: 2.2...4.0)
        
        let clubData = ClubHeadSpeedData(
            peakSpeed: clubSpeed + Double.random(in: 0...8),
            speedAtImpact: clubSpeed,
            accelerationProfile: (0...60).map { _ in Double.random(in: 20...clubSpeed) },
            impactFrame: 35,
            trackingPoints: (0...60).map { i in
                CGPoint(x: Double(i) * 5, y: sin(Double(i) * 0.1) * 50 + 200)
            }
        )
        
        let bodyData = BodyKinematicsData(
            shoulderRotation: RotationData(
                maxRotation: Double.random(in: 80...100),
                rotationSpeed: Double.random(in: 400...500),
                rotationTiming: Double.random(in: 0.7...0.9),
                rotationSequence: []
            ),
            hipRotation: RotationData(
                maxRotation: Double.random(in: 40...55),
                rotationSpeed: Double.random(in: 300...400),
                rotationTiming: Double.random(in: 0.5...0.7),
                rotationSequence: []
            ),
            armPositions: ArmPositionData(
                leftArmAngle: [],
                rightArmAngle: [],
                armExtension: Double.random(in: 0.8...0.95),
                wristCockAngle: Double.random(in: 70...85)
            ),
            spineAngle: SpineAngleData(
                spineAngleAtAddress: Double.random(in: 28...35),
                spineAngleAtTop: Double.random(in: 30...37),
                spineAngleAtImpact: Double.random(in: 25...32),
                spineStability: Double.random(in: 0.75...0.95)
            ),
            weightShift: WeightShiftData(
                initialWeight: CGPoint(x: 0, y: 0),
                weightAtTop: CGPoint(x: Double.random(in: -0.3...0.1), y: Double.random(in: -0.2...0)),
                weightAtImpact: CGPoint(x: Double.random(in: 0.1...0.4), y: Double.random(in: 0...0.3)),
                weightTransferSpeed: Double.random(in: 1.5...3.0)
            ),
            addressPosition: BodyPosition(frame: 0, timestamp: 0, jointPositions: [:], centerOfMass: .zero),
            topOfBackswing: BodyPosition(frame: 20, timestamp: 0.33, jointPositions: [:], centerOfMass: .zero),
            impactPosition: BodyPosition(frame: 35, timestamp: 0.58, jointPositions: [:], centerOfMass: .zero),
            followThrough: BodyPosition(frame: 50, timestamp: 0.83, jointPositions: [:], centerOfMass: .zero)
        )
        
        let planeData = SwingPlaneData(
            planeAngle: Double.random(in: 55...70),
            planeConsistency: consistency,
            clubPath: Double.random(in: -4...4),
            attackAngle: Double.random(in: -2...3),
            planeVisualization: []
        )
        
        let tempoData = SwingTempoData(
            backswingTime: Double.random(in: 0.7...1.1),
            downswingTime: Double.random(in: 0.25...0.35),
            totalTime: Double.random(in: 1.2...1.8),
            tempoRatio: tempoRatio,
            pauseAtTop: Double.random(in: 0...0.15)
        )
        
        let quality = TrackingQuality(
            clubVisibility: Double.random(in: 0.7...0.95),
            bodyVisibility: Double.random(in: 0.8...0.95),
            lightingQuality: Double.random(in: 0.6...0.9),
            cameraAngle: Double.random(in: 0.5...0.85),
            motionBlur: Double.random(in: 0.1...0.4)
        )
        
        return PhysicsSwingAnalysisResult(
            timestamp: Date(),
            videoURL: url,
            duration: 2.5,
            clubHeadSpeed: clubData,
            bodyKinematics: bodyData,
            swingPlane: planeData,
            tempo: tempoData,
            ballFlight: nil,
            trackingQuality: quality,
            confidence: quality.overallScore,
            framesCaptured: 60,
            framesAnalyzed: 60
        )
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
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var videoManager = VideoManager()
    @StateObject private var videoAnalyzer = SwingVideoAnalyzer()
    @State private var selectedTab = 0
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0.0
    @State private var showingPremiumPaywall = false
    @State private var showingVideoPicker = false
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
                            Text("Physics Engine")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Advanced biomechanics analysis")
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
                
                // Elite Benchmarks
                EliteBenchmarksGrid()
                    .padding(.horizontal, 24)
                
                // Analysis Tabs
                VStack(spacing: 20) {
                    // Tab Selector
                    HStack(spacing: 0) {
                        PhysicsTabButton(title: "Kinematics", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        PhysicsTabButton(title: "Forces", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                        PhysicsTabButton(title: "Energy", isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Tab Content
                    Group {
                        switch selectedTab {
                        case 0:
                            KinematicsAnalysisView()
                        case 1:
                            ForceAnalysisView()
                        case 2:
                            EnergyAnalysisView()
                        default:
                            KinematicsAnalysisView()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
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
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 16, weight: .medium))
                            Text("Export Physics Report")
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
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Physics Engine")
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
            
            Spacer()
        }
        .navigationTitle("Physics Engine")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func startRealAnalysis() {
        guard let selectedVideo = videoManager.selectedVideo else {
            return
        }
        
        Task {
            if let analysisResult = await videoAnalyzer.analyzeSwingVideo(url: selectedVideo.url) {
                let feedback = SwingFeedbackEngine.generateFeedback(from: analysisResult)
                currentFeedback = feedback
                showingFeedback = true
            }
        }
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

struct EliteBenchmarksGrid: View {
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
                        yourPotential: "Analysis Required",
                        color: .blue
                    )
                    
                    EliteBenchmarkCard(
                        icon: "arrow.up.right",
                        title: "Launch Angle",
                        eliteValue: "10.9°",
                        eliteUnit: "",
                        yourPotential: "Analysis Required", 
                        color: .green
                    )
                }
                
                HStack(spacing: 12) {
                    EliteBenchmarkCard(
                        icon: "target",
                        title: "Accuracy",
                        eliteValue: "71%",
                        eliteUnit: "",
                        yourPotential: "Analysis Required",
                        color: .orange
                    )
                    
                    EliteBenchmarkCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Distance",
                        eliteValue: "320",
                        eliteUnit: "yds",
                        yourPotential: "Analysis Required",
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

// MARK: - Kinematics Analysis View

struct KinematicsAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("3D Motion Analysis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                KinematicsMetric(label: "Swing Plane Angle", value: "62.5°", trend: .stable)
                KinematicsMetric(label: "Hip Rotation", value: "45.2°", trend: .up)
                KinematicsMetric(label: "Shoulder Turn", value: "87.8°", trend: .up)
                KinematicsMetric(label: "Wrist Cock Angle", value: "78.3°", trend: .stable)
                KinematicsMetric(label: "Club Path", value: "-1.2°", trend: .down)
            }
            
            // 3D Visualization Placeholder
            VStack(spacing: 12) {
                Text("3D Swing Visualization")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.secondary)
                            
                            Text("3D Swing Model")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

// MARK: - Force Analysis View

struct ForceAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Force Vector Analysis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForceMetric(label: "Ground Reaction Force", value: "1,245 N", direction: "Vertical")
                ForceMetric(label: "Grip Force", value: "389 N", direction: "Radial")
                ForceMetric(label: "Centrifugal Force", value: "567 N", direction: "Outward")
                ForceMetric(label: "Impact Force", value: "2,847 N", direction: "Forward")
            }
            
            // Force Vector Diagram
            VStack(spacing: 12) {
                Text("Force Vector Diagram")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "arrow.up.right.and.arrow.down.left")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.orange)
                            
                            Text("Force Vectors")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

// MARK: - Energy Analysis View

struct EnergyAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Energy Transfer Analysis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                EnergyMetric(label: "Total Energy Generated", value: "1,456 J")
                EnergyMetric(label: "Energy to Club Head", value: "1,272 J")
                EnergyMetric(label: "Energy Transfer Efficiency", value: "87.3%")
                EnergyMetric(label: "Ball Kinetic Energy", value: "245 J")
                EnergyMetric(label: "Energy Loss", value: "184 J")
            }
            
            // Energy Flow Chart
            VStack(spacing: 12) {
                Text("Energy Flow Analysis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.blue)
                            
                            Text("Energy Flow Chart")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
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
                SelectedVideoCard(video: selectedVideo)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 60, height: 40)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Duration: \(String(format: "%.1f", video.duration))s")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // Remove video selection
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
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

struct PhysicsEngineView_Previews: PreviewProvider {
    static var previews: some View {
        PhysicsEngineView()
    }
}
