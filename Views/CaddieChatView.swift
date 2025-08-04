import SwiftUI
import Foundation

  struct CaddieChatView: View {
      @State private var messageText = ""
      @State private var messages: [ChatMessage] = []
      @StateObject private var apiService = APIService.shared
      @State private var isLoading = false

      var body: some View {
          NavigationView {
              ZStack {
                  Color(UIColor.systemBackground).ignoresSafeArea()
                  
                  VStack(spacing: 0) {
                      // Chat Header
                      VStack(spacing: 16) {
                          Image(systemName: "message.circle.fill")
                              .font(.system(size: 48, weight: .light))
                              .foregroundColor(.green)
                          
                          Text("CaddieChat Pro")
                              .font(.largeTitle)
                              .fontWeight(.bold)
                              .foregroundColor(.green)
                          
                          Text("Premium AI golf expert with comprehensive analysis")
                              .font(.subheadline)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                      }
                      .padding(.vertical, 20)
                      .padding(.horizontal)
                      
                      // Messages ScrollView
                      ScrollView {
                          LazyVStack(spacing: 16) {
                              // Show premium suggestions when empty
                              if messages.count <= 1 {
                                  PremiumSuggestions { suggestion in
                                      messageText = suggestion
                                      sendMessage()
                                  }
                              }
                              
                              ForEach(messages) { message in
                                  ChatBubble(message: message)
                              }
                          }
                          .padding(.horizontal)
                          .padding(.bottom, 20)
                      }
                      
                      // Message Input
                      VStack(spacing: 12) {
                          Divider()
                              .background(Color.secondary.opacity(0.3))
                          
                          HStack(spacing: 12) {
                              TextField("Ask me anything about golf...", text: $messageText)
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
                                  .background(
                                      Circle()
                                          .fill(
                                              (messageText.isEmpty || isLoading)
                                              ? LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                              : LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          )
                                  )
                                  .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                              }
                              .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                          }
                          .padding(.horizontal)
                          .padding(.bottom, 8)
                      }
                  }
              }
              .navigationTitle("CaddieChat Pro")
              .navigationBarTitleDisplayMode(.inline)
              .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
              .toolbar {
                  ToolbarItem(placement: .navigationBarTrailing) {
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
              .onAppear {
                  addWelcomeMessage()
              }
          }
      }

      private func addWelcomeMessage() {
          if messages.isEmpty {
              let welcome = ChatMessage(
                  text: "🏌️ Welcome to CaddieChat Pro! I'm your premium AI golf expert with comprehensive knowledge.\n\n✨ **I can help with:**\n• Swing analysis & technique fixes\n• Launch monitor data interpretation\n• Practice routines & drills\n• Course strategy & mental game\n• Equipment fitting & club selection\n• Statistics & improvement tracking\n\nTry asking: \"What's wrong with my swing if I keep slicing?\" or \"What's a good practice routine for an 18 handicapper?\"",
                  isUser: false,
                  timestamp: Date()
              )
              messages.append(welcome)
          }
      }

      private func sendMessage() {
          guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
          
          let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
          let userMsg = ChatMessage(
              text: userMessage,
              isUser: true,
              timestamp: Date()
          )
          messages.append(userMsg)
          messageText = ""
          isLoading = true

          // Send message to custom API
          Task {
              do {
                  print("🔄 Sending chat message: \(userMessage)")
                  let response = try await apiService.sendChatMessage(userMessage)
                  print("✅ Received chat response: \(response.answer)")
                  
                  await MainActor.run {
                      let botMsg = ChatMessage(
                          text: response.answer,
                          isUser: false,
                          timestamp: Date()
                      )
                      messages.append(botMsg)
                      isLoading = false
                      
                      SimpleAnalytics.shared.trackEvent("chat_message_sent", properties: [
                          "message_length": userMessage.count
                      ])
                  }
              } catch {
                  print("❌ Chat error: \(error)")
                  await MainActor.run {
                      let errorMsg = ChatMessage(
                          text: "Sorry, I'm having trouble connecting right now. Please try again later.\n\nError: \(error.localizedDescription)",
                          isUser: false,
                          timestamp: Date()
                      )
                      messages.append(errorMsg)
                      isLoading = false
                  }
              }
          }
      }
  }

  struct ChatMessage: Identifiable {
      let id = UUID()
      let text: String
      let isUser: Bool
      let timestamp: Date
  }

  struct ChatBubble: View {
      let message: ChatMessage
      
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
                      Text(parseMarkdown(message.text))
                          .font(.body)
                          .foregroundColor(.primary)
                          .padding(.horizontal, 16)
                          .padding(.vertical, 12)
                          .background(
                              RoundedRectangle(cornerRadius: 18)
                                  .fill(Color(UIColor.secondarySystemBackground))
                                  .overlay(
                                      RoundedRectangle(cornerRadius: 18)
                                          .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                  )
                          )
                      
                      Text(DateFormatter.timeFormatter.string(from: message.timestamp))
                          .font(.caption2)
                          .foregroundColor(.secondary)
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

  extension DateFormatter {
      static let timeFormatter: DateFormatter = {
          let formatter = DateFormatter()
          formatter.timeStyle = .short
          return formatter
      }()
  }

  // MARK: - Premium Suggestions Component
  struct PremiumSuggestions: View {
      let onSuggestionTap: (String) -> Void
      
      private let premiumQuestions = [
          ("🏌️ Swing Analysis", "What's wrong with my swing if I keep slicing the ball?"),
          ("📊 Launch Monitor", "What do my launch monitor numbers mean?"),
          ("📅 Practice Plan", "What's a good weekly practice routine for an 18 handicapper?"),
          ("🏋️ Fitness", "What stretches help improve my shoulder turn?"),
          ("🧠 Mental Game", "How can I stay mentally focused after a bad hole?"),
          ("🛠️ Equipment", "Should I get fitted for clubs or buy off the rack?"),
          ("🎯 Club Selection", "What club should I use for a 150-yard shot into the wind?"),
          ("📈 Stats", "How can I lower my handicap using my stats?")
      ]
      
      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              Text("✨ Try These Premium Questions")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(.primary)
                  .padding(.horizontal, 4)
              
              LazyVGrid(columns: [
                  GridItem(.flexible()),
                  GridItem(.flexible())
              ], spacing: 12) {
                  ForEach(Array(premiumQuestions.enumerated()), id: \.offset) { index, question in
                      Button(action: {
                          onSuggestionTap(question.1)
                      }) {
                          VStack(alignment: .leading, spacing: 8) {
                              Text(question.0)
                                  .font(.caption)
                                  .fontWeight(.semibold)
                                  .foregroundColor(.green)
                              
                              Text(question.1)
                                  .font(.caption2)
                                  .foregroundColor(.secondary)
                                  .multilineTextAlignment(.leading)
                                  .lineLimit(2)
                          }
                          .frame(maxWidth: .infinity, alignment: .leading)
                          .padding(12)
                          .background(
                              RoundedRectangle(cornerRadius: 12)
                                  .fill(Color(UIColor.secondarySystemBackground))
                                  .overlay(
                                      RoundedRectangle(cornerRadius: 12)
                                          .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                  )
                          )
                      }
                      .buttonStyle(PlainButtonStyle())
                  }
              }
              
              Text("💡 Ask me anything about golf - I have expert knowledge on all aspects of the game!")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .padding(.horizontal, 4)
                  .padding(.top, 8)
          }
          .padding(.vertical, 16)
      }
  }

  #Preview {
      CaddieChatView()
          .environmentObject(AuthenticationManager())
  }
