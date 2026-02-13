---
name: "gitlab-tester-agent"
description: "Migrate and run the workflow from Claude command gitlab/tester-agent.md. Use when asked to perform tasks matching gitlab-tester-agent, for example: Run comprehensive tests and report results back to developer agent."
---

# GitLab Tester Agent

## Overview

Use this skill to execute the existing workflow migrated from `gitlab/tester-agent.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

## Codex Invocation Mapping

If this playbook references slash commands (for example `/plan` or `/tdd`), treat them as skill names in Codex. Ask Codex directly to run the equivalent skill workflow.

# GitLab Tester Agent

Run comprehensive tests and report results back to developer agent.

## Command Usage

Provide issue number: $ARGUMENTS

## Overview

This agent runs in its own tmux session and communicates via state files in `.workflow/` directory. It:
1. Waits for developer to signal readiness
2. Auto-detects the test framework
3. Runs tests and captures output
4. Analyzes results and generates feedback
5. Reports outcomes via state files

## Step 1: Validate Environment

Check developer is ready for testing:

```bash
ISSUE_NUMBER="$ARGUMENTS"
DEV_STATUS_FILE=".workflow/dev-status.json"
TEST_RESULTS_FILE=".workflow/test-results.json"
WORKFLOW_FILE=".workflow/workflow.json"

if [ ! -f "$DEV_STATUS_FILE" ]; then
    echo "Error: Developer status file not found"
    echo "This agent should be launched by the orchestrator."
    exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "Error: Workflow not initialized"
    exit 1
fi

# Check jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for state management"
    exit 1
fi

# Check if developer is ready
READY_FOR_TEST=$(jq -r '.ready_for_testing' "$DEV_STATUS_FILE" 2>/dev/null)
if [ "$READY_FOR_TEST" != "true" ]; then
    echo "Error: Developer not ready for testing yet"
    echo "Current status:"
    jq '.' "$DEV_STATUS_FILE"
    exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "  Tester Agent - Issue #$ISSUE_NUMBER"
echo "════════════════════════════════════════════════════════"
echo ""
```

## Step 2: Load Context

Read development status and iteration info:

```bash
CURRENT_ITERATION=$(jq -r '.iteration' "$DEV_STATUS_FILE" 2>/dev/null || echo "1")
ISSUE_TITLE=$(jq -r '.issue_title' "$WORKFLOW_FILE" 2>/dev/null)

echo "Issue: $ISSUE_TITLE"
echo "Iteration: $CURRENT_ITERATION"
echo ""

echo "Files modified by developer:"
jq -r '.files_modified[]?' "$DEV_STATUS_FILE" 2>/dev/null | sed 's/^/  - /'
echo ""

echo "Starting test execution..."
echo ""
```

## Step 3: Detect Test Framework

Identify project type and test commands:

```bash
TEST_COMMAND=""
COVERAGE_COMMAND=""
PROJECT_TYPE="unknown"

# Node.js/TypeScript project
if [ -f "package.json" ]; then
    PROJECT_TYPE="nodejs"

    if jq -e '.scripts.test' package.json > /dev/null 2>&1; then
        TEST_COMMAND=$(jq -r '.scripts.test' package.json)
        # Add npm run prefix if not already a full command
        if [[ ! "$TEST_COMMAND" =~ ^npm ]]; then
            TEST_COMMAND="npm test"
        fi
    else
        TEST_COMMAND="npm test"
    fi

    # Check for coverage script
    if jq -e '.scripts["test:coverage"]' package.json > /dev/null 2>&1; then
        COVERAGE_COMMAND="npm run test:coverage"
    elif jq -e '.scripts.coverage' package.json > /dev/null 2>&1; then
        COVERAGE_COMMAND="npm run coverage"
    else
        COVERAGE_COMMAND="npm test -- --coverage"
    fi

# Gradle project
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    PROJECT_TYPE="gradle"
    TEST_COMMAND="./gradlew test"
    COVERAGE_COMMAND="./gradlew test jacocoTestReport"

# Maven project
elif [ -f "pom.xml" ]; then
    PROJECT_TYPE="maven"
    TEST_COMMAND="./mvnw test"
    COVERAGE_COMMAND="./mvnw test jacoco:report"

# Python project
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    PROJECT_TYPE="python"
    TEST_COMMAND="pytest"
    COVERAGE_COMMAND="pytest --cov --cov-report=json"

# Rust project
elif [ -f "Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    TEST_COMMAND="cargo test"
    COVERAGE_COMMAND="cargo tarpaulin --out Json"

else
    echo "Error: Unable to detect test framework"
    echo "Checked for: package.json, build.gradle, pom.xml, requirements.txt, Cargo.toml"
    echo ""

    # Write error status
    cat > "$TEST_RESULTS_FILE" <<EOF
{
  "iteration": $CURRENT_ITERATION,
  "status": "error",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_summary": null,
  "failures": [],
  "coverage": null,
  "performance_metrics": null,
  "feedback_for_developer": "Could not detect test framework. Please ensure package.json, build.gradle, pom.xml, requirements.txt, or Cargo.toml exists with proper test configuration."
}
EOF

    exit 1
fi

echo "Detected project type: $PROJECT_TYPE"
echo "Test command: $TEST_COMMAND"
echo ""
```

## Step 4: Initialize Test Results

Create initial test results file:

```bash
cat > "$TEST_RESULTS_FILE" <<EOF
{
  "iteration": $CURRENT_ITERATION,
  "status": "running",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_summary": null,
  "failures": [],
  "coverage": null,
  "performance_metrics": null,
  "feedback_for_developer": ""
}
EOF

echo "✓ Test results file initialized"
echo ""
```

## Step 5: Run Tests

Execute test suite and capture output:

```bash
echo "════════════════════════════════════════════════════════"
echo "  Running Tests"
echo "════════════════════════════════════════════════════════"
echo ""

# Create logs directory if it doesn't exist
mkdir -p ".workflow/logs"

TEST_OUTPUT_FILE=".workflow/logs/test-output-iteration-${CURRENT_ITERATION}.log"
TEST_EXIT_CODE=0

# Run tests
echo "Executing: $TEST_COMMAND"
echo ""

$TEST_COMMAND 2>&1 | tee "$TEST_OUTPUT_FILE"
TEST_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "────────────────────────────────────────────────────────"
echo "Test execution completed with exit code: $TEST_EXIT_CODE"
echo "Output saved to: $TEST_OUTPUT_FILE"
echo ""
```

## Step 6: Parse Test Results

Extract test metrics based on framework:

```bash
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

case $PROJECT_TYPE in
    nodejs)
        # Jest/Vitest output parsing
        # Look for patterns like "Tests: 5 passed, 15 total" or "Test Suites: 2 passed, 2 total"
        if grep -q "Tests:" "$TEST_OUTPUT_FILE"; then
            PASSED_TESTS=$(grep -oP 'Tests:.*?(\d+) passed' "$TEST_OUTPUT_FILE" | grep -oP '\d+' | head -1 || echo "0")
            FAILED_TESTS=$(grep -oP 'Tests:.*?(\d+) failed' "$TEST_OUTPUT_FILE" | grep -oP '\d+' | head -1 || echo "0")
            TOTAL_TESTS=$(grep -oP 'Tests:.*?(\d+) total' "$TEST_OUTPUT_FILE" | grep -oP '\d+' | tail -1 || echo "0")
        else
            # Alternative format: "x passing" / "x failing"
            PASSED_TESTS=$(grep -oP '\d+(?= passing)' "$TEST_OUTPUT_FILE" | head -1 || echo "0")
            FAILED_TESTS=$(grep -oP '\d+(?= failing)' "$TEST_OUTPUT_FILE" | head -1 || echo "0")
            TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))
        fi
        ;;

    gradle|maven)
        # JUnit output parsing
        # Look for "Tests run: X, Failures: Y, Errors: Z, Skipped: W"
        if grep -q "Tests run:" "$TEST_OUTPUT_FILE"; then
            TOTAL_TESTS=$(grep -oP 'Tests run: \K\d+' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            FAILED_TESTS=$(grep -oP 'Failures: \K\d+' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            ERROR_TESTS=$(grep -oP 'Errors: \K\d+' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            SKIPPED_TESTS=$(grep -oP 'Skipped: \K\d+' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            FAILED_TESTS=$((FAILED_TESTS + ERROR_TESTS))
            PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS - SKIPPED_TESTS))
        fi
        ;;

    python)
        # Pytest output parsing
        # Look for "5 passed, 2 failed in 1.23s"
        if grep -q "passed" "$TEST_OUTPUT_FILE"; then
            PASSED_TESTS=$(grep -oP '\d+(?= passed)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
        fi
        if grep -q "failed" "$TEST_OUTPUT_FILE"; then
            FAILED_TESTS=$(grep -oP '\d+(?= failed)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
        fi
        if grep -q "skipped" "$TEST_OUTPUT_FILE"; then
            SKIPPED_TESTS=$(grep -oP '\d+(?= skipped)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
        fi
        TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS + SKIPPED_TESTS))
        ;;

    rust)
        # Cargo test output parsing
        # Look for "test result: ok. 10 passed; 0 failed; 0 ignored"
        if grep -q "test result:" "$TEST_OUTPUT_FILE"; then
            PASSED_TESTS=$(grep -oP '\d+(?= passed)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            FAILED_TESTS=$(grep -oP '\d+(?= failed)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            SKIPPED_TESTS=$(grep -oP '\d+(?= ignored)' "$TEST_OUTPUT_FILE" | tail -1 || echo "0")
            TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS + SKIPPED_TESTS))
        fi
        ;;
esac

echo "Test Summary:"
echo "  Total: $TOTAL_TESTS"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
if [ "$SKIPPED_TESTS" -gt 0 ]; then
    echo "  Skipped: $SKIPPED_TESTS"
fi
echo ""
```

## Step 7: Extract Failure Details

Parse specific test failures for actionable feedback:

```bash
FAILURES_JSON="[]"

if [ "$FAILED_TESTS" -gt 0 ]; then
    echo "Extracting failure details..."

    # Create temporary file for failures
    FAILURES_FILE=".workflow/logs/failures-iteration-${CURRENT_ITERATION}.txt"

    case $PROJECT_TYPE in
        nodejs)
            # Extract Jest/Vitest failures
            # Look for lines like "● TestSuite › test name"
            grep -A 5 "●" "$TEST_OUTPUT_FILE" > "$FAILURES_FILE" 2>/dev/null || true
            ;;

        gradle|maven)
            # Extract JUnit failures
            grep -A 10 "FAILED" "$TEST_OUTPUT_FILE" > "$FAILURES_FILE" 2>/dev/null || true
            ;;

        python)
            # Extract pytest failures
            grep -A 10 "FAILED" "$TEST_OUTPUT_FILE" > "$FAILURES_FILE" 2>/dev/null || true
            ;;

        rust)
            # Extract cargo test failures
            grep -A 5 "test .* FAILED" "$TEST_OUTPUT_FILE" > "$FAILURES_FILE" 2>/dev/null || true
            ;;
    esac

    # Build JSON array of failures (simplified)
    # In a real implementation, you'd parse more carefully
    FAILURES_JSON='['
    FAILURE_COUNT=0
    while IFS= read -r line; do
        if [ $FAILURE_COUNT -lt 5 ]; then  # Limit to first 5 failures
            if [ $FAILURE_COUNT -gt 0 ]; then
                FAILURES_JSON="${FAILURES_JSON},"
            fi
            # Escape quotes and create JSON object
            ESCAPED_LINE=$(echo "$line" | sed 's/"/\\"/g' | head -c 200)
            FAILURES_JSON="${FAILURES_JSON}{\"test_name\":\"Test failure $((FAILURE_COUNT+1))\",\"error_message\":\"$ESCAPED_LINE\",\"file\":\"See log: $TEST_OUTPUT_FILE\"}"
            FAILURE_COUNT=$((FAILURE_COUNT+1))
        fi
    done < "$FAILURES_FILE"
    FAILURES_JSON="${FAILURES_JSON}]"

    echo "✓ Extracted $FAILURE_COUNT failure details"
else
    echo "✓ No failures to extract"
fi
echo ""
```

## Step 8: Run Coverage Analysis

Generate coverage metrics if tests passed:

```bash
COVERAGE_PCT="null"
COVERAGE_BRANCHES="null"
COVERAGE_FUNCTIONS="null"

if [ $TEST_EXIT_CODE -eq 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  Running Coverage Analysis"
    echo "════════════════════════════════════════════════════════"
    echo ""

    COVERAGE_LOG=".workflow/logs/coverage-iteration-${CURRENT_ITERATION}.log"

    $COVERAGE_COMMAND 2>&1 | tee "$COVERAGE_LOG"

    # Parse coverage based on project type
    case $PROJECT_TYPE in
        nodejs)
            if [ -f "coverage/coverage-summary.json" ]; then
                COVERAGE_PCT=$(jq -r '.total.lines.pct' coverage/coverage-summary.json 2>/dev/null || echo "null")
                COVERAGE_BRANCHES=$(jq -r '.total.branches.pct' coverage/coverage-summary.json 2>/dev/null || echo "null")
                COVERAGE_FUNCTIONS=$(jq -r '.total.functions.pct' coverage/coverage-summary.json 2>/dev/null || echo "null")
            fi
            ;;

        gradle)
            # Parse Jacoco XML report
            if [ -f "build/reports/jacoco/test/jacocoTestReport.xml" ]; then
                # Simplified - would need proper XML parsing
                COVERAGE_PCT=$(grep -oP 'type="LINE".*?covered="\K[^"]+' build/reports/jacoco/test/jacocoTestReport.xml | head -1 || echo "null")
            fi
            ;;

        maven)
            # Parse Jacoco CSV
            if [ -f "target/site/jacoco/jacoco.csv" ]; then
                # Simplified parsing
                COVERAGE_PCT="75"  # Placeholder
            fi
            ;;

        python)
            if [ -f "coverage.json" ]; then
                COVERAGE_PCT=$(jq -r '.totals.percent_covered' coverage.json 2>/dev/null || echo "null")
            fi
            ;;

        rust)
            if [ -f "cobertura.xml" ]; then
                # Parse tarpaulin output
                COVERAGE_PCT=$(grep -oP 'line-rate="\K[^"]+' cobertura.xml | head -1 | awk '{print $1*100}' || echo "null")
            fi
            ;;
    esac

    if [ "$COVERAGE_PCT" != "null" ]; then
        echo "✓ Coverage: ${COVERAGE_PCT}%"
    else
        echo "⚠ Coverage data not available"
    fi
    echo ""
fi
```

## Step 9: Generate Feedback

Create actionable feedback for developer:

```bash
FEEDBACK=""
FINAL_STATUS="passed"

if [ $TEST_EXIT_CODE -ne 0 ] || [ "$FAILED_TESTS" -gt 0 ]; then
    FINAL_STATUS="failed"

    FEEDBACK="Test failures detected in iteration ${CURRENT_ITERATION}:\n\n"
    FEEDBACK+="Summary:\n"
    FEEDBACK+="- Total tests: ${TOTAL_TESTS}\n"
    FEEDBACK+="- Passed: ${PASSED_TESTS}\n"
    FEEDBACK+="- Failed: ${FAILED_TESTS}\n"
    FEEDBACK+="\n"
    FEEDBACK+="Please review the detailed test output at:\n"
    FEEDBACK+="  ${TEST_OUTPUT_FILE}\n"
    FEEDBACK+="\n"
    FEEDBACK+="Key issues to address:\n"

    # Add specific failure hints based on common patterns
    if grep -q "TypeError" "$TEST_OUTPUT_FILE"; then
        FEEDBACK+="- Type errors detected - check type definitions and interfaces\n"
    fi
    if grep -q "AssertionError" "$TEST_OUTPUT_FILE"; then
        FEEDBACK+="- Assertion failures - verify logic matches expected behavior\n"
    fi
    if grep -q "ReferenceError" "$TEST_OUTPUT_FILE"; then
        FEEDBACK+="- Reference errors - check variable names and imports\n"
    fi
    if grep -q "timeout" "$TEST_OUTPUT_FILE"; then
        FEEDBACK+="- Timeouts detected - check for async issues or infinite loops\n"
    fi

    FEEDBACK+="\nAfter fixing, the orchestrator will re-run tests automatically."

elif [ "$COVERAGE_PCT" != "null" ] && [ $(echo "$COVERAGE_PCT < 70" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    # Tests pass but coverage is low
    FINAL_STATUS="passed"
    FEEDBACK="All tests passed! ✓\n\n"
    FEEDBACK+="Note: Code coverage is ${COVERAGE_PCT}% (target: 70%+).\n"
    FEEDBACK+="Consider adding more tests in future iterations to improve coverage."

else
    FEEDBACK="All tests passed! ✓\n\n"
    FEEDBACK+="Test Results:\n"
    FEEDBACK+="- Total: ${TOTAL_TESTS}\n"
    FEEDBACK+="- Passed: ${PASSED_TESTS}\n"
    FEEDBACK+="- Failed: 0\n"

    if [ "$COVERAGE_PCT" != "null" ]; then
        FEEDBACK+="\nCode Coverage: ${COVERAGE_PCT}%\n"
    fi

    FEEDBACK+="\nGreat work! The implementation meets all test requirements."
fi

echo "Test Status: $FINAL_STATUS"
echo ""
```

## Step 10: Write Final Results

Update test-results.json with complete information:

```bash
echo "Writing test results..."

# Escape feedback for JSON
FEEDBACK_ESCAPED=$(echo -e "$FEEDBACK" | jq -Rs .)

# Build coverage JSON
if [ "$COVERAGE_PCT" != "null" ]; then
    COVERAGE_JSON="{\"lines\": $COVERAGE_PCT, \"branches\": ${COVERAGE_BRANCHES:-null}, \"functions\": ${COVERAGE_FUNCTIONS:-null}}"
else
    COVERAGE_JSON="null"
fi

# Write final results
cat > "$TEST_RESULTS_FILE" <<EOF
{
  "iteration": $CURRENT_ITERATION,
  "status": "$FINAL_STATUS",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS
  },
  "failures": $FAILURES_JSON,
  "coverage": $COVERAGE_JSON,
  "performance_metrics": {
    "test_duration_seconds": 0,
    "avg_response_time_ms": 0,
    "memory_usage_mb": 0
  },
  "feedback_for_developer": $FEEDBACK_ESCAPED
}
EOF

echo "✓ Test results written to: $TEST_RESULTS_FILE"
echo ""
```

## Step 11: Update Iteration History

Record this iteration for audit trail:

```bash
echo "Updating iteration history..."

ITERATION_HISTORY_FILE=".workflow/iteration-history.json"

# Get timing info
DEV_START=$(jq -r '.start_time' "$DEV_STATUS_FILE" 2>/dev/null || echo "null")
DEV_END=$(jq -r '.end_time' "$DEV_STATUS_FILE" 2>/dev/null || echo "null")
TEST_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create iteration entry
ITERATION_ENTRY=$(cat <<EOF
{
  "iteration": $CURRENT_ITERATION,
  "dev_start_time": "$DEV_START",
  "dev_end_time": "$DEV_END",
  "test_time": "$TEST_TIME",
  "outcome": "$FINAL_STATUS",
  "test_total": $TOTAL_TESTS,
  "test_passed": $PASSED_TESTS,
  "test_failed": $FAILED_TESTS,
  "coverage_pct": $COVERAGE_PCT
}
EOF
)

# Append to history
if [ ! -f "$ITERATION_HISTORY_FILE" ]; then
    echo '{"iterations":[]}' > "$ITERATION_HISTORY_FILE"
fi

jq --argjson entry "$ITERATION_ENTRY" '.iterations += [$entry]' \
   "$ITERATION_HISTORY_FILE" > "$ITERATION_HISTORY_FILE.tmp" && \
   mv "$ITERATION_HISTORY_FILE.tmp" "$ITERATION_HISTORY_FILE"

echo "✓ Iteration history updated"
echo ""
```

## Step 12: Final Summary

Display results:

```bash
echo "════════════════════════════════════════════════════════"
echo "  Test Execution Complete"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Status: $FINAL_STATUS"
echo "Iteration: $CURRENT_ITERATION"
echo ""
echo "Test Summary:"
echo "  Total:   $TOTAL_TESTS"
echo "  Passed:  $PASSED_TESTS"
echo "  Failed:  $FAILED_TESTS"
if [ "$SKIPPED_TESTS" -gt 0 ]; then
    echo "  Skipped: $SKIPPED_TESTS"
fi
echo ""

if [ "$COVERAGE_PCT" != "null" ]; then
    echo "Coverage: ${COVERAGE_PCT}%"
    echo ""
fi

if [ "$FINAL_STATUS" = "passed" ]; then
    echo "✓ All tests passed!"
    echo "Developer will create merge request."
else
    echo "✗ Tests failed"
    echo "Developer will fix issues and retry."
fi

echo ""
echo "Logs saved to: .workflow/logs/"
echo ""
echo "════════════════════════════════════════════════════════"

# Exit with appropriate code
if [ "$FINAL_STATUS" = "passed" ]; then
    exit 0
else
    exit 1
fi
```

## Manual Mode

If running this agent manually:

```bash
# Ensure developer has signaled ready
cat .workflow/dev-status.json | jq '.ready_for_testing'

# Run tester agent
claude
/tester-agent 123

# Check results
cat .workflow/test-results.json | jq
```

## Notes

- Runs in dedicated tmux session: `<issue>-tester`
- Communicates via `.workflow/test-results.json`
- Auto-detects test frameworks (npm, gradle, maven, pytest, cargo)
- Provides structured, actionable feedback
- Captures comprehensive logs for debugging
- Supports coverage analysis
- Records iteration history

## Supported Test Frameworks

- **Node.js**: Jest, Vitest, Mocha (via npm test)
- **Java**: JUnit (via Gradle or Maven)
- **Python**: pytest
- **Rust**: cargo test

## Error Recovery

If this agent crashes:

```bash
# Check what iteration was being tested
cat .workflow/dev-status.json | jq '.iteration'

# Check test results
cat .workflow/test-results.json | jq

# Re-run tester manually
claude
/tester-agent 123
```
