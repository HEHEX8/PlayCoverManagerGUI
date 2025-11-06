#!/bin/bash
#######################################################
# PlayCover Manager - Launch Wrapper
# Prevents multiple Terminal windows
#######################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Lock file to prevent multiple instances
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-launch.lock"
LOCK_PID_FILE="${TMPDIR:-/tmp}/playcover-manager-launch.pid"

# Check if already running
if [[ -f "$LOCK_FILE" ]] && [[ -f "$LOCK_PID_FILE" ]]; then
    EXISTING_PID=$(cat "$LOCK_PID_FILE" 2>/dev/null)
    
    # Check if the process is actually running
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        # Already running - bring Terminal to front and activate existing window
        osascript <<'APPLESCRIPT' 2>/dev/null
tell application "Terminal"
    activate
    -- Try to find and select the PlayCover Manager window
    set foundWindow to false
    repeat with w in windows
        set windowName to name of w
        if windowName contains "PlayCover" or windowName contains "playcover" then
            set foundWindow to true
            set index of w to 1
            do script "# Switching to existing PlayCover Manager window" in w
            exit repeat
        end if
    end repeat
    
    -- If no specific window found, just activate Terminal
    if not foundWindow then
        tell application "System Events"
            tell process "Terminal"
                set frontmost to true
            end tell
        end tell
    end if
end tell
APPLESCRIPT
        exit 0
    else
        # Stale lock - remove it
        rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
    fi
fi

# Create lock with current PID
echo $$ > "$LOCK_PID_FILE"
touch "$LOCK_FILE"

# Cleanup function
cleanup_lock() {
    rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
}

trap cleanup_lock EXIT INT TERM

# Launch in new Terminal window with custom title
osascript <<APPLESCRIPT
tell application "Terminal"
    activate
    -- Create new window with custom name
    do script "clear; printf '\\033]0;PlayCover Manager\\007'; cd \"${SCRIPT_DIR}\"; ./playcover-manager.command; exit"
end tell
APPLESCRIPT

# Wait for Terminal to launch
sleep 0.5

# Keep this script running to maintain the lock
# When Terminal window closes, this script will exit and release the lock
wait
