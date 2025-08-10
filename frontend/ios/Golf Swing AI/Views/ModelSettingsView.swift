import SwiftUI

// MARK: - Model Settings View

struct ModelSettingsView: View {
    @StateObject private var modelManager = LocalModelManager.shared
    @StateObject private var apiService = APIService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: ModelInfo?
    @State private var isCheckingUpdates = false
    
    var body: some View {
        NavigationView {
            List {
                // Analysis Mode Section
                Section("Analysis Mode") {
                    ForEach(AnalysisMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                    .font(.headline)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if apiService.analysisMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            apiService.analysisMode = mode
                        }
                    }
                }
                
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
                    ForEach(modelManager.availableModels) { model in
                        ModelRowView(
                            model: model,
                            onDownload: {
                                Task {
                                    try await modelManager.downloadModel(model)
                                }
                            },
                            onDelete: {
                                modelToDelete = model
                                showingDeleteAlert = true
                            }
                        )
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
                            Text(modelManager.getStorageUsed())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Clear All") {
                            modelManager.clearAllModels()
                        }
                        .foregroundColor(.red)
                        .disabled(modelManager.availableModels.allSatisfy { !$0.isInstalled })
                    }
                }
                
                // Update Section
                Section("Updates") {
                    Button(action: checkForUpdates) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            
                            Text("Check for Updates")
                                .foregroundColor(.blue)
                            
                            if isCheckingUpdates {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isCheckingUpdates)
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
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    modelManager.deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete \(model.name)? You can download it again later.")
            }
        }
    }
    
    private func checkForUpdates() {
        isCheckingUpdates = true
        
        Task {
            await modelManager.checkForModelUpdates()
            
            await MainActor.run {
                isCheckingUpdates = false
            }
        }
    }
}

// MARK: - Model Row View

struct ModelRowView: View {
    let model: ModelInfo
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var modelManager = LocalModelManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: model.statusIcon)
                    .foregroundColor(statusColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading) {
                    Text(model.name)
                        .font(.headline)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(model.displayVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(model.size)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Download/Update Progress
            if let progress = modelManager.downloadProgress[model.id] {
                HStack {
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            // Action Buttons
            HStack {
                if model.hasUpdate {
                    Button("Update") {
                        onDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if !model.isInstalled {
                    Button("Download") {
                        onDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if model.isInstalled {
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch model.statusColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

struct ModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSettingsView()
    }
}