---
name: "github-create-worktree"
description: "Migrate and run the workflow from Claude command github/create-worktree.md. Use when asked to perform tasks matching github-create-worktree, for example: Create a git worktree for a Github issue in the parent directory to keep the main working directory clean."
---

# Github Issue Worktree Creation

## Overview

Use this skill to execute the existing workflow migrated from `github/create-worktree.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# Github Issue Worktree Creation

Create a git worktree for a Github issue in the parent directory to keep the main working directory clean.

## Command Usage

Provide a Github issue URL or issue number: $ARGUMENTS

## Workflow

1. **Check gh CLI installation**
   - Verify gh is installed and authenticated
   - If not installed, provide installation instructions and stop

2. **Extract and validate issue**
   - Parse issue number from URL or direct number input
   - Fetch issue details using `gh issue view`
   - Display issue title and description

3. **Determine branch name**
   - Fetch latest branches from remote using `git fetch --all --prune`
   - Search for existing branches with the issue number (e.g., `feature/123`, `issue-123`)
   - If no branch exists, create branch name from issue (e.g., `feature/123-feature-description`)

4. **Create worktree in parent directory**
   - Check if worktree already exists for the branch
   - Create worktree at `../worktrees/<branch-name>`
   - This keeps the main project directory clean
   - Checkout or create the branch in the worktree

5. **Create tmux session and initialize spec-kit**
   - Create a new tmux session named `<issue-number>-develop`
   - Navigate to the worktree directory
   - Initialize spec-kit with claude AI configuration
   - Skip if tmux is not installed

6. **Provide next steps**
   - Show worktree location and branch information
   - Display command to navigate to worktree or attach to tmux session
   - Show git worktree list

## Example Implementation

```bash
# Step 1: Check gh installation
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI is not installed"
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/github-org/cli#installation"
    echo "  Windows: scoop install gh"
    echo ""
    echo "After installation, authenticate with: gh auth login"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "Error: gh is not authenticated"
    echo "Please run: gh auth login"
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
ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --json title -q '.title')

if [ -z "$ISSUE_TITLE" ]; then
    echo "Error: Could not fetch issue #$ISSUE_NUMBER"
    exit 1
fi

echo "Issue: $ISSUE_TITLE"

# Step 4: Determine branch name
# Update branch list from remote
echo "Fetching latest branches from remote..."
git fetch --all --prune

# Check for existing branches related to this issue
# Search for branches containing the issue number (e.g., feature/123, issue-123, 123-feature, etc.)
EXISTING_BRANCHES=$(git branch -a | grep -E "(feature[/-]${ISSUE_NUMBER}[^0-9]|feature[/-]${ISSUE_NUMBER}$|issue[-_]${ISSUE_NUMBER}|${ISSUE_NUMBER}[-_])" | head -n 1 | sed 's/^[* ]*//' | sed 's/remotes\/origin\///')

if [ -n "$EXISTING_BRANCHES" ]; then
    # Remove any whitespace
    EXISTING_BRANCHES=$(echo "$EXISTING_BRANCHES" | xargs)
    echo "Found existing branch: $EXISTING_BRANCHES"
    BRANCH_NAME="$EXISTING_BRANCHES"
else
    # Create branch name from issue in feature/{issue-number}-{slug} format
    SLUG=$(echo "$ISSUE_TITLE" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z | cut -c1-50)
    BRANCH_NAME="feature/${ISSUE_NUMBER}-${SLUG}"
    echo "No existing branch found. Suggested branch name: $BRANCH_NAME"
fi

# Step 5: Create worktree in parent directory
WORKTREE_DIR="../worktrees/$BRANCH_NAME"

# Create parent worktrees directory if needed
mkdir -p "../worktrees"

# Check if worktree already exists for this branch
EXISTING_WORKTREE=$(git worktree list | grep "$BRANCH_NAME" | awk '{print $1}')

if [ -n "$EXISTING_WORKTREE" ]; then
    echo "Worktree already exists for branch '$BRANCH_NAME' at: $EXISTING_WORKTREE"
    echo "To use it, run: cd $EXISTING_WORKTREE"
    exit 0
fi

# Also check if directory exists but not registered as worktree
if [ -d "$WORKTREE_DIR" ]; then
    echo "Warning: Directory exists at $WORKTREE_DIR but is not a registered worktree"
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

# Step 6: Create tmux session and initialize spec-kit
SESSION_NAME="${ISSUE_NUMBER}-develop"

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Warning: tmux is not installed. Skipping tmux session creation."
    echo "To install tmux:"
    echo "  macOS:   brew install tmux"
    echo "  Linux:   sudo apt-get install tmux"
else
    # Get absolute path of worktree
    WORKTREE_ABS_PATH=$(cd "$WORKTREE_DIR" && pwd)

    # Check if session already exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "tmux session '$SESSION_NAME' already exists"
        echo "To attach: tmux attach -t $SESSION_NAME"
    else
        # Initialize spec-kit in the worktree directory first
        echo "Initializing spec-kit in worktree..."
        (cd "$WORKTREE_ABS_PATH" && uvx --from git+https://github.com/young-hwang/spec-kit.git specify init --here --script sh --force --ai claude)

        # Create new tmux session in the worktree directory
        echo "Creating tmux session: $SESSION_NAME"
        tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_ABS_PATH"

        # Start claude code in the session
        tmux send-keys -t "$SESSION_NAME" "claude" C-m

        echo "✓ tmux session created: $SESSION_NAME"
        echo "✓ spec-kit initialized and claude code started"
        echo "  To attach: tmux attach -t $SESSION_NAME"
    fi
fi

echo ""

# Step 7: Show results
echo "✓ Worktree created successfully!"
echo "  Location: $WORKTREE_DIR"
echo "  Branch: $BRANCH_NAME"
echo "  Issue: #$ISSUE_NUMBER - $ISSUE_TITLE"
echo ""
echo "To start working:"
echo "  cd $WORKTREE_DIR"
if command -v tmux &> /dev/null && tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "  OR: tmux attach -t $SESSION_NAME"
fi
echo ""
echo "All worktrees:"
git worktree list
```

## Notes

- Worktrees are created in `../worktrees/` to keep the main project clean
- The command handles both issue URLs and issue numbers
- Uses `git fetch` to update branch list instead of `gh` for better reliability
- Automatically detects existing branches associated with the issue (supports `feature/{number}`, `issue-{number}` patterns)
- Creates descriptive branch names from issue title if no branch exists (format: `feature/{number}-{slug}`)
- Supports both local and remote branches
- Automatically creates a tmux session named `{issue-number}-develop` if tmux is installed
- Initializes spec-kit in the worktree directory before creating tmux session
- Automatically starts claude code in the tmux session for immediate development

## Cleanup

To remove a worktree when done:
```bash
git worktree remove ../worktrees/<branch-name>
```

To kill the associated tmux session:
```bash
tmux kill-session -t <issue-number>-develop
```

To remove both worktree and tmux session:
```bash
git worktree remove ../worktrees/<branch-name>
tmux kill-session -t <issue-number>-develop
```

To remove all worktrees for closed issues:
```bash
# List all worktrees and manually remove closed ones
git worktree list
git worktree remove <path>

# List all tmux sessions
tmux ls
tmux kill-session -t <session-name>
```
