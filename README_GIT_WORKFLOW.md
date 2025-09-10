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
# Always start by checking status
git status

# If you have uncommitted changes, commit them first
git add .
git commit -m "WIP: save current progress before starting new work"
git push origin main
```

### 2. During Development
```bash
# Commit frequently (every 30-60 minutes of work)
git add .
git commit -m "feat: describe the specific feature/fix you added"
git push origin main
```

### 3. Before Major Changes
```bash
# Create a backup branch
git checkout -b backup-$(date +%Y%m%d-%H%M%S)
git push origin backup-$(date +%Y%m%d-%H%M%S)
git checkout main
```

### 4. End of Day
```bash
# Always commit and push before closing
git add .
git commit -m "end of day: save all progress"
git push origin main
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

### Create Feature Branches for Risky Work
```bash
# Create and switch to new branch
git checkout -b feature/new-ai-model

# Work on your feature...
git add .
git commit -m "feat: implement new AI model"

# When done, merge back to main
git checkout main
git merge feature/new-ai-model

# Delete feature branch
git branch -d feature/new-ai-model
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