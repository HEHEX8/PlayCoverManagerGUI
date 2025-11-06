#!/bin/bash
#######################################################
# DMG作成 - Standalone版（appdmg使用）
#######################################################

set -e

APP_NAME="PlayCover Manager"

# Get version from build-app-standalone.sh
if [ -f "build-app-standalone.sh" ]; then
    APP_VERSION=$(grep '^APP_VERSION=' build-app-standalone.sh | cut -d'"' -f2)
else
    APP_VERSION="5.2.0"
fi

SOURCE_APP="build-standalone/${APP_NAME}.app"
DMG_NAME="PlayCover-Manager-${APP_VERSION}-Standalone.dmg"
CONFIG_JSON="appdmg-config-standalone.json"
BACKGROUND_IMG="dmg-background.png"

echo "🚀 appdmgでDMGを作成中..."
echo ""

# アプリの存在確認
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ アプリが見つかりません: $SOURCE_APP"
    echo "   先に ./build-app.sh を実行してください"
    exit 1
fi

# 設定ファイルの存在確認
if [ ! -f "$CONFIG_JSON" ]; then
    echo "❌ 設定ファイルが見つかりません: $CONFIG_JSON"
    exit 1
fi

# 背景画像の存在確認（オプション）
if [ ! -f "$BACKGROUND_IMG" ]; then
    echo "⚠️  背景画像が見つかりません: $BACKGROUND_IMG"
    echo "   背景なしでDMGを作成します"
    echo ""
fi

# appdmgツールがインストールされているか確認
if ! command -v appdmg &> /dev/null; then
    echo "📦 appdmgツールをインストール中..."
    if command -v npm &> /dev/null; then
        npm install -g appdmg
    else
        echo "❌ npmが必要です"
        echo ""
        echo "インストール方法:"
        echo "  brew install node"
        echo "  npm install -g appdmg"
        exit 1
    fi
fi

# 以前のDMGを削除
rm -f "${DMG_NAME}"

# appdmgでDMGを作成
echo "📦 Standalone版 DMGを作成中..."
echo ""
echo "📐 設定:"
echo "   ウィンドウサイズ: 600x400"
echo "   アイコンサイズ: 128x128"
echo "   左アイコン位置: (150, 200)"
echo "   右アイコン位置: (450, 200)"
echo ""

appdmg "$CONFIG_JSON" "${DMG_NAME}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Standalone版 DMGの作成に成功しました！"
    echo ""
    ls -lh "${DMG_NAME}"
    echo ""
    echo "🎉 配布用DMGが準備できました！"
    echo ""
    echo "📦 テスト方法:"
    echo "   open '${DMG_NAME}'"
    echo ""
    echo "✨ 特徴:"
    echo "   - 確実に動作するappdmg方式"
    echo "   - JSON設定で簡単カスタマイズ"
    echo "   - 正確なアイコン配置"
else
    echo ""
    echo "❌ DMGの作成に失敗しました"
    echo ""
    echo "🔍 トラブルシューティング:"
    echo "   1. appdmg-config.jsonの内容を確認"
    echo "   2. アプリのパスが正しいか確認"
    echo "   3. 背景画像のパスが正しいか確認"
    exit 1
fi
