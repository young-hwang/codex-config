---
name: "update-docs"
description: "Migrate and run the workflow from Claude command update-docs.md. Use when asked to perform tasks matching update-docs, for example: Sync documentation from source-of-truth:"
---

# Update Documentation

## Overview

Use this skill to execute the existing workflow migrated from `update-docs.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

# Update Documentation

Sync documentation from source-of-truth:

1. Read package.json scripts section
   - Generate scripts reference table
   - Include descriptions from comments

2. Read .env.example
   - Extract all environment variables
   - Document purpose and format

3. Generate docs/CONTRIB.md with:
   - Development workflow
   - Available scripts
   - Environment setup
   - Testing procedures

4. Generate docs/RUNBOOK.md with:
   - Deployment procedures
   - Monitoring and alerts
   - Common issues and fixes
   - Rollback procedures

5. Identify obsolete documentation:
   - Find docs not modified in 90+ days
   - List for manual review

6. Show diff summary

Single source of truth: package.json and .env.example
