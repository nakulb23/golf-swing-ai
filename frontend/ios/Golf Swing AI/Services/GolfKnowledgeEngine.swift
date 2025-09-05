import Foundation

// MARK: - Dynamic Golf Knowledge Engine
// Flexible knowledge base that can answer any golf question contextually

class GolfKnowledgeEngine {
    private let knowledgeBase: [String: GolfKnowledgeDomain]
    
    init() {
        self.knowledgeBase = Self.buildKnowledgeBase()
        print("🧠 Golf Knowledge Engine loaded with \(knowledgeBase.count) domains")
    }
    
    func getKnowledge(for topics: [String], complexity: QuestionComplexity) -> [KnowledgeComponent] {
        var components: [KnowledgeComponent] = []
        
        for topic in topics {
            if let domain = knowledgeBase[topic] {
                let domainComponents = domain.getComponents(for: complexity)
                components.append(contentsOf: domainComponents)
            }
        }
        
        return components.isEmpty ? getGeneralGolfKnowledge() : components
    }
    
    func searchKnowledge(query: String) -> [KnowledgeComponent] {
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)
        var results: [KnowledgeComponent] = []
        
        for domain in knowledgeBase.values {
            let matches = domain.search(terms: searchTerms)
            results.append(contentsOf: matches)
        }
        
        return results
    }
    
    private func getGeneralGolfKnowledge() -> [KnowledgeComponent] {
        return knowledgeBase["general"]?.getComponents(for: .simple) ?? []
    }
    
    private static func buildKnowledgeBase() -> [String: GolfKnowledgeDomain] {
        return [
            "swing_mechanics": SwingMechanicsDomain(),
            "short_game": ShortGameDomain(),
            "driving": DrivingDomain(),
            "equipment": EquipmentDomain(),
            "course_management": CourseManagementDomain(),
            "mental_game": MentalGameDomain(),
            "rules": RulesDomain(),
            "practice": PracticeDomain(),
            "scoring": ScoringDomain(),
            "troubleshooting": TroubleshootingDomain(),
            "general": GeneralGolfDomain()
        ]
    }
}

// MARK: - Knowledge Domain Protocol

protocol GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent]
    func search(terms: [String]) -> [KnowledgeComponent]
}

// MARK: - Knowledge Component

struct KnowledgeComponent {
    let title: String
    let content: String
    let type: ComponentType
    let complexity: QuestionComplexity
    let tags: [String]
    let confidence: Double
    
    enum ComponentType {
        case definition, technique, tip, troubleshooting, equipment, strategy, drill
    }
}

// MARK: - Swing Mechanics Domain

class SwingMechanicsDomain: GolfKnowledgeDomain {
    private let components: [KnowledgeComponent] = [
        KnowledgeComponent(
            title: "Chip Shot",
            content: """
            A chip shot is a short, low-trajectory shot played around the green to get the ball close to the hole.
            
            **Key characteristics:**
            • Distance: 10-30 yards from green
            • Trajectory: Low flight, mostly roll
            • Clubs: Wedges, 9-iron, 8-iron
            • Setup: Narrow stance, weight forward
            • Ball position: Back of center
            
            **Technique:**
            1. Hands ahead of ball at address and impact
            2. Small backswing, accelerate through
            3. Hit ball first, then turf
            4. Minimal wrist action
            
            **Club selection rule:** Higher loft = more air time, less roll. Lower loft = less air time, more roll.
            """,
            type: .definition,
            complexity: .simple,
            tags: ["chip", "short game", "wedge", "green"],
            confidence: 0.95
        ),
        
        KnowledgeComponent(
            title: "Pitch Shot",
            content: """
            A pitch shot is a higher, softer shot that lands and stops quickly on the green.
            
            **When to use:**
            • Need to carry over obstacles (bunkers, rough)
            • Pin is close to where you'll land
            • Firm or fast greens
            • Need more spin to stop the ball
            
            **Technique:**
            1. Wider stance than chip shot
            2. More weight on front foot (60-70%)
            3. Open clubface slightly
            4. Longer backswing than chip
            5. Accelerate through with active wrists
            6. High finish
            
            **Distance control:** Vary backswing length, not swing speed.
            """,
            type: .technique,
            complexity: .moderate,
            tags: ["pitch", "short game", "wedge", "spin"],
            confidence: 0.9
        ),
        
        KnowledgeComponent(
            title: "Full Swing Fundamentals",
            content: """
            The golf swing is a complex motion, but these fundamentals apply to all full swings:
            
            **Setup (GAPS):**
            • **Grip:** Neutral grip, hands work together
            • **Alignment:** Body parallel to target line
            • **Posture:** Athletic position, spine tilted
            • **Stance:** Shoulder-width apart, balanced
            
            **Swing sequence:**
            1. **Takeaway:** One-piece, low and slow
            2. **Backswing:** Full shoulder turn, stable lower body
            3. **Transition:** Start with lower body
            4. **Impact:** Hands ahead, ball first contact
            5. **Follow-through:** Balanced finish facing target
            
            **Key feels:** Smooth tempo, connected arms and body, maintain balance.
            """,
            type: .technique,
            complexity: .moderate,
            tags: ["swing", "fundamentals", "setup", "tempo"],
            confidence: 0.9
        )
    ]
    
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        switch complexity {
        case .simple:
            return components.filter { $0.complexity == .simple || $0.complexity == .moderate }
        case .moderate:
            return components
        case .complex:
            return components // Would include advanced biomechanics in real implementation
        }
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return components.filter { component in
            terms.contains { term in
                component.tags.contains { $0.contains(term) } ||
                component.title.lowercased().contains(term) ||
                component.content.lowercased().contains(term)
            }
        }
    }
}

// MARK: - Short Game Domain

class ShortGameDomain: GolfKnowledgeDomain {
    private let components: [KnowledgeComponent] = [
        KnowledgeComponent(
            title: "Putting Fundamentals",
            content: """
            Putting accounts for about 40% of your shots - mastering it can dramatically lower scores.
            
            **Setup:**
            • Eyes over the ball
            • Shoulders square to target line
            • Hands under shoulders
            • Ball position: Forward of center
            
            **Stroke:**
            • Pendulum motion from shoulders
            • Minimal wrist action
            • Accelerate through impact
            • Follow through toward target
            
            **Reading greens:**
            • Look for overall slope from behind ball
            • Consider grain direction
            • Factor in speed of greens
            • Trust your first read
            
            **Distance control:** Vary backswing length, keep tempo consistent.
            """,
            type: .technique,
            complexity: .moderate,
            tags: ["putting", "green", "stroke", "distance"],
            confidence: 0.9
        ),
        
        KnowledgeComponent(
            title: "Bunker Play",
            content: """
            Sand shots can be easier than shots from rough once you understand the technique.
            
            **Greenside bunker setup:**
            • Open stance and clubface
            • Ball position forward in stance
            • Dig feet into sand for stability
            • Weight slightly on front foot
            
            **Technique:**
            • Aim 2-3 inches behind ball
            • Hit sand, not ball directly
            • Accelerate through the sand
            • High finish
            • Let loft of club do the work
            
            **Distance control:** 
            • Longer shot: Take less sand, longer swing
            • Shorter shot: Take more sand, shorter swing
            
            **Key:** Commit to the shot and accelerate through impact.
            """,
            type: .technique,
            complexity: .moderate,
            tags: ["bunker", "sand", "wedge", "greenside"],
            confidence: 0.85
        )
    ]
    
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return components.filter { $0.complexity.rawValue <= complexity.rawValue }
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return components.filter { component in
            terms.contains { term in
                component.tags.contains { $0.contains(term) } ||
                component.content.lowercased().contains(term)
            }
        }
    }
}

// MARK: - Additional Domains (Simplified for brevity)

class DrivingDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Driver Setup and Swing",
                content: "Driver technique focuses on hitting up on the ball, wide stance, ball forward in stance, and maintaining balance through a full swing.",
                type: .technique,
                complexity: .moderate,
                tags: ["driver", "tee", "distance", "power"],
                confidence: 0.8
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate).filter { component in
            terms.contains { term in component.tags.contains { $0.contains(term) } }
        }
    }
}

class EquipmentDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Club Selection Basics",
                content: "Choose clubs based on distance, lie, weather conditions, and pin position. Take more club and swing easier for better control.",
                type: .strategy,
                complexity: .simple,
                tags: ["clubs", "selection", "distance", "control"],
                confidence: 0.85
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class CourseManagementDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Smart Course Strategy",
                content: "Play to your strengths, avoid big numbers, aim for center of greens, and think about your next shot when planning the current one.",
                type: .strategy,
                complexity: .moderate,
                tags: ["strategy", "course", "management", "scoring"],
                confidence: 0.8
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class MentalGameDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Mental Approach",
                content: "Stay in the present, commit to your shots, develop a consistent pre-shot routine, and accept that golf is a game of misses.",
                type: .strategy,
                complexity: .moderate,
                tags: ["mental", "confidence", "routine", "focus"],
                confidence: 0.75
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class RulesDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Basic Golf Rules",
                content: "Play the ball as it lies, count every stroke, know your relief options, and when in doubt, play two balls and sort it out later.",
                type: .definition,
                complexity: .simple,
                tags: ["rules", "relief", "penalty", "stroke"],
                confidence: 0.8
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class PracticeDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Effective Practice",
                content: "Practice with purpose, spend 60% of time on short game, create realistic course conditions, and track your progress.",
                type: .tip,
                complexity: .moderate,
                tags: ["practice", "improvement", "drills", "range"],
                confidence: 0.85
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class ScoringDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Lower Your Scores",
                content: "Focus on avoiding big numbers, improve your short game, course management, and develop a reliable pre-shot routine.",
                type: .strategy,
                complexity: .moderate,
                tags: ["scoring", "handicap", "improvement", "strategy"],
                confidence: 0.8
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class TroubleshootingDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Fix Common Issues",
                content: "Most swing problems stem from setup issues. Check grip, alignment, posture, and ball position before making swing changes.",
                type: .troubleshooting,
                complexity: .moderate,
                tags: ["problems", "fix", "setup", "swing"],
                confidence: 0.8
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

class GeneralGolfDomain: GolfKnowledgeDomain {
    func getComponents(for complexity: QuestionComplexity) -> [KnowledgeComponent] {
        return [
            KnowledgeComponent(
                title: "Golf Fundamentals",
                content: "Golf is a game of precision and consistency. Focus on fundamentals, practice regularly, and enjoy the journey of improvement.",
                type: .tip,
                complexity: .simple,
                tags: ["fundamentals", "basics", "improvement"],
                confidence: 0.7
            )
        ]
    }
    
    func search(terms: [String]) -> [KnowledgeComponent] {
        return getComponents(for: .moderate)
    }
}

// MARK: - Extensions

extension QuestionComplexity {
    var rawValue: Int {
        switch self {
        case .simple: return 1
        case .moderate: return 2
        case .complex: return 3
        }
    }
}