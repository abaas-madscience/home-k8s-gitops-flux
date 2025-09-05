#!/bin/bash
# merge.sh - Promote changes from kind to production

set -e

echo "🔄 Promoting changes from kind branch to main..."

# Safety check - make sure we're not on main
current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ]; then
    echo "❌ You're on main branch! Switch to kind branch first."
    exit 1
fi

# Ensure we're on kind branch
git checkout kind
git pull origin kind

# Switch to main and merge
git checkout main
git pull origin main
git merge kind --no-ff -m "🚀 Promote: $(git log --oneline -1 kind)"

# Push to production
git push origin main

echo "✅ Changes promoted to production!"
echo "🔍 Monitor Flux reconciliation: flux get kustomizations -w"

# Optional: Switch back to kind for continued development
read -p "Switch back to kind branch? (y/n): " -n 1 -r
echo
if [[ $RPLY =~ ^[Yy]$ ]]; then
    git checkout kind
    echo "👍 Back on kind branch for continued development"
fi