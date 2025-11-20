# MCP Toggle

[![Tests](https://github.com/dgilperez/mcp-toggle/workflows/Tests/badge.svg)](https://github.com/dgilperez/mcp-toggle/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Manage, discover, and toggle MCP servers for Claude and other AI tools**

## Why MCP Toggle?

- ⚡ **Fast**: No more 30+ second npx downloads - local servers start in 2-5 seconds
- 🔄 **Toggle**: Enable/disable servers without losing configuration
- 🔍 **Discover**: Find and install 50+ popular MCP servers from curated lists
- 🎯 **Multi-tool**: Works with Claude, Cursor, Windsurf, Zed, VSCode
- 🚀 **Auto-update**: Weekly maintenance on Monday mornings (Oh My Zsh style)
- 📦 **Unified**: One config for all your AI tools

## Overview

MCP Toggle is a comprehensive MCP (Model Context Protocol) server management system that provides:
- **Server Toggle**: Enable/disable MCP servers without losing their configuration
- **Server Discovery**: Browse and install from a curated list of popular MCP servers
- **Multi-Editor Sync**: Automatically sync MCP configuration across Claude, Cursor, Windsurf, and more
- **Global Setup**: One installation for all tools, no more per-tool configuration
- **Automatic Updates**: Weekly background updates keep your servers current

## Quick Start

### 1. Initial Installation

```bash
# Clone the repository
git clone https://github.com/dgilperez/mcp-toggle.git
cd mcp-toggle

# Run installation
chmod +x install.sh
./install.sh
```

This installs essential MCP servers to `~/.mcp/servers/` and creates a global config at `~/.mcp/global-config.json`. Use `discover` to add more servers.

### 2. Set API Keys (Optional)

Set API keys for servers you plan to use. Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Only add keys for servers you'll use
export BRAVE_API_KEY='your-key'      # For brave-search
export GH_TOKEN='your-token'          # For github
export NOTION_API_KEY='your-key'      # For notion
# ... add others as needed
```

Then reload:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

### 3. Update Your Tools

```bash
# Update Claude config
./update-claude-config.sh

# Sync to all tools (Claude, Cursor, Windsurf, Zed, VSCode)
./sync-all.sh
```

## Core Features

### 1. Toggle Servers On/Off

Enable and disable MCP servers without losing their configuration:

```bash
# List all servers and their status (or just run without args)
./mcp-toggle.sh
./mcp-toggle.sh info

# Disable a server (moves to _disabled_mcpServers)
./mcp-toggle.sh disable figma

# Enable a server (moves back to mcpServers)
./mcp-toggle.sh enable figma

# Bulk operations - enable/disable multiple servers at once
./mcp-toggle.sh enable figma puppeteer notion
./mcp-toggle.sh disable github brave-search
```

Disabled servers are kept in `_disabled_mcpServers` section - they're not loaded but configuration is preserved.

### 2. Server Information & Health

Check health of all servers or get detailed info for a specific server:

```bash
# Health check ALL enabled servers
./mcp-toggle.sh info

# Shows for each server:
# - Status with impact indicator (🔴 Heavy, 🟡 Medium, 🟢 Light)
# - Command availability check
# - Environment variables check
# - Summary with issue count and recommendations

# Detailed info for specific server
./mcp-toggle.sh info filesystem

# Shows:
# - Status: ENABLED/DISABLED
# - Context Window Impact: Heavy/Medium/Light
# - Configuration details
# - Health Check: command availability, environment variables
# - Impact guidance
```

Impact levels:
- **Heavy**: 1000+ tokens (filesystem, figma, puppeteer, obsidian)
- **Medium**: 100-1000 tokens (github, databases, notion)
- **Light**: <100 tokens (search, slack, official servers)

### 3. Discover Servers

Browse curated servers or search npm - all in one command:

```bash
# Show curated list of popular servers
./mcp-toggle.sh discover

# Browse by category
./mcp-toggle.sh discover database      # Database-related servers
./mcp-toggle.sh discover productivity  # Productivity tools
./mcp-toggle.sh discover dev-tools     # Development tools

# Search npm for anything else
./mcp-toggle.sh discover weather       # Searches npm if not a known category
```

The discover feature includes 15+ curated categories with impact indicators:
- **Database**: PostgreSQL, SQLite
- **Productivity**: Notion, Obsidian, Slack
- **Development**: GitHub, Puppeteer
- **Search**: Brave, PubMed
- **AI & Official**: Memory, Sequential-thinking
- And more categories dynamically from the cache

### 4. Usage Analytics

Get insights into your server configuration and receive recommendations:

```bash
# Show statistics and recommendations
./mcp-toggle.sh stats
```

Displays:
- Enabled/disabled server counts
- Impact breakdown by category (Heavy/Medium/Light)
- Estimated context usage baseline
- Smart recommendations based on your setup

### 5. Multi-Editor Support

Sync your MCP configuration across multiple editors:

```bash
# Sync to all supported editors
./sync-all.sh

# This updates:
# - Claude Code (~/.claude.json)
# - Cursor (~/.config/cursor/mcp.json)
# - Windsurf (~/.codeium/windsurf/mcp.json)
# - Zed (~/.config/zed/settings.json)
# - VSCode (multiple locations)
```

Each editor receives a properly formatted configuration with:
- Environment variable substitution
- Editor-specific paths and formats
- Automatic server discovery

### 6. Automatic Updates

MCP servers are automatically updated every Monday when you start a new terminal (Oh My Zsh style):

- **Frequency**: Weekly on Monday mornings
- **Background**: Runs without blocking terminal startup
- **Logging**: Results logged to `~/.cache/mcp/update.log`
- **Smart**: Only updates if 7+ days have passed
- **Force update**: After 14 days if Monday is missed

**How it works:**
1. Checks if it's been 7+ days since last update
2. If it's Monday (or 14+ days passed), runs update in background
3. Logs results to `~/.cache/mcp/update.log`
4. Doesn't block terminal startup

**Check update status:**
```bash
# When last updated
cat ~/.cache/mcp/.mcp-update

# View update log
tail ~/.cache/mcp/update.log

# Force update now
mcp-update
```

**Disable automatic updates:**
```bash
# Add to ~/.zshrc
export DISABLE_MCP_AUTO_UPDATE="true"
```

**Troubleshooting auto-updates:**
- If updates aren't running, check `echo $DISABLE_MCP_AUTO_UPDATE` isn't set to "true"
- Check the log file: `tail ~/.cache/mcp/update.log`
- Manually update: `mcp-update`

## Daily Usage

### Using with Claude Code

Just start Claude Code normally:
```bash
claude
```

It will automatically use the fast, global MCP servers. No more waiting!

### Using in Python Scripts

```python
import subprocess
from pathlib import Path

mcp_config = Path.home() / '.mcp' / 'global-config.json'

with open(mcp_config) as f:
    config = f.read()

result = subprocess.run([
    'claude',
    '--strict-mcp-config',
    '--mcp-config', config,
    '--print', 'Your prompt here'
], capture_output=True, text=True)
```

### Testing MCP Tools

Test that the installed servers work:

```bash
# Test filesystem access
claude --print "List files in my home directory using filesystem"

# Test web fetching
claude --print "Fetch the content from example.com using fetch"
```

After installing more servers via `discover`, test them similarly.

## Maintenance

### Manual Updates

Update all MCP servers manually:

```bash
mcp-update
```

Or update packages only:
```bash
cd ~/.mcp/servers
npm update
```

Check update status:
```bash
# Check last update
cat ~/.cache/mcp/.mcp-update

# Check update log
tail ~/.cache/mcp/update.log
```

### Add a New MCP Server

1. Install it:
```bash
cd ~/.mcp/servers
npm install @org/new-mcp-server
```

2. Add to `~/.mcp/global-config.json`:
```json
"new-server": {
  "command": "node",
  "args": ["$HOME/.mcp/servers/node_modules/@org/new-mcp-server/dist/index.js"],
  "env": {
    "API_KEY": "${NEW_API_KEY}"
  }
}
```

3. Sync to all tools:
```bash
./sync-all.sh
```

### Check Installed Versions

```bash
cd ~/.mcp/servers
npm list --depth=0
```

## File Locations

| File | Purpose |
|------|---------|
| `~/.mcp/servers/` | All MCP server packages installed here |
| `~/.mcp/global-config.json` | Global MCP configuration |
| `~/.mcp/update.sh` | Update script for all servers |
| `~/.claude.json` | Claude's config (points to global MCP) |
| `~/.cache/mcp/` | Update logs and cache |

## Available MCP Servers

After installation, you'll have:
- **filesystem**: Local file operations
- **fetch**: Web content fetching

Discover and install more:
```bash
./mcp-toggle.sh discover      # Browse 50+ curated servers
cd ~/.mcp/servers && npm install @modelcontextprotocol/server-github
# Then add to config and sync
```

## Performance Comparison

| Setup | First Run | Subsequent Runs |
|-------|-----------|-----------------|
| Smithery/npx (old) | 30-45 seconds | 30-45 seconds |
| MCP Toggle (new) | 2-5 seconds | 2-5 seconds |

## Troubleshooting

### MCP tool not available

1. Check it's installed:
```bash
ls ~/.mcp/servers/node_modules/ | grep your-server
```

2. Check it's in config:
```bash
cat ~/.mcp/global-config.json | jq '.mcpServers | keys'
```

3. Check server info:
```bash
./mcp-toggle.sh info your-server
```

4. Restart your editor if needed

### API key errors

1. Verify key is set:
```bash
echo $YOUR_API_KEY
```

2. Check it's exported in ~/.zshrc
3. `source ~/.zshrc` to reload

### Slow performance

This shouldn't happen with local setup! If it does:
1. Check you're not using old Smithery config
2. Verify with: `jq '.mcpServers.brave.command' ~/.claude.json`
3. Should show "node", not "npx"

### Server toggle not working

1. Check config is valid JSON:
```bash
jq . ~/.mcp/global-config.json
```

2. Backup is created before each toggle at:
```bash
ls -la ~/.mcp/*.backup
```

3. Restore from backup if needed:
```bash
cp ~/.mcp/global-config.json.backup ~/.mcp/global-config.json
```

For more troubleshooting help, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Advanced Usage

### Using Different Configs

You can maintain multiple configs for different purposes:

```bash
# Production config
~/.mcp/global-config.json

# Development config
~/.mcp/dev-config.json

# Minimal config for testing
~/.mcp/minimal-config.json
```

Switch between them:
```bash
claude --mcp-config ~/.mcp/dev-config.json
```

### Environment-Specific Keys

Use different keys per environment:

```bash
# Development
export BRAVE_API_KEY=$BRAVE_API_KEY_DEV

# Production
export BRAVE_API_KEY=$BRAVE_API_KEY_PROD
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for general guidelines.

### Contributing Server Metadata

The MCP server cache (`data/mcp-cache.json`) is automatically updated weekly. To contribute:

1. **Add impact ratings and descriptions** - Edit `data/manual-metadata.json`
2. **Measure with Claude Code** - Use `/context` command to see actual token usage
3. **Test locally** - Run `./scripts/generate-cache.sh` to regenerate cache
4. **Submit PR** - See [docs/CONTRIBUTING_CACHE.md](docs/CONTRIBUTING_CACHE.md) for details

The cache system:
- Pulls from MCP official registry + npm stats
- Merges with manual metadata (PRs welcome!)
- Regenerates automatically every Sunday night
- Supports local overrides in `~/.mcp/local-metadata.json`

## Security Notes

- Never commit API keys to git
- Use environment variables for all keys
- All sensitive files are in `.gitignore`
- Consider using a secrets manager for production
- Rotate API keys periodically
- Repository has been security audited (no secrets in git history)

## Documentation

- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute
- [Cache Contributions](docs/CONTRIBUTING_CACHE.md) - Add server metadata and impact ratings
- [Changelog](CHANGELOG.md) - Version history and changes

## Resources

- MCP Documentation: https://modelcontextprotocol.io/
- Claude Code Docs: https://docs.anthropic.com/claude/docs
- Issues: [GitHub Issues](https://github.com/dgilperez/mcp-toggle/issues)

## License

MIT License - see [LICENSE](LICENSE) file for details

---

**Last updated**: 2025-01-19
**Version**: 1.0.0
