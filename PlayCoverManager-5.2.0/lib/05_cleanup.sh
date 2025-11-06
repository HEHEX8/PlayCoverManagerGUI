#!/bin/zsh
#
# PlayCover Volume Manager - Module 05: Nuclear Cleanup
# ════════════════════════════════════════════════════════════════════
#
# This module provides complete system reset functionality:
# - Scan and preview all deletion targets
# - Unmount all mapped volumes
# - Delete all APFS volumes
# - Uninstall PlayCover app (both Homebrew and manual)
# - Delete all mapped containers (internal storage)
# - Delete mapping file
# - Two-step confirmation ("yes" + "DELETE ALL")
#
# ⚠️  WARNING: This is a DESTRUCTIVE operation with NO UNDO!
#
# Hidden Access: This function is accessed via special keys:
#   - X, x, RESET, reset in main menu
#
# Version: 5.0.1
# Part of: Modular Architecture Refactoring

#######################################################
# Main Nuclear Cleanup Function
#######################################################

nuclear_cleanup() {
    clear
    print_separator "=" "$RED"
    echo ""
    echo "${RED}🔥 超強力クリーンアップ（完全リセット）🔥${NC}"
    echo ""
    print_separator "=" "$RED"
    echo ""
    
    #######################################################
    # Phase 1: Scan and collect deletion targets
    #######################################################
    
    echo "${CYAN}【フェーズ 1/2】削除対象をスキャンしています...${NC}"
    echo ""
    
    # Read mapping file and collect targets
    local mapped_volumes=()
    local mapped_containers=()
    
    if [[ -f "$MAPPING_FILE" ]]; then
        while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
            [[ -z "$volume_name" ]] || [[ -z "$bundle_id" ]] && continue
            
            # Get device in one call (validates existence)
            local device=$(validate_and_get_device "$volume_name")
            if [[ $? -eq 0 ]] && [[ -n "$device" ]]; then
                mapped_volumes+=("${display_name:-$volume_name}|${volume_name}|${device}|${bundle_id}")
            fi
            
            # Check if container exists
            local container_path="${HOME}/Library/Containers/${bundle_id}"
            if [[ -d "$container_path" ]]; then
                mapped_containers+=("${display_name:-$bundle_id}|${container_path}")
            fi
        done < "$MAPPING_FILE"
    fi
    
    # Check PlayCover app
    local playcover_app_exists=false
    local playcover_homebrew=false
    if "$BREW_PATH" list --cask playcover-community &>/dev/null 2>&1; then
        playcover_app_exists=true
        playcover_homebrew=true
    elif [[ -d "/Applications/PlayCover.app" ]]; then
        playcover_app_exists=true
        playcover_homebrew=false
    fi
    
    # Check mapping file
    local mapping_exists=false
    if [[ -f "$MAPPING_FILE" ]]; then
        mapping_exists=true
    fi
    
    #######################################################
    # Display deletion preview
    #######################################################
    
    clear
    print_separator "=" "$RED"
    echo ""
    echo "${RED}🔥 削除対象の確認 🔥${NC}"
    echo ""
    print_separator "=" "$RED"
    echo ""
    
    local total_items=0
    
    # 1. Volumes to unmount and delete
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        echo "${CYAN}【1】マップ登録ボリューム: ${#mapped_volumes}個${NC}"
        echo "     ${ORANGE}→ アンマウント後、削除されます${NC}"
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local vol_name=$(echo "$vol_info" | /usr/bin/cut -d'|' -f2)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            echo "  ${RED}💥${NC}  ${display}"
            echo "      ${ORANGE}${vol_name}${NC} (${device})"
            ((total_items++))
        done
        echo ""
    else
        echo "${CYAN}【1】マップ登録ボリューム: なし${NC}"
        echo ""
    fi
    
    # 2. PlayCover app
    echo "${CYAN}【2】PlayCoverアプリ${NC}"
    if [[ "$playcover_app_exists" == true ]]; then
        if [[ "$playcover_homebrew" == true ]]; then
            echo "  ${RED}🗑${NC}  PlayCover (Homebrew Cask)"
            echo "      ${ORANGE}brew uninstall --cask playcover-community${NC}"
        else
            echo "  ${RED}🗑${NC}  /Applications/PlayCover.app（手動インストール版）"
        fi
        ((total_items++))
    else
        echo "  ${GREEN}✅${NC}  インストールされていません"
    fi
    echo ""
    
    # 3. Mapped containers
    if [[ ${#mapped_containers} -gt 0 ]]; then
        echo "${CYAN}【3】マップ登録コンテナ（内蔵）: ${#mapped_containers}個${NC}"
        for container_info in "${(@)mapped_containers}"; do
            local display=$(echo "$container_info" | /usr/bin/cut -d'|' -f1)
            local container_path=$(echo "$container_info" | /usr/bin/cut -d'|' -f2)
            echo "  ${RED}🗑${NC}  ${display}"
            echo "      ${container_path}"
            ((total_items++))
        done
        echo ""
    else
        echo "${CYAN}【3】マップ登録コンテナ（内蔵）: なし${NC}"
        echo ""
    fi
    
    # 4. Mapping file
    echo "${CYAN}【4】マッピングファイル${NC}"
    if [[ "$mapping_exists" == true ]]; then
        echo "  ${RED}🗑${NC}  playcover-map.txt"
        ((total_items++))
    else
        echo "  ${GREEN}✅${NC}  存在しません（削除不要）"
    fi
    echo ""
    
    print_separator "─" "$YELLOW"
    echo ""
    echo "${ORANGE}合計削除項目: ${total_items}個${NC}"
    echo ""
    echo "${RED}⚠️  この操作は取り消せません！${NC}"
    echo ""
    echo "${CYAN}ℹ️  ゲームデータはアカウントに紐付いているため、再インストール後に復元できます${NC}"
    echo ""
    print_separator "─" "$YELLOW"
    echo ""
    
    # If nothing to delete
    if [[ $total_items -eq 0 ]]; then
        print_info "削除対象が見つかりません"
        wait_for_enter
        return
    fi
    
    #######################################################
    # Phase 2: Confirmation
    #######################################################
    
    # First confirmation
    if ! prompt_confirmation "上記の項目をすべて削除しますか？" "yes/no"; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    echo ""
    echo "${RED}⚠️  最終確認: 'DELETE ALL' と正確に入力してください:${NC} "
    read final_confirm
    
    if [[ "$final_confirm" != "DELETE ALL" ]]; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    echo ""
    print_separator "─" "$YELLOW"
    echo ""
    echo "${CYAN}【フェーズ 2/2】クリーンアップを実行します...${NC}"
    echo ""
    
    # Authenticate sudo
    authenticate_sudo
    
    #######################################################
    # Step 1: Unmount all mapped volumes
    #######################################################
    
    echo "${CYAN}【ステップ 1/5】マップ登録ボリュームをアンマウント${NC}"
    echo ""
    
    local unmount_count=0
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        # Quit all running apps first
        for vol_info in "${(@)mapped_volumes}"; do
            local bundle_id=$(echo "$vol_info" | /usr/bin/cut -d'|' -f4)
            if [[ "$bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
                quit_app_if_running "$bundle_id" 2>/dev/null || true
            fi
        done
        
        # Unmount volumes
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            
            echo "  アンマウント中: ${display} (${device})"
            if unmount_volume "$device" "silent" "force"; then
                ((unmount_count++))
                print_success "  完了"
            else
                print_warning "  失敗（既にアンマウント済み）"
            fi
        done
    else
        print_info "  アンマウント対象なし"
    fi
    
    print_success "ボリュームアンマウント完了: ${unmount_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 2: Delete all mapped volumes
    #######################################################
    
    echo "${CYAN}【ステップ 2/5】マップ登録ボリュームを削除${NC}"
    echo ""
    
    local volume_count=0
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local vol_name=$(echo "$vol_info" | /usr/bin/cut -d'|' -f2)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            
            echo "  削除中: ${display} (${device})"
            
            if /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$device" >/dev/null 2>&1; then
                print_success "  削除完了"
                ((volume_count++))
            else
                print_warning "  削除失敗（マウント済みまたは保護されています）"
            fi
        done
    else
        print_info "  削除対象なし"
    fi
    
    print_success "APFSボリューム削除完了: ${volume_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 3: Uninstall PlayCover app
    #######################################################
    
    echo "${CYAN}【ステップ 3/5】PlayCoverアプリをアンインストール${NC}"
    echo ""
    
    if [[ "$playcover_app_exists" == true ]]; then
        if [[ "$playcover_homebrew" == true ]]; then
            echo "  アンインストール中: PlayCover (Homebrew Cask)"
            if "$BREW_PATH" uninstall --cask playcover-community >/dev/null 2>&1; then
                print_success "  Homebrewからアンインストール完了"
            else
                print_warning "  Homebrewアンインストール失敗"
            fi
        else
            echo "  削除中: /Applications/PlayCover.app（手動インストール版）"
        fi
        
        # Clean up manual installation remnants
        if [[ -d "/Applications/PlayCover.app" ]]; then
            if /usr/bin/sudo /bin/rm -rf "/Applications/PlayCover.app" 2>/dev/null; then
                print_success "  削除完了"
            else
                print_warning "  削除失敗"
            fi
        fi
    else
        print_info "  アンインストール対象なし"
    fi
    
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 4: Delete all mapped containers
    #######################################################
    
    echo "${CYAN}【ステップ 4/5】マップ登録コンテナ（内蔵）を削除${NC}"
    echo ""
    
    local container_count=0
    if [[ ${#mapped_containers} -gt 0 ]]; then
        for container_info in "${(@)mapped_containers}"; do
            local display=$(echo "$container_info" | /usr/bin/cut -d'|' -f1)
            local container_path=$(echo "$container_info" | /usr/bin/cut -d'|' -f2)
            
            echo "  削除中: ${display}"
            if /usr/bin/sudo /bin/rm -rf "$container_path" 2>/dev/null; then
                print_success "  削除完了"
                ((container_count++))
            else
                print_warning "  削除失敗"
            fi
        done
    else
        print_info "  削除対象なし"
    fi
    
    print_success "コンテナ削除完了: ${container_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 5: Delete mapping file
    #######################################################
    
    echo "${CYAN}【ステップ 5/5】マッピングファイルを削除${NC}"
    echo ""
    
    if [[ "$mapping_exists" == true ]]; then
        echo "  削除中: playcover-map.txt"
        if /bin/rm -f "$MAPPING_FILE" 2>/dev/null; then
            print_success "  ✅ 削除完了"
        else
            print_warning "  ⚠️ 削除失敗"
        fi
        
        # Delete lock file if exists
        if [[ -d "$MAPPING_LOCK_FILE" ]]; then
            /bin/rmdir "$MAPPING_LOCK_FILE" 2>/dev/null || true
        fi
    else
        print_info "  削除対象なし"
    fi
    
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Final summary
    #######################################################
    
    echo ""
    print_separator "=" "$GREEN"
    echo ""
    echo "${GREEN}✅ クリーンアップ完了${NC}"
    echo ""
    print_separator "=" "$GREEN"
    echo ""
    
    echo "${ORANGE}⚠️  重要: 再セットアップが必要です${NC}"
    echo ""
    echo "${CYAN}次のステップ:${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}1.${NC} このツールを再起動"
    echo "      ${SKY_BLUE}→ 0_PlayCover-ManagementTool.command${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}2.${NC} メニューから初期セットアップを実行"
    echo "      ${SKY_BLUE}→ [1] 初期セットアップ${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}3.${NC} IPAインストールを実行"
    echo "      ${SKY_BLUE}→ [2] IPAインストール${NC}"
    echo ""
    echo "${ORANGE}📝 注意事項:${NC}"
    echo ""
    echo "  • ${RED}すべてのPlayCoverデータが削除されました${NC}"
    echo "  • ${RED}外部ボリュームも削除されました${NC}"
    echo "  • ${GREEN}ゲームデータはアカウントに紐付いているため復元できます${NC}"
    echo "  • 再インストール後、アカウントでログインしてください"
    echo ""
    print_separator "─" "$BLUE"
    echo ""
    echo "${CYAN}3秒後にターミナルを閉じます...${NC}"
    echo ""
    
    /bin/sleep 3
    exit_with_cleanup 0 "クリーンアップ完了"
}

#######################################################
# System Maintenance Functions
#######################################################

# Check and display APFS snapshot information
# This helps diagnose storage space issues
check_apfs_snapshots() {
    echo ""
    print_separator "━" "$CYAN"
    echo "${CYAN}APFSスナップショットの確認${NC}"
    print_separator "━" "$CYAN"
    echo ""
    
    print_info "ローカルスナップショットをチェック中..."
    local snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -v "Snapshots for volume group")
    
    if [[ -z "$snapshots" ]]; then
        print_success "ローカルスナップショットは見つかりませんでした"
        echo ""
        return 0
    fi
    
    local snapshot_count=$(echo "$snapshots" | wc -l | /usr/bin/xargs)
    print_warning "ローカルスナップショット: ${snapshot_count}個"
    echo ""
    
    # Show snapshots
    echo "${GRAY}スナップショット一覧:${NC}"
    echo "$snapshots" | while read -r snap; do
        echo "  ${DIM_GRAY}${snap}${NC}"
    done
    echo ""
    
    # Explain the issue
    echo "${YELLOW}💡 ストレージ容量について${NC}"
    echo ""
    echo "${WHITE}APFSスナップショットは、Time Machineや${NC}"
    echo "${WHITE}システムアップデートにより自動作成されます。${NC}"
    echo ""
    echo "${ORANGE}これらは「その時点でのデータ」を保持するため、${NC}"
    echo "${RED}削除したファイルの容量が解放されない${NC}${ORANGE}ことがあります。${NC}"
    echo ""
    
    # Offer cleanup
    echo -n "${CYAN}スナップショットを削除しますか? (y/n):${NC} "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        cleanup_apfs_snapshots
    else
        print_info "スキップしました"
    fi
    
    echo ""
}

# Clean up APFS snapshots to free space
# This is safe and can help recover "phantom" storage consumption
cleanup_apfs_snapshots() {
    echo ""
    print_info "スナップショットを削除中..."
    echo ""
    
    # Get list of snapshots
    local snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep "com.apple" || true)
    
    if [[ -z "$snapshots" ]]; then
        print_info "削除可能なスナップショットがありません"
        echo ""
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    # Delete each snapshot
    echo "$snapshots" | while read -r snapshot; do
        # Extract snapshot name
        local snap_name=$(echo "$snapshot" | /usr/bin/sed 's/^com\.apple\./com.apple./')
        
        if [[ -n "$snap_name" ]]; then
            printf "  削除中: ${DIM_GRAY}${snap_name}${NC}... "
            
            if sudo tmutil deletelocalsnapshots "$snap_name" >/dev/null 2>&1; then
                echo "${GREEN}✓${NC}"
                ((deleted_count++))
            else
                echo "${RED}✗${NC}"
                ((failed_count++))
            fi
        fi
    done
    
    echo ""
    
    if (( deleted_count > 0 )); then
        print_success "削除完了: ${deleted_count}個のスナップショット"
        echo ""
        print_info "💡 ストレージ容量表示の更新には数分かかる場合があります"
    fi
    
    if (( failed_count > 0 )); then
        print_warning "削除失敗: ${failed_count}個のスナップショット"
        print_info "システムが使用中のスナップショットは削除できません"
    fi
    
    echo ""
}

# Comprehensive system maintenance menu
# Offers multiple cleanup options
system_maintenance_menu() {
    clear
    print_separator "═" "$CYAN"
    echo ""
    echo "${CYAN}🛠️  システムメンテナンス${NC}"
    echo ""
    print_separator "═" "$CYAN"
    echo ""
    
    echo "${WHITE}実行可能な操作:${NC}"
    echo ""
    echo "  ${CYAN}1.${NC} APFSスナップショットの確認・削除"
    echo "     ${GRAY}→ ストレージ容量が解放されない問題を解決${NC}"
    echo ""
    echo "  ${CYAN}2.${NC} システムキャッシュのクリア"
    echo "     ${GRAY}→ 一時ファイルとキャッシュを削除${NC}"
    echo ""
    echo "  ${CYAN}3.${NC} ストレージ使用状況の確認"
    echo "     ${GRAY}→ 各ボリュームの容量を表示${NC}"
    echo ""
    echo "  ${CYAN}q.${NC} メインメニューに戻る"
    echo ""
    
    echo -n "${CYAN}選択 (1-3/q):${NC} "
    read -r choice
    
    case $choice in
        1)
            check_apfs_snapshots
            echo ""
            read -k1 -s "?Enterキーを押して続行..."
            system_maintenance_menu
            ;;
        2)
            clear_system_caches
            echo ""
            read -k1 -s "?Enterキーを押して続行..."
            system_maintenance_menu
            ;;
        3)
            show_storage_usage
            echo ""
            read -k1 -s "?Enterキーを押して続行..."
            system_maintenance_menu
            ;;
        q|Q)
            return 0
            ;;
        *)
            print_error "無効な選択です"
            sleep 1
            system_maintenance_menu
            ;;
    esac
}

# Clear system caches
clear_system_caches() {
    echo ""
    print_separator "━" "$CYAN"
    echo "${CYAN}システムキャッシュのクリア${NC}"
    print_separator "━" "$CYAN"
    echo ""
    
    print_info "以下のキャッシュがクリアされます:"
    echo ""
    echo "  ${GRAY}• ユーザーキャッシュ${NC}"
    echo "  ${GRAY}• 一時ファイル${NC}"
    echo "  ${GRAY}• ダウンロード済みアップデート${NC}"
    echo ""
    
    echo -n "${YELLOW}続行しますか? (y/n):${NC} "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "キャンセルしました"
        return 0
    fi
    
    echo ""
    print_info "キャッシュをクリア中..."
    echo ""
    
    local cleaned_count=0
    
    # User caches
    if [[ -d "$HOME/Library/Caches" ]]; then
        printf "  ユーザーキャッシュ... "
        local cache_size=$(du -sh "$HOME/Library/Caches" 2>/dev/null | awk '{print $1}')
        sudo rm -rf "$HOME/Library/Caches/"* 2>/dev/null || true
        echo "${GREEN}✓${NC} ${GRAY}(${cache_size})${NC}"
        ((cleaned_count++))
    fi
    
    # System tmp
    if [[ -d "/tmp" ]]; then
        printf "  一時ファイル... "
        sudo rm -rf /tmp/* 2>/dev/null || true
        echo "${GREEN}✓${NC}"
        ((cleaned_count++))
    fi
    
    # Downloaded updates
    if [[ -d "$HOME/Library/Updates" ]]; then
        printf "  ダウンロード済みアップデート... "
        local update_size=$(du -sh "$HOME/Library/Updates" 2>/dev/null | awk '{print $1}')
        sudo rm -rf "$HOME/Library/Updates/"* 2>/dev/null || true
        echo "${GREEN}✓${NC} ${GRAY}(${update_size})${NC}"
        ((cleaned_count++))
    fi
    
    echo ""
    print_success "クリア完了: ${cleaned_count}項目"
    echo ""
}

# Show storage usage information
show_storage_usage() {
    echo ""
    print_separator "━" "$CYAN"
    echo "${CYAN}ストレージ使用状況${NC}"
    print_separator "━" "$CYAN"
    echo ""
    
    print_info "ストレージ情報を取得中..."
    echo ""
    
    # System volume
    local system_info=$(df -H / | tail -1)
    local system_total=$(echo "$system_info" | awk '{print $2}')
    local system_used=$(echo "$system_info" | awk '{print $3}')
    local system_avail=$(echo "$system_info" | awk '{print $4}')
    local system_percent=$(echo "$system_info" | awk '{print $5}')
    
    echo "${CYAN}システムボリューム (/)${NC}"
    echo "  ${WHITE}合計:${NC}     ${system_total}"
    echo "  ${ORANGE}使用中:${NC}   ${system_used} ${GRAY}(${system_percent})${NC}"
    echo "  ${GREEN}利用可能:${NC} ${system_avail}"
    echo ""
    
    # Check for external volumes
    if [[ -f "$MAPPING_FILE" ]]; then
        local has_external=false
        
        while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
            [[ -z "$volume_name" ]] || [[ -z "$bundle_id" ]] && continue
            
            local mount_point=$(get_mount_point "$volume_name")
            if [[ -n "$mount_point" ]]; then
                if [[ "$has_external" == false ]]; then
                    echo "${CYAN}外部ボリューム${NC}"
                    has_external=true
                fi
                
                local vol_info=$(df -H "$mount_point" 2>/dev/null | tail -1)
                if [[ -n "$vol_info" ]]; then
                    local vol_total=$(echo "$vol_info" | awk '{print $2}')
                    local vol_used=$(echo "$vol_info" | awk '{print $3}')
                    local vol_avail=$(echo "$vol_info" | awk '{print $4}')
                    local vol_percent=$(echo "$vol_info" | awk '{print $5}')
                    
                    echo "  ${WHITE}${display_name:-$volume_name}${NC}"
                    echo "    合計:     ${vol_total}"
                    echo "    使用中:   ${vol_used} ${GRAY}(${vol_percent})${NC}"
                    echo "    利用可能: ${vol_avail}"
                    echo ""
                fi
            fi
        done < "$MAPPING_FILE"
    fi
}
