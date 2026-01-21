import Foundation

/// Manages chat conversation persistence - local storage only
/// Follows pattern from CaddieFeedbackManager
@MainActor
class ChatHistoryManager: ObservableObject {
    static let shared = ChatHistoryManager()

    @Published var conversations: [ChatConversation] = []
    @Published var activeConversationId: UUID?

    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    private var chatHistoryDirectory: URL {
        documentsDirectory.appendingPathComponent("ChatHistory")
    }

    private init() {
        createHistoryDirectory()
        print("📚 ChatHistoryManager initialized")
    }

    // MARK: - Directory Setup
    private func createHistoryDirectory() {
        do {
            try FileManager.default.createDirectory(at: chatHistoryDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create ChatHistory directory: \(error)")
        }
    }

    // MARK: - User-Specific File Path
    private func conversationsFile(for userId: UUID) -> URL {
        chatHistoryDirectory.appendingPathComponent("conversations_\(userId.uuidString).json")
    }

    // MARK: - Load Conversations for User
    func loadConversations(for userId: UUID) {
        let fileURL = conversationsFile(for: userId)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            conversations = []
            print("📚 No existing conversations for user")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([ChatConversation].self, from: data)
            conversations = loaded.sorted { $0.lastMessageAt > $1.lastMessageAt }
            print("📚 Loaded \(conversations.count) conversations for user")
        } catch {
            print("❌ Failed to load conversations: \(error)")
            conversations = []
        }
    }

    // MARK: - Save Conversations
    private func saveConversations(for userId: UUID) {
        let fileURL = conversationsFile(for: userId)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(conversations)
            try data.write(to: fileURL)
            print("💾 Saved \(conversations.count) conversations")
        } catch {
            print("❌ Failed to save conversations: \(error)")
        }
    }

    // MARK: - Create New Conversation
    @discardableResult
    func createNewConversation(for userId: UUID) -> ChatConversation {
        let conversation = ChatConversation(userId: userId)
        conversations.insert(conversation, at: 0)
        activeConversationId = conversation.id
        saveConversations(for: userId)
        print("📝 Created new conversation: \(conversation.id)")
        return conversation
    }

    // MARK: - Get Active Conversation
    func getActiveConversation() -> ChatConversation? {
        guard let activeId = activeConversationId else { return nil }
        return conversations.first { $0.id == activeId }
    }

    // MARK: - Set Active Conversation
    func setActiveConversation(_ conversationId: UUID) {
        activeConversationId = conversationId
    }

    // MARK: - Add Message to Active Conversation
    func addMessage(text: String, isUser: Bool, timestamp: Date, userQuestion: String?, userId: UUID) {
        guard let activeId = activeConversationId,
              let index = conversations.firstIndex(where: { $0.id == activeId }) else {
            print("⚠️ No active conversation to add message to")
            return
        }

        let message = PersistentChatMessage(
            text: text,
            isUser: isUser,
            timestamp: timestamp,
            userQuestion: userQuestion
        )

        conversations[index].messages.append(message)
        conversations[index].lastMessageAt = Date()

        // Update title if this is the first user message
        if conversations[index].messages.filter({ $0.isUser }).count == 1 && isUser {
            conversations[index].updateTitleFromFirstMessage()
        }

        // Move to top of list
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)

        saveConversations(for: userId)
    }

    // MARK: - Update Message Feedback
    func updateMessageFeedback(messageId: UUID, helpful: Bool, userId: UUID) {
        guard let activeId = activeConversationId,
              let convIndex = conversations.firstIndex(where: { $0.id == activeId }),
              let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        conversations[convIndex].messages[msgIndex].feedbackGiven = helpful ? .helpful : .unhelpful
        saveConversations(for: userId)
    }

    // MARK: - Delete Conversation
    func deleteConversation(_ conversationId: UUID, userId: UUID) {
        conversations.removeAll { $0.id == conversationId }

        if activeConversationId == conversationId {
            activeConversationId = conversations.first?.id
        }

        saveConversations(for: userId)
        print("🗑️ Deleted conversation: \(conversationId)")
    }

    // MARK: - Search Conversations
    func searchConversations(query: String) -> [ChatConversation] {
        guard !query.isEmpty else { return conversations }
        return conversations.filter { $0.matchesSearch(query) }
    }

    // MARK: - Clear All (for logout)
    func clearUserData() {
        conversations = []
        activeConversationId = nil
        print("🧹 Cleared chat history from memory")
    }

    // MARK: - Get Conversation by ID
    func getConversation(by id: UUID) -> ChatConversation? {
        return conversations.first { $0.id == id }
    }

    // MARK: - Get Messages for Active Conversation
    func getActiveMessages() -> [PersistentChatMessage] {
        return getActiveConversation()?.messages ?? []
    }
}
