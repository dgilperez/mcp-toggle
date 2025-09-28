#!/bin/bash
# Update ~/.claude.json to use global MCP installations

set -e

echo "📝 Updating Claude config to use global MCP servers..."

CLAUDE_CONFIG="$HOME/.claude.json"
MCP_HOME="$HOME/.mcp"

# Backup current config
cp "$CLAUDE_CONFIG" "$CLAUDE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"

# Use jq to update the mcpServers section
# This preserves all other settings while updating MCP servers
cat > /tmp/mcp-servers.json << EOF
{
  "brave-search": {
    "command": "node",
    "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-brave-search/dist/index.js"],
    "env": {
      "BRAVE_API_KEY": "\${BRAVE_API_KEY}"
    }
  },
  "pubmed": {
    "command": "node",
    "args": ["$MCP_HOME/servers/node_modules/@cyanheads/pubmed-mcp-server/dist/index.js"],
    "env": {
      "NCBI_API_KEY": "\${PUBMED_API_KEY}",
      "MCP_TRANSPORT_TYPE": "stdio"
    }
  },
  "github": {
    "command": "node",
    "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-github/dist/index.js"],
    "env": {
      "GITHUB_TOKEN": "\${GH_TOKEN}"
    }
  },
  "filesystem": {
    "command": "node",
    "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js"],
    "env": {}
  },
  "notion": {
    "command": "node",
    "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-notion/dist/index.js"],
    "env": {
      "NOTION_API_KEY": "\${NOTION_API_KEY}"
    }
  }
}
EOF

# Update the config using jq
jq --slurpfile servers /tmp/mcp-servers.json '.mcpServers = $servers[0]' "$CLAUDE_CONFIG" > /tmp/claude-updated.json
mv /tmp/claude-updated.json "$CLAUDE_CONFIG"

rm /tmp/mcp-servers.json

echo "✅ Claude config updated to use global MCP servers"
echo ""
echo "🚀 Claude Code will now use fast, locally-installed MCP servers!"
echo "   No more npx downloads!"