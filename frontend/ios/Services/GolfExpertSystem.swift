import Foundation

/// Pure Swift Golf Expert System - No external LLM needed
/// Provides accurate, instant golf advice using pattern matching + knowledge base
@MainActor
class GolfExpertSystem: ObservableObject {
    static let shared = GolfExpertSystem()

    @Published var isLoading = false

    private var conversationHistory: [Message] = []
    private let maxHistoryLength = 10

    private struct Message {
        let role: String // "user" or "assistant"
        let content: String
    }

    // MARK: - Knowledge Base Categories

    private let knowledgeBase: [GolfKnowledgeCategory] = [
        // Rules & Regulations
        GolfKnowledgeCategory(
            category: "rules",
            patterns: [
                "cart path", "path relief", "artificial surface",
                "water hazard", "penalty area", "red stake", "yellow stake",
                "out of bounds", "ob", "white stakes",
                "lost ball", "can't find", "provisional",
                "unplayable", "drop", "relief",
                "embedded", "plugged", "ground under repair",
                "casual water", "standing water",
                "movable obstruction", "immovable obstruction",
                "bunker", "sand", "rake",
                "flagstick", "pin", "tending",
                "stroke and distance", "penalty stroke",
                "ball mark", "pitch mark", "repair",
                "line of play", "line of putt"
            ],
            responses: GolfRulesResponses.all
        ),

        // Swing Mechanics
        GolfKnowledgeCategory(
            category: "swing",
            patterns: [
                "slice", "slicing", "fade", "left to right",
                "hook", "hooking", "draw", "right to left",
                "topped", "topping", "thin", "skulled",
                "fat", "heavy", "chunk", "duff",
                "shank", "hosel",
                "grip", "hold", "hands",
                "posture", "stance", "setup", "address",
                "backswing", "takeaway", "top of swing",
                "downswing", "transition",
                "impact", "contact",
                "follow through", "finish",
                "swing plane", "swing path",
                "tempo", "rhythm", "timing",
                "weight shift", "weight transfer"
            ],
            responses: GolfSwingResponses.all
        ),

        // Equipment
        GolfKnowledgeCategory(
            category: "equipment",
            patterns: [
                "driver", "woods", "fairway wood",
                "iron", "club", "distance",
                "wedge", "loft", "degree",
                "putter", "putting",
                "shaft", "flex", "regular", "stiff",
                "grip size", "grip thickness",
                "ball", "titleist", "callaway",
                "club fitting", "fitted", "custom",
                "beginner clubs", "game improvement",
                "hybrid", "rescue club"
            ],
            responses: GolfEquipmentResponses.all
        ),

        // Course Strategy
        GolfKnowledgeCategory(
            category: "strategy",
            patterns: [
                "course management", "strategy",
                "tee shot", "driver off tee",
                "approach", "iron shot",
                "lay up", "go for it",
                "wind", "upwind", "downwind",
                "uphill", "downhill", "sidehill",
                "hazard", "trouble",
                "safe", "smart", "percentage",
                "target", "aim", "alignment"
            ],
            responses: GolfStrategyResponses.all
        ),

        // Short Game
        GolfKnowledgeCategory(
            category: "short_game",
            patterns: [
                "putt", "putting", "green",
                "chip", "chipping", "bump and run",
                "pitch", "pitching", "lob",
                "flop shot", "high shot",
                "bunker", "sand", "greenside",
                "read green", "break", "slope",
                "distance control", "speed",
                "short game", "around the green"
            ],
            responses: GolfShortGameResponses.all
        ),

        // Mental Game & Practice
        GolfKnowledgeCategory(
            category: "mental_practice",
            patterns: [
                "practice", "drill", "training",
                "mental", "nerves", "pressure",
                "pre-shot routine", "routine",
                "focus", "concentration",
                "visualization", "visualize",
                "improve", "better", "lower score"
            ],
            responses: GolfMentalPracticeResponses.all
        )
    ]

    // MARK: - Main Response System

    func sendMessage(_ userMessage: String) async throws -> ChatResponse {
        isLoading = true
        defer { isLoading = false }

        // Add to history
        conversationHistory.append(Message(role: "user", content: userMessage))
        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
        }

        // Get response
        let response = await analyzeAndRespond(to: userMessage)

        // Add response to history
        conversationHistory.append(Message(role: "assistant", content: response))

        return ChatResponse(
            id: UUID().uuidString,
            message: response,
            isUser: false,
            timestamp: Date(),
            intent: "golf_advice",
            confidence: 0.95
        )
    }

    private func analyzeAndRespond(to question: String) async -> String {
        let lowercased = question.lowercased()

        // Check each knowledge category
        for category in knowledgeBase {
            // Check if question matches any patterns
            for pattern in category.patterns {
                if lowercased.contains(pattern) {
                    // Find best matching response
                    if let response = category.responses.first(where: { response in
                        response.triggers.contains(where: { lowercased.contains($0) })
                    }) {
                        return response.answer
                    }
                }
            }
        }

        // Fallback for unmatched questions
        return """
I'm CaddieChat Pro, your expert golf caddie! I can help you with:

• Golf rules and scenarios
• Swing mechanics and fixes
• Equipment selection and fitting
• Course strategy and management
• Short game and putting
• Practice drills and mental game

What specific golf question can I help you with?
"""
    }

    func clearConversation() {
        conversationHistory.removeAll()
    }
}

// MARK: - Knowledge Base Structures

struct GolfKnowledgeCategory {
    let category: String
    let patterns: [String]
    let responses: [GolfResponse]
}

struct GolfResponse {
    let triggers: [String]
    let answer: String
}

// MARK: - Golf Rules Responses

struct GolfRulesResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["cart path", "path relief", "artificial surface"],
            answer: """
When your ball lands on a cart path, you get **free relief under Rule 16.1** (Abnormal Course Conditions):

**Procedure**:
• Find your nearest point of complete relief (where the path doesn't interfere)
• Drop within one club-length, no closer to the hole
• Must stay in the same area (fairway, rough, etc.)
• **No penalty strokes**

If the path doesn't interfere with your stance or swing, you can play it as it lies. Remember to protect your clubs when hitting off hard surfaces!
"""
        ),

        GolfResponse(
            triggers: ["water hazard", "penalty area", "red stake", "yellow stake"],
            answer: """
**Penalty Areas** (formerly water hazards):

**Yellow Stakes** (lateral boundary):
• **1 penalty stroke**
• Option 1: Stroke and distance (re-hit from original spot)
• Option 2: Drop on line from hole through entry point, any distance back

**Red Stakes** (lateral penalty area):
• **1 penalty stroke**
• Same options as yellow PLUS
• Option 3: Drop within 2 club-lengths of entry point, no closer to hole

**Pro tip**: Take relief from where ball last crossed the margin, not where it ended up.
"""
        ),

        GolfResponse(
            triggers: ["out of bounds", "ob", "white stakes"],
            answer: """
**Out of Bounds** (Rule 18.2):

If your ball is OB (white stakes/lines):
• **Stroke and distance penalty**
• Return to original spot and re-hit
• Counts as 2 strokes (original + penalty)

**Local Rule Alternative** (if in effect):
• Drop in fairway near where ball went OB
• 2-stroke penalty
• Check if your course allows this!

**Pro tip**: Hit a provisional if you think it might be OB to save time walking back.
"""
        ),

        GolfResponse(
            triggers: ["lost ball", "can't find", "provisional"],
            answer: """
**Lost Ball** (Rule 18.2):

You have **3 minutes** to search. If not found:
• **Stroke and distance**
• Return and re-hit (+1 penalty)

**Provisional Ball**:
Announce "I'm hitting a provisional" before playing:
• If original found: pick up provisional (no penalty)
• If original lost/OB: continue with provisional (+1 penalty)

**Pro tip**: Always hit a provisional to save time!
"""
        ),

        GolfResponse(
            triggers: ["unplayable", "drop", "relief"],
            answer: """
**Unplayable Lie** (Rule 19):

Declare your ball unplayable anywhere except penalty area:

**Options** (all 1 penalty stroke):
1. **Stroke & distance**: Re-hit from original spot
2. **Back-on-line**: Drop on line from hole through ball, any distance back
3. **Lateral relief**: Drop within 2 club-lengths, no closer to hole

**Bunker**: Same options, but if dropping outside bunker, it's **2 penalty strokes**.

You decide what's unplayable - it's your call!
"""
        ),

        GolfResponse(
            triggers: ["embedded", "plugged", "ground under repair"],
            answer: """
**Embedded Ball / Ground Under Repair**:

**Embedded Ball** (in own pitch mark):
• Free relief in general area (not bunkers)
• Drop within 1 club-length, no closer

**Ground Under Repair** (GUR - white lines):
• Free relief under Rule 16.1
• Nearest point of complete relief
• Drop within 1 club-length

**Casual Water** (temporary puddles):
• Same as GUR - free relief

**No penalty** for any of these!
"""
        )
    ]
}

// MARK: - Swing Mechanics Responses

struct GolfSwingResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["slice", "slicing", "fade"],
            answer: """
**Fixing a Slice**:

A slice = open clubface + outside-in path.

**Quick Fixes**:
• **Strengthen grip**: See 2-3 knuckles on left hand
• **Check alignment**: Shoulders parallel to target
• **Swing path**: Feel like swinging toward right field (RH)
• **Rotate forearms**: Roll arms through impact
• **Gate drill**: Place sticks to encourage inside-out path

**Most common cause**: Grip too weak. Fix grip first!
"""
        ),

        GolfResponse(
            triggers: ["hook", "hooking", "draw"],
            answer: """
**Fixing a Hook**:

Hook = closed clubface + inside-out path.

**Quick Fixes**:
• **Weaken grip**: Show fewer knuckles
• **Ball position**: Not too far back in stance
• **Hold face open**: Feel clubface stays open through impact
• **Check shoulders**: Don't close them at setup
• **Delay release**: Keep hands quieter

**Practice**: Hit intentional fades to feel open face.
"""
        ),

        GolfResponse(
            triggers: ["topped", "topping", "thin", "skulled"],
            answer: """
**Stopping Topped Shots**:

Topping = rising up or early extension.

**Fixes**:
• **Stay down**: Keep chest over ball through impact
• **Finish swing**: Don't try to "help" ball up
• **Posture**: Maintain spine angle
• **Weight forward**: 60% on lead foot at impact
• **Tee drill**: Place tee just past ball, try to hit it

**Key**: Trust the loft - the club lifts the ball, not you!
"""
        ),

        GolfResponse(
            triggers: ["fat", "heavy", "chunk", "duff"],
            answer: """
**Fixing Fat Shots**:

Fat shots = hitting ground before ball.

**Fixes**:
• **Ball position**: Not too far forward
• **Weight forward**: Start with 60% on lead foot
• **Shallow attack**: Don't dig down
• **Hands ahead**: At impact, hands ahead of ball
• **Head steady**: Don't fall back

**Drill**: Place towel 6" behind ball - don't hit it!
"""
        ),

        GolfResponse(
            triggers: ["grip", "hold", "hands"],
            answer: """
**Golf Grip Fundamentals**:

**Types**:
• **Overlap** (Vardon): Most common
• **Interlock**: Smaller hands
• **Baseball**: Beginners

**Strength**:
• **Neutral**: See 2 knuckles (left hand)
• **Strong**: See 3 knuckles (fixes slice)
• **Weak**: See 1 knuckle (fixes hook)

**Pressure**: 4/10 - light enough to feel clubhead!

**Check**: Lifeline of right hand covers left thumb.
"""
        )
    ]
}

// MARK: - Equipment Responses

struct GolfEquipmentResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["wedge", "loft", "degree"],
            answer: """
**Standard Wedge Lofts**:

• **Pitching Wedge (PW)**: 44-48°
• **Gap Wedge (GW)**: 50-52°
• **Sand Wedge (SW)**: 54-56°
• **Lob Wedge (LW)**: 58-60°

**Gapping**: Use 4-6° between wedges

**Example Setup**: PW (46°), GW (50°), SW (54°), LW (58°)

**Bounce Angle**:
• High (10-14°): Soft conditions, bunkers
• Low (4-8°): Firm turf, tight lies

**Pro tip**: Most golfers need 3-4 wedges max!
"""
        ),

        GolfResponse(
            triggers: ["driver", "loft", "shaft"],
            answer: """
**Driver Specifications**:

**Loft Selection**:
• Slow swing (<85 mph): 12-14°
• Average (85-95 mph): 10.5-12°
• Fast (>95 mph): 8.5-10.5°

**Shaft Flex**:
• Senior: <75 mph
• Regular: 75-90 mph
• Stiff: 90-105 mph
• Extra Stiff: >105 mph

**Rule**: Higher loft = easier launch + more forgiveness

**Pro tip**: Get fitted! Launch angle and spin rate matter more than loft number.
"""
        ),

        GolfResponse(
            triggers: ["iron", "distance", "club selection"],
            answer: """
**Average Iron Distances** (recreational):

• **9-iron**: 120-140 yards
• **8-iron**: 130-150 yards
• **7-iron**: 140-160 yards
• **6-iron**: 150-170 yards
• **5-iron**: 160-180 yards

**Key**: Know YOUR distances, not averages!

**Pro tip**:
• Spend time on the range finding your reliable carry distances
• Take one more club than you think (most miss short!)
• Distance control > max distance
"""
        ),

        GolfResponse(
            triggers: ["beginner clubs", "game improvement", "equipment"],
            answer: """
**Equipment for Beginners**:

**Irons**:
• Game improvement (cavity back, wide sole)
• Larger sweet spot, more forgiving
• Start with 5-iron through PW

**Driver**:
• 10.5° or higher loft
• Forgiving head (460cc)
• Regular flex shaft

**Hybrids** > Long irons
• Replace 3/4/5 irons
• Much easier to hit

**Pro tip**: Get fitted even as beginner! Proper lie angle and shaft flex matter from day 1.
"""
        )
    ]
}

// MARK: - Course Strategy Responses

struct GolfStrategyResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["course management", "strategy", "smart"],
            answer: """
**Smart Course Management**:

**Principles**:
• Play to strengths - know your reliable distances
• Aim for fat part of green, not pin
• Take one more club on approaches
• Avoid compounding mistakes (no hero shots!)
• Minimize big numbers > maximize birdies

**Decision Framework**:
1. What's the worst that can happen?
2. What's my comfortable miss?
3. Am I being aggressive or foolish?

**Pro tip**: Safe bogey > risky double!
"""
        ),

        GolfResponse(
            triggers: ["wind", "upwind", "downwind"],
            answer: """
**Playing in Wind**:

**Into Wind**:
• Take 1-3 more clubs
• Ball back in stance
• Lower trajectory (grip down)
• Swing easier (80%)

**Downwind**:
• Take 1-2 less clubs
• Higher trajectory
• Land short, let it run

**Crosswind**:
• Aim into wind, let it drift
• OR ride the wind (advanced)

**Pro tip**: "Swing easy when it's breezy"
"""
        )
    ]
}

// MARK: - Short Game Responses

struct GolfShortGameResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["putt", "putting", "green"],
            answer: """
**Putting Fundamentals**:

**Setup**:
• Eyes over ball (or just inside)
• Shoulders drive stroke, not hands
• Grip pressure: 3/10 (light!)

**Stroke**:
• Pendulum motion from shoulders
• Accelerate through impact
• No deceleration!

**Distance Control**:
• Focus on distance, not line
• Practice ladder drill (10', 20', 30')

**Pro tip**: Speed control prevents 3-putts!
"""
        ),

        GolfResponse(
            triggers: ["chip", "chipping", "bump and run"],
            answer: """
**Chipping Technique**:

**Setup**:
• Narrow stance, weight forward (60-70%)
• Hands ahead of ball
• Ball back in stance

**Technique**:
• Putting grip for control
• Quiet hands, use shoulders
• Let loft do the work
• Bump and run > high flop

**Club Selection**:
• More green = less loft (8i, 9i)
• Less green = more loft (PW, SW)

**Rule**: Get on green rolling ASAP!
"""
        ),

        GolfResponse(
            triggers: ["bunker", "sand", "greenside"],
            answer: """
**Bunker Play**:

**Setup**:
• Open stance and clubface
• Dig feet in for stability
• Ball forward in stance

**Technique**:
• Aim 2" behind ball
• Swing along body line (left of target)
• Accelerate through sand
• Finish high

**Distance**:
• More sand = less distance
• Less sand = more distance

**Pro tip**: Bounce is your friend - use SW (54-56°)!
"""
        )
    ]
}

// MARK: - Mental & Practice Responses

struct GolfMentalPracticeResponses {
    static let all: [GolfResponse] = [
        GolfResponse(
            triggers: ["practice", "drill", "training", "improve"],
            answer: """
**Effective Practice**:

**Structure** (60/40 rule):
• 60% short game (chipping, putting)
• 40% full swing

**Quality > Quantity**:
• 30 focused minutes > 2 mindless hours
• Every shot has a target
• Practice weaknesses, not strengths

**Drills**:
• **9-ball**: Chip from 3 spots, get 6/9 within 3 feet
• **Ladder**: Putts at 10, 20, 30 feet
• **Gate drill**: Alignment sticks for swing path

**Pro tip**: Track stats to find real weaknesses!
"""
        ),

        GolfResponse(
            triggers: ["mental", "nerves", "pressure", "focus"],
            answer: """
**Mental Game**:

**Pre-Shot Routine**:
1. Stand behind ball, visualize shot
2. Pick specific target
3. Take practice swing feeling the shot
4. Address ball, look at target
5. Trust and swing

**Managing Pressure**:
• Deep breath before shot
• Focus on process, not outcome
• Accept bad shots will happen
• Reset between holes

**Visualization**: See, feel, trust

**Pro tip**: Play one shot at a time. Even pros miss fairways!
"""
        )
    ]
}
