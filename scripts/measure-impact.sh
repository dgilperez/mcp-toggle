#!/bin/bash
# Measure MCP Server Token Impact
# Estimates context window usage by measuring tool definitions and sample responses

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"

# Approximate token counter (rough estimate: ~4 chars per token)
estimate_tokens() {
    local text="$1"
    local char_count=$(echo -n "$text" | wc -c | tr -d ' ')
    echo $(( char_count / 4 ))
}

# Start MCP server and get tool list
get_tool_definitions() {
    local server_name="$1"
    local command="$2"
    shift 2
    local args=("$@")

    echo "Measuring $server_name..." >&2

    # Start server and send initialize request
    # This is a simplified version - would need full MCP protocol implementation
    timeout 5 "$command" "${args[@]}" <<EOF 2>/dev/null || true
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "0.1.0", "capabilities": {}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
EOF
}

echo "MCP Server Impact Measurement Tool"
echo "===================================="
echo ""
echo "This tool provides BASELINE estimates by measuring:"
echo "  1. Tool definition sizes (always loaded)"
echo "  2. Approximate token counts (char_count / 4)"
echo ""
echo "⚠️  LIMITATIONS:"
echo "  - Actual usage varies by operation"
echo "  - filesystem: small file vs large file = 100x difference"
echo "  - search: 1 result vs 20 results = 20x difference"
echo "  - This measures BASELINE only, not actual usage"
echo ""
echo "For accurate measurements, use Claude Code's /context command"
echo ""

# Example measurements for installed servers
if [ -f "$HOME/.claude.json" ]; then
    echo "Analyzing servers from ~/.claude.json..."
    echo ""

    # Get list of enabled servers
    servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)

    while IFS= read -r server; do
        if [ -n "$server" ]; then
            # Get command and args
            command=$(jq -r ".mcpServers.\"$server\".command" "$HOME/.claude.json")

            echo "Server: $server"
            echo "  Command: $command"
            echo "  Method: Would need to start server and query tool list"
            echo "  Recommendation: Use /context in Claude Code for accurate measurement"
            echo ""
        fi
    done <<< "$servers"
fi

echo ""
echo "PROPOSED APPROACH:"
echo "=================="
echo ""
echo "1. Manual measurement (CURRENT):"
echo "   - Use /context command in Claude Code"
echo "   - Observe actual token usage"
echo "   - Update data/manual-metadata.json"
echo ""
echo "2. Semi-automated (POSSIBLE):"
echo "   - Script starts each MCP server"
echo "   - Queries tool list via MCP protocol"
echo "   - Measures JSON response size"
echo "   - Estimates tokens (chars / 4)"
echo "   - Makes sample requests where possible"
echo "   - Outputs to data/automated-measurements.json"
echo ""
echo "3. Fully automated (IDEAL):"
echo "   - Integrate with Claude API"
echo "   - Make actual requests with each MCP server"
echo "   - Measure real token usage via API"
echo "   - Would need Claude API key + automation"
echo ""
echo "Which approach would you prefer?"
