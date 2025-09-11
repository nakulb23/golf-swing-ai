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
                          .padding(.top, 20)
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
          }
          .onAppear {
              print("🔍 CaddieChatView appeared - messages count: \\(messages.count)")
              if messages.isEmpty {
                  print("🔍 Adding welcome message")
                  let welcome = ChatMessage(
                      text: "Welcome to CaddieChat Pro! What golf challenge can I help you tackle today?",
                      isUser: false,
                      timestamp: Date()
                  )
                  messages.append(welcome)
              } else {
                  print("🔍 Messages already exist, not adding welcome")
              }
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

          // Use enhanced AI system with dynamic responses
          Task {
              do {
                  print("🤖 Processing with Enhanced Golf Chat: \(userMessage)")
                  
                  // Use the local dynamic AI for contextual responses
                  let response = try await dynamicAI.sendMessage(userMessage)
                  print("✅ Enhanced AI response: \(response.message)")
                  
                  await MainActor.run {
                      let botMsg = ChatMessage(
                          text: response.message,
                          isUser: false,
                          timestamp: Date()
                      )
                      messages.append(botMsg)
                      isLoading = false
                      
                      SimpleAnalytics.shared.trackEvent("enhanced_ai_chat", properties: [
                          "message_length": userMessage.count,
                          "intent": response.intent,
                          "confidence": response.confidence,
                          "model_used": "enhanced_chat"
                      ])
                  }
              } catch {
                  print("❌ Enhanced chat error: \(error)")
                  
                  // Simple fallback message if dynamic AI fails
                  await MainActor.run {
                      let botMsg = ChatMessage(
                          text: "I'm having trouble processing that right now. Please try asking your golf question again!",
                          isUser: false,
                          timestamp: Date()
                      )
                      messages.append(botMsg)
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
                      PremiumChatBubble(text: message.text)
                      
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


  #Preview {
      CaddieChatView()
          .environmentObject(AuthenticationManager())
  }
