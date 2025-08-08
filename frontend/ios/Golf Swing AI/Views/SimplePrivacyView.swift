import SwiftUI

struct SimplePrivacyView: View {
    @ObservedObject private var analytics = SimpleAnalytics.shared
    @State private var showingExportAlert = false
    @State private var showingClearAlert = false
    @State private var exportText = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Analytics Settings") {
                    Toggle("Anonymous Analytics", isOn: $analytics.isEnabled)
                        .onChange(of: analytics.isEnabled) { oldValue, newValue in
                            analytics.setEnabled(newValue)
                        }
                    
                    if analytics.isEnabled {
                        HStack {
                            Text("Events Collected")
                            Spacer()
                            Text("\(analytics.getEventCount())")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if analytics.isEnabled {
                    Section("Privacy Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What we collect:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("• Authentication methods used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• General profile info (experience level, handicap ranges)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• App usage patterns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Swing analysis metrics (speed ranges)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy protection:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("• No personal information (names, emails)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Anonymous session IDs only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Data stored locally on your device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• You control all data collection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section("Data Management") {
                        Button("Export Data") {
                            exportText = analytics.exportData()
                            showingExportAlert = true
                        }
                        
                        Button("Request Data Deletion", role: .destructive) {
                            requestDataDeletion()
                        }
                        
                        Button("Clear All Data", role: .destructive) {
                            showingClearAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.large)
            .alert("Export Data", isPresented: $showingExportAlert) {
                Button("Share") {
                    let activityVC = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your anonymous analytics data is ready to export.")
            }
            .alert("Clear All Data?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    analytics.clearAllData()
                }
            } message: {
                Text("This will permanently delete all locally stored analytics data.")
            }
        }
    }
    
    private func requestDataDeletion() {
        let email = "privacy@golfswingai.com"
        let subject = "Data Deletion Request - Golf Swing AI"
        let body = """
        Hi Golf Swing AI Team,
        
        I would like to request the deletion of my account and all associated data.
        
        Device Information:
        - Device: \(UIDevice.current.model)
        - iOS Version: \(UIDevice.current.systemVersion)
        - App Version: 1.0.0
        
        I confirm that I want to permanently delete all my data from Golf Swing AI, including:
        - Account information
        - Golf profile data
        - Swing analysis history
        - All personal data
        
        Please process this request within 30 days as required by privacy regulations.
        
        Thank you.
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                SimpleAnalytics.shared.trackEvent("data_deletion_requested")
            }
        }
    }
}

#Preview {
    SimplePrivacyView()
}