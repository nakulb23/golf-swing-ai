import SwiftUI
import Foundation

struct CaddieChatView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @StateObject private var chatEngine = CaddieChatEngine.shared
    @StateObject private var historyManager = ChatHistoryManager.shared
    @State private var isLoading = false
    @State private var showingHistory = false
    @State private var selectedConversation: ChatConversation?

      private var buttonBackgroundGradient: some View {
          let isDisabled = messageText.isEmpty || isLoading
          let colors = isDisabled
              ? [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
              : [Color.green, Color.mint]

          return Circle()
              .fill(LinearGradient(
                  colors: colors,
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              ))
      }

      var body: some View {
          NavigationView {
              ZStack {
                  Color(UIColor.systemBackground).ignoresSafeArea()

                  if chatEngine.isLoading {
                      // Loading state - show immediately while model loads in background
                      VStack(spacing: 20) {
                          ProgressView()
                              .scaleEffect(1.5)
                              .progressViewStyle(CircularProgressViewStyle(tint: .green))

                          Text("Loading AI Caddie...")
                              .font(.headline)
                              .foregroundColor(.primary)

                          Text("Preparing golf knowledge base")
                              .font(.subheadline)
                              .foregroundColor(.secondary)
                      }
                  } else {
                      chatInterface
                  }
              }
              .navigationTitle("CaddieChat Pro")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .principal) {
                      VStack(spacing: 2) {
                          HStack(spacing: 8) {
                              Image(systemName: "figure.golf")
                                  .font(.system(size: 16, weight: .medium))
                                  .foregroundColor(.green)

                              Text("CaddieChat Pro")
                                  .font(.headline)
                                  .fontWeight(.semibold)
                          }

                          Text(chatEngine.isReady ? "Powered by Qwen2.5" : "Loading AI...")
                              .font(.caption2)
                              .foregroundColor(.secondary)
                              .opacity(0.8)
                      }
                  }
              }
              .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
              .toolbar {
                  // History button (only when authenticated)
                  ToolbarItem(placement: .navigationBarLeading) {
                      if authManager.isAuthenticated {
                          Button(action: { showingHistory = true }) {
                              Image(systemName: "clock.arrow.circlepath")
                                  .foregroundColor(.green)
                                  .font(.system(size: 16, weight: .medium))
                          }
                      }
                  }

                  ToolbarItem(placement: .navigationBarTrailing) {
                      HStack(spacing: 12) {
                          // New conversation button (only when authenticated)
                          if authManager.isAuthenticated {
                              Button(action: startNewConversation) {
                                  Image(systemName: "square.and.pencil")
                                      .foregroundColor(.green)
                                      .font(.system(size: 16, weight: .medium))
                              }
                          }

                          Button(action: {
                              // Switch to Home tab
                              NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                          }) {
                              Image(systemName: "xmark")
                                  .foregroundColor(.gray)
                                  .font(.system(size: 16, weight: .medium))
                          }
                      }
                  }
              }
          }
          .sheet(isPresented: $showingHistory) {
              ChatHistoryView(
                  historyManager: historyManager,
                  onSelectConversation: { conversation in
                      selectConversation(conversation)
                      showingHistory = false
                  },
                  onNewConversation: {
                      startNewConversation()
                      showingHistory = false
                  },
                  onDismiss: {
                      showingHistory = false
                  }
              )
              .environmentObject(authManager)
          }
          .onChange(of: selectedConversation) { _, newConversation in
              if let conv = newConversation {
                  loadConversationMessages(conv)
              }
          }
          .task {
              // Load chat history if authenticated
              if let userId = authManager.currentUser?.id {
                  historyManager.loadConversations(for: userId)

                  // Load existing active conversation or create new one
                  if let activeConv = historyManager.getActiveConversation() {
                      loadConversationMessages(activeConv)
                  } else if historyManager.conversations.isEmpty {
                      // Create first conversation
                      let newConv = historyManager.createNewConversation(for: userId)
                      addWelcomeMessage()
                      selectedConversation = newConv
                  } else {
                      // Select the most recent conversation
                      if let firstConv = historyManager.conversations.first {
                          historyManager.setActiveConversation(firstConv.id)
                          loadConversationMessages(firstConv)
                      }
                  }
              } else {
                  // Not authenticated - just show welcome message
                  addWelcomeMessage()
              }

              // Initialize CaddieChat engine in background (loads model + knowledge pack)
              await chatEngine.initialize()
          }
      }

      // MARK: - Conversation Management
      private func addWelcomeMessage() {
          if messages.isEmpty {
              let welcome = ChatMessage(
                  text: "Welcome to CaddieChat Pro! I'm your AI golf caddie powered by Qwen2.5 with a golf knowledge base. Ask me about swing tips, rules, equipment, strategy, or anything golf-related!",
                  isUser: false,
                  timestamp: Date()
              )
              messages.append(welcome)
          }
      }

      private func loadConversationMessages(_ conversation: ChatConversation) {
          // Convert persistent messages to ChatMessage, preserving IDs
          messages = conversation.messages.map { persistent in
              var feedbackType: ChatMessage.FeedbackType? = nil
              if let feedback = persistent.feedbackGiven {
                  feedbackType = feedback == .helpful ? .helpful : .unhelpful
              }
              return ChatMessage(
                  id: persistent.id,  // Preserve ID for feedback tracking
                  text: persistent.text,
                  isUser: persistent.isUser,
                  timestamp: persistent.timestamp,
                  userQuestion: persistent.userQuestion,
                  feedbackGiven: feedbackType
              )
          }

          // Add welcome message if conversation is empty
          if messages.isEmpty {
              addWelcomeMessage()
          }
      }

      private func startNewConversation() {
          guard let userId = authManager.currentUser?.id else { return }
          let newConv = historyManager.createNewConversation(for: userId)
          messages = []
          addWelcomeMessage()
          selectedConversation = newConv
      }

      private func selectConversation(_ conversation: ChatConversation) {
          historyManager.setActiveConversation(conversation.id)
          selectedConversation = conversation
      }

      // MARK: - Chat Interface
      private var chatInterface: some View {
          VStack(spacing: 0) {
              // Messages ScrollView with ScrollViewReader for auto-scroll
              ScrollViewReader { proxy in
                  ScrollView {
                      LazyVStack(spacing: 16) {
                          ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                              ChatBubble(message: message) { helpful in
                                  handleFeedback(for: index, helpful: helpful)
                              }
                              .id(message.id)
                          }

                          // Streaming bubble: shows live LLM output while generating
                          if chatEngine.isStreaming && !chatEngine.streamingOutput.isEmpty {
                              StreamingChatBubble(text: chatEngine.streamingOutput)
                                  .id("streaming_bubble")
                                  .transition(.opacity)
                          } else if chatEngine.isStreaming {
                              // Show a typing indicator before first token arrives
                              TypingIndicatorBubble()
                                  .id("typing_bubble")
                                  .transition(.opacity)
                          }
                      }
                      .padding(.horizontal)
                      .padding(.bottom, 20)
                      .padding(.top, 20)
                  }
                  .onChange(of: messages.count) { _, _ in
                      if let lastMessage = messages.last {
                          withAnimation(.easeOut(duration: 0.3)) {
                              proxy.scrollTo(lastMessage.id, anchor: .bottom)
                          }
                      }
                  }
                  .onChange(of: chatEngine.streamingOutput) { _, newOutput in
                      // Scroll to streaming bubble as tokens arrive
                      if !newOutput.isEmpty {
                          proxy.scrollTo("streaming_bubble", anchor: .bottom)
                      }
                  }
                  .onChange(of: chatEngine.isStreaming) { _, streaming in
                      if streaming {
                          withAnimation(.easeOut(duration: 0.2)) {
                              proxy.scrollTo("typing_bubble", anchor: .bottom)
                          }
                      }
                  }
              }

              // Message Input
              VStack(spacing: 12) {
                  Divider()
                      .background(Color.secondary.opacity(0.3))

                  // Streaming status bar — visible only while LLM is generating
                  if chatEngine.isStreaming {
                      HStack(spacing: 6) {
                          ProgressView()
                              .scaleEffect(0.65)
                              .progressViewStyle(CircularProgressViewStyle(tint: .green))
                          Text("CaddieChat is thinking…")
                              .font(.caption)
                              .foregroundColor(.secondary)
                          Spacer()
                      }
                      .padding(.horizontal)
                      .transition(.opacity)
                  }

                  HStack(spacing: 12) {
                      TextField("Ask about your swing, strategy, equipment...", text: $messageText)
                          .textFieldStyle(RoundedBorderTextFieldStyle())

                      Button(action: sendMessage) {
                          Group {
                              if isLoading {
                                  ProgressView()
                                      .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                      .scaleEffect(0.8)
                              } else {
                                  Image(systemName: "paperplane.fill")
                                      .font(.system(size: 18, weight: .semibold))
                              }
                          }
                          .foregroundColor(.white)
                          .frame(width: 44, height: 44)
                          .background(buttonBackgroundGradient)
                          .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                      }
                      .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                  }
                  .padding(.horizontal)
                  .padding(.bottom, 8)
              }
          }
      }

      // MARK: - Feedback Handler
      private func handleFeedback(for index: Int, helpful: Bool) {
          guard index < messages.count else { return }

          let message = messages[index]
          guard !message.isUser, let question = message.userQuestion else { return }

          // Record feedback using CaddieFeedbackManager
          CaddieFeedbackManager.shared.recordRating(question: question, response: message.text, helpful: helpful)

          // Update UI
          withAnimation(.easeOut(duration: 0.2)) {
              messages[index].feedbackGiven = helpful ? .helpful : .unhelpful
          }

          // Persist feedback to chat history (if authenticated)
          if let userId = authManager.currentUser?.id {
              historyManager.updateMessageFeedback(messageId: message.id, helpful: helpful, userId: userId)
          }

          // If unhelpful, could prompt for correction (future enhancement)
          if !helpful {
              print("👎 User marked response as unhelpful for: \(question)")
          }
      }

      // MARK: - Send Message
      private func sendMessage() {
          guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

          let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
          let userTimestamp = Date()
          let userMsg = ChatMessage(
              text: userMessage,
              isUser: true,
              timestamp: userTimestamp
          )

          // Animate user message appearing
          withAnimation(.easeOut(duration: 0.25)) {
              messages.append(userMsg)
          }

          // Persist user message (if authenticated)
          if let userId = authManager.currentUser?.id {
              historyManager.addMessage(
                  text: userMessage,
                  isUser: true,
                  timestamp: userTimestamp,
                  userQuestion: nil,
                  userId: userId
              )
          }

          messageText = ""
          isLoading = true

          // Use CaddieChatEngine with RAG for intelligent golf advice
          Task {
              print("🤖 Processing with CaddieChatEngine: \(userMessage)")

              // Get response from RAG-powered engine
              let response = await chatEngine.chat(userMessage)
              print("✅ Response (\(response.intent.rawValue)): \(response.message.prefix(100))...")

              await MainActor.run {
                  let botTimestamp = Date()
                  var botMsg = ChatMessage(
                      text: response.message,
                      isUser: false,
                      timestamp: botTimestamp
                  )
                  botMsg.userQuestion = userMessage  // Track what question generated this response

                  // Animate bot response appearing
                  withAnimation(.easeOut(duration: 0.25)) {
                      messages.append(botMsg)
                  }

                  // Persist bot response (if authenticated)
                  if let userId = authManager.currentUser?.id {
                      historyManager.addMessage(
                          text: response.message,
                          isUser: false,
                          timestamp: botTimestamp,
                          userQuestion: userMessage,
                          userId: userId
                      )
                  }

                  isLoading = false

                  SimpleAnalytics.shared.trackEvent("caddie_chat", properties: [
                      "message_length": userMessage.count,
                      "intent": response.intent.rawValue,
                      "sources_count": response.sources.count,
                      "system": "caddie_rag"
                  ])
              }
          }
      }
  }


  struct ChatMessage: Identifiable {
      let id: UUID
      let text: String
      let isUser: Bool
      let timestamp: Date
      var userQuestion: String? = nil  // For bot responses, track what question triggered it
      var feedbackGiven: FeedbackType? = nil

      enum FeedbackType {
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

  struct ChatBubble: View {
      let message: ChatMessage
      var onFeedback: ((Bool) -> Void)? = nil

      var body: some View {
          HStack {
              if message.isUser {
                  Spacer()

                  VStack(alignment: .trailing, spacing: 4) {
                      Text(message.text)
                          .font(.body)
                          .foregroundColor(.white)
                          .padding(.horizontal, 16)
                          .padding(.vertical, 12)
                          .background(
                              RoundedRectangle(cornerRadius: 18)
                                  .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                          )

                      Text(DateFormatter.timeFormatter.string(from: message.timestamp))
                          .font(.caption2)
                          .foregroundColor(.secondary)
                  }
              } else {
                  VStack(alignment: .leading, spacing: 4) {
                      PremiumChatBubble(text: message.text)

                      HStack(spacing: 12) {
                          Text(DateFormatter.timeFormatter.string(from: message.timestamp))
                              .font(.caption2)
                              .foregroundColor(.secondary)

                          Spacer()

                          // Feedback buttons (only show if no feedback given yet)
                          if message.feedbackGiven == nil, let onFeedback = onFeedback {
                              HStack(spacing: 8) {
                                  Button(action: { onFeedback(true) }) {
                                      Image(systemName: "hand.thumbsup")
                                          .font(.system(size: 14))
                                          .foregroundColor(.secondary)
                                  }

                                  Button(action: { onFeedback(false) }) {
                                      Image(systemName: "hand.thumbsdown")
                                          .font(.system(size: 14))
                                          .foregroundColor(.secondary)
                                  }
                              }
                          } else if let feedback = message.feedbackGiven {
                              Image(systemName: feedback == .helpful ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                  .font(.system(size: 14))
                                  .foregroundColor(feedback == .helpful ? .green : .orange)
                          }
                      }
                  }

                  Spacer()
              }
          }
      }
      
      // MARK: - Helper Functions
      private func parseMarkdown(_ text: String) -> AttributedString {
          do {
              return try AttributedString(markdown: text)
          } catch {
              return AttributedString(text)
          }
      }
  }

  // MARK: - Premium Chat Bubble
  
  struct PremiumChatBubble: View {
      let text: String
      
      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              ForEach(parsedSections, id: \.title) { section in
                  if section.title.isEmpty {
                      // Regular paragraph
                      Text(section.content)
                          .font(.body)
                          .foregroundColor(.primary)
                          .lineSpacing(2)
                  } else {
                      // Section with title
                      VStack(alignment: .leading, spacing: 8) {
                          HStack {
                              Text(section.title)
                                  .font(.system(size: 16, weight: .semibold))
                                  .foregroundColor(.green)
                              Spacer()
                          }
                          .padding(.bottom, 4)
                          
                          VStack(alignment: .leading, spacing: 6) {
                              ForEach(section.items, id: \.self) { item in
                                  HStack(alignment: .top, spacing: 8) {
                                      Circle()
                                          .fill(Color.green.opacity(0.7))
                                          .frame(width: 4, height: 4)
                                          .padding(.top, 8)
                                      
                                      Text(item)
                                          .font(.system(size: 14))
                                          .foregroundColor(.primary)
                                          .lineSpacing(1)
                                      
                                      Spacer()
                                  }
                              }
                          }
                      }
                  }
              }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(
              RoundedRectangle(cornerRadius: 18)
                  .fill(Color(UIColor.secondarySystemBackground))
                  .overlay(
                      RoundedRectangle(cornerRadius: 18)
                          .stroke(LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                  )
          )
      }
      
      private var parsedSections: [ChatSection] {
          let lines = text.components(separatedBy: .newlines)
          var sections: [ChatSection] = []
          var currentSection: ChatSection?
          
          for line in lines {
              let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
              
              if trimmedLine.isEmpty {
                  continue
              }
              
              // Check if it's a section header (contains :)
              if trimmedLine.contains(":") && !trimmedLine.hasPrefix("•") && !trimmedLine.hasPrefix("-") {
                  // Save previous section
                  if let section = currentSection {
                      sections.append(section)
                  }
                  
                  let parts = trimmedLine.components(separatedBy: ":")
                  let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                  let content = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                  
                  currentSection = ChatSection(title: title, content: content, items: content.isEmpty ? [] : [content])
              }
              // Check if it's a bullet point
              else if trimmedLine.hasPrefix("•") || trimmedLine.hasPrefix("-") {
                  let item = trimmedLine.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                  if currentSection != nil {
                      currentSection?.items.append(item)
                  } else {
                      // Create a new section for orphaned bullet points
                      if sections.isEmpty || !sections.last!.title.isEmpty {
                          currentSection = ChatSection(title: "", content: "", items: [item])
                      } else {
                          sections[sections.count - 1].items.append(item)
                      }
                  }
              }
              // Regular text
              else {
                  if currentSection != nil {
                      currentSection?.items.append(trimmedLine)
                  } else {
                      sections.append(ChatSection(title: "", content: trimmedLine, items: []))
                  }
              }
          }
          
          // Don't forget the last section
          if let section = currentSection {
              sections.append(section)
          }
          
          return sections
      }
  }
  
  struct ChatSection {
      let title: String
      var content: String
      var items: [String]
  }

  extension DateFormatter {
      static let timeFormatter: DateFormatter = {
          let formatter = DateFormatter()
          formatter.timeStyle = .short
          return formatter
      }()
  }

// MARK: - Streaming Chat Bubble
// Displayed while the LLM is generating tokens, updated progressively.

struct StreamingChatBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                // Live text — reuses the same styled container as PremiumChatBubble
                VStack(alignment: .leading, spacing: 0) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green.opacity(0.4), .mint.opacity(0.2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1)
                        )
                )

                // Subtle "generating" label
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.55)
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    Text("Generating…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 48)
        }
    }
}

// MARK: - Typing Indicator Bubble
// Three animated dots shown before the first streaming token arrives.

struct TypingIndicatorBubble: View {
    @State private var dotOpacity: [Double] = [1, 0.4, 0.1]

    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(dotOpacity[i]))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    dotOpacity = [dotOpacity[2], dotOpacity[0], dotOpacity[1]]
                }
            }

            Spacer(minLength: 48)
        }
    }
}

  #Preview {
      CaddieChatView()
          .environmentObject(AuthenticationManager())
  }
