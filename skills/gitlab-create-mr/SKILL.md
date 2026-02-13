---
name: "gitlab-create-mr"
description: "Create a GitLab merge request from current changes. Use when asked to branch, format, split commits by concern, push, and open an MR with summary and test plan."
---

# Create Pull Request Command

## Overview

Use this skill to execute the existing workflow migrated from `gitlab/create-mr.md`.
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
- Creates merge request with proper summary and test plan, If a merge request template exists, it will be utilized.

## Guidelines for Automatic Commit Splitting
- Split commits by feature, component, or concern
- Keep related file changes together in the same commit
- Separate refactoring from feature additions
- Ensure each commit can be understood independently
- Multiple unrelated changes should be split into separate commits
