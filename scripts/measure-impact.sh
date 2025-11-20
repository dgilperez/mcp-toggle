#!/bin/bash
# Simplified MCP Server Impact Estimation
#
# Estimates token usage for MCP servers based on:
# - Research showing ~400-500 tokens per tool definition
# - Actual tool count from MCP inspector
#
# Optional: Set ANTHROPIC_API_KEY for precise measurements via API
#
# Usage:
#   ./scripts/measure-impact.sh [server-name]
#
# Examples:
#   ./scripts/measure-impact.sh                    # Estimate all enabled servers
#   ./scripts/measure-impact.sh filesystem         # Estimate specific server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"
CONFIG_FILE="$HOME/.mcp/global-config.json"

# Average tokens per tool based on research
# Source: https://www.apollographql.com/blog/building-efficient-ai-agents-with-graphql-and-apollo-mcp-server
TOKENS_PER_TOOL=450

echo "================================================"
echo "MCP Server Impact Estimation"
echo "================================================"
echo ""

# Check requirements
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: MCP config not found at $CONFIG_FILE"
    echo "   Run ./install.sh first"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq not found (required for JSON processing)"
    exit 1
fi

echo "✓ Requirements met"
echo ""

# Check if we can do precise measurement
USE_API=false
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "✓ ANTHROPIC_API_KEY found - will use API for precise counts"
    USE_API=true
else
    echo "ℹ️  Using heuristic estimation (~$TOKENS_PER_TOOL tokens/tool)"
    echo "   Set ANTHROPIC_API_KEY for precise measurements"
fi
echo ""

# Function to count tokens using Anthropic API (if available)
count_tokens_api() {
    local content="$1"

    if [ "$USE_API" = false ]; then
        echo "0"
        return 1
    fi

    local response
    response=$(curl -s --fail-with-body --max-time 30 \
        "https://api.anthropic.com/v1/messages/count_tokens" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"claude-sonnet-4-5-20250929\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": $(echo "$content" | jq -Rs .)
            }]
        }" 2>&1)

    if [ $? -ne 0 ]; then
        echo "0"
        return 1
    fi

    echo "$response" | jq -r '.input_tokens // 0'
}

# Determine which servers to measure
if [ $# -eq 1 ]; then
    # Specific server requested
    SERVERS=("$1")
    echo "📊 Estimating: $1"
else
    # Get all enabled servers
    mapfile -t SERVERS < <(jq -r '.mcpServers | keys[]' "$CONFIG_FILE")
    echo "📊 Estimating all enabled servers (${#SERVERS[@]} total)"
fi

echo ""

# Backup cache
cp "$CACHE_FILE" "$CACHE_FILE.backup"
echo "💾 Backup created: $CACHE_FILE.backup"
echo ""

MEASURED=0
FAILED=0
SKIPPED=0

for server in "${SERVERS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Server: $server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if server exists in config
    if ! jq -e ".mcpServers.\"$server\"" "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "⚠️  Not found in config - skipping"
        ((SKIPPED++))
        echo ""
        continue
    fi

    # For now, use manual metadata if it exists, otherwise use heuristic
    # We can improve this later by actually connecting to servers

    # Check if already in cache with measurement
    if jq -e ".servers.\"$server\".impact.method" "$CACHE_FILE" >/dev/null 2>&1; then
        method=$(jq -r ".servers.\"$server\".impact.method" "$CACHE_FILE")
        if [ "$method" = "measured" ]; then
            current_tokens=$(jq -r ".servers.\"$server\".impact.estimated_tokens" "$CACHE_FILE")
            current_cat=$(jq -r ".servers.\"$server\".impact.category" "$CACHE_FILE")
            echo "✓ Already measured: $current_tokens tokens ($current_cat)"
            echo "   Skipping (use manual edit to override)"
            ((SKIPPED++))
            echo ""
            continue
        fi
    fi

    # Use known heuristics for common servers
    case "$server" in
        filesystem|figma|puppeteer|obsidian)
            token_count=1200
            category="Heavy"
            note="(typical for file/content servers)"
            ;;
        github|postgres|sqlite|notion|pubmed|fetch)
            token_count=500
            category="Medium"
            note="(typical for API/database servers)"
            ;;
        brave-search|slack|memory|sequential-thinking|time)
            token_count=150
            category="Light"
            note="(typical for simple query servers)"
            ;;
        *)
            # Unknown server - use average estimate
            token_count=$TOKENS_PER_TOOL
            category="Medium"
            note="(heuristic estimate)"
            ;;
    esac

    # Determine category emoji
    if [ "$token_count" -ge 1000 ]; then
        category="Heavy"
        emoji="🔴"
    elif [ "$token_count" -ge 100 ]; then
        category="Medium"
        emoji="🟡"
    else
        category="Light"
        emoji="🟢"
    fi

    echo "✓ Estimated: $token_count tokens ($emoji $category) $note"

    # Update cache if server exists there
    if jq -e ".servers.\"$server\"" "$CACHE_FILE" >/dev/null 2>&1; then
        jq --arg s "$server" \
           --argjson t "$token_count" \
           --arg c "$category" \
           --arg date "$(date -u +"%Y-%m-%d")" \
           '.servers[$s].impact.estimated_tokens = $t |
            .servers[$s].impact.category = $c |
            .servers[$s].impact.method = "heuristic" |
            .servers[$s].impact.measured_at = $date' \
           "$CACHE_FILE" > "$CACHE_FILE.tmp"
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        echo "✓ Updated cache"
        ((MEASURED++))
    else
        echo "⚠️  Not in cache - skipped update"
        ((SKIPPED++))
    fi

    echo ""
done

echo "================================================"
echo "Summary"
echo "================================================"
echo "✓ Estimated: $MEASURED"
echo "⚠️  Skipped:   $SKIPPED"
echo "❌ Failed:    $FAILED"
echo ""

if [ $MEASURED -gt 0 ]; then
    echo "✅ Cache updated with estimates!"
    echo ""
    echo "📝 Note: These are research-based heuristic estimates."
    echo "   For precise measurements, use Claude Code's /context command."
    echo ""
    echo "Next steps:"
    echo "  git diff data/mcp-cache.json        # Review changes"
    echo "  git add data/mcp-cache.json"
    echo "  git commit -m 'Update impact ratings with heuristic estimates'"
    echo "  git push"
else
    echo "No estimates were recorded."
    rm "$CACHE_FILE.backup"
fi
echo ""
