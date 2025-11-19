#!/bin/bash
# Basic Tests for MCP Toggle
# Tests core script functionality and requirements

set -uo pipefail  # Removed -e so tests continue even if some fail

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

# Test 1: Check core scripts exist
test_core_scripts_exist() {
    test_header "Core scripts exist"

    if [[ -f "$PROJECT_ROOT/install.sh" ]]; then pass "install.sh exists"; else fail "install.sh missing"; fi
    if [[ -f "$PROJECT_ROOT/mcp-toggle.sh" ]]; then pass "mcp-toggle.sh exists"; else fail "mcp-toggle.sh missing"; fi
    if [[ -f "$PROJECT_ROOT/sync-all.sh" ]]; then pass "sync-all.sh exists"; else fail "sync-all.sh missing"; fi
    if [[ -f "$PROJECT_ROOT/health-check.sh" ]]; then pass "health-check.sh exists"; else fail "health-check.sh missing"; fi
    if [[ -f "$PROJECT_ROOT/mcp-auto-update.sh" ]]; then pass "mcp-auto-update.sh exists"; else fail "mcp-auto-update.sh missing"; fi
    if [[ -f "$PROJECT_ROOT/update-claude-config.sh" ]]; then pass "update-claude-config.sh exists"; else fail "update-claude-config.sh missing"; fi
}

# Test 2: Check scripts are executable
test_scripts_executable() {
    test_header "Scripts are executable"

    if [[ -x "$PROJECT_ROOT/install.sh" ]]; then pass "install.sh is executable"; else fail "install.sh not executable"; fi
    if [[ -x "$PROJECT_ROOT/mcp-toggle.sh" ]]; then pass "mcp-toggle.sh is executable"; else fail "mcp-toggle.sh not executable"; fi
    if [[ -x "$PROJECT_ROOT/sync-all.sh" ]]; then pass "sync-all.sh is executable"; else fail "sync-all.sh not executable"; fi
    if [[ -x "$PROJECT_ROOT/health-check.sh" ]]; then pass "health-check.sh is executable"; else fail "health-check.sh not executable"; fi
}

# Test 3: Check documentation exists
test_documentation_exists() {
    test_header "Documentation exists"

    if [[ -f "$PROJECT_ROOT/README.md" ]]; then pass "README.md exists"; else fail "README.md missing"; fi
    if [[ -f "$PROJECT_ROOT/LICENSE" ]]; then pass "LICENSE exists"; else fail "LICENSE missing"; fi
    if [[ -f "$PROJECT_ROOT/CONTRIBUTING.md" ]]; then pass "CONTRIBUTING.md exists"; else fail "CONTRIBUTING.md missing"; fi
    if [[ -f "$PROJECT_ROOT/CHANGELOG.md" ]]; then pass "CHANGELOG.md exists"; else fail "CHANGELOG.md missing"; fi
    if [[ -f "$PROJECT_ROOT/docs/TROUBLESHOOTING.md" ]]; then pass "TROUBLESHOOTING.md exists"; else fail "TROUBLESHOOTING.md missing"; fi
}

# Test 4: Check required commands available
test_required_commands() {
    test_header "Required commands available"

    if command -v node >/dev/null 2>&1; then pass "node is available"; else fail "node not found"; fi
    if command -v npm >/dev/null 2>&1; then pass "npm is available"; else fail "npm not found"; fi
    if command -v jq >/dev/null 2>&1; then pass "jq is available"; else fail "jq not found (optional)"; fi
}

# Test 5: Check for hardcoded paths
test_no_hardcoded_paths() {
    test_header "No hardcoded personal paths"

    # Allow GitHub URLs but not other hardcoded paths
    if ! grep -r "dgilperez" "$PROJECT_ROOT" --exclude-dir=.git --exclude-dir=tests 2>/dev/null | grep -v "github.com" >/dev/null 2>&1; then
        pass "No hardcoded username (GitHub URLs allowed)"
    else
        fail "Found hardcoded username 'dgilperez'"
    fi

    if ! grep -r "/Users/dgilperez" "$PROJECT_ROOT" --exclude-dir=.git --exclude-dir=tests >/dev/null 2>&1; then
        pass "No hardcoded paths to /Users/dgilperez"
    else
        fail "Found hardcoded path /Users/dgilperez"
    fi
}

# Test 6: Check .gitignore covers sensitive files
test_gitignore_coverage() {
    test_header ".gitignore covers sensitive files"

    if grep -q "\.env" "$PROJECT_ROOT/.gitignore"; then pass ".gitignore covers .env files"; else fail ".env not in .gitignore"; fi
    if grep -q "\*api-key\*" "$PROJECT_ROOT/.gitignore"; then pass ".gitignore covers API keys"; else fail "API keys not in .gitignore"; fi
    if grep -q "\*secret\*" "$PROJECT_ROOT/.gitignore"; then pass ".gitignore covers secrets"; else fail "Secrets not in .gitignore"; fi
    if grep -q "\.claude/" "$PROJECT_ROOT/.gitignore"; then pass ".gitignore covers .claude/"; else fail ".claude/ not in .gitignore"; fi
}

# Run all tests
echo ""
test_core_scripts_exist
test_scripts_executable
test_documentation_exists
test_required_commands
test_no_hardcoded_paths
test_gitignore_coverage

# Summary
echo ""
echo "  Basic Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit code
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
