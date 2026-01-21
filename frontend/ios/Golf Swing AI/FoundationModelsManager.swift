import Foundation
import FoundationModels

@MainActor
class FoundationModelsManager: ObservableObject {
    static let shared = FoundationModelsManager()
    
    @Published var isLoading = false
    @Published var modelLoadError: String?
    
    private var model = SystemLanguageModel.default
    private var currentSession: LanguageModelSession?
    
    private init() {
        print("🤖 Foundation Models Manager initialized")
    }
    
    var isModelDownloaded: Bool {
        return model.availability == .available
    }
    
    var downloadProgress: Double {
        return isModelDownloaded ? 1.0 : 0.0
    }
    
    // Golf-specific system instructions
    private let systemPrompt = """
    You are CaddieChat Pro, an expert golf caddie and instructor with deep knowledge of:
    - Golf swing mechanics and technique
    - Course management and strategy
    - Equipment selection and fitting
    - Golf rules (USGA/R&A)
    - Practice drills and training methods
    - Mental game and course psychology
    - Troubleshooting common issues (slice, hook, topped shots, etc.)

    Your communication style:
    - Friendly, encouraging, and professional
    - Provide specific, actionable advice
    - Use golf terminology appropriately
    - Ask clarifying questions when needed
    - Adapt explanations to the golfer's skill level
    - Keep responses concise but comprehensive (2-4 sentences preferred)
    - Use bullet points for multi-step advice

    Always prioritize safety, etiquette, and proper fundamentals.
    """
    
    func ensureModelLoaded() async {
        switch model.availability {
        case .available:
            if currentSession == nil {
                currentSession = LanguageModelSession(instructions: systemPrompt)
            }
            print("✅ Foundation Models ready")
        case .unavailable(.deviceNotEligible):
            modelLoadError = "This device doesn't support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            modelLoadError = "Please enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady):
            modelLoadError = "Model is downloading or not ready"
        case .unavailable(let other):
            modelLoadError = "Model unavailable: \(other)"
        }
    }
    
    func downloadModel() async throws {
        // With Foundation Models, there's no explicit download
        // The system handles model availability
        await ensureModelLoaded()
        if !isModelDownloaded {
            throw LLMError.modelNotDownloaded
        }
    }
    
    func loadModel() async throws {
        await ensureModelLoaded()
        if !isModelDownloaded {
            throw LLMError.modelNotDownloaded
        }
    }
    
    func sendMessage(_ userMessage: String) async throws -> ChatResponse {
        guard let session = currentSession, model.availability == .available else {
            await ensureModelLoaded()
            throw LLMError.modelNotLoaded
        }
        
        print("🤖 Sending message to Foundation Models: \(userMessage)")
        isLoading = true
        
        do {
            let response = try await session.respond(to: userMessage)
            
            isLoading = false
            
            return ChatResponse(
                message: response.content,
                isFromUser: false,
                timestamp: Date()
            )
        } catch {
            isLoading = false
            print("❌ Foundation Models error: \(error)")
            throw LLMError.inferenceFailed
        }
    }
}

// Compatibility types
enum LLMError: Error {
    case modelNotDownloaded
    case modelNotLoaded
    case inferenceFailed
}

struct ChatResponse {
    let message: String
    let isFromUser: Bool
    let timestamp: Date
}