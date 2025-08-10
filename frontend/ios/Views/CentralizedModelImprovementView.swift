import SwiftUI

// MARK: - Centralized Model Improvement Settings
struct CentralizedModelImprovementView: View {
    @StateObject private var centralizedImprovement = CentralizedModelImprovement.shared
    @State private var showingConsentSheet = false
    @State private var showingSyncAlert = false
    @State private var isSyncing = false
    
    var body: some View {
        NavigationView {
            List {
                // Data Sharing Consent Section
                Section {
                    if centralizedImprovement.hasUserConsent {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data Sharing Enabled")
                                    .font(.headline)
                                Text("Helping improve AI for everyone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Settings") {
                                showingConsentSheet = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text("Improve AI for Everyone")
                                    .font(.headline)
                            }
                            
                            Text("Share your swing analysis data to help improve the AI model for all users. All data is anonymous and secure.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Enable Data Sharing") {
                                showingConsentSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("AI Model Improvement")
                } footer: {
                    Text("Your swing data helps train better AI models that benefit all users. Data is sent securely to our servers and processed anonymously.")
                }
                
                // Statistics Section
                if centralizedImprovement.hasUserConsent {
                    Section {
                        let stats = centralizedImprovement.getCollectionStats()
                        
                        HStack {
                            Label("Total Contributions", systemImage: "chart.bar")
                            Spacer()
                            Text("\(stats.totalCollected)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Pending Upload", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            Text("\(stats.pendingUploads)")
                                .foregroundColor(stats.pendingUploads > 0 ? .orange : .secondary)
                        }
                        
                        if let lastSync = stats.lastSyncDate {
                            HStack {
                                Label("Last Sync", systemImage: "clock")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { syncData() }) {
                            HStack {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isSyncing || stats.pendingUploads == 0)
                    } header: {
                        Text("Contribution Statistics")
                    } footer: {
                        Text("Data is automatically synced when connected to internet. Manual sync uploads any pending data.")
                    }
                }
                
                // Model Updates Section
                Section {
                    Button(action: checkForUpdates) {
                        HStack {
                            Label("Check for Model Updates", systemImage: "arrow.down.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("Current Model", systemImage: "cpu")
                        Spacer()
                        Text("v1.0-local")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Model Updates")
                } footer: {
                    Text("Periodically, improved AI models trained on community data are released through app updates.")
                }
                
                // Privacy & Benefits Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Benefits
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("Benefits of Data Sharing")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            benefitPoint("🎯", "More accurate swing analysis")
                            benefitPoint("🚀", "Faster model improvements")
                            benefitPoint("🌍", "Better AI for all users")
                            benefitPoint("📈", "Continuous learning from real swings")
                        }
                        
                        Divider()
                        
                        // Privacy
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                Text("Privacy Protection")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            privacyPoint("🔒", "All data is anonymous")
                            privacyPoint("🛡️", "No personal information collected")
                            privacyPoint("🔐", "Secure server transmission")
                            privacyPoint("⚙️", "Full control over sharing")
                            privacyPoint("🗑️", "Can opt-out anytime")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Why Share Data?")
                }
            }
            .navigationTitle("AI Improvement")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingConsentSheet) {
                DataSharingConsentView()
            }
            .alert("Sync Complete", isPresented: $showingSyncAlert) {
                Button("OK") { }
            } message: {
                Text("All pending data has been uploaded successfully.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func benefitPoint(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func privacyPoint(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func syncData() {
        isSyncing = true
        
        Task {
            await centralizedImprovement.syncPendingData()
            
            await MainActor.run {
                isSyncing = false
                showingSyncAlert = true
            }
        }
    }
    
    private func checkForUpdates() {
        Task {
            await centralizedImprovement.checkForModelUpdates()
        }
    }
}

// MARK: - Data Sharing Consent Sheet
struct DataSharingConsentView: View {
    @StateObject private var centralizedImprovement = CentralizedModelImprovement.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareAllPredictions = true
    @State private var shareFeedbackData = true
    @State private var shareAnonymousMetadata = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Help Improve Golf AI")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your anonymous swing data helps create better AI models for everyone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Data Types
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $shareAllPredictions) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share AI Predictions")
                                .font(.headline)
                            Text("Model predictions and confidence scores")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $shareFeedbackData) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share User Corrections")
                                .font(.headline)
                            Text("When you correct AI predictions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $shareAnonymousMetadata) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share Technical Data")
                                .font(.headline)
                            Text("Device type, app version, timestamps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                
                // Privacy Note
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Complete Privacy")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("• No personal information is collected\n• All data is processed anonymously\n• You can change these settings anytime\n• Data helps improve AI for all users")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Enable Data Sharing") {
                        centralizedImprovement.updateDataSharingPreferences(
                            shareAll: shareAllPredictions,
                            shareFeedback: shareFeedbackData,
                            shareMetadata: shareAnonymousMetadata
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!shareAllPredictions && !shareFeedbackData && !shareAnonymousMetadata)
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Data Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            shareAllPredictions = centralizedImprovement.shareAllPredictions
            shareFeedbackData = centralizedImprovement.shareFeedbackData
            shareAnonymousMetadata = centralizedImprovement.shareAnonymousMetadata
        }
    }
}

#Preview {
    CentralizedModelImprovementView()
}

#Preview("Consent") {
    DataSharingConsentView()
}