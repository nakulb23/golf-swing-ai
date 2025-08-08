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
                      // Messages ScrollView
                      ScrollView {
                          LazyVStack(spacing: 16) {
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
              .toolbar {
                  ToolbarItem(placement: .principal) {
                      HStack(spacing: 8) {
                          Image(systemName: "figure.golf")
                              .font(.system(size: 16, weight: .medium))
                              .foregroundColor(.green)
                          
                          Text("CaddieChat Pro")
                              .font(.headline)
                              .fontWeight(.semibold)
                      }
                  }
              }
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
                  text: "I'm your AI golf expert. Ask me anything about your game.",
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


  #Preview {
      CaddieChatView()
          .environmentObject(AuthenticationManager())
  }
