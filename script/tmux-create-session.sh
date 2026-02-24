#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <session-name> <target-directory>"
    exit 1
fi

SESSION_NAME="$1"
TARGET_DIR="$2"

echo "--- Creating tmux session '$SESSION_NAME'..."

if ! command -v tmux &> /dev/null; then
    echo "Warning: tmux is not installed. Skipping tmux session creation."
    exit 0
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist."
    exit 1
fi

TARGET_ABS_PATH=$(cd "$TARGET_DIR" && pwd)

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "✓ tmux session '$SESSION_NAME' already exists."
        echo "  To attach: tmux attach -t $SESSION_NAME"
    else
        echo "Creating tmux session: $SESSION_NAME"
        tmux new-session -d -s "$SESSION_NAME" -c "$TARGET_ABS_PATH"
        tmux send-keys -t "$SESSION_NAME" "codex" C-m
        
        echo "✓ tmux session created: $SESSION_NAME"
        echo "  To attach: tmux attach -t $SESSION_NAME"
    fi
