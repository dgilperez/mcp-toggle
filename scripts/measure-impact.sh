#!/bin/bash
# Measure and update MCP server impact ratings from Claude Code
#
# This script helps you measure REAL token usage from your local Claude Code
# installation and updates the cache with accurate measurements.
#
# Usage:
#   ./scripts/measure-impact.sh
#
# The script will guide you through the process.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"

echo "================================================"
echo "MCP Server Impact Measurement Tool"
echo "================================================"
echo ""
echo "This tool updates data/mcp-cache.json with REAL token"
echo "measurements from your Claude Code installation."
echo ""
echo "📊 Why measure? Current ratings are estimates. Real"
echo "   measurements help everyone understand actual impact."
echo ""
echo "🎯 This runs LOCALLY - you need Claude Code installed."
echo ""

# Check if Claude Code is installed
if ! command -v claude &> /dev/null; then
    echo "❌ Error: Claude Code not found"
    echo ""
    echo "Install Claude Code first, then run this script."
    exit 1
fi

echo "✓ Claude Code found"
echo ""
echo "STEPS:"
echo "------"
echo "1. I'll open Claude Code in a new terminal"
echo "2. You run: /context"
echo "3. Copy the MCP server lines (showing token counts)"
echo "4. Paste them here"
echo "5. I'll update the cache with real measurements"
echo ""
echo -n "Ready? Press Enter to start..."
read

echo ""

# Open Claude Code in new terminal (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript <<EOF 2>/dev/null
tell application "Terminal"
    do script "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo 'MCP Impact Measurement - Claude Code' && echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo '' && echo '1. Run this command: /context' && echo '2. Copy the MCP server lines (with token counts)' && echo '3. Paste in the other terminal' && echo '' && claude"
    activate
end tell
EOF
    echo "✓ Opened Claude Code in new terminal"
else
    echo "ℹ️  Please open another terminal and run: claude"
fi

echo ""
echo "Now in Claude Code terminal:"
echo "  1. Type: /context"
echo "  2. Copy lines like: 'filesystem: 1,450 tokens'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paste /context output below (Ctrl+D when done):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
