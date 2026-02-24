#!/bin/bash
set -euo pipefail

# This script checks if the GitLab CLI (glab) is installed and authentication is configured.

# Check for glab command
if ! command -v glab >/dev/null 2>&1; then
    echo "Error: glab CLI is not installed."
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install glab"
    echo "  Linux:   See https://gitlab.com/gitlab-org/cli#installation"
    echo "  Windows: scoop install glab"
    echo ""
    echo "After installation, authenticate with: glab auth login"
    exit 1
fi

status_output="$(glab auth status 2>&1 || true)"

# Authentication is configured if glab reports logged-in host or token presence.
if echo "$status_output" | grep -Eq 'Logged in to[[:space:]]+' || echo "$status_output" | grep -Eq 'Token found:[[:space:]]+\*+'; then
    if echo "$status_output" | grep -Eq 'API call failed|could not authenticate to one or more of the configured GitLab instances'; then
        echo "✓ glab is installed and authentication is configured."
        echo "Warning: API verification failed (likely network/DNS issue)."
    else
        echo "✓ glab is installed and authenticated."
    fi
    exit 0
fi

echo "Error: glab authentication is not configured."
echo "Please run: glab auth login"
if [ -n "$status_output" ]; then
    echo ""
    echo "glab auth status output:"
    echo "$status_output"
fi
exit 1
