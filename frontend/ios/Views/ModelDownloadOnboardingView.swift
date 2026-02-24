import SwiftUI

struct ModelDownloadOnboardingView: View {
    @ObservedObject var llmManager: RealLLMCaddieChat
    let onComplete: () -> Void

    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            // Title and description
            VStack(spacing: 12) {
                Text("CaddieChat Pro AI")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Download the on-device AI model to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "lock.shield.fill", text: "100% Private - runs on your device")
                FeatureRow(icon: "wifi.slash", text: "Works offline - no internet needed")
                FeatureRow(icon: "brain", text: "Expert golf knowledge built-in")
            }
            .padding(.horizontal, 40)

            Spacer()

            // Download info
            VStack(spacing: 8) {
                if isDownloading {
                    VStack(spacing: 12) {
                        ProgressView(value: llmManager.downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(.green)

                        if llmManager.downloadProgress > 0 && llmManager.downloadProgress < 1.0 {
                            VStack(spacing: 4) {
                                Text("\(Int(llmManager.downloadProgress * 100))% complete")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                let downloadedGB = llmManager.downloadProgress * 1.0
                                Text(String(format: "%.1f GB / 1.0 GB", downloadedGB))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Starting download...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    Text("Download size: ~1.0 GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = downloadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }
            }
            .frame(height: 60)

            // Download button
            Button(action: startDownload) {
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Downloading...")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download AI Model")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isDownloading ? [.gray, .gray.opacity(0.8)] : [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .disabled(isDownloading)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func startDownload() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                print("🚀 Starting model download...")
                try await llmManager.downloadModel()

                await MainActor.run {
                    isDownloading = false
                    onComplete()

                    SimpleAnalytics.shared.trackEvent("model_downloaded", properties: [
                        "model_name": "qwen2.5-1.5b",
                        "source": "onboarding"
                    ])
                }
            } catch {
                print("❌ Download/Load failed: \(error)")

                await MainActor.run {
                    isDownloading = false

                    // Provide user-friendly error messages
                    if let llmError = error as? LLMError {
                        switch llmError {
                        case .modelLoadFailed(let underlyingError):
                            downloadError = "Model file is incompatible with this device. Error: \(underlyingError.localizedDescription)"
                        case .downloadFailed:
                            downloadError = "Download failed. Please check your internet connection and try again."
                        case .invalidURL:
                            downloadError = "Invalid download URL. Please contact support."
                        default:
                            downloadError = error.localizedDescription
                        }
                    } else {
                        downloadError = "Download failed: \(error.localizedDescription)"
                    }

                    SimpleAnalytics.shared.trackEvent("model_download_failed", properties: [
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    ModelDownloadOnboardingView(llmManager: RealLLMCaddieChat.shared, onComplete: {})
}
