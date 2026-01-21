import Foundation

// MARK: - Persistent Chat Message
/// Codable version of ChatMessage for persistence
struct PersistentChatMessage: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var userQuestion: String?  // For bot responses, tracks what question triggered it
    var feedbackGiven: FeedbackType?

    enum FeedbackType: String, Codable, Sendable {
        case helpful, unhelpful
    }

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date, userQuestion: String? = nil, feedbackGiven: FeedbackType? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.userQuestion = userQuestion
        self.feedbackGiven = feedbackGiven
    }
}

// MARK: - Chat Conversation (Thread)
struct ChatConversation: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let userId: UUID  // Associates conversation with authenticated user
    var title: String  // Auto-generated from first user message or "New Conversation"
    var messages: [PersistentChatMessage]
    let createdAt: Date
    var lastMessageAt: Date

    var messageCount: Int { messages.count }

    init(userId: UUID, title: String = "New Conversation") {
        self.id = UUID()
        self.userId = userId
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.lastMessageAt = Date()
    }

    // Generate title from first user message
    mutating func updateTitleFromFirstMessage() {
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let trimmed = firstUserMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
            title = String(trimmed.prefix(50))
            if trimmed.count > 50 {
                title += "..."
            }
        }
    }

    // Check if conversation matches search query
    func matchesSearch(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        if title.lowercased().contains(lowercased) {
            return true
        }
        return messages.contains { $0.text.lowercased().contains(lowercased) }
    }
}
