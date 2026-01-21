import Foundation
@preconcurrency import NaturalLanguage

// MARK: - Golf RAG Chunk Model
struct GolfChunk: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let tags: GolfTags

    var fullText: String {
        "\(title). \(body)"
    }
}

struct GolfTags: Codable, Sendable {
    let domain: String
    let topic: String
    let skill_level: String
    let club: String
    let shot_type: String
    let conditions: [String]
}

// MARK: - Rules Chunk Model
struct RulesChunk: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let effective_date: String
    let source: String
    let url: String
    let tags: RulesTags

    var fullText: String {
        "\(title). \(body)"
    }
}

struct RulesTags: Codable, Sendable {
    let domain: String
    let type: String
    let topic: String
}

// MARK: - Golf Knowledge Pack Manager
@MainActor
class GolfKnowledgePack: ObservableObject {
    static let shared = GolfKnowledgePack()

    @Published var isLoaded = false
    @Published var loadError: String?

    private var golfChunks: [GolfChunk] = []
    private var rulesChunks: [RulesChunk] = []
    private var chunkEmbeddings: [[Float]] = []
    private var rulesEmbeddings: [[Float]] = []

    private let embeddingModel: NLEmbedding?

    private init() {
        // Use Apple's built-in sentence embedding
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)
        print("📚 GolfKnowledgePack initialized")
    }

    // MARK: - Load Knowledge Pack
    func loadKnowledgePack() async {
        print("📚 Loading golf knowledge pack...")

        do {
            // Load chunks on background thread
            let (loadedGolfChunks, loadedRulesChunks) = try await Task.detached(priority: .userInitiated) {
                var golf: [GolfChunk] = []
                var rules: [RulesChunk] = []

                // Load main golf chunks
                if let golfURL = Bundle.main.url(forResource: "golf_rag", withExtension: "jsonl", subdirectory: "RAG") {
                    golf = try Self.loadJSONLBackground(from: golfURL)
                    print("✅ Loaded \(golf.count) golf chunks")
                } else {
                    print("⚠️ golf_rag.jsonl not found in bundle")
                }

                // Load rules chunks
                if let rulesURL = Bundle.main.url(forResource: "rules_core", withExtension: "jsonl", subdirectory: "RAG") {
                    rules = try Self.loadRulesJSONLBackground(from: rulesURL)
                    print("✅ Loaded \(rules.count) rules chunks")
                } else {
                    print("⚠️ rules_core.jsonl not found in bundle")
                }

                return (golf, rules)
            }.value

            // Update on main actor
            self.golfChunks = loadedGolfChunks
            self.rulesChunks = loadedRulesChunks

            // Generate embeddings on background thread using DispatchQueue
            let embeddingModel = self.embeddingModel
            let golfTexts = loadedGolfChunks.map { $0.fullText }
            let rulesTexts = loadedRulesChunks.map { $0.fullText }

            let (golfEmbeddings, rulesEmbeddings): ([[Float]], [[Float]]) = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    print("🔄 Generating embeddings for \(golfTexts.count) chunks on background thread...")

                    var golfEmb: [[Float]] = []
                    var rulesEmb: [[Float]] = []

                    if let model = embeddingModel {
                        // Generate embeddings for golf chunks
                        golfEmb = golfTexts.map { text in
                            if let vector = model.vector(for: text) {
                                return vector.map { Float($0) }
                            }
                            return []
                        }

                        // Generate embeddings for rules chunks
                        rulesEmb = rulesTexts.map { text in
                            if let vector = model.vector(for: text) {
                                return vector.map { Float($0) }
                            }
                            return []
                        }

                        print("✅ Generated \(golfEmb.count) golf embeddings and \(rulesEmb.count) rules embeddings")
                    } else {
                        print("⚠️ Embedding model not available")
                    }

                    continuation.resume(returning: (golfEmb, rulesEmb))
                }
            }

            // Update on main actor
            self.chunkEmbeddings = golfEmbeddings
            self.rulesEmbeddings = rulesEmbeddings

            isLoaded = true
            loadError = nil
            print("✅ Knowledge pack loaded successfully")

        } catch {
            loadError = error.localizedDescription
            print("❌ Failed to load knowledge pack: \(error)")
        }
    }

    // MARK: - Background Loading Functions (nonisolated for background execution)
    private nonisolated static func loadJSONLBackground(from url: URL) throws -> [GolfChunk] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var items: [GolfChunk] = []
        let decoder = JSONDecoder()

        for line in lines {
            if let data = line.data(using: .utf8) {
                do {
                    let item = try decoder.decode(GolfChunk.self, from: data)
                    items.append(item)
                } catch {
                    print("⚠️ Failed to decode line: \(error)")
                }
            }
        }

        return items
    }

    private nonisolated static func loadRulesJSONLBackground(from url: URL) throws -> [RulesChunk] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var items: [RulesChunk] = []
        let decoder = JSONDecoder()

        for line in lines {
            if let data = line.data(using: .utf8) {
                do {
                    let item = try decoder.decode(RulesChunk.self, from: data)
                    items.append(item)
                } catch {
                    print("⚠️ Failed to decode rules line: \(error)")
                }
            }
        }

        return items
    }

    // MARK: - Retrieval
    func retrieveRelevantChunks(for query: String, topK: Int = 6) -> [GolfChunk] {
        guard let model = embeddingModel,
              let queryVector = model.vector(for: query) else {
            print("⚠️ Could not generate query embedding")
            return keywordSearch(query: query, topK: topK)
        }

        let queryFloats = queryVector.map { Float($0) }

        // Calculate similarities
        var similarities: [(index: Int, score: Float)] = []

        for (index, embedding) in chunkEmbeddings.enumerated() {
            if !embedding.isEmpty {
                let score = cosineSimilarity(queryFloats, embedding)
                similarities.append((index, score))
            }
        }

        // Sort by similarity and get top K
        similarities.sort { $0.score > $1.score }
        let topIndices = similarities.prefix(topK).map { $0.index }

        return topIndices.map { golfChunks[$0] }
    }

    func retrieveRulesChunks(for query: String, topK: Int = 4) -> [RulesChunk] {
        guard let model = embeddingModel,
              let queryVector = model.vector(for: query) else {
            print("⚠️ Could not generate query embedding for rules")
            return keywordSearchRules(query: query, topK: topK)
        }

        let queryFloats = queryVector.map { Float($0) }

        // Calculate similarities
        var similarities: [(index: Int, score: Float)] = []

        for (index, embedding) in rulesEmbeddings.enumerated() {
            if !embedding.isEmpty {
                let score = cosineSimilarity(queryFloats, embedding)
                similarities.append((index, score))
            }
        }

        // Sort by similarity and get top K
        similarities.sort { $0.score > $1.score }
        let topIndices = similarities.prefix(topK).map { $0.index }

        return topIndices.map { rulesChunks[$0] }
    }

    // MARK: - Keyword Search Fallback
    private func keywordSearch(query: String, topK: Int) -> [GolfChunk] {
        let queryWords = query.lowercased().components(separatedBy: .whitespaces)

        var scores: [(index: Int, score: Int)] = []

        for (index, chunk) in golfChunks.enumerated() {
            let text = chunk.fullText.lowercased()
            var score = 0
            for word in queryWords {
                if text.contains(word) {
                    score += 1
                }
            }
            if score > 0 {
                scores.append((index, score))
            }
        }

        scores.sort { $0.score > $1.score }
        return scores.prefix(topK).map { golfChunks[$0.index] }
    }

    private func keywordSearchRules(query: String, topK: Int) -> [RulesChunk] {
        let queryWords = query.lowercased().components(separatedBy: .whitespaces)

        var scores: [(index: Int, score: Int)] = []

        for (index, chunk) in rulesChunks.enumerated() {
            let text = chunk.fullText.lowercased()
            var score = 0
            for word in queryWords {
                if text.contains(word) {
                    score += 1
                }
            }
            if score > 0 {
                scores.append((index, score))
            }
        }

        scores.sort { $0.score > $1.score }
        return scores.prefix(topK).map { rulesChunks[$0.index] }
    }

    // MARK: - Cosine Similarity
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    // MARK: - Stats
    var totalChunks: Int {
        golfChunks.count + rulesChunks.count
    }

    var golfChunkCount: Int {
        golfChunks.count
    }

    var rulesChunkCount: Int {
        rulesChunks.count
    }
}
