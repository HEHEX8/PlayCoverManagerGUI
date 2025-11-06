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

# DMG作成
log_info "DMGを作成中..."
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# 既存のDMGを削除
[ -f "$DMG_PATH" ] && rm "$DMG_PATH"

# DMG作成
hdiutil create -volname "$PROJECT_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO "$DMG_PATH"

log_success "DMG作成完了！"

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
