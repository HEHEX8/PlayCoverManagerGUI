#!/bin/zsh
#
# PlayCover Volume Manager - Module 03: Storage Detection & Switching
# ════════════════════════════════════════════════════════════════════
#
# This module provides storage detection and switching capabilities:
# - Container size calculation (human-readable and bytes)
# - Free space calculation for internal/external storage
# - Storage type detection (internal/external/none)
# - Internal storage flag management
# - Storage mode detection (intentional vs contamination)
# - Complete internal ⇄ external switching with data migration
#
# Storage Mode States:
#   - external                    : Data is on mounted external volume
#   - external_wrong_location     : External volume mounted at wrong path
#   - internal_intentional        : Intentionally switched to internal (has flag + data)
#   - internal_intentional_empty  : Intentionally switched to internal (has flag, no data)
#   - internal_contaminated       : Accidentally has internal data (no flag, has data)
#   - none                        : No data exists (empty or unmounted)
#
# Version: 5.0.1
# Part of: Modular Architecture Refactoring

#######################################################
# Container Size Calculation
#######################################################

# Get container size in human-readable format (decimal/1000-based like macOS Finder)
get_container_size() {
    local container_path=$1
    
    if [[ ! -e "$container_path" ]]; then
        echo "0B"
        return
    fi
    
    # Get size in bytes first, then use our bytes_to_human function for consistent decimal units
    local size_kb=$(/usr/bin/du -sk "$container_path" 2>/dev/null | /usr/bin/awk '{print $1}')
    
    if [[ -z "$size_kb" ]] || [[ ! "$size_kb" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi
    
    local size_bytes=$((size_kb * 1024))
    bytes_to_human "$size_bytes"
}

# Get container size with styled formatting (bold number + normal unit)
get_container_size_styled() {
    local container_path=$1
    local size=$(get_container_size "$container_path")
    
    # Extract number and unit using regex
    if [[ "$size" =~ ^([0-9.]+)([A-Za-z]+)$ ]]; then
        local number="${match[1]}"
        local unit="${match[2]}"
        echo "${BOLD}${WHITE}${number}${NC}${LIGHT_GRAY}${unit}${NC}"
    else
        echo "${LIGHT_GRAY}${size}${NC}"
    fi
}

# Get container size in bytes (for capacity comparison)
get_container_size_bytes() {
    local container_path=$1
    
    if [[ ! -e "$container_path" ]]; then
        echo "0"
        return
    fi
    
    # Use get_directory_size for kilobytes, then convert to bytes
    local size_kb=$(get_directory_size "$container_path")
    
    if [[ -z "$size_kb" ]]; then
        echo "0"
    else
        echo $((size_kb * 1024))
    fi
}

#######################################################
# Free Space Calculation
#######################################################

# Get storage free space in bytes (for capacity comparison)
get_storage_free_space_bytes() {
    local target_path="${1:-$HOME}"
    
    # Get free space using df (1K-blocks)
    local free_blocks=$(/bin/df "$target_path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -z "$free_blocks" ]]; then
        echo "0"
    else
        echo $((free_blocks * 1024))
    fi
}

# Get storage free space (APFS volumes share space in same container)
# Uses decimal units (1000-based: KB/MB/GB/TB) like macOS Finder
get_storage_free_space() {
    local target_path="${1:-$HOME}"  # Default to home directory if no path provided
    
    # Get free space in KB, then convert to bytes and use our bytes_to_human function
    local free_kb=$(/bin/df -k "$target_path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -z "$free_kb" ]] || [[ ! "$free_kb" =~ ^[0-9]+$ ]]; then
        echo "不明"
        return
    fi
    
    local free_bytes=$((free_kb * 1024))
    bytes_to_human "$free_bytes"
}

# Get external drive free space using PlayCover volume
get_external_drive_free_space() {
    # Always use PlayCover volume mount point to get external drive free space
    # This is more reliable than checking individual app volumes
    
    # Get PlayCover volume mount point using CACHED data (performance optimization)
    local playcover_mount=$(validate_and_get_mount_point_cached "$PLAYCOVER_VOLUME_NAME")
    local vol_status=$?
    
    if [[ $vol_status -ne 0 ]] || [[ -z "$playcover_mount" ]]; then
        # Volume doesn't exist or not mounted, use home directory space
        get_storage_free_space "$HOME"
        return
    fi
    
    # Get free space from PlayCover volume mount point using df -H
    get_storage_free_space "$playcover_mount"
}

#######################################################
# Storage Type Detection
#######################################################

# CRITICAL FIX (v1.5.12): Renamed 'path' to 'container_path' to avoid zsh conflict
# zsh has a special 'path' array variable that syncs with PATH environment variable
get_storage_type() {
    local container_path=$1
    # Debug parameter removed in stable release
    
    # If path doesn't exist, return unknown
    if [[ ! -e "$container_path" ]]; then
        echo "unknown"
        return
    fi
    
    # CRITICAL: First check if this path is a mount point for an APFS volume
    # This is the most reliable way to detect external storage
    # Use exact match with trailing space to avoid partial matches
    local mount_check=$(/sbin/mount | /usr/bin/grep " on ${container_path} " | /usr/bin/grep "apfs")
    if [[ -n "$mount_check" ]]; then
        # This path is mounted as an APFS volume = external storage
        echo "external"
        return
    fi
    
    # If it's a directory but not a mount point, check if it has content
    if [[ -d "$container_path" ]]; then
        # Ignore macOS metadata files when checking for content
        # Note: Do NOT exclude flag file here - that's handled in get_storage_mode()
        # Use /bin/ls -A1 to ensure one item per line (not multi-column output)
        local content_check=$(/bin/ls -A1 "$container_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
        
        if [[ -z "$content_check" ]]; then
            # Directory exists but is empty (or only has metadata) = no actual data
            # This is just an empty mount point directory left after unmount
            echo "none"
            return
        fi
    fi
    
    # If not a mount point and has content, it's a regular directory on some disk
    # Get the device info for the filesystem containing this path
    local device=$(/bin/df "$container_path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
    local disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    
    # Check the disk location
    local disk_location=$(get_disk_location "/dev/$disk_id")
    
    
    if [[ "$disk_location" == "Internal" ]]; then
        echo "internal"
    elif [[ "$disk_location" == "External" ]]; then
        echo "external"
    else
        # Fallback: check if it's on the main system disk (disk0 or disk1 usually)
        if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
            echo "internal"
        else
            echo "external"
        fi
    fi
}

#######################################################
# Internal Storage Flag Management
#######################################################

# Check if internal storage flag exists
has_internal_storage_flag() {
    local container_path=$1
    
    if [[ -f "${container_path}/${INTERNAL_STORAGE_FLAG}" ]]; then
        return 0  # Flag exists
    else
        return 1  # Flag does not exist
    fi
}

# Create internal storage flag (when switching to internal)
create_internal_storage_flag() {
    local container_path=$1
    local flag_path="${container_path}/${INTERNAL_STORAGE_FLAG}"
    
    # Debug: Check directory permissions before creating flag
    if [[ ! -d "$container_path" ]]; then
        print_error "フラグファイル作成失敗: ディレクトリが存在しません"
        print_info "パス: $container_path"
        return 1
    fi
    
    if [[ ! -w "$container_path" ]]; then
        print_error "フラグファイル作成失敗: ディレクトリに書き込み権限がありません"
        print_info "パス: $container_path"
        print_info "パーミッション: $(ls -ld "$container_path" 2>/dev/null)"
        return 1
    fi
    
    # Create flag file with timestamp
    if ! echo "Switched to internal storage at: $(date)" > "$flag_path" 2>/dev/null; then
        print_error "内蔵ストレージフラグの作成に失敗しました"
        print_info "フラグパス: $flag_path"
        print_info "ディレクトリ情報: $(ls -ld "$container_path" 2>/dev/null)"
        return 1
    fi
    
    return 0
}

# Remove internal storage flag (when switching back to external)
remove_internal_storage_flag() {
    local container_path=$1
    
    if [[ -f "${container_path}/${INTERNAL_STORAGE_FLAG}" ]]; then
        /bin/rm -f "${container_path}/${INTERNAL_STORAGE_FLAG}"
        
        if [[ $? -eq 0 ]]; then
            return 0
        else
            print_error "内蔵ストレージフラグの削除に失敗しました"
            return 1
        fi
    fi
    
    return 0  # Flag doesn't exist, nothing to remove
}

#######################################################
# Storage Mode Detection
#######################################################

# Get storage mode (intentional internal vs contamination)
# Enhanced: Check external volume mount status first to avoid misdetection
get_storage_mode() {
    local container_path=$1
    local volume_name=$2  # Optional: volume name for mount status check
    
    # If volume name is provided, check external volume mount status first
    if [[ -n "$volume_name" ]]; then
        local current_mount=$(validate_and_get_mount_point_cached "$volume_name")
        local vol_status=$?
        
        if [[ $vol_status -eq 0 ]] && [[ -n "$current_mount" ]]; then
            # External volume is mounted somewhere
            # Normalize paths for comparison (remove trailing slashes)
            local normalized_current="${current_mount%/}"
            local normalized_expected="${container_path%/}"
            
            if [[ "$normalized_current" == "$normalized_expected" ]]; then
                echo "external"  # Correctly mounted at target location
            else
                echo "external_wrong_location"  # Mounted at wrong location
            fi
            return 0
        fi
    fi
    
    # External volume not mounted, check internal storage
    local storage_type=$(get_storage_type "$container_path")
    
    case "$storage_type" in
        "external")
            echo "external"
            ;;
        "internal")
            # Check if has actual user data (not just macOS container structure)
            # macOS creates complex container structure with symlinks and empty dirs:
            # - Symlinks to ~/Desktop, ~/Documents, etc.
            # - Empty Library/ subdirectories
            # - .DS_Store files
            # We need to count ACTUAL FILES only (not symlinks, not directories)
            
            # Count real files (excluding system files and our flag):
            local real_file_count=$(/usr/bin/find "$container_path" -type f \
                ! -name '.DS_Store' \
                ! -name '.com.apple.containermanagerd.metadata.plist' \
                ! -name '.CFUserTextEncoding' \
                ! -name 'com.apple.security*.plist' \
                ! -name "${INTERNAL_STORAGE_FLAG}" \
                2>/dev/null | /usr/bin/wc -l | /usr/bin/xargs)
            
            # If no real files exist, container has only structure (no user data)
            if [[ "$real_file_count" -eq 0 ]]; then
                # Only flag file (and/or metadata) exists, no real data
                if has_internal_storage_flag "$container_path"; then
                    # Flag exists = intentional internal mode, but empty
                    echo "internal_intentional_empty"
                else
                    # No flag, no data = truly empty
                    echo "none"
                fi
            elif has_internal_storage_flag "$container_path"; then
                # Has flag + actual data = intentional internal storage
                echo "internal_intentional"
            else
                # Has data but no flag = unintended contamination
                echo "internal_contaminated"
            fi
            ;;
        "none")
            # Directory is empty, but check if flag file exists
            if has_internal_storage_flag "$container_path"; then
                # Flag file exists without data - intentional internal mode (empty)
                echo "internal_intentional_empty"
            else
                echo "none"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

#######################################################
# Migration Helper Functions (Common Operations)
#######################################################

# Check migration capacity and show warnings
# Returns: 0 if sufficient (or user confirms), 1 if insufficient and user cancels
_check_migration_capacity() {
    local source_size_bytes=$1
    local storage_free_bytes=$2
    local direction=$3  # "internal_to_external" or "external_to_internal"
    
    # Calculate required space with 10% safety margin
    local required_bytes=$((source_size_bytes * 110 / 100))
    
    # Convert to human-readable format
    local source_size_human=$(bytes_to_human "$source_size_bytes")
    local available_human=$(bytes_to_human "$storage_free_bytes")
    local required_human=$(bytes_to_human "$required_bytes")
    
    echo ""
    print_info "容量チェック結果:"
    echo "  コピー元サイズ: ${source_size_human}"
    echo "  転送先空き容量: ${available_human}"
    echo "  必要容量（余裕込み）: ${required_human}"
    echo ""
    
    if [[ $storage_free_bytes -lt $required_bytes ]] && [[ $storage_free_bytes -gt 0 ]]; then
        print_error "容量不足: 転送先の空き容量が不足しています"
        echo ""
        local shortage_bytes=$((required_bytes - storage_free_bytes))
        local shortage_human=$(bytes_to_human "$shortage_bytes")
        echo "不足分: ${shortage_human}"
        echo ""
        print_warning "このまま続行すると、転送が不完全になる恐れがあります"
        echo ""
        if ! prompt_confirmation "それでも続行しますか？" "y/N"; then
            print_info "$MSG_CANCELED"
            return 1
        fi
        
        print_warning "容量不足を承知で続行します..."
        echo ""
    else
        print_success "容量チェック: OK（十分な空き容量があります）"
        echo ""
    fi
    
    return 0
}

# Mount volume temporarily for capacity check
# Returns mount point via stdout, exit code 0 on success
_mount_for_capacity_check() {
    local volume_name=$1
    local volume_device=$2
    
    # Check if already mounted
    local existing_mount=$(get_volume_mount_point "$volume_device")
    
    if [[ -n "$existing_mount" ]] && [[ "$existing_mount" != "Not applicable (no file system)" ]]; then
        # Already mounted - return existing mount point
        echo "$existing_mount"
        return 0
    fi
    
    # Not mounted - create temporary mount
    local temp_mount="/tmp/playcover_check_$$"
    /usr/bin/sudo /bin/mkdir -p "$temp_mount"
    
    print_info "外部ボリュームをマウント中..."
    if /usr/bin/sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_mount" 2>/dev/null; then
        print_success "マウント成功"
        echo "$temp_mount"
        return 0
    else
        print_error "外部ボリュームのマウントに失敗しました"
        echo ""
        print_info "デバッグ情報:"
        echo "  デバイス: $volume_device"
        echo "  マウントポイント: $temp_mount"
        cleanup_temp_dir "$temp_mount" true
        return 1
    fi
}

# Perform ditto-based data transfer (macOS native, fastest)
# Returns: 0 on success, 1 on failure
_perform_data_transfer() {
    local source_path=$1
    local dest_path=$2
    local sync_mode=$3  # "sync" or "copy"
    
    _perform_rsync_transfer "$source_path" "$dest_path" "$sync_mode"
}

# Perform rsync-based data transfer with real-time progress bar
# Returns: 0 on success, 1 on failure
_perform_rsync_transfer() {
    local source_path=$1
    local dest_path=$2
    local sync_mode=$3  # "sync" (with --delete) or "copy" (without --delete)
    
    local start_time=$(date +%s)
    
    # Count total files to transfer with spinner
    (/usr/bin/find "$source_path" -type f \
        ! -path "*/.DS_Store" \
        ! -path "*/.Spotlight-V100/*" \
        ! -path "*/.fseventsd/*" \
        ! -path "*/.Trashes/*" \
        ! -path "*/.TemporaryItems/*" \
        2>/dev/null | wc -l > /tmp/file_count_$$ ) &
    local count_pid=$!
    show_spinner "転送ファイル数をカウント中" $count_pid
    wait $count_pid
    local total_files=$(cat /tmp/file_count_$$ | /usr/bin/xargs)
    /bin/rm -f /tmp/file_count_$$
    
    if (( total_files == 0 )); then
        print_warning "転送するファイルがありません"
        return 0
    fi
    
    print_info "転送ファイル数: ${total_files}"
    
    if [[ "$sync_mode" == "sync" ]]; then
        print_info "💡 同期モード: 削除されたファイルも反映、同一ファイルはスキップ"
    fi
    
    # Use macOS built-in rsync without --info=progress2 (not supported)
    local rsync_opts="-a"  # Archive mode: recursive, preserve permissions, times, etc.
    local exclude_opts="--exclude='.Spotlight-V100' --exclude='.fseventsd' --exclude='.Trashes' --exclude='.TemporaryItems' --exclude='.DS_Store' --exclude='.playcover_backup_*'"
    
    if [[ "$sync_mode" == "sync" ]]; then
        rsync_opts="$rsync_opts --delete"
    fi
    
    # Run rsync in background and monitor progress with custom implementation
    local rsync_pid=""
    local rsync_output="/tmp/rsync_output_$$"
    
    (eval "/usr/bin/sudo /usr/bin/rsync $rsync_opts $exclude_opts \"$source_path/\" \"$dest_path/\"" > "$rsync_output" 2>&1) &
    rsync_pid=$!
    
    # Monitor progress using generic progress bar
    local initial_count=$(/usr/bin/find "$dest_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    
    echo ""  # New line before progress bar
    
    # Monitor progress while rsync is running
    local copied=$(monitor_file_progress "$dest_path" "$total_files" "$initial_count" "$start_time" "$rsync_pid" 0.2)
    
    # Wait for rsync to finish and get exit code
    wait $rsync_pid
    local rsync_exit=$?
    
    # Get final count
    local final_count=$(/usr/bin/find "$dest_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    copied=$((final_count - initial_count))
    
    # Clear progress line and add newline
    clear_progress_bar
    
    # Clean up output file
    /bin/rm -f "$rsync_output"
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    # Check rsync exit code (0, 23, 24 are acceptable)
    if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
        print_success "データのコピーが完了しました"
        
        local copied_size=$(get_container_size "$dest_path")
        print_info "  コピー完了: ${final_count} ファイル (${copied_size})"
        print_info "  処理時間: ${elapsed}秒"
        echo ""
        return 0
    else
        print_error "データのコピーに失敗しました"
        echo ""
        return 1
    fi
}

# Handle empty volume switching (no data to transfer)
# Returns: 0 on success, 1 on failure
_handle_empty_internal_to_external() {
    local volume_name=$1
    local bundle_id=$2
    local target_path=$3
    
    print_info "空のボリューム検出: 実データなし（フラグファイルのみ）"
    print_info "内蔵ストレージをクリーンアップして外部ボリュームをマウントします"
    echo ""
    
    # Check if external volume is mounted at wrong location
    local current_mount=$(get_mount_point "$volume_name")
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "$target_path" ]]; then
        print_info "外部ボリュームが誤った位置にマウントされています: ${current_mount}"
        print_info "正しい位置に再マウントするため、一度アンマウントします"
        unmount_app_volume "$volume_name" "$bundle_id" || true
        /bin/sleep 1
    fi
    
    # Remove internal flag and directory
    remove_internal_storage_flag "$target_path"
    /usr/bin/sudo /bin/rm -rf "$target_path"
    
    # Mount to correct location
    print_info "外部ボリュームを正しい位置にマウント中..."
    if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
        echo ""
        print_success "外部ストレージへの切り替えが完了しました"
        print_info "保存場所: ${target_path}"
        remove_internal_storage_flag "$target_path"
        return 0
    else
        print_error "$MSG_MOUNT_FAILED"
        return 1
    fi
}

# Handle empty external to internal switching
_handle_empty_external_to_internal() {
    local volume_name=$1
    local bundle_id=$2
    local target_path=$3
    
    print_warning "外部ボリュームが空です（0バイト）"
    print_info "空のデータを内蔵ストレージにコピーします"
    echo ""
    
    # Unmount external volume first
    print_info "外部ボリュームをアンマウント中..."
    if ! unmount_app_volume "$volume_name" "$bundle_id"; then
        print_error "外部ボリュームのアンマウントに失敗しました"
        print_info "手動でアンマウントしてから、再度ストレージ切替を実行してください"
        return 1
    fi
    
    # Remove existing mount point directory
    if [[ -e "$target_path" ]]; then
        print_info "既存のマウントポイントをクリーンアップ中..."
        /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null || true
    fi
    
    # Create empty internal directory
    /usr/bin/sudo /bin/mkdir -p "$target_path"
    
    # Change ownership
    if ! /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"; then
        print_error "ディレクトリの所有権変更に失敗しました"
        return 1
    fi
    
    echo ""
    print_success "内蔵ストレージへの切り替えが完了しました（空ディレクトリ作成）"
    print_info "保存場所: ${target_path}"
    
    # Create internal storage flag
    local flag_path="${target_path}/${INTERNAL_STORAGE_FLAG}"
    if /usr/bin/sudo /bin/bash -c "echo 'Switched to internal storage at: $(date)' > '$flag_path'"; then
        /usr/bin/sudo /usr/sbin/chown $(id -u):$(id -g) "$flag_path"
        print_info "内蔵ストレージモードフラグを作成しました"
    else
        print_warning "内蔵ストレージフラグの作成に失敗しました"
    fi
    
    return 0
}

# Show migration success message
_show_migration_success() {
    local storage_type=$1  # "internal" or "external"
    local target_path=$2
    
    echo ""
    print_success "ストレージ切り替えが完了しました"
    
    if [[ "$storage_type" == "external" ]]; then
        print_info "外部ストレージモードに切り替わりました"
    else
        print_info "内蔵ストレージモードに切り替わりました"
    fi
    
    print_info "保存場所: ${target_path}"
}

# Cleanup and unmount after migration
_cleanup_and_unmount() {
    local mount_point=$1
    local is_temp_mount=$2  # "true" or "false"
    local volume_name=$3
    local bundle_id=$4
    
    if [[ "$is_temp_mount" == "true" ]]; then
        print_info "一時マウントをクリーンアップ中..."
        unmount_with_fallback "$mount_point" "silent" "$volume_name" || true
        /bin/sleep 1
        cleanup_temp_dir "$mount_point" true
        return 0
    else
        print_info "外部ボリュームをアンマウント中..."
        if ! unmount_app_volume "$volume_name" "$bundle_id"; then
            print_error "外部ボリュームのアンマウントに失敗しました"
            print_warning "ボリュームがまだマウントされている可能性があります"
            print_info "手動でアンマウントしてください"
            return 1
        fi
        return 0
    fi
}

#######################################################
# Storage Switching Functions
#######################################################

switch_storage_location() {
    while true; do
        clear
        print_header "ストレージ切替（内蔵⇄外部）"
        
        # Preload all volume information into cache for fast display
        preload_all_volume_cache
        
        local mappings_content=$(read_mappings)
        
        if [[ -z "$mappings_content" ]]; then
            show_error_and_return "ストレージ切替（内蔵⇄外部）" "$MSG_NO_REGISTERED_VOLUMES"
            return
        fi
        
        # Display volume list with storage type and mount status
        echo "${BOLD}データ位置情報${NC}"
        echo ""
        
        declare -a mappings_array=()
        local index=1
        while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
            if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
                continue
            fi
            
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            
            # Check actual mount status using cached data
            local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
            local vol_status=$?
            
            # Skip only non-existent volumes
            if [[ $vol_status -eq 1 ]]; then
                # Skip apps with non-existent volumes
                continue
            fi
            
            # Check storage mode after mount status check
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
            
            # Add to selectable array only if it has data
            mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
            
            local container_size=$(get_container_size "$target_path")
            local free_space=""
            local location_text=""
            local usage_text=""
            
            if [[ $vol_status -eq 0 ]] && [[ -n "$actual_mount" ]]; then
                # Volume is mounted somewhere
                if [[ "$actual_mount" == "$target_path" ]]; then
                    # Correctly mounted = external storage mode
                    location_text="${BOLD}${BLUE}⚡ 外部ストレージモード${NC}"
                    free_space=$(get_external_drive_free_space "$volume_name")
                    usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                else
                    # Mounted at wrong location
                    location_text="${BOLD}${ORANGE}⚠️  マウント位置異常（外部）${NC}"
                    free_space=$(get_external_drive_free_space "$volume_name")
                    usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}|${NC} ${ORANGE}誤ったマウント位置:${NC} ${DIM_GRAY}${actual_mount}${NC}"
                fi
            elif [[ $vol_status -eq 2 ]]; then
                # Volume exists but not mounted
                case "$storage_mode" in
                    "internal_intentional")
                        location_text="${BOLD}${GREEN}🍎 内蔵ストレージモード${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "internal_intentional_empty")
                        location_text="${BOLD}${GREEN}🍎 内蔵ストレージモード (空)${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${GRAY}0B${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "internal_contaminated")
                        location_text="${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${GRAY}内蔵ストレージ残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "none")
                        # Volume exists but unmounted, no internal data
                        location_text="${BOLD}${GRAY}💤 未マウント${NC}"
                        usage_text="${GRAY}外部ボリュームはマウントされていません${NC}"
                        ;;
                esac
            else
                # Volume not mounted or mount point empty - check internal storage
                case "$storage_mode" in
                    "internal_intentional")
                        location_text="${BOLD}${GREEN}🍎 内蔵ストレージモード${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "internal_intentional_empty")
                        location_text="${BOLD}${GREEN}🍎 内蔵ストレージモード (空)${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${GRAY}0B${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "internal_contaminated")
                        location_text="${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
                        free_space=$(get_storage_free_space "$HOME")
                        usage_text="${GRAY}内蔵ストレージ残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                        ;;
                    "none")
                        # Volume not mounted, no internal data
                        location_text="${BOLD}${ORANGE}💤 外部ボリューム（未マウント）${NC}"
                        usage_text="${GRAY}マウントが必要です${NC}"
                        ;;
                    *)
                        # Unknown state
                        location_text="${BOLD}${RED}？ 不明${NC}"
                        usage_text="${GRAY}状態を確認してください${NC}"
                        ;;
                esac
            fi
            
            # Display formatted output
            echo "  ${BOLD}${CYAN}${index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
            echo "      ${GRAY}位置:${NC} ${location_text}"
            echo "      ${GRAY}使用容量:${NC} ${usage_text}"
            echo ""
            ((index++))
        done <<< "$mappings_content"
        
        print_separator
        echo ""
        echo "${BOLD}${UNDERLINE}切り替えるアプリを選択してください${NC}"
        echo "  ${BOLD}${CYAN}1-${#mappings_array}.${NC} データ位置切替"
        echo "  ${BOLD}${LIGHT_GRAY}0.${NC} 戻る  ${BOLD}${LIGHT_GRAY}q.${NC} 終了"
        echo ""
        echo "${DIM_GRAY}※ Enterキーのみ: 状態を再取得${NC}"
        echo ""
        echo -n "${BOLD}${YELLOW}選択:${NC} "
        read choice
        
        # Empty Enter - refresh cache and redisplay menu
        if [[ -z "$choice" ]]; then
            refresh_all_volume_caches
            continue
        fi
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
            clear
            osascript -e 'tell application "Terminal" to close first window' & exit 0
        fi
        
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array} ]]; then
            print_error "$MSG_INVALID_SELECTION"
            /bin/sleep 2
            continue
        fi
        
        # zsh arrays are 1-indexed, so choice can be used directly
        local selected_mapping="${mappings_array[$choice]}"
        IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
        
        echo ""
        print_header "${display_name} のストレージ切替"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        
        # Check volume mount status first
        local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
        local vol_status=$?
        
        # Check current storage mode (enhanced with external volume mount check)
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        
        # Handle unmounted external volume (except intentional internal modes)
        if [[ $vol_status -eq 2 ]] && [[ "$storage_mode" != "internal_intentional" ]] && [[ "$storage_mode" != "internal_intentional_empty" ]]; then
            clear
            print_header "${display_name} のストレージ切替"
            echo ""
            print_error "外部ボリュームがマウントされていません"
            echo ""
            echo "${BOLD}推奨される操作:${NC}"
            echo "  ${LIGHT_GREEN}1.${NC} ボリューム管理 → 個別ボリューム操作 → マウント"
            echo "  ${LIGHT_GREEN}2.${NC} または、ボリューム管理 → 全ボリュームをマウント"
            echo ""
            if prompt_confirmation "ボリューム管理画面を開きますか？" "y/N"; then
                individual_volume_control
            fi
            continue
        fi
        
        # Handle external volume mounted at wrong location
        if [[ "$storage_mode" == "external_wrong_location" ]]; then
            clear
            print_header "${display_name} のストレージ切替"
            echo ""
            print_error "外部ボリュームが誤った位置にマウントされています"
            echo ""
            local current_mount=$(validate_and_get_mount_point_cached "$volume_name")
            echo "${BOLD}現在のマウント位置:${NC}"
            echo "  ${DIM_GRAY}${current_mount}${NC}"
            echo ""
            echo "${BOLD}正しいマウント位置:${NC}"
            echo "  ${DIM_GRAY}${target_path}${NC}"
            echo ""
            print_info "ストレージ切替を実行する前に、正しい位置に再マウントしてください"
            echo ""
            echo "${BOLD}推奨される操作:${NC}"
            echo "  ${LIGHT_GREEN}1.${NC} ボリューム管理 → 個別ボリューム操作 → 再マウント"
            echo "  ${LIGHT_GREEN}2.${NC} または、全ボリュームをマウント（自動修正）"
            echo ""
            wait_for_enter
            continue
        fi
        
        # Convert storage_mode to legacy storage_type for compatibility
        local current_storage="unknown"
        case "$storage_mode" in
            "external")
                current_storage="external"
                ;;
            "internal_intentional"|"internal_intentional_empty"|"internal_contaminated")
                current_storage="internal"
                ;;
            "none")
                current_storage="none"
                ;;
        esac
        
        # Get current size (both human-readable and bytes)
        local current_size=$(get_container_size "$target_path")
        local current_size_bytes=$(get_container_size_bytes "$target_path")
        
        echo "${BOLD}${UNDERLINE}${CYAN}現在のデータ位置${NC}"
        case "$current_storage" in
            "internal")
                local internal_free=$(get_storage_free_space "$HOME")
                echo "  ${BOLD}🍎 ${CYAN}内蔵ストレージ${NC}"
                echo "     ${LIGHT_GRAY}使用容量:${NC} $(get_container_size_styled "$target_path") ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${internal_free}${NC}"
                ;;
            "external")
                local external_free=$(get_external_drive_free_space "$volume_name")
                echo "  ${BOLD}⚡ ${CYAN}外部ストレージ${NC}"
                echo "     ${LIGHT_GRAY}使用容量:${NC} $(get_container_size_styled "$target_path") ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${external_free}${NC}"
                ;;
            *)
                echo "  ${GRAY}❓ 不明 / データなし${NC}"
                ;;
        esac
        echo ""
        
        # Determine target action and show appropriate free space
        local action=""
        local storage_free=""
        local storage_free_bytes=0
        local storage_location=""
        
        case "$current_storage" in
            "internal")
                action="external"
                # Moving to external - show external drive free space for the target volume
                storage_free=$(get_external_drive_free_space "$volume_name")
                storage_location="外部ドライブ"
                
                # Get mount point of the target app volume (not PlayCover volume) to check capacity
                local volume_mount=$(get_mount_point_cached "$volume_name")
                if [[ -n "$volume_mount" ]]; then
                    # Target volume is mounted, get its free space
                    storage_free_bytes=$(get_storage_free_space_bytes "$volume_mount")
                else
                    # Volume not mounted, assume sufficient space (will be verified during actual operation)
                    # Set to a large value to skip capacity warning
                    storage_free_bytes=999999999999
                fi
                
                echo "${BOLD}${UNDERLINE}${CYAN}実行する操作:${NC} ${BOLD}${GREEN}🍎内蔵${NC} ${BOLD}${YELLOW}→${NC} ${BOLD}${BLUE}⚡外部${NC} ${LIGHT_GRAY}へ移動${NC}"
                echo "  ${BOLD}⚡${CYAN}外部ストレージ残容量:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
                ;;
            "external")
                action="internal"
                # Moving to internal - show internal drive free space
                storage_free=$(get_storage_free_space "$HOME")
                storage_location="内蔵ドライブ"
                storage_free_bytes=$(get_storage_free_space_bytes "$HOME")
                
                echo "${BOLD}${UNDERLINE}${CYAN}実行する操作:${NC} ${BOLD}${BLUE}⚡外部${NC} ${BOLD}${YELLOW}→${NC} ${BOLD}${GREEN}🍎内蔵${NC} ${LIGHT_GRAY}へ移動${NC}"
                echo "  ${BOLD}🍎${CYAN}内蔵ストレージ残容量:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
                ;;
            "none")
                print_error "ストレージ切り替えを実行できません"
                echo ""
                echo "理由: データが存在しません（未マウント）"
                echo ""
                echo "推奨される操作:"
                echo "  ${LIGHT_GREEN}1.${NC} メインメニューのオプション3で外部ボリュームをマウント"
                echo "  ${LIGHT_GREEN}2.${NC} その後、このストレージ切り替え機能を使用"
                wait_for_enter
                continue
                ;;
            *)
                print_error "現在のストレージ状態を判定できません"
                echo ""
                echo "考えられる原因:"
                echo "  - アプリがまだインストールされていない"
                echo "  - データディレクトリが存在しない"
                wait_for_enter
                continue
                ;;
        esac
        
        # Check if there's enough space (with 10% safety margin)
        local required_bytes=$((current_size_bytes + current_size_bytes / 10))
        if [[ $storage_free_bytes -lt $required_bytes ]] && [[ $storage_free_bytes -gt 0 ]]; then
            echo ""
            echo "${BOLD}${RED}════════════════════════════════════════════════════${NC}"
            print_error "警告: 移行先の容量が不足している可能性があります"
            echo "${BOLD}${RED}════════════════════════════════════════════════════${NC}"
            echo ""
            echo "  ${LIGHT_GRAY}必要容量:${NC} ${BOLD}${WHITE}${current_size}${NC} ${LIGHT_GRAY}+ 10% 安全余裕${NC}"
            echo "  ${LIGHT_GRAY}利用可能:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
            echo ""
            echo "${BOLD}${RED}⚠️  続行するとデータ破損のリスクがあります${NC}"
        fi
        
        echo ""
        print_warning "この操作には時間がかかる場合があります"
        echo ""
        
        if ! prompt_confirmation "${BOLD}${YELLOW}続行しますか？${NC}" "Y"; then
            print_info "$MSG_CANCELED"
            wait_for_enter "Enterキーで続行..."
            continue
        fi
        
        # Authenticate sudo only when actually needed (before mount/copy operations)
        authenticate_sudo
        
        echo ""
        
        if [[ "$action" == "external" ]]; then
            # ═══════════════════════════════════════════════════════
            # Internal -> External Migration
            # ═══════════════════════════════════════════════════════
            perform_internal_to_external_migration "$volume_name" "$bundle_id" "$display_name" "$target_path"
        else
            # ═══════════════════════════════════════════════════════
            # External -> Internal Migration
            # ═══════════════════════════════════════════════════════
            perform_external_to_internal_migration "$volume_name" "$bundle_id" "$display_name" "$target_path"
        fi
        
        wait_for_enter
    done  # End of while true loop
}

#######################################################
# Migration Helper Functions
#######################################################

# Internal -> External migration logic
# This is extracted to improve readability and maintainability
perform_internal_to_external_migration() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    local target_path=$4
    
    print_info "内蔵から外部ストレージへデータを移行中..."
    
    # Get volume device early (validates existence and gets device in one call)
    local volume_device=$(validate_and_get_device "$volume_name")
    if [[ $? -ne 0 ]] || [[ -z "$volume_device" ]]; then
        show_error_and_return "${display_name} のストレージ切替" "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    # Determine correct source path
    local source_path="$target_path"
    
    # Validate source path exists
    if [[ ! -d "$source_path" ]]; then
        print_error "コピー元が存在しません: $source_path"
        return 1
    fi
    
    # Check container structure
    if [[ -d "$source_path/Data" ]] && [[ -f "$source_path/.com.apple.containermanagerd.metadata.plist" ]]; then
        # Normal container structure - use as-is
        print_info "内蔵ストレージからコピーします: $source_path"
    else
        # Check for empty source (only flag file exists)
        local content_check=$(/bin/ls -A1 "$source_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist' | /usr/bin/grep -v -x -F "${INTERNAL_STORAGE_FLAG}")
        
        if [[ -z "$content_check" ]]; then
            # Use helper function for empty volume handling
            _handle_empty_internal_to_external "$volume_name" "$bundle_id" "$target_path"
            return $?
        fi
    fi
    
    # Check disk space before migration
    print_info "転送前の容量チェック中..."
    local source_size_bytes=$(get_container_size_bytes "$source_path")
    
    # Special handling for empty source (0 bytes)
    if [[ -z "$source_size_bytes" ]] || [[ "$source_size_bytes" -eq 0 ]]; then
        print_warning "コピー元が空です（0バイト）"
        print_info "空のディレクトリを外部ボリュームにマウントします"
        echo ""
        
        /usr/bin/sudo /bin/rm -rf "$target_path"
        
        print_info "外部ボリュームをマウント中..."
        if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
            echo ""
            print_success "外部ストレージへの切り替えが完了しました"
            print_info "保存場所: ${target_path}"
            remove_internal_storage_flag "$target_path"
            return 0
        else
            print_error "$MSG_MOUNT_FAILED"
            return 1
        fi
    fi
    
    # Volume device was already retrieved at function start (line 873)
    print_info "外部ボリューム: $volume_device"
    
    # Mount for capacity check
    local check_mount=$(_mount_for_capacity_check "$volume_name" "$volume_device")
    local mount_result=$?
    
    if [[ $mount_result -ne 0 ]]; then
        return 1
    fi
    
    # Get available space
    local available_kb=$(get_available_space "$check_mount")
    local available_bytes=$((available_kb * 1024))
    
    # Unmount after check
    if [[ "$check_mount" == /tmp/playcover_check_* ]]; then
        unmount_volume "$check_mount" "silent"
        /bin/sleep 1
        cleanup_temp_dir "$check_mount" true
    fi
    
    # Perform capacity check
    if ! _check_migration_capacity "$source_size_bytes" "$available_bytes" "internal_to_external"; then
        return 1
    fi
    
    # Unmount if already mounted
    local current_mount=$(get_mount_point "$volume_name")
    if [[ -n "$current_mount" ]]; then
        print_info "既存のマウントをアンマウント中..."
        unmount_app_volume "$volume_name" "$bundle_id" || true
        /bin/sleep 1
    fi
    
    # Create temporary mount point
    local temp_mount="/tmp/playcover_temp_$$"
    /usr/bin/sudo /bin/mkdir -p "$temp_mount"
    
    # Mount volume temporarily (with nobrowse to hide from Finder)
    local volume_device=$(get_volume_device "$volume_name")
    print_info "ボリュームを一時マウント中..."
    if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
        print_error "$MSG_MOUNT_FAILED"
        cleanup_temp_dir "$temp_mount" true
        return 1
    fi
    
    # Debug: Show source path and content
    print_info "コピー元: ${source_path}"
    local file_count=$(/usr/bin/find "$source_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    local total_size=$(get_container_size "$source_path")
    print_info "  ファイル数: ${file_count}"
    print_info "  データサイズ: ${total_size}"
    
    # Copy data from internal to external
    if ! _perform_data_transfer "$source_path" "$temp_mount" "sync"; then
        unmount_with_fallback "$temp_mount" "silent" "$volume_name" || true
        /bin/sleep 1
        cleanup_temp_dir "$temp_mount" true
        return 1
    fi
    
    # Unmount temporary mount
    print_info "一時マウントをアンマウント中..."
    unmount_with_fallback "$temp_mount" "verbose" "$volume_name"
    /bin/sleep 1  # Wait for unmount to complete
    cleanup_temp_dir "$temp_mount" true
    
    # Delete internal data completely (no backup needed)
    print_info "内蔵データを完全削除中..."
    /usr/bin/sudo /bin/rm -rf "$target_path"
    
    # Ensure directory is completely gone before mounting
    # This prevents macOS from auto-creating container structure
    if [[ -d "$target_path" ]]; then
        print_warning "ディレクトリが残っています、再削除を試みます..."
        /usr/bin/sudo /bin/rm -rf "$target_path"
        /bin/sleep 0.5
    fi
    
    # Mount volume to proper location
    print_info "ボリュームを正式にマウント中..."
    if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
        _show_migration_success "external" "$target_path"
        
        # Verify mount success and no leftover internal data
        if /sbin/mount | grep -q " on ${target_path} "; then
            print_success "マウント検証: OK"
        else
            print_warning "マウント検証: 警告 - マウント状態を確認できません"
        fi
        
        echo ""
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "${YELLOW}📊 容量表示について${NC}"
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "${ORANGE}⚠️  内蔵ストレージの使用容量が増えて見える場合:${NC}"
        echo ""
        echo "${WHITE}原因1: ${GRAY}APFSの仕様により論理サイズが重複カウント${NC}"
        echo "${WHITE}原因2: ${GRAY}Time MachineのAPFSスナップショットが容量を保持${NC}"
        echo ""
        echo "${GREEN}✅ 外部ボリューム使用により内蔵ストレージは節約されています${NC}"
        echo ""
        echo "${YELLOW}💡 容量が解放されない場合の対処法:${NC}"
        echo "   ${SKY_BLUE}メインメニュー → [6] システムメンテナンス${NC}"
        echo "   ${GRAY}→ APFSスナップショットの削除で容量を回復できます${NC}"
        echo ""
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Explicitly remove internal storage flag to prevent false lock status
        # This is critical because mount_volume creates the directory,
        # and any remaining flag file would cause misdetection
        remove_internal_storage_flag "$target_path"
    else
        print_error "$MSG_MOUNT_FAILED"
        
        # Cleanup any leftover directory created by failed mount
        if [[ -d "$target_path" ]]; then
            print_info "失敗したマウントのクリーンアップ中..."
            /usr/bin/sudo /bin/rm -rf "$target_path"
        fi
    fi
    
    return 0
}

# External -> Internal migration logic
perform_external_to_internal_migration() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    local target_path=$4
    
    print_info "外部から内蔵ストレージへデータを移行中..."
    
    # Get volume info early (validates existence and gets device + mount in one call)
    local vol_info=$(get_volume_info "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        show_error_and_return "${display_name} のストレージ切替" "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    local volume_device="${vol_info%%|*}"
    local current_mount="${vol_info#*|}"
    
    # Check if app is running before migration
    if is_app_running "$bundle_id"; then
        print_error "アプリが実行中です"
        print_info "アプリを終了してから再度お試しください"
        return 1
    fi
    
    # Check disk space before migration
    print_info "転送前の容量チェック中..."
    
    # Mount volume temporarily to check size (if not already mounted)
    local check_mount_point=""
    local need_unmount=false
    
    if [[ -n "$current_mount" ]]; then
        check_mount_point="$current_mount"
    else
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        check_mount_point=$(_mount_for_capacity_check "$volume_name" "$volume_device")
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        need_unmount=true
    fi
    
    # Get directory size
    local source_size_kb=$(get_directory_size "$check_mount_point")
    local source_size_bytes=$((source_size_kb * 1024))
    
    # Unmount temporary check mount if created
    if [[ "$need_unmount" == true ]]; then
        unmount_volume "$check_mount_point" "silent"
        cleanup_temp_dir "$check_mount_point" true
    fi
    
    # Special handling for empty source (0 bytes or failed to get size)
    if [[ -z "$source_size_bytes" ]] || [[ "$source_size_bytes" -eq 0 ]]; then
        _handle_empty_external_to_internal "$volume_name" "$bundle_id" "$target_path"
        return $?
    fi
    
    # Get available space on internal disk
    local internal_disk_path=$(dirname "$target_path")
    while [[ ! -d "$internal_disk_path" ]] && [[ "$internal_disk_path" != "/" ]]; do
        internal_disk_path=$(dirname "$internal_disk_path")
    done
    
    local available_kb=$(get_available_space "$internal_disk_path")
    local available_bytes=$((available_kb * 1024))
    
    # Perform capacity check
    if ! _check_migration_capacity "$source_size_bytes" "$available_bytes" "external_to_internal"; then
        return 1
    fi
    
    # Determine current mount point
    local current_mount=$(get_mount_point "$volume_name")
    local temp_mount_created=false
    local source_mount=""
    
    if [[ -z "$current_mount" ]]; then
        # Volume not mounted - mount to temporary location
        print_info "ボリュームを一時マウント中..."
        local temp_mount="/tmp/playcover_temp_$$"
        /usr/bin/sudo /bin/mkdir -p "$temp_mount"
        local volume_device=$(get_volume_device "$volume_name")
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            print_error "$MSG_MOUNT_FAILED"
            /usr/bin/sudo /bin/rm -rf "$temp_mount"
            return 1
        fi
        source_mount="$temp_mount"
        temp_mount_created=true
    elif [[ "$current_mount" == "$target_path" ]]; then
        # Volume is mounted at target path - need to remount to temporary location
        print_info "外部ボリュームは ${target_path} にマウントされています"
        print_info "一時マウントポイントへ移動中..."
        
        local volume_device=$(get_volume_device "$volume_name")
        
        # Try unmount with automatic fallback
        if ! unmount_with_fallback "$target_path" "verbose" "$volume_name"; then
            print_error "強制アンマウントも失敗しました"
            echo ""
            print_warning "このアプリが使用中の可能性があります"
            print_info "推奨される対応:"
            echo "  1. アプリが起動していないか確認"
            echo "  2. Finderでこのディレクトリを開いていないか確認"
            echo "  3. 上記を確認後、再度実行"
            echo ""
            return 1
        fi
        
        print_success "アンマウントに成功しました"
        
        /bin/sleep 1
        
        local temp_mount="/tmp/playcover_temp_$$"
        /usr/bin/sudo /bin/mkdir -p "$temp_mount"
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            print_error "一時マウントに失敗しました"
            /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$target_path" 2>/dev/null || true
            /usr/bin/sudo /bin/rm -rf "$temp_mount"
            return 1
        fi
        source_mount="$temp_mount"
        temp_mount_created=true
    else
        # Volume is mounted elsewhere
        print_info "外部ボリュームは ${current_mount} にマウントされています"
        source_mount="$current_mount"
    fi
    
    # Remove existing internal data/mount point if it exists
    if [[ -e "$target_path" ]]; then
        print_info "既存データをクリーンアップ中..."
        remove_internal_storage_flag "$target_path"
        /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null || true
    fi
    
    # Create new internal directory
    /usr/bin/sudo /bin/mkdir -p "$target_path"
    
    # Copy data from external to internal
    if ! _perform_data_transfer "$source_mount" "$target_path" "copy"; then
        # Cleanup on failure
        if [[ "$temp_mount_created" == true ]]; then
            unmount_with_fallback "$source_mount" "silent" "$volume_name" || true
            /bin/sleep 1
            /usr/bin/sudo /bin/rm -rf "$source_mount" 2>/dev/null || true
        fi
        
        /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null || true
        return 1
    fi
    
    # Change ownership after successful copy
    /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"
    
    # Unmount volume
    local unmount_success=true
    if [[ "$temp_mount_created" == true ]]; then
        print_info "一時マウントをクリーンアップ中..."
        if ! unmount_with_fallback "$source_mount" "silent" "$volume_name"; then
            print_warning "一時マウントのアンマウントに失敗しました"
            unmount_success=false
        fi
        /bin/sleep 1
        cleanup_temp_dir "$source_mount" true
    else
        print_info "外部ボリュームをアンマウント中..."
        if ! unmount_app_volume "$volume_name" "$bundle_id"; then
            print_error "外部ボリュームのアンマウントに失敗しました"
            print_warning "ボリュームがまだマウントされている可能性があります"
            print_info "手動でアンマウントしてください"
            unmount_success=false
        fi
    fi
    
    # Only proceed with flag creation if unmount succeeded
    if [[ "$unmount_success" == false ]]; then
        echo ""
        print_error "アンマウント失敗のため、内蔵ストレージモードの設定を完了できませんでした"
        print_warning "データは ${target_path} にコピーされましたが、外部ボリュームがまだマウントされています"
        print_info "手動で外部ボリュームをアンマウントしてから、再度ストレージ切替を実行してください"
        return 1
    fi
    
    _show_migration_success "internal" "$target_path"
    
    # Create internal storage flag to mark this as intentional (only if unmount succeeded)
    if create_internal_storage_flag "$target_path"; then
        print_info "内蔵ストレージモードフラグを作成しました"
    fi
    
    return 0
}
