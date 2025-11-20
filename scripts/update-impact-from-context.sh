#!/bin/bash
# Update MCP server impact ratings from Claude Code /context output
#
# Usage:
#   1. Start Claude Code: claude
#   2. Run: /context
#   3. Copy the MCP server section output
#   4. Run: ./scripts/update-impact-from-context.sh
#   5. Paste the output when prompted
#   6. Script updates data/mcp-cache.json with real measurements

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"

echo "========================================"
echo "MCP Impact Updater from /context Output"
echo "========================================"
echo ""
echo "This script updates data/mcp-cache.json with REAL token measurements"
echo "from your Claude Code installation."
echo ""
echo "INSTRUCTIONS:"
echo "-------------"
echo "1. Open another terminal and run: claude"
echo "2. In Claude Code, type: /context"
echo "3. Copy the MCP Servers section (lines showing token counts)"
echo "4. Come back here and paste it (Ctrl+D when done)"
echo ""
echo "Expected format:"
echo "  filesystem: 1,450 tokens"
echo "  github: 520 tokens"
echo "  brave-search: 48 tokens"
echo ""
echo -n "Paste /context output here (Ctrl+D when done): "
echo ""

# Read multiline input until EOF
context_output=$(cat)

if [ -z "$context_output" ]; then
    echo "Error: No input received"
    exit 1
fi

echo ""
echo "Parsing measurements..."
echo ""

# Parse the output and update cache
temp_updates=$(mktemp)

# Extract server: token_count pairs
echo "$context_output" | grep -E "^\s*[a-z0-9_-]+:\s*[0-9,]+\s*tokens?" | while IFS= read -r line; do
    # Extract server name and token count
    server=$(echo "$line" | sed -E 's/^\s*([a-z0-9_-]+):.*/\1/')
    tokens=$(echo "$line" | sed -E 's/.*:\s*([0-9,]+).*/\1/' | tr -d ',')

    if [ -n "$server" ] && [ -n "$tokens" ]; then
        # Determine category based on token count
        if [ "$tokens" -ge 1000 ]; then
            category="Heavy"
        elif [ "$tokens" -ge 100 ]; then
            category="Medium"
        else
            category="Light"
        fi

        echo "  • $server: $tokens tokens ($category)"
        echo "$server|$tokens|$category" >> "$temp_updates"
    fi
done

if [ ! -s "$temp_updates" ]; then
    echo "Error: No valid measurements found in input"
    echo "Please paste the MCP server section from /context output"
    rm "$temp_updates"
    exit 1
fi

echo ""
echo "Updating $CACHE_FILE..."

# Backup cache
cp "$CACHE_FILE" "$CACHE_FILE.backup"

# Update cache with measurements
while IFS='|' read -r server tokens category; do
    # Check if server exists in cache
    if jq -e ".servers.\"$server\"" "$CACHE_FILE" >/dev/null 2>&1; then
        # Update existing server
        jq --arg s "$server" \
           --argjson t "$tokens" \
           --arg c "$category" \
           --arg date "$(date -u +"%Y-%m-%d")" \
           '.servers[$s].impact.estimated_tokens = $t |
            .servers[$s].impact.category = $c |
            .servers[$s].impact.method = "measured" |
            .servers[$s].impact.measured_at = $date' \
           "$CACHE_FILE" > "$CACHE_FILE.tmp"
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        echo "  ✓ Updated $server"
    else
        echo "  ⚠ Skipped $server (not in cache)"
    fi
done < "$temp_updates"

rm "$temp_updates"

echo ""
echo "✓ Cache updated successfully!"
echo ""
echo "Backup saved to: $CACHE_FILE.backup"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff data/mcp-cache.json"
echo "  2. Commit: git add data/mcp-cache.json"
echo "  3. Commit: git commit -m 'Update impact ratings with real measurements'"
echo "  4. Push: git push"
echo ""
