#!/bin/zsh
#######################################################
# PlayCover Manager - Volume Operations Module
# ボリュームの作成、マウント、アンマウント、検出
#######################################################

# Note: Basic mount_volume() and unmount_volume() are in 00_core.sh
# This module contains higher-level volume operations

#######################################################
# Batch Operation Helper Functions
#######################################################

# Initialize batch operation counters and UI
_init_batch_operation() {
    local operation_name="$1"
    
    clear
    print_header "$operation_name"
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_error "マッピングファイルが見つかりません: $MAPPING_FILE"
        wait_for_enter
        return 1
    fi
    
    # Request sudo upfront
    /usr/bin/sudo -v
    
    echo ""
    print_info "登録されたボリュームをスキャン中..."
    echo ""
    
    return 0
}

# Show batch operation summary
_show_batch_summary() {
    local operation_name="$1"
    local success_count=$2
    local skipped_count=$3
    local failed_count=$4
    local success_label="${5:-成功}"
    
    echo ""
    print_header "${operation_name}完了"
    echo ""
    echo "  ${GREEN}✅ ${success_label}: ${success_count}件${NC}"
    echo "  ${GRAY}⏭️  スキップ: ${skipped_count}件${NC}"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "  ${RED}❌ 失敗: ${failed_count}件${NC}"
    fi
    
    echo ""
    wait_for_enter
}

# Check common skip conditions for batch operations
# Returns: 0 if should skip, 1 if should process
_should_skip_batch_volume() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local check_type="$4"  # "mount" or "unmount"
    
    # Get volume info in one call (more efficient than separate existence + mount checks)
    local actual_mount=$(validate_and_get_mount_point "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        echo "  ⚠️  ${display_name}: ボリュームが見つかりません"
        return 0
    fi
    
    # Check if app is running
    if is_app_running "$bundle_id"; then
        echo "  🔒 ${display_name}: アプリ実行中（スキップ）"
        return 0
    fi
    
    # Type-specific checks
    case "$check_type" in
        "mount")
            local target_path="${PLAYCOVER_BASE}/${bundle_id}"
            
            # Skip if already mounted at correct location
            if [[ $vol_status -eq 0 ]] && [[ "$actual_mount" == "$target_path" ]]; then
                echo "  ✅ ${display_name}: 既にマウント済"
                return 0
            fi
            ;;
        "unmount")
            # Skip if not mounted (status 2 = exists but not mounted)
            if [[ $vol_status -eq 2 ]]; then
                echo "  ⚪️ ${display_name}: 既にアンマウント済"
                return 0
            fi
            
            # Check if PlayCover app files are in use
            local target_path="${PLAYCOVER_BASE}/${bundle_id}"
            if [[ -d "${target_path}/Wrapper" ]]; then
                local running_apps=$(get_running_apps_in_directory "$target_path")
                if [[ -n "$running_apps" ]]; then
                    echo "  🔥 ${display_name}: 配下アプリ実行中（スキップ）"
                    return 0
                fi
            fi
            ;;
    esac
    
    return 1
}

#######################################################
# Volume Detection Functions
#######################################################

# Check if APFS volume exists
# Args: volume_name, [diskutil_cache]
# Returns: 0 if exists, 1 if not found
volume_exists() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    # Use flexible pattern to match volume name (handles special characters and formatting)
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep -q "${volume_name}"
    else
        /usr/sbin/diskutil list | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep -q "${volume_name}"
    fi
}

# Get volume device identifier
# Args: volume_name, [diskutil_cache]
# Output: Device identifier (e.g., disk3s2)
# Returns: Device string or empty
get_volume_device() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    # Use flexible pattern to match volume name and extract device
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep "${volume_name}" | /usr/bin/awk '{print $NF}'
    else
        /usr/sbin/diskutil list | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep "${volume_name}" | /usr/bin/awk '{print $NF}'
    fi
}

# Get current mount point of volume
# Args: volume_name, [diskutil_cache]
# Output: Mount point path or empty string
get_mount_point() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    local device=$(get_volume_device "$volume_name" "$diskutil_cache")
    
    if [[ -z "$device" ]]; then
        echo ""
        return 1
    fi
    
    # Use new get_volume_mount_point function
    get_volume_mount_point "$device"
}

# Check volume existence with automatic error handling and callback
# Args: volume_name, title, [callback]
# Returns: 0 if volume exists, 1 if not (with error display and callback)
check_volume_exists_or_error() {
    local volume_name="$1"
    local title="$2"
    local callback="${3:-}"
    
    if ! volume_exists_cached "$volume_name"; then
        show_error_and_return "$title" "ボリューム '${volume_name}' が見つかりません" "$callback"
        return 1
    fi
    
    return 0
}

#######################################################
# Core Volume Mount/Unmount Functions
#######################################################

# Unmount volume with optional force
# Args: target (device or mount point), mode (silent|verbose), force (optional)
# Returns: 0 on success, 1 on failure
unmount_volume() {
    local target="$1"
    local mode="${2:-silent}"   # silent, verbose
    local force="${3:-}"         # force (optional)
    
    local force_option=""
    if [[ "$force" == "force" ]]; then
        force_option="force"
    fi
    
    if [[ "$mode" == "verbose" ]]; then
        if [[ -n "$force_option" ]]; then
            print_info "強制アンマウント中..."
        else
            print_info "アンマウント中..."
        fi
    fi
    
    if /usr/bin/sudo /usr/sbin/diskutil unmount $force_option "$target" >/dev/null 2>&1; then
        if [[ "$mode" == "verbose" ]]; then
            print_success "アンマウント成功"
        fi
        return 0
    else
        if [[ "$mode" == "verbose" ]]; then
            if [[ -z "$force_option" ]]; then
                print_error "アンマウント失敗"
            else
                print_error "強制アンマウント失敗"
            fi
        fi
        return 1
    fi
}

# Note: unmount_with_fallback() is now in 00_core.sh for cross-module use

# Mount volume with unified error handling
# Args: device|volume_name, mount_point, [nobrowse], [silent|verbose]
# Returns: 0 on success, 1 on failure
mount_volume() {
    local device="$1"
    local mount_point="$2"
    local nobrowse="${3:-}"     # nobrowse (optional)
    local mode="${4:-silent}"   # silent, verbose
    
    if [[ "$mode" == "verbose" ]]; then
        print_info "マウント中..."
    fi
    
    # Create mount point if not exists
    if [[ ! -d "$mount_point" ]]; then
        /usr/bin/sudo /bin/mkdir -p "$mount_point" 2>/dev/null
    fi
    
    # Mount with or without nobrowse option
    if [[ "$nobrowse" == "nobrowse" ]]; then
        # Use /sbin/mount directly with nobrowse option to prevent desktop icon
        if /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$device" "$mount_point" >/dev/null 2>&1; then
            # Mount successful
            :
        else
            if [[ "$mode" == "verbose" ]]; then
                print_error "マウント失敗"
            fi
            return 1
        fi
    else
        if ! /usr/bin/sudo /usr/sbin/diskutil mount -mountPoint "$mount_point" "$device" >/dev/null 2>&1; then
            if [[ "$mode" == "verbose" ]]; then
                print_error "マウント失敗"
            fi
            return 1
        fi
    fi
    
    if [[ "$mode" == "verbose" ]]; then
        print_success "マウント成功"
    fi
    
    # Set ownership to current user
    /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$mount_point" 2>/dev/null || true
    
    return 0
}

#######################################################
# High-Level Volume Operations
#######################################################

# Unmount app volume with optional app quit
# Args: volume_name, bundle_id, [diskutil_cache]
# Returns: 0 on success, 1 on failure
unmount_app_volume() {
    local volume_name=$1
    local bundle_id=$2
    local diskutil_cache="${3:-}"
    
    # Get all volume info in one diskutil call (more efficient)
    local vol_info=$(get_volume_info "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        print_warning "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    local device="${vol_info%%|*}"
    local current_mount="${vol_info#*|}"
    
    if [[ -z "$current_mount" ]]; then
        print_info "既にアンマウント済みです"
        return 0
    fi
    
    # Quit app before unmounting if bundle_id is provided
    if [[ -n "$bundle_id" ]]; then
        quit_app_if_running "$bundle_id"
    fi
    
    if unmount_volume "$device" "silent"; then
        print_success "アンマウント成功"
        # Invalidate cache after successful unmount
        invalidate_volume_cache "$volume_name"
        return 0
    else
        print_error "アンマウント失敗"
        return 1
    fi
}

# Mount app volume to specific path
# Args: volume_name, mount_path, [bundle_id]
# Returns: 0 on success, 1 on failure
mount_app_volume() {
    local volume_name=$1
    local mount_path=$2
    local bundle_id="${3:-}"
    
    # Get volume device (with existence check and error handling)
    local device=$(get_volume_device_or_fail "$volume_name") || return 1
    
    # Check if already mounted at correct location
    local current_mount=$(get_mount_point "$volume_name")
    if [[ "$current_mount" == "$mount_path" ]]; then
        print_info "既に正しい位置にマウント済みです"
        return 0
    fi
    
    # If mounted elsewhere, unmount first
    if [[ -n "$current_mount" ]]; then
        print_info "別の位置にマウントされているため、再マウントします"
        if [[ -n "$bundle_id" ]]; then
            quit_app_if_running "$bundle_id"
        fi
        unmount_with_fallback "$device" "silent" "$volume_name"
    fi
    
    # Create mount point if not exists
    if [[ ! -d "$mount_path" ]]; then
        /usr/bin/sudo /bin/mkdir -p "$mount_path" 2>/dev/null
    fi
    
    # Mount with nobrowse option
    if mount_volume "$device" "$mount_path" "nobrowse" "silent"; then
        print_success "マウント成功: $mount_path"
        # Invalidate cache after successful mount
        invalidate_volume_cache "$volume_name"
        return 0
    else
        print_error "マウント失敗"
        return 1
    fi
}

#######################################################
# Volume Creation Functions
#######################################################

#######################################################
# Utility Functions
#######################################################

# Get drive name from device path
# Args: device_path (e.g., /dev/disk3s1)
# Output: Drive name (e.g., "External SSD")
get_drive_name() {
    local device=$1
    
    # Extract disk identifier (e.g., disk3 from disk3s1)
    local disk_id=$(echo "$device" | /usr/bin/sed 's|/dev/||;s|s[0-9]*$||')
    
    # Use new get_disk_name function
    get_disk_name "$disk_id"
}

# Check if PlayCover main volume is mounted
# Returns: 0 if mounted, 1 if not
check_playcover_volume_mount() {
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        # Check if it's actually a mount point
        if /sbin/mount | /usr/bin/grep -q "$PLAYCOVER_CONTAINER"; then
            return 0
        fi
    fi
    return 1
}

#######################################################
# Disk Eject Function
#######################################################

# Eject external disk containing PlayCover volume
# Unmounts all PlayCover-related volumes before ejecting
eject_disk() {
    clear
    
    # Get current PlayCover volume device dynamically
    local volume_device=$(get_volume_device_or_fail "$PLAYCOVER_VOLUME_NAME")
    if [[ $? -ne 0 ]]; then
        print_header "ディスク取り外し"
        handle_error_and_return "PlayCoverボリュームが見つかりません"
    fi
    
    local playcover_device="/dev/${volume_device}"
    
    local disk_id=$(echo "$playcover_device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    local drive_name=$(get_drive_name "$playcover_device")
    
    print_header "「${drive_name}」の取り外し"
    
    print_warning "このドライブの全てのボリュームをアンマウントします"
    echo ""
    print_info "注意: PlayCover関連ボリューム以外も含まれる可能性があります"
    echo ""
    
    if ! prompt_confirmation "続行しますか？" "Y/n"; then
        print_info "$MSG_CANCELED"
        wait_for_enter "Enterキーで続行..."
        return
    fi
    
    # Authenticate sudo only when user confirms
    authenticate_sudo
    
    echo ""
    
    # Use existing batch_unmount_all logic to unmount all mapped volumes
    local mappings_content=$(read_mappings)
    
    if [[ -n "$mappings_content" ]]; then
        local -a mappings_array=()
        while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
            [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
            mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
        done <<< "$mappings_content"
        
        if [[ ${#mappings_array} -gt 0 ]]; then
            print_info "登録済みボリュームをアンマウント中..."
            echo ""
            
            # Cache diskutil list for performance (single call for all volumes)
            local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
            
            local success_count=0
            local fail_count=0
            
            # Unmount in reverse order (apps first, PlayCover last)
            for ((i=${#mappings_array}; i>=1; i--)); do
                IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
                
                # Check if this volume is on the target disk
                local device=$(get_volume_device "$volume_name" "$diskutil_cache" 2>/dev/null)
                if [[ -z "$device" ]]; then
                    continue
                fi
                
                local vol_disk=$(echo "$device" | /usr/bin/sed -E 's|(disk[0-9]+).*|\1|')
                if [[ "$vol_disk" != "$disk_id" ]]; then
                    continue
                fi
                
                echo "  ${CYAN}${display_name}${NC} (${volume_name})"
                
                local current_mount=$(get_mount_point "$volume_name" "$diskutil_cache")
                
                if [[ -z "$current_mount" ]]; then
                    echo "     ${GREEN}✅ 既にアンマウント済${NC}"
                    ((success_count++))
                else
                    if [[ -n "$bundle_id" ]]; then
                        quit_app_if_running "$bundle_id"
                    fi
                    
                    if unmount_volume "$device" "silent"; then
                        echo "     ${GREEN}✅ アンマウント成功${NC}"
                        ((success_count++))
                    else
                        if /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1; then
                            echo "     ${RED}❌ アンマウント失敗: アプリが実行中です${NC}"
                        else
                            echo "     ${RED}❌ アンマウント失敗${NC}"
                        fi
                        ((fail_count++))
                    fi
                fi
                echo ""
            done
            
            if [[ $success_count -gt 0 ]] || [[ $fail_count -gt 0 ]]; then
                echo ""
                print_info "PlayCover関連: 成功 ${success_count}個, 失敗 ${fail_count}個"
            fi
        fi
    fi
    
    echo ""
    print_info "ディスク ${drive_name} (${disk_id}) を取り外し中..."
    
    if /usr/bin/sudo /usr/sbin/diskutil eject "$disk_id"; then
        print_success "ディスク ${drive_name} を安全に取り外しました"
        echo ""
        print_info "3秒後にターミナルを自動で閉じます..."
        /bin/sleep 3
        /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
    else
        print_error "ディスクの取り外しに失敗しました"
        wait_for_enter
    fi
}

#######################################################
# Batch Volume Operations
#######################################################

# Mount all registered volumes
# Reads from MAPPING_FILE and mounts all unmounted volumes
batch_mount_all() {
    _init_batch_operation "全ボリュームをマウント" || return 1
    
    local mounted_count=0
    local skipped_count=0
    local failed_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip empty lines
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        
        # Check common skip conditions
        if _should_skip_batch_volume "$volume_name" "$bundle_id" "$display_name" "mount"; then
            ((skipped_count++))
            continue
        fi
        
        local target_path="${PLAYCOVER_BASE}/${bundle_id}"
        
        # Check storage mode
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        if [[ "$storage_mode" == "internal_intentional" ]] || [[ "$storage_mode" == "internal_intentional_empty" ]]; then
            echo "  🏠 ${display_name}: 内蔵ストレージモード（スキップ）"
            ((skipped_count++))
            continue
        elif [[ "$storage_mode" == "internal_contaminated" ]]; then
            echo ""
            echo "  ⚠️  ${YELLOW}${display_name}: 内蔵データが検出されました${NC}"
            echo ""
            echo "  ${CYAN}処理方法を選択:${NC}"
            echo "    ${LIGHT_GREEN}1.${NC} 削除して外部ボリュームをマウント"
            echo "    ${LIGHT_GREEN}2.${NC} 保持して外部ボリュームと統合"
            echo "    ${LIGHT_GREEN}3.${NC} スキップ（後で個別に処理）"
            echo ""
            echo -n "  選択 (1-3): "
            read contamination_choice </dev/tty
            echo ""
            
            case "$contamination_choice" in
                1)
                    echo "  🗑️  ${display_name}: 内蔵データを削除中..."
                    if /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null; then
                        echo "  ✅ 削除完了"
                        # Continue to mount below
                    else
                        echo "  ❌ 削除失敗"
                        ((failed_count++))
                        continue
                    fi
                    ;;
                2)
                    echo "  🔄 ${display_name}: データを統合します（マウント後に外部に移動）"
                    # Continue to mount, data will be merged
                    ;;
                3|*)
                    echo "  ⏭️  ${display_name}: スキップしました"
                    ((skipped_count++))
                    continue
                    ;;
            esac
        fi
        
        # Get device early (needed for both unmount and mount)
        local device=$(get_volume_device "$volume_name")
        if [[ -z "$device" ]]; then
            echo "  ❌ ${display_name}: デバイス取得失敗"
            ((failed_count++))
            continue
        fi
        
        # Unmount if mounted elsewhere
        if [[ -n "$actual_mount" ]] && [[ "$actual_mount" != "$target_path" ]]; then
            echo -n "  📍 ${display_name}: マウント位置調整中..."
            if unmount_volume "/dev/$device" "silent"; then
                echo " ✅"
                # Wait for unmount to complete fully
                /bin/sleep 1
            else
                echo " ❌"
                ((failed_count++))
                continue
            fi
        fi
        
        # Mount the volume
        echo -n "  🔄 ${display_name}: マウント中..."
        
        # Create mount point
        /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
        
        # Mount with nobrowse
        if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
            echo " ✅"
            ((mounted_count++))
            # Invalidate cache after successful mount
            invalidate_volume_cache "$volume_name"
        else
            echo " ❌ (マウント失敗)"
            ((failed_count++))
        fi
        
    done < "$MAPPING_FILE"
    
    _show_batch_summary "マウント" "$mounted_count" "$skipped_count" "$failed_count" "マウント成功"
    
    # Only show storage explanation if at least one volume was mounted
    if [[ $mounted_count -gt 0 ]]; then
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "${YELLOW}📊 容量表示について${NC}"
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "${ORANGE}⚠️  内蔵ストレージの使用容量が増えて見える場合がありますが、${NC}"
        echo "${GREEN}✅ 外部ボリューム使用により内蔵ストレージは節約されています${NC}"
        echo ""
        echo "${GRAY}詳細: APFSの仕様により論理サイズが重複カウントされています。${NC}"
        echo "${WHITE}使用容量表示が実容量を超えて表示される場合もありますが、仕様です。${NC}"
        echo ""
        echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        wait_for_enter
    fi
}

# Unmount all registered volumes
# Reads from MAPPING_FILE and unmounts all mounted volumes
batch_unmount_all() {
    _init_batch_operation "全ボリュームをアンマウント" || return 1
    
    local unmounted_count=0
    local skipped_count=0
    local failed_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip empty lines
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        
        # Check common skip conditions
        if _should_skip_batch_volume "$volume_name" "$bundle_id" "$display_name" "unmount"; then
            ((skipped_count++))
            continue
        fi
        
        # Unmount the volume
        echo -n "  🔄 ${display_name}: アンマウント中..."
        
        if unmount_with_fallback "$volume_name" "silent"; then
            echo " ✅"
            ((unmounted_count++))
            # Invalidate cache after successful unmount
            invalidate_volume_cache "$volume_name"
        else
            echo " ❌ (アンマウント失敗)"
            ((failed_count++))
        fi
        
    done < "$MAPPING_FILE"
    
    _show_batch_summary "アンマウント" "$unmounted_count" "$skipped_count" "$failed_count" "アンマウント成功"
}
