#!/bin/bash
#######################################################
# PlayCover Manager - Daemon Launcher
# Uses launchd-style background daemon approach
#######################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_PLIST="${HOME}/Library/LaunchAgents/com.playcover.manager.plist"
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-daemon.lock"

#######################################################
# Check if already running
#######################################################

check_running() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    return 1  # Not running
}

#######################################################
# Launch or activate
#######################################################

if check_running; then
    # Already running - activate existing window
    osascript <<'APPLESCRIPT' 2>/dev/null
tell application "Terminal"
    activate
    repeat with w in windows
        if (name of w) contains "PlayCover" then
            set index of w to 1
            exit repeat
        end if
    end repeat
end tell
APPLESCRIPT
    exit 0
fi

#######################################################
# Launch new instance
#######################################################

# Create lock with current PID
echo $$ > "$LOCK_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

# Launch Terminal with script
osascript <<APPLESCRIPT
tell application "Terminal"
    activate
    set newWindow to do script "clear; printf '\\033]0;PlayCover Manager\\007'; cd '${SCRIPT_DIR}'; ./playcover-manager.command; exit"
end tell
APPLESCRIPT

# Keep running to maintain lock
while true; do
    if ! pgrep -f "playcover-manager.command" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
