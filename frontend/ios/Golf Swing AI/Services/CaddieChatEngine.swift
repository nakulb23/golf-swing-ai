import Foundation
import LLM

// MARK: - Query Intent Classification

enum QueryIntent: String, CaseIterable {
    case coaching = "COACHING"
    case rules = "RULES"
    case equipment = "EQUIPMENT"
    case strategy = "STRATEGY"
    case liveLatest = "LIVE_LATEST"

    static func classify(_ query: String) -> QueryIntent {
        let lowercased = query.lowercased()

        let latestTriggers = ["latest", "today", "this week", "released", "price", "leaderboard",
                              "pga", "tour", "lpga", "2025", "2026", "2027", "tournament",
                              "who won", "current ranking", "news", "announcement"]
        for trigger in latestTriggers where lowercased.contains(trigger) { return .liveLatest }

        let rulesTriggers = ["rule", "penalty", "drop", "relief", "ob", "out of bounds",
                             "unplayable", "hazard", "bunker rule", "can i", "am i allowed",
                             "legal", "illegal", "usga", "r&a"]
        for trigger in rulesTriggers where lowercased.contains(trigger) { return .rules }

        let equipmentTriggers = ["club", "driver", "iron", "wedge", "putter", "shaft",
                                 "loft", "lie angle", "fitting", "ball", "grip", "equipment",
                                 "gear", "which club", "what club"]
        for trigger in equipmentTriggers where lowercased.contains(trigger) { return .equipment }

        let strategyTriggers = ["strategy", "course", "wind", "approach", "tee shot",
                                "lay up", "target", "aim", "safe", "risk", "when to",
                                "should i", "how do i play"]
        for trigger in strategyTriggers where lowercased.contains(trigger) { return .strategy }

        return .coaching
    }
}

// MARK: - CaddieChat Engine

/// Tiered response pipeline:
///   T0 (~1 ms)   — In-memory response cache (exact query match)
///   T1 (~5-50 ms) — GolfExpertSystem pattern-match (handles ~60-70% of queries)
///   T2/T3 (LLM)  — Qwen2.5-1.5B with reduced context (1 chunk / 300 tokens)
///                   Streams tokens progressively so the user sees text immediately.
@MainActor
class CaddieChatEngine: ObservableObject {
    static let shared = CaddieChatEngine()

    @Published var isLoading = true
    @Published var isReady = false
    @Published var error: String?

    /// Live token stream from the LLM — shown in the chat UI while inference runs.
    @Published var streamingOutput: String = ""
    @Published var isStreaming: Bool = false

    private var bot: LLM?
    private let knowledgePack = GolfKnowledgePack.shared
    private let webSearch = DuckDuckGoSearch.shared

    // MARK: Tier 1 — Expert system (instant pattern-match)
    private let expertSystem = GolfExpertSystem.shared

    // MARK: Tier 0 — Response cache
    private var responseCache = [String: String]()

    // MARK: Streaming
    private var streamingTask: Task<Void, Never>?

    private let modelName = "qwen2.5-1.5b-instruct-q4_k_m"

    // Shorter system prompt → fewer tokens burned on every call
    private let systemPrompt = """
    You are CaddieChat, a friendly golf caddie assistant.

    RULES:
    1. ONLY discuss golf (swing, clubs, rules, strategy, practice)
    2. NEVER write code or technical content
    3. Keep answers to 2-4 sentences maximum
    4. Be conversational and practical like a real caddie

    For non-golf questions say: "I'm your golf caddie! Ask me about your game."
    """

    private init() {
        print("🤖 CaddieChatEngine initialized")
    }

    // MARK: - Initialization

    func initialize() async {
        guard !isReady else {
            print("✅ CaddieChatEngine already ready")
            return
        }

        print("🔄 Initializing CaddieChatEngine...")
        isLoading = true
        error = nil

        await knowledgePack.loadKnowledgePack()

        do {
            try await loadModelBackground()
            isReady = true
            print("✅ CaddieChatEngine ready")
        } catch {
            self.error = error.localizedDescription
            print("❌ CaddieChatEngine initialization failed: \(error)")
        }

        isLoading = false
    }

    private func loadModelBackground() async throws {
        guard let path = modelPath else { throw CaddieError.modelNotFound }
        guard FileManager.default.fileExists(atPath: path.path) else { throw CaddieError.modelNotFound }

        print("🔄 Loading LLM model on background thread...")
        let systemPromptCopy = self.systemPrompt
        let loadedBot: LLM? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let bot = LLM(from: path, template: .chatML(systemPromptCopy))
                continuation.resume(returning: bot)
            }
        }

        self.bot = loadedBot
        if bot == nil { throw CaddieError.modelLoadFailed }
        print("✅ LLM model loaded")
    }

    private var modelPath: URL? {
        if let bundlePath = Bundle.main.url(forResource: modelName, withExtension: "gguf") {
            return bundlePath
        }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("\(modelName).gguf")
    }

    // MARK: - Tier 0: Cache key normalisation

    private func normalizeQuery(_ query: String) -> String {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip punctuation, collapse whitespace
        let stripped = lower.unicodeScalars
            .filter { !CharacterSet.punctuationCharacters.contains($0) }
            .map { String($0) }.joined()
        return stripped
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Streaming helpers

    /// Begins polling bot.output every 60 ms and publishing it to streamingOutput.
    private func startStreaming() {
        streamingOutput = ""
        isStreaming = true
        streamingTask?.cancel()

        guard let bot = bot else { return }

        // Poll bot.output on the main actor; Task.sleep yields so LLM work can proceed.
        streamingTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { [weak self, weak bot] in
                    guard let self, let bot else { return }
                    if self.isStreaming {
                        self.streamingOutput = bot.output
                    }
                }
                try? await Task.sleep(nanoseconds: 60_000_000) // 60 ms
            }
        }
    }

    private func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        streamingOutput = ""
    }

    // MARK: - Main Chat Interface

    func chat(_ query: String) async -> CaddieResponse {
        let startTime = Date()
        let intent = QueryIntent.classify(query)
        let cacheKey = normalizeQuery(query)

        // ─────────────────────────────────────────────────────────
        // TIER 0: Response cache (~1 ms)
        // ─────────────────────────────────────────────────────────
        if let cached = responseCache[cacheKey] {
            let ms = Int(Date().timeIntervalSince(startTime) * 1000)
            print("⚡ T0 cache hit (\(ms) ms)")
            return CaddieResponse(message: cached, intent: intent, sources: [])
        }

        // ─────────────────────────────────────────────────────────
        // TIER 1: Expert system (~5-50 ms) — skip for live queries
        // ─────────────────────────────────────────────────────────
        if intent != .liveLatest {
            if let expertAnswer = expertSystem.tryAnswer(query) {
                responseCache[cacheKey] = expertAnswer
                let ms = Int(Date().timeIntervalSince(startTime) * 1000)
                print("⚡ T1 expert system hit (\(ms) ms)")
                return CaddieResponse(message: expertAnswer, intent: intent, sources: [])
            }
        }

        // ─────────────────────────────────────────────────────────
        // TIER 2/3: LLM with reduced context + streaming
        // ─────────────────────────────────────────────────────────
        startStreaming()
        defer { stopStreaming() }

        let response: CaddieResponse
        switch intent {
        case .liveLatest:
            response = await handleLiveLatestQuery(query)
        case .rules:
            response = await handleRulesQuery(query)
        default:
            response = await handleLocalQuery(query, intent: intent)
        }

        // Cache the LLM result for future identical queries
        if !response.message.isEmpty {
            responseCache[cacheKey] = response.message
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("⏱️ T2/3 LLM total: \(String(format: "%.1f", elapsed))s")
        return response
    }

    // MARK: - Local Query Handler — RAG + LLM (Tier 2/3)

    private func handleLocalQuery(_ query: String, intent: QueryIntent) async -> CaddieResponse {
        guard let bot = bot else {
            return CaddieResponse(
                message: "I'm not ready yet. Please wait while I load.",
                intent: intent, sources: []
            )
        }

        // Reduced from topK:4 / 1200 tokens → topK:1 / 300 tokens
        let relevantChunks = knowledgePack.retrieveRelevantChunks(for: query, topK: 1)

        var context = ""
        var tokenCount = 0
        let maxContextTokens = 300

        for chunk in relevantChunks {
            let chunkText = "[\(chunk.tags.domain.uppercased())] \(chunk.title): \(chunk.body)\n\n"
            let estimated = chunkText.count / 4
            if tokenCount + estimated > maxContextTokens { break }
            context += chunkText
            tokenCount += estimated
        }

        let prompt: String
        if context.isEmpty {
            prompt = "Golf question: \(query)\n\nAnswer briefly (2-3 sentences):"
        } else {
            prompt = "Context: \(context)\nQuestion: \(query)\nBrief answer (2-3 sentences):"
        }

        print("📝 LLM generating (topK=1, ≤300 ctx tokens)…")
        let rawResponse = await bot.getCompletion(from: prompt)
        let cleaned = cleanResponse(rawResponse)

        return CaddieResponse(
            message: cleaned.isEmpty
                ? "I couldn't generate a response. Try rephrasing your question."
                : cleaned,
            intent: intent,
            sources: relevantChunks.map { $0.title }
        )
    }

    // MARK: - Rules Query Handler

    private func handleRulesQuery(_ query: String) async -> CaddieResponse {
        guard let bot = bot else {
            return CaddieResponse(message: "I'm not ready yet.", intent: .rules, sources: [])
        }

        // Reduced from topK:3+2 → topK:2+1
        let rulesChunks = knowledgePack.retrieveRulesChunks(for: query, topK: 2)
        let golfChunks  = knowledgePack.retrieveRelevantChunks(for: query, topK: 1)

        var context = ""
        for chunk in rulesChunks {
            context += "[\(chunk.tags.topic.uppercased())] \(chunk.title): \(chunk.body)\n\n"
        }
        for chunk in golfChunks {
            context += "[\(chunk.tags.domain.uppercased())] \(chunk.title): \(chunk.body)\n\n"
        }

        let prompt = """
        Golf rules context:
        \(context)
        Question: \(query)
        Clear, brief answer (2-3 sentences):
        """

        let rawResponse = await bot.getCompletion(from: prompt)
        let cleaned = cleanResponse(rawResponse)

        var sources = rulesChunks.map { "\($0.title) (\($0.source))" }
        sources.append(contentsOf: golfChunks.map { $0.title })

        return CaddieResponse(message: cleaned, intent: .rules, sources: sources)
    }

    // MARK: - Live/Latest Query Handler

    private func handleLiveLatestQuery(_ query: String) async -> CaddieResponse {
        print("🌐 Live query → web search…")
        let searchResults = await webSearch.search(query: query + " golf", maxResults: 3)

        if searchResults.isEmpty {
            var local = await handleLocalQuery(query, intent: .liveLatest)
            local.message = "Based on my knowledge:\n\n" + local.message
                + "\n\n⚠️ For current info, please check official sources."
            return local
        }

        guard let bot = bot else {
            return CaddieResponse(message: "I'm not ready yet.", intent: .liveLatest, sources: [])
        }

        var context = "Recent web search results:\n\n"
        var sources: [String] = []
        for result in searchResults {
            context += "[\(result.title)]\n\(result.snippet)\nSource: \(result.url)\n\n"
            sources.append(result.url)
        }

        let prompt = "\(context)\nQuestion: \(query)\nBrief answer (2-3 sentences):"
        let rawResponse = await bot.getCompletion(from: prompt)
        var cleaned = cleanResponse(rawResponse)

        if !sources.isEmpty {
            cleaned += "\n\nSources:\n" + sources.map { "• \($0)" }.joined(separator: "\n")
        }

        return CaddieResponse(message: cleaned, intent: .liveLatest, sources: sources)
    }

    // MARK: - Response Cleaning

    private func cleanResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove code blocks
        let codeBlockPattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")

        // Remove lines that look like code
        let codeKeywords = ["#include", "import ", "def ", "func ", "class ", "return ",
                            "int ", "void ", "std::", "cout", "cin", "printf",
                            "assert(", "if (", "for (", "while (", "++", "==", "!=", "();", "};"]
        let lines = cleaned.components(separatedBy: "\n")
        cleaned = lines.filter { line in
            !codeKeywords.contains { line.contains($0) }
        }.joined(separator: "\n")

        // Truncate at common LLM "continuation" hallucination patterns
        let stopPatterns = ["\nQ:", "\nQuestion:", "\n\nQ", "\nUser:", "Human:",
                            "\n---", "\n\n\n", "Here's a C++", "Here's a Python", "Here's code"]
        for pattern in stopPatterns {
            if let range = cleaned.range(of: pattern) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }

        // Limit to ~5 sentences
        let sentences = cleaned.components(separatedBy: ". ")
        if sentences.count > 5 {
            cleaned = sentences.prefix(5).joined(separator: ". ")
            if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                cleaned += "."
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clear Conversation

    func clearConversation() {
        if let path = modelPath {
            bot = LLM(from: path, template: .chatML(systemPrompt))
        }
        responseCache.removeAll()
        print("🗑️ Conversation + cache cleared")
    }
}

// MARK: - Response Model

struct CaddieResponse {
    var message: String
    let intent: QueryIntent
    let sources: [String]
}

// MARK: - Errors

enum CaddieError: LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound:   return "Golf AI model not found"
        case .modelLoadFailed: return "Failed to load AI model"
        case .generationFailed: return "Failed to generate response"
        }
    }
}
