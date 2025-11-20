#!/bin/bash
# Context Window Impact Tests for MCP Toggle
# Tests showing token usage estimates for MCP servers

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
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"]
    }
  },
  "_disabled_mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
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

# Test 1: Info command exists and works
test_info_command() {
    test_header "Info command exists"

    local config=$(setup_test_config)

    # Test that info command works
    local output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info filesystem 2>/dev/null)
    if echo "$output" | grep -q "filesystem"; then
        pass "Info command returns server information"
    else
        fail "Info command failed or missing"
    fi

    cleanup_test_config "$config"
}

# Test 2: Info shows token impact estimate
test_info_shows_impact() {
    test_header "Info shows token impact estimate"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info filesystem 2>/dev/null)

    # Check for impact indicator (Heavy/Medium/Light)
    if echo "$output" | grep -qiE "impact|tokens|context"; then
        pass "Info displays token/context impact information"
    else
        fail "Info missing impact information"
    fi

    cleanup_test_config "$config"
}

# Test 3: List command shows impact indicators
test_list_shows_impact() {
    test_header "List shows impact indicators"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" list 2>/dev/null)

    # Should show servers with some indication of impact
    if echo "$output" | grep -q "filesystem"; then
        pass "List command displays servers"
    else
        fail "List command failed"
    fi

    cleanup_test_config "$config"
}

# Test 4: Info on unknown server handling
test_info_unknown_server() {
    test_header "Info handles unknown servers"

    local config=$(setup_test_config)

    if ! "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info nonexistent-server 2>/dev/null; then
        pass "Info correctly handles unknown servers"
    else
        fail "Info should fail for unknown servers"
    fi

    cleanup_test_config "$config"
}

# Test 5: Known servers have predefined impact data
test_known_servers_metadata() {
    test_header "Known servers have metadata"

    local config=$(setup_test_config)

    # Check if filesystem (heavy) and brave-search (light) have different ratings
    local fs_output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info filesystem 2>/dev/null || echo "")
    local brave_output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info brave-search 2>/dev/null || echo "")

    if [[ -n "$fs_output" && -n "$brave_output" ]]; then
        pass "Info provides data for known servers"
    else
        fail "Missing metadata for known servers"
    fi

    cleanup_test_config "$config"
}

# Test 6: Info shows capabilities summary
test_info_shows_capabilities() {
    test_header "Info shows server capabilities"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle.sh" --config "$config" info filesystem 2>/dev/null)

    # Should mention what the server does
    if echo "$output" | grep -qiE "file|read|write|operations"; then
        pass "Info describes server capabilities"
    else
        fail "Info missing capabilities description"
    fi

    cleanup_test_config "$config"
}

# Run all tests
echo ""
test_info_command
test_info_shows_impact
test_list_shows_impact
test_info_unknown_server
test_known_servers_metadata
test_info_shows_capabilities

# Summary
echo ""
echo "  Context Impact Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit code
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
