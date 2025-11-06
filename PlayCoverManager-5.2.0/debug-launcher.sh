#!/bin/bash
#######################################################
# PlayCover Manager - Debug Launcher
# アプリが起動しない問題を診断するスクリプト
#######################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PlayCover Manager - 起動デバッグ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# アプリバンドルのパス
APP_PATH="/Applications/PlayCover Manager.app"

echo "📦 Step 1: アプリバンドルの存在確認"
if [ -d "$APP_PATH" ]; then
    echo "   ✅ アプリバンドルが存在します: $APP_PATH"
else
    echo "   ❌ アプリバンドルが見つかりません: $APP_PATH"
    echo ""
    echo "解決策:"
    echo "   cd $(pwd)"
    echo "   cp -r 'build/PlayCover Manager.app' /Applications/"
    exit 1
fi

echo ""
echo "📂 Step 2: ファイル構造の確認"

LAUNCHER="$APP_PATH/Contents/MacOS/PlayCoverManager"
MAIN_SCRIPT="$APP_PATH/Contents/Resources/main-script.sh"
CORE_LIB="$APP_PATH/Contents/Resources/lib/00_core.sh"

echo "   Launcher: $LAUNCHER"
if [ -f "$LAUNCHER" ]; then
    echo "      ✅ 存在します"
    if [ -x "$LAUNCHER" ]; then
        echo "      ✅ 実行権限あり"
    else
        echo "      ❌ 実行権限なし"
        echo "         修正: chmod +x '$LAUNCHER'"
    fi
else
    echo "      ❌ 存在しません"
fi

echo ""
echo "   Main Script: $MAIN_SCRIPT"
if [ -f "$MAIN_SCRIPT" ]; then
    echo "      ✅ 存在します"
    if [ -x "$MAIN_SCRIPT" ]; then
        echo "      ✅ 実行権限あり"
    else
        echo "      ❌ 実行権限なし"
        echo "         修正: chmod +x '$MAIN_SCRIPT'"
    fi
    
    # Shebangを確認
    SHEBANG=$(head -1 "$MAIN_SCRIPT")
    echo "      Shebang: $SHEBANG"
    if [[ "$SHEBANG" == "#!/bin/zsh" ]] || [[ "$SHEBANG" == "#!/usr/bin/env zsh" ]]; then
        echo "      ✅ Shebang正常"
    else
        echo "      ⚠️  予期しないShebang: $SHEBANG"
    fi
else
    echo "      ❌ 存在しません"
fi

echo ""
echo "   Core Library: $CORE_LIB"
if [ -f "$CORE_LIB" ]; then
    echo "      ✅ 存在します"
else
    echo "      ❌ 存在しません"
fi

echo ""
echo "🔐 Step 3: macOSセキュリティ属性の確認"
QUARANTINE=$(xattr -l "$APP_PATH" 2>/dev/null | grep com.apple.quarantine)
if [ -n "$QUARANTINE" ]; then
    echo "   ⚠️  Quarantine属性が設定されています"
    echo "      $QUARANTINE"
    echo ""
    echo "   解決策:"
    echo "      xattr -dr com.apple.quarantine '$APP_PATH'"
else
    echo "   ✅ Quarantine属性なし"
fi

echo ""
echo "🔒 Step 4: ロックファイルの確認"
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    echo "   ⚠️  ロックファイルが存在します"
    echo "      Path: $LOCK_FILE"
    echo "      PID: $LOCK_PID"
    
    if ps -p "$LOCK_PID" >/dev/null 2>&1; then
        echo "      ✅ プロセスは実行中です"
        echo ""
        echo "   既にPlayCover Managerが実行中です。"
        echo "   Terminalウィンドウを確認してください。"
    else
        echo "      ❌ プロセスは存在しません（古いロック）"
        echo ""
        echo "   解決策:"
        echo "      rm -f '$LOCK_FILE'"
    fi
else
    echo "   ✅ ロックファイルなし"
fi

echo ""
echo "🖥️  Step 5: Terminalプロセスの確認"
TERMINAL_PROCS=$(ps aux | grep -i "playcover" | grep -v grep | wc -l)
if [ "$TERMINAL_PROCS" -gt 0 ]; then
    echo "   ⚠️  PlayCover関連のプロセスが実行中:"
    ps aux | grep -i "playcover" | grep -v grep | head -5
else
    echo "   ✅ PlayCover関連のプロセスなし"
fi

echo ""
echo "🧪 Step 6: ランチャースクリプトの直接テスト"
echo "   ランチャーを直接実行してみます..."
echo ""

# ランチャーを直接実行
if bash "$LAUNCHER" 2>&1; then
    echo ""
    echo "   ✅ ランチャーは正常に実行されました"
else
    EXIT_CODE=$?
    echo ""
    echo "   ❌ ランチャーがエラーで終了しました (Exit code: $EXIT_CODE)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 診断完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 追加のデバッグ方法:"
echo ""
echo "1. ランチャーを直接実行:"
echo "   bash '$LAUNCHER'"
echo ""
echo "2. main-script.shを直接実行:"
echo "   zsh '$MAIN_SCRIPT'"
echo ""
echo "3. Console.appでログを確認:"
echo "   - アプリケーション → ユーティリティ → Console"
echo "   - 「Terminal」や「PlayCover」で検索"
echo ""
echo "4. ロックファイルをクリア:"
echo "   rm -f '$LOCK_FILE'"
echo ""
echo "5. アプリを再ビルド:"
echo "   cd $(pwd)"
echo "   rm -rf build/"
echo "   ./build-app.sh"
echo "   cp -r 'build/PlayCover Manager.app' /Applications/"
echo ""
