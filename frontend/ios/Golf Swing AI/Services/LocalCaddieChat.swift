import Foundation
import NaturalLanguage

// MARK: - Local Caddie Chat

@MainActor
class LocalCaddieChat: ObservableObject {
    @Published var isProcessing = false
    
    private let knowledgeBase = GolfKnowledgeBase()
    private let responseGenerator = CaddieResponseGenerator()
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
    
    func sendChatMessage(_ message: String) async throws -> ChatResponse {
        print("🏌️ Processing local caddie chat: \(message)")
        
        self.isProcessing = true
        
        defer {
            self.isProcessing = false
        }
        
        // Analyze intent and extract keywords
        let intent = analyzeIntent(message: message)
        let keywords = extractKeywords(from: message)
        
        // Check if question is golf-related
        let isGolfRelated = isGolfQuestion(message: message, keywords: keywords)
        
        if !isGolfRelated {
            return ChatResponse(
                id: UUID().uuidString,
                message: "I'm your golf caddie! I'm here to help with golf-related questions like swing tips, course strategy, equipment advice, and rules. How can I assist with your golf game?",
                isUser: false,
                timestamp: Date(),
                intent: "greeting",
                confidence: 1.0
            )
        }
        
        // Generate response based on intent and knowledge base
        let answer = generateResponse(intent: intent, keywords: keywords, originalMessage: message)
        
        return ChatResponse(
            id: UUID().uuidString,
            message: answer,
            isUser: false,
            timestamp: Date(),
            intent: "response",
            confidence: 0.8
        )
    }
    
    private func analyzeIntent(message: String) -> ChatIntent {
        let lowercaseMessage = message.lowercased()
        
        // Swing advice patterns
        if lowercaseMessage.contains("swing") || lowercaseMessage.contains("technique") || 
           lowercaseMessage.contains("form") || lowercaseMessage.contains("posture") {
            return .swingAdvice
        }
        
        // Equipment patterns
        if lowercaseMessage.contains("club") || lowercaseMessage.contains("equipment") ||
           lowercaseMessage.contains("driver") || lowercaseMessage.contains("iron") ||
           lowercaseMessage.contains("putter") || lowercaseMessage.contains("wedge") {
            return .equipment
        }
        
        // Course strategy patterns
        if lowercaseMessage.contains("course") || lowercaseMessage.contains("strategy") ||
           lowercaseMessage.contains("hole") || lowercaseMessage.contains("shot") ||
           lowercaseMessage.contains("approach") || lowercaseMessage.contains("green") {
            return .courseStrategy
        }
        
        // Rules patterns
        if lowercaseMessage.contains("rule") || lowercaseMessage.contains("penalty") ||
           lowercaseMessage.contains("legal") || lowercaseMessage.contains("allowed") {
            return .rules
        }
        
        // Training patterns
        if lowercaseMessage.contains("practice") || lowercaseMessage.contains("training") ||
           lowercaseMessage.contains("improve") || lowercaseMessage.contains("better") ||
           lowercaseMessage.contains("drill") || lowercaseMessage.contains("exercise") {
            return .training
        }
        
        // Recommendation patterns
        if lowercaseMessage.contains("recommend") || lowercaseMessage.contains("suggest") ||
           lowercaseMessage.contains("should") || lowercaseMessage.contains("best") {
            return .recommendation
        }
        
        // Problem solving patterns
        if lowercaseMessage.contains("problem") || lowercaseMessage.contains("issue") ||
           lowercaseMessage.contains("wrong") || lowercaseMessage.contains("fix") ||
           lowercaseMessage.contains("help") || lowercaseMessage.contains("trouble") {
            return .problemSolving
        }
        
        return .general
    }
    
    private func extractKeywords(from message: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = message
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: message.startIndex..<message.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, tag == .noun || tag == .verb {
                let keyword = String(message[tokenRange]).lowercased()
                if keyword.count > 2 && !isStopWord(keyword) {
                    keywords.append(keyword)
                }
            }
            return true
        }
        
        return keywords
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["the", "and", "but", "for", "you", "can", "how", "what", "when", "where", "why", "with"]
        return stopWords.contains(word)
    }
    
    private func isGolfQuestion(message: String, keywords: [String]) -> Bool {
        let golfTerms = [
            "golf", "swing", "club", "ball", "course", "hole", "tee", "green", "fairway",
            "driver", "iron", "putter", "wedge", "handicap", "par", "birdie", "eagle",
            "bogey", "slice", "hook", "draw", "fade", "chip", "pitch", "bunker", "sand",
            "caddie", "tournament", "pga", "masters", "stroke", "shot", "round", "game"
        ]
        
        let messageWords = message.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let allWords = messageWords + keywords
        
        return allWords.contains { word in
            golfTerms.contains { golfTerm in
                word.contains(golfTerm) || golfTerm.contains(word)
            }
        }
    }
    
    private func generateResponse(intent: ChatIntent, keywords: [String], originalMessage: String) -> String {
        switch intent {
        case .swingAdvice:
            return responseGenerator.generateSwingAdvice(keywords: keywords)
        case .equipment:
            return responseGenerator.generateEquipmentAdvice(keywords: keywords)
        case .courseStrategy:
            return responseGenerator.generateCourseStrategy(keywords: keywords)
        case .rules:
            return responseGenerator.generateRulesAdvice(keywords: keywords)
        case .training:
            return responseGenerator.generateTrainingAdvice(keywords: keywords)
        case .recommendation:
            return responseGenerator.generateRecommendationAdvice(keywords: keywords)
        case .problemSolving:
            return responseGenerator.generateProblemSolvingAdvice(keywords: keywords)
        case .general:
            return responseGenerator.generateGeneralAdvice(keywords: keywords, message: originalMessage)
        case .followUp:
            return responseGenerator.generateGeneralAdvice(keywords: keywords, message: originalMessage)
        case .clarification:
            return responseGenerator.generateGeneralAdvice(keywords: keywords, message: originalMessage)
        case .information:
            return responseGenerator.generateGeneralAdvice(keywords: keywords, message: originalMessage)
        case .technique:
            return responseGenerator.generateSwingAdvice(keywords: keywords)
        case .strategy:
            return responseGenerator.generateCourseStrategy(keywords: keywords)
        }
    }
}

// MARK: - Chat Intent (using enum from EnhancedGolfChat)
// ChatIntent enum is defined in EnhancedGolfChat.swift to avoid conflicts

// MARK: - Golf Knowledge Base

class GolfKnowledgeBase {
    let swingTips = [
        "Keep your head still during the swing",
        "Maintain proper posture with a slight knee bend",
        "Start the downswing with your hips, not your hands",
        "Follow through completely to a balanced finish",
        "Keep your left arm straight during the backswing",
        "Grip the club with light pressure, like holding a bird",
        "Make sure your stance is shoulder-width apart",
        "Keep your weight on the balls of your feet"
    ]
    
    let equipmentAdvice = [
        "Choose clubs that match your skill level and swing speed",
        "Get properly fitted for clubs by a professional",
        "Start with a basic set: driver, 5-iron through pitching wedge, putter",
        "Consider game improvement irons if you're a beginner",
        "Make sure your golf ball compression matches your swing speed",
        "Replace your grips every 40 rounds or once a year",
        "Keep your clubs clean for better performance"
    ]
    
    let courseStrategy = [
        "Play within your abilities and choose conservative shots",
        "Aim for the center of greens, not the pin",
        "Use course management to avoid trouble areas",
        "Plan your approach shot when hitting your tee shot",
        "Take one more club than you think you need",
        "Focus on your short game to lower scores",
        "Learn to read greens for better putting"
    ]
    
    let trainingDrills = [
        "Practice your putting every session",
        "Work on alignment with alignment sticks",
        "Practice chipping from various lies around the green",
        "Use impact tape to check your contact",
        "Practice slow-motion swings to build muscle memory",
        "Work on your balance with one-legged swings",
        "Practice tempo with a metronome or counting"
    ]
    
    let commonRules = [
        "Play the ball as it lies, unless local rules allow otherwise",
        "If your ball goes in a water hazard, you can drop behind the hazard",
        "You get free relief from cart paths and other immovable obstructions",
        "Maximum of 14 clubs allowed in your bag during a round",
        "Count every stroke, including penalty strokes",
        "Repair divots and ball marks to help maintain the course",
        "Be ready to play when it's your turn"
    ]
}

// MARK: - Response Generator

class CaddieResponseGenerator {
    private let knowledgeBase = GolfKnowledgeBase()
    
    func generateSwingAdvice(keywords: [String]) -> String {
        var response = "Here's some swing advice:\n\n"
        
        // Check for specific swing issues
        if keywords.contains("slice") {
            response += "To fix a slice:\n• Check your grip - try a stronger grip\n• Make sure you're not swinging too much from outside-in\n• Focus on releasing the club through impact\n\n"
        } else if keywords.contains("hook") {
            response += "To fix a hook:\n• Try a weaker grip\n• Make sure your clubface isn't too closed at impact\n• Focus on your swing path\n\n"
        } else if keywords.contains("tempo") {
            response += "For better tempo:\n• Count '1-2-3' during your swing\n• Practice with slow, smooth swings\n• Focus on rhythm rather than power\n\n"
        }
        
        // Add general tip
        let randomTip = knowledgeBase.swingTips.randomElement() ?? "Focus on fundamentals"
        response += "💡 Pro tip: \(randomTip)"
        
        return response
    }
    
    func generateEquipmentAdvice(keywords: [String]) -> String {
        var response = "Equipment recommendations:\n\n"
        
        if keywords.contains("driver") {
            response += "🏌️ Driver selection:\n• Choose loft based on your swing speed\n• Higher loft (10.5°+) for slower swings\n• Consider adjustable drivers for fine-tuning\n\n"
        } else if keywords.contains("putter") {
            response += "🎯 Putter advice:\n• Try different putter styles to find what feels comfortable\n• Blade putters for better feel, mallet putters for forgiveness\n• Make sure the length fits your setup\n\n"
        } else if keywords.contains("iron") {
            response += "⛳ Iron selection:\n• Game improvement irons for beginners\n• Cavity back designs for more forgiveness\n• Consider hybrid clubs to replace long irons\n\n"
        }
        
        let randomAdvice = knowledgeBase.equipmentAdvice.randomElement() ?? "Get properly fitted by a professional"
        response += "💡 Remember: \(randomAdvice)"
        
        return response
    }
    
    func generateCourseStrategy(keywords: [String]) -> String {
        var response = "Course strategy tips:\n\n"
        
        if keywords.contains("tee") || keywords.contains("drive") {
            response += "🏌️ Tee shots:\n• Aim for the widest part of the fairway\n• Choose a club you can hit straight consistently\n• Consider position for your approach shot\n\n"
        } else if keywords.contains("approach") {
            response += "🎯 Approach shots:\n• Aim for the center of the green\n• Take one more club than you think\n• Consider pin position when choosing your target\n\n"
        } else if keywords.contains("putting") || keywords.contains("green") {
            response += "⛳ Putting strategy:\n• Read the green from multiple angles\n• Focus on speed more than line\n• Try to leave putts below the hole\n\n"
        }
        
        let randomStrategy = knowledgeBase.courseStrategy.randomElement() ?? "Play smart, not aggressive"
        response += "💡 Key principle: \(randomStrategy)"
        
        return response
    }
    
    func generateRulesAdvice(keywords: [String]) -> String {
        var response = "Golf rules guidance:\n\n"
        
        if keywords.contains("water") || keywords.contains("hazard") {
            response += "💧 Water hazards:\n• You can play from where the ball crossed into the hazard\n• Add one penalty stroke\n• Drop behind the hazard keeping the point between you and the hole\n\n"
        } else if keywords.contains("bunker") || keywords.contains("sand") {
            response += "🏖️ Bunker rules:\n• Don't ground your club before hitting\n• You can't move loose impediments\n• If unplayable, you can take relief with penalty\n\n"
        } else if keywords.contains("lost") || keywords.contains("ball") {
            response += "🔍 Lost ball:\n• You have 3 minutes to search\n• If not found, return to where you last played\n• Add stroke and distance penalty\n\n"
        }
        
        let randomRule = knowledgeBase.commonRules.randomElement() ?? "When in doubt, ask your playing partners"
        response += "📋 Remember: \(randomRule)"
        
        return response
    }
    
    func generateTrainingAdvice(keywords: [String]) -> String {
        var response = "Practice recommendations:\n\n"
        
        if keywords.contains("putting") {
            response += "🎯 Putting practice:\n• Practice short putts (3-6 feet) daily\n• Work on distance control with long putts\n• Use alignment aids during practice\n\n"
        } else if keywords.contains("short") || keywords.contains("game") {
            response += "⛳ Short game practice:\n• Spend 70% of practice time on short game\n• Practice from different lies around the green\n• Work on various distances and trajectories\n\n"
        } else if keywords.contains("range") {
            response += "🏌️ Range practice:\n• Have a plan before hitting balls\n• Work on specific targets and distances\n• Practice with different clubs\n\n"
        }
        
        let randomDrill = knowledgeBase.trainingDrills.randomElement() ?? "Practice with purpose, not just volume"
        response += "💪 Practice tip: \(randomDrill)"
        
        return response
    }
    
    func generateRecommendationAdvice(keywords: [String]) -> String {
        var response = "Here are my recommendations:\n\n"
        
        if keywords.contains("beginner") || keywords.contains("start") {
            response += "🔰 For beginners:\n• Start with lessons from a PGA professional\n• Focus on short game fundamentals\n• Practice regularly but don't overdo it\n• Play shorter courses initially\n\n"
        } else if keywords.contains("equipment") {
            response += "🛠️ Equipment recommendations:\n• Get a basic club fitting\n• Start with game improvement clubs\n• Don't buy too many clubs initially\n• Invest in good instruction before expensive equipment\n\n"
        } else {
            response += "🎯 General recommendations:\n• Focus on fundamentals\n• Practice with purpose\n• Play within your abilities\n• Enjoy the journey of improvement\n\n"
        }
        
        response += "💡 Remember: Consistent practice beats perfect technique!"
        return response
    }
    
    func generateProblemSolvingAdvice(keywords: [String]) -> String {
        var response = "Let's solve this golf challenge:\n\n"
        
        if keywords.contains("slice") || keywords.contains("hook") {
            response += "🎯 Ball flight issues:\n• Check your grip first\n• Work on swing path\n• Consider professional lessons\n• Practice with alignment aids\n\n"
        } else if keywords.contains("distance") {
            response += "📏 Distance problems:\n• Focus on solid contact first\n• Work on flexibility and fitness\n• Check your equipment specifications\n• Consider swing tempo adjustments\n\n"
        } else if keywords.contains("consistency") {
            response += "🎯 Consistency issues:\n• Develop a pre-shot routine\n• Focus on fundamentals\n• Practice more frequently\n• Work on mental game\n\n"
        } else {
            response += "🔧 Problem-solving approach:\n• Identify the root cause\n• Work on one thing at a time\n• Practice with specific drills\n• Be patient with progress\n\n"
        }
        
        response += "💪 Stay positive - every golfer faces challenges!"
        return response
    }
    
    func generateGeneralAdvice(keywords: [String], message: String) -> String {
        let responses = [
            "Great question! Golf is a game of continuous improvement. What specific aspect of your game would you like to work on?",
            "I'm here to help with your golf game! Whether it's swing mechanics, course strategy, or equipment advice, just ask.",
            "Golf can be challenging, but that's what makes it rewarding. What's your biggest golf challenge right now?",
            "Every golfer's journey is unique. What would you like to know about improving your game?",
            "I love talking golf! What specific area would you like some guidance on?"
        ]
        
        return responses.randomElement() ?? "How can I help with your golf game today?"
    }
}

// MARK: - Chat Response Formatter

extension LocalCaddieChat {
    private func formatResponse(_ response: String) -> String {
        // Add some personality and formatting
        var formattedResponse = response
        
        // Add caddie personality
        if formattedResponse.count < 50 {
            let caddieIntros = [
                "As your caddie, I'd suggest: ",
                "Here's what I recommend: ",
                "From my experience: ",
                "My advice would be: "
            ]
            formattedResponse = (caddieIntros.randomElement() ?? "") + formattedResponse
        }
        
        return formattedResponse
    }
}