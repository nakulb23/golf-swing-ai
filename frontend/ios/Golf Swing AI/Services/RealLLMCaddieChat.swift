import Foundation
import Combine
import LLM

// MARK: - Real On-Device LLM for CaddieChat
// Uses LLM.swift for on-device AI golf conversations

@MainActor
class RealLLMCaddieChat: ObservableObject {
    static let shared = RealLLMCaddieChat()

    @Published var isLoading = false
    @Published var isModelReady = false
    @Published var modelLoadError: String?

    private var bot: LLM?
    private var conversationHistory: [String] = []
    private let maxHistoryLength = 10

    // Model configuration - Bundled with the app
    // Qwen2.5-1.5B is faster than Phi-3.5 (1GB vs 2.2GB) with similar quality
    private let modelName = "qwen2.5-1.5b-instruct-q4_k_m"

    /// Path to the bundled model in the app bundle
    private var modelPath: URL? {
        // First try to find in app bundle
        if let bundlePath = Bundle.main.url(forResource: modelName, withExtension: "gguf") {
            return bundlePath
        }
        // Fallback to Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("\(modelName).gguf")
    }

    /// For backwards compatibility
    var isModelDownloaded: Bool {
        guard let path = modelPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Download progress (always 1.0 since model is bundled)
    var downloadProgress: Double {
        return isModelDownloaded ? 1.0 : 0.0
    }

    // Golf-specific system prompt
    private let systemPrompt = """
    You are CaddieChat Pro, a friendly golf caddie assistant.

    STRICT RULES:
    1. ONLY discuss golf topics (swing, clubs, rules, strategy, courses, practice)
    2. NEVER write code, programming examples, or technical content
    3. NEVER use bullet points with code syntax
    4. Keep answers SHORT: 2-3 sentences maximum
    5. Be conversational and friendly, like talking to a real caddie

    If asked about non-golf topics, say: "I'm your golf caddie! Ask me about your swing, club selection, or course strategy."

    Always give practical, actionable golf advice.
    """

    private init() {
        print("🤖 Real LLM CaddieChat initialized")

        if let path = modelPath {
            print("✅ Model path: \(path.path)")
            if FileManager.default.fileExists(atPath: path.path) {
                print("✅ Model file exists")
            } else {
                print("⚠️ Model file not found at path")
                modelLoadError = "Model file not found. Please ensure qwen2.5-1.5b-instruct-q4_k_m.gguf is included."
            }
        } else {
            print("⚠️ Could not determine model path")
            modelLoadError = "Could not determine model path"
        }
    }

    /// Call this when chat view appears to ensure model is loaded
    func ensureModelLoaded() async {
        guard bot == nil else {
            isModelReady = true
            return
        }

        do {
            try await loadModel()
        } catch {
            print("⚠️ Failed to load model: \(error.localizedDescription)")
            modelLoadError = error.localizedDescription
        }
    }

    // MARK: - Model Management

    func downloadModel() async throws {
        print("ℹ️ Model is bundled with the app - no download required")
        try await loadModel()
    }

    func loadModel() async throws {
        guard let path = modelPath else {
            let error = "Model path not available"
            print("❌ \(error)")
            modelLoadError = error
            throw LLMError.modelNotDownloaded
        }

        guard FileManager.default.fileExists(atPath: path.path) else {
            let error = "Model file not found at: \(path.path)"
            print("❌ \(error)")
            modelLoadError = error
            throw LLMError.modelNotDownloaded
        }

        // Log file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
           let fileSize = attrs[.size] as? Int64 {
            print("📦 Model size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        }

        print("🔄 Loading LLM model with LLM.swift...")
        isLoading = true

        // Initialize LLM.swift with the model
        // Using .chatML template with system prompt for Phi-3.5
        bot = LLM(from: path, template: .chatML(systemPrompt))

        if bot != nil {
            isModelReady = true
            modelLoadError = nil
            print("✅ Model loaded successfully with LLM.swift")
        } else {
            let error = "LLM initialization returned nil"
            print("❌ \(error)")
            modelLoadError = error
            isLoading = false
            throw LLMError.modelLoadFailed(NSError(domain: "LLM", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        isLoading = false
    }

    // MARK: - Chat Interface

    func sendMessage(_ userMessage: String) async throws -> ChatResponse {
        guard let bot = bot else {
            print("⚠️ Model not loaded, attempting to load...")
            try await loadModel()
            return try await sendMessage(userMessage)
        }

        print("🤖 Generating response for: \(userMessage)")
        print("⏱️ Starting inference...")
        isLoading = true

        // Generate response using LLM.swift getCompletion
        let startTime = Date()
        let response = await bot.getCompletion(from: userMessage)
        let elapsed = Date().timeIntervalSince(startTime)

        print("⏱️ Inference took \(String(format: "%.1f", elapsed)) seconds")

        // Clean up response
        let cleanedResponse = cleanLLMResponse(response)

        print("✅ Generated response: \(cleanedResponse.prefix(100))...")

        isLoading = false

        return ChatResponse(
            id: UUID().uuidString,
            message: cleanedResponse.isEmpty ? "I'd be happy to help with your golf game! What would you like to know about?" : cleanedResponse,
            isUser: false,
            timestamp: Date(),
            intent: "llm_response",
            confidence: 0.95,
            is_golf_related: true
        )
    }

    /// Clean LLM response to remove code, repetition, and unwanted content
    private func cleanLLMResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove code blocks completely
        let codeBlockPattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }

        // Remove inline code
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")

        // Remove lines that look like code (contain programming keywords)
        let codeKeywords = ["#include", "import ", "def ", "func ", "class ", "return ", "int ", "void ", "std::", "cout", "cin", "printf", "assert(", "if (", "for (", "while ("]
        for keyword in codeKeywords {
            if cleaned.contains(keyword) {
                // Remove lines containing code
                let lines = cleaned.components(separatedBy: "\n")
                cleaned = lines.filter { !$0.contains(keyword) }.joined(separator: "\n")
            }
        }

        // Stop at continuation patterns
        let stopPatterns = ["\nQ:", "\nQuestion:", "\nUser:", "Human:", "\n---", "\n\n\n", "What is a", "Here's a"]
        for pattern in stopPatterns {
            if let range = cleaned.range(of: pattern) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }

        // Limit response length (roughly 3-4 sentences)
        let sentences = cleaned.components(separatedBy: ". ")
        if sentences.count > 4 {
            cleaned = sentences.prefix(4).joined(separator: ". ")
            if !cleaned.hasSuffix(".") {
                cleaned += "."
            }
        }

        // Final cleanup
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove bullet points that might look weird
        cleaned = cleaned.replacingOccurrences(of: "• ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "- ", with: "")

        return cleaned
    }

    func clearConversation() {
        conversationHistory.removeAll()
        // Reinitialize bot to clear history
        if let path = modelPath {
            bot = LLM(from: path, template: .chatML(systemPrompt))
        }
        print("🗑️ Conversation history cleared")
    }

    func resetModel() {
        bot = nil
        conversationHistory.removeAll()
        isModelReady = false
        print("🔄 Model reset")
    }
}

// MARK: - Supporting Types

enum LLMError: LocalizedError {
    case modelNotDownloaded
    case modelNotLoaded
    case modelLoadFailed(Error)
    case generationFailed(Error)
    case invalidURL
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Model not found. The Phi-3.5 model should be bundled with the app."
        case .modelNotLoaded:
            return "Model not loaded. Please try again."
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "Failed to generate response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid model download URL"
        case .downloadFailed:
            return "Failed to download model"
        }
    }
}
