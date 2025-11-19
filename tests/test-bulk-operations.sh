#!/bin/bash
# Bulk Operations Tests for MCP Toggle
# Tests enabling/disabling multiple servers at once

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
    # Create a temporary test config
    TEST_CONFIG=$(mktemp)
    cat > "$TEST_CONFIG" <<'EOF'
{
  "mcpServers": {
    "test-server-1": {
      "command": "node",
      "args": ["test1.js"]
    },
    "test-server-2": {
      "command": "node",
      "args": ["test2.js"]
    },
    "test-server-3": {
      "command": "node",
      "args": ["test3.js"]
    }
  },
  "_disabled_mcpServers": {
    "test-server-4": {
      "command": "node",
      "args": ["test4.js"]
    },
    "test-server-5": {
      "command": "node",
      "args": ["test5.js"]
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

# Test 1: Bulk enable multiple servers
test_bulk_enable() {
    test_header "Bulk enable multiple servers"

    local config=$(setup_test_config)

    # Test enabling 2 servers at once
    if "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable test-server-4 test-server-5 2>/dev/null; then
        # Check both servers are now in mcpServers
        local count=$(jq -r '.mcpServers | keys | map(select(. == "test-server-4" or . == "test-server-5")) | length' "$config")
        if [[ "$count" == "2" ]]; then
            pass "Bulk enable moves multiple servers to mcpServers"
        else
            fail "Bulk enable did not move all servers (found $count of 2)"
        fi

        # Check both servers removed from disabled
        local disabled_count=$(jq -r '._disabled_mcpServers | keys | map(select(. == "test-server-4" or . == "test-server-5")) | length' "$config")
        if [[ "$disabled_count" == "0" ]]; then
            pass "Bulk enable removes servers from _disabled_mcpServers"
        else
            fail "Bulk enable left servers in disabled (found $disabled_count)"
        fi
    else
        fail "Bulk enable command failed"
    fi

    cleanup_test_config "$config"
}

# Test 2: Bulk disable multiple servers
test_bulk_disable() {
    test_header "Bulk disable multiple servers"

    local config=$(setup_test_config)

    # Test disabling 2 servers at once
    if "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" disable test-server-1 test-server-2 2>/dev/null; then
        # Check both servers are now in _disabled_mcpServers
        local count=$(jq -r '._disabled_mcpServers | keys | map(select(. == "test-server-1" or . == "test-server-2")) | length' "$config")
        if [[ "$count" == "2" ]]; then
            pass "Bulk disable moves multiple servers to _disabled_mcpServers"
        else
            fail "Bulk disable did not move all servers (found $count of 2)"
        fi

        # Check both servers removed from enabled
        local enabled_count=$(jq -r '.mcpServers | keys | map(select(. == "test-server-1" or . == "test-server-2")) | length' "$config")
        if [[ "$enabled_count" == "0" ]]; then
            pass "Bulk disable removes servers from mcpServers"
        else
            fail "Bulk disable left servers in enabled (found $enabled_count)"
        fi
    else
        fail "Bulk disable command failed"
    fi

    cleanup_test_config "$config"
}

# Test 3: Mixed valid/invalid server names
test_mixed_servers() {
    test_header "Handle mix of valid and invalid server names"

    local config=$(setup_test_config)

    # Try to enable one valid and one invalid server
    if "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable test-server-4 nonexistent-server 2>/dev/null; then
        fail "Should fail with invalid server in list"
    else
        pass "Correctly rejects bulk operation with invalid server"
    fi

    # Verify no changes were made (atomic operation)
    local count=$(jq -r '._disabled_mcpServers | keys | map(select(. == "test-server-4")) | length' "$config")
    if [[ "$count" == "1" ]]; then
        pass "Atomic operation: no changes on error"
    else
        fail "Non-atomic: partial changes were made"
    fi

    cleanup_test_config "$config"
}

# Test 4: Empty server list
test_empty_list() {
    test_header "Handle empty server list"

    local config=$(setup_test_config)

    if "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable 2>/dev/null; then
        fail "Should reject empty server list"
    else
        pass "Correctly rejects empty server list"
    fi

    cleanup_test_config "$config"
}

# Test 5: Backup created before bulk operation
test_backup_created() {
    test_header "Backup created before bulk operation"

    local config=$(setup_test_config)
    local backup_dir=$(mktemp -d)

    # Override backup directory for testing
    export MCP_BACKUP_DIR="$backup_dir"

    "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable test-server-4 test-server-5 2>/dev/null

    # Check if backup was created (claude-config-*.json pattern)
    if ls "$backup_dir"/claude-config-*.json 2>/dev/null | grep -q .; then
        pass "Backup created before bulk operation"
    else
        fail "No backup created"
    fi

    rm -rf "$backup_dir"
    cleanup_test_config "$config"
}

# Test 6: Idempotent operations
test_idempotent_enable() {
    test_header "Idempotent enable operations"

    local config=$(setup_test_config)

    # Enable servers that are already enabled
    if "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable test-server-1 test-server-2 2>/dev/null; then
        pass "Enable accepts already-enabled servers"
    else
        fail "Enable rejects already-enabled servers"
    fi

    cleanup_test_config "$config"
}

# Test 7: Bulk operation preserves server config
test_preserves_config() {
    test_header "Bulk operation preserves server configuration"

    local config=$(setup_test_config)

    # Get original config for test-server-4
    local original=$(jq -c '._disabled_mcpServers["test-server-4"]' "$config")

    # Enable it
    "$PROJECT_ROOT/mcp-toggle.sh" --config "$config" enable test-server-4 2>/dev/null

    # Check config is preserved
    local new_config=$(jq -c '.mcpServers["test-server-4"]' "$config")

    if [[ "$original" == "$new_config" ]]; then
        pass "Server configuration preserved during move"
    else
        fail "Server configuration changed: $original -> $new_config"
    fi

    cleanup_test_config "$config"
}

# Run all tests
echo ""
test_bulk_enable
test_bulk_disable
test_mixed_servers
test_empty_list
test_backup_created
test_idempotent_enable
test_preserves_config

# Summary
echo ""
echo "  Bulk Operations Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit code
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
