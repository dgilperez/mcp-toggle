#!/bin/bash
# Sync global MCP configuration to all installed tools
# This ensures all editors/tools use the same fast, local MCP servers

set -e

GLOBAL_CONFIG="$HOME/.mcp/global-config.json"
SCRIPT_DIR="$(dirname "$0")"

echo "🔄 Syncing MCP configuration to all tools"
echo "=========================================="
echo ""

# Check if global config exists
if [ ! -f "$GLOBAL_CONFIG" ]; then
    echo "❌ Global config not found at $GLOBAL_CONFIG"
    echo "   Run ./install.sh first"
    exit 1
fi

# Function to substitute environment variables
substitute_env_vars() {
    local config_file="$1"
    local temp_file=$(mktemp)

    # Substitute environment variables
    envsubst < "$config_file" > "$temp_file"
    echo "$temp_file"
}

sync_to_claude() {
    echo "📝 Claude Code:"
    CLAUDE_CONFIG="$HOME/.claude.json"

    # Backup current config if it exists
    if [ -f "$CLAUDE_CONFIG" ]; then
        cp "$CLAUDE_CONFIG" "$CLAUDE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        echo "   💾 Backup created"
    fi

    # Extract mcpServers from global config and substitute env vars
    temp_file=$(substitute_env_vars "$GLOBAL_CONFIG")

    if [ -f "$CLAUDE_CONFIG" ]; then
        # Update existing config, preserving other settings
        jq --slurpfile mcp "$temp_file" '.mcpServers = $mcp[0].mcpServers' "$CLAUDE_CONFIG" > "$CLAUDE_CONFIG.tmp"
        mv "$CLAUDE_CONFIG.tmp" "$CLAUDE_CONFIG"
        echo "   ✅ Config updated at ~/.claude.json"
    else
        # Create new config with just mcpServers
        jq '{mcpServers: .mcpServers}' "$temp_file" > "$CLAUDE_CONFIG"
        echo "   ✅ Config created at ~/.claude.json"
    fi

    rm "$temp_file"
    echo "   📊 Servers available: $(jq -r '.mcpServers | keys | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "unknown")"
    echo ""
}

sync_to_cursor() {
    echo "📝 Cursor:"
    if command -v cursor >/dev/null 2>&1; then
        mkdir -p ~/.cursor

        # Extract just mcpServers section and substitute env vars
        temp_file=$(substitute_env_vars "$GLOBAL_CONFIG")
        jq '.mcpServers' "$temp_file" > ~/.cursor/mcp.json
        rm "$temp_file"

        echo "   ✅ Config updated at ~/.cursor/mcp.json"
        echo "   📊 Servers available: $(jq -r 'keys | length' ~/.cursor/mcp.json 2>/dev/null || echo "unknown")"
    else
        echo "   ⚠️  Cursor not installed, skipping"
    fi
    echo ""
}

sync_to_vscode() {
    echo "📝 VSCode:"
    if command -v code >/dev/null 2>&1; then
        # VSCode uses workspace configs, so we'll create a template
        mkdir -p ~/.mcp/templates

        temp_file=$(substitute_env_vars "$GLOBAL_CONFIG")

        # Create VSCode format template
        jq '{servers: .mcpServers}' "$temp_file" > ~/.mcp/templates/vscode-mcp.json
        rm "$temp_file"

        echo "   ✅ Template created at ~/.mcp/templates/vscode-mcp.json"
        echo "   💡 Copy this to your workspace .vscode/mcp.json as needed"
    else
        echo "   ⚠️  VSCode not installed, skipping"
    fi
    echo ""
}

sync_to_windsurf() {
    echo "📝 Windsurf:"
    if [ -d ~/.codeium ] || command -v windsurf >/dev/null 2>&1; then
        mkdir -p ~/.codeium/windsurf

        # Windsurf uses same format as our global config
        temp_file=$(substitute_env_vars "$GLOBAL_CONFIG")
        cp "$temp_file" ~/.codeium/windsurf/mcp_config.json
        rm "$temp_file"

        echo "   ✅ Config updated at ~/.codeium/windsurf/mcp_config.json"
        echo "   📊 Servers available: $(jq -r '.mcpServers | keys | length' ~/.codeium/windsurf/mcp_config.json)"
    else
        echo "   ⚠️  Windsurf not installed, skipping"
    fi
    echo ""
}

sync_to_zed() {
    echo "📝 Zed:"
    if command -v zed >/dev/null 2>&1; then
        ZED_CONFIG="$HOME/.config/zed/settings.json"
        mkdir -p "$(dirname "$ZED_CONFIG")"

        # Create Zed format (context_servers section)
        temp_file=$(substitute_env_vars "$GLOBAL_CONFIG")

        if [ -f "$ZED_CONFIG" ]; then
            # Merge with existing settings
            jq --slurpfile mcp "$temp_file" '.context_servers = $mcp[0].mcpServers' "$ZED_CONFIG" > "$ZED_CONFIG.tmp"
            mv "$ZED_CONFIG.tmp" "$ZED_CONFIG"
        else
            # Create new settings file
            jq '{context_servers: .mcpServers}' "$temp_file" > "$ZED_CONFIG"
        fi

        rm "$temp_file"
        echo "   ✅ Config updated at $ZED_CONFIG"
    else
        echo "   ⚠️  Zed not installed, skipping"
    fi
    echo ""
}

# Check global config validity
echo "🔍 Validating global config..."
if jq . "$GLOBAL_CONFIG" >/dev/null 2>&1; then
    echo "   ✅ Global config is valid JSON"
    echo "   📊 Available servers: $(jq -r '.mcpServers | keys | join(", ")' "$GLOBAL_CONFIG")"
else
    echo "   ❌ Global config has invalid JSON"
    exit 1
fi
echo ""

# Run all syncs
sync_to_claude
sync_to_cursor
sync_to_vscode
sync_to_windsurf
sync_to_zed

echo "🎉 Sync complete!"
echo ""
echo "💡 Next steps:"
echo "   • Restart any open editors to pick up new configs"
echo "   • Test MCP tools in each editor"
echo "   • Run 'mcp-health-check' to verify everything works"