import Foundation
#if canImport(CoreML)
@preconcurrency import CoreML
#endif
import NaturalLanguage
import Combine

@MainActor
final class GolfChatMLModel: ObservableObject {
    @Published var isLoading = false
    @Published var lastResponse: ChatResponse?
    
    #if canImport(CoreML)
    @available(iOS 11.0, *)
    private var mlModel: MLModel?
    #endif
    private let intentAnalyzer = GolfIntentAnalyzer()
    private let conversationContext = ConversationContext()
    private var cancellables = Set<AnyCancellable>()
    
    // Fallback to rule-based responses if ML model fails
    private var fallbackChat: LocalCaddieChat?
    
    init() {
        self.fallbackChat = LocalCaddieChat()
        loadMLModel()
    }
    
    // MARK: - Core ML Model Loading
    
    private func loadMLModel() {
        #if canImport(CoreML)
        if #available(iOS 11.0, *) {
            Task {
                do {
                    // Try to load the Core ML model (golf_chat_model.mlmodel)
                    guard let modelURL = Bundle.main.url(forResource: "golf_chat_model", withExtension: "mlmodel") else {
                        print("⚠️ Core ML model not found, using fallback responses")
                        return
                    }
                    
                    self.mlModel = try MLModel(contentsOf: modelURL)
                    print("✅ Core ML Golf Chat model loaded successfully")
                    
                } catch {
                    print("❌ Failed to load Core ML model: \(error)")
                    print("🔄 Falling back to rule-based responses")
                }
            }
        } else {
            print("⚠️ Core ML not available on this iOS version, using fallback responses")
        }
        #else
        print("⚠️ Core ML framework not available, using fallback responses")
        #endif
    }
    
    // MARK: - Main Chat Interface
    
    func sendMessage(_ message: String) async -> ChatResponse {
        isLoading = true
        defer { isLoading = false }
        
        // Analyze user intent
        let intent = await intentAnalyzer.analyzeIntent(message)
        
        // Get response from ML model or fallback
        let response = await generateResponse(message: message, intent: intent)
        
        // Update conversation context
        conversationContext.addExchange(userMessage: message, botResponse: response.message)
        
        // Store last response
        lastResponse = response
        
        return response
    }
    
    // MARK: - Response Generation
    
    private func generateResponse(message: String, intent: GolfIntent) async -> ChatResponse {
        // Try Core ML model first
        if let mlResponse = await generateMLResponse(message: message, intent: intent) {
            return mlResponse
        }
        
        // Fallback to rule-based responses
        return await getFallbackResponse(message)
    }
    
    private func generateMLResponse(message: String, intent: GolfIntent) async -> ChatResponse? {
        #if canImport(CoreML)
        if #available(iOS 11.0, *) {
            guard let model = mlModel else { return nil }
            
            do {
                // Prepare input for Core ML model
                let input = prepareMLInput(message: message, intent: intent)
                
                // Run inference (Core ML models are thread-safe)
                let output = try await model.prediction(from: input)
                
                // Extract response from model output
                if let response = extractResponseFromOutput(output) {
                    return ChatResponse(
                        id: UUID().uuidString,
                        message: response,
                        isUser: false,
                        timestamp: Date(),
                        intent: intent.rawValue,
                        confidence: 0.9
                    )
                }
                
            } catch {
                print("❌ Core ML inference error: \(error)")
            }
        }
        #endif
        
        return nil
    }
    
    private func getFallbackResponse(_ message: String) async -> ChatResponse {
        guard let fallbackChat = fallbackChat else {
            return ChatResponse(
                id: UUID().uuidString,
                message: "I'm here to help with your golf questions! Could you try rephrasing that?",
                isUser: false,
                timestamp: Date(),
                intent: "error",
                confidence: 0.5
            )
        }
        
        do {
            return try await fallbackChat.sendChatMessage(message)
        } catch {
            return ChatResponse(
                id: UUID().uuidString,
                message: "I'm here to help with your golf questions! Could you try rephrasing that?",
                isUser: false,
                timestamp: Date(),
                intent: "error",
                confidence: 0.5
            )
        }
    }
    
    // MARK: - Core ML Input/Output Processing
    
    #if canImport(CoreML)
    @available(iOS 11.0, *)
    private func prepareMLInput(message: String, intent: GolfIntent) -> MLDictionaryFeatureProvider {
        // Prepare features for the Core ML model
        let features: [String: Any] = [
            "input_text": message,
            "intent": intent.rawValue,
            "context": conversationContext.getRecentContext(),
            "message_length": message.count,
            "golf_terms_count": countGolfTerms(in: message)
        ]
        
        return try! MLDictionaryFeatureProvider(dictionary: features)
    }
    
    @available(iOS 11.0, *)
    private func extractResponseFromOutput(_ output: MLFeatureProvider) -> String? {
        // Extract the generated text from Core ML model output
        if let responseValue = output.featureValue(for: "generated_text") {
            return responseValue.stringValue
        }
        return nil
    }
    #endif
    
    private func countGolfTerms(in message: String) -> Int {
        let golfTerms = [
            "golf", "swing", "club", "ball", "course", "hole", "tee", "green", "fairway",
            "driver", "iron", "putter", "wedge", "handicap", "par", "birdie", "eagle",
            "bogey", "slice", "hook", "draw", "fade", "chip", "pitch", "bunker"
        ]
        
        let messageWords = message.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return messageWords.filter { word in golfTerms.contains(word) }.count
    }
}

// MARK: - Golf Intent Analyzer

class GolfIntentAnalyzer: @unchecked Sendable {
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    func analyzeIntent(_ message: String) async -> GolfIntent {
        let lowercaseMessage = message.lowercased()
        
        // Advanced intent analysis using Natural Language framework
        tagger.string = message
        
        // Check for specific golf intents
        if containsSwingTerms(lowercaseMessage) {
            return .swingAdvice
        } else if containsEquipmentTerms(lowercaseMessage) {
            return .equipment
        } else if containsStrategyTerms(lowercaseMessage) {
            return .courseStrategy
        } else if containsRuleTerms(lowercaseMessage) {
            return .rules
        } else if containsTrainingTerms(lowercaseMessage) {
            return .training
        } else if containsRecommendationTerms(lowercaseMessage) {
            return .recommendation
        } else if containsProblemTerms(lowercaseMessage) {
            return .problemSolving
        }
        
        return .general
    }
    
    private func containsSwingTerms(_ message: String) -> Bool {
        let swingTerms = ["swing", "technique", "form", "posture", "grip", "stance", "tempo", "rhythm"]
        return swingTerms.contains { message.contains($0) }
    }
    
    private func containsEquipmentTerms(_ message: String) -> Bool {
        let equipmentTerms = ["club", "driver", "iron", "putter", "wedge", "equipment", "gear"]
        return equipmentTerms.contains { message.contains($0) }
    }
    
    private func containsStrategyTerms(_ message: String) -> Bool {
        let strategyTerms = ["strategy", "course", "hole", "shot", "approach", "green", "fairway"]
        return strategyTerms.contains { message.contains($0) }
    }
    
    private func containsRuleTerms(_ message: String) -> Bool {
        let ruleTerms = ["rule", "penalty", "legal", "allowed", "usga", "regulation"]
        return ruleTerms.contains { message.contains($0) }
    }
    
    private func containsTrainingTerms(_ message: String) -> Bool {
        let trainingTerms = ["practice", "training", "improve", "better", "drill", "exercise", "lesson"]
        return trainingTerms.contains { message.contains($0) }
    }
    
    private func containsRecommendationTerms(_ message: String) -> Bool {
        let recTerms = ["recommend", "suggest", "should", "best", "advice", "tips"]
        return recTerms.contains { message.contains($0) }
    }
    
    private func containsProblemTerms(_ message: String) -> Bool {
        let problemTerms = ["problem", "issue", "wrong", "fix", "help", "trouble", "slice", "hook"]
        return problemTerms.contains { message.contains($0) }
    }
}

// MARK: - Conversation Context

class ConversationContext: @unchecked Sendable {
    private var exchanges: [(user: String, bot: String)] = []
    private let maxExchanges = 5
    
    func addExchange(userMessage: String, botResponse: String) {
        exchanges.append((user: userMessage, bot: botResponse))
        
        // Keep only recent exchanges
        if exchanges.count > maxExchanges {
            exchanges.removeFirst()
        }
    }
    
    func getRecentContext() -> String {
        return exchanges.suffix(3).map { exchange in
            "User: \(exchange.user)\nBot: \(exchange.bot)"
        }.joined(separator: "\n\n")
    }
    
    func clearContext() {
        exchanges.removeAll()
    }
}

// MARK: - Golf Intent Enum

enum GolfIntent: String, CaseIterable {
    case swingAdvice = "swing_advice"
    case equipment = "equipment"
    case courseStrategy = "course_strategy"
    case rules = "rules"
    case training = "training"
    case recommendation = "recommendation"
    case problemSolving = "problem_solving"
    case general = "general"
    case followUp = "follow_up"
    case clarification = "clarification"
}

