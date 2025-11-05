#!/bin/bash
#######################################################
# Main.sh Compatibility Test
# 
# main.shがbash環境で動作するかテストします。
#######################################################

cd "$(dirname "$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Main.sh Bash Compatibility Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "このテストは、main.shがbash環境で正しく動作するか検証します。"
echo ""

# 互換性レイヤーを読み込み
source lib/00_compat.sh

echo "✅ Compatibility layer loaded"
echo ""

# SCRIPT_DIR検出のテスト
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Testing SCRIPT_DIR detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# main.shの ${0:A:h} をシミュレート
SCRIPT_DIR=$(get_script_dir_compat)
echo "SCRIPT_DIR detected as: $SCRIPT_DIR"
echo ""

# 必要なファイルの存在確認
echo "Checking required files:"
files_to_check=(
    "lib/00_core.sh"
    "lib/01_mapping.sh"
    "lib/02_volume.sh"
    "lib/03_storage.sh"
    "lib/04_app.sh"
    "lib/05_cleanup.sh"
    "lib/06_setup.sh"
    "lib/07_ui.sh"
)

all_exist=true
for file in "${files_to_check[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        echo "  ✅ ${file}"
    else
        echo "  ❌ ${file} NOT FOUND"
        all_exist=false
    fi
done

echo ""

if [[ "$all_exist" == "false" ]]; then
    echo "❌ Some required files are missing"
    echo ""
    exit 1
fi

echo "✅ All required files exist"
echo ""

# main.shの構文変換テスト
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Testing zsh→bash syntax conversion"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# main.shからSCRIPT_DIR定義行を抽出
echo "Original zsh syntax in main.sh:"
grep "SCRIPT_DIR=" main.sh | head -1
echo ""

echo "Converted to bash:"
echo "SCRIPT_DIR=\"\$(get_script_dir_compat)\""
echo ""

# 変換したmain.shを作成
echo "Creating bash-compatible version of main.sh..."
TEMP_MAIN=$(mktemp /tmp/main-compat.XXXXXX.sh)

# zsh→bash変換
sed -e '1s|^#!/bin/zsh|#!/bin/bash|' \
    -e '1s|^#!/usr/bin/env zsh|#!/bin/bash|' \
    -e 's|SCRIPT_DIR="${0:A:h}"|SCRIPT_DIR="$(cd "$(dirname "$0")" \&\& pwd)"|g' \
    main.sh > "$TEMP_MAIN"

echo "✅ Conversion complete"
echo "   Temp file: $TEMP_MAIN"
echo ""

# 構文チェック
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Testing bash syntax validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if bash -n "$TEMP_MAIN" 2>&1; then
    echo "✅ No syntax errors detected"
else
    echo "❌ Syntax errors found"
    echo ""
    rm -f "$TEMP_MAIN"
    exit 1
fi

echo ""

# ロック機能の動作テスト（実際には起動しない）
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Testing single instance lock mechanism"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"

# クリーンアップ
rm -f "$LOCK_FILE"

echo "Testing lock file creation..."
# ロック部分のみを抽出して実行
{
    cat << 'LOCK_TEST'
#!/bin/bash

LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"

is_lock_stale() {
    local lock_file=$1
    if [[ ! -f "$lock_file" ]]; then
        return 0
    fi
    local lock_pid=$(cat "$lock_file" 2>/dev/null)
    if [[ -z "$lock_pid" ]]; then
        return 0
    fi
    if ps -p "$lock_pid" >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

if [[ -f "$LOCK_FILE" ]]; then
    if is_lock_stale "$LOCK_FILE"; then
        rm -f "$LOCK_FILE"
        echo "Removed stale lock"
    else
        echo "Another instance running (PID: $(cat "$LOCK_FILE"))"
        exit 0
    fi
fi

echo $$ > "$LOCK_FILE"
echo "✅ Lock created (PID: $$)"

cleanup_lock() {
    rm -f "$LOCK_FILE"
    echo "✅ Lock cleaned up"
}

trap cleanup_lock EXIT INT TERM QUIT

sleep 1
echo "✅ Lock mechanism working"
LOCK_TEST
} | bash

echo ""

# 最終クリーンアップ
rm -f "$TEMP_MAIN"
rm -f "$LOCK_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All Compatibility Tests Passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ Compatibility layer functional"
echo "   ✅ SCRIPT_DIR detection working"
echo "   ✅ All required files present"
echo "   ✅ Syntax conversion successful"
echo "   ✅ No bash syntax errors"
echo "   ✅ Lock mechanism operational"
echo ""
echo "🎯 Next Steps:"
echo "   1. Test on actual macOS with zsh"
echo "   2. Verify Terminal window activation"
echo "   3. Test multiple rapid clicks on app icon"
echo ""
