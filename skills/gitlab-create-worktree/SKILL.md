---
name: "gitlab-create-worktree"
description: "Migrate and run the workflow from Claude command gitlab/create-worktree.md. Use when asked to perform tasks matching gitlab-create-worktree, for example: Create a git worktree for a GitLab issue in the parent directory to keep the main working directory clean."
---

# GitLab Issue Worktree Creation

## Overview

Use this skill to execute the existing workflow migrated from `gitlab/create-worktree.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# GitLab Issue Worktree Creation

Create a git worktree for a GitLab issue in the parent directory to keep the main working directory clean.

## Command Usage

Provide a GitLab issue URL or issue number: $ARGUMENTS

## Workflow

1. **Check glab CLI installation via `~/.codex/script/check_glab.sh`**
   - Executes the `~/.codex/script/check_glab.sh` script without any arguments to verify `glab` is installed and authenticated.
   - The script will stop execution and provide instructions if `glab` is not found or configured.

2. **Extract and validate issue**
   - Parse issue number from URL or direct number input
   - Fetch issue details using `glab issue view`
   - Display issue title and description

3. **Determine branch name**
   - Fetch latest branches from remote using `git fetch --all --prune`
   - Search for existing branches with the issue number (e.g., `feature/123`, `issue-123`)
   - If no branch exists, create branch name from issue (e.g., `feature/123-feature-description`)

4. **Create Git Worktree**
    - Executes `~/.codex/script/git-create-worktree.sh` passing the determined branch name (e.g., `feature/123-feature-description`) as the sole argument.
    - This script handles the logic for creating the worktree and outputs its path.
    - Example: `~/.codex/script/git-create-worktree.sh <branch_name>`

5. **Create tmux Development Session**
    - Executes `~/.codex/script/tmux-create-session.sh` with two arguments:
      1. Session Name: `{issue_number}-develop`
      2. Target Directory: The path to the newly created worktree directory from step 4.
    - Example: `~/.codex/script/tmux-create-session.sh {issue_number}-develop <path_to_worktree>`

## Notes

- Worktrees are created in `../worktrees/` to keep the main project clean
- The command handles both issue URLs and issue numbers
- Uses `git fetch` to update branch list instead of `glab` for better reliability
- Automatically detects existing branches associated with the issue (supports `feature/{number}`, `issue-{number}` patterns)
- Creates descriptive branch names from issue title if no branch exists (format: `feature/{number}-{slug}`)
- Supports both local and remote branches
- Automatically creates a tmux session named `{issue-number}-develop` if tmux is installed
- Automatically starts codex in the tmux session for immediate development
