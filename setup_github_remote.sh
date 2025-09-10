#!/bin/bash

# Golf Swing AI - GitHub Remote Setup Script
# Run this script after creating your GitHub repository

echo "🚀 Setting up GitHub remote for Golf Swing AI..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d ".git" ]; then
    print_error "Not in a Git repository! Please run this script from the Golf Swing AI project root."
    exit 1
fi

print_status "Current directory: $(pwd)"

# Prompt for GitHub repository URL
echo ""
print_status "Please enter your GitHub repository URL:"
print_status "Example: https://github.com/yourusername/golf-swing-ai-ios.git"
echo -n "GitHub Repository URL: "
read GITHUB_URL

# Validate URL format
if [[ ! $GITHUB_URL =~ ^https://github\.com/.*/.*\.git$ ]]; then
    print_warning "URL format might be incorrect. Expected format: https://github.com/username/repo.git"
    echo -n "Continue anyway? (y/n): "
    read CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        print_error "Aborted by user."
        exit 1
    fi
fi

# Check if origin remote already exists
if git remote get-url origin &> /dev/null; then
    print_warning "Remote 'origin' already exists."
    CURRENT_ORIGIN=$(git remote get-url origin)
    print_status "Current origin: $CURRENT_ORIGIN"
    
    if [ "$CURRENT_ORIGIN" = "$GITHUB_URL" ]; then
        print_success "Remote is already set to the correct URL!"
        SKIP_REMOTE_SETUP=true
    else
        echo -n "Update origin to new URL? (y/n): "
        read UPDATE_ORIGIN
        if [ "$UPDATE_ORIGIN" = "y" ]; then
            print_status "Updating remote origin..."
            git remote set-url origin "$GITHUB_URL"
            print_success "Remote origin updated!"
        else
            print_error "Keeping existing remote. Script will continue with push attempt."
        fi
    fi
else
    print_status "Adding GitHub remote..."
    git remote add origin "$GITHUB_URL"
    print_success "Remote 'origin' added successfully!"
fi

# Show current remotes
print_status "Current remotes:"
git remote -v

echo ""

# Attempt to push to GitHub
if [ "$SKIP_REMOTE_SETUP" != "true" ]; then
    print_status "Attempting to push to GitHub..."
    
    # Push main branch and set upstream
    if git push -u origin main; then
        print_success "Successfully pushed to GitHub!"
        print_success "Your code is now backed up on GitHub: $GITHUB_URL"
    else
        print_error "Push failed. This might be because:"
        echo "  1. The repository doesn't exist on GitHub yet"
        echo "  2. You don't have push permissions"
        echo "  3. Authentication is required"
        echo ""
        print_status "To fix this:"
        echo "  1. Make sure you've created the repository on GitHub"
        echo "  2. Ensure you're authenticated (use 'gh auth login' if using GitHub CLI)"
        echo "  3. Try running: git push -u origin main"
    fi
else
    print_status "Skipping push since remote was already configured."
    print_status "To push manually, run: git push origin main"
fi

echo ""

# Show next steps
print_success "🎉 Setup complete!"
echo ""
print_status "Next steps:"
echo "  1. ✅ Repository is initialized with Git"
echo "  2. ✅ Comprehensive .gitignore is set up"
echo "  3. ✅ Current stable state is committed"
echo "  4. ✅ GitHub remote is configured"
echo "  5. 📋 Review the workflow guide: README_GIT_WORKFLOW.md"
echo ""
print_status "Daily workflow reminder:"
echo "  • Commit frequently: git add . && git commit -m 'your message'"
echo "  • Push to backup: git push origin main"
echo "  • Check status: git status"
echo ""
print_success "Your work is now protected! 🛡️"