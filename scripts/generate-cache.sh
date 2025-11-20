#!/bin/bash
# Generate MCP Server Cache from Official Registry and npm
# Runs weekly via GitHub Actions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_FILE="$PROJECT_ROOT/data/mcp-cache.json"

echo "Generating MCP cache..."
echo ""

# Create temp file for building cache
TEMP_CACHE=$(mktemp)

# Start JSON structure
cat > "$TEMP_CACHE" <<EOF
{
  "_meta": {
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "version": "1.0.0",
    "sources": {
      "mcp_registry": "https://registry.modelcontextprotocol.io/v0/servers",
      "npm_registry": "https://registry.npmjs.org",
      "manual_overrides": true
    }
  },
  "servers": {},
  "categories": {
    "database": [],
    "search": [],
    "filesystem": [],
    "dev-tools": [],
    "productivity": [],
    "ai": []
  }
}
EOF

echo "✓ Fetching from MCP official registry..."

# Fetch from MCP registry (limit 100 for now)
MCP_SERVERS=$(curl -s "https://registry.modelcontextprotocol.io/v0/servers?limit=100" | jq -c '.servers[]' || echo "[]")

echo "✓ Processing servers and fetching npm data..."

# Process each server
echo "$MCP_SERVERS" | while IFS= read -r server; do
    name=$(echo "$server" | jq -r '.name // empty')
    description=$(echo "$server" | jq -r '.description // empty')

    # Extract package info (look for npm packages)
    npm_package=$(echo "$server" | jq -r '.packages[]? | select(.type == "npm") | .spec // empty' | head -1)

    if [ -n "$npm_package" ] && [ -n "$name" ]; then
        server_id=$(echo "$name" | sed 's/.*\///')  # Extract last part after /

        # Fetch npm stats
        npm_data=$(curl -s "https://registry.npmjs.org/$npm_package" 2>/dev/null || echo "{}")
        npm_version=$(echo "$npm_data" | jq -r '."dist-tags".latest // "unknown"')
        npm_updated=$(echo "$npm_data" | jq -r '.time.modified // .time.created // "unknown"')

        # Get download stats (from npm API, approximate)
        npm_downloads=$(curl -s "https://api.npmjs.org/downloads/point/last-week/$npm_package" 2>/dev/null | jq -r '.downloads // 0')

        # Update temp cache
        jq --arg id "$server_id" \
           --arg pkg "$npm_package" \
           --arg desc "$description" \
           --arg ver "$npm_version" \
           --arg updated "$npm_updated" \
           --argjson downloads "$npm_downloads" \
           '.servers[$id] = {
              "package": $pkg,
              "description": $desc,
              "impact": {
                "estimated_tokens": 0,
                "category": "Unknown",
                "method": "pending",
                "measured_at": null
              },
              "npm": {
                "downloads_weekly": $downloads,
                "version": $ver,
                "updated": $updated
              },
              "mcp_registry": {
                "official": true,
                "verified": true
              },
              "categories": []
            }' "$TEMP_CACHE" > "$TEMP_CACHE.new" && mv "$TEMP_CACHE.new" "$TEMP_CACHE"

        echo "  Added: $server_id ($npm_package)"
    fi
done

# Merge with manual metadata if it exists
MANUAL_META="$PROJECT_ROOT/data/manual-metadata.json"
if [ -f "$MANUAL_META" ]; then
    echo ""
    echo "✓ Merging manual metadata..."
    jq -s '.[0] * .[1]' "$TEMP_CACHE" "$MANUAL_META" > "$TEMP_CACHE.new"
    mv "$TEMP_CACHE.new" "$TEMP_CACHE"
fi

# Rebuild categories from server data
echo ""
echo "✓ Rebuilding category index..."
jq '
  # Start with empty categories object
  .categories = {} |
  # For each server, add to its categories
  .servers | to_entries[] | .value.categories[]? as $cat | $cat as $category |
  # Add this server to the category
  (.key) as $server_name |
  . |
  # Initialize category array if needed, then add server if not already there
  .categories[$category] = (.categories[$category] // []) |
  if (.categories[$category] | index($server_name)) then . else .categories[$category] += [$server_name] end
' "$TEMP_CACHE" | jq -s '
  # Merge all the category updates together
  reduce .[] as $item ({}; . * $item)
' > "$TEMP_CACHE.new"

# Actually, let me use a simpler approach - rebuild categories from scratch
jq '
  .categories = (
    reduce (.servers | to_entries[]) as $entry (
      {};
      reduce ($entry.value.categories // [])[] as $cat (
        .;
        .[$cat] = (.[$cat] // []) + [$entry.key] | .[$cat] |= unique
      )
    )
  )
' "$TEMP_CACHE" > "$TEMP_CACHE.new"
mv "$TEMP_CACHE.new" "$TEMP_CACHE"

# Save final cache
mv "$TEMP_CACHE" "$CACHE_FILE"

echo ""
echo "✓ Cache generated: $CACHE_FILE"
echo "  Servers: $(jq '.servers | length' "$CACHE_FILE")"
echo "  Categories: $(jq '.categories | length' "$CACHE_FILE")"
