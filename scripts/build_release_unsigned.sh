#!/bin/bash

################################################################################
# PlayCoverManager 署名なしリリースビルドスクリプト（無料）
################################################################################

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 設定
PROJECT_NAME="PlayCoverManager"
SCHEME="PlayCoverManager"
BUILD_DIR="build/release-unsigned"
DMG_NAME="${PROJECT_NAME}.dmg"

log_info "署名なしリリースビルド開始（無料配布用）"
echo ""

# クリーン
log_info "ビルドディレクトリをクリーン..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Releaseビルド（署名なし）
log_info "Releaseビルド中..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="$BUILD_DIR/Build/Products/Release/${PROJECT_NAME}.app"

log_success "ビルド完了！"

# DMG作成（appdmgを使用）
log_info "DMGを作成中（appdmgを使用）..."
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# appdmgがインストールされているか確認
if ! command -v appdmg &> /dev/null; then
    log_warning "appdmgがインストールされていません。シンプルなDMGを作成します。"
    
    # 既存のDMGを削除
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"
    
    # シンプルなDMG作成（フォールバック）
    hdiutil create -volname "$PROJECT_NAME" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO "$DMG_PATH"
    
    log_success "DMG作成完了！（シンプル版）"
    log_info "より見た目の良いDMGを作成するには:"
    echo "  npm install -g appdmg"
    echo "  ./scripts/build_release_unsigned.sh"
else
    # appdmgで綺麗なDMGを作成
    
    # 既存のDMGを削除
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"
    
    # 背景画像の確認と作成
    if [ ! -f "dmg-background.png" ]; then
        if [ -x "scripts/create_dmg_background.sh" ]; then
            log_info "背景画像を作成中..."
            ./scripts/create_dmg_background.sh > /dev/null 2>&1 || true
        fi
    fi
    
    # アイコンパス
    ICON_PATH="PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
    
    # appdmg設定ファイルを生成
    CONFIG_JSON="appdmg-config-temp.json"
    cat > "$CONFIG_JSON" << EOF
{
  "title": "$PROJECT_NAME",
EOF
    
    if [ -f "$ICON_PATH" ]; then
        cat >> "$CONFIG_JSON" << EOF
  "icon": "$ICON_PATH",
EOF
    fi
    
    if [ -f "dmg-background.png" ]; then
        cat >> "$CONFIG_JSON" << EOF
  "background": "dmg-background.png",
EOF
    fi
    
    cat >> "$CONFIG_JSON" << EOF
  "icon-size": 128,
  "window": {
    "size": { "width": 600, "height": 400 },
    "position": { "x": 200, "y": 120 }
  },
  "contents": [
    { "x": 150, "y": 200, "type": "file", "path": "$APP_PATH" },
    { "x": 450, "y": 200, "type": "link", "path": "/Applications" }
  ]
}
EOF
    
    # appdmgでDMG作成
    appdmg "$CONFIG_JSON" "$DMG_PATH" > /dev/null 2>&1
    
    # 一時ファイル削除
    rm -f "$CONFIG_JSON"
    
    log_success "DMG作成完了！（appdmg版 - プロフェッショナル）"
fi

# SHA256計算
log_info "SHA256ハッシュを計算中..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

# サマリー
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "署名なしリリースビルドが完了しました！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "配布用ファイル:"
echo "  📦 $(pwd)/${DMG_PATH}"
echo ""
log_info "ファイルサイズ:"
ls -lh "$DMG_PATH" | awk '{print "  " $5}'
echo ""
log_info "SHA256ハッシュ（Homebrew Cask用）:"
echo "  ${SHA256}"
echo ""
log_warning "⚠️  このビルドは署名されていません"
echo ""
log_info "ユーザーへの案内:"
echo "  1. DMGをダウンロード"
echo "  2. アプリを「アプリケーション」フォルダにドラッグ"
echo "  3. 右クリック → 「開く」で初回起動"
echo ""
log_info "GitHub Releasesにアップロード:"
echo "  1. git tag -a v1.0.0 -m 'Release v1.0.0'"
echo "  2. git push origin v1.0.0"
echo "  3. https://github.com/HEHEX8/PlayCoverManagerGUI/releases/new"
echo "  4. DMGファイルをアップロード"
echo ""
log_info "Homebrew Cask対応:"
echo "  Cask formulaに以下のSHA256を記載:"
echo "  sha256 \"${SHA256}\""
echo ""
