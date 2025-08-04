import Foundation
import SwiftUI

// MARK: - Data Collection Manager
class DataCollectionManager: ObservableObject {
    static let shared = DataCollectionManager()
    
    @Published var hasConsent = false
    @Published var anonymousUserId: String = ""
    @Published var contributionCount = 0
    @Published var lastContributionDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let apiService = APIService.shared
    
    // Privacy compliance keys
    private let consentKey = "data_collection_consent"
    private let userIdKey = "anonymous_user_id"
    private let contributionCountKey = "contribution_count"
    private let lastContributionKey = "last_contribution_date"
    private let privacyVersionKey = "privacy_policy_version"
    
    private let currentPrivacyVersion = "1.0.0"
    
    private init() {
        loadStoredConsent()
        generateAnonymousUserId()
    }
    
    // MARK: - Consent Management
    func checkConsentStatus() -> Bool {
        return hasConsent && isPrivacyVersionCurrent()
    }
    
    private func isPrivacyVersionCurrent() -> Bool {
        let storedVersion = userDefaults.string(forKey: privacyVersionKey) ?? ""
        return storedVersion == currentPrivacyVersion
    }
    
    func requestDataCollectionConsent() async throws {
        // This will trigger the consent UI
        await MainActor.run {
            self.showConsentDialog()
        }
    }
    
    func grantConsent(for dataTypes: [String]) async throws {
        let consent = DataCollectionConsent(
            user_id: anonymousUserId,
            consent_given: true,
            consent_date: ISO8601DateFormatter().string(from: Date()),
            data_types_consented: dataTypes,
            privacy_version: currentPrivacyVersion
        )
        
        // Submit consent to server
        let response = try await apiService.submitDataCollectionConsent(consent)
        
        // Store consent locally
        await MainActor.run {
            self.hasConsent = true
            self.userDefaults.set(true, forKey: self.consentKey)
            self.userDefaults.set(self.currentPrivacyVersion, forKey: self.privacyVersionKey)
            self.userDefaults.set(Date(), forKey: self.lastContributionKey)
        }
        
        print("✅ Data collection consent granted: \(response.thank_you_message)")
    }
    
    func revokeConsent() async throws {
        let consent = DataCollectionConsent(
            user_id: anonymousUserId,
            consent_given: false,
            consent_date: ISO8601DateFormatter().string(from: Date()),
            data_types_consented: [],
            privacy_version: currentPrivacyVersion
        )
        
        // Submit revocation to server
        _ = try await apiService.submitDataCollectionConsent(consent)
        
        // Clear local storage
        await MainActor.run {
            self.hasConsent = false
            self.userDefaults.removeObject(forKey: self.consentKey)
            self.userDefaults.removeObject(forKey: self.privacyVersionKey)
        }
        
        print("🚫 Data collection consent revoked")
    }
    
    // MARK: - Data Submission
    func submitSwingDataIfConsented(
        features: [String: Double],
        prediction: String,
        confidence: Double,
        cameraAngle: String?,
        sessionId: String
    ) async {
        guard checkConsentStatus() else {
            print("⚠️ No consent for data collection - skipping submission")
            return
        }
        
        let swingData = AnonymousSwingData(
            session_id: sessionId,
            swing_features: features,
            predicted_classification: prediction,
            confidence_score: confidence,
            camera_angle: cameraAngle,
            user_feedback: nil, // Added later via feedback
            timestamp: ISO8601DateFormatter().string(from: Date()),
            app_version: getAppVersion(),
            model_version: "2.0_multi_angle"
        )
        
        do {
            let response = try await apiService.submitAnonymousSwingData(swingData)
            
            await MainActor.run {
                self.contributionCount += 1
                self.lastContributionDate = Date()
                self.userDefaults.set(self.contributionCount, forKey: self.contributionCountKey)
                self.userDefaults.set(Date(), forKey: self.lastContributionKey)
            }
            
            print("✅ Swing data contributed: \(response.anonymous_id)")
        } catch {
            print("❌ Failed to submit swing data: \(error)")
        }
    }
    
    func submitUserFeedback(
        sessionId: String,
        feedback: UserFeedback
    ) async {
        guard checkConsentStatus() else { return }
        
        do {
            let response = try await apiService.submitUserFeedback(sessionId: sessionId, feedback: feedback)
            print("✅ User feedback submitted: \(response.thank_you_message)")
        } catch {
            print("❌ Failed to submit feedback: \(error)")
        }
    }
    
    // MARK: - Stats & Analytics
    func getContributionStats() async throws -> DataContributionStats {
        return try await apiService.getDataContributionStats(userId: anonymousUserId)
    }
    
    // MARK: - Helper Methods
    private func generateAnonymousUserId() {
        if anonymousUserId.isEmpty {
            if let storedId = userDefaults.string(forKey: userIdKey) {
                anonymousUserId = storedId
            } else {
                anonymousUserId = UUID().uuidString
                userDefaults.set(anonymousUserId, forKey: userIdKey)
            }
        }
    }
    
    private func loadStoredConsent() {
        hasConsent = userDefaults.bool(forKey: consentKey) && isPrivacyVersionCurrent()
        contributionCount = userDefaults.integer(forKey: contributionCountKey)
        lastContributionDate = userDefaults.object(forKey: lastContributionKey) as? Date
    }
    
    private func showConsentDialog() {
        // This will be handled by the UI
        NotificationCenter.default.post(name: .showDataCollectionConsent, object: nil)
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showDataCollectionConsent = Notification.Name("showDataCollectionConsent")
    static let dataCollectionConsentGranted = Notification.Name("dataCollectionConsentGranted")
    static let dataCollectionConsentRevoked = Notification.Name("dataCollectionConsentRevoked")
}

// MARK: - Data Collection Consent View
struct DataCollectionConsentView: View {
    @StateObject private var dataManager = DataCollectionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDataTypes: Set<String> = []
    @State private var showDetailedInfo = false
    @State private var isSubmitting = false
    
    private let availableDataTypes = [
        "swing_videos": "Swing Video Analysis",
        "analysis_results": "AI Prediction Results", 
        "feedback": "Your Feedback & Ratings"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Help Improve Golf Swing AI")
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Your anonymous data helps train our AI to provide better swing analysis for everyone")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Benefits
                    VStack(spacing: 16) {
                        benefitItem(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Improve Accuracy",
                            description: "More data = better predictions for all users"
                        )
                        
                        benefitItem(
                            icon: "lock.shield",
                            title: "100% Anonymous",
                            description: "No personal information is ever collected"
                        )
                        
                        benefitItem(
                            icon: "person.3",
                            title: "Community Driven",
                            description: "Help build the best golf AI together"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Data Types Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What data can we use?")
                            .font(.system(size: 18, weight: .semibold))
                        
                        ForEach(Array(availableDataTypes.keys), id: \.self) { key in
                            dataTypeToggle(key: key, title: availableDataTypes[key] ?? "")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Privacy Details
                    Button(action: { showDetailedInfo.toggle() }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Privacy Details")
                            Spacer()
                            Image(systemName: showDetailedInfo ? "chevron.up" : "chevron.down")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    
                    if showDetailedInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            privacyDetailItem("🔒", "All data is anonymized before transmission")
                            privacyDetailItem("🚫", "No personal information, account data, or identifying details")
                            privacyDetailItem("🎯", "Only swing mechanics and AI prediction data")
                            privacyDetailItem("✋", "You can revoke consent anytime in Settings")
                            privacyDetailItem("🗑️", "Request data deletion anytime")
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .slide))
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: grantConsent) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text(isSubmitting ? "Submitting..." : "Yes, Help Improve AI")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedDataTypes.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(selectedDataTypes.isEmpty || isSubmitting)
                        
                        Button("No Thanks") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Data Collection")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func benefitItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func dataTypeToggle(key: String, title: String) -> some View {
        Button(action: {
            if selectedDataTypes.contains(key) {
                selectedDataTypes.remove(key)
            } else {
                selectedDataTypes.insert(key)
            }
        }) {
            HStack {
                Image(systemName: selectedDataTypes.contains(key) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedDataTypes.contains(key) ? .blue : .gray)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
    
    private func privacyDetailItem(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func grantConsent() {
        guard !selectedDataTypes.isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await dataManager.grantConsent(for: Array(selectedDataTypes))
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                }
                print("❌ Failed to grant consent: \(error)")
            }
        }
    }
}