#!/bin/bash
#######################################################
# DMG背景画像作成スクリプト（オプション）
# ImageMagickを使用してシンプルな背景を生成
#######################################################

set -e

OUTPUT_FILE="dmg-background.png"
WIDTH=600
HEIGHT=400
BACKGROUND_COLOR="#2C2C2E"

echo "🎨 DMG背景画像を生成中..."

# ImageMagickがインストールされているか確認
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagickが必要です"
    echo ""
    echo "インストール方法:"
    echo "  brew install imagemagick"
    echo ""
    echo "または、Photoshop/Pixelmator等で600x400pxの背景画像を作成し、"
    echo "dmg-background.png として保存してください"
    exit 1
fi

# シンプルなグラデーション背景を作成
convert -size ${WIDTH}x${HEIGHT} \
    -define gradient:angle=135 \
    gradient:"${BACKGROUND_COLOR}"-"#1C1C1E" \
    "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ 背景画像を生成しました: $OUTPUT_FILE"
    echo ""
    echo "サイズ: ${WIDTH}x${HEIGHT}"
    echo "カラー: グラデーション (${BACKGROUND_COLOR} → #1C1C1E)"
    echo ""
    ls -lh "$OUTPUT_FILE"
else
    echo "❌ 背景画像の生成に失敗しました"
    exit 1
fi
