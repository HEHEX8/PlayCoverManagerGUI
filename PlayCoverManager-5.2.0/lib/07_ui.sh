#!/bin/zsh
#
# PlayCover Volume Manager - UI Module
# File: lib/07_ui.sh
# Description: Main menu, quick status, individual volume control, batch operations
# Version: 5.2.0
#

#######################################################
# Volume Control Helper Functions
#######################################################

# Handle unmount operation with error checking
_handle_unmount_operation() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    
    # Check if app is running
    check_app_running_with_error "$bundle_id" "$display_name" "アンマウント" "individual_volume_control" || return 1
    
    local device=$(get_volume_device "$volume_name")
    if unmount_volume "$device" "silent"; then
        # Invalidate cache after successful unmount
        invalidate_volume_cache "$volume_name"
        silent_return_to_menu "individual_volume_control"
        return 0
    else
        # Determine error reason
        local error_msg="アンマウント失敗: ファイルが使用中の可能性があります"
        if /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1; then
            error_msg="アンマウント失敗: アプリが実行中です"
        fi
        
        show_error_and_return "${display_name} の操作" "$error_msg" "individual_volume_control"
        return 1
    fi
}

# Handle remount operation (from wrong location to correct location)
_handle_remount_operation() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local target_path="$4"
    
    # Check if app is running
    check_app_running_with_error "$bundle_id" "$display_name" "再マウント" "individual_volume_control" || return 1
    
    local device=$(get_volume_device "$volume_name")
    
    # Unmount from wrong location
    if ! unmount_volume "$device" "silent"; then
        show_error_and_return "${display_name} の操作" \
            "アンマウント失敗: ファイルが使用中の可能性があります" \
            "individual_volume_control"
        return 1
    fi
    
    # Invalidate cache after unmount (before remount)
    invalidate_volume_cache "$volume_name"
    
    # Mount to correct location
    /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
    
    if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
        # Invalidate cache after successful remount
        invalidate_volume_cache "$volume_name"
        silent_return_to_menu "individual_volume_control"
        return 0
    else
        show_error_and_return "${display_name} の操作" "再マウント失敗" "individual_volume_control"
        return 1
    fi
}

# Handle mount operation with storage mode checks
_handle_mount_operation() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local target_path="$4"
    
    # Check if volume exists
    if ! check_volume_exists_or_error "$volume_name" "${display_name} の操作" "individual_volume_control"; then
        return 1
    fi
    
    # Check storage mode
    local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
    
    case "$storage_mode" in
        "internal_intentional"|"internal_intentional_empty")
            show_error_info_and_return "${display_name} の操作" \
                "$MSG_INTENTIONAL_INTERNAL_MODE" \
                "$MSG_SWITCH_VIA_STORAGE_MENU" \
                "individual_volume_control"
            return 1
            ;;
        "internal_contaminated")
            _handle_contaminated_mount "$volume_name" "$bundle_id" "$display_name" "$target_path"
            return $?
            ;;
        *)
            _perform_mount "$volume_name" "$bundle_id" "$display_name" "$target_path"
            return $?
            ;;
    esac
}

# Handle contaminated data during mount
_handle_contaminated_mount() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local target_path="$4"
    
    clear
    print_header "${display_name} の操作"
    echo ""
    print_warning "$MSG_UNINTENDED_INTERNAL_DATA"
    echo ""
    
    # Show data sizes
    local internal_size=$(get_container_size "$target_path")
    echo "  ${CYAN}内蔵データサイズ:${NC} ${BOLD}${internal_size}${NC}"
    echo ""
    
    echo "${BOLD}${YELLOW}処理方法を選択してください:${NC}"
    echo "  ${BOLD}${GREEN}1.${NC} 外部ボリュームを優先（内蔵データは削除）${BOLD}${GREEN}[推奨・デフォルト]${NC}"
    echo "  ${BOLD}${CYAN}2.${NC} 内蔵データを外部ボリュームにマージ（内蔵データを保持）"
    echo "  ${BOLD}${BLUE}3.${NC} キャンセル（マウントしない）"
    echo ""
    echo -n "${BOLD}${YELLOW}選択 (1-3) [デフォルト: 1]:${NC} "
    read cleanup_choice </dev/tty
    
    cleanup_choice=${cleanup_choice:-1}
    
    case "$cleanup_choice" in
        1)
            print_info "外部ボリュームを優先します（内蔵データを削除）"
            print_info "$MSG_CLEANUP_INTERNAL_STORAGE"
            /usr/bin/sudo /bin/rm -rf "$target_path"
            echo ""
            _perform_mount "$volume_name" "$bundle_id" "$display_name" "$target_path"
            return $?
            ;;
        2)
            _merge_internal_to_external "$volume_name" "$bundle_id" "$display_name" "$target_path"
            return $?
            ;;
        3)
            print_info "マウントをキャンセルしました"
            wait_for_enter
            silent_return_to_menu "individual_volume_control"
            return 0
            ;;
        *)
            print_error "$MSG_INVALID_SELECTION"
            wait_for_enter
            silent_return_to_menu "individual_volume_control"
            return 1
            ;;
    esac
}

# Perform actual mount operation
_perform_mount() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local target_path="$4"
    
    authenticate_sudo
    
    local device=$(get_volume_device "$volume_name")
    /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
    
    if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
        # Invalidate cache after successful mount
        invalidate_volume_cache "$volume_name"
        silent_return_to_menu "individual_volume_control"
        return 0
    else
        show_error_and_return "${display_name} の操作" "マウント失敗" "individual_volume_control"
        return 1
    fi
}

# Merge internal data to external volume
_merge_internal_to_external() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local target_path="$4"
    
    print_info "内蔵データを外部ボリュームにマージします"
    echo ""
    
    # Mount to temp location
    local temp_mount=$(create_temp_dir) || {
        show_error_and_return "${display_name} の操作" \
            "一時ディレクトリの作成に失敗しました" \
            "individual_volume_control"
        return 1
    }
    
    authenticate_sudo
    local device=$(get_volume_device "$volume_name")
    
    if ! mount_volume "/dev/$device" "$temp_mount" "nobrowse" "silent"; then
        /bin/rm -rf "$temp_mount"
        show_error_and_return "${display_name} の操作" \
            "一時マウントに失敗しました" \
            "individual_volume_control"
        return 1
    fi
    
    # Copy data
    print_info "データをマージしています..."
    if /usr/bin/sudo /usr/bin/rsync -a --info=progress2 "$target_path/" "$temp_mount/"; then
        unmount_volume "$device" "silent"
        # Invalidate cache after temp unmount
        invalidate_volume_cache "$volume_name"
        /bin/rm -rf "$temp_mount"
        /usr/bin/sudo /bin/rm -rf "$target_path"
        
        # Final mount
        /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
        if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
            # Invalidate cache after final mount
            invalidate_volume_cache "$volume_name"
            print_success "マージとマウントが完了しました"
            wait_for_enter
            silent_return_to_menu "individual_volume_control"
            return 0
        else
            show_error_and_return "${display_name} の操作" \
                "最終マウントに失敗しました" \
                "individual_volume_control"
            return 1
        fi
    else
        unmount_volume "$device" "silent"
        /bin/rm -rf "$temp_mount"
        show_error_and_return "${display_name} の操作" \
            "データのマージに失敗しました" \
            "individual_volume_control"
        return 1
    fi
}

#######################################################
# Quick Status Display
#######################################################

show_quick_status() {
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        return
    fi
    
    local external_count=0
    local internal_count=0
    local unmounted_count=0
    local total_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip PlayCover itself
        if [[ "$volume_name" == "PlayCover" ]]; then
            continue
        fi
        
        ((total_count++))
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        
        # Check actual mount status using cached data for performance
        local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
        local vol_status=$?
        
        if [[ $vol_status -eq 0 ]] && [[ "$actual_mount" == "$target_path" ]]; then
            # Volume is mounted at correct location = external storage
            ((external_count++))
        else
            # Volume not mounted - check if internal storage has data
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
            case "$storage_mode" in
                "internal_intentional"|"internal_intentional_empty")
                    ((internal_count++))
                    ;;
                "internal_contaminated")
                    # 内蔵データ検出状態は警告として扱う
                    ((unmounted_count++))
                    ;;
                *)
                    ((unmounted_count++))
                    ;;
            esac
        fi
    done <<< "$mappings_content"
    
    if [[ $total_count -gt 0 ]]; then
        echo "${CYAN}コンテナ情報${NC}"
        
        # Build status line dynamically (only show non-zero items)
        local status_parts=()
        
        if [[ $external_count -gt 0 ]]; then
            status_parts+=("${SKY_BLUE}⚡ 外部マウント: ${external_count}件${NC}")
        fi
        
        if [[ $internal_count -gt 0 ]]; then
            status_parts+=("${ORANGE}🍎 内部マウント: ${internal_count}件${NC}")
        fi
        
        if [[ $unmounted_count -gt 0 ]]; then
            status_parts+=("${RED}❌ データ無し: ${unmounted_count}件${NC}")
        fi
        
        # Join status parts with separator
        local first=true
        for part in "${(@)status_parts}"; do
            if [[ "$first" == true ]]; then
                echo -n "$part"
                first=false
            else
                echo -n "　　$part"
            fi
        done
        echo ""
        
        if [[ $unmounted_count -gt 0 ]]; then
            echo "${RED}⚠️ データが入っていないコンテナがあります。マウントを行ってください。${NC}"
        fi
    fi
}

#######################################################
# Main Menu Display
#######################################################

show_menu() {
    clear
    
    # Preload all volume information into cache for fast menu display
    # This happens once per menu display cycle
    preload_all_volume_cache
    
    echo ""
    echo "${GREEN}PlayCover 統合管理ツール${NC}  ${SKY_BLUE}Version 5.2.0${NC}"
    echo ""
    
    show_quick_status
    
    echo "${CYAN}メインメニュー${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}1.${NC} アプリ管理"
    echo "  ${LIGHT_GREEN}2.${NC} ボリューム操作"
    echo "  ${LIGHT_GREEN}3.${NC} ストレージ切替"
    echo "  ${LIGHT_GREEN}4.${NC} クイックランチャー"
    echo ""
    
    # Dynamic eject menu label (v4.7.0)
    local eject_label="ディスク全体を取り外し"
    
    # Get current PlayCover volume device dynamically for menu display
    if volume_exists_cached "$PLAYCOVER_VOLUME_NAME"; then
        local volume_device=$(validate_and_get_device_cached "$PLAYCOVER_VOLUME_NAME")
        if [[ -n "$volume_device" ]]; then
            local playcover_device="/dev/${volume_device}"
            local drive_name=$(get_drive_name "$playcover_device")
            eject_label="${drive_name} の取り外し"
        fi
    fi
    
    echo "  ${LIGHT_GREEN}5.${NC} ${eject_label}"
    echo "  ${LIGHT_GREEN}6.${NC} システムメンテナンス ${GRAY}(APFS修復)${NC}"
    echo "  ${LIGHT_GRAY}q.${NC} 終了"
    echo ""
    echo "${DIM_GRAY}空Enterで最新の情報に更新${NC}"
    echo ""
    echo -n "${CYAN}選択 (1-6/q):${NC} "
}

#######################################################
# Installed Apps Display
#######################################################

show_installed_apps() {
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local display_only="${1:-true}"  # Default to display mode
    
    # Check if mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${ORANGE}インストール済みアプリ:${NC} ${SKY_BLUE}0個${NC}"
        fi
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${ORANGE}インストール済みアプリ:${NC} ${SKY_BLUE}0個${NC}"
        fi
        return
    fi
    
    # Check if PlayCover Applications directory exists
    # Create it if PlayCover container is mounted but directory doesn't exist
    if [[ ! -d "$playcover_apps" ]]; then
        local playcover_container="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
        if [[ -d "$playcover_container" ]]; then
            # Container exists (mounted), create Applications directory
            /bin/mkdir -p "$playcover_apps" 2>/dev/null || true
        fi
        
        # Check again after creation attempt
        if [[ ! -d "$playcover_apps" ]]; then
            if [[ "$display_only" == "true" ]]; then
                echo "${ORANGE}インストール済みアプリ:${NC} ${RED}PlayCoverコンテナが見つかりません${NC}"
            fi
            return
        fi
    fi
    
    if [[ "$display_only" == "true" ]]; then
        echo "${ORANGE}インストール済みアプリ${NC}"
        echo ""
    fi
    
    local installed_count=0
    local missing_count=0
    local index=1
    
    # Global arrays for uninstall workflow (declared in main if needed)
    if [[ "$display_only" == "false" ]]; then
        apps_list=()
        volumes_list=()
        bundles_list=()
        versions_list=()
    fi
    
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip PlayCover itself (it's not an iOS app)
        if [[ "$volume_name" == "PlayCover" ]]; then
            continue
        fi
        
        # Search for app in PlayCover Applications
        local app_found=false
        local app_version=""
        
        if [[ -d "$playcover_apps" ]]; then
            while IFS= read -r app_path; do
                if [[ -f "${app_path}/Info.plist" ]]; then
                    local found_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                    
                    if [[ "$found_bundle_id" == "$bundle_id" ]]; then
                        app_found=true
                        app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null || echo "不明")
                        break
                    fi
                fi
            done < <(find "$playcover_apps" -maxdepth 1 -name "*.app" -type d 2>/dev/null)
        fi
        
        if [[ "$app_found" == true ]]; then
            # Get container path and size
            local container_path="${HOME}/Library/Containers/${bundle_id}"
            local container_size=$(get_container_size "$container_path")
            
            # Check actual mount status using cached data for performance
            local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
            local vol_status=$?
            local storage_icon=""
            
            # Check storage mode to determine icon
            local storage_mode=""
            if [[ $vol_status -eq 0 ]] && [[ "$actual_mount" == "$container_path" ]]; then
                # Volume is mounted at correct location = external storage
                storage_icon="⚡ 外部"
            elif [[ -n "$actual_mount" ]]; then
                # Volume is mounted but at wrong location
                storage_icon="⚠️  位置異常"
            elif [[ $vol_status -eq 2 ]]; then
                # Volume exists but not mounted
                storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                
                case "$storage_mode" in
                    "internal_intentional")
                        storage_icon="🍎 内部"
                        ;;
                    "internal_intentional_empty")
                        storage_icon="🍎 内部(空)"
                        ;;
                    "internal_contaminated")
                        storage_icon="⚠️  内蔵データ検出"
                        ;;
                    "none")
                        storage_icon="💤 未マウント"
                        ;;
                    *)
                        storage_icon="？ 不明"
                        ;;
                esac
            else
                # Volume not mounted - check if internal storage has data
                storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                
                # Skip apps with no data and unknown storage mode
                if [[ "$storage_mode" == "none" ]] || [[ "$storage_mode" == "unknown" ]]; then
                    continue
                fi
                
                case "$storage_mode" in
                    "internal_intentional")
                        storage_icon="🍎 内部"
                        ;;
                    "internal_intentional_empty")
                        storage_icon="🍎 内部(空)"
                        ;;
                    "internal_contaminated")
                        storage_icon="⚠️  内蔵データ検出"
                        ;;
                    *)
                        storage_icon="？ 不明"
                        ;;
                esac
            fi
            
            if [[ "$display_only" == "true" ]]; then
                printf " ${BOLD}%s${NC} ${LIGHT_GRAY}|${NC} ${BOLD}${WHITE}%s${NC} ${GRAY}(v%s)${NC} ${LIGHT_GRAY}%s${NC}\n" "$storage_icon" "$container_size" "$app_version" "$display_name"
            else
                echo "  ${BOLD}${CYAN}${index}.${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}(v${app_version})${NC}"
                echo "      ${GRAY}Bundle ID:${NC} ${LIGHT_GRAY}${bundle_id}${NC}"
                echo "      ${GRAY}ボリューム:${NC} ${LIGHT_GRAY}${volume_name}${NC}"
                echo "      ${GRAY}使用容量:${NC} ${BOLD}${storage_icon}${NC} ${BOLD}${WHITE}${container_size}${NC}"
                echo ""
                apps_list+=("$display_name")
                volumes_list+=("$volume_name")
                bundles_list+=("$bundle_id")
                versions_list+=("$app_version")
                ((index++))
            fi
            ((installed_count++))
        else
            if [[ "$display_only" == "true" ]]; then
                # Check what exactly is missing for detailed error message
                local volume_exists_check=$(volume_exists_cached "$volume_name" && echo "yes" || echo "no")
                local container_exists_check=$([[ -d "${HOME}/Library/Containers/${bundle_id}" ]] && echo "yes" || echo "no")
                
                local missing_reason=""
                if [[ "$volume_exists_check" == "no" ]] && [[ "$container_exists_check" == "no" ]]; then
                    missing_reason="${RED}(ボリュームとアプリ本体が見つかりません - マッピングデータが古い可能性)${NC}"
                elif [[ "$volume_exists_check" == "no" ]]; then
                    missing_reason="${RED}(ボリュームが見つかりません)${NC}"
                else
                    missing_reason="${RED}(アプリ本体.appが見つかりません)${NC}"
                fi
                
                echo "  ${BOLD}${RED}❌${NC} ${STRIKETHROUGH}${GRAY}${display_name}${NC} ${BOLD}${missing_reason}"
            fi
            ((missing_count++))
        fi
    done <<< "$mappings_content"
    
    if [[ "$display_only" == "true" ]]; then
        print_separator
        echo ""
        echo "${CYAN}操作を選択してください${NC}"
    fi
    
    # Return installed count for uninstall workflow
    if [[ "$display_only" == "false" ]]; then
        return $installed_count
    fi
}

#######################################################
# App Management Menu
#######################################################

app_management_menu() {
    # Ensure PlayCover volume is mounted before showing menu
    local playcover_mounted=false
    
    local pc_current_mount=$(validate_and_get_mount_point_cached "$PLAYCOVER_VOLUME_NAME")
    local pc_vol_status=$?
    
    if [[ $pc_vol_status -ne 1 ]]; then
        # Volume exists (either mounted or unmounted)
        if [[ $pc_vol_status -eq 2 ]]; then
            # Volume exists but not mounted (status 2)
            # Volume exists but not mounted - try to mount it
            authenticate_sudo
            
            # Clear internal data first if needed
            if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
                local storage_type=$(get_storage_type "$PLAYCOVER_CONTAINER")
                if [[ "$storage_type" == "internal" ]]; then
                    clear
                    print_warning "PlayCoverボリュームが未マウントですが、内蔵ストレージにデータがあります"
                    echo ""
                    echo "${ORANGE}対処方法:${NC}"
                    echo "  1. 内蔵データを外部に移行してマウント（推奨）"
                    echo "  2. 内蔵データを削除してクリーンな状態でマウント"
                    echo "  3. キャンセル"
                    echo ""
                    echo -n "選択してください (1/2/3): "
                    read cleanup_choice
                    
                    case "$cleanup_choice" in
                        1|2)
                            # Call mount_playcover_main_volume which handles cleanup
                            mount_playcover_main_volume
                            playcover_mounted=true
                            ;;
                        *)
                            print_info "$MSG_CANCELED"
                            echo ""
                            echo -n "Enterキーで続行..."
                            read
                            return
                            ;;
                    esac
                else
                    # No internal data, mount directly
                    mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
                    playcover_mounted=$?
                    [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
                fi
            else
                # Directory doesn't exist, create and mount
                mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
                playcover_mounted=$?
                [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
            fi
        elif [[ "$pc_current_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            # Volume mounted to wrong location - remount
            authenticate_sudo
            unmount_volume "$PLAYCOVER_VOLUME_NAME" >/dev/null 2>&1 || true
            mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
            playcover_mounted=$?
            [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
        else
            # Already mounted correctly
            playcover_mounted=true
        fi
    fi
    
    # If PlayCover volume couldn't be mounted, show warning
    if [[ "$playcover_mounted" == false ]]; then
        clear
        print_warning "PlayCoverボリュームがマウントされていません"
        print_info "アプリ一覧を正しく表示するには、ボリュームをマウントしてください"
        wait_for_enter
    fi
    
    while true; do
        clear
        echo ""
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "${BOLD}${CYAN}  📱 アプリ管理${NC}"
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        show_installed_apps
        echo ""
        print_separator
        echo ""
        echo "${BOLD}${UNDERLINE}操作を選択してください${NC}"
        echo "  ${BOLD}${GREEN}1.${NC} アプリをインストール"
        echo "  ${BOLD}${RED}2.${NC} アプリをアンインストール"
        echo "  ${BOLD}${LIGHT_GRAY}0.${NC} 戻る  ${BOLD}${LIGHT_GRAY}q.${NC} 終了"
        echo ""
        echo "${DIM_GRAY}※ Enterキーのみ: 状態を再取得${NC}"
        echo ""
        echo -n "${BOLD}${YELLOW}選択: ${NC}"
        read choice
        
        case "$choice" in
            "")
                # Empty Enter - refresh cache and redisplay menu
                refresh_all_volume_caches
                ;;
            1)
                install_workflow
                ;;
            2)
                uninstall_workflow
                ;;
            0)
                return
                ;;
            *)
                print_error "$MSG_INVALID_SELECTION"
                wait_for_enter
                ;;
        esac
    done
}

#######################################################
# Individual Volume Control
#######################################################

individual_volume_control() {
    clear
    print_header "ボリューム情報"
    
    # Read mapping file directly
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません: $MAPPING_FILE"
        wait_for_enter
        return
    fi
    
    # Build array from file (ignore 4th column if present)
    local -a mappings_array=()
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip empty lines
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        
        # Add to array (only first 3 columns)
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    
    # Check if we have any mappings
    if [[ ${#mappings_array} -eq 0 ]]; then
        show_error_and_return "ボリューム情報" "$MSG_NO_REGISTERED_VOLUMES"
        return
    fi
    
    echo "登録ボリューム"
    echo ""
    
    # Cache diskutil output once for performance
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    local mount_cache=$(/sbin/mount 2>/dev/null)
    
    # Check if any app is running (affects PlayCover lock status)
    local any_app_running=false
    for ((j=1; j<=${#mappings_array}; j++)); do
        IFS='|' read -r _ check_bundle_id _ <<< "${mappings_array[$j]}"
        if [[ "$check_bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
            if is_app_running "$check_bundle_id"; then
                any_app_running=true
                break
            fi
        fi
    done
    
    # Build selectable array (excluding locked volumes)
    local -a selectable_array=()
    local -a selectable_indices=()
    
    # Display volumes with detailed status (single column)
    local display_index=1
    for ((i=1; i<=${#mappings_array}; i++)); do
        IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local status_line=""
        local extra_info=""
        local is_locked=false
        
        # Check if app is running (locked)
        local lock_reason=""
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            # PlayCover volume is locked if PlayCover is running OR any app is running
            if is_playcover_running; then
                is_locked=true
                lock_reason="app_running"  # PlayCover自体が動作中
            elif [[ "$any_app_running" == "true" ]]; then
                is_locked=true
                lock_reason="app_storage"  # 配下のアプリが動作中（アプリ本体.appを保管中）
            fi
        else
            if is_app_running "$bundle_id"; then
                is_locked=true
                lock_reason="app_running"  # アプリ自体が動作中
            fi
        fi
        
        # Check volume mount status using cached data
        local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
        local vol_status=$?
        
        if [[ $vol_status -eq 1 ]]; then
            status_line="❌ ボリュームが見つかりません"
        elif [[ $vol_status -eq 0 ]]; then
            # Volume is mounted
            # Additional check: if mount point is empty, treat as unmounted (stale cache protection)
            if [[ -z "$actual_mount" ]]; then
                # Cache might be stale, treat as unmounted
                local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
                case "$storage_mode" in
                    "none")
                        status_line="⚪️ 未マウント"
                        ;;
                    "internal_intentional")
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional"
                        ;;
                    "internal_intentional_empty")
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional_empty"
                        ;;
                    "internal_contaminated")
                        status_line="⚪️ 未マウント"
                        extra_info="internal_contaminated"
                        ;;
                    *)
                        status_line="⚪️ 未マウント"
                        ;;
                esac
            elif [[ "$actual_mount" == "$target_path" ]]; then
                status_line="🟢 マウント済: ${actual_mount}"
            else
                status_line="⚠️  マウント位置異常: ${actual_mount}"
            fi
        else
            # Volume exists but not mounted (vol_status == 2)
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
                
                case "$storage_mode" in
                    "none")
                        status_line="⚪️ 未マウント"
                        ;;
                    "internal_intentional")
                        # Intentionally switched to internal storage with data
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional"
                        ;;
                    "internal_intentional_empty")
                        # Intentionally switched to internal storage but empty
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional_empty"
                        ;;
                    "internal_contaminated")
                        # Unintended internal data contamination
                        status_line="⚪️ 未マウント"
                        extra_info="internal_contaminated"
                        ;;
                    *)
                        status_line="⚪️ 未マウント"
                        ;;
                esac
        fi
        
        # Display with lock status or number
        if $is_locked; then
            # Locked: show with lock icon, no number
            if [[ "$lock_reason" == "app_running" ]]; then
                echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🏃 アプリ動作中${NC}"
            elif [[ "$lock_reason" == "app_storage" ]]; then
                echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🚬 下記アプリの終了待機中${NC}"
            fi
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
        elif [[ "$extra_info" == "internal_intentional" ]] || [[ "$extra_info" == "internal_intentional_empty" ]]; then
            # Intentional internal storage mode (with or without data): show as locked
            echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🍎 内蔵ストレージモード${NC}"
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
        elif [[ "$extra_info" == "internal_contaminated" ]]; then
            # Contaminated: show as warning (selectable)
            selectable_array+=("${mappings_array[$i]}")
            selectable_indices+=("$i")
            
            echo "  ${BOLD}${YELLOW}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC} ${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
            echo "      ${GRAY}${status_line} ${ORANGE}| マウント時に処理方法を確認します${NC}"
            echo ""
            ((display_index++))
        else
            # Not locked: add to selectable array and show with number
            selectable_array+=("${mappings_array[$i]}")
            selectable_indices+=("$i")
            
            echo "  ${BOLD}${CYAN}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
            ((display_index++))
        fi
    done
    
    print_separator
    echo ""
    echo "${BOLD}${UNDERLINE}操作を選択してください:${NC}"
    if [[ ${#selectable_array[@]} -gt 0 ]]; then
        echo "  ${BOLD}${CYAN}1-$((display_index-1)).${NC} 個別マウント/アンマウント"
    fi
    echo "  ${BOLD}${GREEN}m.${NC} 全ボリュームをマウント"
    echo "  ${BOLD}${YELLOW}u.${NC} 全ボリュームをアンマウント"
    echo "  ${BOLD}${LIGHT_GRAY}0.${NC} 戻る  ${BOLD}${LIGHT_GRAY}q.${NC} 終了"
    echo ""
    echo "${DIM_GRAY}※ Enterキーのみ: 状態を再取得${NC}"
    echo ""
    echo -n "選択: "
    read choice
    
    # Empty Enter - refresh cache and redisplay menu
    if [[ -z "$choice" ]]; then
        refresh_all_volume_caches
        individual_volume_control
        return
    fi
    
    if [[ "$choice" == "0" ]] || [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
        return
    fi
    
    # Batch operations (sudo will be requested inside the function)
    if [[ "$choice" == "m" ]] || [[ "$choice" == "M" ]]; then
        batch_mount_all
        individual_volume_control
        return
    fi
    
    if [[ "$choice" == "u" ]] || [[ "$choice" == "U" ]]; then
        batch_unmount_all
        individual_volume_control
        return
    fi
    
    # Check if no selectable volumes
    if [[ ${#selectable_array} -eq 0 ]]; then
        print_warning "選択可能なボリュームがありません（全てロック中）"
        wait_for_enter
        individual_volume_control
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#selectable_array} ]]; then
        print_error "$MSG_INVALID_SELECTION"
        /bin/sleep 2
        individual_volume_control
        return
    fi
    
    # zsh arrays are 1-indexed, so choice can be used directly
    local selected_mapping="${selectable_array[$choice]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local current_mount=$(get_mount_point_cached "$volume_name")
    
    # Quick switch without confirmation - delegate to helper functions
    if [[ -n "$current_mount" ]]; then
        # Volume is mounted somewhere
        if ! check_volume_exists_or_error "$volume_name" "${display_name} の操作" "individual_volume_control"; then
            return
        fi
        
        # Check if mounted at correct location
        if [[ "$current_mount" == "$target_path" ]]; then
            # Correctly mounted -> Unmount
            _handle_unmount_operation "$volume_name" "$bundle_id" "$display_name"
            return
        else
            # Mounted at wrong location -> Remount to correct location
            _handle_remount_operation "$volume_name" "$bundle_id" "$display_name" "$target_path"
            return
        fi
    else
        # Currently unmounted -> Mount
        _handle_mount_operation "$volume_name" "$bundle_id" "$display_name" "$target_path"
        return
    fi
}

#######################################################
# Quick Launcher UI
#######################################################

# Show quick launcher menu (app selection and launch)
# Returns: 0 to continue to main menu, exits on quit
show_quick_launcher() {
    while true; do
        clear
        print_header "🚀 PlayCover クイックランチャー"
        
        # Preload all volume information into cache for fast display
        # This ensures quick launcher is as fast as management screens
        preload_all_volume_cache
        
        # Check PlayCover volume mount status using cached data
        local playcover_mount=$(validate_and_get_mount_point_cached "$PLAYCOVER_VOLUME_NAME")
        local pc_vol_status=$?
        
        if [[ $pc_vol_status -eq 1 ]]; then
            # Volume doesn't exist
            echo ""
            print_error "PlayCoverボリュームが見つかりません"
            echo ""
            print_info "初期セットアップが必要です"
            print_info "管理メニューから初期セットアップを実行してください"
            echo ""
            prompt_continue
            return 0  # Go to main menu
        fi
        
        # Check if PlayCover volume is mounted at correct location
        if [[ $pc_vol_status -ne 0 ]] || [[ "$playcover_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            echo ""
            print_warning "PlayCoverボリュームがマウントされていません"
            print_info "PlayCoverボリュームをマウントしています..."
            echo ""
            
            # Try to mount PlayCover volume
            if ! mount_app_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "$PLAYCOVER_BUNDLE_ID"; then
                print_error "PlayCoverボリュームのマウントに失敗しました"
                echo ""
                print_info "管理メニューから手動でマウントしてください"
                echo ""
                prompt_continue
                return 0  # Go to main menu
            fi
            
            print_success "PlayCoverボリュームをマウントしました"
            echo ""
            sleep 1
        fi
        
        # Get launchable apps
        local -a apps_info=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && apps_info+=("$line")
        done < <(get_launchable_apps)
        
        if [[ ${#apps_info[@]} -eq 0 ]]; then
            print_warning "起動可能なアプリがありません"
            echo ""
            print_info "管理メニューからIPAをインストールしてください"
            echo ""
            prompt_continue
            return 0  # Go to main menu
        fi
        
        # Get most recent app (only 1 app stored)
        local most_recent_bundle_id=$(get_recent_app 2>/dev/null)
        
        # Display app list (in mapping file order, no sorting)
        local index=1
        local -a app_names=()
        local -a bundle_ids=()
        local -a app_paths=()
        local recent_count=0
        
        for app_info in "${apps_info[@]}"; do
            IFS='|' read -r app_name bundle_id app_path <<< "$app_info"
            
            # Get display name from mapping file
            local display_name=""
            if [[ -f "$MAPPING_FILE" ]]; then
                while IFS=$'\t' read -r vol_name stored_bundle_id stored_display_name recent_flag; do
                    if [[ "$stored_bundle_id" == "$bundle_id" ]]; then
                        display_name=$stored_display_name
                        break
                    fi
                done < "$MAPPING_FILE"
            fi
            
            # Fallback to app_name if no display name found
            if [[ -z "$display_name" ]]; then
                display_name=$app_name
            fi
            
            app_names+=("$display_name")
            bundle_ids+=("$bundle_id")
            app_paths+=("$app_path")
            
            # Get storage state
            local container_path=$(get_container_path "$bundle_id")
            local volume_name=$(get_volume_name_from_bundle_id "$bundle_id")
            local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
            
            # Storage type icon (simple)
            local storage_icon=""
            case "$storage_mode" in
                "external"|"external_wrong_location"|"none")
                    storage_icon="⚡"
                    ;;
                "internal_intentional"|"internal_intentional_empty")
                    storage_icon="🍎"
                    ;;
                "internal_contaminated")
                    storage_icon="⚠️"
                    ;;
            esac
            
            # Check sudo necessity
            local sudo_mark=""
            if needs_sudo_for_launch "$bundle_id" "$storage_mode"; then
                sudo_mark="🔐"
            fi
            
            # Recent mark
            local recent_display=""
            if [[ -n "$most_recent_bundle_id" ]] && [[ "$bundle_id" == "$most_recent_bundle_id" ]]; then
                recent_display="⭐"
                recent_count=1
            fi
            
            # Format: [storage][sudo][recent] in fixed positions
            # Order: データ位置、要管理者権限、前回起動
            local slot1="${storage_icon:-  }"  # Storage icon or 2 spaces
            local slot2="${sudo_mark:-  }"     # Sudo icon or 2 spaces  
            local slot3="${recent_display:-  }" # Recent icon or 2 spaces
            
            printf "%s%s%s %2d. %s\n" \
                "$slot1" "$slot2" "$slot3" "$index" "$display_name"
            ((index++))
        done
        
        echo ""
        print_separator
        # Compact help: icons and actions in one line when possible
        local help_line="  🔐:要管理者権限"
        if [[ $recent_count -gt 0 ]]; then
            help_line="${help_line}  ⭐:前回起動 Enterで起動"
        fi
        echo "$help_line"
        echo "  ${BOLD}1-${#apps_info[@]}.${NC}アプリ起動  ${BOLD}p.${NC}PlayCover  ${BOLD}0.${NC}管理画面  ${BOLD}q.${NC}終了  ${DIM_GRAY}r.更新${NC}"
        print_separator
        echo ""
        
        # User input
        read "choice?選択: "
        
        case "$choice" in
            [rR])
                # Refresh cache - invalidate and redisplay
                refresh_all_volume_caches
                continue
                ;;
            "")
                # Empty input (Enter key) - launch most recent app if exists
                if [[ $recent_count -gt 0 ]] && [[ -n "$most_recent_bundle_id" ]]; then
                    # Find the recent app in the arrays (no longer at index 1)
                    local recent_index=0
                    for ((i=1; i<=${#bundle_ids[@]}; i++)); do
                        if [[ "${bundle_ids[$i]}" == "$most_recent_bundle_id" ]]; then
                            recent_index=$i
                            break
                        fi
                    done
                    
                    if [[ $recent_index -gt 0 ]]; then
                        local selected_name="${app_names[$recent_index]}"
                        local selected_bundle_id="${bundle_ids[$recent_index]}"
                        local selected_path="${app_paths[$recent_index]}"
                        
                        echo ""
                        local container_path=$(get_container_path "$selected_bundle_id")
                        local volume_name=$(get_volume_name_from_bundle_id "$selected_bundle_id")
                        local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                        
                        if launch_app "$selected_path" "$selected_name" "$selected_bundle_id" "$storage_mode"; then
                            # Success - return to quick launcher
                            echo ""
                            sleep 1
                            continue
                        else
                            # Failure - go to main menu
                            echo ""
                            print_warning "起動に失敗しました"
                            print_info "管理メニューで状態を確認してください"
                            echo ""
                            prompt_continue
                            return 0
                        fi
                    else
                        print_error "最近起動したアプリが見つかりません"
                        sleep 1
                        continue
                    fi
                else
                    # No recent app
                    print_error "最近起動したアプリがありません"
                    sleep 1
                    continue
                fi
                ;;
            0)
                return 0  # Go to main menu
                ;;
            [qQ])
                clear
                # Close Terminal window using AppleScript
                osascript -e 'tell application "Terminal" to close first window' & exit 0
                ;;
            [pP])
                echo ""
                open_playcover_settings
                echo ""
                prompt_continue
                continue  # Redisplay quick launcher
                ;;
            [1-9]|[1-9][0-9])
                if [[ $choice -ge 1 ]] && [[ $choice -le ${#apps_info[@]} ]]; then
                    # zsh arrays are 1-based, so choice directly maps to index
                    local selected_index=$choice
                    local selected_name="${app_names[$selected_index]}"
                    local selected_bundle_id="${bundle_ids[$selected_index]}"
                    local selected_path="${app_paths[$selected_index]}"
                    
                    echo ""
                    local container_path=$(get_container_path "$selected_bundle_id")
                    local volume_name=$(get_volume_name_from_bundle_id "$selected_bundle_id")
                    local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                    
                    if launch_app "$selected_path" "$selected_name" "$selected_bundle_id" "$storage_mode"; then
                        # Success - return to quick launcher
                        echo ""
                        sleep 1
                        continue
                    else
                        # Failure - go to main menu for troubleshooting
                        echo ""
                        print_warning "起動に失敗しました"
                        print_info "管理メニューで状態を確認してください"
                        echo ""
                        prompt_continue
                        return 0  # Go to main menu
                    fi
                else
                    print_error "無効な選択です"
                    sleep 1
                    continue
                fi
                ;;
            *)
                print_error "無効な選択です"
                sleep 1
                continue
                ;;
        esac
    done
}

