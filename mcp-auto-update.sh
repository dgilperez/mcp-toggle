#!/bin/bash
# MCP Auto-Update System
# Automatically checks for MCP updates on Monday terminal startup (similar to Oh My Zsh)

# Only load in interactive shells, not subprocess/script contexts
[[ $- != *i* ]] && return 2>/dev/null || true

# Configuration
MCP_HOME="$HOME/.mcp"
MCP_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.cache/mcp}"
MCP_UPDATE_FILE="$MCP_CACHE_DIR/.mcp-update"
# Auto-detect script directory (works regardless of installation location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
MCP_TOGGLE_DIR="${MCP_TOGGLE_DIR:-$SCRIPT_DIR}"

# Create cache directory
mkdir -p "$MCP_CACHE_DIR"

# Get current epoch (days since epoch)
function mcp_current_epoch() {
    if command -v date >/dev/null; then
        # macOS/Linux date command
        echo $(( $(date +%s) / 60 / 60 / 24 ))
    else
        # Fallback: zsh datetime
        zmodload zsh/datetime 2>/dev/null && echo $(( EPOCHSECONDS / 60 / 60 / 24 )) || echo 0
    fi
}

# Check if it's Monday (1 = Monday in most systems)
function is_monday() {
    local day_of_week
    if command -v date >/dev/null; then
        day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
        [[ "$day_of_week" == "1" ]]
    else
        # Fallback: assume it's update time
        return 0
    fi
}

# Update the last update file
function mcp_update_last_updated_file() {
    local exit_status="$1" error="$2"

    if [[ -z "${1}${2}" ]]; then
        echo "LAST_EPOCH=$(mcp_current_epoch)" > "$MCP_UPDATE_FILE"
        return
    fi

    cat > "$MCP_UPDATE_FILE" <<EOD
LAST_EPOCH=$(mcp_current_epoch)
EXIT_STATUS=${exit_status}
ERROR='${error//\'/'}'
EOD
}

# Perform the actual update
function mcp_update() {
    echo "🔄 Auto-updating MCP servers (weekly maintenance)..."

    # Run the update command in background to not block terminal startup
    {
        if [[ -x "$MCP_TOGGLE_DIR/update.sh" ]]; then
            cd "$MCP_TOGGLE_DIR" && ./update.sh >/dev/null 2>&1
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                echo "✅ MCP servers updated successfully ($(date))" >> "$MCP_CACHE_DIR/update.log"
                mcp_update_last_updated_file
            else
                echo "❌ MCP update failed with code $exit_code ($(date))" >> "$MCP_CACHE_DIR/update.log"
                mcp_update_last_updated_file "$exit_code" "Update script failed"
            fi
        else
            echo "⚠️  MCP update script not found at $MCP_TOGGLE_DIR/update.sh" >> "$MCP_CACHE_DIR/update.log"
            mcp_update_last_updated_file "1" "Update script not found"
        fi
    } &

    # Don't wait for background process - let terminal start normally
    disown
}

# Main update check logic
function mcp_check_for_update() {
    # Skip if auto-update is disabled
    [[ "$DISABLE_MCP_AUTO_UPDATE" == "true" ]] && return

    # Skip if MCP setup doesn't exist
    [[ ! -d "$MCP_HOME" ]] && return

    # Skip if not in an interactive terminal
    [[ ! -t 1 ]] && return

    # Skip if update script doesn't exist
    [[ ! -x "$MCP_TOGGLE_DIR/update.sh" ]] && return

    local LAST_EPOCH=0

    # Read last update file
    if [[ -f "$MCP_UPDATE_FILE" ]]; then
        source "$MCP_UPDATE_FILE" 2>/dev/null || LAST_EPOCH=0
    fi

    # Create update file if missing
    if [[ ! -f "$MCP_UPDATE_FILE" ]] || [[ -z "$LAST_EPOCH" ]]; then
        mcp_update_last_updated_file
        return
    fi

    # Check if it's been at least 7 days (1 week) since last update
    local current_epoch=$(mcp_current_epoch)
    local days_since_update=$(( current_epoch - LAST_EPOCH ))

    # Only update if:
    # 1. It's been at least 7 days
    # 2. It's Monday (for weekly Monday updates)
    # 3. Or it's been more than 14 days (force update)
    if (( days_since_update >= 7 )) && (is_monday || (( days_since_update >= 14 ))); then
        mcp_update
    fi
}

# Don't try to export functions in zsh - it's bash-specific
# Just run the check
mcp_check_for_update 2>/dev/null || true