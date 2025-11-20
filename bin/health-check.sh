#!/bin/bash
# Health check for MCP servers across all tools

set -e

echo "🏥 MCP Health Check"
echo "==================="
echo ""

GLOBAL_CONFIG="$HOME/.mcp/global-config.json"

check_packages() {
    echo "📦 Checking installed packages..."
    cd ~/.mcp/servers

    if [ -f package.json ]; then
        echo "   📋 Installed packages:"
        npm list --depth=0 2>/dev/null | grep -E "^├──|^└──" | sed 's/^[├└]── /   ✅ /' || echo "   ❌ No packages found"
    else
        echo "   ❌ No package.json found"
        return 1
    fi
    echo ""
}

check_config_validity() {
    echo "🔧 Checking configuration files..."

    # Global config
    if [ -f "$GLOBAL_CONFIG" ]; then
        if jq . "$GLOBAL_CONFIG" >/dev/null 2>&1; then
            echo "   ✅ Global config: Valid JSON"
            echo "   📊 Servers configured: $(jq -r '.mcpServers | keys | length' "$GLOBAL_CONFIG")"
        else
            echo "   ❌ Global config: Invalid JSON"
        fi
    else
        echo "   ❌ Global config: Not found"
    fi

    # Claude config
    if [ -f ~/.claude.json ]; then
        if jq '.mcpServers' ~/.claude.json >/dev/null 2>&1; then
            echo "   ✅ Claude config: Valid"
            echo "   📊 Claude MCP servers: $(jq -r '.mcpServers | keys | length' ~/.claude.json)"
        else
            echo "   ❌ Claude config: Invalid or missing MCP section"
        fi
    else
        echo "   ⚠️  Claude config: Not found"
    fi

    # Cursor config
    if [ -f ~/.cursor/mcp.json ]; then
        if jq . ~/.cursor/mcp.json >/dev/null 2>&1; then
            echo "   ✅ Cursor config: Valid JSON"
            echo "   📊 Cursor MCP servers: $(jq -r 'keys | length' ~/.cursor/mcp.json)"
        else
            echo "   ❌ Cursor config: Invalid JSON"
        fi
    else
        echo "   ⚠️  Cursor config: Not found"
    fi

    # Windsurf config
    if [ -f ~/.codeium/windsurf/mcp_config.json ]; then
        if jq . ~/.codeium/windsurf/mcp_config.json >/dev/null 2>&1; then
            echo "   ✅ Windsurf config: Valid JSON"
            echo "   📊 Windsurf MCP servers: $(jq -r '.mcpServers | keys | length' ~/.codeium/windsurf/mcp_config.json)"
        else
            echo "   ❌ Windsurf config: Invalid JSON"
        fi
    else
        echo "   ⚠️  Windsurf config: Not found"
    fi

    echo ""
}

check_env_vars() {
    echo "🔑 Checking environment variables..."

    vars=("BRAVE_API_KEY" "PUBMED_API_KEY" "GH_TOKEN" "SMITHERY_KEY" "SMITHERY_PROFILE")

    for var in "${vars[@]}"; do
        if [ -n "${!var}" ]; then
            echo "   ✅ $var: Set (${!var:0:10}...)"
        else
            echo "   ⚠️  $var: Not set"
        fi
    done
    echo ""
}

test_claude_mcp() {
    echo "🧪 Testing Claude CLI with MCP..."

    # Test basic Claude CLI
    if command -v ~/.claude/local/claude >/dev/null 2>&1; then
        echo "   ✅ Claude CLI: Available"

        # Test MCP tool list (quick test)
        if timeout 10 ~/.claude/local/claude --strict-mcp-config --mcp-config "$GLOBAL_CONFIG" --print "List available MCP tools" >/dev/null 2>&1; then
            echo "   ✅ MCP integration: Working"
        else
            echo "   ❌ MCP integration: Failed or timeout"
        fi
    else
        echo "   ❌ Claude CLI: Not found"
    fi
    echo ""
}

check_server_executables() {
    echo "🔍 Checking MCP server executables..."

    if [ -f "$GLOBAL_CONFIG" ]; then
        # Extract server commands and check if executables exist
        jq -r '.mcpServers | to_entries[] | "\(.key) \(.value.command) \(.value.args[0] // "")"' "$GLOBAL_CONFIG" | while read -r name command arg; do
            if [ "$command" = "node" ] && [ -n "$arg" ]; then
                if [ -f "$arg" ]; then
                    echo "   ✅ $name: Server executable found"
                else
                    echo "   ❌ $name: Server executable missing ($arg)"
                fi
            elif [ "$command" = "npx" ]; then
                echo "   ⚠️  $name: Uses npx (may be slow)"
            else
                if command -v "$command" >/dev/null 2>&1; then
                    echo "   ✅ $name: Command available ($command)"
                else
                    echo "   ❌ $name: Command not found ($command)"
                fi
            fi
        done
    fi
    echo ""
}

generate_report() {
    echo "📋 Health Check Summary"
    echo "======================="

    # Count issues
    local errors=0
    local warnings=0

    # Re-run checks silently and count issues
    if ! check_packages >/dev/null 2>&1; then ((errors++)); fi
    if [ ! -f "$GLOBAL_CONFIG" ]; then ((errors++)); fi
    if [ -z "$BRAVE_API_KEY" ]; then ((warnings++)); fi
    if [ -z "$PUBMED_API_KEY" ]; then ((warnings++)); fi

    echo "🔴 Errors: $errors"
    echo "🟡 Warnings: $warnings"

    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo ""
        echo "🎉 All systems green! MCP setup is healthy."
    elif [ $errors -eq 0 ]; then
        echo ""
        echo "⚠️  Minor issues detected, but core functionality should work."
    else
        echo ""
        echo "❌ Critical issues detected. Run install.sh or check configuration."
    fi
}

# Run all checks
check_packages
check_config_validity
check_env_vars
check_server_executables
test_claude_mcp
generate_report