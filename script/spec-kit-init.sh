#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-directory>"
    exit 1
fi

TARGET_DIR="$1"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo "--- Initializing spec-kit in $TARGET_DIR..."

TARGET_ABS_PATH=$(cd "$TARGET_DIR" && pwd)

(cd "$TARGET_ABS_PATH" && uvx --from git+https://github.com/young-hwang/spec-kit.git specify init --here --script sh --force --ai claude) &>/dev/null

echo "✓ spec-kit initialized."
