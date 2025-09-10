# 🤖 Claude AI Assistant Instructions for Golf Swing AI Project

## 🚨 CRITICAL SAFETY RULES - READ FIRST!

**NEVER work directly on main branch. Use this workflow: feature → testing → main**

### Your Repository Structure:
- **main branch**: Production-ready, stable code only
- **testing branch**: https://github.com/nakulb23/golf-swing-ai/tree/testing - Staging area for tested features
- **feature branches**: Development workspace for individual changes

### 1. MANDATORY Pre-Work Checklist
Before making ANY code changes:

```bash
# 1. Always check current status and branch
git status
git branch

# 2. If on main branch, immediately create feature branch
git checkout -b feature/describe-your-work

# 3. Read the project structure first
cat CLAUDE_INSTRUCTIONS.md
cat README_GIT_WORKFLOW.md
ls -la frontend/ios/
```

### 2. Project Understanding Requirements
- **ALWAYS** analyze existing code patterns before making changes
- **NEVER** assume libraries are available - check imports and package files first
- **ALWAYS** follow existing naming conventions and code style
- **NEVER** create duplicate functions or components without checking for existing ones

## 📱 Golf Swing AI App Structure

### Core Architecture
```
Golf Swing AI/
├── frontend/ios/              # iOS SwiftUI App
│   ├── Golf Swing AI/         # Main app module
│   │   ├── Services/          # Core services (CRITICAL - handle with care)
│   │   │   ├── AuthenticationManager.swift    # Google Sign-In - threading sensitive
│   │   │   ├── CameraManager.swift           # AVFoundation camera handling
│   │   │   ├── EnhancedGolfChat.swift        # AI chat service
│   │   │   ├── LocalAIManager.swift          # Core ML integration
│   │   │   └── LocalCaddieChat.swift         # Local AI responses
│   │   ├── Views/             # SwiftUI views
│   │   │   ├── LoginView.swift               # Authentication UI
│   │   │   ├── HomeView.swift                # Main dashboard
│   │   │   ├── CameraView.swift              # Video capture
│   │   │   └── ChatView.swift                # AI chat interface
│   │   ├── Models/            # Data models
│   │   └── Utils/             # Helper utilities
│   └── Golf Swing AI.xcodeproj # Xcode project file
├── backend/                   # Python backend services
│   ├── utils/                 # AI utilities
│   │   └── ai_golf_chatbot.py # Local LLM chatbot
│   ├── app.py                 # Flask API server
│   └── model.py               # ML model handling
├── README_GIT_WORKFLOW.md     # Version control guide
└── CLAUDE_INSTRUCTIONS.md     # This file - READ FIRST!
```

## 🛠️ Critical Code Patterns (DO NOT BREAK)

### 1. Swift 6 Concurrency Rules
```swift
// ✅ CORRECT - Use @MainActor for UI updates
@MainActor
class SomeUIManager: ObservableObject {
    @Published var isLoading = false
}

// ✅ CORRECT - Use @unchecked Sendable for delegate protocols
extension CameraManager: @unchecked Sendable {}

// ❌ NEVER - Don't create Task inside MainActor.run
MainActor.run {
    Task { // This causes SIGTERM crashes!
        await doSomething()
    }
}
```

### 2. Google Sign-In Threading (EXTREMELY SENSITIVE)
```swift
// ✅ CORRECT - Background configuration, main thread updates
private func configureGoogleSignIn() {
    DispatchQueue.global(qos: .background).async {
        // Configure here
        DispatchQueue.main.async {
            GIDSignIn.sharedInstance.configuration = config
        }
    }
}

// ❌ NEVER - Direct Task creation in sign-in methods
```

### 3. Camera Management
- Uses AVFoundation with careful session management
- Implements proper threading for camera operations
- Never modify without understanding session lifecycle

### 4. AI Integration
- Local Core ML models for on-device inference
- Python backend with Flask API
- Local LLM (Phi-2/similar) for chat functionality

## 🔧 Safe Development Workflow

### Phase 1: Analysis (ALWAYS DO FIRST)
```bash
# 1. Create feature branch immediately
git checkout -b feature/your-task-description

# 2. Read project context
head -50 frontend/ios/Golf\ Swing\ AI/*.swift
ls -la frontend/ios/Golf\ Swing\ AI/Services/

# 3. Check dependencies
cat frontend/ios/Golf\ Swing\ AI.xcodeproj/project.pbxproj | grep -i framework
grep -r "import " frontend/ios/Golf\ Swing\ AI/
```

### Phase 2: Implementation (INCREMENTAL ONLY)
```bash
# 1. Make ONE small change at a time
# 2. Test immediately after each change
cd frontend/ios && xcodebuild -project "Golf Swing AI.xcodeproj" -scheme "Golf Swing AI" build

# 3. Commit each working change
git add .
git commit -m "specific description of change"
```

### Phase 3: Testing & Pull Request Creation (MANDATORY)
```bash
# 1. Run build tests
./test_build.sh

# 2. Check for Swift compilation issues
./test_compile.sh

# 3. Push feature branch to GitHub
git push origin feature/your-task-description

# 4. Create Pull Request (PR) to testing branch for review
# Go to: https://github.com/nakulb23/golf-swing-ai
# Create PR: feature/your-branch → testing

# 5. After PR approval and merge to testing, create another PR
# Create PR: testing → main (requires approval before merge)

# NEVER directly merge to main - always use Pull Requests
```

## ⚠️ DANGER ZONES - Extra Caution Required

### 1. AuthenticationManager.swift
- **Issue**: SIGTERM crashes from threading problems
- **Rule**: Never modify async/await patterns without deep understanding
- **Test**: Always test sign-in flow after changes

### 2. CameraManager.swift  
- **Issue**: AVFoundation session conflicts
- **Rule**: Don't modify session setup/teardown without testing
- **Test**: Camera preview must work in app

### 3. Swift 6 Concurrency
- **Issue**: Sendable protocol violations cause crashes
- **Rule**: Add @unchecked Sendable carefully, understand why
- **Test**: No compiler warnings about concurrency

### 4. Google Sign-In Configuration
- **Issue**: Configuration timing causes app termination
- **Rule**: Keep background configuration pattern
- **Test**: Sign-in must work without crashes

## 📋 Pre-Change Validation Checklist

Before ANY modification:
- [ ] I'm on a feature branch (not main)
- [ ] I've read the relevant existing code
- [ ] I understand the current implementation pattern
- [ ] I've checked for similar existing functions
- [ ] I know which files I need to modify
- [ ] I have a plan to test the changes

## 🧪 Testing Requirements

### Mandatory Tests After Changes:
1. **Build Test**: App compiles without errors
2. **Launch Test**: App starts without crashing
3. **Feature Test**: The specific feature works as expected
4. **Regression Test**: Existing features still work

### Test Commands:
```bash
# Quick compilation check
cd frontend/ios && swift build --package-path .

# Full build test  
./test_build.sh

# Syntax validation
./test_compile.sh

# Manual testing in Xcode simulator required for UI changes
```

## 🚨 Emergency Recovery Procedures

### If App Won't Build After Changes:
```bash
# 1. Don't panic - you're on a feature branch
git status

# 2. See what changed
git diff

# 3. Revert problematic changes
git checkout -- filename.swift

# 4. Or abandon branch and start over
git checkout main
git branch -D feature/broken-branch
```

### If App Crashes After Changes:
```bash
# 1. Check for threading issues in modified files
grep -n "Task\|MainActor\|DispatchQueue" modified_file.swift

# 2. Look for concurrency warnings
xcodebuild build 2>&1 | grep -i concurrency

# 3. Test individual components
# Use Xcode debugger to identify crash point
```

## 💡 Common Mistakes to Avoid

1. **Working on main branch** → Always use feature branches
2. **Making multiple changes at once** → One change, test, commit, repeat
3. **Assuming libraries exist** → Check imports and dependencies first
4. **Ignoring compiler warnings** → Fix all warnings before merging
5. **Not testing before merging** → Every merge to main must be tested
6. **Threading violations** → Understand Swift 6 concurrency rules
7. **Duplicate code** → Check for existing implementations first

## 📞 When in Doubt

**STOP and ask questions rather than guessing:**
- "What does this existing code pattern do?"
- "Are there similar implementations I should follow?"
- "What's the safest way to test this change?"
- "Should I create a backup branch before this risky change?"

## 🎯 Success Criteria

A successful Claude session should:
- ✅ Never break the main branch
- ✅ Follow existing code patterns
- ✅ Fix issues without creating new ones
- ✅ Leave the app in a better state than found
- ✅ Provide clear documentation of changes made

---

**Remember: The user lost 2 weeks of work due to previous mistakes. Your job is to be helpful while being extremely careful to preserve working code.**