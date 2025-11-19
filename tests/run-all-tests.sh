#!/bin/bash
# MCP Toggle Test Runner
# Runs all test suites and reports results

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "MCP Toggle Test Suite"
echo "======================================"
echo ""

# Function to run a test script
run_test_script() {
    local test_script="$1"
    local test_name=$(basename "$test_script" .sh)

    echo "Running: $test_name"

    if bash "$test_script"; then
        echo -e "${GREEN}✓${NC} $test_name passed"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} $test_name failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    echo ""
}

# Find and run all test scripts
for test_script in "$SCRIPT_DIR"/test-*.sh; do
    if [[ -f "$test_script" ]]; then
        run_test_script "$test_script"
    fi
done

# Summary
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
else
    echo -e "Failed:       $FAILED_TESTS"
fi
echo ""

# Exit with appropriate code
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
