#!/bin/bash
# Standalone App Diagnostic Tool

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PlayCover Manager - Standalone App Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APP_BUNDLE="build-standalone/PlayCover Manager.app"

# 1. Check if app bundle exists
echo "1. App Bundle Structure:"
if [[ -d "$APP_BUNDLE" ]]; then
    echo "   ✅ App bundle exists"
    ls -la "$APP_BUNDLE/Contents/"
else
    echo "   ❌ App bundle NOT found"
    exit 1
fi

echo ""
echo "2. Launcher Script:"
LAUNCHER="$APP_BUNDLE/Contents/MacOS/PlayCoverManager"
if [[ -f "$LAUNCHER" ]]; then
    echo "   ✅ Launcher exists"
    ls -la "$LAUNCHER"
    echo ""
    echo "   First line (shebang):"
    head -1 "$LAUNCHER"
else
    echo "   ❌ Launcher NOT found"
fi

echo ""
echo "3. Test Direct Execution:"
echo "   Running launcher directly..."
if [[ -x "$LAUNCHER" ]]; then
    echo "   Launcher is executable"
    echo "   Trying to execute..."
    "$LAUNCHER" &
    LAUNCHER_PID=$!
    echo "   Launcher PID: $LAUNCHER_PID"
    sleep 2
    
    if ps -p $LAUNCHER_PID > /dev/null 2>&1; then
        echo "   ✅ Launcher is running"
        kill $LAUNCHER_PID 2>/dev/null
    else
        echo "   ❌ Launcher exited immediately"
    fi
else
    echo "   ❌ Launcher is NOT executable"
    echo "   Fixing permissions..."
    chmod +x "$LAUNCHER"
fi

echo ""
echo "4. Check for System Logs:"
echo "   Console.app logs (last 10 lines):"
log show --predicate 'process == "PlayCover Manager" OR process == "PlayCoverManager"' --last 1m 2>/dev/null | tail -10

echo ""
echo "5. Check Info.plist:"
if plutil -lint "$APP_BUNDLE/Contents/Info.plist" > /dev/null 2>&1; then
    echo "   ✅ Info.plist is valid"
    echo ""
    echo "   CFBundleExecutable:"
    /usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo "   ❌ Not found"
else
    echo "   ❌ Info.plist is INVALID"
fi

echo ""
echo "6. Check Gatekeeper Status:"
xattr -l "$APP_BUNDLE" 2>/dev/null
if [[ $? -eq 0 ]]; then
    QUARANTINE=$(xattr -l "$APP_BUNDLE" | grep com.apple.quarantine)
    if [[ -n "$QUARANTINE" ]]; then
        echo "   ⚠️  Quarantine attribute found"
        echo "   Run: xattr -cr '$APP_BUNDLE'"
    else
        echo "   ✅ No quarantine attributes"
    fi
fi

echo ""
echo "7. Test with Terminal.app directly:"
echo "   Running: /bin/zsh '$LAUNCHER'"
/bin/zsh "$LAUNCHER" 2>&1 &
TEST_PID=$!
echo "   Test PID: $TEST_PID"
sleep 2

if ps -p $TEST_PID > /dev/null 2>&1; then
    echo "   ✅ Script is running via zsh"
    kill $TEST_PID 2>/dev/null
else
    echo "   ❌ Script exited via zsh"
fi

echo ""
echo "8. Check for Errors in Script:"
echo "   Syntax check:"
zsh -n "$LAUNCHER" 2>&1
if [[ $? -eq 0 ]]; then
    echo "   ✅ No syntax errors"
else
    echo "   ❌ Syntax errors found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Diagnostic Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
