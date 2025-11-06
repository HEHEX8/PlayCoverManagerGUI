#!/bin/bash

################################################################################
# PlayCoverManager 開発用ビルドスクリプト（署名なし）
################################################################################

set -e

# 色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 設定
PROJECT_NAME="PlayCoverManager"
SCHEME="PlayCoverManager"
BUILD_DIR="build/dev"

log_info "開発用ビルド開始..."

# クリーン
log_info "ビルドディレクトリをクリーン..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ビルド
log_info "ビルド中..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="$BUILD_DIR/Build/Products/Debug/${PROJECT_NAME}.app"

log_success "ビルド完了！"
echo ""
log_info "アプリのパス:"
echo "  $APP_PATH"
echo ""
log_info "起動方法:"
echo "  open \"$APP_PATH\""
echo ""
