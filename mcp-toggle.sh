#!/bin/bash
#
# MCP Server Toggle Script
# Enable/disable MCP servers without losing configuration
#
# Usage:
#   ./mcp-toggle.sh enable <server-name>
#   ./mcp-toggle.sh disable <server-name>
#   ./mcp-toggle.sh status [server-name]
#   ./mcp-toggle.sh list
#

set -e

CLAUDE_CONFIG="$HOME/.claude.json"
BACKUP_DIR="$HOME/.mcp/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

# Check if config exists
if [ ! -f "$CLAUDE_CONFIG" ]; then
    echo -e "${RED}Error: Claude config not found at $CLAUDE_CONFIG${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup config
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/claude-config-$timestamp.json"
    cp "$CLAUDE_CONFIG" "$backup_file"
    echo -e "${BLUE}Backup created: $backup_file${NC}"
}

# List all servers
list_servers() {
    echo -e "${BLUE}=== MCP Servers ===${NC}\n"

    echo -e "${GREEN}Enabled:${NC}"
    jq -r '.mcpServers // {} | keys[]' "$CLAUDE_CONFIG" 2>/dev/null | while read -r server; do
        echo "  ✓ $server"
    done || echo "  (none)"

    echo ""
    echo -e "${YELLOW}Disabled:${NC}"
    jq -r '._disabled_mcpServers // {} | keys[]' "$CLAUDE_CONFIG" 2>/dev/null | while read -r server; do
        echo "  ✗ $server"
    done || echo "  (none)"
}

# Get server status
get_status() {
    local server_name="$1"

    if [ -z "$server_name" ]; then
        list_servers
        return
    fi

    # Check if enabled
    if jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${GREEN}✓ $server_name is ENABLED${NC}"
        return 0
    fi

    # Check if disabled
    if jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${YELLOW}✗ $server_name is DISABLED${NC}"
        return 0
    fi

    echo -e "${RED}✗ $server_name not found${NC}"
    return 1
}

# Enable a server
enable_server() {
    local server_name="$1"

    if [ -z "$server_name" ]; then
        echo -e "${RED}Error: Server name required${NC}"
        echo "Usage: $0 enable <server-name>"
        exit 1
    fi

    # Check if already enabled
    if jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${YELLOW}$server_name is already enabled${NC}"
        return 0
    fi

    # Check if exists in disabled
    if ! jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${RED}Error: $server_name not found in disabled servers${NC}"
        return 1
    fi

    # Backup before changes
    backup_config

    # Move from disabled to enabled
    local temp_file=$(mktemp)
    jq --arg name "$server_name" '
        .mcpServers[$name] = ._disabled_mcpServers[$name] |
        del(._disabled_mcpServers[$name])
    ' "$CLAUDE_CONFIG" > "$temp_file"

    mv "$temp_file" "$CLAUDE_CONFIG"
    echo -e "${GREEN}✓ Enabled $server_name${NC}"
}

# Disable a server
disable_server() {
    local server_name="$1"

    if [ -z "$server_name" ]; then
        echo -e "${RED}Error: Server name required${NC}"
        echo "Usage: $0 disable <server-name>"
        exit 1
    fi

    # Check if already disabled
    if jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${YELLOW}$server_name is already disabled${NC}"
        return 0
    fi

    # Check if exists in enabled
    if ! jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        echo -e "${RED}Error: $server_name not found in enabled servers${NC}"
        return 1
    fi

    # Backup before changes
    backup_config

    # Move from enabled to disabled
    local temp_file=$(mktemp)
    jq --arg name "$server_name" '
        ._disabled_mcpServers[$name] = .mcpServers[$name] |
        del(.mcpServers[$name])
    ' "$CLAUDE_CONFIG" > "$temp_file"

    mv "$temp_file" "$CLAUDE_CONFIG"
    echo -e "${YELLOW}✓ Disabled $server_name${NC}"
}

# Show help
show_help() {
    echo -e "${BLUE}MCP Server Toggle Script${NC}"
    echo ""
    echo "Enable or disable MCP servers without losing configuration."
    echo ""
    echo -e "${GREEN}Usage:${NC}"
    echo "  $0 enable <server-name>     Enable a disabled server"
    echo "  $0 disable <server-name>    Disable an enabled server"
    echo "  $0 status [server-name]     Show status of server(s)"
    echo "  $0 list                     List all servers (enabled and disabled)"
    echo "  $0 help                     Show this help message"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 disable figma            Disable Figma MCP server"
    echo "  $0 enable figma             Re-enable Figma MCP server"
    echo "  $0 status figma             Check if Figma is enabled or disabled"
    echo "  $0 list                     List all servers"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo "  - Configuration is preserved when disabling"
    echo "  - Backups are created automatically in ~/.mcp/backups/"
    echo "  - Disabled servers are stored in _disabled_mcpServers"
    echo ""
    echo -e "${BLUE}File Locations:${NC}"
    echo "  Config:  $CLAUDE_CONFIG"
    echo "  Backups: $BACKUP_DIR"
    echo ""
}

# Main command handler
main() {
    local command="$1"
    local server_name="$2"

    case "$command" in
        enable)
            enable_server "$server_name"
            ;;
        disable)
            disable_server "$server_name"
            ;;
        status)
            get_status "$server_name"
            ;;
        list)
            list_servers
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}\n"
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
