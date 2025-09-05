import SwiftUI

// MARK: - Model Settings View

struct ModelSettingsView: View {
    @StateObject private var localAIManager = LocalAIManager.shared
    @StateObject private var apiService = APIService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var isCheckingUpdates = false
    
    var body: some View {
        NavigationView {
            List {
                
                // Model Status Section
                Section("Local AI Models") {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.headline)
                            Text(LocalAIManager.shared.isModelsLoaded ? "Ready" : "Loading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if LocalAIManager.shared.isModelsLoaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if !LocalAIManager.shared.isModelsLoaded {
                        HStack {
                            Text("Loading Progress")
                            Spacer()
                            Text("\(Int(LocalAIManager.shared.loadingProgress * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: LocalAIManager.shared.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
                
                // Available Models Section
                Section("Available Models") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text("Swing Analysis Model")
                                    .font(.headline)
                                Text("On-device pose analysis and swing classification")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(localAIManager.isModelsLoaded ? "Ready" : "Loading...")
                                .font(.caption)
                                .foregroundColor(localAIManager.isModelsLoaded ? .green : .orange)
                        }
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Storage Used")
                                .font(.headline)
                            Text("Models included in app bundle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Info Section
                Section("Information") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Local AI Processing")
                                .font(.headline)
                            Text("All analysis runs on-device for privacy and speed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.large)
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


// MARK: - Preview

struct ModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSettingsView()
    }
}