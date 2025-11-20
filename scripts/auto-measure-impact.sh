#!/bin/bash
# Automatically measure MCP server impact using Claude Code
# This is a convenience wrapper that opens two terminals

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "Auto-measure MCP Server Impact"
echo "========================================"
echo ""
echo "This script will:"
echo "  1. Start Claude Code in a new terminal"
echo "  2. Show you the /context command to run"
echo "  3. Wait for you to paste the output"
echo ""
echo "Press Enter to continue..."
read

# Open new terminal with Claude Code
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    osascript <<EOF
tell application "Terminal"
    do script "echo 'Run this command: /context' && echo '' && echo 'Then copy the MCP Servers section and paste it in the other terminal' && echo '' && claude"
    activate
end tell
EOF
else
    # Linux/other - try gnome-terminal or xterm
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "echo 'Run: /context'; echo 'Copy MCP section'; claude; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "echo 'Run: /context'; echo 'Copy MCP section'; claude; bash" &
    else
        echo "Could not open new terminal automatically"
        echo "Please open a new terminal manually and run: claude"
    fi
fi

echo ""
echo "Waiting for Claude Code to start..."
sleep 2

echo ""
echo "Now in Claude Code:"
echo "  1. Type: /context"
echo "  2. Copy the lines showing token counts"
echo ""

# Run the update script which will wait for input
exec "$SCRIPT_DIR/update-impact-from-context.sh"
