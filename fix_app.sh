#!/bin/bash

# PlayCover App Info.plist Fix Script (Single App Version)
# This script removes the NSUserNotificationAlertStyle key from a specific app
#
# Usage: ./fix_app.sh "~/Library/Containers/io.playcover.PlayCover/Applications/YourApp.app"
#    or: ./fix_app.sh "Genshin Impact.app"  (searches in PlayCover directory)

set -e

# Default PlayCover apps directory
PLAYCOVER_APPS_DIR="$HOME/Library/Containers/io.playcover.PlayCover/Applications"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <app_name_or_path>"
    echo ""
    echo "Examples:"
    echo "  $0 \"Genshin Impact.app\""
    echo "  $0 \"$PLAYCOVER_APPS_DIR/Genshin Impact.app\""
    exit 1
fi

INPUT="$1"

# Remove trailing slash if present
INPUT="${INPUT%/}"

# If input doesn't start with /, assume it's just the app name
if [[ "$INPUT" != /* ]]; then
    # Search in PlayCover directory
    if [ ! -d "$PLAYCOVER_APPS_DIR" ]; then
        echo "Error: PlayCover Applications directory not found at:"
        echo "  $PLAYCOVER_APPS_DIR"
        exit 1
    fi
    APP_PATH="$PLAYCOVER_APPS_DIR/$INPUT"
else
    # Expand ~ if present
    APP_PATH="${INPUT/#\~/$HOME}"
fi

echo "================================================"
echo "PlayCover App Info.plist Fix Script"
echo "================================================"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at: $APP_PATH"
    echo ""
    if [[ "$INPUT" != /* ]]; then
        echo "Available apps in PlayCover directory:"
        ls -1 "$PLAYCOVER_APPS_DIR" | grep "\.app$" || echo "  (none found)"
    fi
    exit 1
fi

APP_NAME=$(basename "$APP_PATH")
INFO_PLIST="$APP_PATH/Info.plist"

echo "Target app: $APP_NAME"
echo "Info.plist: $INFO_PLIST"
echo ""

# Check if Info.plist exists
if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Info.plist not found in app bundle"
    exit 1
fi

# Check if NSUserNotificationAlertStyle key exists
if /usr/libexec/PlistBuddy -c "Print :NSUserNotificationAlertStyle" "$INFO_PLIST" >/dev/null 2>&1; then
    echo "Found NSUserNotificationAlertStyle key"
    
    # Create backup
    BACKUP_PATH="${INFO_PLIST}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INFO_PLIST" "$BACKUP_PATH"
    echo "Created backup: $BACKUP_PATH"
    echo ""
    
    # Try to delete the key
    if /usr/libexec/PlistBuddy -c "Delete :NSUserNotificationAlertStyle" "$INFO_PLIST" 2>/dev/null; then
        echo "✓ Successfully removed NSUserNotificationAlertStyle"
        echo ""
        echo "The app has been fixed! You can now launch it normally."
    else
        echo "✗ Failed to remove key"
        echo ""
        echo "This may require elevated permissions. Try running with sudo:"
        echo "  sudo $0 \"$APP_PATH\""
        
        # Restore backup
        mv "$BACKUP_PATH" "$INFO_PLIST"
        exit 1
    fi
else
    echo "NSUserNotificationAlertStyle key not found."
    echo "This app is OK and doesn't need fixing!"
fi

echo ""
echo "================================================"
