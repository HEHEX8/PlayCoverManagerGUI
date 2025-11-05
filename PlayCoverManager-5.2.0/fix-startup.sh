#!/bin/bash
#######################################################
# PlayCover Manager - 起動問題の自動修正スクリプト
#######################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PlayCover Manager 起動問題の自動修正"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APP_PATH="/Applications/PlayCover Manager.app"
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"
LAUNCHER_LOG="${TMPDIR:-/tmp}/playcover-manager-launcher.log"

# 1. ロックファイルのクリーンアップ
echo "🔒 Step 1: ロックファイルのクリーンアップ..."
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$LOCK_PID" ]; then
        if ps -p "$LOCK_PID" >/dev/null 2>&1; then
            echo "   ⚠️  プロセス $LOCK_PID が実行中です"
            echo "   終了させますか？ (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                kill "$LOCK_PID" 2>/dev/null
                echo "   ✅ プロセスを終了しました"
            else
                echo "   ⏭️  スキップしました"
            fi
        else
            echo "   🗑️  古いロックファイルを削除します"
            rm -f "$LOCK_FILE"
            echo "   ✅ 削除完了"
        fi
    else
        rm -f "$LOCK_FILE"
        echo "   ✅ 空のロックファイルを削除しました"
    fi
else
    echo "   ✅ ロックファイルなし"
fi

echo ""

# 2. ランチャーログの確認
echo "📋 Step 2: ランチャーログの確認..."
if [ -f "$LAUNCHER_LOG" ]; then
    echo "   ログファイル: $LAUNCHER_LOG"
    echo ""
    echo "   --- 最新のログ（最後の20行）---"
    tail -20 "$LAUNCHER_LOG"
    echo "   --- ログ終了 ---"
    echo ""
    echo "   ログをクリアしますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -f "$LAUNCHER_LOG"
        echo "   ✅ ログをクリアしました"
    fi
else
    echo "   ℹ️  ログファイルなし（まだ起動されていない）"
fi

echo ""

# 3. 実行権限の確認
echo "🔐 Step 3: 実行権限の確認..."
if [ -d "$APP_PATH" ]; then
    LAUNCHER="$APP_PATH/Contents/MacOS/PlayCoverManager"
    MAIN_SCRIPT="$APP_PATH/Contents/Resources/main-script.sh"
    
    FIXED=0
    
    if [ -f "$LAUNCHER" ]; then
        if [ ! -x "$LAUNCHER" ]; then
            echo "   🔧 ランチャーに実行権限を付与..."
            chmod +x "$LAUNCHER"
            FIXED=1
        fi
    fi
    
    if [ -f "$MAIN_SCRIPT" ]; then
        if [ ! -x "$MAIN_SCRIPT" ]; then
            echo "   🔧 メインスクリプトに実行権限を付与..."
            chmod +x "$MAIN_SCRIPT"
            FIXED=1
        fi
    fi
    
    if [ $FIXED -eq 0 ]; then
        echo "   ✅ 実行権限は正常です"
    else
        echo "   ✅ 実行権限を修正しました"
    fi
else
    echo "   ❌ アプリが見つかりません: $APP_PATH"
    echo ""
    echo "   アプリをインストールしますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -d "build/PlayCover Manager.app" ]; then
            echo "   📦 アプリをインストール中..."
            cp -r "build/PlayCover Manager.app" /Applications/
            echo "   ✅ インストール完了"
        else
            echo "   ❌ build/PlayCover Manager.app が見つかりません"
            echo "   まず ./build-app.sh を実行してください"
        fi
    fi
fi

echo ""

# 4. Quarantine属性の削除
echo "🔓 Step 4: macOSセキュリティ属性の確認..."
if [ -d "$APP_PATH" ]; then
    QUARANTINE=$(xattr -l "$APP_PATH" 2>/dev/null | grep com.apple.quarantine)
    if [ -n "$QUARANTINE" ]; then
        echo "   ⚠️  Quarantine属性が設定されています"
        echo "   削除しますか？ (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            xattr -dr com.apple.quarantine "$APP_PATH"
            echo "   ✅ Quarantine属性を削除しました"
        fi
    else
        echo "   ✅ セキュリティ属性は正常です"
    fi
fi

echo ""

# 5. テスト起動
echo "🚀 Step 5: テスト起動"
echo "   アプリを起動してテストしますか？ (y/N): "
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "   起動中..."
    open "$APP_PATH"
    
    echo ""
    echo "   ⏳ 5秒待機中..."
    sleep 5
    
    # ログを確認
    if [ -f "$LAUNCHER_LOG" ]; then
        echo ""
        echo "   📋 ランチャーログ:"
        tail -10 "$LAUNCHER_LOG"
    fi
    
    # Terminalウィンドウが開いたか確認
    TERMINAL_COUNT=$(osascript -e 'tell application "Terminal" to count windows' 2>/dev/null || echo 0)
    if [ "$TERMINAL_COUNT" -gt 0 ]; then
        echo ""
        echo "   ✅ Terminalウィンドウが開いています（$TERMINAL_COUNT 個）"
    else
        echo ""
        echo "   ❌ Terminalウィンドウが開いていません"
        echo ""
        echo "   トラブルシューティング:"
        echo "   1. システム設定 → プライバシーとセキュリティ → オートメーション"
        echo "   2. Terminalの権限を確認"
        echo "   3. ランチャーログを確認: cat $LAUNCHER_LOG"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 修正スクリプト完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 次のステップ:"
echo ""
echo "1. アプリが起動しない場合:"
echo "   ./debug-launcher.sh"
echo ""
echo "2. ランチャーログを確認:"
echo "   cat $LAUNCHER_LOG"
echo ""
echo "3. 直接実行してテスト:"
echo "   zsh main.sh"
echo ""
echo "4. さらに詳しいトラブルシューティング:"
echo "   cat TROUBLESHOOTING.md"
echo ""
