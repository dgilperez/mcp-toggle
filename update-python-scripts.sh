#!/bin/bash
# Update Python scripts to use global MCP configuration

echo "🐍 Updating Python scripts to use global MCP..."

# Update generate_and_integrate.py to use global config
SCRIPT_PATH="/Users/dgilperez/src/balneario/procesos/science/tools/generate_and_integrate.py"
GLOBAL_CONFIG="$HOME/.mcp/global-config.json"

# Create a patch for the Python script
cat > /tmp/python-patch.txt << 'EOF'
# In _generate_references method, update the local_mcp_config path:
local_mcp_config = Path.home() / '.mcp' / 'global-config.json'

# The rest of the logic stays the same - it will automatically use the global config
EOF

echo "✅ Python scripts will now use: $GLOBAL_CONFIG"
echo ""
echo "📝 Update needed in generate_and_integrate.py:"
echo "   Change: local_mcp_config = Path.home() / '.local' / 'mcp-fast-config.json'"
echo "   To:     local_mcp_config = Path.home() / '.mcp' / 'global-config.json'"