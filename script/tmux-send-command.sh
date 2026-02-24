#!/bin/bash

# A script to send a command to a specific tmux session.

# Check for the correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <session-name> <command>"
    exit 1
fi

SESSION_NAME="$1"
COMMAND_TO_SEND="$2"

# Check if the session exists
if ! tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
    echo "Error: Tmux session '$SESSION_NAME' not found."
    exit 1
fi

# Send the command to the tmux session
# The 'C-m' at the end simulates pressing the Enter key.
tmux send-keys -t "$SESSION_NAME" "$COMMAND_TO_SEND" C-m
tmux send-keys -t "" C-m

echo "Command sent to tmux session '$SESSION_NAME'."
