# MCP Toggle Test Suite

Automated tests for MCP Toggle to ensure reliability and catch regressions.

## Running Tests

### Run All Tests

```bash
cd tests
./run-all-tests.sh
```

### Run Individual Test

```bash
cd tests
./test-basic.sh
```

## Test Structure

```
tests/
├── README.md              # This file
├── run-all-tests.sh       # Test runner (runs all tests)
├── test-basic.sh          # Basic functionality tests
├── test-toggle.sh         # Server toggle functionality (TODO)
├── test-install.sh        # Installation process tests (TODO)
├── test-sync.sh           # Multi-editor sync tests (TODO)
└── fixtures/              # Test data and mock configs
```

## Current Tests

### test-basic.sh

Tests fundamental project structure and requirements:
- Core scripts exist and are executable
- Documentation files exist
- Required commands (node, npm, jq) are available
- No hardcoded personal paths
- .gitignore covers sensitive files

**Status**: ✅ Implemented

### test-toggle.sh (TODO)

Will test server toggle functionality:
- List servers
- Enable/disable servers
- Check server status
- Backup creation
- JSON validity after operations

**Status**: 📝 Planned

### test-install.sh (TODO)

Will test installation process:
- Directory creation
- npm package installation
- Config file generation
- Symlink creation

**Status**: 📝 Planned

### test-sync.sh (TODO)

Will test multi-editor sync:
- Config sync to Claude
- Config sync to Cursor
- Config sync to Windsurf
- Environment variable substitution
- JSON validity of synced configs

**Status**: 📝 Planned

## Writing Tests

### Test File Template

```bash
#!/bin/bash
# Description of test suite

set -euo pipefail

# Setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

TESTS_RUN=0
TESTS_PASSED=0

# Test helpers
pass() {
    echo -e "  ✓ $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "  ✗ $1"
    ((TESTS_RUN++))
}

test_header() {
    echo "  Testing: $1"
}

# Test functions
test_something() {
    test_header "Something works"

    [[ condition ]] && pass "Test passed" || fail "Test failed"
}

# Run tests
test_something

# Summary
echo ""
echo "  Tests: $TESTS_PASSED/$TESTS_RUN passed"

# Exit
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
```

### Best Practices

1. **Isolation**: Tests should not affect user's actual MCP setup
2. **Cleanup**: Use temp directories and clean up after tests
3. **Clear Output**: Use descriptive test names and clear pass/fail indicators
4. **Exit Codes**: Exit 0 on success, 1 on failure
5. **Dependencies**: Check for required commands before running tests

## CI/CD Integration

### GitHub Actions (Future)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Run tests
        run: |
          cd tests
          ./run-all-tests.sh
```

## Contributing Tests

When adding new features:

1. Add corresponding tests
2. Ensure all existing tests still pass
3. Document new tests in this README
4. Run `shellcheck` on test scripts
5. Include test results in PR

## Test Coverage Goals

- [ ] Basic structure and requirements (✅ Done)
- [ ] Server toggle operations
- [ ] Installation process
- [ ] Multi-editor sync
- [ ] Health check validation
- [ ] Auto-update system
- [ ] Error handling
- [ ] Edge cases

---

**Current Coverage**: Basic tests implemented. Additional tests are planned and contributions are welcome!
