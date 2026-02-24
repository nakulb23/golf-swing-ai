import Foundation
import CloudKit

/// Manages feedback collection and learning for CaddieChat
/// Stores unknown questions, corrections, and ratings - syncs to iCloud
@MainActor
class CaddieFeedbackManager: ObservableObject {
    static let shared = CaddieFeedbackManager()

    @Published var pendingCorrections: [CaddieCorrection] = []
    @Published var unknownQuestions: [UnknownQuestion] = []
    @Published var customResponses: [CustomResponse] = []
    @Published var ratings: [ResponseRating] = []
    @Published var iCloudSyncEnabled = true
    @Published var lastSyncDate: Date?

    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var feedbackDirectory: URL {
        documentsDirectory.appendingPathComponent("CaddieFeedback")
    }

    // iCloud key-value store for simple sync
    private let iCloudStore = NSUbiquitousKeyValueStore.default

    // CloudKit for larger data
    private let container = CKContainer(identifier: "iCloud.nakulb.Golf-Swing-AI")
    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    private init() {
        createFeedbackDirectory()
        loadAllData()
        setupiCloudSync()
    }

    // MARK: - iCloud Sync Setup

    private func setupiCloudSync() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Sync on launch
        iCloudStore.synchronize()

        // Load from iCloud if available
        loadFromiCloud()
    }

    @objc private func iCloudDataDidChange(_ notification: Notification) {
        print("☁️ iCloud data changed externally")
        loadFromiCloud()
    }

    // MARK: - Logging Methods

    /// Log a question that wasn't matched by the knowledge base
    func logUnknownQuestion(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check if already logged (avoid duplicates)
        if unknownQuestions.contains(where: { $0.question.lowercased() == trimmed.lowercased() }) {
            // Increment count instead
            if let index = unknownQuestions.firstIndex(where: { $0.question.lowercased() == trimmed.lowercased() }) {
                unknownQuestions[index].askCount += 1
                unknownQuestions[index].lastAsked = Date()
            }
        } else {
            let unknown = UnknownQuestion(
                id: UUID(),
                question: trimmed,
                firstAsked: Date(),
                lastAsked: Date(),
                askCount: 1,
                deviceId: getDeviceId()
            )
            unknownQuestions.append(unknown)
        }

        saveUnknownQuestions()
        syncToiCloud()
        print("❓ Logged unknown question: \(trimmed)")
    }

    /// Log a successful pattern match (for analytics)
    func logSuccessfulMatch(question: String, pattern: String, category: String) {
        print("✅ Matched '\(question)' → pattern: '\(pattern)' (category: \(category))")
    }

    // MARK: - Rating & Corrections

    /// Record thumbs up/down rating for a response
    func recordRating(question: String, response: String, helpful: Bool) {
        let rating = ResponseRating(
            id: UUID(),
            question: question,
            responsePreview: String(response.prefix(200)),
            helpful: helpful,
            timestamp: Date(),
            deviceId: getDeviceId()
        )

        ratings.append(rating)
        saveRatings()
        syncToiCloud()
        print(helpful ? "👍 Response rated helpful" : "👎 Response rated unhelpful")
    }

    /// Submit a user correction for an incorrect answer
    func submitCorrection(question: String, wrongResponse: String, correctAnswer: String) {
        let correction = CaddieCorrection(
            id: UUID(),
            question: question,
            wrongResponse: String(wrongResponse.prefix(200)),
            correctAnswer: correctAnswer,
            submittedAt: Date(),
            approved: false,
            deviceId: getDeviceId()
        )

        pendingCorrections.append(correction)
        saveCorrections()
        syncToiCloud()
        print("📝 Correction submitted for review")
    }

    /// Approve a correction and add it to custom responses
    func approveCorrection(_ correction: CaddieCorrection) {
        let customResponse = CustomResponse(
            id: UUID(),
            triggers: extractKeywords(from: correction.question),
            response: correction.correctAnswer,
            source: "user_correction",
            addedAt: Date()
        )

        customResponses.append(customResponse)
        pendingCorrections.removeAll { $0.id == correction.id }

        saveCustomResponses()
        saveCorrections()
        syncToiCloud()
        print("✅ Correction approved and added to knowledge base")
    }

    /// Manually add a custom response
    func addCustomResponse(triggers: [String], response: String) {
        let custom = CustomResponse(
            id: UUID(),
            triggers: triggers,
            response: response,
            source: "manual_add",
            addedAt: Date()
        )

        customResponses.append(custom)
        saveCustomResponses()
        syncToiCloud()
        print("➕ Added custom response with triggers: \(triggers)")
    }

    // MARK: - Query Methods

    /// Check if we have a custom response for a question
    func getCustomResponse(for question: String) -> String? {
        let lowercased = question.lowercased()

        for custom in customResponses {
            if custom.triggers.contains(where: { lowercased.contains($0.lowercased()) }) {
                return custom.response
            }
        }

        return nil
    }

    /// Get count of unknown questions
    func getUnknownQuestionsCount() -> Int {
        return unknownQuestions.count
    }

    /// Get most frequently asked unknown questions
    func getTopUnknownQuestions(limit: Int = 10) -> [UnknownQuestion] {
        return unknownQuestions
            .sorted { $0.askCount > $1.askCount }
            .prefix(limit)
            .map { $0 }
    }

    /// Get all ratings (for admin view)
    func getAllRatings() -> [ResponseRating] {
        return ratings.sorted { $0.timestamp > $1.timestamp }
    }

    /// Get unhelpful ratings (priority for improvement)
    func getUnhelpfulRatings() -> [ResponseRating] {
        return ratings.filter { !$0.helpful }.sorted { $0.timestamp > $1.timestamp }
    }

    /// Get statistics
    func getStats() -> CaddieStats {
        let helpfulCount = ratings.filter { $0.helpful }.count
        let totalRatings = ratings.count
        let helpfulPercentage = totalRatings > 0 ? Double(helpfulCount) / Double(totalRatings) * 100 : 0

        return CaddieStats(
            unknownQuestionsCount: unknownQuestions.count,
            pendingCorrectionsCount: pendingCorrections.count,
            customResponsesCount: customResponses.count,
            totalRatings: totalRatings,
            helpfulPercentage: helpfulPercentage,
            topUnknownQuestions: getTopUnknownQuestions(limit: 5).map { $0.question }
        )
    }

    // MARK: - iCloud Sync

    private func syncToiCloud() {
        guard iCloudSyncEnabled else { return }

        // Sync small data via key-value store
        if let unknownData = try? JSONEncoder().encode(unknownQuestions) {
            iCloudStore.set(unknownData, forKey: "unknownQuestions")
        }

        if let ratingsData = try? JSONEncoder().encode(ratings.suffix(100)) { // Keep last 100 ratings in iCloud
            iCloudStore.set(ratingsData, forKey: "ratings")
        }

        if let correctionsData = try? JSONEncoder().encode(pendingCorrections) {
            iCloudStore.set(correctionsData, forKey: "corrections")
        }

        if let customData = try? JSONEncoder().encode(customResponses) {
            iCloudStore.set(customData, forKey: "customResponses")
        }

        iCloudStore.set(Date(), forKey: "lastSyncDate")
        iCloudStore.synchronize()

        lastSyncDate = Date()
        print("☁️ Synced feedback to iCloud")
    }

    private func loadFromiCloud() {
        guard iCloudSyncEnabled else { return }

        // Merge unknown questions from iCloud
        if let data = iCloudStore.data(forKey: "unknownQuestions"),
           let cloudQuestions = try? JSONDecoder().decode([UnknownQuestion].self, from: data) {
            mergeUnknownQuestions(cloudQuestions)
        }

        // Merge ratings from iCloud
        if let data = iCloudStore.data(forKey: "ratings"),
           let cloudRatings = try? JSONDecoder().decode([ResponseRating].self, from: data) {
            mergeRatings(cloudRatings)
        }

        // Merge corrections from iCloud
        if let data = iCloudStore.data(forKey: "corrections"),
           let cloudCorrections = try? JSONDecoder().decode([CaddieCorrection].self, from: data) {
            mergeCorrections(cloudCorrections)
        }

        // Merge custom responses from iCloud
        if let data = iCloudStore.data(forKey: "customResponses"),
           let cloudCustom = try? JSONDecoder().decode([CustomResponse].self, from: data) {
            mergeCustomResponses(cloudCustom)
        }

        if let syncDate = iCloudStore.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = syncDate
        }

        print("☁️ Loaded feedback from iCloud")
    }

    private func mergeUnknownQuestions(_ cloudQuestions: [UnknownQuestion]) {
        for cloudQ in cloudQuestions {
            if let existingIndex = unknownQuestions.firstIndex(where: { $0.question.lowercased() == cloudQ.question.lowercased() }) {
                // Merge: take higher count and latest date
                unknownQuestions[existingIndex].askCount = max(unknownQuestions[existingIndex].askCount, cloudQ.askCount)
                unknownQuestions[existingIndex].lastAsked = max(unknownQuestions[existingIndex].lastAsked, cloudQ.lastAsked)
            } else {
                unknownQuestions.append(cloudQ)
            }
        }
        saveUnknownQuestions()
    }

    private func mergeRatings(_ cloudRatings: [ResponseRating]) {
        let existingIds = Set(ratings.map { $0.id })
        let newRatings = cloudRatings.filter { !existingIds.contains($0.id) }
        ratings.append(contentsOf: newRatings)
        saveRatings()
    }

    private func mergeCorrections(_ cloudCorrections: [CaddieCorrection]) {
        let existingIds = Set(pendingCorrections.map { $0.id })
        let newCorrections = cloudCorrections.filter { !existingIds.contains($0.id) }
        pendingCorrections.append(contentsOf: newCorrections)
        saveCorrections()
    }

    private func mergeCustomResponses(_ cloudCustom: [CustomResponse]) {
        let existingIds = Set(customResponses.map { $0.id })
        let newCustom = cloudCustom.filter { !existingIds.contains($0.id) }
        customResponses.append(contentsOf: newCustom)
        saveCustomResponses()
    }

    // MARK: - Export for Training

    /// Export all feedback data as JSON for external training
    func exportFeedbackData() -> URL? {
        let export = CaddieFeedbackExport(
            exportDate: Date(),
            unknownQuestions: unknownQuestions,
            corrections: pendingCorrections,
            customResponses: customResponses,
            ratings: ratings
        )

        let exportURL = documentsDirectory.appendingPathComponent("caddie_feedback_export_\(Int(Date().timeIntervalSince1970)).json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(export)
            try data.write(to: exportURL)
            print("📤 Exported feedback data to: \(exportURL.lastPathComponent)")
            return exportURL
        } catch {
            print("❌ Failed to export feedback: \(error)")
            return nil
        }
    }

    /// Clear an unknown question (after adding it to knowledge base)
    func clearUnknownQuestion(_ question: UnknownQuestion) {
        unknownQuestions.removeAll { $0.id == question.id }
        saveUnknownQuestions()
        syncToiCloud()
    }

    /// Clear all unknown questions
    func clearAllUnknownQuestions() {
        unknownQuestions.removeAll()
        saveUnknownQuestions()
        syncToiCloud()
    }

    /// Force sync with iCloud
    func forceSync() {
        syncToiCloud()
        loadFromiCloud()
    }

    // MARK: - Private Helpers

    private func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private func extractKeywords(from question: String) -> [String] {
        let stopWords = Set(["what", "how", "do", "i", "my", "the", "a", "an", "is", "are", "to", "for", "on", "in", "with", "can", "should", "when", "where", "why"])

        let words = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return Array(Set(words))
    }

    private func createFeedbackDirectory() {
        try? FileManager.default.createDirectory(at: feedbackDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Local Persistence

    private var unknownQuestionsFile: URL {
        feedbackDirectory.appendingPathComponent("unknown_questions.json")
    }

    private var correctionsFile: URL {
        feedbackDirectory.appendingPathComponent("corrections.json")
    }

    private var customResponsesFile: URL {
        feedbackDirectory.appendingPathComponent("custom_responses.json")
    }

    private var ratingsFile: URL {
        feedbackDirectory.appendingPathComponent("ratings.json")
    }

    private func loadAllData() {
        loadUnknownQuestions()
        loadCorrections()
        loadCustomResponses()
        loadRatings()
    }

    private func loadUnknownQuestions() {
        guard let data = try? Data(contentsOf: unknownQuestionsFile),
              let loaded = try? JSONDecoder().decode([UnknownQuestion].self, from: data) else {
            return
        }
        unknownQuestions = loaded
    }

    private func saveUnknownQuestions() {
        guard let data = try? JSONEncoder().encode(unknownQuestions) else { return }
        try? data.write(to: unknownQuestionsFile)
    }

    private func loadCorrections() {
        guard let data = try? Data(contentsOf: correctionsFile),
              let loaded = try? JSONDecoder().decode([CaddieCorrection].self, from: data) else {
            return
        }
        pendingCorrections = loaded
    }

    private func saveCorrections() {
        guard let data = try? JSONEncoder().encode(pendingCorrections) else { return }
        try? data.write(to: correctionsFile)
    }

    private func loadCustomResponses() {
        guard let data = try? Data(contentsOf: customResponsesFile),
              let loaded = try? JSONDecoder().decode([CustomResponse].self, from: data) else {
            return
        }
        customResponses = loaded
    }

    private func saveCustomResponses() {
        guard let data = try? JSONEncoder().encode(customResponses) else { return }
        try? data.write(to: customResponsesFile)
    }

    private func loadRatings() {
        guard let data = try? Data(contentsOf: ratingsFile),
              let loaded = try? JSONDecoder().decode([ResponseRating].self, from: data) else {
            return
        }
        ratings = loaded
    }

    private func saveRatings() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        try? data.write(to: ratingsFile)
    }
}

// MARK: - Data Models

struct UnknownQuestion: Codable, Identifiable {
    let id: UUID
    let question: String
    let firstAsked: Date
    var lastAsked: Date
    var askCount: Int
    var deviceId: String = "unknown"
}

struct CaddieCorrection: Codable, Identifiable {
    let id: UUID
    let question: String
    let wrongResponse: String
    let correctAnswer: String
    let submittedAt: Date
    var approved: Bool
    var deviceId: String = "unknown"
}

struct CustomResponse: Codable, Identifiable {
    let id: UUID
    let triggers: [String]
    let response: String
    let source: String
    let addedAt: Date
}

struct ResponseRating: Codable, Identifiable {
    let id: UUID
    let question: String
    let responsePreview: String
    let helpful: Bool
    let timestamp: Date
    var deviceId: String = "unknown"
}

struct CaddieStats {
    let unknownQuestionsCount: Int
    let pendingCorrectionsCount: Int
    let customResponsesCount: Int
    let totalRatings: Int
    let helpfulPercentage: Double
    let topUnknownQuestions: [String]
}

struct CaddieFeedbackExport: Codable {
    let exportDate: Date
    let unknownQuestions: [UnknownQuestion]
    let corrections: [CaddieCorrection]
    let customResponses: [CustomResponse]
    let ratings: [ResponseRating]
}
