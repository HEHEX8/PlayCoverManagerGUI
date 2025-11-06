#!/bin/bash
#######################################################
# ソース画像からmacOS .icnsアイコンを作成
# このスクリプトはmacOSで実行してください
#######################################################

set -e

SOURCE_IMAGE="app-icon.png"
ICONSET_DIR="AppIcon.iconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ エラー: $SOURCE_IMAGE が見つかりません"
    exit 1
fi

echo "🎨 $SOURCE_IMAGE からmacOSアイコンを作成中..."
echo ""

# ソース画像のフォーマットを確認
IMAGE_FORMAT=$(file "$SOURCE_IMAGE" | grep -o "PNG\|JPEG")
echo "📋 検出されたフォーマット: $IMAGE_FORMAT"

# JPEGの場合、最初にPNGに変換
if [[ "$IMAGE_FORMAT" == "JPEG" ]]; then
    echo "🔄 JPEGをPNGフォーマットに変換中..."
    TEMP_PNG="app-icon-converted.png"
    sips -s format png "$SOURCE_IMAGE" --out "$TEMP_PNG" > /dev/null 2>&1
    if [ -f "$TEMP_PNG" ]; then
        SOURCE_IMAGE="$TEMP_PNG"
        echo "✅ PNGに変換しました: $SOURCE_IMAGE"
    else
        echo "❌ PNGへの変換に失敗しました"
        exit 1
    fi
fi

echo ""

# macOSで実行されているか確認
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  警告: このスクリプトはmacOSで実行してください"
    echo "   アイコンはビルドに追加されますが、.icns変換にはmacOSが必要です"
    echo ""
    echo "📋 macOSで.icnsを作成するには:"
    echo "   1. AppIcon.iconsetディレクトリを作成"
    echo "   2. sipsで必要なサイズを生成:"
    echo "      sips -z 16 16     $SOURCE_IMAGE --out AppIcon.iconset/icon_16x16.png"
    echo "      sips -z 32 32     $SOURCE_IMAGE --out AppIcon.iconset/icon_16x16@2x.png"
    echo "      sips -z 32 32     $SOURCE_IMAGE --out AppIcon.iconset/icon_32x32.png"
    echo "      sips -z 64 64     $SOURCE_IMAGE --out AppIcon.iconset/icon_32x32@2x.png"
    echo "      sips -z 128 128   $SOURCE_IMAGE --out AppIcon.iconset/icon_128x128.png"
    echo "      sips -z 256 256   $SOURCE_IMAGE --out AppIcon.iconset/icon_128x128@2x.png"
    echo "      sips -z 256 256   $SOURCE_IMAGE --out AppIcon.iconset/icon_256x256.png"
    echo "      sips -z 512 512   $SOURCE_IMAGE --out AppIcon.iconset/icon_256x256@2x.png"
    echo "      sips -z 512 512   $SOURCE_IMAGE --out AppIcon.iconset/icon_512x512.png"
    echo "      sips -z 1024 1024 $SOURCE_IMAGE --out AppIcon.iconset/icon_512x512@2x.png"
    echo "   3. .icnsに変換:"
    echo "      iconutil -c icns AppIcon.iconset"
    echo ""
    exit 0
fi

# iconsetディレクトリを作成
echo "📁 $ICONSET_DIR ディレクトリを作成中..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# 必要な全てのアイコンサイズを生成
echo "🔧 アイコンサイズを生成中..."

# 生成するサイズの配列
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

FAILED=0
for size_info in "${SIZES[@]}"; do
    SIZE="${size_info%%:*}"
    NAME="${size_info##*:}"
    
    if ! sips -z "$SIZE" "$SIZE" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$NAME" > /dev/null 2>&1; then
        echo "⚠️  $NAME の生成に失敗しました"
        FAILED=$((FAILED + 1))
    fi
done

if [ $FAILED -gt 0 ]; then
    echo "❌ $FAILED 個のアイコンサイズの生成に失敗しました"
    echo "🔍 詳細は ./debug-icon.sh を実行してください"
    exit 1
fi

echo "✅ 10個のアイコンサイズを生成しました"

# 全てのファイルが存在し、有効なPNGであることを検証
echo "🔍 生成されたアイコンを検証中..."
for size_info in "${SIZES[@]}"; do
    NAME="${size_info##*:}"
    if [ ! -f "$ICONSET_DIR/$NAME" ]; then
        echo "❌ 見つかりません: $NAME"
        exit 1
    fi
    if ! file "$ICONSET_DIR/$NAME" | grep -q "PNG image data"; then
        echo "❌ 無効なPNG: $NAME"
        exit 1
    fi
done
echo "✅ 全てのアイコンを検証しました"

# .icnsに変換
echo "🎨 .icnsフォーマットに変換中..."
if iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns 2>&1; then
    if [ -f "AppIcon.icns" ]; then
        echo "✅ AppIcon.icnsの作成に成功しました！"
        echo ""
        echo "📦 次のステップ:"
        echo "   1. ./build-app.sh を実行して新しいアイコンでアプリを再ビルド"
        echo "   2. アイコンは自動的にアプリバンドルに含まれます"
        echo ""
        ls -lh AppIcon.icns
        file AppIcon.icns
    else
        echo "❌ AppIcon.icnsの作成に失敗しました（ファイルが見つかりません）"
        echo "🔍 詳細は ./debug-icon.sh を実行してください"
        exit 1
    fi
else
    echo "❌ iconutilコマンドが失敗しました"
    echo "🔍 AppIcon.iconsetの内容を確認中..."
    ls -la "$ICONSET_DIR/"
    echo ""
    echo "💡 考えられる問題:"
    echo "   1. 1つ以上のPNGファイルが破損している可能性があります"
    echo "   2. iconsetでのファイル命名が正しくありません"
    echo "   3. 詳細な診断には ./debug-icon.sh を実行してください"
    exit 1
fi

# iconsetディレクトリをクリーンアップ（オプション）
# rm -rf "$ICONSET_DIR"

# 作成された一時変換PNGをクリーンアップ
if [ -f "app-icon-converted.png" ]; then
    rm -f "app-icon-converted.png"
    echo "🧹 一時ファイルをクリーンアップしました"
fi

echo ""
echo "✨ 完了！"
