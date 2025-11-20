#!/bin/bash
# Usage Analytics Tests for MCP Toggle
# Tests showing server statistics and usage patterns

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
      "command": "node",
      "args": ["fs.js"]
    },
    "brave-search": {
      "command": "node",
      "args": ["brave.js"]
    },
    "github": {
      "command": "node",
      "args": ["gh.js"]
    }
  },
  "_disabled_mcpServers": {
    "figma": {
      "command": "node",
      "args": ["figma.js"]
    },
    "puppeteer": {
      "command": "node",
      "args": ["puppeteer.js"]
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

# Test 1: Stats command exists
test_stats_command() {
    test_header "Stats command exists"

    local config=$(setup_test_config)

    if "$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null >/dev/null; then
        pass "Stats command runs successfully"
    else
        fail "Stats command failed or missing"
    fi

    cleanup_test_config "$config"
}

# Test 2: Stats shows enabled/disabled counts
test_stats_shows_counts() {
    test_header "Stats shows server counts"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null)

    # Should show counts (3 enabled, 2 disabled)
    if echo "$output" | grep -qE "[0-9]+.*enabled|Enabled.*[0-9]+"; then
        pass "Stats displays enabled server count"
    else
        fail "Stats missing enabled count"
    fi

    if echo "$output" | grep -qE "[0-9]+.*disabled|Disabled.*[0-9]+"; then
        pass "Stats displays disabled server count"
    else
        fail "Stats missing disabled count"
    fi

    cleanup_test_config "$config"
}

# Test 3: Stats shows impact breakdown
test_stats_shows_impact() {
    test_header "Stats shows impact breakdown"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null)

    # Should mention impact levels
    if echo "$output" | grep -qiE "heavy|medium|light|impact"; then
        pass "Stats shows impact analysis"
    else
        fail "Stats missing impact analysis"
    fi

    cleanup_test_config "$config"
}

# Test 4: Stats shows recommendations
test_stats_shows_recommendations() {
    test_header "Stats shows recommendations"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null)

    # Should provide some guidance or recommendations
    if echo "$output" | grep -qiE "recommendation|consider|tip|suggestion|context"; then
        pass "Stats provides recommendations"
    else
        fail "Stats missing recommendations"
    fi

    cleanup_test_config "$config"
}

# Test 5: Stats handles empty config
test_stats_empty_config() {
    test_header "Stats handles empty configuration"

    local config=$(mktemp)
    cat > "$config" <<'EOF'
{
  "mcpServers": {},
  "_disabled_mcpServers": {}
}
EOF

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null)
    if echo "$output" | grep -qE "0|none|empty"; then
        pass "Stats handles empty config gracefully"
    else
        fail "Stats fails on empty config"
    fi

    rm -f "$config"
}

# Test 6: Stats shows total context estimate
test_stats_total_impact() {
    test_header "Stats estimates total context usage"

    local config=$(setup_test_config)

    local output=$("$PROJECT_ROOT/mcp-toggle" --config "$config" stats 2>/dev/null)

    # Should show some total or summary
    if echo "$output" | grep -qiE "total|overall|combined|context"; then
        pass "Stats shows total/overall metrics"
    else
        fail "Stats missing total metrics"
    fi

    cleanup_test_config "$config"
}

# Run all tests
echo ""
test_stats_command
test_stats_shows_counts
test_stats_shows_impact
test_stats_shows_recommendations
test_stats_empty_config
test_stats_total_impact

# Summary
echo ""
echo "  Usage Analytics Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit code
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
