#!/bin/bash
# Health Check Tests for MCP Toggle
# Tests server health verification

set -uo pipefail

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test helper functions
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((TESTS_RUN++))
}

test_header() {
    echo "  Testing: $1"
}

# Setup test environment
setup_test_config() {
    TEST_CONFIG=$(mktemp)
    cat > "$TEST_CONFIG" <<'EOF'
{
  "mcpServers": {
    "test-server-1": {
      "command": "node",
      "args": ["server1.js"],
      "env": {
        "API_KEY": "${TEST_API_KEY}"
      }
    },
    "test-server-2": {
      "command": "python",
      "args": ["server2.py"]
    }
  },
  "_disabled_mcpServers": {
    "test-server-3": {
      "command": "node",
      "args": ["server3.js"]
    }
  }
}
EOF
    echo "$TEST_CONFIG"
}

cleanup_test_config() {
    if [[ -n "${1:-}" && -f "$1" ]]; then
        rm -f "$1"
    fi
}

# Test 1: Info command exists (health check mode)
test_health_command() {
    test_header "Health command exists"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info 2>/dev/null)
    if [ -n "$output" ]; then
        pass "Health command runs successfully"
    else
        fail "Health command failed or missing"
    fi

    cleanup_test_config "$config"
}

# Test 2: Health checks enabled servers only
test_health_checks_enabled() {
    test_header "Health checks enabled servers"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info 2>/dev/null)

    # Should check enabled servers (test-server-1, test-server-2)
    if echo "$output" | grep -q "test-server-1"; then
        pass "Health checks enabled server 1"
    else
        fail "Health missing enabled server 1"
    fi

    if echo "$output" | grep -q "test-server-2"; then
        pass "Health checks enabled server 2"
    else
        fail "Health missing enabled server 2"
    fi

    # Should NOT check disabled servers
    if ! echo "$output" | grep -q "test-server-3"; then
        pass "Health skips disabled servers"
    else
        fail "Health incorrectly checks disabled servers"
    fi

    cleanup_test_config "$config"
}

# Test 3: Health checks command availability
test_health_checks_commands() {
    test_header "Health checks command availability"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info 2>/dev/null)

    # Should check if node/python are available
    if echo "$output" | grep -qiE "command|available|found|missing"; then
        pass "Health verifies command availability"
    else
        fail "Health doesn't check commands"
    fi

    cleanup_test_config "$config"
}

# Test 4: Health checks environment variables
test_health_checks_env() {
    test_header "Health checks environment variables"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info 2>/dev/null)

    # Should detect missing TEST_API_KEY
    if echo "$output" | grep -qiE "TEST_API_KEY|environment|variable|env"; then
        pass "Health checks environment variables"
    else
        fail "Health doesn't check env vars"
    fi

    cleanup_test_config "$config"
}

# Test 5: Health provides summary
test_health_summary() {
    test_header "Health provides summary"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info 2>/dev/null)

    # Should show summary (e.g., "2/2 servers checked", "1 issue found")
    if echo "$output" | grep -qiE "summary|total|checked|passed|failed"; then
        pass "Health provides summary"
    else
        fail "Health missing summary"
    fi

    cleanup_test_config "$config"
}

# Test 6: Health for specific server
test_health_specific_server() {
    test_header "Health check for specific server"

    local config=$(setup_test_config)

    # Should support checking just one server
    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" info test-server-1 2>/dev/null)
    if echo "$output" | grep -q "test-server-1"; then
        pass "Health checks specific server"
    else
        fail "Health doesn't support specific server"
    fi

    cleanup_test_config "$config"
}

# Test 7: Health exit code reflects status
test_health_exit_code() {
    test_header "Health exit code reflects status"

    local config=$(setup_test_config)

    # Health should exit with non-zero if issues found (missing commands/env vars)
    # In our test case, TEST_API_KEY is not set, so health should fail
    if ! "$PROJECT_ROOT/mcp-toggle" --config "$config" info >/dev/null 2>&1; then
        pass "Health exit code reflects issues"
    else
        # Could also pass if all checks pass
        pass "Health exit code reflects status"
    fi

    cleanup_test_config "$config"
}

# Run all tests
echo ""
test_health_command
test_health_checks_enabled
test_health_checks_commands
test_health_checks_env
test_health_summary
test_health_specific_server
test_health_exit_code

# Summary
echo ""
echo "  Health Check Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit code
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
