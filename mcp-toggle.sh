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

# Parse --config flag for testing
CLAUDE_CONFIG="$HOME/.claude.json"
if [ "${1:-}" = "--config" ]; then
    CLAUDE_CONFIG="$2"
    shift 2
fi

BACKUP_DIR="${MCP_BACKUP_DIR:-$HOME/.mcp/backups}"

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

# Get server metadata (impact and description)
get_server_metadata() {
    local server_name="$1"

    # Define metadata: server|||impact|||description
    # Impact: Heavy (1000+ tokens), Medium (100-1000), Light (<100)
    case "$server_name" in
        filesystem)
            echo "Heavy|||Reads/writes files; returns full file contents in context"
            ;;
        github)
            echo "Medium|||Fetches repos, issues, PRs; moderate API responses"
            ;;
        brave-search|brave)
            echo "Light|||Returns search results; compact responses"
            ;;
        pubmed)
            echo "Medium|||Scientific papers; abstract-heavy responses"
            ;;
        figma)
            echo "Heavy|||Design files; large JSON responses with layer data"
            ;;
        puppeteer)
            echo "Heavy|||Full webpage scraping; returns complete HTML/DOM"
            ;;
        postgres|sqlite)
            echo "Medium|||Database queries; result set size varies"
            ;;
        notion)
            echo "Medium|||Notion pages; moderate content per page"
            ;;
        slack)
            echo "Light|||Messages and channels; compact responses"
            ;;
        obsidian)
            echo "Heavy|||Note contents; returns full markdown files"
            ;;
        memory|sequential-thinking|time|everything)
            echo "Light|||Official MCP servers; minimal token usage"
            ;;
        *)
            echo "Unknown|||Impact not assessed; check server documentation"
            ;;
    esac
}

# Show detailed server info
show_server_info() {
    local server_name="$1"

    if [ -z "$server_name" ]; then
        echo -e "${RED}Error: Server name required${NC}"
        echo "Usage: $0 info <server-name>"
        exit 1
    fi

    echo -e "${BLUE}=== Server Information: $server_name ===${NC}\n"

    # Check status
    local status="NOT FOUND"
    local status_color="$RED"
    local config_section=""

    if jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        status="ENABLED"
        status_color="$GREEN"
        config_section="mcpServers"
    elif jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
        status="DISABLED"
        status_color="$YELLOW"
        config_section="_disabled_mcpServers"
    else
        echo -e "${RED}Server not found in configuration${NC}"
        return 1
    fi

    echo -e "${status_color}Status: $status${NC}\n"

    # Get metadata
    local metadata=$(get_server_metadata "$server_name")
    local impact=$(echo "$metadata" | cut -d'|' -f1)
    local description=$(echo "$metadata" | cut -d'|' -f4-)

    # Show impact
    local impact_color="$GREEN"
    case "$impact" in
        Heavy) impact_color="$RED" ;;
        Medium) impact_color="$YELLOW" ;;
        Light) impact_color="$GREEN" ;;
    esac

    echo -e "${BLUE}Context Window Impact:${NC} ${impact_color}$impact${NC}"
    echo -e "${BLUE}Description:${NC} $description"
    echo ""

    # Show configuration
    echo -e "${BLUE}Configuration:${NC}"
    jq -r ".$config_section.\"$server_name\"" "$CLAUDE_CONFIG" | sed 's/^/  /'
    echo ""

    # Impact guidance
    case "$impact" in
        Heavy)
            echo -e "${YELLOW}⚠ Heavy Impact:${NC} This server may consume significant context"
            echo "  Consider disabling when not actively needed"
            ;;
        Medium)
            echo -e "${BLUE}ℹ Medium Impact:${NC} Moderate token usage"
            echo "  Generally safe to keep enabled"
            ;;
        Light)
            echo -e "${GREEN}✓ Light Impact:${NC} Minimal token usage"
            echo "  Safe to keep enabled"
            ;;
    esac
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

# Enable server(s) - supports bulk operations
enable_server() {
    local server_names=("$@")

    if [ ${#server_names[@]} -eq 0 ]; then
        echo -e "${RED}Error: At least one server name required${NC}"
        echo "Usage: $0 enable <server-name> [server-name...]"
        exit 1
    fi

    # Validate all servers first (atomic operation)
    local to_enable=()
    for server_name in "${server_names[@]}"; do
        # Skip if already enabled
        if jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
            echo -e "${YELLOW}$server_name is already enabled${NC}"
            continue
        fi

        # Check if exists in disabled
        if ! jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
            echo -e "${RED}Error: $server_name not found in disabled servers${NC}"
            return 1
        fi

        to_enable+=("$server_name")
    done

    # If nothing to enable, exit successfully
    if [ ${#to_enable[@]} -eq 0 ]; then
        return 0
    fi

    # Backup before changes
    backup_config

    # Enable all servers in one operation
    local temp_file=$(mktemp)
    local jq_script='.'
    for server_name in "${to_enable[@]}"; do
        jq_script="$jq_script | .mcpServers[\"$server_name\"] = ._disabled_mcpServers[\"$server_name\"] | del(._disabled_mcpServers[\"$server_name\"])"
    done

    jq "$jq_script" "$CLAUDE_CONFIG" > "$temp_file"
    mv "$temp_file" "$CLAUDE_CONFIG"

    for server_name in "${to_enable[@]}"; do
        echo -e "${GREEN}✓ Enabled $server_name${NC}"
    done
}

# Disable server(s) - supports bulk operations
disable_server() {
    local server_names=("$@")

    if [ ${#server_names[@]} -eq 0 ]; then
        echo -e "${RED}Error: At least one server name required${NC}"
        echo "Usage: $0 disable <server-name> [server-name...]"
        exit 1
    fi

    # Validate all servers first (atomic operation)
    local to_disable=()
    for server_name in "${server_names[@]}"; do
        # Skip if already disabled
        if jq -e "._disabled_mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
            echo -e "${YELLOW}$server_name is already disabled${NC}"
            continue
        fi

        # Check if exists in enabled
        if ! jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
            echo -e "${RED}Error: $server_name not found in enabled servers${NC}"
            return 1
        fi

        to_disable+=("$server_name")
    done

    # If nothing to disable, exit successfully
    if [ ${#to_disable[@]} -eq 0 ]; then
        return 0
    fi

    # Backup before changes
    backup_config

    # Disable all servers in one operation
    local temp_file=$(mktemp)
    local jq_script='.'
    for server_name in "${to_disable[@]}"; do
        jq_script="$jq_script | ._disabled_mcpServers[\"$server_name\"] = .mcpServers[\"$server_name\"] | del(.mcpServers[\"$server_name\"])"
    done

    jq "$jq_script" "$CLAUDE_CONFIG" > "$temp_file"
    mv "$temp_file" "$CLAUDE_CONFIG"

    for server_name in "${to_disable[@]}"; do
        echo -e "${YELLOW}✓ Disabled $server_name${NC}"
    done
}

# Restart MCP servers (restart Claude Code)
restart_mcp() {
    local server_name="$1"

    echo -e "${BLUE}=== MCP Server Restart ===${NC}\n"

    if [ -n "$server_name" ]; then
        echo -e "${YELLOW}Note: Individual server restart not supported${NC}"
        echo -e "To restart $server_name, you need to restart Claude Code.\n"
    fi

    echo -e "${YELLOW}MCP servers run as subprocesses of Claude Code.${NC}"
    echo -e "${YELLOW}To restart them (e.g., to pick up new environment variables):${NC}\n"

    echo -e "${GREEN}Option 1: Restart current Claude Code session${NC}"
    echo "  1. Type: /exit"
    echo "  2. Start new session: claude"
    echo ""

    echo -e "${GREEN}Option 2: Kill all Claude Code processes${NC}"
    echo "  pkill -f 'claude|mcp.*server'"
    echo "  claude"
    echo ""

    echo -e "${BLUE}Common reasons to restart:${NC}"
    echo "  • Updated API keys in .zshrc"
    echo "  • Changed MCP server configuration"
    echo "  • Updated environment variables"
    echo "  • MCP server not responding"
    echo ""

    # Check if we're inside a Claude Code session
    if [ -n "$CLAUDE_CODE_SESSION" ] || pgrep -f "claude" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Claude Code appears to be running${NC}"
        echo -e "${YELLOW}  Exit your current session with /exit before restarting${NC}"
        echo ""
    fi

    # Show running MCP processes
    echo -e "${BLUE}Currently running MCP-related processes:${NC}"
    ps aux | grep -E "claude|mcp.*server|node.*\.mcp" | grep -v grep | awk '{print "  " $11, $12, $13, $14, $15}' || echo "  (none found)"
    echo ""
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

# Health check for MCP servers
health_check() {
    local specific_server="$1"

    echo -e "${BLUE}=== MCP Server Health Check ===${NC}\n"

    local total_checked=0
    local issues_found=0
    local servers_to_check=()

    # Determine which servers to check
    if [ -n "$specific_server" ]; then
        # Check if server exists and is enabled
        if jq -e ".mcpServers.\"$specific_server\"" "$CLAUDE_CONFIG" &>/dev/null; then
            servers_to_check=("$specific_server")
        else
            echo -e "${RED}Error: $specific_server is not enabled${NC}"
            return 1
        fi
    else
        # Check all enabled servers
        while IFS= read -r server; do
            [ -n "$server" ] && servers_to_check+=("$server")
        done < <(jq -r '.mcpServers // {} | keys[]' "$CLAUDE_CONFIG" 2>/dev/null)
    fi

    if [ ${#servers_to_check[@]} -eq 0 ]; then
        echo -e "${YELLOW}No enabled servers to check${NC}"
        return 0
    fi

    # Check each server
    for server in "${servers_to_check[@]}"; do
        ((total_checked++))
        echo -e "${BLUE}Checking:${NC} $server"

        local server_issues=0

        # Get server config
        local command=$(jq -r ".mcpServers.\"$server\".command" "$CLAUDE_CONFIG" 2>/dev/null)
        local env_vars=$(jq -r ".mcpServers.\"$server\".env // {} | keys[]" "$CLAUDE_CONFIG" 2>/dev/null)

        # Check command availability
        if [ -n "$command" ]; then
            if command -v "$command" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Command '$command' is available"
            else
                echo -e "  ${RED}✗${NC} Command '$command' NOT FOUND"
                ((server_issues++))
            fi
        fi

        # Check environment variables
        if [ -n "$env_vars" ]; then
            while IFS= read -r env_var; do
                if [ -n "$env_var" ]; then
                    # Extract the variable name from ${VAR_NAME} format
                    local var_name=$(echo "$env_var" | sed 's/\${//;s/}//')

                    if [ -n "${!var_name:-}" ]; then
                        echo -e "  ${GREEN}✓${NC} Environment variable $var_name is set"
                    else
                        echo -e "  ${RED}✗${NC} Environment variable $var_name NOT SET"
                        ((server_issues++))
                    fi
                fi
            done < <(jq -r ".mcpServers.\"$server\".env // {} | to_entries[] | .value" "$CLAUDE_CONFIG" 2>/dev/null)
        fi

        if [ $server_issues -eq 0 ]; then
            echo -e "  ${GREEN}Status: Healthy${NC}"
        else
            echo -e "  ${YELLOW}Status: Issues found ($server_issues)${NC}"
            ((issues_found+=server_issues))
        fi
        echo ""
    done

    # Summary
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "  Servers checked: $total_checked"
    if [ $issues_found -eq 0 ]; then
        echo -e "  ${GREEN}✓ All checks passed!${NC}"
        echo -e "  ${GREEN}All enabled servers are healthy${NC}"
        return 0
    else
        echo -e "  ${YELLOW}⚠ Issues found: $issues_found${NC}"
        echo ""
        echo -e "${YELLOW}Recommendations:${NC}"
        echo "  - Install missing commands (e.g., 'brew install node')"
        echo "  - Set missing environment variables in ~/.zshrc or ~/.bashrc"
        echo "  - Run 'source ~/.zshrc' to reload environment"
        return 1
    fi
}

# Show usage statistics
show_stats() {
    echo -e "${BLUE}=== MCP Server Statistics ===${NC}\n"

    # Count servers
    local enabled_count=$(jq -r '.mcpServers // {} | keys | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "0")
    local disabled_count=$(jq -r '._disabled_mcpServers // {} | keys | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "0")
    local total_count=$((enabled_count + disabled_count))

    echo -e "${GREEN}Enabled:${NC}  $enabled_count servers"
    echo -e "${YELLOW}Disabled:${NC} $disabled_count servers"
    echo -e "${BLUE}Total:${NC}    $total_count servers"
    echo ""

    # Analyze enabled servers by impact
    echo -e "${BLUE}Enabled Servers by Context Impact:${NC}"
    local heavy_count=0
    local medium_count=0
    local light_count=0
    local heavy_list=""
    local medium_list=""
    local light_list=""

    while IFS= read -r server; do
        if [ -n "$server" ]; then
            local metadata=$(get_server_metadata "$server")
            local impact=$(echo "$metadata" | cut -d'|' -f1)

            case "$impact" in
                Heavy)
                    ((heavy_count++))
                    heavy_list="$heavy_list $server"
                    ;;
                Medium)
                    ((medium_count++))
                    medium_list="$medium_list $server"
                    ;;
                Light)
                    ((light_count++))
                    light_list="$light_list $server"
                    ;;
            esac
        fi
    done < <(jq -r '.mcpServers // {} | keys[]' "$CLAUDE_CONFIG" 2>/dev/null)

    echo -e "  ${RED}Heavy:${NC}  $heavy_count server(s)${heavy_list:+ -$heavy_list}"
    echo -e "  ${YELLOW}Medium:${NC} $medium_count server(s)${medium_list:+ -$medium_list}"
    echo -e "  ${GREEN}Light:${NC}  $light_count server(s)${light_list:+ -$light_list}"
    echo ""

    # Estimate total context impact
    local total_estimate=$((heavy_count * 1500 + medium_count * 500 + light_count * 50))
    echo -e "${BLUE}Estimated Context Usage:${NC}"
    echo -e "  ~${total_estimate} tokens (approximate baseline)"
    echo -e "  ${YELLOW}Note:${NC} Actual usage varies by operation"
    echo ""

    # Recommendations
    echo -e "${BLUE}Recommendations:${NC}"

    if [ "$heavy_count" -gt 2 ]; then
        echo -e "  ${YELLOW}⚠${NC}  You have $heavy_count heavy-impact servers enabled"
        echo "     Consider disabling unused servers to reduce context usage"
    fi

    if [ "$enabled_count" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}  No servers currently enabled"
        echo "     Enable servers with: ./mcp-toggle.sh enable <name>"
    elif [ "$heavy_count" -eq 0 ] && [ "$medium_count" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC}  All enabled servers have light context impact"
        echo "     Your configuration is optimized for minimal token usage"
    else
        echo -e "  ${GREEN}✓${NC}  Good balance of server types"
        echo "     Disable heavy servers when not actively needed"
    fi

    if [ "$disabled_count" -gt "$enabled_count" ] && [ "$enabled_count" -gt 0 ]; then
        echo -e "  ${BLUE}ℹ${NC}  More servers are disabled than enabled"
        echo "     Use 'list' to see what's available"
    fi
}

# Show help
show_help() {
    echo -e "${BLUE}MCP Server Toggle Script${NC}"
    echo ""
    echo "Enable or disable MCP servers without losing configuration."
    echo ""
    echo -e "${GREEN}Usage:${NC}"
    echo "  $0 enable <server-name...>    Enable disabled server(s)"
    echo "  $0 disable <server-name...>   Disable enabled server(s)"
    echo "  $0 status [server-name]       Show status of server(s)"
    echo "  $0 info <server-name>         Show server details and token impact"
    echo "  $0 stats                      Show usage statistics and recommendations"
    echo "  $0 health [server-name]       Check server health and dependencies"
    echo "  $0 list                       List all servers (enabled and disabled)"
    echo "  $0 restart [server-name]      Show how to restart MCP servers"
    echo "  $0 discover [category]        Discover popular MCP servers"
    echo "  $0 search <query>             Search npm for MCP servers"
    echo "  $0 help                       Show this help message"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 disable figma              Disable Figma MCP server"
    echo "  $0 enable figma puppeteer     Enable multiple servers at once"
    echo "  $0 disable github brave       Disable multiple servers at once"
    echo "  $0 status figma               Check if Figma is enabled or disabled"
    echo "  $0 info filesystem            Show filesystem server token impact"
    echo "  $0 stats                      Show statistics and recommendations"
    echo "  $0 health                     Check all enabled servers"
    echo "  $0 health filesystem          Check specific server health"
    echo "  $0 list                       List all servers"
    echo "  $0 restart                    Show how to restart all MCP servers"
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
    shift

    case "$command" in
        enable)
            enable_server "$@"
            ;;
        disable)
            disable_server "$@"
            ;;
        status)
            get_status "$1"
            ;;
        info)
            show_server_info "$1"
            ;;
        stats)
            show_stats
            ;;
        health)
            health_check "$1"
            ;;
        list)
            list_servers
            ;;
        restart)
            restart_mcp "$1"
            ;;
        discover)
            search_servers "" "$1"
            ;;
        search)
            if [ -z "$1" ]; then
                echo -e "${RED}Error: Search query required${NC}"
                echo "Usage: $0 search <query>"
                exit 1
            fi
            search_servers "$1"
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
