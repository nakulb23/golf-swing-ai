import Foundation
import NaturalLanguage

// MARK: - Enhanced Golf Chat (Claude-Style Responses)

@MainActor
class EnhancedGolfChat: ObservableObject {
    static let shared = EnhancedGolfChat()
    
    @Published var isProcessing = false
    
    private let golfExpert = GolfExpertSystem()
    private let responseFormatter = ConversationalFormatter()
    
    // Conversation history for context
    private var conversationHistory: [(role: String, content: String)] = []
    private let maxHistorySize = 10
    
    private init() {
        print("🤖 Enhanced Golf Chat initialized - Claude-style conversations")
    }
    
    func sendChatMessage(_ message: String) async throws -> ChatResponse {
        print("🏌️ Processing enhanced golf chat: \(message)")
        
        self.isProcessing = true
        
        defer {
            self.isProcessing = false
        }
        
        // Add user message to history
        conversationHistory.append((role: "user", content: message))
        
        // Simulate processing time for more natural feel
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second for faster response
        
        // Analyze the message with context
        let analysis = analyzeMessageWithContext(message)
        
        // Generate contextual response
        let response = golfExpert.generateContextualResponse(for: analysis, history: conversationHistory)
        let formattedResponse = responseFormatter.formatAsConversational(response)
        
        // Add assistant response to history
        conversationHistory.append((role: "assistant", content: formattedResponse))
        
        // Trim history if too long
        if conversationHistory.count > maxHistorySize * 2 {
            conversationHistory = Array(conversationHistory.suffix(maxHistorySize * 2))
        }
        
        return ChatResponse(
            id: UUID().uuidString,
            message: formattedResponse,
            isUser: false,
            timestamp: Date(),
            intent: analysis.intent.rawValue,
            confidence: response.confidence
        )
    }
    
    private func analyzeMessageWithContext(_ message: String) -> MessageAnalysis {
        let lowercased = message.lowercased()
        
        // Check context from previous messages
        let hasGolfContext = conversationHistory.contains { 
            $0.content.lowercased().contains("golf") || 
            $0.content.lowercased().contains("swing") ||
            $0.content.lowercased().contains("club")
        }
        
        // Check if golf-related
        let golfKeywords = ["golf", "swing", "club", "ball", "course", "hole", "tee", "green", "fairway", "putt", "chip", "drive", "iron", "wedge", "driver", "handicap", "par", "birdie", "eagle", "bogey", "slice", "hook", "fade", "draw", "grip", "stance", "backswing", "downswing", "follow through", "impact", "release", "tempo", "rhythm", "practice", "range", "lessons"]
        
        let isGolfRelated = golfKeywords.contains { lowercased.contains($0) } || hasGolfContext
        
        // Determine intent with context awareness
        let intent = determineContextualIntent(lowercased, hasContext: hasGolfContext)
        
        // Extract key concepts
        let concepts = extractConcepts(message)
        
        return MessageAnalysis(
            originalMessage: message,
            intent: intent,
            concepts: concepts,
            isGolfRelated: isGolfRelated,
            tone: determineTone(lowercased),
            hasContext: hasGolfContext
        )
    }
    
    private func determineContextualIntent(_ message: String, hasContext: Bool) -> ChatIntent {
        // Check for follow-up questions
        if message.starts(with: "what about") || message.starts(with: "how about") || 
           message.contains("also") || message.contains("another") {
            return .followUp
        }
        
        // Check for clarification
        if message.contains("what do you mean") || message.contains("explain") || 
           message.contains("more detail") || message.contains("elaborate") {
            return .clarification
        }
        
        // Original intent detection
        return determineIntent(message)
    }
    
    private func analyzeMessage(_ message: String) -> MessageAnalysis {
        let lowercased = message.lowercased()
        
        // Check if golf-related
        let golfKeywords = ["golf", "swing", "club", "ball", "course", "hole", "tee", "green", "fairway", "putt", "chip", "drive", "iron", "wedge", "driver", "handicap", "par", "birdie", "eagle", "bogey", "slice", "hook", "fade", "draw"]
        let isGolfRelated = golfKeywords.contains { lowercased.contains($0) }
        
        // Determine intent
        let intent = determineIntent(lowercased)
        
        // Extract key concepts
        let concepts = extractConcepts(message)
        
        return MessageAnalysis(
            originalMessage: message,
            intent: intent,
            concepts: concepts,
            isGolfRelated: isGolfRelated,
            tone: determineTone(lowercased),
            hasContext: false
        )
    }
    
    private func determineIntent(_ message: String) -> ChatIntent {
        if message.contains("how") || message.contains("what") || message.contains("why") {
            // Swing and shot-related keywords
            let swingKeywords = ["swing", "chip", "putt", "drive", "pitch", "flop", "bump", "run", "shot", "stroke", "stance", "grip", "backswing", "downswing", "follow", "through"]
            if swingKeywords.contains(where: { message.contains($0) }) { return .swingAdvice }
            
            if message.contains("club") || message.contains("equipment") { return .equipment }
            if message.contains("course") || message.contains("strategy") { return .courseStrategy }
            if message.contains("rule") { return .rules }
            if message.contains("practice") || message.contains("improve") { return .training }
        }
        
        if message.contains("recommend") || message.contains("suggest") || message.contains("should") {
            return .recommendation
        }
        
        if message.contains("problem") || message.contains("issue") || message.contains("wrong") || message.contains("fix") {
            return .problemSolving
        }
        
        return .general
    }
    
    private func extractConcepts(_ message: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = message
        
        var concepts: [String] = []
        
        tagger.enumerateTags(in: message.startIndex..<message.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, tag == .noun {
                let concept = String(message[tokenRange]).lowercased()
                if concept.count > 2 {
                    concepts.append(concept)
                }
            }
            return true
        }
        
        return concepts
    }
    
    private func determineTone(_ message: String) -> MessageTone {
        if message.contains("help") || message.contains("please") {
            return .helpSeeking
        }
        if message.contains("frustrated") || message.contains("can't") || message.contains("always") {
            return .frustrated
        }
        if message.contains("beginner") || message.contains("new") || message.contains("start") {
            return .beginner
        }
        return .neutral
    }
}

// MARK: - Golf Expert System

class GolfExpertSystem {
    private let knowledgeBase = AdvancedGolfKnowledge()
    
    func generateContextualResponse(for analysis: MessageAnalysis, history: [(role: String, content: String)]) -> ExpertResponse {
        // Handle follow-up and clarification intents
        if analysis.intent == .followUp {
            return handleFollowUp(analysis, history: history)
        }
        
        if analysis.intent == .clarification {
            return handleClarification(analysis, history: history)
        }
        
        // Default to standard response generation
        return generateExpertResponse(for: analysis)
    }
    
    private func handleFollowUp(_ analysis: MessageAnalysis, history: [(role: String, content: String)]) -> ExpertResponse {
        // Look at previous assistant response to build on it
        if history.reversed().first(where: { $0.role == "assistant" }) != nil {
            let followUpContext = "Building on what we just discussed: \n\n"
            
            // Generate follow-up based on the original message and previous context
            let baseResponse = generateExpertResponse(for: analysis)
            return ExpertResponse(
                mainContent: followUpContext + baseResponse.mainContent,
                type: baseResponse.type,
                confidence: baseResponse.confidence
            )
        }
        
        return generateExpertResponse(for: analysis)
    }
    
    private func handleClarification(_ analysis: MessageAnalysis, history: [(role: String, content: String)]) -> ExpertResponse {
        let clarificationIntro = "Let me explain that in more detail:\n\n"
        let baseResponse = generateExpertResponse(for: analysis)
        
        return ExpertResponse(
            mainContent: clarificationIntro + baseResponse.mainContent + "\n\nDoes this clarification help? Feel free to ask if you need me to explain any specific part differently!",
            type: baseResponse.type,
            confidence: baseResponse.confidence
        )
    }
    
    func generateExpertResponse(for analysis: MessageAnalysis) -> ExpertResponse {
        guard analysis.isGolfRelated else {
            return ExpertResponse(
                mainContent: "I'm specifically designed to help with golf! I'd love to assist you with swing technique, course strategy, equipment advice, or any other golf-related questions. What would you like to know about your golf game?",
                type: .redirect,
                confidence: 1.0
            )
        }
        
        switch analysis.intent {
        case .swingAdvice:
            return generateSwingAdvice(analysis)
        case .equipment:
            return generateEquipmentAdvice(analysis)
        case .courseStrategy:
            return generateStrategyAdvice(analysis)
        case .rules:
            return generateRulesAdvice(analysis)
        case .training:
            return generateTrainingAdvice(analysis)
        case .recommendation:
            return generateRecommendation(analysis)
        case .problemSolving:
            return generateProblemSolution(analysis)
        case .general:
            return generateGeneralAdvice(analysis)
        case .followUp:
            return generateGeneralAdvice(analysis)
        case .clarification:
            return generateGeneralAdvice(analysis)
        }
    }
    
    private func generateSwingAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        let message = analysis.originalMessage.lowercased()
        let concepts = analysis.concepts.joined(separator: " ")
        
        // Handle specific shot questions
        if message.contains("chip") && (message.contains("what") || message.contains("how")) {
            return ExpertResponse(
                mainContent: """
                **A chip shot** is a short, low-flying shot around the green to get close to the pin! 🎯
                
                **The Basics:**
                • 10-30 yards from green
                • Low flight, mostly rolls
                • Clear path to pin
                
                **Quick Setup:**
                • Narrow stance, weight forward
                • Ball slightly back
                • Hands ahead at address
                
                **Club Choice:**
                • Pitching wedge → more roll
                • Sand wedge → higher flight
                • 9-iron → maximum roll
                
                **Golden Rule:** Pick landing spot 1/3 to pin, let it roll! 🏌️
                """,
                type: .instruction,
                confidence: 0.95
            )
        }
        
        if concepts.contains("slice") {
            return ExpertResponse(
                mainContent: """
                **Slice Fix** - totally fixable! 💪
                
                **Main Causes:**
                • Open clubface at impact
                • Outside-in swing path
                • Weak grip
                
                **Quick Fixes:**
                1. **Strengthen grip** → see 2-3 knuckles on left hand
                2. **Square up setup** → don't aim too far left
                3. **Feel the release** → rotate forearms through impact
                4. **Swing from inside** → drop right elbow down
                
                **Practice Drill:** Place club behind ball angled inside-out, swing without hitting it.
                
                Start with grip first - it affects everything else! 🏌️
                """,
                type: .instruction,
                confidence: 0.9
            )
        }
        
        return ExpertResponse(
            mainContent: """
            **Swing Fundamentals** 🏌️
            
            **The Big 4:**
            • **Setup** → posture, alignment, ball position
            • **Tempo** → smooth acceleration
            • **Balance** → stay centered
            • **Impact** → hands ahead, clean contact
            
            **Key Sequence:**
            1. Athletic setup
            2. One-piece takeaway
            3. Full shoulder turn
            4. Start down with lower body
            5. Balanced finish to target
            
            What specific part would you like help with?
            """,
            type: .instruction,
            confidence: 0.8
        )
    }
    
    private func generateEquipmentAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            **Equipment Advice** ⛳
            
            **Golden Rules:**
            • Get fitted (even basic fitting helps!)
            • Start simple, add tech later
            • Quality > quantity
            
            **For Beginners:**
            • Game improvement irons
            • Higher-lofted driver (10.5°+)
            • Hybrids instead of long irons
            
            **Course Tips:**
            • Take one more club than you think
            • Factor in wind/elevation
            • Know your distances
            
            What specific equipment are you looking at?
            """,
            type: .advice,
            confidence: 0.85
        )
    }
    
    private func generateStrategyAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            Smart course management can drop strokes off your score immediately! It's often more about avoiding big numbers than making birdies.
            
            **Strategic Mindset:**
            • **Play to your strengths** - Use clubs you're confident with
            • **Minimize risk** - Aim for centers of greens, not pins
            • **Think backwards** - Plan your approach shot when hitting your tee shot
            
            **Key Strategy Principles:**
            
            **Tee Shots:**
            • Aim for the widest part of the fairway
            • Sometimes 3-wood or hybrid is smarter than driver
            • Position for your favorite approach distance
            
            **Approach Shots:**
            • Take enough club to reach the back of the green
            • Avoid short-siding yourself
            • Consider pin position - center is often best
            
            **Short Game:**
            • Get the ball on the green first, worry about distance second
            • Use less lofted clubs when possible (bump and run)
            • Leave putts below the hole when possible
            
            **Mental Game:**
            • Play one shot at a time
            • Accept that golf is hard - don't let bad shots compound
            • Have a pre-shot routine and stick to it
            
            What specific course situations would you like strategy help with?
            """,
            type: .strategy,
            confidence: 0.9
        )
    }
    
    private func generateRulesAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            Golf rules can be tricky, but understanding the basics helps you play with confidence and maintain pace of play.
            
            **Most Important Rules to Know:**
            
            **Ball at Rest:**
            • Play it as it lies (unless local rules provide relief)
            • Free relief from cart paths, sprinkler heads, etc.
            • No moving the ball to improve your lie
            
            **Penalty Situations:**
            • **Water hazards** - Drop behind where ball crossed, add 1 stroke
            • **Lost ball** - Return to where you last played, add stroke + distance
            • **Out of bounds** - Same as lost ball
            • **Unplayable** - Several options, all cost 1 stroke
            
            **On the Green:**
            • Mark your ball before lifting
            • Repair ball marks and replace divots
            • Don't step on other players' lines
            
            **Pace of Play:**
            • Be ready when it's your turn
            • Keep up with the group ahead
            • Let faster groups play through
            
            **Equipment Rules:**
            • Maximum 14 clubs in your bag
            • Can't add clubs during the round
            • No artificial aids (like distance finders in tournaments)
            
            Do you have a specific rules situation you'd like me to explain? I'm happy to clarify any confusing scenarios!
            """,
            type: .rules,
            confidence: 0.95
        )
    }
    
    private func generateTrainingAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            Smart practice is the key to improvement! Quality beats quantity every time.
            
            **Effective Practice Structure:**
            
            **Short Game (70% of practice time):**
            • **Putting** - Work on 3-6 foot putts daily
            • **Chipping** - Practice from different lies and distances
            • **Pitching** - Control trajectory and spin
            • **Bunker play** - Get comfortable with sand shots
            
            **Full Swing (30% of practice time):**
            • **Alignment** - Use alignment sticks or clubs
            • **Tempo** - Practice smooth, controlled swings
            • **Impact position** - Work on hitting down on irons
            • **Ball striking** - Focus on clean contact
            
            **Practice Drills:**
            
            **For Putting:**
            • Gate drill (two tees to create a gate)
            • Distance control ladder (putt to different targets)
            • Clock drill (putts from around the hole)
            
            **For Chipping:**
            • Land spot practice (pick specific landing zones)
            • Different clubs from same spot
            • Pressure situations (must get up and down)
            
            **Mental Practice:**
            • Visualization exercises
            • Pre-shot routine development
            • Course management scenarios
            
            **Practice Schedule:**
            • 3-4 times per week is better than one long session
            • Always have a specific goal for each session
            • Track your progress with stats
            
            What area of your game needs the most work? I can create a specific practice plan for you!
            """,
            type: .training,
            confidence: 0.9
        )
    }
    
    private func generateRecommendation(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            I'd be happy to make some recommendations! Golf improvement is very individual, so the best advice depends on your specific situation.
            
            **To give you the most helpful recommendations, it would be great to know:**
            • What's your current skill level/handicap?
            • What part of your game frustrates you most?
            • How often do you play/practice?
            • What are your golf goals?
            
            **General Recommendations for Most Golfers:**
            
            **Immediate Impact:**
            • Focus on short game - it's the fastest way to lower scores
            • Take lessons from a PGA professional
            • Play within your abilities - course management matters
            
            **Equipment:**
            • Get a basic club fitting
            • Make sure your putter fits your stroke
            • Consider game improvement clubs if you're developing
            
            **Practice:**
            • Spend more time on putting and chipping than full swing
            • Practice with purpose - have specific goals
            • Play different courses to challenge yourself
            
            **Mental Game:**
            • Develop a consistent pre-shot routine
            • Focus on process, not outcome
            • Accept that golf is hard - embrace the challenge!
            
            What specific area would you like me to focus my recommendations on? The more details you can share, the better I can help!
            """,
            type: .recommendation,
            confidence: 0.8
        )
    }
    
    private func generateProblemSolution(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            Golf problems can be frustrating, but they're also opportunities to improve! Let's work through this systematically.
            
            **Problem-Solving Approach:**
            
            **1. Identify the Pattern**
            • When does this issue happen most?
            • Is it with certain clubs or situations?
            • How consistent is the problem?
            
            **2. Check Fundamentals First**
            • **Setup** - grip, stance, alignment, posture
            • **Tempo** - are you rushing or too slow?
            • **Balance** - staying centered throughout swing
            
            **3. Common Issue Fixes:**
            
            **If you're hitting it fat:**
            • Ball position might be too far forward
            • Work on hitting down on irons
            • Check your weight shift
            
            **If you're hitting it thin:**
            • Ball might be too far back
            • Could be standing up during swing
            • Focus on staying down through impact
            
            **If direction is inconsistent:**
            • Check your alignment - use alignment sticks
            • Work on clubface control at impact
            • Ensure consistent setup routine
            
            **4. Practice Solutions**
            • Isolate the problem with specific drills
            • Practice in slow motion first
            • Get feedback (video, impact tape, lessons)
            
            **5. Course Management**
            • While working on fixes, play smarter
            • Use clubs that minimize the problem
            • Focus on avoiding big numbers
            
            What specific problem are you dealing with? The more details you can share, the more targeted help I can provide!
            """,
            type: .problemSolving,
            confidence: 0.85
        )
    }
    
    private func generateGeneralAdvice(_ analysis: MessageAnalysis) -> ExpertResponse {
        return ExpertResponse(
            mainContent: """
            **Your AI Golf Pro** 🏌️‍♂️
            
            **I Can Help With:**
            
            🏌️ **Swing Technique** → fixing slice, fundamentals
            ⛳ **Course Strategy** → shot selection, management  
            🎯 **Short Game** → putting, chipping, bunkers
            🛠️ **Equipment** → club fitting, selection
            📋 **Rules & Etiquette** → penalties, proper play
            💪 **Practice** → drills, improvement plans
            
            **What golf challenge can I help you tackle?**
            """,
            type: .general,
            confidence: 0.7
        )
    }
}

// MARK: - Conversational Formatter

class ConversationalFormatter {
    func formatAsConversational(_ response: ExpertResponse) -> String {
        var formatted = response.mainContent
        
        // Add conversational elements based on type
        switch response.type {
        case .instruction:
            formatted = addInstructionalTone(formatted)
        case .advice:
            formatted = addAdvisoryTone(formatted)
        case .strategy:
            formatted = addStrategicTone(formatted)
        case .rules:
            formatted = addRulesTone(formatted)
        case .training:
            formatted = addTrainingTone(formatted)
        case .recommendation:
            formatted = addRecommendationTone(formatted)
        case .problemSolving:
            formatted = addProblemSolvingTone(formatted)
        case .followUp:
            formatted = addFollowUpTone(formatted)
        case .clarification:
            formatted = addClarificationTone(formatted)
        case .information:
            formatted = addInformationTone(formatted)
        case .general:
            formatted = addGeneralTone(formatted)
        case .redirect:
            return formatted // Already conversational
        }
        
        return formatted
    }
    
    private func addInstructionalTone(_ content: String) -> String {
        return content
    }
    
    private func addAdvisoryTone(_ content: String) -> String {
        return content
    }
    
    private func addStrategicTone(_ content: String) -> String {
        return content
    }
    
    private func addRulesTone(_ content: String) -> String {
        return content
    }
    
    private func addTrainingTone(_ content: String) -> String {
        return content
    }
    
    private func addRecommendationTone(_ content: String) -> String {
        return content
    }
    
    private func addProblemSolvingTone(_ content: String) -> String {
        return content
    }
    
    private func addGeneralTone(_ content: String) -> String {
        return content
    }
    
    private func addFollowUpTone(_ content: String) -> String {
        return content + "\n\nBuilding on that, is there anything else you'd like to explore on this topic?"
    }
    
    private func addClarificationTone(_ content: String) -> String {
        return content + "\n\nDoes this help clarify things? Let me know if you'd like me to explain any part in more detail!"
    }
    
    private func addInformationTone(_ content: String) -> String {
        return content + "\n\nHope this information helps! Feel free to ask about any specific aspect you'd like to explore further."
    }
}

// MARK: - Supporting Models

struct MessageAnalysis {
    let originalMessage: String
    let intent: ChatIntent
    let concepts: [String]
    let isGolfRelated: Bool
    let tone: MessageTone
    let hasContext: Bool
}

enum MessageTone {
    case helpSeeking
    case frustrated
    case beginner
    case neutral
}

enum ChatIntent: String {
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

enum ResponseType: String {
    case followUp = "follow_up"
    case clarification = "clarification"
    case information = "information"
    case problemSolving = "problem_solving"
    case recommendation = "recommendation"
    case general = "general"
    case instruction = "instruction"
    case advice = "advice"
    case strategy = "strategy"
    case rules = "rules"
    case training = "training"
    case redirect = "redirect"
}

struct ExpertResponse {
    let mainContent: String
    let type: ResponseType
    let confidence: Double
}

class AdvancedGolfKnowledge {
    // Extended knowledge base would go here
    // This is a placeholder for the enhanced golf knowledge system
}