# Git Workflow Guide for Golf Swing AI

## Branch Strategy

### Main Branch
- `main` - Production-ready code
- Always stable and deployable
- Protected branch requiring PR reviews

### Development Workflow
```
main
├── feature/dynamic-ai-chat      # New AI features
├── feature/ui-improvements      # UI enhancements  
├── bugfix/chat-duplicates       # Bug fixes
├── hotfix/critical-crash        # Emergency fixes
└── docs/claude-integration      # Documentation updates
```

## Branch Naming Convention

### Feature Branches
- `feature/feature-name` - New functionality
- `feature/caddie-chat-improvements`
- `feature/swing-analysis-enhancement`

### Bug Fixes
- `bugfix/issue-description` - Bug fixes
- `bugfix/duplicate-welcome-messages`
- `bugfix/memory-leak-conversation`

### Hotfixes
- `hotfix/critical-issue` - Production emergency fixes
- `hotfix/app-crash-startup`

### Documentation
- `docs/topic-name` - Documentation updates
- `docs/claude-instructions`
- `docs/api-documentation`

## Workflow Steps

### 1. Starting New Work
```bash
# Update main branch
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name

# Start development
```

### 2. Development Process
```bash
# Regular commits with descriptive messages
git add .
git commit -m "Add contextual analysis to DynamicGolfAI

- Implement conversation memory system
- Add user profiling for personalized responses
- Include topic threading for better context"

# Push branch regularly
git push -u origin feature/your-feature-name
```

### 3. Creating Pull Request
```bash
# Ensure branch is up to date
git checkout main
git pull origin main
git checkout feature/your-feature-name
git merge main

# Resolve any conflicts, test thoroughly
git push origin feature/your-feature-name
```

Then create PR using GitHub interface with the provided template.

### 4. Code Review Process
- **Self-review first** - Check your own changes
- **Request reviewers** - At least one team member
- **Address feedback** - Make requested changes
- **Test again** - After any changes

### 5. Merging
- Use **"Squash and merge"** for feature branches
- Use **"Merge commit"** for hotfixes to preserve history
- Delete feature branch after merging

## Commit Message Guidelines

### Format
```
<type>(<scope>): <description>

<body>

<footer>
```

### Types
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code formatting (no logic changes)
- `refactor` - Code restructuring
- `test` - Adding/updating tests
- `chore` - Build process, dependencies

### Examples
```bash
# Feature commit
git commit -m "feat(chat): implement DynamicGolfAI with conversation memory

- Replace hardcoded responses with intelligent system
- Add contextual analysis and user profiling
- Implement thread-safe conversation management
- Include specific golf advice generation

Closes #123"

# Bug fix commit  
git commit -m "fix(ui): resolve duplicate welcome messages in CaddieChat

- Replace NavigationLink with tab switching mechanism
- Add onAppear logic to prevent multiple message initialization
- Update ContentView to handle tab notifications

Fixes #456"

# Documentation commit
git commit -m "docs: add comprehensive Claude AI integration guide

- Create CLAUDE_INSTRUCTIONS.md with architecture details
- Add QUICK_CLAUDE_SETUP.md for fast orientation
- Include troubleshooting and testing guidelines"
```

## Git Hooks (Recommended)

### Pre-commit Hook
Create `.git/hooks/pre-commit`:
```bash
#!/bin/sh
# Check for Swift compilation errors
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint
fi
```

### Pre-push Hook
Create `.git/hooks/pre-push`:
```bash
#!/bin/sh
# Run tests before pushing (if available)
echo "Running pre-push checks..."
# Add test commands here
```

## Emergency Procedures

### Hotfix Process
```bash
# Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue

# Make minimal fix
git add .
git commit -m "hotfix: resolve critical app crash on startup"

# Push and create urgent PR
git push -u origin hotfix/critical-issue
```

### Rollback Procedure
```bash
# If main branch has issues
git checkout main
git revert <problematic-commit-hash>
git push origin main
```

## Best Practices

### Do's ✅
- Commit frequently with meaningful messages
- Test thoroughly before pushing
- Keep branches focused on single features
- Use descriptive branch names
- Rebase feature branches on main before PR
- Update documentation with code changes

### Don'ts ❌
- Don't commit directly to main
- Don't push untested code
- Don't leave branches unmerged for weeks
- Don't force push to shared branches
- Don't commit sensitive information
- Don't skip code reviews

## Claude AI Specific Workflow

### When Working with Claude
1. **Start each session** by reading QUICK_CLAUDE_SETUP.md
2. **Document changes** in commit messages for context
3. **Update instructions** if architecture changes
4. **Test AI functionality** specifically before commits
5. **Include debug info** in commit descriptions

### AI Feature Development
```bash
# Example workflow for AI improvements
git checkout -b feature/improve-golf-advice

# Development with Claude assistance
# ... make changes to DynamicGolfAI.swift

# Test specifically
# - "How do I fix my driver slice?" 
# - "What club for 200 yards?"
# - Follow-up questions

git commit -m "feat(ai): enhance golf advice specificity

- Add driver slice specific responses
- Implement club selection logic with conditions
- Include follow-up question handling
- Test contextual conversation flow

🤖 Generated with Claude Code assistance"

git push -u origin feature/improve-golf-advice
```

---
*This workflow ensures code quality, maintainability, and effective collaboration with AI assistance.*