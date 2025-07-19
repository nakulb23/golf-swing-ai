import SwiftUI
import PhotosUI

struct SwingAnalysisView: View {
    @StateObject private var apiService = APIService.shared
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var isAnalyzing = false
    @State private var analysisResult: SwingAnalysisResponse?
    @State private var showClassifications = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Swing Analysis")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Upload your golf swing video for AI-powered analysis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)
                        
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
                                        .foregroundColor(videoData != nil ? .green : .blue)
                                    
                                    Text(videoData != nil ? "Video Selected" : "Select Golf Swing Video")
                                        .font(.headline)
                                    
                                    Text(videoData != nil ? "Tap to change video" : "Choose from your photo library")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(videoData != nil ? Color.green.opacity(0.5) : Color.blue.opacity(0.3), lineWidth: 2)
                                )
                            }
                            
                            // Analyze Button
                            Button(action: analyzeSwing) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(isAnalyzing ? "Analyzing..." : "Analyze Swing")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(videoData != nil && !isAnalyzing ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(videoData == nil || isAnalyzing)
                        }
                        
                        // Analysis Results
                        if let result = analysisResult {
                            AnalysisResultView(result: result)
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Analysis Error")
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
                
                // Swing Classifications Overlay
                if showClassifications {
                    SwingClassificationsOverlay(isPresented: $showClassifications)
                }
            }
            .navigationTitle("Swing Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showClassifications = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onChange(of: selectedVideo) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    videoData = data
                    analysisResult = nil
                    errorMessage = nil
                }
            }
        }
    }
    
    private func analyzeSwing() {
        guard let data = videoData else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await apiService.analyzeSwing(videoData: data)
                
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to analyze swing: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

struct AnalysisResultView: View {
    let result: SwingAnalysisResponse
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Analysis Results")
                .font(.title2)
                .fontWeight(.bold)
            
            // Main Result Card
            VStack(spacing: 12) {
                Text(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorForLabel(result.predicted_label))
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(Int(result.confidence * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(String(format: "%.1f°", result.physics_insights.avg_plane_angle))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Plane Angle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(colorForLabel(result.predicted_label).opacity(0.1))
            .cornerRadius(12)
            
            // Physics Analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("Physics Analysis")
                    .font(.headline)
                
                Text(result.physics_insights.plane_analysis)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Detailed Probabilities
            VStack(alignment: .leading, spacing: 8) {
                Text("Detailed Breakdown")
                    .font(.headline)
                
                ForEach(Array(result.all_probabilities.sorted(by: { $0.value > $1.value })), id: \.key) { key, value in
                    HStack {
                        Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        Spacer()
                        Text("\(Int(value * 100))%")
                            .fontWeight(.semibold)
                            .foregroundColor(colorForLabel(key))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func colorForLabel(_ label: String) -> Color {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return .green
        case "too_steep", "too steep":
            return .red
        case "too_flat", "too flat":
            return .orange
        default:
            return .blue
        }
    }
}

struct SwingClassificationsOverlay: View {
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
                    Text("Swing Classifications")
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
                
                VStack(spacing: 16) {
                    ClassificationCard(
                        title: "On Plane",
                        range: "35-55°",
                        description: "Ideal swing plane angle that promotes consistent ball striking and accuracy",
                        color: .green
                    )
                    
                    ClassificationCard(
                        title: "Too Steep",
                        range: ">55°",
                        description: "Swing plane is too vertical, often leads to slices and fat shots",
                        color: .red
                    )
                    
                    ClassificationCard(
                        title: "Too Flat",
                        range: "<35°",
                        description: "Swing plane is too horizontal, can cause hooks and inconsistent contact",
                        color: .orange
                    )
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(20)
        }
    }
}

struct ClassificationCard: View {
    let title: String
    let range: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text(range)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}


#Preview {
    SwingAnalysisView()
}