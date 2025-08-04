import SwiftUI

struct OfflineModeView: View {
    @StateObject private var apiService = APIService.shared
    @State private var showingCacheSettings = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Offline Icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.orange)
                .padding()
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                )
            
            // Offline Message
            VStack(spacing: 12) {
                Text("You're Offline")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("No internet connection available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Available Features
            VStack(spacing: 16) {
                Text("Available Offline:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    OfflineFeatureRow(
                        icon: "video.circle.fill",
                        title: "Cached Analysis Results",
                        description: "View previously analyzed swings"
                    )
                    
                    OfflineFeatureRow(
                        icon: "message.circle.fill",
                        title: "Cached Chat Responses",
                        description: "Review previous golf advice"
                    )
                    
                    OfflineFeatureRow(
                        icon: "gearshape.circle.fill",
                        title: "App Settings",
                        description: "Manage your preferences"
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            
            // Connection Tips
            VStack(spacing: 16) {
                Text("To get back online:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(text: "Check your WiFi or cellular connection")
                    TipRow(text: "Try moving to an area with better signal")
                    TipRow(text: "Restart your network connection")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            
            // Cache Settings Button
            Button(action: { showingCacheSettings = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("View Cache & Network Settings")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingCacheSettings) {
            CacheSettingsView()
        }
    }
}

struct OfflineFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    OfflineModeView()
}