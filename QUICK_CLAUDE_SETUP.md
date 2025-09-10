# 🚨 CLAUDE QUICK START - READ THIS FIRST!

## If Claude Session is New or Lost Context

**Copy and paste these commands to Claude immediately:**

1. **Make Claude read the instructions:**
```
Please read these files first before doing any work:
- Read /Users/nakulbhatnagar/Desktop/Golf Swing AI/CLAUDE_INSTRUCTIONS.md  
- Read /Users/nakulbhatnagar/Desktop/Golf Swing AI/README_GIT_WORKFLOW.md
```

2. **Force Claude to use proper branch workflow:**
```
Before making any changes to my Golf Swing AI project:
1. Always create a feature branch first
2. Never work directly on main or testing branches
3. Test all changes before creating Pull Requests
4. Use Pull Request workflow: feature → testing → main
5. Follow the instructions in CLAUDE_INSTRUCTIONS.md
Repository: https://github.com/nakulb23/golf-swing-ai
Testing branch: https://github.com/nakulb23/golf-swing-ai/tree/testing
```

3. **Give Claude the critical context:**
```
This is a Golf Swing AI iOS app built with SwiftUI. I previously lost 2 weeks of work due to an AI assistant making changes that broke the app. The app currently works and builds properly. Be extremely careful with:
- AuthenticationManager.swift (threading issues)
- Swift 6 concurrency patterns  
- Google Sign-In integration
- Camera management
Always use feature branches and test changes.
```

## Emergency Recovery Commands

If Claude breaks something:

```bash
# Check what branch you're on
git branch

# If on main and it's broken, revert last commit
git reset --hard HEAD~1

# If on feature branch, abandon it
git checkout main
git branch -D feature/broken-branch

# Create fresh feature branch
git checkout -b feature/new-attempt
```

## Key Files to Protect
- `frontend/ios/Golf Swing AI/Services/AuthenticationManager.swift`
- `frontend/ios/Golf Swing AI/Services/CameraManager.swift`  
- `frontend/ios/Golf Swing AI/Views/LoginView.swift`
- `frontend/ios/Golf Swing AI.xcodeproj/project.pbxproj`

## Testing Commands
```bash
# Quick build test
cd "/Users/nakulbhatnagar/Desktop/Golf Swing AI/frontend/ios"
xcodebuild -project "Golf Swing AI.xcodeproj" -scheme "Golf Swing AI" build

# Run test scripts
cd "/Users/nakulbhatnagar/Desktop/Golf Swing AI"
./test_build.sh
./test_compile.sh
```

---
**Save this file to quickly orient new Claude sessions!**