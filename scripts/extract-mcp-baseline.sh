#!/bin/bash
# Extract MCP Basal Consumption from Claude Code JSONL Logs
#
# Analyzes actual Claude Code usage logs to determine real token consumption
# for MCP servers. Uses the first message's cache_creation_input_tokens as
# the baseline MCP overhead.
#
# Usage:
#   ./scripts/extract-mcp-baseline.sh [project-dir]
#
# Examples:
#   ./scripts/extract-mcp-baseline.sh                           # Use current project
#   ./scripts/extract-mcp-baseline.sh /Users/user/src/myapp    # Specific project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"

echo "================================================"
echo "MCP Baseline Extraction from JSONL Logs"
echo "================================================"
echo ""

# Determine project directory
if [ $# -eq 1 ]; then
    PROJECT_DIR="$1"
else
    PROJECT_DIR="$(pwd)"
fi

echo "📁 Project directory: $PROJECT_DIR"
echo ""

# Find JSONL log directory
CLAUDE_PROJECTS="$HOME/.claude/projects"
if [ ! -d "$CLAUDE_PROJECTS" ]; then
    echo "❌ Error: Claude projects directory not found"
    echo "   Expected: $CLAUDE_PROJECTS"
    echo ""
    echo "💡 This tool requires Claude Code to be installed and used"
    exit 1
fi

# Encode project path (Claude uses URL-encoded paths with - instead of /)
# Example: /Users/foo/src/bar -> -Users-foo-src-bar
PROJECT_ENCODED=$(echo "$PROJECT_DIR" | tr '/' '-')

LOG_DIR="$CLAUDE_PROJECTS/$PROJECT_ENCODED"

if [ ! -d "$LOG_DIR" ]; then
    echo "❌ Error: No logs found for this project"
    echo "   Looking in: $LOG_DIR"
    echo ""
    echo "💡 Use Claude Code in this project first to generate logs"
    exit 1
fi

echo "✓ Found log directory: $LOG_DIR"
echo ""

# Find most recent JSONL file
LATEST_LOG=$(find "$LOG_DIR" -name "*.jsonl" -type f -mtime -7 2>/dev/null | head -1 || true)

if [ -z "$LATEST_LOG" ]; then
    # Try without time constraint
    LATEST_LOG=$(find "$LOG_DIR" -name "*.jsonl" -type f 2>/dev/null | sort -r | head -1 || true)
fi

if [ -z "$LATEST_LOG" ]; then
    echo "❌ Error: No JSONL logs found"
    echo "   Directory: $LOG_DIR"
    exit 1
fi

echo "📄 Analyzing: $(basename "$LATEST_LOG")"
echo ""

# Extract first assistant message with cache creation
echo "🔍 Extracting MCP baseline from first message..."
echo ""

FIRST_MSG=$(grep '"type":"assistant"' "$LATEST_LOG" 2>/dev/null | head -1 || true)

if [ -z "$FIRST_MSG" ]; then
    echo "❌ Error: No assistant messages found in log"
    exit 1
fi

# Extract token usage
BASELINE_TOKENS=$(echo "$FIRST_MSG" | jq -r '.message.usage.cache_creation_input_tokens // 0' 2>/dev/null || echo "0")
INPUT_TOKENS=$(echo "$FIRST_MSG" | jq -r '.message.usage.input_tokens // 0' 2>/dev/null || echo "0")
CACHE_READ_TOKENS=$(echo "$FIRST_MSG" | jq -r '.message.usage.cache_read_input_tokens // 0' 2>/dev/null || echo "0")

if [ "$BASELINE_TOKENS" = "0" ]; then
    echo "⚠️  Warning: No cache_creation_input_tokens found"
    echo "   This might not be the first message of a session"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Token Breakdown (First Message)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cache creation:  $BASELINE_TOKENS tokens"
echo "                 (System + Built-in tools + MCP tools)"
echo "Input tokens:    $INPUT_TOKENS tokens"
echo "Cache read:      $CACHE_READ_TOKENS tokens"
echo ""
echo "ℹ️  Note: Cache creation includes everything Claude loads at"
echo "   startup: system prompts, built-in tools (Bash, Read, Edit,"
echo "   Write, etc.), AND all MCP server tool definitions."
echo ""

# Find all MCP servers used in this session
echo "🔧 Detecting active MCP servers..."
echo ""

# Extract unique MCP server names from tool_use events
MCP_SERVERS=$(grep -o '"name":"mcp__[^"]*"' "$LATEST_LOG" 2>/dev/null | \
    sed 's/"name":"mcp__//' | \
    sed 's/__.*"//' | \
    sort -u || echo "")

if [ -z "$MCP_SERVERS" ]; then
    echo "⚠️  No MCP server usage detected in this session"
    echo ""
    exit 0
fi

SERVER_COUNT=$(echo "$MCP_SERVERS" | wc -l | tr -d ' ')

echo "Found $SERVER_COUNT active MCP server(s):"
echo "$MCP_SERVERS" | while read -r server; do
    echo "  • $server"
done
echo ""

# Estimate per-server tokens (rough heuristic: divide baseline by server count)
if [ "$BASELINE_TOKENS" -gt 0 ] && [ "$SERVER_COUNT" -gt 0 ]; then
    AVG_PER_SERVER=$((BASELINE_TOKENS / SERVER_COUNT))

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Estimated Per-Server Breakdown"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Average per server: ~$AVG_PER_SERVER tokens"
    echo ""

    echo "$MCP_SERVERS" | while read -r server; do
        # Determine category
        if [ "$AVG_PER_SERVER" -ge 1000 ]; then
            category="Heavy"
            emoji="🔴"
        elif [ "$AVG_PER_SERVER" -ge 100 ]; then
            category="Medium"
            emoji="🟡"
        else
            category="Light"
            emoji="🟢"
        fi

        echo "  $emoji $server: ~$AVG_PER_SERVER tokens ($category)"
    done
    echo ""
fi

# Offer to update cache
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Update Cache?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Would you like to update data/mcp-cache.json with these measurements?"
echo ""
echo "Options:"
echo "  y - Update cache with measured data"
echo "  n - Just show analysis (default)"
echo ""
read -r -p "Update cache? [y/N] " response

case "$response" in
    [yY][eE][sS]|[yY])
        echo ""
        echo "Updating cache..."

        # Backup cache
        cp "$CACHE_FILE" "$CACHE_FILE.backup"
        echo "💾 Backup created: $CACHE_FILE.backup"

        UPDATED=0
        while IFS= read -r server; do
            [ -z "$server" ] && continue

            # Check if server exists in cache
            if jq -e ".servers.\"$server\"" "$CACHE_FILE" >/dev/null 2>&1; then
                # Determine category
                if [ "$AVG_PER_SERVER" -ge 1000 ]; then
                    category="Heavy"
                elif [ "$AVG_PER_SERVER" -ge 100 ]; then
                    category="Medium"
                else
                    category="Light"
                fi

                # Update cache
                jq --arg s "$server" \
                   --argjson t "$AVG_PER_SERVER" \
                   --arg c "$category" \
                   --arg date "$(date -u +"%Y-%m-%d")" \
                   '.servers[$s].impact.estimated_tokens = $t |
                    .servers[$s].impact.category = $c |
                    .servers[$s].impact.method = "measured-jsonl" |
                    .servers[$s].impact.measured_at = $date' \
                   "$CACHE_FILE" > "$CACHE_FILE.tmp"
                mv "$CACHE_FILE.tmp" "$CACHE_FILE"
                echo "  ✓ Updated $server"
                UPDATED=$((UPDATED + 1))
            else
                echo "  ⚠️  $server not in cache (skipped)"
            fi
        done <<< "$MCP_SERVERS"

        echo ""
        echo "✅ Updated $UPDATED server(s) in cache"
        echo ""
        echo "Next steps:"
        echo "  git diff data/mcp-cache.json"
        echo "  git add data/mcp-cache.json"
        echo "  git commit -m 'Update MCP impact with JSONL measurements'"
        ;;
    *)
        echo ""
        echo "ℹ️  Cache not modified"
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Total baseline overhead: $BASELINE_TOKENS tokens"
echo "   (System + Built-in + $SERVER_COUNT MCP server(s))"
echo "🔧 Active MCP servers: $SERVER_COUNT"
echo "💡 Method: Real JSONL log analysis"
echo ""
echo "⚠️  Limitations:"
echo "   • Baseline includes system prompts and built-in tools"
echo "   • Cannot isolate individual MCP server contributions"
echo "   • Per-server estimates are rough averages"
echo "   • For precise MCP-only data, use Claude's /context command"
echo ""
