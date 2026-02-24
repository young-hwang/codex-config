#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <branch-name>"
    exit 1
fi

BRANCH_NAME="$1"
WORKTREE_DIR="../worktrees/$BRANCH_NAME"

echo "--- Creating worktree for branch '$BRANCH_NAME'..."

# Create parent worktrees directory if needed
mkdir -p "../worktrees"

# Check if worktree already exists for this branch
EXISTING_WORKTREE=$(git worktree list | grep -w "$BRANCH_NAME" | awk '{print $1}')

if [ -n "$EXISTING_WORKTREE" ]; then
    echo "✓ Worktree already exists for branch '$BRANCH_NAME' at: $EXISTING_WORKTREE"
    echo "  To use it, run: cd $EXISTING_WORKTREE"
    exit 0
fi

# Also check if directory exists but not registered as worktree
if [ -d "$WORKTREE_DIR" ]; then
    echo "Warning: Directory exists at $WORKTREE_DIR but is not a registered worktree."
    echo "Removing directory and creating proper worktree..."
    rm -rf "$WORKTREE_DIR"
fi

# Check if branch exists locally or remotely
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    # Local branch exists
    echo "Creating worktree from existing local branch..."
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
elif git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    # Remote branch exists
    echo "Creating worktree from remote branch..."
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
else
    # Create new branch
    echo "Creating new branch and worktree..."
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
fi

echo ""
echo "✓ Worktree created successfully!"
echo "  Location: $WORKTREE_DIR"
echo "  Branch:   $BRANCH_NAME"
echo ""
echo "All worktrees:"
git worktree list