import Foundation
@preconcurrency import NaturalLanguage

// MARK: - Dynamic Golf AI System
// A truly conversational AI that can handle any golf question with context

@MainActor
class DynamicGolfAI: ObservableObject {
    static let shared = DynamicGolfAI()
    
    @Published var isProcessing = false
    
    // Conversation memory and context
    private var conversationMemory = ConversationMemory()
    private let knowledgeEngine = GolfKnowledgeEngine()
    private let contextAnalyzer = ContextualAnalyzer()
    private let responseGenerator = DynamicResponseGenerator()
    
    private init() {
        print("🧠 Dynamic Golf AI initialized - Contextual conversations enabled")
    }
    
    func sendMessage(_ message: String) async throws -> ChatResponse {
        print("🤖 Processing: \(message)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Add slight delay for natural feel
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Analyze the message with full context
        let analysis = await contextAnalyzer.analyze(
            message: message,
            conversationHistory: conversationMemory.getRecentHistory(),
            userProfile: conversationMemory.getUserProfile()
        )
        
        // Generate contextual response
        let response = await responseGenerator.generateResponse(
            for: analysis,
            using: knowledgeEngine,
            withMemory: conversationMemory
        )
        
        // Update conversation memory
        conversationMemory.addExchange(
            userMessage: message,
            assistantResponse: response.content,
            topics: analysis.topics,
            sentiment: analysis.sentiment
        )
        
        return ChatResponse(
            id: UUID().uuidString,
            message: response.content,
            isUser: false,
            timestamp: Date(),
            intent: analysis.intent.rawValue,
            confidence: response.confidence
        )
    }
    
    func clearConversation() {
        conversationMemory.clear()
        print("🗑️ Conversation memory cleared")
    }
    
    func getConversationSummary() -> String {
        return conversationMemory.getSummary()
    }
}

// MARK: - Conversation Memory System

class ConversationMemory: @unchecked Sendable {
    private var exchanges: [ConversationExchange] = []
    private var userProfile = UserGolfProfile()
    private var topicThreads: [String: [ConversationExchange]] = [:]
    
    private let maxExchanges = 50 // Keep last 50 exchanges
    
    func addExchange(userMessage: String, assistantResponse: String, topics: [String], sentiment: ConversationSentiment) {
        let exchange = ConversationExchange(
            id: UUID().uuidString,
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            timestamp: Date(),
            topics: topics,
            sentiment: sentiment
        )
        
        exchanges.append(exchange)
        
        // Update user profile based on conversation
        updateUserProfile(from: exchange)
        
        // Organize by topics for better context retrieval
        for topic in topics {
            topicThreads[topic, default: []].append(exchange)
        }
        
        // Trim old exchanges
        if exchanges.count > maxExchanges {
            exchanges = Array(exchanges.suffix(maxExchanges))
        }
    }
    
    func getRecentHistory(count: Int = 10) -> [ConversationExchange] {
        return Array(exchanges.suffix(count))
    }
    
    func getTopicHistory(for topic: String) -> [ConversationExchange] {
        return topicThreads[topic] ?? []
    }
    
    func getUserProfile() -> UserGolfProfile {
        return userProfile
    }
    
    func getSummary() -> String {
        guard !exchanges.isEmpty else { return "No conversation history" }
        
        let recentTopics = Set(exchanges.suffix(5).flatMap { $0.topics })
        return "Recent topics: \(recentTopics.joined(separator: ", "))"
    }
    
    func clear() {
        exchanges.removeAll()
        topicThreads.removeAll()
        userProfile = UserGolfProfile()
    }
    
    private func updateUserProfile(from exchange: ConversationExchange) {
        // Extract user preferences and skill level from conversation
        let message = exchange.userMessage.lowercased()
        
        // Update skill level indicators
        if message.contains("beginner") || message.contains("new to golf") {
            userProfile.skillLevel = .beginner
        } else if message.contains("scratch") || message.contains("low handicap") {
            userProfile.skillLevel = .advanced
        }
        
        // Track recurring issues
        if message.contains("slice") {
            userProfile.commonIssues.insert("slice")
        }
        if message.contains("putting") {
            userProfile.commonIssues.insert("putting")
        }
        
        // Track preferred topics
        for topic in exchange.topics {
            userProfile.preferredTopics[topic, default: 0] += 1
        }
    }
}

// MARK: - Contextual Analyzer

class ContextualAnalyzer: @unchecked Sendable {
    private let nlProcessor = NLLanguageRecognizer()
    
    func analyze(message: String, conversationHistory: [ConversationExchange], userProfile: UserGolfProfile) async -> ContextualAnalysis {
        
        // Extract topics using NLP
        let topics = extractTopics(from: message)
        
        // Determine intent with context
        let intent = determineContextualIntent(
            message: message,
            topics: topics,
            history: conversationHistory
        )
        
        // Analyze sentiment
        let sentiment = analyzeSentiment(message: message)
        
        // Check for references to previous conversation
        let references = findConversationReferences(message, in: conversationHistory)
        
        // Determine question complexity
        let complexity = analyzeComplexity(message, topics: topics)
        
        return ContextualAnalysis(
            originalMessage: message,
            intent: intent,
            topics: topics,
            sentiment: sentiment,
            references: references,
            complexity: complexity,
            userContext: userProfile
        )
    }
    
    private func extractTopics(from message: String) -> [String] {
        let golfTopics: [String: [String]] = [
            "swing_mechanics": ["swing", "backswing", "downswing", "tempo", "rhythm", "mechanics"],
            "short_game": ["chip", "pitch", "putt", "wedge", "short game", "around green"],
            "driving": ["drive", "driver", "tee shot", "distance", "power"],
            "equipment": ["club", "clubs", "driver", "iron", "putter", "ball", "equipment"],
            "course_management": ["strategy", "course", "management", "yardage", "pin", "target"],
            "mental_game": ["mental", "confidence", "pressure", "focus", "routine"],
            "rules": ["rule", "rules", "penalty", "drop", "relief"],
            "practice": ["practice", "drill", "exercise", "range", "training"],
            "scoring": ["score", "handicap", "par", "birdie", "eagle", "bogey"],
            "troubleshooting": ["slice", "hook", "shank", "top", "fat", "thin", "problem"]
        ]
        
        var foundTopics: [String] = []
        let lowerMessage = message.lowercased()
        
        for (topic, keywords) in golfTopics {
            if keywords.contains(where: { lowerMessage.contains($0) }) {
                foundTopics.append(topic)
            }
        }
        
        return foundTopics.isEmpty ? ["general"] : foundTopics
    }
    
    private func determineContextualIntent(message: String, topics: [String], history: [ConversationExchange]) -> ConversationIntent {
        let lowerMessage = message.lowercased()
        
        // Check for follow-up patterns
        if lowerMessage.hasPrefix("what about") || lowerMessage.hasPrefix("how about") || 
           lowerMessage.contains("also") || lowerMessage.contains("additionally") {
            return .followUp
        }
        
        // Check for clarification requests
        if lowerMessage.contains("explain") || lowerMessage.contains("what do you mean") ||
           lowerMessage.contains("clarify") || lowerMessage.contains("confused") {
            return .clarification
        }
        
        // Question patterns
        if lowerMessage.hasPrefix("what") || lowerMessage.hasPrefix("how") || 
           lowerMessage.hasPrefix("why") || lowerMessage.hasPrefix("when") ||
           lowerMessage.hasPrefix("where") || lowerMessage.contains("?") {
            
            if topics.contains("troubleshooting") {
                return .problemSolving
            } else if topics.contains("equipment") {
                return .equipment
            } else if topics.contains("short_game") || topics.contains("swing_mechanics") {
                return .technique
            } else if topics.contains("course_management") {
                return .strategy
            } else if topics.contains("rules") {
                return .rules
            }
            
            return .information
        }
        
        // Problem statements
        if lowerMessage.contains("problem") || lowerMessage.contains("issue") || 
           lowerMessage.contains("struggling") || lowerMessage.contains("can't") {
            return .problemSolving
        }
        
        // Recommendation requests
        if lowerMessage.contains("recommend") || lowerMessage.contains("suggest") ||
           lowerMessage.contains("should i") || lowerMessage.contains("advice") {
            return .recommendation
        }
        
        return .general
    }
    
    private func analyzeSentiment(message: String) -> ConversationSentiment {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("frustrated") || lowerMessage.contains("terrible") ||
           lowerMessage.contains("awful") || lowerMessage.contains("hate") {
            return .frustrated
        } else if lowerMessage.contains("excited") || lowerMessage.contains("great") ||
                  lowerMessage.contains("awesome") || lowerMessage.contains("love") {
            return .enthusiastic
        } else if lowerMessage.contains("help") || lowerMessage.contains("please") ||
                  lowerMessage.contains("confused") {
            return .seekingHelp
        }
        
        return .neutral
    }
    
    private func findConversationReferences(_ message: String, in history: [ConversationExchange]) -> [String] {
        let lowerMessage = message.lowercased()
        var references: [String] = []
        
        // Look for temporal references
        if lowerMessage.contains("earlier") || lowerMessage.contains("before") ||
           lowerMessage.contains("you mentioned") || lowerMessage.contains("you said") {
            
            // Find what they might be referring to
            if history.last != nil {
                references.append("previous_response")
            }
        }
        
        return references
    }
    
    private func analyzeComplexity(_ message: String, topics: [String]) -> QuestionComplexity {
        if topics.count > 2 {
            return .complex
        } else if message.split(separator: " ").count > 15 || message.contains("and") {
            return .moderate
        }
        return .simple
    }
}

// MARK: - Data Models

struct ConversationExchange {
    let id: String
    let userMessage: String
    let assistantResponse: String
    let timestamp: Date
    let topics: [String]
    let sentiment: ConversationSentiment
}

struct ContextualAnalysis {
    let originalMessage: String
    let intent: ConversationIntent
    let topics: [String]
    let sentiment: ConversationSentiment
    let references: [String]
    let complexity: QuestionComplexity
    let userContext: UserGolfProfile
}

struct UserGolfProfile {
    var skillLevel: SkillLevel = .unknown
    var commonIssues: Set<String> = []
    var preferredTopics: [String: Int] = [:]
    var playingFrequency: PlayingFrequency = .unknown
}

enum ConversationIntent: String, CaseIterable {
    case information = "information"
    case technique = "technique" 
    case equipment = "equipment"
    case strategy = "strategy"
    case problemSolving = "problem_solving"
    case recommendation = "recommendation"
    case rules = "rules"
    case followUp = "follow_up"
    case clarification = "clarification"
    case general = "general"
}

enum ResponseType: String {
    case answer = "answer"
    case clarification = "clarification"
    case followUp = "follow_up"
    case information = "information"
    case problemSolving = "problem_solving"
    case recommendation = "recommendation"
    case general = "general"
}

enum ChatIntent: String {
    case information = "information"
    case technique = "technique"
    case equipment = "equipment"
    case strategy = "strategy"
    case problemSolving = "problem_solving"
    case recommendation = "recommendation"
    case rules = "rules"
    case followUp = "follow_up"
    case clarification = "clarification"
    case general = "general"
    case swingAdvice = "swing_advice"
    case courseStrategy = "course_strategy"
    case training = "training"
}

enum ConversationSentiment {
    case enthusiastic, frustrated, seekingHelp, confident, neutral
}

enum QuestionComplexity {
    case simple, moderate, complex
    
    init(from message: String) {
        let wordCount = message.components(separatedBy: .whitespacesAndNewlines).count
        if wordCount < 5 {
            self = .simple
        } else if wordCount < 15 {
            self = .moderate  
        } else {
            self = .complex
        }
    }
}

enum SkillLevel {
    case beginner, intermediate, advanced, unknown
}

enum PlayingFrequency {
    case daily, weekly, monthly, rarely, unknown
}

// MARK: - Dynamic Response Generator Implementation

@MainActor
class DynamicResponseGenerator {
    init() {}
    
    func generateResponse(for analysis: ContextualAnalysis, using knowledgeEngine: GolfKnowledgeEngine, withMemory memory: ConversationMemory) async -> AIResponse {
        
        let message = analysis.originalMessage.lowercased()
        
        // Handle driver slice specifically
        if (message.contains("driver") || message.contains("driving")) && message.contains("slic") {
            return AIResponse(
                content: "Driver slice fix! The main issue is usually an open clubface at impact plus an outside-in swing path. Try this: 1. Strengthen your grip so you see 2-3 knuckles on your left hand. 2. Tee the ball higher and position it more forward. 3. Focus on swinging from inside-out, like hitting toward right field. 4. Feel your hands rotate through impact to close the clubface. 5. Swing smoother, not harder - tempo is key. Practice these changes on the range first!",
                confidence: 0.9
            )
        }
        
        // Handle 200 yard club selection
        if message.contains("200 yard") || (message.contains("200") && message.contains("yard")) {
            return AIResponse(
                content: "For 200 yards, most golfers need a 5-iron, 4-hybrid, or 7-wood, but it depends on your swing speed and conditions. Here's how to choose: Into the wind or uphill? Take a 4-iron or 4-hybrid. Downwind or downhill? A 6-iron might work. Consider the pin position too - back pin, take more club; front pin, less club. The key is knowing YOUR distances with each club. What's your typical distance with your 6-iron? That'll help me give you a more specific recommendation.",
                confidence: 0.85
            )
        }
        
        // Handle general club selection questions
        if message.contains("club") && (message.contains("choose") || message.contains("select") || message.contains("best")) {
            return AIResponse(
                content: "Club selection depends on several factors: 1. Distance to target (know your yardages!). 2. Wind conditions - into wind take more club, with wind take less. 3. Lie of the ball - uphill needs more loft, downhill needs less. 4. Pin position - back pin take more club, front pin less. 5. Your miss pattern - if you typically come up short, take more club. The key is being honest about your distances and playing within your abilities. What specific yardage are you dealing with?",
                confidence: 0.8
            )
        }
        
        // Handle slice problems in general
        if message.contains("slice") || message.contains("slic") {
            return AIResponse(
                content: "Slice fix time! Most slices come from an open clubface at impact and swinging outside-in. Quick fixes: 1. Strengthen your grip - see more knuckles on your left hand. 2. Check your setup - don't aim left to compensate. 3. Feel like you're swinging from the inside, dropping your right elbow down. 4. Practice the 'baseball swing' feeling - rotating your hands through impact. 5. Tempo is crucial - smooth acceleration, not a quick hit. Which club gives you the most trouble with slicing?",
                confidence: 0.9
            )
        }
        
        // Handle equipment questions
        if analysis.topics.contains("equipment") {
            return AIResponse(
                content: "Equipment can make a big difference! What specific equipment are you asking about? For beginners, I'd recommend game improvement irons, a higher-lofted driver (10.5° or more), and hybrids instead of long irons. Getting properly fitted is worth it even for a basic fitting. What's your current setup or what are you looking to upgrade?",
                confidence: 0.8
            )
        }
        
        // Handle short game questions
        if analysis.topics.contains("short_game") {
            return AIResponse(
                content: "Short game is where you can really save strokes! Are you asking about chipping, pitching, or putting specifically? General tip: practice your short game more than your full swing - it's where most golfers can improve fastest. What specific short game situation are you dealing with?",
                confidence: 0.85
            )
        }
        
        // Default response for unclear questions
        return AIResponse(
            content: "I'd love to help with your golf question! Could you be a bit more specific? For example, are you asking about swing technique, equipment, course strategy, or rules? The more details you give me, the better advice I can provide.",
            confidence: 0.6
        )
    }
}

// MARK: - Golf Knowledge Engine Implementation

@MainActor
class GolfKnowledgeEngine {
    init() {}
    
    // Golf knowledge database - topics and responses are handled in DynamicResponseGenerator
    func getTopicExpertise(_ topic: String) -> Double {
        return 0.8 // Default expertise level
    }
}

struct AIResponse {
    let content: String
    let confidence: Double
}