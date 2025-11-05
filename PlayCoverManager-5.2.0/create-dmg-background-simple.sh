#!/bin/bash
#######################################################
# DMG背景画像作成（appdmg用）
# サイズ: 600x400（appdmg推奨サイズ）
#######################################################

set -e

BACKGROUND_FILE="dmg-background.png"
WIDTH=600
HEIGHT=400

echo "🎨 appdmg用の背景画像を作成中..."

# macOSで実行されているか確認
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  このスクリプトはmacOSで実行してください"
    exit 1
fi

# Pythonスクリプトを作成
cat > /tmp/create_bg_appdmg.py << 'PYTHON_EOF'
from PIL import Image, ImageDraw, ImageFont

# 画像サイズ（appdmg推奨: 600x400）
WIDTH = 600
HEIGHT = 400

# アイコン配置（appdmg-config.jsonと同じ）
LEFT_ICON_X = 150
RIGHT_ICON_X = 450
ICON_Y = 200
ICON_SIZE = 128

print(f"📐 画像サイズ: {WIDTH}x{HEIGHT}")
print(f"📍 左アイコン中心: ({LEFT_ICON_X}, {ICON_Y})")
print(f"📍 右アイコン中心: ({RIGHT_ICON_X}, {ICON_Y})")

# ライトグレーの背景
img = Image.new('RGB', (WIDTH, HEIGHT), color=(200, 208, 214))
draw = ImageDraw.Draw(img)

# 矢印を描画（2つのアイコン中心の間）
arrow_center_x = (LEFT_ICON_X + RIGHT_ICON_X) // 2  # = 300
arrow_y = ICON_Y
arrow_length = 120

arrow_start_x = arrow_center_x - arrow_length // 2  # = 240
arrow_end_x = arrow_center_x + arrow_length // 2    # = 360

print(f"➡️  矢印: {arrow_start_x} → {arrow_end_x}, y={arrow_y}")

# 矢印の色
arrow_color = (70, 70, 70)
line_width = 5

# メイン矢印線
for offset in [-2, 0, 2]:
    draw.line(
        [(arrow_start_x, arrow_y + offset), (arrow_end_x - 30, arrow_y + offset)],
        fill=arrow_color,
        width=line_width
    )

# 矢印の先端
arrow_head_size = 20
arrow_head = [
    (arrow_end_x - 35, arrow_y - arrow_head_size),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 35, arrow_y + arrow_head_size)
]
draw.polygon(arrow_head, fill=arrow_color)

# テキストを追加
try:
    font_main = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 20)
    font_sub = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 14)
except:
    try:
        font_main = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 20)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
    except:
        font_main = ImageFont.load_default()
        font_sub = ImageFont.load_default()

# メインテキスト
main_text = "ドラッグ&ドロップでインストール"
bbox = draw.textbbox((0, 0), main_text, font=font_main)
text_width = bbox[2] - bbox[0]
text_x = (WIDTH - text_width) // 2
text_y = ICON_Y + ICON_SIZE // 2 + 60

# テキストに影を追加
shadow_offset = 2
draw.text(
    (text_x + shadow_offset, text_y + shadow_offset),
    main_text,
    fill=(255, 255, 255, 180),
    font=font_main
)
draw.text((text_x, text_y), main_text, fill=(40, 40, 40), font=font_main)

# サブテキスト
sub_text = "左のアプリを右のフォルダへ"
bbox2 = draw.textbbox((0, 0), sub_text, font=font_sub)
sub_width = bbox2[2] - bbox2[0]
sub_x = (WIDTH - sub_width) // 2
sub_y = text_y + 30

draw.text(
    (sub_x + 1, sub_y + 1),
    sub_text,
    fill=(255, 255, 255, 150),
    font=font_sub
)
draw.text((sub_x, sub_y), sub_text, fill=(60, 60, 60), font=font_sub)

# 保存
img.save('dmg-background.png', 'PNG')
print("✅ 背景画像を作成しました: dmg-background.png")

PYTHON_EOF

# Pythonで背景画像を作成
if command -v python3 &> /dev/null; then
    if ! python3 -c "import PIL" 2>/dev/null; then
        echo "📦 Pillow (PIL) をインストール中..."
        python3 -m pip install --user Pillow --quiet || {
            echo "❌ Pillow のインストールに失敗しました"
            exit 1
        }
    fi
    
    python3 /tmp/create_bg_appdmg.py
    if [ -f "dmg-background.png" ]; then
        echo ""
        echo "✅ 背景画像作成完了"
        ls -lh dmg-background.png
        rm /tmp/create_bg_appdmg.py
    else
        echo "❌ 背景画像の作成に失敗しました"
        rm /tmp/create_bg_appdmg.py
        exit 1
    fi
else
    echo "❌ Python3が見つかりません"
    exit 1
fi
