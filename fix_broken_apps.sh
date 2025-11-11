#!/bin/bash

# PlayCover App Info.plist Fix Script
# This script removes the NSUserNotificationAlertStyle key that was accidentally added
# and caused apps to crash.

set -e

echo "================================================"
echo "PlayCover App Info.plist Fix Script"
echo "================================================"
echo ""

# Find all PlayCover apps in /Applications
APPS_DIR="/Applications"

if [ ! -d "$APPS_DIR" ]; then
    echo "Error: /Applications directory not found"
    exit 1
fi

echo "Searching for apps in $APPS_DIR..."
echo ""

# Counter for fixed apps
FIXED_COUNT=0
CHECKED_COUNT=0

# Find all .app bundles
while IFS= read -r -d '' APP_PATH; do
    APP_NAME=$(basename "$APP_PATH")
    INFO_PLIST="$APP_PATH/Info.plist"
    
    ((CHECKED_COUNT++))
    
    # Check if Info.plist exists
    if [ ! -f "$INFO_PLIST" ]; then
        continue
    fi
    
    # Check if NSUserNotificationAlertStyle key exists
    if /usr/libexec/PlistBuddy -c "Print :NSUserNotificationAlertStyle" "$INFO_PLIST" >/dev/null 2>&1; then
        echo "Found NSUserNotificationAlertStyle in: $APP_NAME"
        
        # Try to delete the key
        if /usr/libexec/PlistBuddy -c "Delete :NSUserNotificationAlertStyle" "$INFO_PLIST" 2>/dev/null; then
            echo "  ✓ Successfully removed NSUserNotificationAlertStyle"
            ((FIXED_COUNT++))
        else
            echo "  ✗ Failed to remove key (may require elevated permissions)"
        fi
        echo ""
    fi
    
done < <(find "$APPS_DIR" -maxdepth 2 -name "*.app" -print0 2>/dev/null)

echo "================================================"
echo "Summary:"
echo "  Checked apps: $CHECKED_COUNT"
echo "  Fixed apps: $FIXED_COUNT"
echo "================================================"

if [ $FIXED_COUNT -gt 0 ]; then
    echo ""
    echo "Apps have been fixed! You can now launch them normally."
else
    echo ""
    echo "No broken apps found. All apps are OK!"
fi
