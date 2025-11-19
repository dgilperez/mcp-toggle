# Contributing to MCP Toggle

Thank you for your interest in contributing to MCP Toggle! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Assume good intentions

## Ways to Contribute

### 1. Report Bugs

If you find a bug, please create an issue with:
- Clear, descriptive title
- Steps to reproduce the bug
- Expected vs. actual behavior
- Your environment (OS, shell, MCP Toggle version)
- Relevant log files or error messages

### 2. Suggest Features

We welcome feature suggestions! Please:
- Check existing issues first to avoid duplicates
- Clearly describe the feature and its use case
- Explain why it would be valuable to users
- Consider implementation complexity

### 3. Add New MCP Servers to Discovery List

One of the most valuable contributions is adding well-tested MCP servers to our curated discovery list:

**Steps:**
1. Test the MCP server thoroughly in your own setup
2. Verify it works with Claude Code and other tools
3. Document any required API keys or setup steps
4. Add to the discovery list in `mcp-toggle.sh`:

```bash
# Find the CURATED_SERVERS array in mcp-toggle.sh
# Add your server in the appropriate category

# Database category example:
"server-name|category|npm-package-name|description|required-env-vars"
"mydb|database|@org/mydb-mcp|MyDB database connector|MYDB_API_KEY"
```

5. Submit a PR with:
   - Server added to curated list
   - Example usage in PR description
   - Documentation of required setup

### 4. Improve Documentation

Documentation improvements are always welcome:
- Fix typos or unclear wording
- Add examples or use cases
- Improve troubleshooting guides
- Translate to other languages (future)

### 5. Submit Code

See "Development Workflow" section below.

## Development Workflow

### Setup

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/YOUR-USERNAME/mcp-toggle.git
cd mcp-toggle
```

3. Test the current setup:
```bash
./install.sh
./mcp-toggle.sh list
```

### Making Changes

1. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes following our code style (see below)

3. Test your changes:
```bash
# Run the test suite
cd tests
./run-all-tests.sh

# Test manually
./mcp-toggle.sh <your-feature>
./health-check.sh
```

4. Commit your changes:
```bash
git add .
git commit -m "Brief description of changes"
```

### Code Style

#### Shell Scripts (Bash)

- **Use `shellcheck`**: All scripts must pass shellcheck validation
  ```bash
  shellcheck *.sh
  ```

- **Naming conventions**:
  - Functions: `lowercase_with_underscores`
  - Variables: `UPPERCASE_FOR_CONSTANTS`, `lowercase_for_locals`
  - Files: `kebab-case.sh`

- **Best practices**:
  - Always quote variables: `"$variable"`
  - Use `[[ ]]` instead of `[ ]` for conditionals
  - Add error checking: `set -euo pipefail` where appropriate
  - Include helpful comments for complex logic
  - Use functions for reusable code

Example:
```bash
#!/bin/bash
# Brief description of script

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="$HOME/.mcp/global-config.json"

# Functions
function check_requirements() {
    local required_cmd="$1"

    if ! command -v "$required_cmd" >/dev/null 2>&1; then
        echo "Error: $required_cmd is required but not installed"
        return 1
    fi
}

# Main logic
main() {
    check_requirements "jq"
    # ... rest of logic
}

main "$@"
```

#### JSON Configuration

- Use 2-space indentation
- Validate with `jq`:
  ```bash
  jq . config.json
  ```
- Use environment variable placeholders: `${VAR_NAME}`

#### Documentation (Markdown)

- Use clear, concise language
- Include code examples where helpful
- Keep line length reasonable (80-100 chars when possible)
- Use proper heading hierarchy (h1 → h2 → h3)
- Include links to related documentation

### Testing

#### Manual Testing

Before submitting a PR, test these scenarios:

1. **Fresh install**:
   ```bash
   rm -rf ~/.mcp
   ./install.sh
   ```

2. **Toggle operations**:
   ```bash
   ./mcp-toggle.sh list
   ./mcp-toggle.sh disable <server>
   ./mcp-toggle.sh enable <server>
   ./mcp-toggle.sh status <server>
   ```

3. **Discovery**:
   ```bash
   ./mcp-toggle.sh discover
   ./mcp-toggle.sh discover database
   ```

4. **Sync**:
   ```bash
   ./sync-all.sh
   # Verify configs were created correctly
   ```

5. **Health check**:
   ```bash
   ./health-check.sh
   ```

#### Automated Testing

Run the test suite:
```bash
cd tests
./run-all-tests.sh
```

Add tests for new features in the `tests/` directory.

### Submitting Pull Requests

1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request** with:
   - Clear title describing the change
   - Description explaining what and why
   - Reference any related issues (#123)
   - Screenshots/examples if applicable
   - Confirmation that tests pass

4. **PR Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Code refactoring

   ## Testing
   - [ ] Tested manually
   - [ ] Added/updated tests
   - [ ] All tests pass
   - [ ] Ran shellcheck

   ## Related Issues
   Fixes #123

   ## Screenshots (if applicable)
   ```

## Project Structure

```
mcp-toggle/
├── docs/                    # Documentation
│   ├── AUTO_UPDATE_GUIDE.md
│   ├── SECURITY_AUDIT.md
│   ├── TROUBLESHOOTING.md
│   └── PLANNING_HISTORY.md
├── tests/                   # Test suite
│   ├── test-toggle.sh
│   ├── test-install.sh
│   ├── test-sync.sh
│   └── run-all-tests.sh
├── examples/                # Example configurations
├── install.sh               # Installation script
├── mcp-toggle.sh            # Main toggle script (CORE)
├── sync-all.sh              # Multi-editor sync
├── health-check.sh          # Health verification
├── mcp-auto-update.sh       # Auto-update system
├── update-claude-config.sh  # Claude config updater
├── README.md                # Main documentation
├── CONTRIBUTING.md          # This file
├── CHANGELOG.md             # Version history
└── LICENSE                  # MIT License
```

## Release Process

(For maintainers)

1. Update `CHANGELOG.md` with changes
2. Update version in `README.md`
3. Create git tag: `git tag v1.x.x`
4. Push tag: `git push origin v1.x.x`
5. Create GitHub release with changelog

## Security

### Reporting Security Issues

**Do NOT create public issues for security vulnerabilities.**

Instead, email the maintainers directly at: [INSERT SECURITY EMAIL]

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Security Best Practices

When contributing:
- Never commit API keys, tokens, or credentials
- Always use environment variables for secrets
- Validate user input in scripts
- Avoid `eval` or similar dangerous constructs
- Be careful with file permissions
- Don't execute untrusted code

## Getting Help

- **Questions**: Create a GitHub discussion
- **Bugs**: Create an issue with bug report template
- **Features**: Create an issue with feature request template
- **Chat**: [INSERT COMMUNITY CHAT LINK IF AVAILABLE]

## Recognition

Contributors are recognized in:
- GitHub contributors page
- CHANGELOG.md for significant contributions
- README.md for major features

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to MCP Toggle! 🎉
