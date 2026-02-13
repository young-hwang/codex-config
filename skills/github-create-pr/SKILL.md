---
name: "github-create-pr"
description: "Migrate and run the workflow from Claude command github/create-pr.md. Use when asked to perform tasks matching github-create-pr, for example: Create a new branch, commit changes, and submit a pull request."
---

# Create Pull Request Command

## Overview

Use this skill to execute the existing workflow migrated from `github/create-pr.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# Create Pull Request Command

Create a new branch, commit changes, and submit a pull request.

## Behavior
- Creates a new branch based on current changes
- Formats modified files using Biome
- Analyzes changes and automatically splits into logical commits when appropriate
- Each commit focuses on a single logical change or feature
- Creates descriptive commit messages for each logical unit
- Pushes branch to remote
- Creates pull request with proper summary and test plan

## Guidelines for Automatic Commit Splitting
- Split commits by feature, component, or concern
- Keep related file changes together in the same commit
- Separate refactoring from feature additions
- Ensure each commit can be understood independently
- Multiple unrelated changes should be split into separate commits
