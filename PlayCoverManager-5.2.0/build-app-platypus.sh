#!/bin/bash
#######################################################
# PlayCover Manager - Platypus版 アプリビルダー
# Platypusを使用して独立したアプリプロセスを作成
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.2.0"
BUNDLE_ID="com.playcover.manager"
BUILD_DIR="build-platypus"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ${APP_NAME} v${APP_VERSION} をビルド中 (Platypus版)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Platypusがインストールされているか確認
if ! command -v platypus &> /dev/null; then
    echo "❌ Platypusがインストールされていません"
    echo ""
    echo "インストール方法:"
    echo "  1. Homebrew経由: brew install --cask platypus"
    echo "  2. 公式サイト: https://sveinbjorn.org/platypus"
    echo ""
    exit 1
fi

echo "✅ Platypus が見つかりました"
PLATYPUS_VERSION=$(platypus -v 2>&1 | head -1)
echo "   Version: $PLATYPUS_VERSION"
echo ""

# 以前のビルドをクリーンアップ
if [ -d "${BUILD_DIR}" ]; then
    echo "🧹 以前のビルドをクリーンアップ中..."
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

# バンドルファイルディレクトリを作成
BUNDLE_FILES_DIR="${BUILD_DIR}/bundle-files"
mkdir -p "${BUNDLE_FILES_DIR}"

# 必要なファイルをコピー
echo "📚 スクリプトとライブラリをコピー中..."
cp main.sh "${BUNDLE_FILES_DIR}/"
cp -r lib "${BUNDLE_FILES_DIR}/"

# アイコンがあればコピー
if [ -f "AppIcon.icns" ]; then
    echo "🎨 アプリアイコンをコピー中..."
    cp AppIcon.icns "${BUNDLE_FILES_DIR}/"
    ICON_ARG="--app-icon AppIcon.icns"
else
    echo "ℹ️  AppIcon.icnsが見つかりません"
    ICON_ARG=""
fi

# Platypus Profileを作成（GUI設定をスクリプト化）
PROFILE="${BUILD_DIR}/PlayCoverManager.platypus"

cat > "$PROFILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AcceptsFiles</key>
    <false/>
    <key>AcceptsText</key>
    <false/>
    <key>AppPathAsFirstArg</key>
    <true/>
    <key>Author</key>
    <string>HEHEX8</string>
    <key>BundledFiles</key>
    <array>
        <string>${BUNDLE_FILES_DIR}/main.sh</string>
        <string>${BUNDLE_FILES_DIR}/lib</string>
    </array>
    <key>Creator</key>
    <string>Platypus-5.4</string>
    <key>DeclareService</key>
    <false/>
    <key>DestinationPath</key>
    <string>${BUILD_DIR}/${APP_NAME}.app</string>
    <key>DevelopmentVersion</key>
    <false/>
    <key>ExecutablePath</key>
    <string>/usr/local/share/platypus/ScriptExec</string>
    <key>IconPath</key>
    <string>AppIcon.icns</string>
    <key>Identifier</key>
    <string>${BUNDLE_ID}</string>
    <key>InterfaceType</key>
    <string>Text Window</string>
    <key>InterpreterArgs</key>
    <array/>
    <key>InterpreterPath</key>
    <string>/bin/zsh</string>
    <key>Name</key>
    <string>${APP_NAME}</string>
    <key>NibPath</key>
    <string>/usr/local/share/platypus/MainMenu.nib</string>
    <key>OptimizeApplication</key>
    <false/>
    <key>PromptForFileOnLaunch</key>
    <false/>
    <key>RemainRunningAfterCompletion</key>
    <true/>
    <key>Role</key>
    <string>Viewer</string>
    <key>ScriptPath</key>
    <string>${BUNDLE_FILES_DIR}/main.sh</string>
    <key>Secure</key>
    <false/>
    <key>ShowInDock</key>
    <true/>
    <key>StatusItemDisplayType</key>
    <string>Text</string>
    <key>StatusItemIcon</key>
    <data></data>
    <key>StatusItemTitle</key>
    <string>${APP_NAME}</string>
    <key>Suffixes</key>
    <array/>
    <key>TextBackground</key>
    <string>#1C1C1C</string>
    <key>TextEncoding</key>
    <integer>4</integer>
    <key>TextFont</key>
    <string>Monaco</string>
    <key>TextForeground</key>
    <string>#FFFFFF</string>
    <key>TextSize</key>
    <real>12</real>
    <key>UseXMLPlistFormat</key>
    <false/>
    <key>Version</key>
    <string>${APP_VERSION}</string>
</dict>
</plist>
EOF

echo "📄 Platypus Profileを作成しました"
echo ""

# Platypusでアプリをビルド
echo "🔨 Platypusでアプリをビルド中..."
if platypus \
    --load-profile "$PROFILE" \
    --overwrite \
    --name "${APP_NAME}" \
    --app-version "${APP_VERSION}" \
    --identifier "${BUNDLE_ID}" \
    --interpreter /bin/zsh \
    --interface-type 'Text Window' \
    --text-background-color '#1C1C1C' \
    --text-foreground-color '#FFFFFF' \
    --text-font 'Monaco 12' \
    $ICON_ARG \
    --bundled-file "${BUNDLE_FILES_DIR}/lib" \
    --quit-after-execution \
    "${BUNDLE_FILES_DIR}/main.sh" \
    "${BUILD_DIR}/${APP_NAME}.app"; then
    
    echo "✅ ビルド成功！"
else
    echo "❌ ビルド失敗"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Platypus版ビルド完了！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 出力:"
echo "   • アプリ: ${BUILD_DIR}/${APP_NAME}.app"
echo ""
echo "🚀 インストール:"
echo "   cp -r '${BUILD_DIR}/${APP_NAME}.app' /Applications/"
echo ""
echo "💡 このアプリは:"
echo "   ✅ Terminal.appを使用しない独立プロセス"
echo "   ✅ Activity Monitorで'PlayCover Manager'として表示"
echo "   ✅ シングルインスタンス機能あり(main.sh内)"
echo "   ✅ Text Windowでリアルタイム出力表示"
echo ""
