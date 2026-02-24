import SwiftUI

// MARK: - Model Status View
// Shows the status of the bundled AI model

struct ModelDownloadView: View {
    @StateObject private var llm = RealLLMCaddieChat.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.green.opacity(0.2), .mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)

                    Image(systemName: llm.isModelDownloaded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(llm.isModelDownloaded ? .green : .orange)
                }

                // Title and description
                VStack(spacing: 12) {
                    Text(llm.isModelDownloaded ? "AI Model Ready!" : "Model Not Found")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIColor.label))

                    Text(llm.isModelDownloaded
                         ? "Your AI golf caddie is ready to help!"
                         : "The AI model is not bundled with this build. Please ensure Phi-3.5-mini-instruct-Q4_K_M.gguf is included in the app bundle.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Model info card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        Text("Model Details")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                    }

                    Divider()

                    InfoRow(icon: "internaldrive", label: "Size", value: "~2.2 GB")
                    InfoRow(icon: "bolt.fill", label: "Type", value: "Phi-3.5 Mini Q4")
                    InfoRow(icon: "lock.shield", label: "Privacy", value: "100% On-Device")
                    InfoRow(icon: "wifi.slash", label: "Internet", value: "Not Required")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)

                Spacer()

                // Button
                Button(action: {
                    dismiss()
                }) {
                    Text(llm.isModelDownloaded ? "Start Chatting" : "Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 280, height: 54)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Spacer()
            }
            .padding()
        }
        .task {
            // Ensure model is loaded when view appears
            await llm.ensureModelLoaded()
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIColor.label))
        }
    }
}

// MARK: - Preview

#Preview {
    ModelDownloadView()
}
