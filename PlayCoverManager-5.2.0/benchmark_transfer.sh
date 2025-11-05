#!/bin/zsh
# PlayCover Manager Transfer Method Benchmark

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_result() {
    printf "%-20s: %s\n" "$1" "$2"
}

generate_random_string() {
    # ランダムな16進数文字列を生成（UUIDっぽく）
    local length=${1:-8}
    openssl rand -hex $((length / 2)) 2>/dev/null || echo $(date +%s)$RANDOM
}

generate_dummy_data() {
    local target_dir="$1"
    local num_files="$2"
    local num_dirs="$3"
    
    print_header "ダミーデータ生成中（ランダムアクセスパターン）"
    
    rm -rf "$target_dir" 2>/dev/null
    mkdir -p "$target_dir"
    
    print_result "ディレクトリ数" "$num_dirs"
    print_result "ファイル数" "$num_files"
    print_result "構造" "ランダム階層・ランダム名・ランダムサイズ"
    
    # ランダムなディレクトリ構造を作成（1-3階層のネスト）
    local -a dir_paths
    for i in {1..$num_dirs}; do
        local depth=$((RANDOM % 3 + 1))  # 1-3階層
        local dir_path="$target_dir"
        
        for d in {1..$depth}; do
            local rand_name=$(generate_random_string 8)
            dir_path="$dir_path/$rand_name"
        done
        
        mkdir -p "$dir_path" 2>/dev/null
        dir_paths+=($dir_path)
        
        # 進捗表示
        if (( i % 50 == 0 )); then
            echo -n "."
        fi
    done
    echo " ディレクトリ作成完了"
    
    # ファイルをランダムなディレクトリに配置
    local generated=0
    for i in {1..$num_files}; do
        # ランダムなディレクトリを選択
        local random_idx=$((RANDOM % ${#dir_paths[@]} + 1))
        local target_subdir="${dir_paths[$random_idx]}"
        
        # ランダムなファイル名とサイズ
        local filename="$(generate_random_string 12).dat"
        local size=$((RANDOM % 50 + 1))  # 1KB-50KB（よりバラつきを持たせる）
        
        # 10%の確率で大きいファイル（100KB-500KB）
        if (( RANDOM % 10 == 0 )); then
            size=$((RANDOM % 400 + 100))
        fi
        
        dd if=/dev/urandom of="$target_subdir/$filename" bs=1024 count=$size 2>/dev/null
        generated=$((generated + 1))
        
        # 進捗表示
        if (( generated % 200 == 0 )); then
            echo -n "."
        fi
    done
    echo " ファイル生成完了"
    
    # 統計情報を表示
    local total_size=$(du -sh "$target_dir" 2>/dev/null | awk '{print $1}')
    local actual_files=$(find "$target_dir" -type f | wc -l | xargs)
    local actual_dirs=$(find "$target_dir" -type d | wc -l | xargs)
    
    print_result "実際のディレクトリ数" "$actual_dirs"
    print_result "実際のファイル数" "$actual_files"
    print_result "総サイズ" "$total_size"
    echo ""
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [--generate-dummy <num_files> <num_dirs>] <source_dir> <dest_base_dir>"
    echo ""
    echo "Options:"
    echo "  --generate-dummy <num_files> <num_dirs>  ダミーデータを生成"
    echo ""
    echo "Examples:"
    echo "  $0 --generate-dummy 5000 100 /tmp/benchmark_source /tmp/benchmark_dest"
    echo "  $0 /existing/source /tmp/benchmark_dest"
    exit 1
fi

GENERATE_DUMMY=false
if [[ "$1" == "--generate-dummy" ]]; then
    GENERATE_DUMMY=true
    NUM_FILES="$2"
    NUM_DIRS="$3"
    SOURCE_DIR="$4"
    DEST_BASE="$5"
    
    if [[ -z "$NUM_FILES" || -z "$NUM_DIRS" || -z "$SOURCE_DIR" || -z "$DEST_BASE" ]]; then
        echo "Error: --generate-dummy requires <num_files> <num_dirs> <source_dir> <dest_base_dir>"
        exit 1
    fi
    
    generate_dummy_data "$SOURCE_DIR" "$NUM_FILES" "$NUM_DIRS"
else
    SOURCE_DIR="$1"
    DEST_BASE="$2"
    
    if [[ -z "$DEST_BASE" ]]; then
        echo "Error: dest_base_dir is required"
        exit 1
    fi
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Clean dest
if [[ -d "$DEST_BASE" ]]; then
    echo "既存のベンチマークディレクトリを削除中..."
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
fi
mkdir -p "$DEST_BASE"

# Count files
print_header "ソースディレクトリ分析"
FILE_COUNT=$(find "$SOURCE_DIR" -type f \
    ! -path "*/.DS_Store" \
    ! -path "*/.Spotlight-V100/*" \
    ! -path "*/.fseventsd/*" \
    ! -path "*/.Trashes/*" \
    ! -path "*/.TemporaryItems/*" \
    2>/dev/null | wc -l | xargs)
SOURCE_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')
print_result "ファイル数" "$FILE_COUNT"
print_result "データサイズ" "$SOURCE_SIZE"

declare -A results
declare -A file_counts
methods=("rsync" "cp" "ditto" "parallel_split")

for method in "${methods[@]}"; do
    dest_dir="$DEST_BASE/test_$method"
    
    print_header "テスト: $method"
    
    rm -rf "$dest_dir" 2>/dev/null || sudo rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    
    echo "転送開始..."
    start_time=$(date +%s)
    
    case "$method" in
        "rsync")
            /usr/bin/rsync -aH --quiet \
                --exclude='.DS_Store' \
                --exclude='.Spotlight-V100' \
                --exclude='.fseventsd' \
                --exclude='.Trashes' \
                --exclude='.TemporaryItems' \
                "$SOURCE_DIR/" "$dest_dir/"
            ;;
        
        "cp")
            # オリジナルのシンプルなcp実装（commit 064e54eから）
            /usr/bin/sudo cp -av "$SOURCE_DIR/" "$dest_dir/" 2>&1 | while IFS= read -r line; do
                # 進捗表示（100行に1回ドットを表示）
                if (( RANDOM % 100 == 0 )); then
                    echo -n "."
                fi
            done
            echo ""  # 改行
            ;;
            
        "ditto")
            # dittoは特殊ファイルも含めてコピーするのでファイル数が多くなる
            /usr/bin/ditto "$SOURCE_DIR/" "$dest_dir/" 2>&1 | grep -i error || true
            ;;
            
        "parallel_split")
            num_workers=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
            echo "並列ワーカー数: $num_workers"
            
            # Create file list and split into chunks for workers
            temp_list="/tmp/benchmark_list_$$.txt"
            find "$SOURCE_DIR" -type f \
                ! -path "*/.DS_Store" \
                ! -path "*/.Spotlight-V100/*" \
                ! -path "*/.fseventsd/*" \
                ! -path "*/.Trashes/*" \
                ! -path "*/.TemporaryItems/*" \
                2>/dev/null > "$temp_list"
            
            total_files=$(wc -l < "$temp_list" | xargs)
            files_per_worker=$(( (total_files + num_workers - 1) / num_workers ))
            
            # Split file list and process in parallel
            split -l "$files_per_worker" "$temp_list" "/tmp/benchmark_split_$$_"
            
            for split_file in /tmp/benchmark_split_$$_*; do
                (
                    while IFS= read -r src; do
                        rel="${src#$SOURCE_DIR/}"
                        dst="$dest_dir/$rel"
                        dstdir=$(dirname "$dst")
                        mkdir -p "$dstdir" 2>/dev/null && cp -p "$src" "$dst" 2>/dev/null
                    done < "$split_file"
                ) &
            done
            
            # Wait for all workers to complete
            wait
            
            # Cleanup
            rm -f "$temp_list" /tmp/benchmark_split_$$_*
            ;;
    esac
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    # Verify (dittoは特殊ファイルも含むので除外してカウント)
    if [[ "$method" == "ditto" ]]; then
        copied_files=$(find "$dest_dir" -type f \
            ! -path "*/.DS_Store" \
            ! -path "*/.Spotlight-V100/*" \
            ! -path "*/.fseventsd/*" \
            ! -path "*/.Trashes/*" \
            ! -path "*/.TemporaryItems/*" \
            2>/dev/null | wc -l | xargs)
    else
        copied_files=$(find "$dest_dir" -type f 2>/dev/null | wc -l | xargs)
    fi
    
    results[$method]=$elapsed
    file_counts[$method]=$copied_files
    
    print_result "処理時間" "${elapsed}秒"
    print_result "コピーファイル数" "$copied_files / $FILE_COUNT"
    
    if (( copied_files == FILE_COUNT )); then
        echo "✅ 転送成功"
    else
        diff=$((FILE_COUNT - copied_files))
        echo "⚠️  警告: ファイル数が一致しません（差分: $diff）"
    fi
done

# Summary
print_header "ベンチマーク結果サマリー"

echo "転送方法別の処理時間:"
echo ""

for method in "${methods[@]}"; do
    time=${results[$method]}
    files=${file_counts[$method]}
    success_rate=$(( files * 100 / FILE_COUNT ))
    printf "  %-10s: %3d秒 (%d/%d ファイル = %d%%)\n" \
        "$method" "$time" "$files" "$FILE_COUNT" "$success_rate"
done

echo ""

# Find fastest
fastest_method=""
fastest_time=999999
for method in "${methods[@]}"; do
    files=${file_counts[$method]}
    if (( files == FILE_COUNT )); then
        time=${results[$method]}
        if (( time < fastest_time )); then
            fastest_time=$time
            fastest_method=$method
        fi
    fi
done

if [[ -n "$fastest_method" ]]; then
    echo "🏆 最速: $fastest_method (${fastest_time}秒)"
else
    echo "⚠️  完全成功した方法がありません"
fi

# Cleanup
echo ""
if [[ "$GENERATE_DUMMY" == true ]]; then
    read "cleanup?テストデータ（ソース含む）を削除しますか？ (y/n): "
    if [[ "$cleanup" == "y" ]]; then
        echo "クリーンアップ中..."
        rm -rf "$SOURCE_DIR" 2>/dev/null
        rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
        echo "✅ 完了"
    fi
else
    read "cleanup?テストデータを削除しますか？ (y/n): "
    if [[ "$cleanup" == "y" ]]; then
        echo "クリーンアップ中..."
        rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
        echo "✅ 完了"
    fi
fi
