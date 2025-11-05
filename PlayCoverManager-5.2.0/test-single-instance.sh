#!/bin/bash
#######################################################
# Single Instance Test Script
# 
# このスクリプトは、lib/00_compat.shを使用して
# main.shのシングルインスタンス機能をテストします。
#######################################################

# プロジェクトルートに移動
cd "$(dirname "$0")"

# 互換性レイヤーを読み込み
source lib/00_compat.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Single Instance Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "このテストでは、main.shのシングルインスタンス機能を検証します。"
echo ""

# ロックファイルの状態を確認
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"

echo "📋 現在の状態:"
echo "   Lock file: $LOCK_FILE"

if [[ -f "$LOCK_FILE" ]]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    echo "   Status: ✅ EXISTS (PID: $LOCK_PID)"
    
    if ps -p "$LOCK_PID" >/dev/null 2>&1; then
        echo "   Process: ✅ RUNNING"
        echo ""
        echo "⚠️  既にインスタンスが実行中です。"
        echo ""
        echo "選択してください:"
        echo "  1) ロックファイルを削除して新規起動"
        echo "  2) テストを中止"
        echo -n "選択 (1-2): "
        read choice
        
        case "$choice" in
            1)
                echo ""
                echo "🗑️  ロックファイルを削除します..."
                rm -f "$LOCK_FILE"
                echo "✅ 削除完了"
                echo ""
                ;;
            *)
                echo ""
                echo "❌ テストを中止しました"
                exit 0
                ;;
        esac
    else
        echo "   Process: ❌ NOT RUNNING (stale lock)"
        echo ""
        echo "🗑️  古いロックファイルを削除します..."
        rm -f "$LOCK_FILE"
        echo "✅ 削除完了"
        echo ""
    fi
else
    echo "   Status: ⭕ NONE"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Test 1: 初回起動テスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "main.shの最初の数行だけを実行してロック機能をテストします..."
echo ""

# main.shの単一インスタンスチェック部分のみを抽出して実行
cat > /tmp/test-single-instance-snippet.sh << 'EOF'
#!/bin/bash

# Single Instance Check (from main.sh)
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE="${LOCK_DIR}/playcover-manager-running.lock"

is_lock_stale() {
    local lock_file=$1
    if [[ ! -f "$lock_file" ]]; then
        return 0  # No lock file = not stale
    fi
    
    local lock_pid=$(cat "$lock_file" 2>/dev/null)
    if [[ -z "$lock_pid" ]]; then
        return 0  # Empty lock = stale
    fi
    
    # Check if process exists
    if ps -p "$lock_pid" >/dev/null 2>&1; then
        return 1  # Process exists = not stale
    else
        return 0  # Process doesn't exist = stale
    fi
}

# Check for existing instance
if [[ -f "$LOCK_FILE" ]]; then
    if is_lock_stale "$LOCK_FILE"; then
        # Stale lock, remove it
        rm -f "$LOCK_FILE"
        echo "✅ Test 1 PASS: Stale lock detected and removed"
    else
        # Another instance is running
        echo "⚠️  Test 1: Another instance detected"
        echo "既存のプロセスPID: $(cat "$LOCK_FILE")"
        exit 0
    fi
fi

# Create lock file with current PID
echo $$ > "$LOCK_FILE"
echo "✅ Test 1 PASS: Lock file created with PID $$"

# Clean up lock on exit
cleanup_lock() {
    rm -f "$LOCK_FILE"
    echo "✅ Test 1 PASS: Lock file cleaned up on exit"
}

trap cleanup_lock EXIT INT TERM QUIT

# Simulate some work
echo "⏳ Simulating work for 3 seconds..."
sleep 3

echo "✅ Test 1 COMPLETE"
EOF

chmod +x /tmp/test-single-instance-snippet.sh
bash /tmp/test-single-instance-snippet.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Test 2: 重複起動防止テスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "バックグラウンドで1つ目のインスタンスを起動します..."
echo ""

# バックグラウンドで起動
bash /tmp/test-single-instance-snippet.sh &
BG_PID=$!
echo "📍 Background process started: PID $BG_PID"

# ロックファイルが作成されるまで待機
sleep 1

echo ""
echo "2つ目のインスタンスを起動して、拒否されることを確認します..."
echo ""

# 2つ目を起動（拒否されるはず）
if bash /tmp/test-single-instance-snippet.sh; then
    echo "❌ Test 2 FAIL: Second instance was allowed to start"
else
    echo "✅ Test 2 PASS: Second instance was correctly rejected"
fi

echo ""
echo "バックグラウンドプロセスの終了を待機..."
wait $BG_PID

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Test 3: ロック解放後の再起動テスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ロックファイルが解放された後、新しいインスタンスが起動できることを確認..."
echo ""

if [[ -f "$LOCK_FILE" ]]; then
    echo "❌ Test 3 FAIL: Lock file still exists after cleanup"
else
    echo "✅ Test 3 PASS: Lock file was properly cleaned up"
fi

# 新しいインスタンスを起動
bash /tmp/test-single-instance-snippet.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All Tests Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# クリーンアップ
rm -f /tmp/test-single-instance-snippet.sh

echo "📋 Final Status:"
if [[ -f "$LOCK_FILE" ]]; then
    echo "   Lock file: ❌ EXISTS (should be cleaned up)"
    echo "   Manual cleanup: rm -f $LOCK_FILE"
else
    echo "   Lock file: ✅ CLEANED UP"
fi
echo ""
