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

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_CACHE="$SCRIPT_DIR/data/mcp-cache.json"
LOCAL_OVERRIDE="$HOME/.mcp/local-metadata.json"

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
    local impact="Unknown"
    local description="Impact not assessed; check server documentation"

    # Try local override first (allows users to extend/override)
    if [ -f "$LOCAL_OVERRIDE" ]; then
        local override_data=$(jq -r --arg s "$server_name" \
            '.servers[$s] // empty' "$LOCAL_OVERRIDE" 2>/dev/null)

        if [ -n "$override_data" ]; then
            impact=$(echo "$override_data" | jq -r '.impact.category // "Unknown"')
            description=$(echo "$override_data" | jq -r '.description // "No description"')
            echo "${impact}|||${description}"
            return
        fi
    fi

    # Fall back to cache
    if [ -f "$MCP_CACHE" ]; then
        local cache_data=$(jq -r --arg s "$server_name" \
            '.servers[$s] // empty' "$MCP_CACHE" 2>/dev/null)

        if [ -n "$cache_data" ]; then
            impact=$(echo "$cache_data" | jq -r '.impact.category // "Unknown"')
            description=$(echo "$cache_data" | jq -r '.description // "No description"')
            echo "${impact}|||${description}"
            return
        fi
    fi

    # Default fallback
    echo "${impact}|||${description}"
}

# Show server info (comprehensive: status + impact + config + health)
show_server_info() {
    local server_name="$1"

    # If no server specified, list all servers
    if [ -z "$server_name" ]; then
        list_servers
        return
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

    # Health check (only for enabled servers)
    if [ "$status" = "ENABLED" ]; then
        echo -e "${BLUE}Health Check:${NC}"

        local server_issues=0
        local command=$(jq -r ".mcpServers.\"$server_name\".command" "$CLAUDE_CONFIG" 2>/dev/null)

        # Check command availability
        if [ -n "$command" ] && [ "$command" != "null" ]; then
            if command -v "$command" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Command '$command' is available"
            else
                echo -e "  ${RED}✗${NC} Command '$command' NOT FOUND"
                ((server_issues++))
            fi
        fi

        # Check environment variables
        local env_check_failed=false
        while IFS= read -r env_value; do
            if [ -n "$env_value" ] && [ "$env_value" != "null" ]; then
                # Extract variable name from ${VAR_NAME} format
                local var_name=$(echo "$env_value" | sed 's/\${//;s/}//')

                if [ -n "${!var_name:-}" ]; then
                    echo -e "  ${GREEN}✓${NC} Environment variable $var_name is set"
                else
                    echo -e "  ${RED}✗${NC} Environment variable $var_name NOT SET"
                    ((server_issues++))
                    env_check_failed=true
                fi
            fi
        done < <(jq -r ".mcpServers.\"$server_name\".env // {} | to_entries[] | .value" "$CLAUDE_CONFIG" 2>/dev/null)

        if [ $server_issues -eq 0 ]; then
            echo -e "  ${GREEN}All health checks passed${NC}"
        else
            echo -e "  ${YELLOW}⚠ Found $server_issues issue(s)${NC}"
            if $env_check_failed; then
                echo -e "  ${BLUE}Tip:${NC} Add missing env vars to ~/.zshrc and run: source ~/.zshrc"
            fi
        fi
        echo ""
    fi

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

# Discover MCP servers (curated list or npm search)
discover_servers() {
    local arg="$1"

    echo -e "${BLUE}=== MCP Server Discovery ===${NC}\n"

    # If no argument, show all curated
    if [ -z "$arg" ]; then
        show_curated_servers ""
        return
    fi

    # Check if it's a known category
    local all_categories=$(jq -r '.categories | keys[]' "$MCP_CACHE" 2>/dev/null)
    local is_category=false

    while IFS= read -r cat; do
        if [[ "$arg" == "$cat" ]] || [[ "$arg" == "${cat%-*}" ]]; then
            is_category=true
            break
        fi
    done <<< "$all_categories"

    # Category aliases
    case "$arg" in
        db) arg="database"; is_category=true ;;
        prod) arg="productivity"; is_category=true ;;
        dev|developer) arg="dev-tools"; is_category=true ;;
    esac

    if $is_category; then
        show_curated_servers "$arg"
    else
        # Not a category, search npm
        search_npm "$arg"
    fi
}

# Show curated popular MCP servers
show_curated_servers() {
    local category="$1"

    echo -e "${GREEN}Popular MCP Servers:${NC}\n"

    # Check if cache exists
    if [ ! -f "$MCP_CACHE" ]; then
        echo -e "${RED}Error: MCP cache not found at $MCP_CACHE${NC}"
        echo "Run: $SCRIPT_DIR/scripts/generate-cache.sh"
        return 1
    fi

    # Read category mappings from cache
    local all_categories=$(jq -r '.categories | keys[]' "$MCP_CACHE" 2>/dev/null)

    # Helper to show servers in a category
    show_category_servers() {
        local cat_name="$1"
        local cat_servers=$(jq -r --arg cat "$cat_name" '.categories[$cat] // [] | .[]' "$MCP_CACHE" 2>/dev/null)

        if [ -z "$cat_servers" ]; then
            return
        fi

        while IFS= read -r server_name; do
            if [ -n "$server_name" ]; then
                local server_data=$(jq -r --arg s "$server_name" '.servers[$s] // empty' "$MCP_CACHE" 2>/dev/null)

                if [ -n "$server_data" ]; then
                    local package=$(echo "$server_data" | jq -r '.package // "unknown"')
                    local description=$(echo "$server_data" | jq -r '.description // "No description"')
                    local impact=$(echo "$server_data" | jq -r '.impact.category // "Unknown"')

                    # Check if installed
                    local status=""
                    local package_dir="$HOME/.mcp/servers/node_modules/${package}"
                    if [ -d "$package_dir" ] || jq -e ".mcpServers.\"$server_name\"" "$CLAUDE_CONFIG" &>/dev/null; then
                        status="${GREEN}[installed]${NC}"
                    fi

                    # Format output with impact indicator
                    local impact_indicator=""
                    case "$impact" in
                        Heavy) impact_indicator="${RED}⬤${NC}" ;;
                        Medium) impact_indicator="${YELLOW}⬤${NC}" ;;
                        Light) impact_indicator="${GREEN}⬤${NC}" ;;
                        *) impact_indicator="⚪" ;;
                    esac

                    printf "  %b %-23s %-40s %b\n" "$impact_indicator" "$server_name" "$package" "$status"
                    printf "    └─ %s\n" "$description"
                fi
            fi
        done <<< "$cat_servers"
    }

    # Category display names and emojis
    case "$category" in
        database|db)
            echo -e "${YELLOW}💾 Database Servers:${NC}"
            show_category_servers "database"
            ;;
        productivity|prod)
            echo -e "${YELLOW}📝 Productivity Servers:${NC}"
            show_category_servers "productivity"
            ;;
        dev|developer|dev-tools)
            echo -e "${YELLOW}🛠️  Developer Tools:${NC}"
            show_category_servers "dev-tools"
            ;;
        search)
            echo -e "${YELLOW}🔍 Search Servers:${NC}"
            show_category_servers "search"
            ;;
        ai)
            echo -e "${YELLOW}🤖 AI & Official Servers:${NC}"
            show_category_servers "ai"
            ;;
        filesystem)
            echo -e "${YELLOW}📁 Filesystem Servers:${NC}"
            show_category_servers "filesystem"
            ;;
        *)
            # Show all categories
            while IFS= read -r cat; do
                case "$cat" in
                    database)
                        echo -e "${YELLOW}💾 Database:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                    search)
                        echo -e "${YELLOW}🔍 Search & Research:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                    productivity)
                        echo -e "${YELLOW}📝 Productivity:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                    dev-tools)
                        echo -e "${YELLOW}🛠️  Developer Tools:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                    ai)
                        echo -e "${YELLOW}🤖 AI & Official:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                    filesystem)
                        echo -e "${YELLOW}📁 Filesystem:${NC}"
                        show_category_servers "$cat"
                        echo ""
                        ;;
                esac
            done <<< "$all_categories"
            ;;
    esac

    echo ""
    echo -e "${BLUE}Impact Legend:${NC} ${RED}⬤${NC} Heavy  ${YELLOW}⬤${NC} Medium  ${GREEN}⬤${NC} Light"
    echo ""
    echo -e "${BLUE}To install a server:${NC}"
    echo "  cd ~/.mcp/servers && npm install <package-name>"
    echo "  Then add to Claude config and sync: ./sync-all.sh"
    echo ""
    echo -e "${BLUE}Categories:${NC}"
    while IFS= read -r cat; do
        echo "  mcp-toggle discover $cat"
    done <<< "$all_categories"
    echo ""
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
    echo -e "${BLUE}Tip:${NC} To see curated servers by category, use:"
    echo "  mcp-toggle discover database"
    echo "  mcp-toggle discover productivity"
    echo ""
}

# Draw an ASCII bar chart
draw_bar() {
    local count=$1
    local max=$2
    local char=$3
    local width=40

    if [ "$max" -eq 0 ]; then
        echo ""
        return
    fi

    local bar_length=$(( (count * width) / max ))
    [ "$bar_length" -eq 0 ] && [ "$count" -gt 0 ] && bar_length=1

    local bar=""
    for ((i=0; i<bar_length; i++)); do
        bar="${bar}${char}"
    done

    echo "${bar} ${count}"
}

# Show usage statistics
show_stats() {
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  MCP SERVER STATS                                       │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""

    # Count servers
    local enabled_count=$(jq -r '.mcpServers // {} | keys | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "0")
    local disabled_count=$(jq -r '._disabled_mcpServers // {} | keys | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "0")
    local total_count=$((enabled_count + disabled_count))

    local max_count=$enabled_count
    [ "$disabled_count" -gt "$max_count" ] && max_count=$disabled_count

    # Server count visualization
    echo "SERVER STATUS"
    echo "  Enabled   $(draw_bar "$enabled_count" "$max_count" "█")"
    echo "  Disabled  $(draw_bar "$disabled_count" "$max_count" "▒")"
    echo "  ─────────────────────────────────────────────"
    echo "  Total: $total_count servers"
    echo ""

    # Analyze enabled servers by impact
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

    # Find max for bar chart
    local impact_max=$heavy_count
    [ "$medium_count" -gt "$impact_max" ] && impact_max=$medium_count
    [ "$light_count" -gt "$impact_max" ] && impact_max=$light_count

    # Impact visualization
    echo "CONTEXT IMPACT (enabled servers)"
    echo "  Heavy     $(draw_bar "$heavy_count" "$impact_max" "█")${heavy_list:+  ($heavy_list )}"
    echo "  Medium    $(draw_bar "$medium_count" "$impact_max" "▓")${medium_list:+  ($medium_list )}"
    echo "  Light     $(draw_bar "$light_count" "$impact_max" "░")${light_list:+  ($light_list )}"
    echo ""

    # Estimate total context impact
    local total_estimate=$((heavy_count * 1500 + medium_count * 500 + light_count * 50))
    local max_tokens=200000
    local usage_percent=$(( (total_estimate * 100) / max_tokens ))

    echo "CONTEXT USAGE"
    echo "  ~${total_estimate} tokens baseline"

    # Visual token usage bar
    local bar_width=50
    local filled=$(( (usage_percent * bar_width) / 100 ))
    [ "$filled" -eq 0 ] && [ "$usage_percent" -gt 0 ] && filled=1

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar="${bar}▓"
    done
    for ((i=filled; i<bar_width; i++)); do
        bar="${bar}░"
    done

    echo "  [${bar}] ${usage_percent}%"
    echo "  (actual usage varies by operation)"
    echo ""

    # Recommendations
    echo "ANALYSIS"

    if [ "$enabled_count" -eq 0 ]; then
        echo "  * No servers enabled"
        echo "    → Run 'mcp-toggle discover' to find servers"
    elif [ "$heavy_count" -gt 2 ]; then
        echo "  * High context usage: $heavy_count heavy servers enabled"
        echo "    → Disable unused servers: mcp-toggle disable <name>"
    elif [ "$heavy_count" -eq 0 ] && [ "$medium_count" -eq 0 ]; then
        echo "  * Optimized: All enabled servers are lightweight"
    else
        echo "  * Balanced configuration"
        echo "    → Disable heavy servers when not needed"
    fi

    if [ "$disabled_count" -gt "$enabled_count" ] && [ "$enabled_count" -gt 0 ]; then
        echo "  * More disabled ($disabled_count) than enabled ($enabled_count)"
        echo "    → Run 'mcp-toggle list' to see available servers"
    fi

    echo ""
}

# Show help
show_help() {
    echo -e "${BLUE}MCP Server Toggle Script${NC}"
    echo ""
    echo "Enable or disable MCP servers without losing configuration."
    echo ""
    echo -e "${GREEN}Usage:${NC}"
    echo "  mcp-toggle enable <server-name...>    Enable disabled server(s)"
    echo "  mcp-toggle disable <server-name...>   Disable enabled server(s)"
    echo "  mcp-toggle info [server-name]         Show server info (status, impact, health)"
    echo "  mcp-toggle list                       List all servers (same as 'info')"
    echo "  mcp-toggle stats                      Show usage statistics and recommendations"
    echo "  mcp-toggle restart [server-name]      Show how to restart MCP servers"
    echo "  mcp-toggle discover [query]           Discover or search for MCP servers"
    echo "  mcp-toggle help                       Show this help message"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  mcp-toggle                            List all servers (enabled and disabled)"
    echo "  mcp-toggle info filesystem            Show detailed server info + health check"
    echo "  mcp-toggle enable figma puppeteer     Enable multiple servers at once"
    echo "  mcp-toggle disable github brave       Disable multiple servers at once"
    echo "  mcp-toggle stats                      Show statistics and recommendations"
    echo "  mcp-toggle discover                   Show all curated MCP servers"
    echo "  mcp-toggle discover database          Show database category servers"
    echo "  mcp-toggle discover postgres          Search npm for 'postgres'"
    echo "  mcp-toggle restart                    Show how to restart all MCP servers"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo "  - Configuration is preserved when disabling"
    echo "  - Backups are created automatically in ~/.mcp/backups/"
    echo "  - Disabled servers are stored in _disabled_mcpServers"
    echo "  - 'info' command includes health check for enabled servers"
    echo ""
    echo -e "${BLUE}File Locations:${NC}"
    echo "  Config:  $CLAUDE_CONFIG"
    echo "  Backups: $BACKUP_DIR"
    echo ""
}

# Main command handler
main() {
    local command="${1:-}"

    # Default to list if no args provided
    if [ -z "$command" ]; then
        list_servers
        echo ""
        echo -e "${BLUE}💡 Tip:${NC} Run 'mcp-toggle help' to see all commands"
        echo -e "${BLUE}💡 Tip:${NC} Run 'mcp-toggle stats' for usage analysis"
        return 0
    fi

    shift

    case "$command" in
        enable)
            enable_server "$@"
            ;;
        disable)
            disable_server "$@"
            ;;
        info|list)
            show_server_info "$1"
            ;;
        stats)
            show_stats
            ;;
        restart)
            restart_mcp "$1"
            ;;
        discover)
            discover_servers "$1"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: ${YELLOW}$command${NC}"
            echo ""
            echo -e "${BLUE}Did you mean one of these?${NC}"
            echo "  • info       Show server info or list all servers"
            echo "  • stats      Show usage statistics"
            echo "  • discover   Browse or search for MCP servers"
            echo "  • enable     Enable a disabled server"
            echo "  • disable    Disable an enabled server"
            echo "  • help       Show full help"
            echo ""
            exit 1
            ;;
    esac
}

# Run main
main "$@"
