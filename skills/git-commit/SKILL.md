---
name: "git-commit"
description: "Create atomic git commits with conventional commit messages. Use when asked to stage changes, run pre-commit checks, split logical changes, and produce clear commit history."
---

# Command: Commit

## Overview

Use this skill to execute the existing workflow migrated from `git/commit.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# Command: Commit

This command helps you create well-formatted commits with conventional commit messages.

## Usage

To run this workflow in Codex, ask:
```
run git-commit skill
```

For skip-verify behavior, ask:
```
run git-commit skill and skip verify checks
```

## What This Command Does

1. Unless specified with `--no-verify`, automatically runs pre-commit checks:
   - Detect package manager (npm, pnpm, yarn, bun) and run appropriate commands
   - Run lint/format checks if available
   - Run build verification if build script exists
   - Update documentation if generation script exists
2. Checks which files are staged with `git status`
3. If 0 files are staged, automatically adds all modified and new files with `git add`
4. Performs a `git diff` to understand what changes are being committed
5. Analyzes the diff to determine if multiple distinct logical changes are present
ONCE user confirm it with yes proceed to the next step
6. If accepted, update a memory file with a short and concise change, and do not update the critical rules section.
7. If multiple distinct changes are detected, suggests breaking the commit into multiple smaller commits
8. For each commit (or the single commit if not split), creates a commit message using conventional commit format

## Best Practices for Commits

- **Verify before committing**: Ensure code is linted, builds correctly, and documentation is updated
- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Split large changes**: If changes touch multiple concerns, split them into separate commits
- **Conventional commit format**: Use the format `<type>: <description>` where type is one of:
  - `feat`: A new feature
  - `fix`: A bug fix
  - `docs`: Documentation changes
  - `style`: Code style changes (formatting, etc)
  - `refactor`: Code changes that neither fix bugs nor add features
  - `perf`: Performance improvements
  - `test`: Adding or fixing tests
  - `chore`: Changes to the build process, tools, etc.
- **Present tense, imperative mood**: Write commit messages as commands (e.g., "add feature" not "added feature")
- **Concise first line**: Keep the first line under 72 characters
