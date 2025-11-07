#!/bin/bash
#######################################################
# PlayCover Manager GUI - DMG作成スクリプト
# appdmgツールを使用した確実なDMG作成
#######################################################

set -e

APP_NAME="PlayCoverManager"

# バージョン情報を取得（Info.plistから）
if [ -f "PlayCoverManager/Info.plist" ]; then
    APP_VERSION=$(defaults read "${PWD}/PlayCoverManager/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
else
    APP_VERSION="1.0.0"
fi

# build_release_unsigned.sh の出力を探す
if [ -d "build/release-unsigned/Build/Products/Release/${APP_NAME}.app" ]; then
    SOURCE_APP="build/release-unsigned/Build/Products/Release/${APP_NAME}.app"
    OUTPUT_DIR="build/release-unsigned"
elif [ -d "build/Release/${APP_NAME}.app" ]; then
    SOURCE_APP="build/Release/${APP_NAME}.app"
    OUTPUT_DIR="build"
else
    SOURCE_APP="build/Release/${APP_NAME}.app"
    OUTPUT_DIR="build"
fi

DMG_NAME="PlayCoverManager-${APP_VERSION}.dmg"
CONFIG_JSON="appdmg-config.json"

echo "🚀 appdmgでDMGを作成中..."
echo ""

# アプリの存在確認
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ アプリが見つかりません: $SOURCE_APP"
    echo "   先に ./scripts/build_release_unsigned.sh を実行してください"
    exit 1
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

# 背景画像の確認と作成
if [ ! -f "dmg-background.png" ]; then
    echo "⚠️  背景画像が見つかりません"
    echo "📦 背景画像を自動作成中..."
    
    if [ -x "scripts/create_dmg_background.sh" ]; then
        ./scripts/create_dmg_background.sh
    else
        echo "⚠️  背景画像作成スクリプトが見つかりません"
        echo "   背景なしでDMGを作成します"
    fi
fi

# アイコンファイルのパス
ICON_PATH="PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
if [ ! -f "$ICON_PATH" ]; then
    echo "⚠️  アイコンファイルが見つかりません: $ICON_PATH"
    ICON_PATH=""
fi

# appdmg設定ファイルを生成
echo "📝 appdmg設定ファイルを生成中..."
cat > "$CONFIG_JSON" << EOF
{
  "title": "PlayCover Manager ${APP_VERSION}",
EOF

# アイコンを追加（存在する場合のみ）
if [ -n "$ICON_PATH" ]; then
    cat >> "$CONFIG_JSON" << EOF
  "icon": "${ICON_PATH}",
EOF
fi

# 背景を追加（存在する場合のみ）
if [ -f "dmg-background.png" ]; then
    cat >> "$CONFIG_JSON" << EOF
  "background": "dmg-background.png",
EOF
fi

cat >> "$CONFIG_JSON" << EOF
  "icon-size": 128,
  "window": {
    "size": {
      "width": 600,
      "height": 400
    },
    "position": {
      "x": 200,
      "y": 120
    }
  },
  "contents": [
    {
      "x": 150,
      "y": 200,
      "type": "file",
      "path": "${SOURCE_APP}"
    },
    {
      "x": 450,
      "y": 200,
      "type": "link",
      "path": "/Applications"
    }
  ]
}
EOF

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# 以前のDMGを削除
rm -f "${OUTPUT_DIR}/${DMG_NAME}"

# appdmgでDMGを作成
echo "📦 DMGを作成中..."
echo ""
echo "📐 設定:"
echo "   バージョン: ${APP_VERSION}"
echo "   ウィンドウサイズ: 600x400"
echo "   アイコンサイズ: 128x128"
echo "   左アイコン位置: (150, 200)"
echo "   右アイコン位置: (450, 200)"
if [ -f "dmg-background.png" ]; then
    echo "   背景画像: あり"
else
    echo "   背景画像: なし"
fi
echo ""

appdmg "$CONFIG_JSON" "${OUTPUT_DIR}/${DMG_NAME}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ DMGの作成に成功しました！"
    echo ""
    ls -lh "${OUTPUT_DIR}/${DMG_NAME}"
    echo ""
    
    # SHA256ハッシュを計算
    echo "🔐 SHA256ハッシュを計算中..."
    SHA256=$(shasum -a 256 "${OUTPUT_DIR}/${DMG_NAME}" | awk '{print $1}')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 配布用DMGが準備できました！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 DMGファイル:"
    echo "   ${OUTPUT_DIR}/${DMG_NAME}"
    echo ""
    echo "🔐 SHA256ハッシュ（Homebrew Cask用）:"
    echo "   ${SHA256}"
    echo ""
    echo "📦 次のステップ:"
    echo "   1. DMGをテスト: open '${OUTPUT_DIR}/${DMG_NAME}'"
    echo "   2. GitHub Releasesにアップロード"
    echo "   3. Homebrew Caskに SHA256 を記載"
    echo ""
    echo "✨ 特徴:"
    echo "   - 確実に動作するappdmg方式"
    echo "   - JSON設定で簡単カスタマイズ"
    echo "   - 正確なアイコン配置"
    if [ -f "dmg-background.png" ]; then
        echo "   - カスタム背景画像付き"
    fi
    
    # 設定ファイルをクリーンアップ
    rm -f "$CONFIG_JSON"
else
    echo ""
    echo "❌ DMGの作成に失敗しました"
    echo ""
    echo "🔍 トラブルシューティング:"
    echo "   1. appdmg-config.jsonの内容を確認"
    echo "   2. アプリのパスが正しいか確認"
    echo "   3. 背景画像のパスが正しいか確認（オプション）"
    echo "   4. appdmgを再インストール: npm install -g appdmg"
    rm -f "$CONFIG_JSON"
    exit 1
fi
