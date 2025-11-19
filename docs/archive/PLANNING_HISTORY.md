# MCP Ecosystem Management Plan

## Current State Analysis

### MCP Configuration Locations

| Tool | Global Config | Project Config | Format |
|------|---------------|----------------|---------|
| **Claude Code** | `~/.claude.json` | - | Full config with MCP section |
| **Cursor** | `~/.cursor/mcp.json` | `.cursor/mcp.json` | MCP-only config |
| **VSCode** | User profile (via Command Palette) | `.vscode/mcp.json` | MCP-only config |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | - | MCP-only config |
| **Zed** | `settings.json` (context_servers) | - | Settings section |

### Our Global Setup

- **Source of Truth**: `~/.mcp/servers/` (npm packages)
- **Config Template**: `~/.mcp/global-config.json`
- **Update Command**: `mcp-update`

## Strategy: Hub and Spoke Model

```
                    ~/.mcp/
                  (Source of Truth)
                       |
        ┌──────────────┼──────────────┐
        |              |              |
   Claude Code     Cursor/VSCode   Windsurf/Zed
 ~/.claude.json   ~/.cursor/mcp.json  ~/.codeium/...
```

## Implementation Plan

### Phase 1: Centralized Management ✅ DONE
- [x] Global package installation at `~/.mcp/servers/`
- [x] Template config at `~/.mcp/global-config.json`
- [x] Update script: `mcp-update`
- [x] Claude Code integration

### Phase 2: Multi-Tool Sync (NEXT)

Create sync scripts that propagate from central source to all tools:

1. **Extract tool-specific configs** from global template
2. **Auto-update all editors** when global config changes
3. **Validation and testing** for each tool

### Phase 3: Maintenance Automation

1. **Scheduled updates** (weekly MCP package updates)
2. **Health checks** (verify all tools can access MCP servers)
3. **Conflict resolution** (handle API key changes, etc.)

## Detailed Action Plan

### 1. Current Cleanup Required

```bash
# What we need to clean up:
~/.claude.json                    # ✅ Already updated to use fast local
~/.local/mcp-fast-config.json     # ❌ Remove (replaced by global)
~/.cursor/mcp.json                # ❓ Check if exists, update if needed
~/.codeium/windsurf/mcp_config.json # ❓ Check if exists, update if needed
```

### 2. Sync Script Architecture

```bash
~/.mcp/
├── servers/               # npm packages (source of truth)
├── global-config.json     # master template
├── sync-all.sh           # sync to all tools
├── configs/              # tool-specific configs
│   ├── claude.json
│   ├── cursor.json
│   ├── vscode.json
│   ├── windsurf.json
│   └── zed.json
└── update.sh             # update packages + sync
```

### 3. Update Workflow

```bash
# Weekly maintenance:
1. mcp-update               # Update npm packages
2. mcp-sync-all            # Propagate to all tools
3. mcp-health-check        # Verify all tools work
```

## Immediate Actions Needed

### 1. Check What Configs Exist

```bash
# Check which tools are installed and configured
ls ~/.cursor/mcp.json 2>/dev/null && echo "Cursor config exists"
ls ~/.codeium/windsurf/mcp_config.json 2>/dev/null && echo "Windsurf config exists"
ls ~/.vscode/mcp.json 2>/dev/null && echo "VSCode workspace config exists"
```

### 2. Create Universal Sync Script

```bash
#!/bin/bash
# ~/.mcp/sync-all.sh
# Sync global MCP config to all installed tools

GLOBAL_CONFIG="$HOME/.mcp/global-config.json"

sync_to_claude() {
    # Already done - Claude uses global config directly
    echo "✅ Claude Code: Using global config"
}

sync_to_cursor() {
    if command -v cursor >/dev/null 2>&1; then
        # Extract just mcpServers section for Cursor
        jq '.mcpServers' "$GLOBAL_CONFIG" > ~/.cursor/mcp.json
        echo "✅ Cursor: Config updated"
    fi
}

sync_to_windsurf() {
    if [ -d ~/.codeium ]; then
        mkdir -p ~/.codeium/windsurf
        cp "$GLOBAL_CONFIG" ~/.codeium/windsurf/mcp_config.json
        echo "✅ Windsurf: Config updated"
    fi
}

# Run all syncs
sync_to_claude
sync_to_cursor
sync_to_windsurf
```

### 3. Environment Variables Strategy

**Problem**: Different tools handle environment variables differently

**Solution**:
- Keep env vars in `~/.zshrc` (source of truth)
- Scripts substitute `${VAR}` → actual values when syncing
- Each tool gets config with resolved values

### 4. Maintenance Schedule

```bash
# Add to crontab or create reminder:
# Weekly: Update all MCP packages
0 10 * * 1 ~/.mcp/update.sh

# Daily: Health check (optional)
0 9 * * * ~/.mcp/health-check.sh
```

## Benefits of This Approach

1. **Single Source of Truth**: All packages in `~/.mcp/servers/`
2. **Consistent Experience**: Same tools available everywhere
3. **Easy Maintenance**: One update command affects all tools
4. **Tool Independence**: Each editor gets its preferred format
5. **Environment Isolation**: API keys managed centrally
6. **Performance**: No npx delays anywhere

## Potential Issues & Solutions

| Issue | Solution |
|-------|----------|
| Tool-specific config formats | Generate appropriate format per tool |
| API key security | Use env vars, never hardcode |
| Package version conflicts | Lock versions in package.json |
| Tool not installed | Skip gracefully in sync script |
| Config corruption | Backup before sync, validate after |

## Next Steps

1. **Audit current configs** - see what exists
2. **Build sync script** - propagate global → tools
3. **Test each tool** - verify MCP servers work
4. **Automate updates** - weekly package updates
5. **Document workflow** - how to add new servers

Would you like me to start implementing the audit and sync scripts?