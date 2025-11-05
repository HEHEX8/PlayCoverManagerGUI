#!/bin/bash
#######################################################
# PlayCover Manager - Bash Test Wrapper
# Bash環境でのテスト用ラッパー
#######################################################
#
# このスクリプトは、sandbox環境（bash）でPlayCover Managerを
# テストするためのラッパーです。
#
# 注意: 実際のmacOS環境では main.sh を直接 zsh で実行してください。
#

set -e  # エラーで停止

echo "=========================================="
echo "🧪 PlayCover Manager - Bash Compatibility Test"
echo "=========================================="
echo ""

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📂 Working Directory: $SCRIPT_DIR"
echo "🐚 Shell: bash $BASH_VERSION"
echo ""

# 互換性レイヤーを読み込み
echo "📥 Loading compatibility layer..."
if [[ -f "lib/00_compat.sh" ]]; then
    source "lib/00_compat.sh"
    echo "   ✅ Compatibility layer loaded"
else
    echo "   ❌ lib/00_compat.sh not found"
    exit 1
fi
echo ""

# 構文チェック
echo "🔍 Syntax Check..."
error_count=0
for file in main.sh lib/*.sh; do
    if bash -n "$file" 2>&1 | grep -i "error" >/dev/null; then
        echo "   ❌ $file: 構文エラー"
        bash -n "$file" 2>&1 | head -3
        error_count=$((error_count + 1))
    else
        echo "   ✅ $file"
    fi
done
echo ""

if [[ $error_count -gt 0 ]]; then
    echo "❌ $error_count 個のファイルに構文エラーがあります"
    exit 1
fi

# 関数定義チェック
echo "🎯 Function Definition Check..."
critical_functions=(
    "print_success"
    "print_error"
    "volume_exists"
    "get_volume_device"
)

missing=0
for func in "${critical_functions[@]}"; do
    if grep -q "^${func}() {" lib/*.sh main.sh 2>/dev/null; then
        echo "   ✅ $func"
    else
        echo "   ❌ $func が見つかりません"
        missing=$((missing + 1))
    fi
done
echo ""

if [[ $missing -gt 0 ]]; then
    echo "❌ $missing 個の重要な関数が見つかりません"
    exit 1
fi

# zsh固有の構文をチェック
echo "⚠️  Zsh-specific Syntax Check..."
echo "   以下の構文はbashで動作しない可能性があります:"
echo ""

# ${(@)array} 構文
zsh_array_syntax=$(grep -rn "\${(@" lib/*.sh main.sh 2>/dev/null | wc -l)
echo "   - \${(@)array} 構文: ${zsh_array_syntax}箇所"

# ${(%):-%x} 構文
zsh_script_path=$(grep -rn "\${(%):-%x}" lib/*.sh main.sh 2>/dev/null | wc -l)
echo "   - \${(%):-%x} 構文: ${zsh_script_path}箇所"

# declare -A（連想配列）
assoc_arrays=$(grep -rn "declare -A" lib/*.sh main.sh 2>/dev/null | wc -l)
echo "   - declare -A（連想配列）: ${assoc_arrays}箇所 (bash 4.0+でサポート)"
echo ""

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "❌ Bash 4.0以降が必要です（現在: $BASH_VERSION）"
    exit 1
else
    echo "   ✅ Bash バージョン: $BASH_VERSION (連想配列サポート)"
fi
echo ""

# まとめ
echo "=========================================="
echo "📊 Test Summary"
echo "=========================================="
echo "✅ 構文エラーなし"
echo "✅ 重要な関数が存在"
echo "✅ 互換性レイヤー動作確認"
echo ""
echo "⚠️  注意事項:"
echo "   - zsh固有の構文（\${(@)array}等）が ${zsh_array_syntax} 箇所あります"
echo "   - 本番環境ではzshで実行してください"
echo "   - このテストは構文チェックのみです（実行テストではありません）"
echo ""
echo "=========================================="
