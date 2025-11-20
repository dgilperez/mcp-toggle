# Troubleshooting Guide

Common issues and solutions for MCP Toggle.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Toggle Issues](#toggle-issues)
- [Server Not Available](#server-not-available)
- [API Key Errors](#api-key-errors)
- [Performance Issues](#performance-issues)
- [Sync Issues](#sync-issues)
- [Auto-Update Issues](#auto-update-issues)
- [Configuration Issues](#configuration-issues)
- [Getting More Help](#getting-more-help)

---

## Installation Issues

### Installation script fails

**Symptoms**: `./install.sh` exits with error

**Solutions**:

1. **Check Node.js/npm installation**:
   ```bash
   node --version  # Should be v16+ or higher
   npm --version   # Should be v8+ or higher
   ```

   If missing, install Node.js from https://nodejs.org/

2. **Check permissions**:
   ```bash
   chmod +x install.sh
   ```

3. **Check disk space**:
   ```bash
   df -h ~
   ```

   Need at least 500MB free for MCP servers

4. **Check internet connection**:
   ```bash
   ping -c 3 registry.npmjs.org
   ```

### npm install fails with EACCES

**Symptoms**: Permission denied errors during npm install

**Solutions**:

```bash
# Don't use sudo! Instead, fix npm permissions:
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'

# Add to ~/.zshrc or ~/.bashrc:
export PATH=~/.npm-global/bin:$PATH

# Reload shell and try again
source ~/.zshrc
./install.sh
```

### Directory already exists error

**Symptoms**: `~/.mcp/servers already exists`

**Solutions**:

```bash
# Backup existing installation
mv ~/.mcp/servers ~/.mcp/servers.backup
mv ~/.mcp/global-config.json ~/.mcp/global-config.json.backup

# Run installation
./install.sh

# Restore your custom servers if needed
```

---

## Toggle Issues

### Server toggle not working

**Symptoms**: `mcp-toggle enable/disable` doesn't change server status

**Diagnosis**:

```bash
# Check config is valid JSON
jq . ~/.mcp/global-config.json

# Check if server exists
./mcp-toggle list | grep your-server
```

**Solutions**:

1. **Invalid JSON**:
   ```bash
   # Restore from automatic backup
   ls -lt ~/.mcp/*.backup | head -1
   cp ~/.mcp/global-config.json.backup.TIMESTAMP ~/.mcp/global-config.json
   ```

2. **Server doesn't exist**:
   ```bash
   # Check server name spelling
   ./mcp-toggle list
   ```

3. **Permissions issue**:
   ```bash
   chmod 644 ~/.mcp/global-config.json
   ```

### Changes don't take effect

**Symptoms**: Toggled server still shows as enabled/disabled in editor

**Solutions**:

1. **Restart your editor** (Claude, Cursor, etc.)

2. **Re-sync configurations**:
   ```bash
   ./bin/sync-all.sh
   ```

3. **Check editor-specific config**:
   ```bash
   # Claude
   jq '.mcpServers | keys' ~/.claude.json

   # Cursor
   jq '.mcpServers | keys' ~/.config/cursor/mcp.json
   ```

---

## Server Not Available

### MCP tool not showing up in Claude

**Diagnosis**:

```bash
# 1. Check server is installed
ls ~/.mcp/servers/node_modules/ | grep your-server

# 2. Check it's in config and enabled
jq '.mcpServers | keys' ~/.mcp/global-config.json

# 3. Check it's not disabled
jq '._disabled_mcpServers | keys' ~/.mcp/global-config.json

# 4. Check Claude config
jq '.mcpServers | keys' ~/.claude.json
```

**Solutions**:

1. **Server not installed**:
   ```bash
   cd ~/.mcp/servers
   npm install server-package-name
   ```

2. **Server disabled**:
   ```bash
   ./mcp-toggle enable server-name
   ./bin/sync-all.sh
   ```

3. **Not in Claude config**:
   ```bash
   
   ```

4. **Restart Claude**:
   ```bash
   # Kill all Claude processes
   pkill -f claude
   # Start fresh
   claude
   ```

### Server installed but still not working

**Advanced Diagnosis**:

```bash
# Test server directly
node ~/.mcp/servers/node_modules/server-package/dist/index.js

# Check server logs (if available)
cat ~/.mcp/logs/server-name.log

# Verify environment variables
env | grep API_KEY
```

---

## API Key Errors

### "API key not found" or "Invalid API key"

**Diagnosis**:

```bash
# Check if variable is set
echo $BRAVE_API_KEY
echo $PUBMED_API_KEY
echo $GH_TOKEN

# Check if exported in shell config
grep API_KEY ~/.zshrc
```

**Solutions**:

1. **Not set**:
   ```bash
   # Add to ~/.zshrc:
   export BRAVE_API_KEY='your-key-here'
   export PUBMED_API_KEY='your-key-here'
   export GH_TOKEN='ghp_your-token-here'

   # Reload
   source ~/.zshrc
   ```

2. **Set but not exported**:
   ```bash
   # Wrong:
   BRAVE_API_KEY='key'

   # Correct:
   export BRAVE_API_KEY='key'
   ```

3. **Key has special characters**:
   ```bash
   # Always use single quotes to prevent expansion
   export API_KEY='key-with-$pecial-chars'
   ```

4. **Wrong shell config file**:
   ```bash
   # Check which shell you're using
   echo $SHELL

   # Bash users: Add to ~/.bashrc
   # Zsh users: Add to ~/.zshrc
   ```

5. **Restart shell after setting**:
   ```bash
   # Close and reopen terminal
   # OR
   source ~/.zshrc  # or ~/.bashrc
   ```

### Environment variable not substituted

**Symptoms**: Config shows `${API_KEY}` literally instead of actual value

**Explanation**: This is normal! The config files use template syntax. Values are substituted at runtime by `envsubst` or the MCP client.

**Verification**:

```bash
# Check that sync properly substituted values in editor configs
cat ~/.claude.json | grep API_KEY
# Should show actual value or environment variable reference depending on tool
```

---

## Performance Issues

### Slow startup (still 30+ seconds)

**Diagnosis**:

```bash
# Check if using npx (bad) or node (good)
jq '.mcpServers.brave.command' ~/.claude.json
```

**Solutions**:

1. **Still using npx**:
   ```bash
   # Re-run config update
   
   ./bin/sync-all.sh
   ```

2. **Using Smithery**:
   ```bash
   # Remove Smithery config
   rm ~/.claude/smithery-config.json  # if exists

   # Ensure using global config
   
   ```

3. **Old config cached**:
   ```bash
   # Backup and regenerate
   mv ~/.claude.json ~/.claude.json.old
   
   ```

### Server takes long to respond

**Diagnosis**:

```bash
# Test server response time
time node ~/.mcp/servers/node_modules/server-package/dist/index.js --test

# Check system resources
top  # Look for CPU/memory usage
```

**Solutions**:

1. **Update packages**:
   ```bash
   cd ~/.mcp/servers
   npm update
   ```

2. **Reinstall problematic server**:
   ```bash
   cd ~/.mcp/servers
   npm uninstall problem-server
   npm install problem-server
   ```

---

## Sync Issues

### Configs not syncing to editors

**Diagnosis**:

```bash
# Run sync with verbose output
./bin/sync-all.sh

# Check if files were created
ls -la ~/.claude.json
ls -la ~/.config/cursor/mcp.json
ls -la ~/.codeium/windsurf/mcp.json
```

**Solutions**:

1. **Directory doesn't exist**:
   ```bash
   # Sync script should create directories, but verify:
   mkdir -p ~/.config/cursor
   mkdir -p ~/.codeium/windsurf
   mkdir -p ~/.config/zed

   # Try again
   ./bin/sync-all.sh
   ```

2. **Permission issues**:
   ```bash
   chmod 644 ~/.claude.json
   chmod 644 ~/.config/cursor/mcp.json
   ```

3. **envsubst not installed**:
   ```bash
   # macOS
   brew install gettext
   brew link --force gettext

   # Linux
   apt-get install gettext-base  # Ubuntu/Debian
   yum install gettext            # CentOS/RHEL
   ```

### Wrong values after sync

**Diagnosis**:

```bash
# Check source config
cat ~/.mcp/global-config.json

# Check synced config
cat ~/.claude.json
```

**Solutions**:

1. **Source config is wrong**:
   ```bash
   # Fix global config first
   vim ~/.mcp/global-config.json
   # OR restore from backup
   cp ~/.mcp/global-config.json.backup ~/.mcp/global-config.json

   # Then re-sync
   ./bin/sync-all.sh
   ```

---

## Auto-Update Issues

### Auto-updates not running

**Diagnosis**:

```bash
# 1. Check if disabled
echo $DISABLE_MCP_AUTO_UPDATE

# 2. Check last update
cat ~/.cache/mcp/.mcp-update

# 3. Check update log
tail ~/.cache/mcp/update.log

# 4. Check if it's Monday
date +%u  # 1 = Monday
```

**Solutions**:

1. **Explicitly disabled**:
   ```bash
   # Remove or comment out in ~/.zshrc:
   # export DISABLE_MCP_AUTO_UPDATE="true"

   # Reload
   source ~/.zshrc
   ```

2. **Script not sourced**:
   ```bash
   # Add to ~/.zshrc if missing:
   source /path/to/mcp-toggle/mcp-auto-update.sh

   # Reload
   source ~/.zshrc
   ```

3. **Force update now**:
   ```bash
   mcp-update
   ```

### Update fails with errors

**Diagnosis**:

```bash
# Check update log
cat ~/.cache/mcp/update.log

# Try manual update to see errors
cd ~/.mcp/servers
npm update
```

**Common Errors**:

1. **No internet connection**: Wait and will retry next week
2. **npm registry down**: Temporary, will retry automatically
3. **Disk full**: Free up space and run `mcp-update`
4. **Permission errors**: Fix permissions:
   ```bash
   chmod -R u+w ~/.mcp/servers
   ```

---

## Configuration Issues

### Invalid JSON in config file

**Symptoms**: `jq` returns "parse error"

**Diagnosis**:

```bash
# Find the error
jq . ~/.mcp/global-config.json
```

**Solutions**:

1. **Restore from automatic backup**:
   ```bash
   # List backups (most recent first)
   ls -lt ~/.mcp/*.backup

   # Restore
   cp ~/.mcp/global-config.json.backup.MOST_RECENT ~/.mcp/global-config.json
   ```

2. **Fix manually**:
   ```bash
   # Common issues:
   # - Missing comma between entries
   # - Trailing comma after last entry
   # - Unmatched braces {}
   # - Unescaped quotes in strings

   vim ~/.mcp/global-config.json
   # Fix and validate:
   jq . ~/.mcp/global-config.json
   ```

3. **Regenerate from scratch**:
   ```bash
   # Backup current (even if broken)
   cp ~/.mcp/global-config.json ~/.mcp/broken-config.json

   # Create minimal valid config
   cat > ~/.mcp/global-config.json << 'EOF'
   {
     "mcpServers": {},
     "_disabled_mcpServers": {}
   }
   EOF

   # Add servers back one by one
   ```

### Server configuration incorrect

**Symptoms**: Server installed but doesn't work

**Diagnosis**:

```bash
# Check server config
jq '.mcpServers.server-name' ~/.mcp/global-config.json
```

**Common Issues**:

1. **Wrong path to server**:
   ```json
   {
     "command": "node",
     "args": ["$HOME/.mcp/servers/node_modules/correct-package-name/dist/index.js"]
   }
   ```

2. **Missing environment variables**:
   ```json
   {
     "env": {
       "API_KEY": "${YOUR_API_KEY}",
       "REQUIRED_VAR": "${REQUIRED_VAR}"
     }
   }
   ```

3. **Wrong command**:
   ```bash
   # Most servers use:
   "command": "node"

   # Some use:
   "command": "python"  # or "python3"

   # Check server's documentation
   ```

---

## Getting More Help

### Health Check

Run the health check script to diagnose multiple issues at once:

```bash
./bin/health-check.sh
```

This checks:
- Package installations
- Configuration validity
- Environment variables
- Editor configurations

### Collect Diagnostic Information

When reporting issues, include:

```bash
# System information
uname -a
echo $SHELL
node --version
npm --version

# MCP Toggle status
./mcp-toggle list
cat ~/.cache/mcp/.mcp-update

# Configuration
jq . ~/.mcp/global-config.json | head -50
env | grep -E '(BRAVE|PUBMED|GH_TOKEN|NOTION|FIGMA)' | sed 's/=.*/=***/'

# Recent logs
tail -20 ~/.cache/mcp/update.log
```

### Community Support

- **GitHub Issues**: https://github.com/YOUR-USERNAME/mcp-toggle/issues
- **Discussions**: https://github.com/YOUR-USERNAME/mcp-toggle/discussions
- **MCP Documentation**: https://modelcontextprotocol.io/
- **Claude Code Docs**: https://docs.anthropic.com/claude/docs

### Reporting Bugs

When creating an issue, include:
1. Clear description of the problem
2. Steps to reproduce
3. Expected vs. actual behavior
4. Diagnostic information (see above)
5. Relevant log files
6. Your operating system and shell

---

## Quick Reference

### Essential Commands

```bash
# Diagnosis
./mcp-toggle list              # List all servers
./bin/health-check.sh                 # Run health check
jq . ~/.mcp/global-config.json    # Validate config

# Fixes
./bin/sync-all.sh                     # Re-sync all configs
         # Update Claude specifically
mcp-update                        # Update all packages
source ~/.zshrc                   # Reload environment vars

# Backups
ls -lt ~/.mcp/*.backup            # List config backups
cp ~/.mcp/global-config.json.backup ~/.mcp/global-config.json  # Restore

# Logs
tail ~/.cache/mcp/update.log      # Check update log
cat ~/.cache/mcp/.mcp-update      # Check last update time
```

---

**Still having issues?** Create an issue on GitHub with diagnostic information and we'll help you out!
