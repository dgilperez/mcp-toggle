# Global MCP (Model Context Protocol) Setup

## Overview

This is a unified, global MCP server setup that provides fast, reliable access to MCP tools for:
- Claude Code (interactive CLI)
- Python scripts and automation
- Any tool that can use MCP servers

**Key Benefits:**
- ⚡ **Fast**: No more 30+ second npx downloads
- 🔄 **Unified**: One config for all tools
- 📦 **Updated**: Easy command to update all servers
- 🚀 **Global**: Available system-wide

## Quick Start

### 1. Initial Installation

```bash
cd ~/src/mcp-global-setup
chmod +x install.sh
./install.sh
```

This installs all MCP servers to `~/.mcp/servers/` and creates a global config at `~/.mcp/global-config.json`.

### 2. Set API Keys

Add to your `~/.zshrc`:

```bash
export BRAVE_API_KEY='your-brave-api-key'        # Get from: https://api.search.brave.com/app/keys
export PUBMED_API_KEY='your-pubmed-api-key'      # Get from: NCBI account
export PUBMED_EMAIL='your-email@example.com'     # Required for PubMed
export GH_TOKEN='ghp_your-github-token'          # GitHub personal access token
export NOTION_API_KEY='your-notion-key'          # If using Notion
```

Then reload:
```bash
source ~/.zshrc
```

### 3. Update Claude Config

```bash
cd ~/src/mcp-global-setup
chmod +x update-claude-config.sh
./update-claude-config.sh
```

This updates `~/.claude.json` to use the fast, local MCP servers instead of slow npx/Smithery.

### 4. Update Python Scripts (if applicable)

For any Python scripts using MCP, update the config path:

```python
# Old:
local_mcp_config = Path.home() / '.local' / 'mcp-fast-config.json'

# New:
local_mcp_config = Path.home() / '.mcp' / 'global-config.json'
```

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
    '/Users/dgilperez/.claude/local/claude',
    '--strict-mcp-config',
    '--mcp-config', config,
    '--print', 'Your prompt here'
], capture_output=True, text=True)
```

### Testing MCP Tools

Test that everything works:

```bash
# Test Brave search
claude --print "Use brave-search to find news about AI"

# Test PubMed
claude --print "Use pubmed to search for papers on balneotherapy"

# Test GitHub
claude --print "Use github to list my recent repos"
```

## Maintenance

### Update All MCP Servers

Run this periodically (e.g., weekly) to get latest versions:

```bash
mcp-update
```

Or manually:
```bash
cd ~/.mcp/servers
npm update
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

3. Update Claude config:
```bash
~/src/mcp-global-setup/update-claude-config.sh
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
| `~/src/mcp-global-setup/` | Setup and maintenance scripts |

## Available MCP Servers

Currently installed:
- **brave-search**: Web search via Brave
- **pubmed**: Scientific literature search
- **github**: GitHub repository operations
- **filesystem**: Local file operations
- **notion**: Notion workspace access

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

3. Restart Claude Code if needed

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

## Performance Comparison

| Setup | First Run | Subsequent Runs |
|-------|-----------|-----------------|
| Smithery/npx (old) | 30-45 seconds | 30-45 seconds |
| Local/global (new) | 2-5 seconds | 2-5 seconds |

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

To add new MCP servers to the global setup:

1. Test the server manually first
2. Add to `install.sh` script
3. Document required API keys
4. Submit PR with example usage

## Security Notes

- Never commit API keys to git
- Use environment variables for all keys
- Consider using a secrets manager for production
- Rotate API keys periodically

## Support

- MCP Documentation: https://modelcontextprotocol.io/
- Claude Code Docs: https://docs.anthropic.com/claude/docs
- Issues: Create issue in relevant MCP server repo

---

Last updated: 2024-12-28
Maintained by: Tech & Science Team