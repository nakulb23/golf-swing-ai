import SwiftUI

/// Browseable list of past chat conversations
struct ChatHistoryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var historyManager: ChatHistoryManager
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: UUID?

    var onSelectConversation: (ChatConversation) -> Void
    var onNewConversation: () -> Void
    var onDismiss: () -> Void

    private var filteredConversations: [ChatConversation] {
        historyManager.searchConversations(query: searchText)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Conversations List
                if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onNewConversation()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .alert("Delete Conversation?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = conversationToDelete, let userId = authManager.currentUser?.id {
                    historyManager.deleteConversation(id, userId: userId)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search conversations...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "No Conversations Yet" : "No Results")
                .font(.headline)
                .foregroundColor(.primary)

            Text(searchText.isEmpty ?
                 "Start a new chat with your AI caddie" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button(action: {
                    onNewConversation()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Conversation")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Conversations List
    private var conversationsList: some View {
        List {
            ForEach(filteredConversations) { conversation in
                ConversationRow(conversation: conversation)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectConversation(conversation)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            conversationToDelete = conversation.id
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: ChatConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(relativeDate(from: conversation.lastMessageAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let lastMessage = conversation.messages.last {
                HStack(spacing: 6) {
                    Image(systemName: lastMessage.isUser ? "person.fill" : "figure.golf")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            HStack {
                Label("\(conversation.messageCount)", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ChatHistoryView(
        historyManager: ChatHistoryManager.shared,
        onSelectConversation: { _ in },
        onNewConversation: { },
        onDismiss: { }
    )
    .environmentObject(AuthenticationManager())
}
