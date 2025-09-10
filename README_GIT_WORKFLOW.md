# Golf Swing AI - Git Workflow & Version Control Guide

## 🎯 Purpose
This guide ensures you never lose weeks of work again by establishing proper version control practices.

## 📋 Quick Commands Reference

### Daily Workflow Commands
```bash
# Navigate to project directory
cd "/Users/nakulbhatnagar/Desktop/Golf Swing AI"

# Check current status
git status

# Save your work (commit changes)
git add .
git commit -m "describe what you changed"
git push origin main

# Pull latest changes (if working with others)
git pull origin main
```

### Emergency Recovery Commands
```bash
# View recent commits
git log --oneline -10

# Revert to a previous commit (DESTRUCTIVE - use with caution)
git reset --hard <commit-hash>

# Revert to previous commit but keep changes as uncommitted
git reset --soft HEAD~1

# Create a new branch from a specific commit
git checkout -b recovery-branch <commit-hash>
```

## 🔄 Recommended Workflow

### 1. Before Starting Any Work
```bash
# Always start by checking status and current branch
git status
git branch

# Make sure you're on main branch first
git checkout main

# Pull latest changes (if connected to GitHub)
git pull origin main

# NEVER work on main - create feature branch immediately
git checkout -b feature/describe-what-youre-doing

# Example branch names:
# git checkout -b feature/fix-login-bug
# git checkout -b feature/add-swing-analysis  
# git checkout -b fix/camera-crash
# git checkout -b experiment/new-ai-model
```

### 2. During Development (ON YOUR FEATURE BRANCH)
```bash
# You're now on your feature branch - work freely here
# Commit frequently (every 30-60 minutes of work)
git add .
git commit -m "feat: describe the specific feature/fix you added"

# Push your feature branch to backup your work
git push origin feature/your-branch-name

# Continue working and committing...
git add .
git commit -m "fix: resolve issue with camera focus"
git commit -m "test: add validation for new feature"
```

### 3. Testing Your Changes
```bash
# Test your changes thoroughly on your feature branch
# Make sure the app builds and runs properly
cd frontend/ios
xcodebuild -project "Golf Swing AI.xcodeproj" -scheme "Golf Swing AI" build

# Run any test scripts
./test_build.sh
./test_compile.sh

# Test manually in Xcode simulator
```

### 4. Creating Pull Request to Testing Branch
```bash
# Push your feature branch to GitHub
git push origin feature/your-branch-name

# Go to GitHub and create Pull Request:
# https://github.com/nakulb23/golf-swing-ai/compare

# Create PR: feature/your-branch-name → testing
# Add description of what was changed and why
# Request review if working with others
```

### 5. After PR is Approved and Merged to Testing
```bash
# Pull the updated testing branch
git checkout testing
git pull origin testing

# Your feature is now in testing branch
# Test thoroughly in this environment

# Clean up local feature branch
git branch -d feature/your-branch-name
```

### 6. Promoting to Main (PRODUCTION)
```bash
# Create Pull Request from testing to main
# Go to: https://github.com/nakulb23/golf-swing-ai/compare/main...testing

# This PR requires approval before merging to main
# Main branch represents production-ready code only

# NEVER push directly to main - always use Pull Requests
```

### 5. End of Day
```bash
# If still working on feature branch:
git add .
git commit -m "end of day: save progress on feature"
git push origin feature/your-branch-name

# Main branch should always be stable, so no daily commits to main
```

## 🏷️ Commit Message Guidelines

Use clear, descriptive messages:
- `feat: add new swing analysis algorithm`
- `fix: resolve login crash on iOS 17`
- `ui: update home page layout`
- `refactor: clean up authentication code`
- `docs: update setup instructions`
- `WIP: working on ball tracking feature` (for work in progress)

## 🆘 Emergency Recovery Scenarios

### Lost Work - Find Your Last Good Version
```bash
# See all recent commits
git log --oneline --graph -20

# Check out a specific commit to a new branch
git checkout -b recovery-<timestamp> <commit-hash>

# If that's the version you want, merge it back
git checkout main
git merge recovery-<timestamp>
```

### Accidentally Deleted Files
```bash
# Restore all files from last commit
git checkout HEAD -- .

# Restore specific file
git checkout HEAD -- path/to/file.swift
```

### Bad Commit - Undo Last Commit
```bash
# Undo last commit but keep changes
git reset --soft HEAD~1

# Undo last commit and discard changes (DANGEROUS)
git reset --hard HEAD~1
```

## 🌿 Branch Strategy for Safe Development

### Keep Main Branch Stable - ALWAYS Work on Feature Branches

**Golden Rule: Never work directly on main branch!**

```bash
# ALWAYS start with a clean main branch
git checkout main
git status  # Should be clean

# Create a new branch for ANY work
git checkout -b feature/fix-camera-bug
# or
git checkout -b feature/add-swing-analysis
# or  
git checkout -b hotfix/login-crash

# Work on your feature branch...
git add .
git commit -m "feat: implement camera improvements"
git commit -m "test: add camera tests"
git commit -m "fix: resolve focus issue"

# Test thoroughly on your branch
# Make sure app builds and works properly

# Only when everything works perfectly:
git checkout main
git merge feature/fix-camera-bug

# Delete the feature branch
git branch -d feature/fix-camera-bug

# Push the stable main branch
git push origin main
```

### Branch Naming Convention
- `feature/description` - New features or improvements
- `fix/description` - Bug fixes
- `hotfix/description` - Critical urgent fixes
- `experiment/description` - Experimental work that might not work

### Safe Development Workflow
```bash
# 1. Start from stable main
git checkout main
git pull origin main  # Get latest if working with others

# 2. Create branch for your work
git checkout -b feature/improve-swing-detection

# 3. Work and commit frequently on your branch
git add .
git commit -m "wip: updating pose detection algorithm"

# 4. Test everything - make sure app builds and works
# Run your test scripts, check in Xcode, etc.

# 5. Only merge to main when 100% working
git checkout main
git merge feature/improve-swing-detection

# 6. Push stable main
git push origin main
```

### Create Backup Points Before Major Changes
```bash
# Before attempting risky changes
git tag stable-$(date +%Y%m%d-%H%M%S)
git push origin --tags

# Later, if you need to recover
git checkout stable-20240309-143000
```

## 📊 Monitoring Your Repository

### Check Repository Health
```bash
# See file sizes and what's tracked
git ls-files --stage

# See recent activity
git log --oneline --since="1 week ago"

# Check remote status
git remote -v
```

## ⚠️ Critical Rules

1. **NEVER FORCE PUSH** (`git push --force`) unless you're 100% sure
2. **COMMIT EARLY, COMMIT OFTEN** - at least every hour of work
3. **ALWAYS PUSH TO REMOTE** - local commits aren't backups
4. **USE DESCRIPTIVE COMMIT MESSAGES** - you'll thank yourself later
5. **TEST BEFORE COMMITTING** - make sure your app still builds
6. **BACKUP BEFORE RISKY CHANGES** - create branches or tags

## 🔗 GitHub Repository Setup

Once we create your GitHub repository, you'll have:
- **Remote backup** of all your code
- **Issue tracking** for bugs and features
- **Release management** for app versions
- **Collaboration tools** if you work with others

## 📞 Getting Help

If you're ever unsure about a Git command:
```bash
# Get help for any command
git help <command>

# Example
git help reset
```

**Remember: It's always better to ask before running a command you're unsure about!**

---

## 🎯 Next Steps

1. ✅ Repository initialized with current stable code
2. ⏳ Create GitHub repository and connect remote
3. ⏳ Set up automated backups
4. ⏳ Create development workflow documentation

This workflow will protect your work and give you confidence to experiment and improve your app without fear of losing progress.