import SwiftUI

struct CacheSettingsView: View {
    @StateObject private var apiService = APIService.shared
    @State private var cacheStats: CacheStatistics?
    @State private var isLoading = false
    @State private var showingClearConfirmation = false
    
    private let logger = Logger.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // Cache Statistics
                    if let stats = cacheStats {
                        VStack(spacing: 16) {
                            // Hit Rate
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Hit Rate")
                                        .font(.headline)
                                    Text("How often cached data is used")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(stats.formattedHitRate)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(hitRateColor(stats.hitRate))
                            }
                            
                            Divider()
                            
                            // Cache Performance Metrics
                            VStack(spacing: 12) {
                                MetricRow(title: "Cache Hits", value: "\(stats.hitCount)")
                                MetricRow(title: "Cache Misses", value: "\(stats.missCount)")
                                MetricRow(title: "Total Requests", value: "\(stats.hitCount + stats.missCount)")
                            }
                            
                            Divider()
                            
                            // Storage Information
                            VStack(spacing: 12) {
                                MetricRow(title: "Items Cached", value: "\(stats.itemCount)")
                                MetricRow(title: "Disk Usage", value: stats.formattedDiskSize)
                            }
                        }
                        .padding(.vertical, 8)
                    } else if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading cache statistics...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("Cache statistics unavailable")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                } header: {
                    Text("Cache Performance")
                } footer: {
                    Text("Cache improves app performance by storing frequently accessed data locally.")
                }
                
                Section {
                    // Network Status
                    HStack {
                        Image(systemName: apiService.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(apiService.isOnline ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Network Status")
                                .font(.headline)
                            Text(apiService.isOnline ? "Connected" : "Offline")
                                .font(.subheadline)
                                .foregroundColor(apiService.isOnline ? .green : .red)
                        }
                        
                        Spacer()
                        
                        if let connectionType = apiService.connectionType {
                            Text(connectionType.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Network Information")
                } footer: {
                    Text(apiService.isOnline ? "App will use cached data when available to improve performance." : "App is currently using cached data only. Some features may be limited.")
                }
                
                Section {
                    // Cache Management Actions
                    Button(action: refreshCacheStats) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Statistics")
                        }
                    }
                    .disabled(isLoading)
                    
                    Button(action: { showingClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cache")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isLoading)
                } header: {
                    Text("Cache Management")
                } footer: {
                    Text("Clearing cache will remove all stored analysis results and chat responses. They will need to be fetched again when needed.")
                }
            }
            .navigationTitle("Cache & Network")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshCacheStatsAsync()
            }
            .task {
                await loadCacheStatistics()
            }
            .confirmationDialog(
                "Clear Cache",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Cache", role: .destructive) {
                    clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all cached analysis results and chat responses. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Views
    private struct MetricRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func hitRateColor(_ rate: Double) -> Color {
        if rate >= 0.8 {
            return .green
        } else if rate >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func loadCacheStatistics() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let stats = await apiService.getCacheStatistics()
            await MainActor.run {
                self.cacheStats = stats
                logger.debug("Cache statistics loaded: \(stats.hitCount) hits, \(stats.missCount) misses", category: .ui)
            }
        }
    }
    
    private func refreshCacheStats() {
        Task {
            await refreshCacheStatsAsync()
        }
    }
    
    private func refreshCacheStatsAsync() async {
        await loadCacheStatistics()
    }
    
    private func clearCache() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            await apiService.clearCache()
            await loadCacheStatistics()
            
            await MainActor.run {
                logger.info("Cache cleared by user", category: .ui)
            }
        }
    }
}

#Preview {
    CacheSettingsView()
}