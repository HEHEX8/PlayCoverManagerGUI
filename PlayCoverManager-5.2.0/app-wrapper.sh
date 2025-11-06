#!/bin/bash
#######################################################
# PlayCover Manager - Application Wrapper
# This wrapper ensures the app launches Terminal correctly
#######################################################

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$(cd "$SCRIPT_DIR/../Resources" && pwd)"

# Path to the actual main script
MAIN_SCRIPT="${RESOURCES_DIR}/main-script.sh"

# Launch in Terminal
if [ -f "$MAIN_SCRIPT" ]; then
    # Open Terminal and execute the script
    osascript -e "tell application \"Terminal\"
        activate
        do script \"cd '$RESOURCES_DIR' && bash '$MAIN_SCRIPT'; exit\"
    end tell"
else
    # Fallback: show error dialog
    osascript -e "display dialog \"PlayCover Manager script not found at:\\n$MAIN_SCRIPT\" buttons {\"OK\"} default button 1 with icon stop"
fi
