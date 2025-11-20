# Changelog

All notable changes to MCP Toggle will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Impact Measurement System**: Real token usage measurement from Claude Code
  - `scripts/measure-impact.sh` - Single script to measure and update impact data
  - Parses Claude Code `/context` output automatically
  - Updates cache with real measurements (`"method": "measured"`)
  - Integrated into weekly GitHub Actions workflow
  - Creates weekly reminder issues to update measurements
- **Dynamic Category Display**: Discover command now fully dynamic
  - Reads all categories from cache (no hardcoded lists)
  - All 15+ categories work (communication, design, demo, utility, etc.)
  - Unknown categories fall back to npm search
- **Merged Commands**: Consolidated overlapping commands
  - `health`, `status`, `info` → `info` (comprehensive health check)
  - `discover`, `search` → `discover` (intelligent category vs search detection)
- **Bulk Operations**: Enable/disable multiple servers at once
  - `mcp-toggle enable server1 server2 server3`
  - `mcp-toggle disable server1 server2`
- **JSON Cache System**: Replaced hardcoded metadata
  - `data/mcp-cache.json` - Main cache (auto-updated weekly)
  - `data/manual-metadata.json` - Manual contributions
  - Pulls from MCP official registry + npm stats
  - Supports local overrides in `~/.mcp/local-metadata.json`

### Changed
- **Retro Stats Display**: Redesigned `stats` command with clean retro ASCII aesthetic
  - Lightweight box drawing (┌─┐│└─┘) instead of heavy banners
  - Monotone design optimized for dark mode terminals
  - Visual hierarchy using character weights: █ (solid), ▓ (dark), ▒ (medium), ░ (light)
  - No colors - purely monochrome design
  - Simpler layout with better readability
- **Improved Default Behavior**: Running `mcp-toggle` without args now shows server list with helpful tips instead of blank output
- **Test Suite**: All tests updated to use merged commands (56/56 tests passing)

### Fixed
- Script robustness with `set -e` when optional files don't exist
- Installation path detection in health checks
- Category display handling for all cache categories

## [1.0.0] - 2025-11-19

### Added
- **Project Rename**: Renamed from "mcp-global-setup" to "MCP Toggle" to better reflect core functionality
- **Server Toggle Feature**: Enable/disable MCP servers without losing configuration
  - `mcp-toggle list` - List all servers and their status
  - `mcp-toggle disable <server>` - Disable a server (moves to _disabled_mcpServers)
  - `mcp-toggle enable <server>` - Enable a server
  - `mcp-toggle status <server>` - Check if server is enabled or disabled
- **Server Discovery**: Browse and install from curated list of 50+ MCP servers
  - `mcp-toggle discover` - Show all curated servers
  - `mcp-toggle discover <category>` - Filter by category (database, productivity, dev-tools, etc.)
  - `mcp-toggle discover --search <term>` - Search npm for MCP servers
- **Multi-Editor Sync**: Automatically sync MCP configuration across editors
  - Claude Code support
  - Cursor support
  - Windsurf support
  - Zed support
  - VSCode support
- **Auto-Update System**: Weekly automatic updates (Oh My Zsh style)
  - Runs every Monday morning
  - Background execution (non-blocking)
  - Configurable with `DISABLE_MCP_AUTO_UPDATE`
  - Update logging to `~/.cache/mcp/update.log`
- **Health Check System**: Verify MCP setup integrity
  - Package installation verification
  - Configuration validation
  - Environment variable checks
  - Editor accessibility checks
- **Comprehensive Documentation**:
  - Restructured README with "Why MCP Toggle?" section
  - CONTRIBUTING.md with development guidelines
  - docs/AUTO_UPDATE_GUIDE.md - Detailed auto-update documentation
  - docs/SECURITY_AUDIT.md - Security review and best practices
  - docs/TROUBLESHOOTING.md - Common issues and solutions
  - docs/PLANNING_HISTORY.md - Project evolution roadmap
- **Security Improvements**:
  - Comprehensive .gitignore for sensitive files
  - Environment variable-only API key management
  - Pre-publication security audit completed
  - No secrets in git history verified
- **Test Infrastructure**:
  - tests/test-toggle.sh - Server toggle functionality tests
  - tests/test-install.sh - Installation process tests
  - tests/test-sync.sh - Multi-editor sync tests
  - tests/run-all-tests.sh - Unified test runner

### Changed
- **Dynamic Path Detection**: Scripts no longer require hardcoded installation paths
  - Auto-detects script directory location
  - Works regardless of where repository is cloned
- **Improved README**: Reorganized to emphasize toggle feature and server discovery
- **Updated Documentation**: All paths changed from mcp-global-setup to mcp-toggle
- **License**: MIT License included for open source distribution

### Fixed
- Removed personal file paths from examples
- Sanitized all documentation to be generic and reusable
- Fixed hardcoded directory references in auto-update system

### Removed
- `update-python-scripts.sh` - Too project-specific, not general-purpose
- Personal settings and configurations
- Hardcoded paths to specific project locations

### Security
- Verified no API keys or secrets in git history
- Removed personal information from examples
- Added comprehensive security documentation
- Implemented proper .gitignore patterns

## [0.9.0] - 2024-12-28 (Pre-release)

### Added
- Initial MCP server installation system
- Global configuration at `~/.mcp/global-config.json`
- Basic Claude Code integration
- Environment variable-based API key management
- Core MCP servers: Brave Search, PubMed, GitHub, Filesystem, Notion
- Figma MCP server support

### Changed
- Migrated from npx/Smithery to local npm packages
- Performance improvement: 30-45s → 2-5s startup time

---

## Version History

- **1.0.0** (2025-11-19): First official open source release as "MCP Toggle"
- **0.9.0** (2024-12-28): Pre-release internal version as "mcp-global-setup"

## Upgrade Guide

### From 0.9.0 to 1.0.0

If you were using the pre-release "mcp-global-setup" version:

1. **Rename Repository** (if you cloned it):
   ```bash
   cd ~/src
   mv mcp-global-setup mcp-toggle
   cd mcp-toggle
   ```

2. **Update Git Remote** (if using your own fork):
   ```bash
   git remote set-url origin https://github.com/YOUR-USERNAME/mcp-toggle.git
   ```

3. **Update Shell Config**:
   If you have hardcoded paths in `~/.zshrc`, update them:
   ```bash
   # Old:
   source ~/src/mcp-global-setup/mcp-auto-update.sh

   # New (or just use the auto-detected path):
   source ~/src/mcp-toggle/mcp-auto-update.sh
   ```

4. **Pull Latest Changes**:
   ```bash
   git pull origin main
   ```

5. **Run Health Check**:
   ```bash
   ./bin/health-check.sh
   ```

All your MCP servers and configurations in `~/.mcp/` are fully compatible - no changes needed!

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting changes and additions to the changelog.
