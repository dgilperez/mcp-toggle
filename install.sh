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

echo "📥 Installing essential MCP servers..."
echo ""

# Install only essential servers - users can add more with discover/search
declare -a servers=(
    "@modelcontextprotocol/server-filesystem"      # File operations (always useful)
    "@modelcontextprotocol/server-fetch"           # Web content fetching
)

# Install each server
for server in "${servers[@]}"; do
    echo "  📦 Installing $server..."
    npm install "$server" --save || echo "  ⚠️  Could not install $server"
done

echo ""
echo "✅ Essential servers installed"
echo "💡 Discover more servers with: ./mcp-toggle.sh discover"
echo ""

# Generate the global MCP configuration
echo "⚙️  Generating global MCP configuration..."

cat > "$MCP_CONFIG" << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js"]
    },
    "fetch": {
      "command": "node",
      "args": ["$MCP_HOME/servers/node_modules/@modelcontextprotocol/server-fetch/dist/index.js"]
    }
  },
  "_disabled_mcpServers": {}
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
echo "🎉 Setup complete!"
echo ""
echo "📍 Installation: $MCP_SERVERS"
echo "📄 Config: $MCP_CONFIG"
echo ""
echo "Next steps:"
echo "1. Update Claude config: ./update-claude-config.sh"
echo "2. Sync to other tools: ./sync-all.sh"
echo "3. Discover more servers: ./mcp-toggle.sh discover"
echo ""
echo "Add more servers:"
echo "  cd ~/.mcp/servers && npm install @modelcontextprotocol/server-github"
echo "  Then add to config manually or use mcp-toggle.sh"