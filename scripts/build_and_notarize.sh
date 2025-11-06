#!/bin/bash

################################################################################
# PlayCoverManager ビルド・署名・公証スクリプト
################################################################################

set -e  # エラーが発生したら即座に終了

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 設定
PROJECT_NAME="PlayCoverManager"
SCHEME="PlayCoverManager"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}.dmg"

# 認証情報（環境変数から取得）
APPLE_ID="${NOTARIZATION_APPLE_ID:-}"
TEAM_ID="${NOTARIZATION_TEAM_ID:-}"
PASSWORD="${NOTARIZATION_PASSWORD:-}"
KEYCHAIN_PROFILE="${NOTARIZATION_KEYCHAIN_PROFILE:-}"

################################################################################
# 関数定義
################################################################################

# 認証情報チェック
check_credentials() {
    log_info "認証情報をチェック中..."
    
    if [ -n "$KEYCHAIN_PROFILE" ]; then
        log_success "Keychainプロファイル使用: $KEYCHAIN_PROFILE"
        return 0
    fi
    
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$PASSWORD" ]; then
        log_warning "認証情報が設定されていません"
        log_info "以下の環境変数を設定してください:"
        echo "  export NOTARIZATION_APPLE_ID=\"your-email@example.com\""
        echo "  export NOTARIZATION_TEAM_ID=\"YOUR_TEAM_ID\""
        echo "  export NOTARIZATION_PASSWORD=\"your-app-specific-password\""
        echo ""
        log_info "または、Keychainプロファイルを使用:"
        echo "  export NOTARIZATION_KEYCHAIN_PROFILE=\"your-profile-name\""
        echo ""
        log_warning "公証をスキップして続行しますか？ [y/N]"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_error "中断しました"
            exit 1
        fi
        return 1
    fi
    
    log_success "認証情報が設定されています"
    return 0
}

# クリーン
clean_build() {
    log_info "ビルドディレクトリをクリーン..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    log_success "クリーン完了"
}

# Archiveビルド
build_archive() {
    log_info "Archiveビルド開始..."
    
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="Developer ID Application" \
        | xcbeautify || xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="Developer ID Application"
    
    log_success "Archiveビルド完了"
}

# エクスポート
export_app() {
    log_info "アプリをエクスポート中..."
    
    # ExportOptions.plistを作成
    cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"
    
    log_success "エクスポート完了"
}

# 署名検証
verify_signature() {
    log_info "署名を検証中..."
    
    APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"
    
    # codesignで検証
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    log_success "codesign検証成功"
    
    # spctlで検証
    spctl --assess --verbose=4 --type execute "$APP_PATH" || true
    
    log_success "署名検証完了"
}

# DMG作成
create_dmg() {
    log_info "DMGを作成中..."
    
    APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"
    
    # 既存のDMGを削除
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"
    
    # DMG作成
    hdiutil create -volname "$PROJECT_NAME" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO "$DMG_PATH"
    
    log_success "DMG作成完了: $DMG_PATH"
}

# 公証
notarize() {
    if ! check_credentials; then
        log_warning "公証をスキップします"
        return 0
    fi
    
    log_info "公証リクエストを送信中..."
    
    # Keychainプロファイル使用
    if [ -n "$KEYCHAIN_PROFILE" ]; then
        xcrun notarytool submit "$DMG_PATH" \
            --keychain-profile "$KEYCHAIN_PROFILE" \
            --wait
    else
        # 環境変数使用
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$PASSWORD" \
            --wait
    fi
    
    log_success "公証完了"
}

# Stapling
staple() {
    log_info "Staplingチケットを添付中..."
    
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    
    log_success "Stapling完了"
}

# 最終検証
final_verification() {
    log_info "最終検証中..."
    
    # Gatekeeperテスト
    spctl --assess --verbose=4 --type open --context context:primary-signature "$DMG_PATH"
    
    log_success "全ての検証が完了しました！"
}

# サマリー表示
show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "ビルド・署名・公証が完了しました！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "配布可能なファイル:"
    echo "  📦 $(pwd)/${DMG_PATH}"
    echo ""
    log_info "ファイルサイズ:"
    ls -lh "$DMG_PATH" | awk '{print "  " $5}'
    echo ""
    log_info "次のステップ:"
    echo "  1. DMGファイルをテスト"
    echo "  2. GitHub Releasesにアップロード"
    echo "  3. ユーザーに配布"
    echo ""
}

################################################################################
# メイン処理
################################################################################

main() {
    log_info "PlayCoverManager ビルド・署名・公証スクリプト"
    echo ""
    
    # 1. クリーン
    clean_build
    
    # 2. Archiveビルド
    build_archive
    
    # 3. エクスポート
    export_app
    
    # 4. 署名検証
    verify_signature
    
    # 5. DMG作成
    create_dmg
    
    # 6. 公証
    notarize
    
    # 7. Stapling
    staple
    
    # 8. 最終検証
    final_verification
    
    # 9. サマリー
    show_summary
}

# スクリプト実行
main "$@"
