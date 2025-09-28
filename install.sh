#!/bin/bash
# Global MCP Server Installation and Configuration
# This installs MCP servers globally for ALL tools to use

set -e

echo "🚀 Global MCP Server Setup"
echo "=========================="
echo ""

# Configuration
MCP_HOME="$HOME/.mcp"
MCP_SERVERS="$MCP_HOME/servers"
MCP_CONFIG="$MCP_HOME/global-config.json"
CLAUDE_CONFIG="$HOME/.claude.json"

# Create directories
mkdir -p "$MCP_SERVERS"
cd "$MCP_SERVERS"

# Initialize package.json if needed
if [ ! -f package.json ]; then
    echo "📦 Initializing MCP servers directory..."
    npm init -y > /dev/null 2>&1
fi

echo "📥 Installing/Updating MCP servers..."
echo ""

# Core MCP servers to install
declare -a servers=(
    "@modelcontextprotocol/server-brave-search"    # Web search
    "@cyanheads/pubmed-mcp-server"                 # Scientific literature
    "@modelcontextprotocol/server-github"          # GitHub repos
    "@modelcontextprotocol/server-filesystem"      # File operations
    "@notionhq/notion-mcp-server"                  # Notion workspace
    "@modelcontextprotocol/server-memory"          # Persistent memory
    "@modelcontextprotocol/server-fetch"           # Web content fetching
    "@modelcontextprotocol/server-git"             # Git operations
    "@modelcontextprotocol/server-puppeteer"       # Browser automation
)

# Install each server
for server in "${servers[@]}"; do
    echo "  📦 Installing $server..."
    npm install "$server" --save || echo "  ⚠️  Could not install $server (may not exist)"
done

echo ""
echo "✅ All MCP servers installed/updated"
echo ""

# Generate the global MCP configuration
echo "⚙️  Generating global MCP configuration..."

cat > "$MCP_CONFIG" << 'EOF'
{
  "mcpServers": {
    "brave-search": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-brave-search/dist/index.js"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    },
    "pubmed": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@cyanheads/pubmed-mcp-server/dist/index.js"],
      "env": {
        "NCBI_API_KEY": "${PUBMED_API_KEY}",
        "MCP_TRANSPORT_TYPE": "stdio"
      }
    },
    "github": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-github/dist/index.js"],
      "env": {
        "GITHUB_TOKEN": "${GH_TOKEN}"
      }
    },
    "filesystem": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js"],
      "env": {}
    },
    "notion": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@notionhq/notion-mcp-server/dist/index.js"],
      "env": {
        "NOTION_TOKEN": "${NOTION_TOKEN}"
      }
    },
    "notion-smithery": {
      "command": "npx",
      "args": [
        "-y",
        "@smithery/cli@latest",
        "run",
        "@smithery/notion",
        "--key",
        "${SMITHERY_KEY}",
        "--profile",
        "${SMITHERY_PROFILE}"
      ]
    }
  }
}
EOF

# Replace $MCP_HOME with actual path
sed -i.bak "s|\$MCP_HOME|$MCP_HOME|g" "$MCP_CONFIG"
rm "$MCP_CONFIG.bak"

echo "✅ Global config created at: $MCP_CONFIG"
echo ""

# Create update script
cat > "$MCP_HOME/update.sh" << 'EOF'
#!/bin/bash
# Update all MCP servers to latest versions

echo "🔄 Updating MCP servers..."
cd "$HOME/.mcp/servers"

# Update all packages
npm update

# Show installed versions
echo ""
echo "📦 Installed versions:"
npm list --depth=0

echo ""
echo "✅ Update complete!"
EOF

chmod +x "$MCP_HOME/update.sh"

# Create symlink for easy access
if [ ! -L "$HOME/.local/bin/mcp-update" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$MCP_HOME/update.sh" "$HOME/.local/bin/mcp-update"
    echo "✅ Created 'mcp-update' command"
fi

echo ""
echo "🎉 Global MCP setup complete!"
echo ""
echo "📍 Installation location: $MCP_SERVERS"
echo "📄 Global config: $MCP_CONFIG"
echo "🔄 To update servers: mcp-update"
echo ""
echo "⚠️  Next steps:"
echo "1. Run: source ~/.zshrc"
echo "2. Set API keys in ~/.zshrc:"
echo "   export BRAVE_API_KEY='your-key'"
echo "   export PUBMED_API_KEY='your-key'"
echo "   export GH_TOKEN='your-github-token'"
echo "   export NOTION_API_KEY='your-notion-key'"
echo ""
echo "3. Update ~/.claude.json to use this config (run update-claude-config.sh)"