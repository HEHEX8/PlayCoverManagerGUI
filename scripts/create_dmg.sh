#!/bin/bash

# PlayCover Manager DMG作成スクリプト
# このスクリプトは.appをDMGファイルにパッケージングします

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PlayCover Manager DMG作成${NC}"
echo -e "${GREEN}========================================${NC}"

# 変数設定
APP_NAME="PlayCoverManager"
APP_PATH="build/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}"
OUTPUT_DIR="build"
TEMP_DMG="${OUTPUT_DIR}/${DMG_NAME}_temp.dmg"
FINAL_DMG="${OUTPUT_DIR}/${DMG_NAME}.dmg"
VOLUME_NAME="PlayCover Manager"
BACKGROUND_COLOR="#2C2C2E"

# .appファイルの存在確認
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}エラー: ${APP_PATH} が見つかりません${NC}"
    echo -e "${YELLOW}先に build_release_unsigned.sh を実行してください${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/5] 既存のDMGを削除中...${NC}"
rm -f "$TEMP_DMG" "$FINAL_DMG"

echo -e "${YELLOW}[2/5] 一時DMGを作成中...${NC}"
# 100MBのDMGを作成（.appのサイズに応じて調整）
hdiutil create -size 100m -fs HFS+ -volname "$VOLUME_NAME" "$TEMP_DMG"

echo -e "${YELLOW}[3/5] DMGをマウント中...${NC}"
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | grep "/Volumes/${VOLUME_NAME}" | awk '{print $3}')

if [ -z "$MOUNT_DIR" ]; then
    echo -e "${RED}エラー: DMGのマウントに失敗しました${NC}"
    exit 1
fi

echo -e "${YELLOW}[4/5] アプリをコピー中...${NC}"
# .appをDMGにコピー
cp -R "$APP_PATH" "$MOUNT_DIR/"

# アプリケーションフォルダへのシンボリックリンクを作成
ln -s /Applications "$MOUNT_DIR/Applications"

# .DS_Storeを設定（Finderで開いたときの見た目を調整）
cat > "$MOUNT_DIR/.DS_Store" << 'DSSTORE'
# カスタムFinderビュー設定はバイナリ形式のため、
# 代わりにapplescriptで設定することを推奨
DSSTORE

# Finderウィンドウの設定（applescript）
osascript << EOS
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background color of viewOptions to {11520, 11520, 11776}
        set position of item "${APP_NAME}.app" of container window to {120, 160}
        set position of item "Applications" of container window to {380, 160}
        update without registering applications
        delay 1
    end tell
end tell
EOS

echo -e "${YELLOW}[5/5] DMGをアンマウントして圧縮中...${NC}"
# 同期してアンマウント
sync
hdiutil detach "$MOUNT_DIR"

# 最終的な圧縮DMGを作成
hdiutil convert "$TEMP_DMG" -format UDZO -o "$FINAL_DMG"

# 一時ファイルを削除
rm -f "$TEMP_DMG"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DMG作成完了！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "出力: ${FINAL_DMG}"
echo ""
echo -e "${YELLOW}次のステップ:${NC}"
echo "1. DMGをテストインストール"
echo "2. GitHub Releasesにアップロード"
echo "3. SHA256ハッシュを取得: shasum -a 256 ${FINAL_DMG}"
