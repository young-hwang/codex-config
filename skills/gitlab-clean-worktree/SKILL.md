---
name: "gitlab-clean-worktree"
description: "Migrate and run the workflow from Claude command gitlab/clean-worktree.md. Use when asked to perform tasks matching gitlab-clean-worktree, for example: Cleanup a git worktree and tmux session for a completed GitLab issue in the parent directory."
---

# GitLab Issue Worktree Cleanup

## Overview

Use this skill to execute the existing workflow migrated from `gitlab/clean-worktree.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# GitLab Issue Worktree Cleanup

Cleanup a git worktree and tmux session for a completed GitLab issue in the parent directory.

## Command Usage

Provide a GitLab issue URL or issue number: $ARGUMENTS

## Workflow

1. **Check glab CLI installation**
   - Verify glab is installed and authenticated
   - If not installed, provide installation instructions and stop

2. **Extract and validate issue**
   - Parse issue number from URL or direct number input
   - Fetch issue details using `glab issue view`
   - Display issue title for confirmation

3. **Find existing branch**
   - Fetch latest branches from remote using `git fetch --all --prune`
   - Search for existing branches with the issue number (e.g., `feature/123`, `issue-123`)
   - If no branch found, warn user but continue cleanup

4. **Kill tmux session**
   - Find tmux session named `<issue-number>-develop` or `<issue-number>-*`
   - Kill the session using `tmux kill-session`
   - Always run tmux commands (`tmux ls`, `tmux kill-session`) with elevated permissions in Codex
   - If tmux socket access fails (permission), treat it as a permission failure (not no-session) and rerun with elevated permissions
   - Do not suppress tmux stderr; treat connection errors as failures
   - Skip only if tmux is not installed or no matching session exists
   - Confirm session terminated

5. **Remove worktree**
   - Find worktree using `git worktree list` with branch name
   - Remove worktree using `git worktree remove <path>`
   - If removal fails (uncommitted changes), offer force removal option
   - Handle case where worktree doesn't exist

6. **Delete local git branch (after worktree removal)**
   - Delete the local branch using `git branch -d <branch-name>` only after worktree removal succeeds
   - Skip if no branch was found in step 3
   - Skip if worktree removal did not succeed
   - If local deletion fails (unmerged), offer force deletion option

7. **Confirm cleanup**
   - Display what was cleaned up (tmux session, worktree, branch)
   - Show remaining worktrees using `git worktree list`
   - Provide status of cleanup operation

## Example Implementation

```bash
# Step 1: Check glab installation
if ! command -v glab &> /dev/null; then
    echo "Error: glab CLI is not installed"
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install glab"
    echo "  Linux:   See https://gitlab.com/gitlab-org/cli#installation"
    echo "  Windows: scoop install glab"
    echo ""
    echo "After installation, authenticate with: glab auth login"
    exit 1
fi

# Check authentication
if ! glab auth status &> /dev/null; then
    echo "Error: glab is not authenticated"
    echo "Please run: glab auth login"
    exit 1
fi

# Step 2: Extract issue number
ISSUE_INPUT="$ARGUMENTS"

# Handle different input formats
if [[ "$ISSUE_INPUT" =~ /-/issues/([0-9]+) ]]; then
    # Full URL format
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
elif [[ "$ISSUE_INPUT" =~ ^#?([0-9]+)$ ]]; then
    # Issue number format (#123 or 123)
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid issue format. Provide URL or issue number."
    exit 1
fi

# Step 3: Fetch issue details
echo "Fetching issue #$ISSUE_NUMBER..."
ISSUE_TITLE=$(glab issue view "$ISSUE_NUMBER" --json title -q '.title')

if [ -z "$ISSUE_TITLE" ]; then
    echo "Error: Could not fetch issue #$ISSUE_NUMBER"
    exit 1
fi

echo "Issue: #$ISSUE_NUMBER - $ISSUE_TITLE"
echo ""

# Step 4: Find branch name
echo "Fetching latest branches from remote..."
git fetch --all --prune

# Search for existing branches related to this issue
EXISTING_BRANCHES=$(git branch -a | grep -E "(feature[/-]${ISSUE_NUMBER}[^0-9]|feature[/-]${ISSUE_NUMBER}$|issue[-_]${ISSUE_NUMBER}|${ISSUE_NUMBER}[-_])" | head -n 1 | sed 's/^[* ]*//' | sed 's/remotes\/origin\///')

if [ -n "$EXISTING_BRANCHES" ]; then
    EXISTING_BRANCHES=$(echo "$EXISTING_BRANCHES" | xargs)
    echo "Found branch: $EXISTING_BRANCHES"
    BRANCH_NAME="$EXISTING_BRANCHES"
else
    echo "Warning: No branch found for issue #$ISSUE_NUMBER"
    echo "Attempting cleanup by issue number only..."
    BRANCH_NAME=""
fi

# Step 5: Kill tmux session
# NOTE: In Codex, run this step with elevated permissions by default to access tmux socket
SESSION_NAME="${ISSUE_NUMBER}-develop"
TMUX_CLEANED=false

if command -v tmux &> /dev/null; then
    # Find sessions matching the issue number
    TMUX_LIST_OUTPUT=$(tmux ls 2>&1)
    if [ $? -ne 0 ]; then
        echo "tmux ls failed: $TMUX_LIST_OUTPUT"
        echo "Retry tmux commands with elevated permissions"
        MATCHING_SESSIONS=""
    else
        MATCHING_SESSIONS=$(printf '%s\n' "$TMUX_LIST_OUTPUT" | grep "^${ISSUE_NUMBER}-" | cut -d: -f1)
    fi

    if [ -n "$MATCHING_SESSIONS" ]; then
        echo "Found tmux session(s) to clean up:"
        while IFS= read -r session; do
            echo "  - $session"
            tmux kill-session -t "$session"
            if [ $? -eq 0 ]; then
                echo "    ✓ Killed session: $session"
                TMUX_CLEANED=true
            else
                echo "    ✗ Failed to kill session: $session"
            fi
        done <<< "$MATCHING_SESSIONS"
    else
        echo "No tmux session found for issue #$ISSUE_NUMBER"
    fi
else
    echo "Skipping tmux cleanup (tmux not installed)"
fi

echo ""

# Step 6: Remove worktree
WORKTREE_CLEANED=false

if [ -n "$BRANCH_NAME" ]; then
    # Find worktree by branch name
    WORKTREE_PATH=$(git worktree list | grep "$BRANCH_NAME" | awk '{print $1}')

    if [ -n "$WORKTREE_PATH" ]; then
        echo "Found worktree: $WORKTREE_PATH"
        echo "Removing worktree..."

        git worktree remove "$WORKTREE_PATH" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "✓ Removed worktree: $WORKTREE_PATH"
            WORKTREE_CLEANED=true
        else
            echo "✗ Failed to remove worktree (may have uncommitted changes)"
            echo ""
            echo "To force removal, run:"
            echo "  git worktree remove --force $WORKTREE_PATH"
            echo ""
            echo "Or manually remove:"
            echo "  rm -rf $WORKTREE_PATH"
            echo "  git worktree prune"
        fi
    else
        echo "No worktree found for branch: $BRANCH_NAME"

        # Try to find by path pattern
        WORKTREE_DIR="../worktrees/$BRANCH_NAME"
        if [ -d "$WORKTREE_DIR" ]; then
            echo "Found directory at: $WORKTREE_DIR (not registered as worktree)"
            echo "Removing directory..."
            rm -rf "$WORKTREE_DIR"
            git worktree prune
            echo "✓ Cleaned up directory and pruned worktrees"
            WORKTREE_CLEANED=true
        fi
    fi
else
    # Try to find worktree by issue number in path
    echo "Searching for worktrees with issue #$ISSUE_NUMBER..."
    WORKTREE_PATHS=$(git worktree list | grep -E "worktrees/(feature/)?${ISSUE_NUMBER}[-_]" | awk '{print $1}')

    if [ -n "$WORKTREE_PATHS" ]; then
        while IFS= read -r path; do
            echo "Found worktree: $path"
            git worktree remove "$path" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "✓ Removed worktree: $path"
                WORKTREE_CLEANED=true
            else
                echo "✗ Failed to remove worktree: $path"
            fi
        done <<< "$WORKTREE_PATHS"
    else
        echo "No worktree found for issue #$ISSUE_NUMBER"
    fi
fi

echo ""

# Step 7: Delete local git branch (after worktree cleanup)
BRANCH_CLEANED=false

if [ -n "$BRANCH_NAME" ] && [ "$WORKTREE_CLEANED" = true ]; then
    echo "Deleting local branch: $BRANCH_NAME"

    # Delete local branch
    if git branch --list "$BRANCH_NAME" | grep -q .; then
        git branch -d "$BRANCH_NAME" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "  ✓ Deleted local branch: $BRANCH_NAME"
            BRANCH_CLEANED=true
        else
            echo "  ✗ Failed to delete local branch (may have unmerged changes)"
            echo ""
            echo "  To force delete, run:"
            echo "    git branch -D $BRANCH_NAME"
        fi
    else
        echo "  No local branch found: $BRANCH_NAME"
    fi
elif [ -n "$BRANCH_NAME" ]; then
    echo "Skipping local branch deletion because worktree removal did not complete"
else
    echo "Skipping local branch deletion (no branch found)"
fi

echo ""

# Step 8: Summary
echo "════════════════════════════════════════"
echo "Cleanup Summary for Issue #$ISSUE_NUMBER"
echo "════════════════════════════════════════"

if [ "$TMUX_CLEANED" = true ] || [ "$WORKTREE_CLEANED" = true ] || [ "$BRANCH_CLEANED" = true ]; then
    echo "✓ Cleanup completed successfully"
    [ "$TMUX_CLEANED" = true ] && echo "  - tmux session(s) killed"
    [ "$WORKTREE_CLEANED" = true ] && echo "  - worktree(s) removed"
    [ "$BRANCH_CLEANED" = true ] && echo "  - local branch deleted"
else
    echo "⚠ No cleanup performed"
    echo "  No tmux session, worktree, or branch found for issue #$ISSUE_NUMBER"
fi

echo ""
echo "Remaining worktrees:"
git worktree list
```

## Manual Cleanup Commands

If you prefer to clean up manually or the automatic cleanup fails, use these commands:

### Remove a specific worktree:
```bash
git worktree remove ../worktrees/<branch-name>
```

### Force remove worktree (with uncommitted changes):
```bash
git worktree remove --force ../worktrees/<branch-name>
```

### Kill the associated tmux session:
```bash
tmux kill-session -t <issue-number>-develop
```

### Delete local branch:
```bash
# Safe delete (fails if unmerged)
git branch -d <branch-name>

# Force delete (even if unmerged)
git branch -D <branch-name>
```

### Remove worktree, local branch, and tmux session:
```bash
git worktree remove ../worktrees/<branch-name>
git branch -d <branch-name>
tmux kill-session -t <issue-number>-develop
```

### Clean up orphaned worktree directories:
```bash
# Remove directory and prune worktree registry
rm -rf ../worktrees/<branch-name>
git worktree prune
```

### Bulk cleanup for closed issues:
```bash
# List all worktrees
git worktree list

# Remove specific worktrees
git worktree remove <path>

# List all tmux sessions
tmux ls

# Kill specific sessions
tmux kill-session -t <session-name>
```

## Notes

- **Safety**: The cleanup process checks for uncommitted changes and will not force-remove worktrees by default
- **Verification**: Always verify the issue number before cleanup to avoid removing the wrong worktree
- **Branch detection**: The command searches for branches using multiple naming patterns (feature/N, issue-N, N-)
- **Branch safety**: Local branch deletion uses `-d` (safe delete) by default, which fails if the branch has unmerged changes
- **Branch cleanup order**: Local branch deletion is attempted only after worktree removal succeeds
- **Graceful failure**: If tmux, worktree, or branch doesn't exist, the command will skip that step and continue
- **Manual intervention**: If automatic cleanup fails due to uncommitted changes, use manual cleanup commands
- **Consistency**: This command is designed to work with worktrees created by the `create-worktree` command
- **Tmux permissions**: Always run tmux steps with elevated permissions in Codex; if `tmux ls` returns socket permission errors, treat it as permission failure instead of no session
- **Multiple sessions**: The command will find and clean up all tmux sessions matching the issue number pattern

## Best Practices

1. **Before cleanup**: Ensure all changes are committed and pushed to remote
2. **Verify completion**: Check that the issue is truly complete before cleaning up
3. **Review changes**: Use `git status` in the worktree before cleanup
4. **Branch deletion**: The cleanup deletes the local branch after worktree removal
5. **Batch cleanup**: Periodically clean up old worktrees for completed issues to save disk space
