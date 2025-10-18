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

# Search for MCP servers
search_servers() {
    local query="$1"
    local category="$2"

    echo -e "${BLUE}=== MCP Server Discovery ===${NC}\n"

    if [ -z "$query" ]; then
        show_curated_servers "$category"
    else
        search_npm "$query"
    fi
}

# Show curated popular MCP servers
show_curated_servers() {
    local category="$1"

    echo -e "${GREEN}Popular MCP Servers:${NC}\n"

    # Define curated servers (name|||package|||description)
    local official=(
        "memory|||@modelcontextprotocol/server-memory|||Knowledge graph persistent memory"
        "sequential-thinking|||@modelcontextprotocol/server-sequential-thinking|||Dynamic problem-solving"
        "time|||@modelcontextprotocol/server-time|||Time and timezone conversion"
        "everything|||@modelcontextprotocol/server-everything|||Full MCP demo server"
    )

    local database=(
        "postgres|||mcp-postgres-server|||PostgreSQL database operations"
        "sqlite|||@modelcontextprotocol/server-sqlite|||SQLite database access"
    )

    local productivity=(
        "google-drive|||@modelcontextprotocol/server-gdrive|||Google Drive integration"
        "slack|||@modelcontextprotocol/server-slack|||Slack workspace access"
        "obsidian|||@mauricio.wolff/mcp-obsidian|||Obsidian vault operations"
        "notion|||@notionhq/notion-mcp-server|||Notion workspace integration"
    )

    local developer=(
        "sentry|||@sentry/mcp-server|||Error tracking and monitoring"
        "puppeteer|||@modelcontextprotocol/server-puppeteer|||Browser automation"
        "github|||installed|||GitHub operations"
        "filesystem|||installed|||File operations"
    )

    local search=(
        "brave-search|||@modelcontextprotocol/server-brave-search|||Privacy-focused web search"
        "pubmed|||@cyanheads/pubmed-mcp-server|||Scientific literature search"
    )

    local design=(
        "figma|||figma-developer-mcp|||Figma design file access"
    )

    case "$category" in
        database|db)
            echo -e "${YELLOW}Database Servers:${NC}"
            for server in "${database[@]}"; do
                print_server_array "$server"
            done
            ;;
        productivity|prod)
            echo -e "${YELLOW}Productivity Servers:${NC}"
            for server in "${productivity[@]}"; do
                print_server_array "$server"
            done
            ;;
        dev|developer)
            echo -e "${YELLOW}Developer Tools:${NC}"
            for server in "${developer[@]}"; do
                print_server_array "$server"
            done
            ;;
        search|data)
            echo -e "${YELLOW}Search & Data:${NC}"
            for server in "${search[@]}"; do
                print_server_array "$server"
            done
            ;;
        official)
            echo -e "${YELLOW}Official MCP Servers:${NC}"
            for server in "${official[@]}"; do
                print_server_array "$server"
            done
            ;;
        *)
            # Show all categories
            echo -e "${YELLOW}📚 Official Servers:${NC}"
            for server in "${official[@]}"; do
                print_server_array "$server"
            done

            echo -e "\n${YELLOW}💾 Database:${NC}"
            for server in "${database[@]}"; do
                print_server_array "$server"
            done

            echo -e "\n${YELLOW}🔍 Search & Research:${NC}"
            for server in "${search[@]}"; do
                print_server_array "$server"
            done

            echo -e "\n${YELLOW}📝 Productivity:${NC}"
            for server in "${productivity[@]}"; do
                print_server_array "$server"
            done

            echo -e "\n${YELLOW}🛠️  Developer Tools:${NC}"
            for server in "${developer[@]}"; do
                print_server_array "$server"
            done

            echo -e "\n${YELLOW}🎨 Design:${NC}"
            for server in "${design[@]}"; do
                print_server_array "$server"
            done
            ;;
    esac

    echo ""
    echo -e "${BLUE}To install a server:${NC}"
    echo "  cd ~/.mcp/servers && npm install <package-name>"
    echo "  Then add to Claude config with: mcp-toggle add <server-name>"
    echo ""
    echo -e "${BLUE}Categories:${NC}"
    echo "  mcp-toggle discover official       # Official MCP servers"
    echo "  mcp-toggle discover database       # Database servers"
    echo "  mcp-toggle discover productivity   # Productivity tools"
    echo "  mcp-toggle discover dev            # Developer tools"
    echo "  mcp-toggle discover search         # Search & data servers"
    echo ""
}

# Print server info from array format (name|||package|||description)
print_server_array() {
    local server_data="$1"
    local name=$(echo "$server_data" | cut -d'|' -f1)
    local package=$(echo "$server_data" | cut -d'|' -f4)
    local description=$(echo "$server_data" | cut -d'|' -f7-)

    # Check if already installed
    local status=""
    if [ -d "$HOME/.mcp/servers/node_modules/$(echo $package | sed 's/@//' | cut -d'/' -f1-2)" ] || [ "$package" = "installed" ]; then
        status="${GREEN}[installed]${NC}"
    fi

    printf "  %-25s %-40s %b\n" "$name" "$package" "$status"
    printf "    └─ %s\n" "$description"
}

# Search npm for MCP packages
search_npm() {
    local query="$1"

    echo -e "${YELLOW}Searching npm for: $query${NC}\n"

    # Search npm and format results
    npm search "mcp $query" 2>/dev/null | head -20 | grep -v "^NAME" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "  $line"
        fi
    done

    echo ""
    echo -e "${BLUE}To see more results, use:${NC}"
    echo "  npm search \"mcp $query\""
    echo ""
}

# Show help
show_help() {
    echo -e "${BLUE}MCP Server Toggle Script${NC}"
    echo ""
    echo "Enable or disable MCP servers without losing configuration."
    echo ""
    echo -e "${GREEN}Usage:${NC}"
    echo "  $0 enable <server-name>       Enable a disabled server"
    echo "  $0 disable <server-name>      Disable an enabled server"
    echo "  $0 status [server-name]       Show status of server(s)"
    echo "  $0 list                       List all servers (enabled and disabled)"
    echo "  $0 discover [category]        Discover popular MCP servers"
    echo "  $0 search <query>             Search npm for MCP servers"
    echo "  $0 help                       Show this help message"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 disable figma              Disable Figma MCP server"
    echo "  $0 enable figma               Re-enable Figma MCP server"
    echo "  $0 status figma               Check if Figma is enabled or disabled"
    echo "  $0 list                       List all servers"
    echo "  $0 discover                   Show all popular MCP servers"
    echo "  $0 discover database          Show database MCP servers"
    echo "  $0 search postgres            Search npm for postgres MCP servers"
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
        discover)
            search_servers "" "$server_name"
            ;;
        search)
            if [ -z "$server_name" ]; then
                echo -e "${RED}Error: Search query required${NC}"
                echo "Usage: $0 search <query>"
                exit 1
            fi
            search_servers "$server_name"
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
