# MCP Toggle Examples

This directory contains example configurations and integration code for MCP Toggle.

## Examples

### 1. Python Integration (`python-integration.py`)

Example Python script showing how to:
- Load MCP Toggle's global configuration
- Use Claude Code programmatically with MCP servers
- Check which servers are enabled/disabled

**Usage**:
```bash
cd examples
chmod +x python-integration.py
python3 python-integration.py
```

**Requirements**:
- Python 3.7+
- Claude Code installed
- MCP Toggle installed (`../install.sh`)
- Environment variables set for required API keys

### 2. Custom Server Configuration (`custom-server-config.json`)

Example JSON configuration demonstrating:
- Custom MCP server definitions
- Environment variable usage
- Different command types (node, python)
- Disabled servers configuration

**Key Features**:
- **Weather Server**: Shows node-based server with API key
- **Database Server**: Shows Python server with multiple env vars
- **API Wrapper**: Shows server with config file and defaults
- **Experimental Server**: Shows disabled server with notes

**How to Use**:

1. Install your custom server packages:
   ```bash
   cd ~/.mcp/servers
   npm install @your-org/weather-mcp
   ```

2. Add server configuration to your global config:
   ```bash
   # Manually edit
   vim ~/.mcp/global-config.json

   # Or merge programmatically
   jq -s '.[0] * .[1]' ~/.mcp/global-config.json custom-server-config.json > temp.json
   mv temp.json ~/.mcp/global-config.json
   ```

3. Set required environment variables:
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export WEATHER_API_KEY='your-key-here'
   export DB_NAME='your-database'
   export DB_USER='username'
   export DB_PASSWORD='password'
   export CUSTOM_API_KEY='your-api-key'
   ```

4. Sync to your editors:
   ```bash
   cd ..
   ./sync-all.sh
   ```

## Creating Your Own Custom Server

### Step 1: Install the Server Package

```bash
cd ~/.mcp/servers
npm install your-mcp-server-package
# or for Python servers:
pip install your-mcp-server-package
```

### Step 2: Add Configuration

Create a server entry in `~/.mcp/global-config.json`:

```json
{
  "mcpServers": {
    "your-server-name": {
      "command": "node",  // or "python3", "python", etc.
      "args": [
        "$HOME/.mcp/servers/node_modules/your-package/dist/index.js",
        "--option", "value"
      ],
      "env": {
        "API_KEY": "${YOUR_API_KEY}",
        "SETTING": "${YOUR_SETTING:-default-value}"
      }
    }
  }
}
```

**Configuration Fields**:
- `command`: The executable (node, python3, etc.)
- `args`: Array of arguments, including path to server script
- `env`: Environment variables (use `${VAR_NAME}` for substitution)
  - Use `${VAR:-default}` syntax for default values

### Step 3: Set Environment Variables

```bash
# Add to ~/.zshrc
export YOUR_API_KEY='your-actual-key'
export YOUR_SETTING='custom-value'  # or omit to use default

# Reload shell
source ~/.zshrc
```

### Step 4: Sync and Test

```bash
# Sync to all editors
./sync-all.sh

# Test in Claude
claude --print "Use your-server-name to test functionality"

# Toggle if needed
./mcp-toggle.sh disable your-server-name
./mcp-toggle.sh enable your-server-name
```

## Best Practices

### Environment Variables

1. **Always use placeholders**: `${API_KEY}` not `"actual-key"`
2. **Provide defaults when sensible**: `${PORT:-3000}`
3. **Document required vars**: In comments or README
4. **Never commit secrets**: Keep keys in `~/.zshrc`, not configs

### Server Configuration

1. **Use absolute paths**: `$HOME/.mcp/servers/...`
2. **Test servers individually**: Before adding to global config
3. **Use descriptive names**: `weather-api` not `server1`
4. **Add notes for complex servers**: In `_note` field

### Toggling Servers

1. **Disable unused servers**: To reduce startup time
2. **Keep config even when disabled**: Use `_disabled_mcpServers`
3. **Test after toggling**: Ensure editors pick up changes
4. **Use health-check**: `../health-check.sh` to verify setup

## Troubleshooting

### Server not appearing in Claude

1. Check it's installed:
   ```bash
   ls -la ~/.mcp/servers/node_modules/your-package
   ```

2. Check it's in config:
   ```bash
   jq '.mcpServers.your-server' ~/.mcp/global-config.json
   ```

3. Check it's not disabled:
   ```bash
   ./mcp-toggle.sh status your-server
   ```

4. Re-sync configs:
   ```bash
   ./sync-all.sh
   ```

5. Restart Claude

### Environment variables not working

1. Check they're exported:
   ```bash
   echo $YOUR_API_KEY
   ```

2. Check shell config:
   ```bash
   grep YOUR_API_KEY ~/.zshrc
   ```

3. Reload shell:
   ```bash
   source ~/.zshrc
   ```

### Invalid JSON errors

1. Validate config:
   ```bash
   jq . ~/.mcp/global-config.json
   ```

2. Common issues:
   - Missing comma between entries
   - Trailing comma after last entry
   - Unescaped quotes in strings
   - Mismatched braces

3. Restore from backup:
   ```bash
   ls -lt ~/.mcp/*.backup | head -1
   cp [most-recent-backup] ~/.mcp/global-config.json
   ```

## Contributing

Have a useful example? Please contribute!

1. Add your example to this directory
2. Document it in this README
3. Test it thoroughly
4. Submit a pull request

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

**Need help?** See [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
