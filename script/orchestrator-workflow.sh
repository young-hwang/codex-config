#!/bin/bash

# GitLab Multi-Agent Workflow Orchestrator Script
# This script runs in the orchestrator tmux session and manages the entire workflow

set -e

ISSUE_NUMBER="$1"
WORKTREE_ABS_PATH="$2"

if [ -z "$ISSUE_NUMBER" ] || [ -z "$WORKTREE_ABS_PATH" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <issue_number> <worktree_path>"
    exit 1
fi

WORKFLOW_FILE="$WORKTREE_ABS_PATH/.workflow/workflow.json"
POLL_INTERVAL=30
MAX_WAIT_MINUTES=60
MAX_TEST_WAIT=30
MAX_ITERATIONS=3

echo "════════════════════════════════════════════════════════"
echo "  Orchestrator - Issue #$ISSUE_NUMBER"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Worktree: $WORKTREE_ABS_PATH"
echo "Starting workflow orchestration..."
echo ""

# Step 1: Launch Developer Agent
SESSION_NAME="${ISSUE_NUMBER}-developer"

echo "Launching developer agent..."

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Warning: Developer session '$SESSION_NAME' already exists"
    echo "To attach: tmux attach -t $SESSION_NAME"
else
    # Initialize spec-kit in the worktree directory
    echo "Initializing spec-kit..."
    (cd "$WORKTREE_ABS_PATH" && uvx --from git+https://github.com/young-hwang/spec-kit.git specify init --here --script sh --force --ai claude 2>/dev/null)

    # Create tmux session
    tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_ABS_PATH"

    # Start claude code in the session
    tmux send-keys -t "$SESSION_NAME" "claude" C-m

    # Wait for claude to start
    sleep 3

    # Get issue details for the prompt
    ISSUE_TITLE=$(jq -r '.issue_title' "$WORKFLOW_FILE" 2>/dev/null || echo "Unknown")
    ISSUE_URL=$(jq -r '.issue_url' "$WORKFLOW_FILE" 2>/dev/null || echo "Unknown")

    # Send comprehensive development prompt
    # This will: 1) Create plan using spec-kit, 2) Implement, 3) Update status
    tmux send-keys -t "$SESSION_NAME" "I need to implement the following GitLab issue:" C-m
    sleep 1
    tmux send-keys -t "$SESSION_NAME" "" C-m
    tmux send-keys -t "$SESSION_NAME" "Issue #$ISSUE_NUMBER: $ISSUE_TITLE" C-m
    tmux send-keys -t "$SESSION_NAME" "URL: $ISSUE_URL" C-m
    tmux send-keys -t "$SESSION_NAME" "" C-m
    tmux send-keys -t "$SESSION_NAME" "Please follow this workflow:" C-m
    tmux send-keys -t "$SESSION_NAME" "1. First, run /spec-kit:plan to create an implementation plan" C-m
    tmux send-keys -t "$SESSION_NAME" "2. Review the issue requirements from GitLab (use glab issue view $ISSUE_NUMBER)" C-m
    tmux send-keys -t "$SESSION_NAME" "3. Implement the feature according to the plan and issue requirements" C-m
    tmux send-keys -t "$SESSION_NAME" "4. When implementation is complete, update the dev-status.json file:" C-m
    tmux send-keys -t "$SESSION_NAME" "   - Set status to 'complete'" C-m
    tmux send-keys -t "$SESSION_NAME" "   - Set ready_for_testing to true" C-m
    tmux send-keys -t "$SESSION_NAME" "   - Set iteration to 1" C-m
    tmux send-keys -t "$SESSION_NAME" "   - List all files_modified" C-m
    tmux send-keys -t "$SESSION_NAME" "   - Add implementation notes" C-m
    tmux send-keys -t "$SESSION_NAME" "" C-m
    tmux send-keys -t "$SESSION_NAME" "The dev-status.json file is located at: .workflow/dev-status.json" C-m
    tmux send-keys -t "$SESSION_NAME" "" C-m
    tmux send-keys -t "$SESSION_NAME" "Start by creating the plan with /spec-kit:plan" C-m
    sleep 1
    tmux send-keys -t "$SESSION_NAME" "" C-m

    echo "✓ Developer agent launched in session: $SESSION_NAME"
    echo "  Development workflow initiated with spec-kit plan"
    echo "  To attach: tmux attach -t $SESSION_NAME"
fi

# Update workflow state
jq '.workflow_state = "developing" | .current_iteration = 1 | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
   "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
   mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

echo ""

# Step 2: Monitor Development Progress
echo "Monitoring development progress..."
echo "(Polling every 30s, max wait 60 minutes)"
echo ""

ELAPSED=0

while [ $ELAPSED -lt $((MAX_WAIT_MINUTES * 60)) ]; do
    if [ -f "$WORKTREE_ABS_PATH/.workflow/dev-status.json" ]; then
        DEV_STATUS=$(jq -r '.status' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "unknown")
        READY_FOR_TEST=$(jq -r '.ready_for_testing' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "false")
        CURRENT_ITERATION=$(jq -r '.iteration' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "0")

        # Show status update every 30s
        echo "[$(date +%H:%M:%S)] Developer status: $DEV_STATUS (iteration: $CURRENT_ITERATION, ready_for_test: $READY_FOR_TEST)"

        if [ "$DEV_STATUS" = "complete" ] && [ "$READY_FOR_TEST" = "true" ]; then
            echo ""
            echo "✓ Development complete! Starting test phase..."
            break
        elif [ "$DEV_STATUS" = "blocked" ]; then
            echo ""
            echo "Error: Development blocked. Check developer session: tmux attach -t $SESSION_NAME"
            exit 1
        fi
    fi

    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ $ELAPSED -ge $((MAX_WAIT_MINUTES * 60)) ]; then
    echo ""
    echo "Error: Development timeout after $MAX_WAIT_MINUTES minutes"
    echo "Developer session is still available: tmux attach -t $SESSION_NAME"
    exit 1
fi

echo ""

# Step 3: Launch Tester Agent
TESTER_SESSION="${ISSUE_NUMBER}-tester"

echo "Launching tester agent..."

if tmux has-session -t "$TESTER_SESSION" 2>/dev/null; then
    echo "Warning: Tester session '$TESTER_SESSION' already exists"
    echo "Killing existing session and creating new one..."
    tmux kill-session -t "$TESTER_SESSION"
fi

# Create tester tmux session
tmux new-session -d -s "$TESTER_SESSION" -c "$WORKTREE_ABS_PATH"

# Start claude code
tmux send-keys -t "$TESTER_SESSION" "claude" C-m

# Wait for claude to start
sleep 2

# Send tester-agent command
tmux send-keys -t "$TESTER_SESSION" "/tester-agent $ISSUE_NUMBER" C-m

echo "✓ Tester agent launched in session: $TESTER_SESSION"
echo "  To attach: tmux attach -t $TESTER_SESSION"
echo ""

# Update workflow state
jq '.workflow_state = "testing" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
   "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
   mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

# Step 4: Coordinate Dev-Test Iteration Cycles
echo "Monitoring test execution and coordinating iterations..."
echo "(Max 3 iterations)"
echo ""

while true; do
    CURRENT_ITERATION=$(jq -r '.current_iteration' "$WORKFLOW_FILE" 2>/dev/null || echo "1")

    if [ "$CURRENT_ITERATION" -gt "$MAX_ITERATIONS" ]; then
        echo "Error: Maximum iterations ($MAX_ITERATIONS) exceeded"
        echo "Manual intervention required."
        echo ""
        jq '.workflow_state = "failed"' "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
           mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"
        exit 1
    fi

    echo "Iteration $CURRENT_ITERATION: Waiting for test results..."

    # Wait for test completion
    TEST_ELAPSED=0
    TEST_STATUS="unknown"

    while [ $TEST_ELAPSED -lt $((MAX_TEST_WAIT * 60)) ]; do
        if [ -f "$WORKTREE_ABS_PATH/.workflow/test-results.json" ]; then
            TEST_STATUS=$(jq -r '.status' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null || echo "unknown")
            TEST_ITERATION=$(jq -r '.iteration' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null || echo "0")

            # Only process results for current iteration
            if [ "$TEST_ITERATION" = "$CURRENT_ITERATION" ]; then
                if [ "$TEST_STATUS" = "passed" ] || [ "$TEST_STATUS" = "failed" ] || [ "$TEST_STATUS" = "error" ]; then
                    break
                fi
            fi
        fi

        sleep $POLL_INTERVAL
        TEST_ELAPSED=$((TEST_ELAPSED + POLL_INTERVAL))

        if [ $((TEST_ELAPSED % 60)) -eq 0 ]; then
            echo "[$(date +%H:%M:%S)] Still waiting for tests... (${TEST_ELAPSED}s elapsed)"
        fi
    done

    if [ $TEST_ELAPSED -ge $((MAX_TEST_WAIT * 60)) ]; then
        echo ""
        echo "Error: Test timeout after $MAX_TEST_WAIT minutes"
        echo "Tester session: tmux attach -t $TESTER_SESSION"
        exit 1
    fi

    # Process test results
    echo ""
    echo "Test Status: $TEST_STATUS"

    if [ "$TEST_STATUS" = "passed" ]; then
        echo "✓ All tests passed!"
        echo ""

        # Get test summary
        TEST_SUMMARY=$(jq -r '.test_summary | "Total: \(.total), Passed: \(.passed), Failed: \(.failed)"' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null)
        echo "Test Summary: $TEST_SUMMARY"

        COVERAGE=$(jq -r '.coverage.lines' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null || echo "N/A")
        echo "Coverage: ${COVERAGE}%"
        echo ""

        # Update workflow state to complete
        jq '.workflow_state = "complete" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
           "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
           mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

        echo "Triggering MR creation in developer session..."
        echo ""

        # Send MR creation command to developer session
        tmux send-keys -t "$SESSION_NAME" "" C-m
        sleep 1
        tmux send-keys -t "$SESSION_NAME" "All tests passed! Now create the merge request:" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "1. Stage and commit all changes with a proper commit message" C-m
        tmux send-keys -t "$SESSION_NAME" "2. Use /create-mr to create the merge request" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "The commit message should include:" C-m
        tmux send-keys -t "$SESSION_NAME" "- Issue reference: Resolves #$ISSUE_NUMBER" C-m
        tmux send-keys -t "$SESSION_NAME" "- Summary of changes" C-m
        tmux send-keys -t "$SESSION_NAME" "- Test results (all passed)" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "Create the commit and MR now." C-m
        sleep 1
        tmux send-keys -t "$SESSION_NAME" "" C-m

        echo "✓ MR creation triggered in developer session"
        echo "Workflow complete!"
        echo ""
        break

    elif [ "$TEST_STATUS" = "failed" ]; then
        echo "✗ Tests failed in iteration $CURRENT_ITERATION"
        echo ""

        # Show failure details
        FAILED_COUNT=$(jq -r '.test_summary.failed' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null || echo "0")
        echo "Failed tests: $FAILED_COUNT"
        echo ""

        if [ "$FAILED_COUNT" != "0" ]; then
            echo "Failures:"
            jq -r '.failures[] | "  - \(.test_name)\n    \(.error_message)"' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null
            echo ""
        fi

        FEEDBACK=$(jq -r '.feedback_for_developer' "$WORKTREE_ABS_PATH/.workflow/test-results.json" 2>/dev/null)
        echo "Feedback for developer:"
        echo "$FEEDBACK"
        echo ""

        if [ "$CURRENT_ITERATION" -ge "$MAX_ITERATIONS" ]; then
            echo "Maximum iterations reached. Workflow failed."
            jq '.workflow_state = "failed"' "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
               mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"
            exit 1
        fi

        # Increment iteration and notify developer to fix
        NEXT_ITERATION=$((CURRENT_ITERATION + 1))

        jq '.current_iteration = '$NEXT_ITERATION' | .workflow_state = "developing" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
           "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
           mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

        # Reset dev status for rework
        jq '.iteration = '$NEXT_ITERATION' | .status = "in_progress" | .ready_for_testing = false | .start_time = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'" | .end_time = null' \
           "$WORKTREE_ABS_PATH/.workflow/dev-status.json" > "$WORKTREE_ABS_PATH/.workflow/dev-status.json.tmp" && \
           mv "$WORKTREE_ABS_PATH/.workflow/dev-status.json.tmp" "$WORKTREE_ABS_PATH/.workflow/dev-status.json"

        echo "Starting iteration $NEXT_ITERATION..."
        echo "Sending feedback to developer session..."
        echo ""

        # Send feedback to developer session
        tmux send-keys -t "$SESSION_NAME" "" C-m
        sleep 1
        tmux send-keys -t "$SESSION_NAME" "The tests have failed. Here is the feedback:" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "Failed tests: $FAILED_COUNT out of total" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "Feedback:" C-m
        tmux send-keys -t "$SESSION_NAME" "$FEEDBACK" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "Please:" C-m
        tmux send-keys -t "$SESSION_NAME" "1. Review the test failures in .workflow/test-results.json" C-m
        tmux send-keys -t "$SESSION_NAME" "2. Review detailed test output in .workflow/logs/test-output-iteration-${CURRENT_ITERATION}.log" C-m
        tmux send-keys -t "$SESSION_NAME" "3. Fix the issues" C-m
        tmux send-keys -t "$SESSION_NAME" "4. Update dev-status.json when done:" C-m
        tmux send-keys -t "$SESSION_NAME" "   - Set iteration to $NEXT_ITERATION" C-m
        tmux send-keys -t "$SESSION_NAME" "   - Set status to 'complete'" C-m
        tmux send-keys -t "$SESSION_NAME" "   - Set ready_for_testing to true" C-m
        tmux send-keys -t "$SESSION_NAME" "" C-m
        tmux send-keys -t "$SESSION_NAME" "Start fixing the issues now." C-m
        sleep 1
        tmux send-keys -t "$SESSION_NAME" "" C-m

        echo "✓ Feedback sent to developer"
        echo ""

        # Wait for developer to fix and signal completion again
        echo "Monitoring developer progress (iteration $NEXT_ITERATION)..."
        ELAPSED=0
        while [ $ELAPSED -lt $((MAX_WAIT_MINUTES * 60)) ]; do
            DEV_STATUS=$(jq -r '.status' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "unknown")
            READY_FOR_TEST=$(jq -r '.ready_for_testing' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "false")
            DEV_ITERATION=$(jq -r '.iteration' "$WORKTREE_ABS_PATH/.workflow/dev-status.json" 2>/dev/null || echo "0")

            if [ "$DEV_ITERATION" = "$NEXT_ITERATION" ]; then
                echo "[$(date +%H:%M:%S)] Developer status: $DEV_STATUS (ready_for_test: $READY_FOR_TEST)"

                if [ "$DEV_STATUS" = "complete" ] && [ "$READY_FOR_TEST" = "true" ]; then
                    echo ""
                    echo "✓ Developer fixes complete! Restarting tests..."
                    echo ""

                    # Restart tester
                    if tmux has-session -t "$TESTER_SESSION" 2>/dev/null; then
                        tmux kill-session -t "$TESTER_SESSION"
                    fi

                    tmux new-session -d -s "$TESTER_SESSION" -c "$WORKTREE_ABS_PATH"
                    tmux send-keys -t "$TESTER_SESSION" "claude" C-m
                    sleep 2
                    tmux send-keys -t "$TESTER_SESSION" "/tester-agent $ISSUE_NUMBER" C-m

                    jq '.workflow_state = "testing"' "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
                       mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

                    break
                elif [ "$DEV_STATUS" = "blocked" ]; then
                    echo ""
                    echo "Error: Developer blocked. Check session: tmux attach -t $SESSION_NAME"
                    exit 1
                fi
            fi

            sleep $POLL_INTERVAL
            ELAPSED=$((ELAPSED + POLL_INTERVAL))
        done

        if [ $ELAPSED -ge $((MAX_WAIT_MINUTES * 60)) ]; then
            echo ""
            echo "Error: Developer timeout in iteration $NEXT_ITERATION"
            exit 1
        fi

        # Continue to next iteration (loop will restart test monitoring)
        continue

    elif [ "$TEST_STATUS" = "error" ]; then
        echo "✗ Test execution error"
        echo ""
        echo "Check tester session: tmux attach -t $TESTER_SESSION"
        echo "Check logs: $WORKTREE_ABS_PATH/.workflow/logs/"

        jq '.workflow_state = "failed"' "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && \
           mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"

        exit 1
    else
        echo "Error: Unknown test status: $TEST_STATUS"
        exit 1
    fi
done

# Step 5: Final Summary
echo "════════════════════════════════════════════════════════"
echo "  Multi-Agent Workflow Complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Issue: #$ISSUE_NUMBER"
echo "Worktree: $WORKTREE_ABS_PATH"
echo ""

# Show iteration history
echo "Iteration History:"
jq -r '.iterations[] | "  Iteration \(.iteration): \(.outcome) (\(.test_failures) failures)"' \
   "$WORKTREE_ABS_PATH/.workflow/iteration-history.json" 2>/dev/null || echo "  No history recorded"

echo ""
echo "Active Sessions (available for inspection):"
echo "  Developer: tmux attach -t ${ISSUE_NUMBER}-developer"
echo "  Tester:    tmux attach -t ${ISSUE_NUMBER}-tester"
echo ""
echo "Workflow State: $WORKTREE_ABS_PATH/.workflow/"
echo ""
echo "Next Steps:"
echo "  1. Developer session will create MR automatically"
echo "  2. Review the MR and merge when ready"
echo "  3. Cleanup: /clean-worktree $ISSUE_NUMBER"
echo ""
echo "════════════════════════════════════════════════════════"
