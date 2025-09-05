import SwiftUI

// MARK: - Model Improvement Settings View
struct ModelImprovementSettingsView: View {
    @StateObject private var feedbackCollector = ModelFeedbackCollector.shared
    @StateObject private var retrainingPipeline = ModelRetrainingPipeline.shared
    @State private var showingExportAlert = false
    @State private var exportURL: URL?
    @State private var showingClearDataAlert = false
    @State private var showingRetrainingAlert = false
    @State private var isExporting = false
    @State private var recommendations: [ModelImprovementRecommendation] = []
    
    var body: some View {
        NavigationView {
            List {
                // Data Collection Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("AI Model Improvement")
                                    .font(.headline)
                                Text("Help make our swing analysis more accurate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Your feedback on swing predictions helps improve the AI model for everyone while keeping all data completely private and local.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle("Enable Feedback Collection", isOn: $feedbackCollector.feedbackEnabled)
                        .onChange(of: feedbackCollector.feedbackEnabled) { _, newValue in
                            feedbackCollector.enableDataCollection(newValue)
                        }
                } header: {
                    Text("Data Collection")
                } footer: {
                    Text("When enabled, the app may ask for your feedback on swing analysis results to improve accuracy. All data stays on your device.")
                }
                
                // Statistics Section
                Section {
                    let stats = feedbackCollector.getCollectionStats()
                    
                    HStack {
                        Label("Total Samples", systemImage: "chart.bar")
                        Spacer()
                        Text("\(stats.totalSamples)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("With Feedback", systemImage: "hand.thumbsup")
                        Spacer()
                        Text("\(stats.feedbackSamples)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Uncertain Predictions", systemImage: "questionmark.circle")
                        Spacer()
                        Text("\(stats.uncertainSamples)")
                            .foregroundColor(.secondary)
                    }
                    
                    // Class Distribution
                    if !stats.classDistribution.isEmpty {
                        DisclosureGroup("Prediction Distribution") {
                            ForEach(stats.classDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { key, count in
                                HStack {
                                    Text(key.capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } header: {
                    Text("Collection Statistics")
                } footer: {
                    Text("Statistics are updated in real-time as you use the app and provide feedback.")
                }
                
                // Model Retraining Section
                Section {
                    Button(action: { showingRetrainingAlert = true }) {
                        HStack {
                            Label("Retrain AI Model", systemImage: "brain")
                            Spacer()
                            if retrainingPipeline.isRetraining {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(retrainingPipeline.isRetraining || feedbackCollector.collectedSamplesCount < 50)
                    
                    if let lastDate = retrainingPipeline.lastRetrainingDate {
                        HStack {
                            Label("Last Retrained", systemImage: "clock")
                            Spacer()
                            Text(lastDate, style: .relative)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    if retrainingPipeline.isRetraining {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Retraining Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: retrainingPipeline.retrainingProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text("\(Int(retrainingPipeline.retrainingProgress * 100))% Complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI Model Training")
                } footer: {
                    Text("Retrain the AI model using your feedback data to improve accuracy. Requires at least 50 samples with feedback.")
                }
                
                // Data Management Section
                Section {
                    Button(action: exportData) {
                        HStack {
                            Label("Export Training Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting || feedbackCollector.collectedSamplesCount == 0)
                    
                    Button(action: { showingClearDataAlert = true }) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(feedbackCollector.collectedSamplesCount == 0)
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export data creates an anonymous training file. Clearing data permanently removes all collected feedback - this cannot be undone.")
                }
                
                // Recommendations Section
                if !recommendations.isEmpty {
                    Section {
                        ForEach(recommendations, id: \.title) { recommendation in
                            RecommendationRow(recommendation: recommendation)
                        }
                    } header: {
                        Text("Improvement Recommendations")
                    } footer: {
                        Text("AI-generated suggestions to improve model performance based on your usage patterns.")
                    }
                }
                
                // Privacy Information
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                            Text("Complete Privacy")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            privacyPoint("All data stays on your device")
                            privacyPoint("No personal information is collected")
                            privacyPoint("No internet connection required")
                            privacyPoint("You control when to share data")
                            privacyPoint("Exported data is anonymous")
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy Protection")
                }
            }
            .navigationTitle("Model Improvement")
            .navigationBarTitleDisplayMode(.large)
            .alert("Export Complete", isPresented: $showingExportAlert) {
                if let url = exportURL {
                    Button("Share") {
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.rootViewController?.present(activityVC, animated: true)
                        }
                    }
                }
                Button("OK") { }
            } message: {
                Text("Training data has been exported successfully. This anonymous file can be used to improve the AI model.")
            }
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Clear", role: .destructive) {
                    feedbackCollector.clearAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all collected feedback data. This action cannot be undone.")
            }
            .alert("Retrain AI Model?", isPresented: $showingRetrainingAlert) {
                Button("Retrain") {
                    Task {
                        if let exportURL = feedbackCollector.exportTrainingData() {
                            do {
                                try await retrainingPipeline.processExportedData(exportURL)
                                // Clean up export file
                                try? FileManager.default.removeItem(at: exportURL)
                            } catch {
                                print("Retraining failed: \(error)")
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will create a new AI model trained on your feedback data. The process may take several minutes.")
            }
            .onAppear {
                Task {
                    recommendations = await retrainingPipeline.getImprovementRecommendations()
                }
            }
        }
    }
}

// MARK: - Recommendation Row
struct RecommendationRow: View {
    let recommendation: ModelImprovementRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: priorityIcon)
                    .foregroundColor(priorityColor)
                    .font(.caption)
                
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Action: \(recommendation.actionRequired)")
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
        }
        .padding(.vertical, 4)
    }
    
    private var priorityIcon: String {
        switch recommendation.priority {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "lightbulb.fill"
        }
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    // MARK: - Helper Methods
    
    private func privacyPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            if let url = feedbackCollector.exportTrainingData() {
                await MainActor.run {
                    exportURL = url
                    showingExportAlert = true
                    isExporting = false
                }
            } else {
                await MainActor.run {
                    isExporting = false
                    // Could show error alert here
                }
            }
        }
    }
}

// MARK: - Compact Widget Version
struct ModelImprovementWidget: View {
    @StateObject private var feedbackCollector = ModelFeedbackCollector.shared
    
    var body: some View {
        NavigationLink {
            ModelImprovementSettingsView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI Improvement")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if feedbackCollector.feedbackEnabled {
                        Text("\(feedbackCollector.collectedSamplesCount) samples collected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Feedback collection disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ModelImprovementSettingsView()
}

#Preview("Widget") {
    NavigationView {
        List {
            ModelImprovementWidget()
        }
    }
}