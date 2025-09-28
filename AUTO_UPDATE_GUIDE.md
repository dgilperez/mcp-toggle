# MCP Auto-Update System

## Overview

The MCP auto-update system automatically keeps your MCP servers up-to-date, similar to how Oh My Zsh handles updates. It runs weekly on Monday mornings when you start a new terminal.

## How It Works

### Timing
- **Weekly Updates**: Checks for updates every Monday
- **Force Updates**: If missed, updates after 14 days regardless of day
- **Background Process**: Runs in background, doesn't slow terminal startup
- **Smart Scheduling**: Only on interactive terminal startup

### Update Process
1. **Check**: Is it Monday and has it been 7+ days since last update?
2. **Update**: Run `mcp-update` in background (packages + sync + health check)
3. **Log**: Results logged to `~/.cache/mcp/update.log`
4. **Track**: Update timestamp stored in `~/.cache/mcp/.mcp-update`

## Files and Locations

```
~/.zshrc                                    # Auto-update integration
~/src/mcp-global-setup/mcp-auto-update.sh  # Main auto-update script
~/.cache/mcp/
├── .mcp-update                            # Last update timestamp
└── update.log                             # Update history log
```

## Configuration

### Enable Auto-Updates (Default)
Auto-updates are enabled by default when you source `.zshrc`.

### Disable Auto-Updates
Add to your `.zshrc` before the MCP auto-update section:
```bash
export DISABLE_MCP_AUTO_UPDATE="true"
```

### Check Update Status
```bash
# Check when last updated
cat ~/.cache/mcp/.mcp-update

# Check update log
tail ~/.cache/mcp/update.log

# Force update now
mcp-update
```

## Manual Control

### Force Update Now
```bash
mcp-update
```

### Check if Update is Due
```bash
# Source the functions
source ~/src/mcp-global-setup/mcp-auto-update.sh

# Check current status
mcp_current_epoch
```

### Reset Update Timer
```bash
# Reset to trigger update on next Monday
rm ~/.cache/mcp/.mcp-update
```

## Troubleshooting

### Updates Not Running
1. **Check if disabled**: `echo $DISABLE_MCP_AUTO_UPDATE`
2. **Check script exists**: `ls -la ~/src/mcp-global-setup/mcp-auto-update.sh`
3. **Check permissions**: Should be executable (`-rwxr-xr-x`)
4. **Check log**: `cat ~/.cache/mcp/update.log`

### Update Failures
Updates may fail if:
- No internet connection
- MCP servers are down
- Permissions issues
- Missing dependencies

Check the log file for specific error messages:
```bash
tail -20 ~/.cache/mcp/update.log
```

### Force Update Bypass
If auto-update is stuck, manually run:
```bash
cd ~/src/mcp-global-setup
./update.sh
```

## Comparison with Oh My Zsh

| Feature | Oh My Zsh | MCP Auto-Update |
|---------|-----------|-----------------|
| **Frequency** | 13 days default | 7 days (weekly) |
| **Day Control** | Any day | Monday preferred |
| **Background** | Optional | Always background |
| **Disable** | `DISABLE_AUTO_UPDATE` | `DISABLE_MCP_AUTO_UPDATE` |
| **Force Update** | After 13+ days | After 14+ days |
| **Logging** | Minimal | Detailed logs |

## Advanced Usage

### Custom Update Frequency
Currently hardcoded to 7 days. To change, edit `mcp-auto-update.sh`:
```bash
# Change this line:
if (( days_since_update >= 7 )) && (is_monday || (( days_since_update >= 14 ))); then
# To (for example, 14 days):
if (( days_since_update >= 14 )) && (is_monday || (( days_since_update >= 28 ))); then
```

### Different Day of Week
To update on a different day, modify the `is_monday()` function:
```bash
# For Friday (5), change:
[[ "$day_of_week" == "1" ]]
# To:
[[ "$day_of_week" == "5" ]]
```

### Update Notifications
To get notifications when updates complete, add to the update script:
```bash
# macOS notification
osascript -e 'display notification "MCP servers updated" with title "MCP Auto-Update"'

# Linux notification (if notify-send available)
command -v notify-send >/dev/null && notify-send "MCP Auto-Update" "MCP servers updated"
```

## Benefits

1. **Always Current**: MCP servers stay up-to-date automatically
2. **Non-Intrusive**: Runs in background, doesn't slow terminal startup
3. **Consistent**: Same behavior across all your machines
4. **Logged**: Track update history and troubleshoot issues
5. **Configurable**: Can disable or customize as needed
6. **Safe**: Only updates packages, doesn't modify your configs

## Security Considerations

- Updates only occur from trusted npm registries
- Background updates don't require user interaction
- Logs are stored locally for audit trail
- Can be disabled if needed for security policies
- No sudo/admin privileges required

## Integration with Development Workflow

The Monday update schedule aligns well with typical work patterns:
- **Weekend**: No interruptions during personal projects
- **Monday Morning**: Fresh start with updated tools
- **Workweek**: Stable environment throughout the week

This ensures you have the latest MCP features and security updates without disrupting your workflow.