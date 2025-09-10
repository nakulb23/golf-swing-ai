import Foundation

// MARK: - Dynamic Response Generator
// Generates contextual, conversational responses using knowledge base and conversation memory

class DynamicResponseGenerator: @unchecked Sendable {
    
    func generateResponse(
        for analysis: ContextualAnalysis,
        using knowledgeEngine: GolfKnowledgeEngine,
        withMemory memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        // Get relevant knowledge components
        let knowledgeComponents = knowledgeEngine.getKnowledge(
            for: analysis.topics,
            complexity: analysis.complexity
        )
        
        // Handle different intent types with context
        switch analysis.intent {
        case .followUp:
            return await generateFollowUpResponse(analysis, knowledgeComponents, memory)
        case .clarification:
            return await generateClarificationResponse(analysis, knowledgeComponents, memory)
        case .information, .technique:
            return await generateInformationResponse(analysis, knowledgeComponents, memory)
        case .problemSolving:
            return await generateProblemSolvingResponse(analysis, knowledgeComponents, memory)
        case .recommendation:
            return await generateRecommendationResponse(analysis, knowledgeComponents, memory)
        default:
            return await generateGeneralResponse(analysis, knowledgeComponents, memory)
        }
    }
    
    // MARK: - Specific Response Generators
    
    private func generateFollowUpResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        let recentHistory = memory.getRecentHistory(count: 3)
        
        var response = ""
        
        // Reference previous conversation
        if let lastExchange = recentHistory.last {
            response += "Building on what we just discussed about \(lastExchange.topics.first ?? "golf"):\n\n"
        }
        
        // Add new information
        if let primaryComponent = knowledge.first {
            response += formatKnowledgeComponent(primaryComponent, style: .conversational)
        } else {
            response += "That's a great follow-up question! Could you be more specific about what aspect you'd like to explore further?"
        }
        
        // Add connecting question
        response += "\n\n" + generateConnectingQuestion(for: analysis.topics, basedOn: memory)
        
        return GeneratedResponse(
            content: response,
            confidence: knowledge.isEmpty ? 0.6 : knowledge.first?.confidence ?? 0.8,
            usedKnowledge: knowledge.map { $0.title },
            responseType: .followUp
        )
    }
    
    private func generateClarificationResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        let recentHistory = memory.getRecentHistory(count: 2)
        
        var response = "Let me break that down more clearly:\n\n"
        
        if let lastTopic = recentHistory.last?.topics.first,
           let relevantKnowledge = knowledge.first(where: { $0.tags.contains(lastTopic) }) {
            
            response += formatKnowledgeComponent(relevantKnowledge, style: .detailed)
            
        } else if let primaryComponent = knowledge.first {
            response += formatKnowledgeComponent(primaryComponent, style: .detailed)
        } else {
            response += "I want to make sure I'm addressing your question properly. Could you help me understand which specific part you'd like me to explain further?"
        }
        
        response += "\n\nDoes this help clarify things? Feel free to ask about any specific part!"
        
        return GeneratedResponse(
            content: response,
            confidence: 0.8,
            usedKnowledge: knowledge.map { $0.title },
            responseType: .clarification
        )
    }
    
    private func generateInformationResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        guard let primaryComponent = knowledge.first else {
            return generateFallbackResponse(for: analysis.originalMessage)
        }
        
        var response = ""
        
        // Personalize based on user context
        response += personalizeOpening(for: analysis.userContext, topic: analysis.topics.first ?? "golf")
        
        // Core information
        response += formatKnowledgeComponent(primaryComponent, style: .informative)
        
        // Add related information if multiple components
        if knowledge.count > 1 {
            response += "\n\n**Related concepts:**\n"
            for component in knowledge.dropFirst().prefix(2) {
                response += "• \(component.title): \(extractFirstSentence(component.content))\n"
            }
        }
        
        // Contextual follow-up
        response += "\n\n" + generateContextualFollowUp(for: analysis, basedOn: memory)
        
        return GeneratedResponse(
            content: response,
            confidence: primaryComponent.confidence,
            usedKnowledge: knowledge.map { $0.title },
            responseType: .information
        )
    }
    
    private func generateProblemSolvingResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        var response = ""
        
        // Empathetic opening based on sentiment
        switch analysis.sentiment {
        case .frustrated:
            response += "I understand how frustrating that can be! Let's work through this step by step.\n\n"
        case .seekingHelp:
            response += "I'm here to help! Let's identify what's happening and how to fix it.\n\n"
        default:
            response += "Let's troubleshoot this issue together.\n\n"
        }
        
        // Problem diagnosis
        if let troubleshootingComponent = knowledge.first(where: { $0.type == .troubleshooting }) {
            response += "**What's likely happening:**\n"
            response += formatKnowledgeComponent(troubleshootingComponent, style: .diagnostic)
            response += "\n\n"
        }
        
        // Solution steps
        if let techniqueComponent = knowledge.first(where: { $0.type == .technique }) {
            response += "**How to fix it:**\n"
            response += formatKnowledgeComponent(techniqueComponent, style: .stepByStep)
        }
        
        // Check if this is a recurring issue
        if memory.getUserProfile().commonIssues.contains(where: { analysis.originalMessage.lowercased().contains($0) }) {
            response += "\n\n💡 I notice we've discussed this before. Consider working with a PGA professional for personalized help with this recurring issue."
        }
        
        return GeneratedResponse(
            content: response,
            confidence: knowledge.isEmpty ? 0.5 : 0.85,
            usedKnowledge: knowledge.map { $0.title },
            responseType: .problemSolving
        )
    }
    
    private func generateRecommendationResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        let userProfile = memory.getUserProfile()
        var response = ""
        
        // Tailor recommendation to skill level
        switch userProfile.skillLevel {
        case .beginner:
            response += "For someone starting out, I'd recommend:\n\n"
        case .intermediate:
            response += "To take your game to the next level:\n\n"
        case .advanced:
            response += "For fine-tuning your advanced game:\n\n"
        default:
            response += "Here's what I'd recommend:\n\n"
        }
        
        // Provide specific recommendations
        if let primaryComponent = knowledge.first {
            response += formatKnowledgeComponent(primaryComponent, style: .recommendation)
        }
        
        // Add personalized tips based on conversation history
        if let preferredTopic = userProfile.preferredTopics.max(by: { $0.value < $1.value })?.key {
            response += "\n\n💡 Since you're interested in \(preferredTopic.replacingOccurrences(of: "_", with: " ")), you might also want to explore how this connects to that area of your game."
        }
        
        return GeneratedResponse(
            content: response,
            confidence: 0.8,
            usedKnowledge: knowledge.map { $0.title },
            responseType: .recommendation
        )
    }
    
    private func generateGeneralResponse(
        _ analysis: ContextualAnalysis,
        _ knowledge: [KnowledgeComponent],
        _ memory: ConversationMemory
    ) async -> GeneratedResponse {
        
        if let primaryComponent = knowledge.first {
            let response = personalizeOpening(for: analysis.userContext, topic: analysis.topics.first ?? "golf") +
                          formatKnowledgeComponent(primaryComponent, style: .conversational) +
                          "\n\n" + generateContextualFollowUp(for: analysis, basedOn: memory)
            
            return GeneratedResponse(
                content: response,
                confidence: primaryComponent.confidence,
                usedKnowledge: knowledge.map { $0.title },
                responseType: .general
            )
        } else {
            return generateFallbackResponse(for: analysis.originalMessage)
        }
    }
    
    // MARK: - Formatting and Helper Methods
    
    private func formatKnowledgeComponent(_ component: KnowledgeComponent, style: FormattingStyle) -> String {
        switch style {
        case .conversational:
            return makeConversational(component.content)
        case .detailed:
            return component.content
        case .informative:
            return component.content
        case .diagnostic:
            return extractDiagnosticInfo(component.content)
        case .stepByStep:
            return extractSteps(component.content)
        case .recommendation:
            return makeRecommendation(component.content)
        }
    }
    
    private func makeConversational(_ content: String) -> String {
        // Remove excessive formatting and make more natural
        return content
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "•", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractDiagnosticInfo(_ content: String) -> String {
        // Extract the most relevant diagnostic information
        let lines = content.components(separatedBy: .newlines)
        return lines.prefix(3).joined(separator: "\n")
    }
    
    private func extractSteps(_ content: String) -> String {
        // Extract numbered steps or bullet points
        let lines = content.components(separatedBy: .newlines)
        let steps = lines.filter { $0.contains("1.") || $0.contains("2.") || $0.contains("•") }
        return steps.isEmpty ? content : steps.joined(separator: "\n")
    }
    
    private func makeRecommendation(_ content: String) -> String {
        // Format as actionable recommendations
        return content.replacingOccurrences(of: "**Key characteristics:**", with: "**I recommend focusing on:**")
    }
    
    private func extractFirstSentence(_ content: String) -> String {
        return content.components(separatedBy: ".").first ?? content
    }
    
    private func personalizeOpening(for userProfile: UserGolfProfile, topic: String) -> String {
        switch userProfile.skillLevel {
        case .beginner:
            return "Great question! As you're developing your game, \(topic.replacingOccurrences(of: "_", with: " ")) is a really important area to understand.\n\n"
        case .advanced:
            return "Excellent question about \(topic.replacingOccurrences(of: "_", with: " ")). For your skill level, here are the key details:\n\n"
        default:
            return ""
        }
    }
    
    private func generateContextualFollowUp(for analysis: ContextualAnalysis, basedOn memory: ConversationMemory) -> String {
        let topics = analysis.topics
        
        if topics.contains("swing_mechanics") {
            return "Would you like me to explain any specific part of the swing sequence in more detail?"
        } else if topics.contains("short_game") {
            return "Are you working on this around a specific course or practice area?"
        } else if topics.contains("equipment") {
            return "What's your current setup, and are you looking to make any changes?"
        } else {
            return "What specific aspect would you like to dive deeper into?"
        }
    }
    
    private func generateConnectingQuestion(for topics: [String], basedOn memory: ConversationMemory) -> String {
        let userProfile = memory.getUserProfile()
        
        if let commonIssue = userProfile.commonIssues.first {
            return "Since you've mentioned \(commonIssue) before, how does this relate to that challenge?"
        } else {
            return "How does this fit with what you're currently working on in your game?"
        }
    }
    
    private func generateFallbackResponse(for message: String) -> GeneratedResponse {
        let response = """
        That's an interesting question! While I want to give you the most accurate golf advice, I might need a bit more context to provide the best answer.
        
        Could you help me understand:
        • What specific situation or challenge you're facing?
        • What aspect of golf this relates to (swing, short game, equipment, etc.)?
        
        I'm here to help with any golf-related question - just want to make sure I give you the most useful information!
        """
        
        return GeneratedResponse(
            content: response,
            confidence: 0.7,
            usedKnowledge: [],
            responseType: .clarification
        )
    }
}

// MARK: - Supporting Types

struct GeneratedResponse {
    let content: String
    let confidence: Double
    let usedKnowledge: [String]
    let responseType: ResponseType
}


enum FormattingStyle {
    case conversational, detailed, informative, diagnostic, stepByStep, recommendation
}