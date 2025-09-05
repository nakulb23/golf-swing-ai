import SwiftUI
import Foundation

  struct CaddieChatView: View {
      @State private var messageText = ""
      @State private var messages: [ChatMessage] = []
      @StateObject private var dynamicAI = DynamicGolfAI.shared
      @State private var isLoading = false

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
                          
                          Text("Enhanced Local Golf Expert")
                              .font(.caption2)
                              .foregroundColor(.secondary)
                              .opacity(0.8)
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
                  text: "Welcome to CaddieChat Pro! 🏌️\n\nI'm your AI golf expert with dynamic conversational abilities and memory. I can help with any golf question - from 'What is a chip shot?' to complex course strategy.\n\nI remember our conversation, learn your preferences, and provide personalized guidance. Everything runs locally on your device for instant responses.\n\nWhat would you like to know about golf?",
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

          // Use new Dynamic Golf AI system
          Task {
              do {
                  print("🤖 Processing with Dynamic Golf AI: \(userMessage)")
                  let response = try await dynamicAI.sendMessage(userMessage)
                  print("✅ Dynamic AI response: \(response.message)")
                  
                  await MainActor.run {
                      let botMsg = ChatMessage(
                          text: response.message,
                          isUser: false,
                          timestamp: Date()
                      )
                      messages.append(botMsg)
                      isLoading = false
                      
                      SimpleAnalytics.shared.trackEvent("dynamic_ai_chat", properties: [
                          "message_length": userMessage.count,
                          "intent": response.intent,
                          "confidence": response.confidence
                      ])
                  }
              } catch {
                  print("❌ Dynamic AI error: \(error)")
                  await MainActor.run {
                      let errorMsg = ChatMessage(
                          text: "I'm here to help with your golf questions! It looks like I had a brief technical hiccup. Please try asking again, and I'll provide you with expert golf guidance.",
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
