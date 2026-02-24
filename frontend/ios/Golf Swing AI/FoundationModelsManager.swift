import Foundation

// Foundation Models is only available in iOS 26.0+ (future release)
// This is a stub implementation that will be updated when the framework is available

@MainActor
class FoundationModelsManager: ObservableObject {
    static let shared = FoundationModelsManager()

    @Published var isLoading = false
    @Published var modelLoadError: String? = "Foundation Models requires iOS 26.0 or later"

    private init() {
        print("🤖 Foundation Models Manager initialized (stub - iOS 26.0 required)")
    }

    var isModelDownloaded: Bool {
        return false
    }

    var downloadProgress: Double {
        return 0.0
    }

    func ensureModelLoaded() async {
        modelLoadError = "Foundation Models requires iOS 26.0 or later"
    }

    func downloadModel() async throws {
        throw FoundationModelsError.modelNotDownloaded
    }

    func loadModel() async throws {
        throw FoundationModelsError.modelNotDownloaded
    }

    func sendMessage(_ userMessage: String) async throws -> FoundationModelsChatResponse {
        throw FoundationModelsError.modelNotLoaded
    }
}

// Separate types to avoid conflicts with RealLLMCaddieChat
enum FoundationModelsError: Error {
    case modelNotDownloaded
    case modelNotLoaded
    case inferenceFailed
}

struct FoundationModelsChatResponse {
    let message: String
    let isFromUser: Bool
    let timestamp: Date
}
