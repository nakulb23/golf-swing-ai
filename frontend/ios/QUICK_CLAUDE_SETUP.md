# Quick Claude Setup Guide

## 🚀 Fast Orientation for New Sessions

### Project Summary
iOS golf app with intelligent AI chat system for golf coaching and swing analysis.

### Key Files to Know
- `DynamicGolfAI.swift` - Main conversational AI system
- `CaddieChatView.swift` - Chat interface
- `API Service.swift` - Local processing service
- `HomeView.swift` - Main dashboard with navigation

### Recent Major Update ✅
**Replaced hardcoded chat responses with intelligent DynamicGolfAI**
- Fixed duplicate welcome messages
- Added contextual conversation memory
- Implemented specific golf advice responses
- Thread-safe with @MainActor

### Quick Commands
```bash
# Build check (if Xcode available)
cd "/path/to/Golf Swing AI/frontend/ios"
xcodebuild -scheme "Golf Swing AI" build

# Git status
git status
git log --oneline -5
```

### Common Tasks

#### Chat System Issues
- **File**: `DynamicGolfAI.swift` 
- **Method**: `DynamicResponseGenerator.generateResponse()`
- **Test**: "How do I fix my driver from slicing?"

#### UI Issues
- **File**: `CaddieChatView.swift`
- **Navigation**: HomeView buttons use tab switching (not NavigationLinks)
- **Messages**: Single welcome message in `onAppear`

#### Build Errors
- Add missing `ChatIntent` cases to switch statements
- Ensure `@MainActor` on AI classes for thread safety
- Check enum completeness in `LocalCaddieChat.swift`

### Architecture Quick Reference
```
User Input → CaddieChatView → DynamicGolfAI → ContextualAnalyzer → DynamicResponseGenerator → Response
```

### Test Scenarios
1. Driver slice question → Specific advice
2. Club selection → Distance-based recommendations  
3. Follow-up questions → Context awareness
4. Tab navigation → No duplicate messages

### Debug Logs to Watch
- "🤖 Processing:" - Message received
- "✅ Enhanced AI response:" - Response generated
- "🔍 CaddieChatView appeared" - UI lifecycle

---
*For detailed information, see CLAUDE_INSTRUCTIONS.md*