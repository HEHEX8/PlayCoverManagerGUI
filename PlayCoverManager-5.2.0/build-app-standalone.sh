#!/bin/bash
# PlayCover Manager - Standalone App Builder
# Creates independent macOS app without Terminal.app dependency

set -e

# ============================================================================
# 設定
# ============================================================================

APP_NAME="PlayCover Manager"
APP_VERSION="5.2.0"
BUNDLE_ID="com.playcover.manager"
BUILD_DIR="build-standalone"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# ヘルパー関数
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# ============================================================================
# ビルド開始
# ============================================================================

print_header "PlayCover Manager - Standalone App Builder v${APP_VERSION}"

# 古いビルドをクリーンアップ
if [[ -d "$BUILD_DIR" ]]; then
    print_info "既存のビルドディレクトリをクリーンアップ中..."
    rm -rf "$BUILD_DIR"
fi

# ディレクトリ構造を作成
print_info ".app バンドル構造を作成中..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

print_success "ディレクトリ構造作成完了"

# ============================================================================
# Info.plist を作成
# ============================================================================

print_info "Info.plist を生成中..."

cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ja_JP</string>
    <key>CFBundleExecutable</key>
    <string>PlayCoverManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.playcover.manager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PlayCover Manager</string>
    <key>CFBundleDisplayName</key>
    <string>PlayCover Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>5.2.0</string>
    <key>CFBundleVersion</key>
    <string>5.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

print_success "Info.plist 生成完了"

# ============================================================================
# PkgInfo を作成
# ============================================================================

print_info "PkgInfo を生成中..."
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
print_success "PkgInfo 生成完了"

# ============================================================================
# Launcher スクリプトを作成
# ============================================================================

print_info "ランチャースクリプトを作成中..."

cat > "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager" << 'LAUNCHER_EOF'
#!/bin/zsh
# PlayCover Manager - Standalone Launcher
# Runs as independent app process

# ============================================================================
# エラーログ設定
# ============================================================================

LOG_FILE="${TMPDIR:-/tmp}/playcover-manager-standalone.log"
exec 2>> "$LOG_FILE"

echo "===== PlayCover Manager Standalone Launch =====" >> "$LOG_FILE"
echo "Launch Time: $(date)" >> "$LOG_FILE"
echo "Bundle Path: ${0:A:h:h}" >> "$LOG_FILE"

# ============================================================================
# シングルインスタンスチェック（読み取りのみ）
# ============================================================================
# NOTE: Launcher checks if instance is running, but does NOT create lock
# main.sh creates and manages the lock file with trap

LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"

is_lock_stale() {
    local lock_file="$1"
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

# 既存インスタンスのチェック
if [[ -f "$LOCK_FILE" ]]; then
    if is_lock_stale "$LOCK_FILE"; then
        echo "Removing stale lock file" >> "$LOG_FILE"
        rm -f "$LOCK_FILE"
    else
        echo "Another instance is already running" >> "$LOG_FILE"
        
        # Activate existing Terminal window
        osascript <<'ACTIVATE_EOF' 2>> "$LOG_FILE"
tell application "Terminal"
    activate
    repeat with w in windows
        if (name of w) contains "PlayCover" then
            set index of w to 1
            exit repeat
        end if
    end repeat
end tell
ACTIVATE_EOF
        
        # Show notification
        osascript -e 'display notification "PlayCover Manager は既に実行中です" with title "PlayCover Manager"' 2>> "$LOG_FILE"
        
        exit 0
    fi
fi

# NOTE: Do NOT create lock file here - main.sh will create it
# Launcher exits after opening Terminal, so trap wouldn't work anyway

# ============================================================================
# Resourcesディレクトリのパスを事前に取得
# ============================================================================

# ランチャースクリプト自身の絶対パスを取得
LAUNCHER_PATH="${0:A}"
BUNDLE_CONTENTS="${LAUNCHER_PATH:h:h}"
RESOURCES_DIR="${BUNDLE_CONTENTS}/Resources"
MAIN_SCRIPT="${RESOURCES_DIR}/main.sh"

echo "Launcher Path: ${LAUNCHER_PATH}" >> "$LOG_FILE"
echo "Bundle Contents: ${BUNDLE_CONTENTS}" >> "$LOG_FILE"
echo "Resources Directory: ${RESOURCES_DIR}" >> "$LOG_FILE"
echo "Main Script: ${MAIN_SCRIPT}" >> "$LOG_FILE"

# メインスクリプトの存在確認
if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "❌ エラー: メインスクリプトが見つかりません: $MAIN_SCRIPT" >> "$LOG_FILE"
    osascript -e 'display alert "PlayCover Manager エラー" message "メインスクリプトが見つかりません" as critical' 2>> "$LOG_FILE"
    exit 1
fi

# ============================================================================
# Terminal ウィンドウで実行（インタラクティブモード必須）
# ============================================================================

echo "Opening Terminal window for interactive execution..." >> "$LOG_FILE"

# AppleScript で新しい Terminal ウィンドウを開く
osascript 2>> "$LOG_FILE" <<EOF
tell application "Terminal"
    set wasRunning to (count of windows) > 0
    
    -- 新しいウィンドウでスクリプトを実行
    set newWindow to do script "clear; printf '\\\\033]0;PlayCover Manager\\\\007'; cd '$RESOURCES_DIR'; exec /bin/zsh '$MAIN_SCRIPT'"
    
    -- 起動時に開いた空のウィンドウを閉じる
    if not wasRunning then
        delay 0.5
        repeat with w in (get windows)
            try
                if (name of w) does not contain "PlayCover" then
                    close w
                end if
            end try
        end repeat
    end if
    
    activate
    set frontmost of newWindow to true
end tell
EOF

echo "Terminal window opened successfully" >> "$LOG_FILE"

LAUNCHER_EOF

# 実行権限を付与
chmod +x "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager"

print_success "ランチャースクリプト作成完了"

# ============================================================================
# リソースファイルをコピー
# ============================================================================

print_info "リソースファイルをコピー中..."

# main.sh をコピー
if [[ -f "main.sh" ]]; then
    cp "main.sh" "${APP_BUNDLE}/Contents/Resources/"
    print_success "main.sh をコピー"
else
    print_error "main.sh が見つかりません"
    exit 1
fi

# lib ディレクトリをコピー
if [[ -d "lib" ]]; then
    cp -r "lib" "${APP_BUNDLE}/Contents/Resources/"
    print_success "lib/ をコピー"
else
    print_error "lib/ ディレクトリが見つかりません"
    exit 1
fi

# アイコンファイルをコピー（優先順位: .icns > .png）
if [[ -f "AppIcon.icns" ]]; then
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    print_success "AppIcon.icns をコピー"
elif [[ -f "app-icon.png" ]]; then
    cp "app-icon.png" "${APP_BUNDLE}/Contents/Resources/AppIcon.png"
    print_info "警告: AppIcon.icns が見つかりません。./create-icon.sh を実行してください"
    print_info "現在は app-icon.png をコピーしていますが、macOS はアイコンを表示しない可能性があります"
else
    print_info "警告: アイコンファイルが見つかりません"
    print_info "app-icon.png を配置して ./create-icon.sh を実行してください"
fi

# ============================================================================
# Quarantine 属性を削除
# ============================================================================

print_info "Quarantine 属性を削除中..."
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
print_success "Quarantine 属性削除完了"

# ============================================================================
# ビルド完了
# ============================================================================

print_header "ビルド完了！"

echo ""
echo -e "${GREEN}✅ アプリケーションが正常に作成されました${NC}"
echo ""
echo -e "📦 出力先: ${BLUE}${APP_BUNDLE}${NC}"
echo -e "📄 バージョン: ${BLUE}${APP_VERSION}${NC}"
echo -e "🆔 Bundle ID: ${BLUE}${BUNDLE_ID}${NC}"
echo ""

print_header "テスト方法"

echo "1. ターミナルから起動:"
echo -e "   ${YELLOW}open '${APP_BUNDLE}'${NC}"
echo ""
echo "2. Finder からダブルクリック:"
echo -e "   ${YELLOW}open '${BUILD_DIR}'${NC}"
echo ""
echo "3. プロセス確認:"
echo -e "   ${YELLOW}ps aux | grep 'PlayCover Manager'${NC}"
echo ""

print_header "配布用パッケージ作成"

# アイコンの存在をチェックして警告
if [[ ! -f "AppIcon.icns" ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  注意: AppIcon.icns が見つかりません${NC}"
    echo ""
    echo "アイコンを表示するには、以下を実行してください:"
    echo -e "   ${YELLOW}1. ./create-icon.sh${NC}          # .icns ファイルを生成"
    echo -e "   ${YELLOW}2. ./build-app-standalone.sh${NC} # アプリを再ビルド"
    echo ""
fi

echo "DMG インストーラーを作成:"
echo -e "   ${YELLOW}./create-dmg-standalone.sh${NC}"
echo ""
echo "ZIP ファイルを作成:"
echo -e "   ${YELLOW}cd '${BUILD_DIR}' && zip -r 'PlayCover-Manager-${APP_VERSION}.zip' '${APP_NAME}.app'${NC}"
echo ""

print_info "ログファイル: \${TMPDIR:-/tmp}/playcover-manager-standalone.log"

echo ""
